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
  fit <- structure(list(), class = "stanfit")
  expect_error(backend_diagnostics(fit, pars = 1), "`pars` must be a character vector")
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
})
