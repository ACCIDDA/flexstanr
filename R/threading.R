# Scheduler-aware thread allocation for Stan fits. Splits the cores a process is
# allowed to use between chain-parallelism (independent MCMC chains, ~linear
# speedup, no coordination) and within-chain threading (Stan's reduce_sum over a
# conditionally-independent term). Chain-parallelism is filled first because it
# has no threading overhead; leftover cores become per-chain threads. The split
# is then written onto a stan_options() object for whichever backend is in use --
# rstan (cores + the STAN_NUM_THREADS env var) or cmdstanr (native
# parallel_chains / threads_per_chain arguments). Ported from hestia (#24), which
# now depends on flexstanr for it rather than carrying its own copy.

#' Split available cores between chain-parallelism and within-chain threads
#'
#' @description
#' Given the number of MCMC `chains` and the cores available, decides how many
#' chains to run in parallel and how many threads each chain gets for a
#' `reduce_sum` likelihood. Chain-parallelism has no threading overhead and
#' scales ~linearly, so it is filled first; any leftover cores become per-chain
#' threads. Pair the result with [configure_threading()] to apply it to a
#' [stan_options()] object.
#'
#' @details
#' `parallel_chains = min(chains, cores)` and
#' `threads_per_chain = max(1L, cores %/% parallel_chains)`. So threading only
#' "turns on" (more than one thread) when there are more cores than chains;
#' otherwise every core goes to running chains in parallel. Cores that do not
#' divide evenly are left idle rather than rebalanced.
#'
#' @param chains number of MCMC chains (a single positive integer).
#' @param cores total cores to use. If `NULL` (default), the cores *available to
#'   the process* are detected with [parallelly::availableCores()], which
#'   respects the HPC scheduler's allocation (`SLURM_CPUS_PER_TASK`, PBS, SGE,
#'   LSF), cgroup CPU quotas, `getOption("mc.cores")`, and returns 2 under
#'   `R CMD check`. This is deliberately *not* [parallel::detectCores()], which
#'   reports the whole node and would over-subscribe a scheduled HPC job. An
#'   explicit `cores` is used as given (no cap).
#' @returns a list with integer elements `parallel_chains` and
#'   `threads_per_chain`.
#'
#' @seealso [configure_threading()]
#'
#' @examples
#' optimal_alloc(4, cores = 8)   # 4 chains in parallel, 2 threads each
#' optimal_alloc(4, cores = 4)   # 4 chains in parallel, 1 thread each
#' optimal_alloc(2, cores = 8)   # 2 chains in parallel, 4 threads each
#'
#' @export
optimal_alloc <- function(chains, cores = NULL) {
  if (length(chains) != 1L) {
    stop("'chains' must be a single positive integer", call. = FALSE)
  }
  chains <- assert_positive_int(chains, "chains")

  if (is.null(cores)) {
    # Cores the process is *allowed* to use (scheduler-, cgroup-, and
    # check-aware), not the node's physical core count.
    cores <- parallelly::availableCores()
  }
  if (length(cores) != 1L) {
    stop("'cores' must be a single positive integer", call. = FALSE)
  }
  cores <- assert_positive_int(cores, "cores")

  parallel_chains   <- min(chains, cores)
  threads_per_chain <- max(1L, cores %/% parallel_chains)

  list(parallel_chains = parallel_chains, threads_per_chain = threads_per_chain)
}

#' Apply a core allocation to sampler options for the active backend
#'
#' @description
#' Writes an [optimal_alloc()] split onto a [stan_options()] object using the
#' native threading controls of the backend the options were built for:
#'
#' * **rstan** runs chains in parallel via `cores` and reads the per-chain thread
#'   count from the `STAN_NUM_THREADS` environment variable at sampling time (it
#'   has no threads-per-chain argument). So this sets `stan_opts$cores` and, as a
#'   side effect, `Sys.setenv(STAN_NUM_THREADS = ...)`.
#' * **cmdstanr** takes both natively, so this sets `stan_opts$parallel_chains`
#'   and `stan_opts$threads_per_chain` and touches no environment variable.
#'
#' It runs *after* [stan_options()] and deliberately writes each backend's own
#' field names, bypassing the cross-backend vocabulary guard that
#' [stan_options()] applies at construction time.
#'
#' @section Side effects (rstan):
#' The rstan branch mutates the process environment (`STAN_NUM_THREADS`), which
#' persists beyond the fit and is what [check_threaded()] inspects. A caller that
#' does not want the thread count to leak into the rest of the session should
#' save and restore it around the fit (e.g. with an `on.exit()` handler or
#' [withr::local_envvar()]). See the "Parallel and threaded fitting" vignette.
#'
#' @section Compiling for threading (cmdstanr):
#' `threads_per_chain > 1` only takes effect if the model was compiled with
#' threading enabled (`cpp_options = list(stan_threads = TRUE)`). [fit_model()]
#' does this automatically when the options carry a multi-thread allocation.
#'
#' @param stan_opts a [stan_options()] result.
#' @param alloc an [optimal_alloc()] result (a list with `parallel_chains` and
#'   `threads_per_chain`).
#' @returns `stan_opts`, updated with the allocation for its backend.
#'
#' @seealso [optimal_alloc()], [check_threaded()]
#'
#' @examples
#' opts <- stan_options(chains = 4)
#' old <- Sys.getenv("STAN_NUM_THREADS", unset = NA)
#' opts <- configure_threading(opts, optimal_alloc(4, cores = 8))
#' opts$cores                      # 4 chains in parallel
#' Sys.getenv("STAN_NUM_THREADS")  # "2" threads per chain
#' # restore the previous value so the fit does not leak its thread count
#' if (is.na(old)) Sys.unsetenv("STAN_NUM_THREADS") else
#'   Sys.setenv(STAN_NUM_THREADS = old)
#'
#' @export
configure_threading <- function(stan_opts, alloc) {
  pc  <- assert_positive_int(alloc$parallel_chains, "parallel_chains")
  tpc <- assert_positive_int(alloc$threads_per_chain, "threads_per_chain")
  # Fail loudly on an invalid backend rather than silently returning the options
  # unchanged (an empty switch is a no-op). stan_options() already guarantees a
  # valid backend, but this is an exported entry point taking arbitrary input.
  backend <- stan_opts$backend
  if (length(backend) != 1L || !backend %in% c("rstan", "cmdstanr")) {
    stop(
      'configure_threading(): stan_opts$backend must be "rstan" or "cmdstanr".',
      call. = FALSE
    )
  }
  switch(
    backend,
    rstan = {
      stan_opts$cores <- pc
      Sys.setenv(STAN_NUM_THREADS = tpc)
    },
    cmdstanr = {
      stan_opts$parallel_chains   <- pc
      stan_opts$threads_per_chain <- tpc
    }
  )
  stan_opts
}
