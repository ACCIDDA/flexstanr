# --- convergence and sampler diagnostics --------------------------------------
# backend_diagnostics() reports the numbers a caller needs to judge whether a fit
# can be trusted, in one shape for both backends. It computes and reports; it
# does not judge. Thresholds, pass/fail flags, and warnings are modeling
# decisions that belong to the host package.
#
# Parameter summaries delegate to posterior; sampler summaries use the public
# cmdstanr diagnostic_summary() and rstan get_bfmi() methods. RStan's public
# count helpers aggregate chains, so only its per-chain counts stay local.
# A normalized sampler array supplies missing-column and undefined-energy
# guards, and a fallback for valid chains when cmdstanr's E-BFMI helper returns
# NA for every chain because another chain contains missing energy.

#' Per-parameter convergence summaries
#'
#' @param draws a posterior `draws` object.
#' @returns a base `data.frame` with one row per flat variable and columns
#'   `variable`, `rhat`, `ess_bulk`, and `ess_tail`.
#' @keywords internal
diagnose_parameters <- function(draws) {
  # posterior warns when it caps an unstable ESS estimate. Keep its reported
  # value, but leave all judgments and warnings to the caller of this API.
  s <- suppressWarnings(posterior::summarise_draws(
    draws,
    rhat = posterior::rhat,
    ess_bulk = posterior::ess_bulk,
    ess_tail = posterior::ess_tail
  ))
  data.frame(
    variable = s$variable,
    rhat = s$rhat,
    ess_bulk = s$ess_bulk,
    ess_tail = s$ess_tail
  )
}

#' Whether one chain's energy can have a defined E-BFMI
#'
#' @param energy numeric vector of post-warmup `energy__` values.
#' @returns a logical scalar.
#' @keywords internal
test_ebfmi_energy <- function(energy) {
  if (length(energy) < 3L || any(!is.finite(energy))) {
    return(FALSE)
  }
  variance <- stats::var(energy)
  is.finite(variance) && variance > 0
}

#' Fallback E-BFMI for one chain's post-warmup energy
#'
#' Used only when the reference cannot report a valid chain independently.
#' @param energy numeric vector of `energy__` values for one chain.
#' @returns a numeric scalar, or `NA` when undefined (fewer than three
#'   iterations, non-finite energy, zero variance, or numerical overflow).
#' @keywords internal
chain_ebfmi <- function(energy) {
  if (!test_ebfmi_energy(energy)) {
    return(NA_real_)
  }
  ebfmi <- (sum(diff(energy)^2) / length(energy)) / stats::var(energy)
  if (is.finite(ebfmi)) ebfmi else NA_real_
}

#' Per-chain sampler diagnostics
#'
#' @param sampler a plain iterations x chains x variables array of post-warmup
#'   sampler parameters (`divergent__`, `treedepth__`, `energy__`, ...).
#' @param max_treedepth the run's maximum tree depth setting.
#' @param reference named list or data frame of available backend summaries.
#' @returns a base `data.frame` with one row per chain and columns `chain`,
#'   `num_divergent`, `num_max_treedepth`, and `ebfmi`. A diagnostic whose
#'   sampler column is absent (e.g. `algorithm = "Fixed_param"`) is `NA`.
#' @keywords internal
diagnose_chains <- function(sampler, max_treedepth, reference = NULL) {
  n_iter <- dim(sampler)[1L]
  n_chains <- dim(sampler)[2L]
  vars <- dimnames(sampler)[[3L]]
  # iterations x chains matrix for one sampler column, or NULL if not written
  column <- function(v) {
    if (!v %in% vars) {
      return(NULL)
    }
    matrix(sampler[, , v], nrow = n_iter, ncol = n_chains)
  }
  per_chain <- function(m, f, na) {
    if (is.null(m)) rep(na, n_chains) else apply(m, 2L, f)
  }
  counts <- function(variable, summary, f) {
    if (!variable %in% vars) {
      return(rep(NA_integer_, n_chains))
    }
    if (!is.null(reference[[summary]])) {
      return(as.integer(reference[[summary]]))
    }
    per_chain(column(variable), f, NA_integer_)
  }
  energy <- column("energy__")
  ebfmi <- reference$ebfmi
  if (is.null(ebfmi)) {
    ebfmi <- per_chain(energy, chain_ebfmi, NA_real_)
  } else {
    ebfmi <- as.numeric(ebfmi)
    for (k in seq_len(n_chains)) {
      if (is.null(energy) || !test_ebfmi_energy(energy[, k])) {
        ebfmi[k] <- NA_real_
      } else if (!is.finite(ebfmi[k])) {
        # cmdstanr can return NA for all chains when only one contains NA.
        ebfmi[k] <- chain_ebfmi(energy[, k])
      }
    }
  }

  data.frame(
    chain = seq_len(n_chains),
    num_divergent = counts(
      "divergent__", "num_divergent", function(x) as.integer(sum(x))
    ),
    num_max_treedepth = counts(
      "treedepth__", "num_max_treedepth",
      function(x) as.integer(sum(x >= max_treedepth))
    ),
    ebfmi = ebfmi
  )
}

#' Stack rstan's per-chain sampler parameters into one array
#'
#' @param sp the list returned by `rstan::get_sampler_params()`: one
#'   iterations x variables matrix per chain.
#' @returns a plain iterations x chains x variables array.
#' @keywords internal
rstan_sampler_array <- function(sp) {
  # simplify2array() drops dimensions for length-one (or empty) matrices.
  # Declare all three dimensions before moving chains to the second margin.
  out <- aperm(array(
    unlist(sp, use.names = FALSE),
    dim = c(dim(sp[[1L]]), length(sp))
  ), c(1L, 3L, 2L))
  dimnames(out) <- list(iteration = NULL, chain = NULL, variable = colnames(sp[[1L]]))
  out
}

#' The maximum tree depth an rstan fit ran with
#'
#' @param stan_args one chain's `stan_args` list from a `stanfit`.
#' @returns an integer scalar; rstan's default of 10 when not set.
#' @keywords internal
rstan_max_treedepth <- function(stan_args) {
  max_td <- stan_args$control$max_treedepth
  if (is.null(max_td)) 10L else as.integer(max_td)
}

#' A fit's post-warmup sampler parameters, for either backend
#'
#' @param raw_fit a backend-native fit object.
#' @returns a plain iterations x chains x variables array, or `NULL` for
#'   cmdstanr fixed-parameter fits, which do not expose sampler diagnostics.
#' @keywords internal
fit_sampler_array <- function(raw_fit) {
  switch(
    fit_backend(raw_fit),
    rstan = {
      assert_backend_available("rstan")
      rstan_sampler_array(rstan::get_sampler_params(raw_fit, inc_warmup = FALSE))
    },
    cmdstanr = {
      assert_backend_available("cmdstanr")
      if (isTRUE(raw_fit$metadata()$algorithm == "fixed_param")) {
        return(NULL)
      }
      cmdstanr_draws_array(raw_fit$sampler_diagnostics(
        inc_warmup = FALSE, format = "draws_array"
      ))
    }
  )
}

#' Available public backend sampler summaries
#'
#' @param raw_fit a backend-native fit object.
#' @param sampler normalized post-warmup sampler parameters.
#' @returns a named list or data frame of the available per-chain summaries.
#' @keywords internal
fit_sampler_summary <- function(raw_fit, sampler) {
  vars <- dimnames(sampler)[[3L]]
  diagnostics <- c(
    divergences = "divergent__", treedepth = "treedepth__", ebfmi = "energy__"
  )
  diagnostics <- names(diagnostics)[diagnostics %in% vars]
  if (dim(sampler)[1L] < 3L) {
    diagnostics <- setdiff(diagnostics, "ebfmi")
  }
  switch(
    fit_backend(raw_fit),
    rstan = {
      if ("ebfmi" %in% diagnostics) {
        list(ebfmi = suppressWarnings(rstan::get_bfmi(raw_fit)))
      } else {
        list()
      }
    },
    cmdstanr = {
      # Older cmdstanr versions can error on undefined E-BFMI even in quiet
      # mode; newer versions can lose valid chains when another contains NA.
      # Ask for E-BFMI only when every chain has usable energy.
      if ("ebfmi" %in% diagnostics && !all(vapply(
        seq_len(dim(sampler)[2L]),
        function(k) test_ebfmi_energy(sampler[, k, "energy__"]), logical(1L)
      ))) {
        diagnostics <- setdiff(diagnostics, "ebfmi")
      }
      if (length(diagnostics)) {
        if (!is.function(raw_fit$diagnostic_summary)) {
          stop("computing sampler diagnostics needs cmdstanr >= 0.5.0; update it.", call. = FALSE)
        }
        suppressWarnings(raw_fit$diagnostic_summary(
          diagnostics = diagnostics, quiet = TRUE
        ))
      } else {
        list()
      }
    }
  )
}

#' The maximum tree depth a fit ran with, for either backend
#'
#' @param raw_fit a backend-native fit object.
#' @returns an integer scalar, or `NA` when no tree depth setting applies.
#' @keywords internal
fit_max_treedepth <- function(raw_fit) {
  switch(
    fit_backend(raw_fit),
    rstan = rstan_max_treedepth(raw_fit@stan_args[[1L]]),
    cmdstanr = {
      metadata <- raw_fit$metadata()
      if (isTRUE(metadata$algorithm == "fixed_param") || is.null(metadata$max_treedepth)) {
        NA_integer_
      } else {
        as.integer(metadata$max_treedepth)
      }
    }
  )
}

#' Convergence and sampler diagnostics for a fit
#'
#' @description
#' The backend-agnostic way to read the numbers used to judge whether a fit can
#' be trusted. The result has the same shape whichever backend produced the fit.
#'
#' `backend_diagnostics()` only reports; it applies no thresholds and signals no
#' warnings. Deciding what counts as a failed fit is left to the caller. The
#' current Stan guidance (Vehtari et al. 2021) is R-hat below 1.01, bulk and tail
#' ESS of at least 100 per chain, and no divergent transitions.
#'
#' R-hat and ESS are computed by the 'posterior' package on both backends. The
#' sampler diagnostics delegate to cmdstanr's `diagnostic_summary()` and rstan's
#' `get_bfmi()`. RStan's divergence and treedepth helpers return totals, so their
#' counts are computed per chain here. Undefined E-BFMI values are normalized to
#' `NA`; a per-chain fallback preserves valid chains when cmdstanr cannot report
#' them independently of a chain with missing energy. A post-warmup transition
#' whose tree depth reaches `max_treedepth` counts as a hit, and E-BFMI is
#' `sum(diff(energy)^2) / (N * var(energy))` for each chain,
#' where `N` is its number of post-warmup iterations.
#'
#' @param raw_fit a backend-native fit object (an rstan `stanfit` or a cmdstanr
#'   `CmdStanMCMC`).
#' @param pars character vector of parameter base names to summarize, with the
#'   same meaning as in [backend_extract()]. `NULL`, the default, summarizes
#'   every parameter, including `lp__`, transformed parameters, and generated
#'   quantities; pass the parameters you care about to limit the cost on large
#'   models. The per-chain diagnostics are unaffected by `pars`.
#' @returns a list with elements:
#'   * `parameters`: a `data.frame` with one row per flat variable and columns
#'     `variable`, `rhat`, `ess_bulk`, and `ess_tail`. A value is `NA` when it
#'     cannot be computed, e.g. for a variable that is constant across draws.
#'   * `chains`: a `data.frame` with one row per chain and columns `chain`,
#'     `num_divergent`, `num_max_treedepth`, and `ebfmi` (all post-warmup). A
#'     column is `NA` when the sampler did not record it (e.g.
#'     `algorithm = "Fixed_param"`); `ebfmi` is also `NA` for chains shorter than
#'     three iterations, non-finite energy, zero energy variance, or numerical
#'     overflow.
#'   * `n_chains`: the number of chains.
#'   * `n_iter`: the number of post-warmup iterations per chain.
#'   * `max_treedepth`: the maximum tree depth setting the fit ran with, or `NA`
#'     when unavailable (e.g. a cmdstanr fixed-parameter fit).
#' @seealso [backend_has_draws()] for the earlier check that a fit produced any
#'   draws at all.
#'
#' @examples
#' \dontrun{
#' diag <- backend_diagnostics(fit, pars = c("beta", "sigma"))
#' max(diag$parameters$rhat, na.rm = TRUE) < 1.01
#' sum(diag$chains$num_divergent) == 0
#' }
#'
#' @export
backend_diagnostics <- function(raw_fit, pars = NULL) {
  if (!requireNamespace("posterior", quietly = TRUE)) {
    stop(
      "computing fit diagnostics needs the 'posterior' package; install it.",
      call. = FALSE
    )
  }
  if (!is.null(pars) && !is.character(pars)) {
    stop(
      "`pars` must be a character vector of parameter names, or NULL for all.",
      call. = FALSE
    )
  }
  assert_backend_available(fit_backend(raw_fit))
  draws <- as_posterior_draws(raw_fit, pars)
  max_treedepth <- fit_max_treedepth(raw_fit)
  sampler <- fit_sampler_array(raw_fit)
  if (is.null(sampler)) {
    sampler <- array(
      numeric(), dim = c(posterior::niterations(draws), posterior::nchains(draws), 0L)
    )
  }
  list(
    parameters = diagnose_parameters(draws),
    chains = diagnose_chains(
      sampler, max_treedepth, reference = fit_sampler_summary(raw_fit, sampler)
    ),
    n_chains = posterior::nchains(draws),
    n_iter = posterior::niterations(draws),
    max_treedepth = max_treedepth
  )
}
