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

test_that("backend_int_args and assert_backend_available validate names", {
  expect_identical(backend_int_args("rstan"), c("iter", "chains", "warmup", "cores"))
  expect_true("threads_per_chain" %in% backend_int_args("cmdstanr"))
  expect_error(assert_backend_available("nonsense"), "should be one of")
  # With the backend installed, a valid name passes through unchanged. Mock the
  # availability seam so this holds regardless of which backends are installed.
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  expect_identical(assert_backend_available("rstan"), "rstan")
  expect_identical(assert_backend_available("cmdstanr"), "cmdstanr")
})

test_that("assert_backend_available errors with an install hint when missing", {
  local_mocked_bindings(backend_installed = function(backend) FALSE)
  expect_error(assert_backend_available("rstan"), "requires the rstan package")
  expect_error(assert_backend_available("rstan"), "install.packages\\('rstan'\\)")
  expect_error(assert_backend_available("rstan"), "use backend = 'cmdstanr'")
  expect_error(assert_backend_available("cmdstanr"), "requires the cmdstanr package")
  expect_error(assert_backend_available("cmdstanr"), "mc-stan.org/cmdstanr")
})

# --- stan_options ------------------------------------------------------------

test_that("stan_options defaults and rejects illegal arguments", {
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  expect_identical(stan_options()$backend, "rstan")
  expect_identical(stan_options()$chains, 4L)
  expect_error(stan_options(backend = "nonsense"))
  expect_error(stan_options(backend = "rstan", parallel_chains = 4), "parallel_chains")
  expect_error(stan_options(object = 1), "object")
  expect_error(stan_options(data = 1), "data")
  expect_error(stan_options(init = 1), "init")
})

test_that("stan_options preserves arbitrary same-backend sampler arguments", {
  local_mocked_bindings(backend_installed = function(backend) TRUE)

  rstan_opts <- stan_options(refresh = 25, algorithm = "NUTS")
  expect_identical(rstan_opts$refresh, 25)
  expect_identical(rstan_opts$algorithm, "NUTS")

  cmdstanr_opts <- stan_options(
    backend = "cmdstanr",
    refresh = 50,
    open_progress = FALSE
  )
  expect_identical(cmdstanr_opts$refresh, 50)
  expect_identical(cmdstanr_opts$open_progress, FALSE)
})

test_that("stan_options surfaces the missing-backend error early", {
  local_mocked_bindings(backend_installed = function(backend) FALSE)
  expect_error(stan_options(), "requires the rstan package")
  expect_error(stan_options(backend = "cmdstanr"), "requires the cmdstanr package")
})

# test_threaded is covered in test-threading.R (it reads threads_per_chain).

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
  local_mocked_bindings(backend_installed = function(backend) TRUE)
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
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  host <- function() {
    fit_model("coverage", dat_stan = list(), init = list(),
              stan_opts = stan_options())
  }
  environment(host) <- globalenv()
  expect_error(host(), "could not determine the host package")
})

test_that("fit_model reports a resolvable-but-modelless package (explicit)", {
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  expect_error(
    fit_model("coverage", dat_stan = list(), init = list(),
              stan_opts = stan_options(), package = "methods"),
    "no 'stanmodels'"
  )
})

# --- attach-time backend detection -------------------------------------------

test_that("missing_backend_message guides the user when no backend is installed", {
  local_mocked_bindings(backend_installed = function(backend) FALSE)
  expect_match(missing_backend_message(), "neither 'rstan' nor 'cmdstanr' is")
})

test_that("missing_backend_message is NULL when a backend is installed", {
  local_mocked_bindings(backend_installed = function(backend) backend == "rstan")
  expect_null(missing_backend_message())
})
