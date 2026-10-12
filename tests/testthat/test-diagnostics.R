# Tests for backend_diagnostics() (#40). Toolchain-free: the per-parameter
# summaries run on synthetic posterior draws, and the per-chain sampler
# summaries run on a synthetic iterations x chains x variables array of sampler
# parameters -- the shape both backends are normalized to before any number is
# computed. Where cmdstanr is installed, its own E-BFMI / divergence / treedepth
# helpers (which take plain posterior draws, no CmdStan needed) serve as the
# reference, so parity is checked rather than re-derived.

# Synthetic post-warmup sampler parameters: `iter` iterations x `chains` chains,
# with the columns both rstan and cmdstanr report for NUTS.
fake_sampler_array <- function(iter = 20L, chains = 3L, seed = 1L) {
  withr::local_seed(seed)
  vars <- c(
    "accept_stat__", "stepsize__", "treedepth__",
    "n_leapfrog__", "divergent__", "energy__"
  )
  a <- array(
    0,
    dim = c(iter, chains, length(vars)),
    dimnames = list(iteration = NULL, chain = NULL, variable = vars)
  )
  a[, , "accept_stat__"] <- stats::runif(iter * chains)
  a[, , "stepsize__"] <- 0.5
  a[, , "treedepth__"] <- sample(1:10, iter * chains, replace = TRUE)
  a[, , "n_leapfrog__"] <- 2^a[, , "treedepth__"] - 1
  a[, , "divergent__"] <- stats::rbinom(iter * chains, 1L, 0.1)
  a[, , "energy__"] <- stats::rnorm(iter * chains, 10, 2)
  a
}

# --- per-parameter convergence ------------------------------------------------

test_that("diagnose_parameters reports rhat and bulk/tail ESS per variable", {
  skip_if_not_installed("posterior")
  d <- posterior::example_draws()
  out <- diagnose_parameters(d)

  expect_s3_class(out, "data.frame")
  expect_false(inherits(out, "tbl_df"))
  expect_named(out, c("variable", "rhat", "ess_bulk", "ess_tail"))
  expect_identical(out$variable, posterior::variables(d))
  # values are posterior's own, not a reimplementation
  mu <- posterior::extract_variable_matrix(d, "mu")
  expect_equal(out$rhat[out$variable == "mu"], posterior::rhat(mu))
  expect_equal(out$ess_bulk[out$variable == "mu"], posterior::ess_bulk(mu))
  expect_equal(out$ess_tail[out$variable == "mu"], posterior::ess_tail(mu))
})

test_that("diagnose_parameters reports capped ESS without warnings", {
  skip_if_not_installed("posterior")
  # Strongly antithetic draws make posterior cap its ESS estimate and warn.
  withr::local_seed(123)
  d <- posterior::as_draws_array(array(
    replicate(4L, as.numeric(stats::arima.sim(list(ar = -0.9), 100L))),
    dim = c(100L, 4L, 1L),
    dimnames = list(NULL, NULL, "theta")
  ))
  expected <- suppressWarnings(posterior::summarise_draws(
    d, rhat = posterior::rhat,
    ess_bulk = posterior::ess_bulk, ess_tail = posterior::ess_tail
  ))
  expect_silent(out <- diagnose_parameters(d))
  for (column in names(out)) expect_equal(out[[column]], expected[[column]])
})

# --- per-chain sampler diagnostics --------------------------------------------

test_that("diagnose_chains counts divergences and treedepth hits per chain", {
  a <- fake_sampler_array()
  max_td <- 8L
  out <- diagnose_chains(a, max_treedepth = max_td)

  expect_s3_class(out, "data.frame")
  expect_named(out, c("chain", "num_divergent", "num_max_treedepth", "ebfmi"))
  expect_identical(out$chain, seq_len(dim(a)[2L]))
  expect_identical(out$num_divergent, as.integer(colSums(a[, , "divergent__"])))
  # a transition at the cap counts as a hit, as in rstan and cmdstanr
  expect_identical(
    out$num_max_treedepth,
    as.integer(colSums(a[, , "treedepth__"] >= max_td))
  )
})

test_that("diagnose_chains matches cmdstanr's own divergence, treedepth, E-BFMI", {
  skip_if_not_installed("posterior")
  skip_if_not_installed("cmdstanr")
  a <- fake_sampler_array()
  max_td <- 8L
  d <- posterior::as_draws_array(a)
  out <- diagnose_chains(a, max_treedepth = max_td)

  expect_equal(
    out$num_divergent,
    suppressMessages(cmdstanr:::check_divergences(d))
  )
  expect_equal(
    out$num_max_treedepth,
    suppressMessages(
      cmdstanr:::check_max_treedepth(d, list(max_treedepth = max_td))
    )
  )
  expect_equal(out$ebfmi, unname(cmdstanr:::ebfmi(d)))
})

test_that("diagnose_chains gives NA E-BFMI when it is undefined", {
  # fewer than three post-warmup iterations
  expect_true(all(is.na(diagnose_chains(fake_sampler_array(iter = 2L), 10L)$ebfmi)))
  # energy missing
  a <- fake_sampler_array()
  a[1L, 1L, "energy__"] <- NA
  expect_true(is.na(diagnose_chains(a, 10L)$ebfmi[1L]))
  expect_false(anyNA(diagnose_chains(a, 10L)$ebfmi[-1L]))
})

test_that("chain_ebfmi gives NA for constant or non-finite energy", {
  for (energy in list(
    rep(5, 4L), c(1, 2, NA_real_), c(1, 2, NaN),
    c(1, 2, Inf), c(1, 2, -Inf), c(-1e308, 0, 1e308),
    c(0, 1e154, 0, 1e154)
  )) {
    expect_identical(chain_ebfmi(energy), NA_real_)
  }
  # Match the backends' sum / N numerator, not mean(diff(energy)^2).
  expect_equal(chain_ebfmi(c(1, 2, 3)), 2 / 3)
})

test_that("diagnose_chains reports NA for a column the sampler did not write", {
  # e.g. algorithm = "Fixed_param", which writes no NUTS sampler columns
  a <- fake_sampler_array()
  fixed <- a[, , "accept_stat__", drop = FALSE]
  out <- diagnose_chains(fixed, 10L)
  expect_identical(out$chain, seq_len(dim(a)[2L]))
  expect_true(all(is.na(out$num_divergent)))
  expect_true(all(is.na(out$num_max_treedepth)))
  expect_true(all(is.na(out$ebfmi)))
})

# --- rstan normalization ------------------------------------------------------

test_that("rstan_sampler_array stacks get_sampler_params() output by chain", {
  a <- fake_sampler_array()
  # rstan::get_sampler_params() returns one iterations x variables matrix per chain
  sp <- lapply(seq_len(dim(a)[2L]), function(k) a[, k, ])
  out <- rstan_sampler_array(sp)
  expect_identical(dim(out), dim(a))
  expect_identical(dimnames(out)$variable, dimnames(a)$variable)
  expect_equal(unname(out), unname(a))
})

test_that("rstan_sampler_array preserves singleton and empty dimensions", {
  for (n_iter in c(1L, 2L, 0L)) {
    for (n_vars in c(1L, 2L, 0L)) {
      for (n_chains in c(1L, 2L)) {
        vars <- c("accept_stat__", "energy__")[seq_len(n_vars)]
        sp <- lapply(seq_len(n_chains), function(k) {
          matrix(
            seq_len(n_iter * n_vars) + k,
            nrow = n_iter, ncol = n_vars,
            dimnames = list(NULL, vars)
          )
        })
        out <- rstan_sampler_array(sp)
        expect_identical(dim(out), c(n_iter, n_chains, n_vars))
        expect_equal(dimnames(out)[[3L]], colnames(sp[[1L]]))
        for (k in seq_len(n_chains)) {
          expect_equal(as.numeric(out[, k, , drop = FALSE]), as.numeric(sp[[k]]))
        }
      }
    }
  }
})

test_that("rstan_max_treedepth reads control$max_treedepth, defaulting to 10", {
  expect_identical(rstan_max_treedepth(list(control = list(max_treedepth = 12L))), 12L)
  expect_identical(rstan_max_treedepth(list(control = list(adapt_delta = 0.9))), 10L)
  expect_identical(rstan_max_treedepth(list()), 10L)
})

# --- backend_diagnostics() ----------------------------------------------------

local_diagnostics_fit <- function(sampler, max_treedepth = 10L, env = parent.frame()) {
  testthat::local_mocked_bindings(
    fit_backend = function(raw_fit) "rstan",
    backend_installed = function(backend) TRUE,
    fit_sampler_array = function(raw_fit) sampler,
    fit_sampler_summary = function(raw_fit, sampler) list(),
    fit_max_treedepth = function(raw_fit) max_treedepth,
    .env = env
  )
}

test_that("backend_diagnostics assembles parameters, chains, and run metadata", {
  skip_if_not_installed("posterior")
  a <- fake_sampler_array(iter = 10L, chains = 2L)
  local_diagnostics_fit(a, max_treedepth = 9L)
  # stand-in for as.array(stanfit), as in test-extract.R
  fit <- array(
    stats::rnorm(10L * 2L * 3L),
    dim = c(10L, 2L, 3L),
    dimnames = list(NULL, NULL, c("mu", "theta[1]", "theta[2]"))
  )

  out <- backend_diagnostics(fit)
  expect_named(out, c("parameters", "chains", "n_chains", "n_iter", "max_treedepth"))
  expect_identical(out$parameters$variable, c("mu", "theta[1]", "theta[2]"))
  expect_identical(nrow(out$chains), 2L)
  expect_identical(out$n_chains, 2L)
  expect_identical(out$n_iter, 10L)
  expect_identical(out$max_treedepth, 9L)
})

test_that("backend_diagnostics restricts parameters to `pars` by base name", {
  skip_if_not_installed("posterior")
  local_diagnostics_fit(fake_sampler_array(iter = 10L, chains = 2L))
  fit <- array(
    stats::rnorm(10L * 2L * 3L),
    dim = c(10L, 2L, 3L),
    dimnames = list(NULL, NULL, c("mu", "theta[1]", "theta[2]"))
  )
  out <- backend_diagnostics(fit, pars = "theta")
  expect_identical(out$parameters$variable, c("theta[1]", "theta[2]"))
  # sampler diagnostics are per chain, so `pars` does not touch them
  expect_identical(nrow(out$chains), 2L)
  expect_error(backend_diagnostics(fit, pars = "sigma"), "'sigma'")
})

test_that("backend_diagnostics rejects a non-character pars", {
  skip_if_not_installed("posterior")
  fit <- structure(list(), class = "stanfit")
  expect_error(backend_diagnostics(fit, pars = 1), "`pars` must be a character vector")
})

test_that("backend_diagnostics checks posterior before pars or the fit", {
  diagnostics <- backend_diagnostics
  environment(diagnostics) <- list2env(list(
    requireNamespace = function(package, quietly) {
      expect_identical(package, "posterior")
      expect_true(quietly)
      FALSE
    }
  ), parent = environment(backend_diagnostics))
  expect_error(diagnostics(NULL, pars = 1), "needs the 'posterior' package")
})

test_that("cmdstanr availability is checked before touching fit methods", {
  local_mocked_bindings(backend_installed = function(backend) FALSE)
  fit <- structure(list(
    metadata = function() stop("metadata must not be read"),
    draws = function(...) stop("draws must not be read")
  ), class = "CmdStanMCMC")
  expect_error(fit_sampler_array(fit), "requires the cmdstanr package")
  skip_if_not_installed("posterior")
  expect_error(backend_diagnostics(fit), "requires the cmdstanr package")
})

test_that("diagnose_chains preserves available reference values and count types", {
  a <- fake_sampler_array()
  reference <- list(
    num_divergent = c(4, 5, 6), num_max_treedepth = c(7, 8, 9),
    ebfmi = c(0.4, 0.5, 0.6)
  )
  out <- diagnose_chains(a, 8L, reference = reference)
  expect_identical(out$num_divergent, c(4L, 5L, 6L))
  expect_identical(out$num_max_treedepth, c(7L, 8L, 9L))
  expect_identical(out$ebfmi, reference$ebfmi)

  # A backend's scalar undefined result must not erase another valid chain.
  a[1L, 1L, "energy__"] <- NA_real_
  expect_silent(out <- diagnose_chains(a, 8L, reference = list(ebfmi = NA)))
  expect_identical(out$ebfmi[1L], NA_real_)
  expect_equal(out$ebfmi[-1L], diagnose_chains(a, 8L)$ebfmi[-1L])
})

test_that("cmdstanr public summaries are requested quietly and passed through", {
  a <- fake_sampler_array()
  calls <- 0L
  reference <- list(
    num_divergent = c(4, 5, 6), num_max_treedepth = c(7, 8, 9),
    ebfmi = c(0.4, 0.5, 0.6)
  )
  fit <- structure(list(diagnostic_summary = function(diagnostics, quiet) {
    calls <<- calls + 1L
    expect_identical(diagnostics, c("divergences", "treedepth", "ebfmi"))
    expect_true(quiet)
    warning("backend warning must remain silent")
    reference
  }), class = "CmdStanMCMC")
  expect_silent(summary <- fit_sampler_summary(fit, a))
  expect_identical(calls, 1L)
  expect_identical(summary, reference)
  expect_identical(diagnose_chains(a, 8L, summary)$ebfmi, reference$ebfmi)
})

test_that("cmdstanr summary selection handles absent and undefined diagnostics", {
  a <- fake_sampler_array(iter = 4L, chains = 2L)
  fit <- structure(list(diagnostic_summary = function(diagnostics, quiet) {
    expect_identical(diagnostics, c("divergences", "treedepth"))
    expect_true(quiet)
    list(num_divergent = c(0, 1), num_max_treedepth = c(1L, 2L))
  }), class = "CmdStanMCMC")
  for (energy in list(
    rep(5, 4L), c(1, 2, 3, NA_real_), c(1, 2, 3, NaN),
    c(1, 2, 3, Inf), c(-1e308, 0, 1e308, 0)
  )) {
    a[, 1L, "energy__"] <- energy
    expect_silent(reference <- fit_sampler_summary(fit, a))
    expect_silent(out <- diagnose_chains(a, 8L, reference))
    expect_identical(out$ebfmi[1L], NA_real_)
    expect_equal(out$ebfmi[2L], chain_ebfmi(a[, 2L, "energy__"]))
  }
  expect_silent(reference <- fit_sampler_summary(fit, a[1L, , , drop = FALSE]))
  expect_true(all(is.na(diagnose_chains(a[1L, , , drop = FALSE], 8L, reference)$ebfmi)))

  fit$diagnostic_summary <- function(diagnostics, quiet) {
    expect_identical(diagnostics, "divergences")
    list(num_divergent = c(0, 1))
  }
  partial <- a[, , "divergent__", drop = FALSE]
  out <- diagnose_chains(partial, 8L, fit_sampler_summary(fit, partial))
  expect_identical(out$num_divergent, c(0L, 1L))
  expect_true(all(is.na(out$num_max_treedepth)))
  expect_true(all(is.na(out$ebfmi)))

  fit$diagnostic_summary <- function(...) stop("summary must not be read")
  expect_identical(fit_sampler_summary(fit, a[, , "accept_stat__", drop = FALSE]), list())
})

test_that("old cmdstanr fits receive an actionable summary upgrade error", {
  fit <- structure(list(), class = "CmdStanMCMC")
  expect_error(fit_sampler_summary(fit, fake_sampler_array()), "cmdstanr >= 0.5.0")
})

# Exercise the public CmdStanMCMC accessors, including their global-format
# default and the fixed_param error, without compiling a Stan model.
fake_cmdstan_diagnostics_fit <- function(draws, sampler, fixed_param = FALSE) {
  convert <- function(x, format) {
    switch(format,
      draws_array = posterior::as_draws_array(x),
      draws_df = posterior::as_draws_df(x),
      draws_matrix = posterior::as_draws_matrix(x),
      draws_list = posterior::as_draws_list(x)
    )
  }
  structure(list(
    draws = function(format = getOption("cmdstanr_draws_format", "draws_array")) {
      convert(draws, format)
    },
    sampler_diagnostics = function(
      inc_warmup = FALSE,
      format = getOption("cmdstanr_draws_format", "draws_array")
    ) {
      expect_false(inc_warmup)
      if (fixed_param) stop("There are no sampler diagnostics when fixed_param = TRUE.")
      convert(sampler, format)
    },
    diagnostic_summary = function(diagnostics, quiet) {
      expect_true(quiet)
      if (fixed_param) stop("Fixed-parameter fits have no sampler summary.")
      out <- diagnose_chains(sampler, max_treedepth = 8L)
      columns <- c(
        divergences = "num_divergent", treedepth = "num_max_treedepth", ebfmi = "ebfmi"
      )
      as.list(out[unname(columns[diagnostics])])
    },
    metadata = function() {
      if (fixed_param) list(algorithm = "fixed_param") else list(max_treedepth = 8L)
    }
  ), class = "CmdStanMCMC")
}

test_that("backend_diagnostics handles cmdstanr fixed_param fits", {
  skip_if_not_installed("posterior")
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  for (n_iter in c(1L, 20L)) {
    for (n_chains in c(1L, 2L)) {
      draws <- posterior::as_draws_array(array(
        seq_len(n_iter * n_chains), dim = c(n_iter, n_chains, 1L),
        dimnames = list(NULL, NULL, "theta")
      ))
      fit <- fake_cmdstan_diagnostics_fit(draws, NULL, fixed_param = TRUE)
      expect_silent(out <- backend_diagnostics(fit, pars = "theta"))
      expect_identical(out$n_iter, n_iter)
      expect_identical(out$n_chains, n_chains)
      expect_identical(out$max_treedepth, NA_integer_)
      expect_identical(out$parameters$variable, "theta")
      expect_identical(out$chains$chain, seq_len(n_chains))
      expect_identical(out$chains$num_divergent, rep(NA_integer_, n_chains))
      expect_identical(out$chains$num_max_treedepth, rep(NA_integer_, n_chains))
      expect_identical(out$chains$ebfmi, rep(NA_real_, n_chains))
    }
  }
})

test_that("cmdstanr diagnostics are independent of the global draws format", {
  skip_if_not_installed("posterior")
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  draws <- posterior::example_draws()
  sampler <- fake_sampler_array(
    iter = posterior::niterations(draws), chains = posterior::nchains(draws)
  )
  fit <- fake_cmdstan_diagnostics_fit(draws, sampler)
  withr::local_options(cmdstanr_draws_format = "draws_array")
  expected <- backend_diagnostics(fit)
  for (format in c("draws_df", "draws_matrix", "draws_list")) {
    withr::local_options(cmdstanr_draws_format = format)
    expect_silent(out <- backend_diagnostics(fit))
    expect_equal(out, expected)
  }
})

test_that("cmdstanr sampler errors are not mistaken for fixed_param fits", {
  skip_if_not_installed("posterior")
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  fit <- fake_cmdstan_diagnostics_fit(posterior::example_draws(), NULL)
  fit$sampler_diagnostics <- function(...) stop("sampler output unavailable")
  expect_error(backend_diagnostics(fit), "sampler output unavailable")
})

# --- live rstan parity ----------------------------------------------------------

# --- rstan branch, without a toolchain -----------------------------------------

test_that("fit_sampler_array reads post-warmup sampler params from an rstan fit", {
  skip_if_not_installed("rstan")
  a <- fake_sampler_array()
  sp <- lapply(seq_len(dim(a)[2L]), function(k) a[, k, ])
  local_mocked_bindings(
    get_sampler_params = function(object, inc_warmup) {
      expect_false(inc_warmup)
      sp
    },
    .package = "rstan"
  )
  fit <- methods::new("stanfit")
  expect_equal(unname(fit_sampler_array(fit)), unname(a))
})

test_that("fit_max_treedepth reads an rstan fit's stan_args", {
  skip_if_not_installed("rstan")
  fit <- methods::new(
    "stanfit",
    stan_args = list(list(control = list(max_treedepth = 12L)))
  )
  expect_identical(fit_max_treedepth(fit), 12L)
})

test_that("backend_diagnostics agrees with rstan's own reports on a live fit", {
  skip_on_cran() # compiles a Stan model
  skip_if_not_installed("rstan")
  skip_if_not_installed("posterior")
  # compiling needs rstan's LinkingTo headers, which a binary rstan install does
  # not pull in (CI runners have rstan without them)
  for (pkg in c("BH", "StanHeaders", "RcppEigen", "RcppParallel")) {
    skip_if_not_installed(pkg)
  }
  # Neal's funnel with a low treedepth cap, so the fit has divergences and
  # treedepth hits to count rather than agreeing trivially on zeros.
  model <- rstan::stan_model(model_code = "
    parameters { real y; vector[2] x; }
    model { y ~ normal(0, 3); x ~ normal(0, exp(y / 2)); }
  ")
  max_td <- 3L
  fit <- suppressWarnings(rstan::sampling(
    model,
    chains = 2L, iter = 400L, seed = 1L, refresh = 0L,
    control = list(max_treedepth = max_td)
  ))

  out <- backend_diagnostics(fit)
  expect_identical(out$max_treedepth, max_td)
  expect_identical(out$n_chains, 2L)
  expect_identical(out$n_iter, 200L)
  expect_identical(sum(out$chains$num_divergent), rstan::get_num_divergent(fit))
  expect_gt(sum(out$chains$num_divergent), 0L)
  expect_identical(sum(out$chains$num_max_treedepth), rstan::get_num_max_treedepth(fit))
  expect_gt(sum(out$chains$num_max_treedepth), 0L)
  expect_equal(out$chains$ebfmi, unname(rstan::get_bfmi(fit)))
  # R-hat is posterior's on both backends (cmdstanr's $summary() uses it too),
  # so it matches posterior exactly; rstan::Rhat() implements the same
  # rank-normalized statistic separately and agrees only to numerical noise.
  y <- as.array(fit)[, , "y"]
  rhat_y <- out$parameters$rhat[out$parameters$variable == "y"]
  expect_equal(rhat_y, posterior::rhat(y))
  expect_equal(rhat_y, rstan::Rhat(y), tolerance = 1e-3)

  # Fixed_param writes just accept_stat__; a single retained draw must still
  # survive normalization as an iterations x chains x variables array.
  fixed <- rstan::sampling(
    model, algorithm = "Fixed_param", chains = 1L, iter = 1L, warmup = 0L,
    seed = 1L, refresh = 0L
  )
  expect_silent(fixed_out <- backend_diagnostics(fixed))
  expect_identical(fixed_out$n_iter, 1L)
  expect_identical(fixed_out$n_chains, 1L)
  expect_identical(fixed_out$chains$num_divergent, NA_integer_)
  expect_identical(fixed_out$chains$num_max_treedepth, NA_integer_)
  expect_identical(fixed_out$chains$ebfmi, NA_real_)
})
