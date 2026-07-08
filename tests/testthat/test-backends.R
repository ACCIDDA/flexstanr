# Toolchain-free unit tests for the portable backend layer. These exercise the
# backend-agnostic dispatch, option construction, validation, and model
# resolution -- none of which need rstan/cmdstanr or a Stan toolchain. The
# actual fit / draws / generated-quantities paths need a Stan install (and the
# cmdstanr paths a CmdStan install), so they are covered by the host packages.

# --- backend vocabulary + option validation ---------------------------------

test_that("assert_backend_vocab rejects the other backend's words", {
  expect_error(assert_backend_vocab("parallel_chains", "rstan"), "parallel_chains")
  expect_error(assert_backend_vocab("cores", "cmdstanr"), "cores")
  expect_identical(
    assert_backend_vocab(c("iter", "cores"), "rstan"),
    c("iter", "cores")
  )
})

test_that("assert_positive_int coerces valid input and rejects invalid", {
  expect_identical(assert_positive_int(4, "x"), 4L)
  expect_identical(assert_positive_int(c(1, 2, 3), "x"), c(1L, 2L, 3L))
  expect_error(assert_positive_int("3", "x"), "numeric")
  expect_error(assert_positive_int(0L, "x"), "positive")
})

test_that("backend_int_args and assert_backend_available behave", {
  expect_identical(backend_int_args("rstan"), c("iter", "chains", "warmup", "cores"))
  expect_true("threads_per_chain" %in% backend_int_args("cmdstanr"))
  expect_identical(assert_backend_available("rstan"), "rstan")
  expect_error(assert_backend_available("nonsense"), "should be one of")
})

# --- stan_options ------------------------------------------------------------

test_that("stan_options defaults and rejects illegal arguments", {
  expect_identical(stan_options()$backend, "rstan")
  expect_identical(stan_options()$chains, 4L)
  expect_error(stan_options(backend = "nonsense"))
  expect_error(stan_options(backend = "rstan", parallel_chains = 4), "parallel_chains")
  expect_error(stan_options(object = 1), "object")
  expect_error(stan_options(data = 1), "data")
  expect_error(stan_options(init = 1), "init")
})

# --- check_threaded ----------------------------------------------------------

test_that("check_threaded reads run-time threading config per backend", {
  skip_if_not_installed("withr")
  rstan_opts <- stan_options()
  withr::with_envvar(c(STAN_NUM_THREADS = NA), expect_false(check_threaded(rstan_opts)))
  withr::with_envvar(c(STAN_NUM_THREADS = "4"), expect_true(check_threaded(rstan_opts)))
  withr::with_envvar(c(STAN_NUM_THREADS = "-1"), expect_true(check_threaded(rstan_opts)))
  expect_false(check_threaded(list(backend = "cmdstanr")))
  expect_true(check_threaded(list(backend = "cmdstanr", threads_per_chain = 4L)))
})

# --- fit-consumption dispatch ------------------------------------------------

test_that("fit_backend identifies the producing backend", {
  expect_identical(fit_backend(structure(list(), class = "stanfit")), "rstan")
  expect_identical(fit_backend(structure(list(), class = "CmdStanMCMC")), "cmdstanr")
  expect_error(fit_backend(list()), "unrecognized fit object")
})

test_that("unrecognized fits pass through backend_has_draws as having draws", {
  expect_true(backend_has_draws(list()))
})

test_that("cmdstanr generate_quantities requires a model_name", {
  cmd <- structure(list(), class = "CmdStanMCMC")
  expect_error(
    backend_generate_quantities(cmd, list(), matrix(0), "p_obs"),
    "needs `model_name`"
  )
})

# --- model resolution (import mode) ------------------------------------------

test_that("caller_package resolves a namespace and rejects the global env", {
  expect_null(caller_package(globalenv()))
  expect_identical(caller_package(asNamespace("methods")), "methods")
})

test_that("get_stanmodel errors clearly when the host has no models", {
  # A base package with no 'stanmodels' object.
  expect_error(get_stanmodel("methods", "coverage"), "no 'stanmodels'")
  # An unknown package (asNamespace() fails) surfaces the same actionable error.
  expect_error(get_stanmodel("no_such_pkg_xyz", "coverage"), "no 'stanmodels'")
})

test_that("fit_model auto-detects the CALLING package, not flexstanr", {
  # Regression: `package = caller_package()` as a default argument resolved to
  # flexstanr itself. Put a host function in the `tools` namespace (a base
  # package with no stanmodels) and call fit_model() with no `package` -- the
  # resolution must land on 'tools' (surfacing tools' missing-stanmodels error),
  # never flexstanr.
  host <- function() {
    fit_model("coverage", dat_stan = list(), init = list(),
              stan_opts = stan_options())
  }
  environment(host) <- asNamespace("tools")
  expect_error(host(), "'tools'")
})

test_that("fit_model errors when the caller has no package (global env)", {
  host <- function() {
    fit_model("coverage", dat_stan = list(), init = list(),
              stan_opts = stan_options())
  }
  environment(host) <- globalenv()
  expect_error(host(), "could not determine the host package")
})

test_that("fit_model reports a resolvable-but-modelless package (explicit)", {
  expect_error(
    fit_model("coverage", dat_stan = list(), init = list(),
              stan_opts = stan_options(), package = "methods"),
    "no 'stanmodels'"
  )
})
