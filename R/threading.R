# Scheduler-aware thread allocation for Stan fits. When a caller asks for
# threading via stan_options(threading = TRUE), flexstanr splits the cores the
# process is allowed to use between chain-parallelism (independent MCMC chains,
# ~linear speedup, no coordination) and within-chain threading (Stan's reduce_sum
# over a conditionally-independent term). Chain-parallelism is filled first
# because it has no threading overhead; leftover cores become per-chain threads.
# The split is written onto the options for whichever backend is in use -- rstan
# (cores; the per-chain thread count rides along and fit_rstan() applies it via
# STAN_NUM_THREADS at fit time) or cmdstanr (native parallel_chains /
# threads_per_chain). All of this is internal: the user-facing surface is the
# single `threading` switch on stan_options(). Ported from hestia (#24).

#' Split available cores between chain-parallelism and within-chain threads
#'
#' @description Decides how many chains to run in parallel and how many threads
#' each chain gets. Chain-parallelism has no threading overhead and scales
#' ~linearly, so it is filled first; any leftover cores become per-chain threads:
#' `parallel_chains = min(chains, cores)` and
#' `threads_per_chain = max(1L, cores %/% parallel_chains)`. Cores that do not
#' divide evenly are left idle rather than rebalanced.
#'
#' @param chains number of MCMC chains (a single positive integer).
#' @param cores total cores to split (a single positive integer).
#' @returns a list with integer elements `parallel_chains` and
#'   `threads_per_chain`.
#' @keywords internal
optimal_alloc <- function(chains, cores) {
  if (length(chains) != 1L) {
    stop("'chains' must be a single positive integer", call. = FALSE)
  }
  chains <- assert_positive_int(chains, "chains")
  if (length(cores) != 1L) {
    stop("'cores' must be a single positive integer", call. = FALSE)
  }
  cores <- assert_positive_int(cores, "cores")

  parallel_chains   <- min(chains, cores)
  threads_per_chain <- max(1L, cores %/% parallel_chains)

  list(parallel_chains = parallel_chains, threads_per_chain = threads_per_chain)
}

#' Write a thread allocation onto sampler options, per backend
#'
#' @description Records an [optimal_alloc()] split on a [stan_options()] list
#' using each backend's own field names. No environment variable is touched here:
#' rstan's per-chain thread count rides along as `threads_per_chain` (metadata
#' that [fit_model()] strips and applies via `STAN_NUM_THREADS` at fit time),
#' while cmdstanr consumes `parallel_chains` / `threads_per_chain` natively.
#'
#' @param res a [stan_options()] result (backend already recorded).
#' @param alloc an [optimal_alloc()] result.
#' @returns `res`, with the backend's parallelism fields set.
#' @keywords internal
write_threading <- function(res, alloc) {
  switch(
    res$backend,
    rstan = {
      res$cores <- alloc$parallel_chains
      # Carried, not an rstan::sampling() argument; fit_rstan() applies it via
      # STAN_NUM_THREADS and strips it before dispatch.
      res$threads_per_chain <- alloc$threads_per_chain
    },
    cmdstanr = {
      res$parallel_chains   <- alloc$parallel_chains
      res$threads_per_chain <- alloc$threads_per_chain
    }
  )
  res
}

#' Automatically allocate and record threading on a stan_options result
#'
#' @description Backs [stan_options()]'s `threading = TRUE`. Detects the cores
#' the process is *allowed* to use with [parallelly::availableCores()] (which
#' respects the HPC scheduler's allocation -- `SLURM_CPUS_PER_TASK`, PBS, SGE,
#' LSF -- cgroup CPU quotas, `getOption("mc.cores")`, and returns 2 under
#' `R CMD check`, so it never over-subscribes a scheduled job), reserves one core
#' by default (or caps the pool at `max_cores`), splits it across the chains with
#' [optimal_alloc()], writes the result with [write_threading()], and messages
#' the chosen allocation so the choice is never silent.
#'
#' @param res a [stan_options()] result (backend and chains already recorded).
#' @param max_cores optional cap on the cores used; `NULL` uses all available
#'   minus one.
#' @returns `res`, with threading allocated and recorded.
#' @keywords internal
apply_auto_threading <- function(res, max_cores = NULL) {
  available <- detect_cores()
  if (is.null(max_cores)) {
    pool <- max(1L, available - 1L)   # leave one core for everything else
  } else {
    if (length(max_cores) != 1L) {
      stop("'max_cores' must be a single positive integer", call. = FALSE)
    }
    pool <- min(available, assert_positive_int(max_cores, "max_cores"))
  }
  alloc <- optimal_alloc(res$chains, cores = pool)
  res <- write_threading(res, alloc)
  # Report the cores actually used (chains x threads), not the pool: with
  # `chains` chains and one thread each, most of a large pool sits idle.
  used <- alloc$parallel_chains * alloc$threads_per_chain
  message(
    "flexstanr: threading enabled. Using ", used, " of ", available,
    " available core", if (available == 1L) "" else "s", ": ",
    alloc$parallel_chains, " chain",
    if (alloc$parallel_chains == 1L) "" else "s", " in parallel, ",
    alloc$threads_per_chain, " thread",
    if (alloc$threads_per_chain == 1L) "" else "s", " per chain.",
    if (is.null(max_cores) && pool < available)
      " Reserved 1 core; pass max_cores to change." else ""
  )
  res
}

#' Cores the process is allowed to use
#'
#' A one-line seam over [parallelly::availableCores()] so tests can mock the core
#' count (via [testthat::local_mocked_bindings()]) rather than the machine.
#' @returns a single positive integer.
#' @keywords internal
detect_cores <- function() {
  parallelly::availableCores()
}

#' Run an expression with STAN_NUM_THREADS set, restoring it afterwards
#'
#' @description rstan reads `STAN_NUM_THREADS` at sampling time. This sets it for
#' the duration of `expr` and restores the previous value afterwards (clearing
#' it if it was unset), so a fit does not leak its per-chain thread count into
#' the rest of the session.
#'
#' @param threads the per-chain thread count to expose.
#' @param expr the expression to evaluate with the variable set (lazily, so it
#'   runs *after* the variable is in place).
#' @returns the value of `expr`.
#' @keywords internal
with_stan_num_threads <- function(threads, expr) {
  old <- Sys.getenv("STAN_NUM_THREADS", unset = NA_character_)
  on.exit(
    if (is.na(old)) Sys.unsetenv("STAN_NUM_THREADS") else
      Sys.setenv(STAN_NUM_THREADS = old),
    add = TRUE
  )
  Sys.setenv(STAN_NUM_THREADS = threads)
  force(expr)
}
