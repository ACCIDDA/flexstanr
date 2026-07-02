# Toolchain-free unit tests for the portable backend script. These source the
# standalone file directly (no package, no rstan/cmdstanr install, no Stan
# toolchain) and exercise the backend-agnostic dispatch, option construction,
# and validation logic. The actual fit / draws / generated-quantities paths need
# a Stan toolchain (and the cmdstanr paths a CmdStan install), so they are
# covered elsewhere; a failed expectation here aborts the script (non-zero exit).

library(testthat)
source(file.path("R", "standalone-backends.R"))

# --- backend vocabulary + option validation ---------------------------------
expect_error(assert_backend_vocab("parallel_chains", "rstan"), "parallel_chains")
expect_error(assert_backend_vocab("cores", "cmdstanr"), "cores")
expect_identical(assert_backend_vocab(c("iter", "cores"), "rstan"), c("iter", "cores"))

expect_identical(assert_positive_int(4, "x"), 4L)
expect_identical(assert_positive_int(c(1, 2, 3), "x"), c(1L, 2L, 3L))
expect_error(assert_positive_int("3", "x"), "numeric")
expect_error(assert_positive_int(0L, "x"), "positive")

expect_identical(backend_int_args("rstan"), c("iter", "chains", "warmup", "cores"))
expect_true("threads_per_chain" %in% backend_int_args("cmdstanr"))

expect_identical(assert_backend_available("rstan"), "rstan")
expect_error(assert_backend_available("nonsense"), "should be one of")

# --- stan_options ------------------------------------------------------------
expect_identical(stan_options()$backend, "rstan")
expect_identical(stan_options()$chains, 4L)
expect_error(stan_options(backend = "nonsense"))
expect_error(stan_options(backend = "rstan", parallel_chains = 4), "parallel_chains")
expect_error(stan_options(object = 1), "object")
expect_error(stan_options(data = 1), "data")
expect_error(stan_options(init = 1), "init")

# --- check_threaded ----------------------------------------------------------
rstan_opts <- stan_options()
withr::with_envvar(c(STAN_NUM_THREADS = NA), expect_false(check_threaded(rstan_opts)))
withr::with_envvar(c(STAN_NUM_THREADS = "4"), expect_true(check_threaded(rstan_opts)))
withr::with_envvar(c(STAN_NUM_THREADS = "-1"), expect_true(check_threaded(rstan_opts)))
expect_false(check_threaded(list(backend = "cmdstanr")))
expect_true(check_threaded(list(backend = "cmdstanr", threads_per_chain = 4L)))

# --- fit-consumption dispatch ------------------------------------------------
expect_identical(fit_backend(structure(list(), class = "stanfit")), "rstan")
expect_identical(fit_backend(structure(list(), class = "CmdStanMCMC")), "cmdstanr")
expect_error(fit_backend(list()), "unrecognized fit object")

# unrecognized objects pass through as "has draws"; cmdstanr stubs error clearly
expect_true(backend_has_draws(list()))
cmd <- structure(list(), class = "CmdStanMCMC")
expect_error(backend_draws_array(cmd), "not yet implemented")
expect_error(backend_extract(cmd, "beta_bs"), "not yet implemented")
expect_error(
  backend_generate_quantities(cmd, list(), matrix(0), "p_obs"),
  "not yet implemented"
)

cat("standalone-backends: all toolchain-free checks passed\n")
