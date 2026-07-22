# Tests for the scheduler-aware thread-allocation helpers (optimal_alloc,
# configure_threading). Backend-agnostic and toolchain-free: no rstan/cmdstanr
# fit is run. The cmdstanr branch of configure_threading is exercised with a
# plain list(backend = "cmdstanr") stub, so it does not need cmdstanr installed.

# --- optimal_alloc: the core split -------------------------------------------

test_that("optimal_alloc fills chains first, then hands leftovers to threads", {
  expect_equal(optimal_alloc(4, cores = 8),
               list(parallel_chains = 4L, threads_per_chain = 2L))
  expect_equal(optimal_alloc(2, cores = 8),
               list(parallel_chains = 2L, threads_per_chain = 4L))
  expect_equal(optimal_alloc(4, cores = 16),
               list(parallel_chains = 4L, threads_per_chain = 4L))
  expect_equal(optimal_alloc(1, cores = 8),
               list(parallel_chains = 1L, threads_per_chain = 8L))
})

test_that("optimal_alloc gives one thread when there are no spare cores", {
  expect_equal(optimal_alloc(4, cores = 4),
               list(parallel_chains = 4L, threads_per_chain = 1L))
  # more chains than cores: chains queue, still no threading
  expect_equal(optimal_alloc(8, cores = 4),
               list(parallel_chains = 4L, threads_per_chain = 1L))
})

test_that("optimal_alloc floors (leaves idle cores) when cores don't divide", {
  expect_equal(optimal_alloc(4, cores = 6),
               list(parallel_chains = 4L, threads_per_chain = 1L))
  expect_equal(optimal_alloc(3, cores = 10),
               list(parallel_chains = 3L, threads_per_chain = 3L))
})

test_that("explicit cores are used as given, bypassing availableCores()", {
  skip_if_not_installed("withr")
  # explicit cores skip parallelly entirely -- deterministic regardless of the
  # machine, the scheduler, or R CMD check.
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "TRUE")
  expect_equal(optimal_alloc(4, cores = 8),
               list(parallel_chains = 4L, threads_per_chain = 2L))
})

test_that("auto-detected cores respect availableCores() under R CMD check", {
  skip_if_not_installed("withr")
  # parallelly::availableCores() returns 2 when _R_CHECK_LIMIT_CORES_ is set.
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "TRUE")
  expect_equal(optimal_alloc(4),
               list(parallel_chains = 2L, threads_per_chain = 1L))
})

test_that("auto-detected cores respect a constraining mc.cores", {
  skip_if_not_installed("withr")
  # availableCores() takes the minimum across sources, so mc.cores = 1 is a hard
  # floor independent of the test machine's core count.
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "")
  withr::local_options(mc.cores = 1)
  expect_equal(optimal_alloc(4),
               list(parallel_chains = 1L, threads_per_chain = 1L))
})

test_that("the auto-detect path returns a valid allocation", {
  alloc <- optimal_alloc(4)
  expect_named(alloc, c("parallel_chains", "threads_per_chain"))
  # the documented contract is integer elements (expect_equal ignores int/double)
  expect_type(alloc$parallel_chains, "integer")
  expect_type(alloc$threads_per_chain, "integer")
  expect_true(alloc$parallel_chains >= 1L && alloc$parallel_chains <= 4L)
  expect_true(alloc$threads_per_chain >= 1L)
})

test_that("optimal_alloc validates chains", {
  expect_error(optimal_alloc(0, cores = 8), "positive")
  expect_error(optimal_alloc(-1, cores = 8), "positive")
  expect_error(optimal_alloc(2.5, cores = 8), "integer")
  expect_error(optimal_alloc(c(2, 4), cores = 8), "single")
})

test_that("optimal_alloc validates cores", {
  expect_error(optimal_alloc(4, cores = 0), "positive")
  expect_error(optimal_alloc(4, cores = 2.5), "integer")
  expect_error(optimal_alloc(4, cores = c(2, 4)), "single")
})

# --- configure_threading: rstan branch ---------------------------------------

test_that("configure_threading (rstan) sets cores and STAN_NUM_THREADS", {
  skip_if_not_installed("withr")
  withr::local_envvar(STAN_NUM_THREADS = "")
  opts <- configure_threading(
    stan_options(chains = 4),
    list(parallel_chains = 4L, threads_per_chain = 2L)
  )
  expect_equal(opts$cores, 4L)
  expect_equal(Sys.getenv("STAN_NUM_THREADS"), "2")
  expect_identical(opts$backend, "rstan")
})

test_that("configure_threading (rstan) exports one thread when threading is off", {
  skip_if_not_installed("withr")
  withr::local_envvar(STAN_NUM_THREADS = "")
  opts <- configure_threading(
    stan_options(chains = 4),
    list(parallel_chains = 4L, threads_per_chain = 1L)
  )
  expect_equal(opts$cores, 4L)
  expect_equal(Sys.getenv("STAN_NUM_THREADS"), "1")
})

# --- configure_threading: cmdstanr branch (stub, no cmdstanr needed) ---------

test_that("configure_threading (cmdstanr) sets native args and no env var", {
  skip_if_not_installed("withr")
  withr::local_envvar(STAN_NUM_THREADS = "")
  # A plain stub avoids stan_options(backend = "cmdstanr"), which needs cmdstanr
  # installed; configure_threading only switches on $backend.
  opts <- configure_threading(
    list(backend = "cmdstanr", chains = 4L),
    list(parallel_chains = 4L, threads_per_chain = 2L)
  )
  expect_equal(opts$parallel_chains, 4L)
  expect_equal(opts$threads_per_chain, 2L)
  # cmdstanr passes threads as call arguments, so no environment variable is set.
  expect_identical(Sys.getenv("STAN_NUM_THREADS"), "")
  expect_null(opts$cores)
})

test_that("configure_threading rejects an unknown or missing backend", {
  alloc <- list(parallel_chains = 2L, threads_per_chain = 1L)
  expect_error(configure_threading(list(backend = "nope"), alloc), "rstan")
  expect_error(configure_threading(list(backend = NULL), alloc), "rstan")
})

test_that("configure_threading validates the allocation", {
  expect_error(
    configure_threading(
      stan_options(chains = 2),
      list(parallel_chains = 0L, threads_per_chain = 1L)
    ),
    "positive"
  )
  expect_error(
    configure_threading(
      stan_options(chains = 2),
      list(parallel_chains = 2L, threads_per_chain = 2.5)
    ),
    "integer"
  )
})

# --- cmdstanr compile-time threading flag (toolchain-free) -------------------

test_that("threading_cpp_options enables stan_threads only above one thread", {
  expect_equal(threading_cpp_options(2L), list(stan_threads = TRUE))
  expect_equal(threading_cpp_options(4L), list(stan_threads = TRUE))
  expect_null(threading_cpp_options(1L))
  expect_null(threading_cpp_options(NULL))
})

# --- check_threaded reflects a configured allocation -------------------------

test_that("check_threaded sees the allocation configure_threading writes", {
  skip_if_not_installed("withr")
  withr::local_envvar(STAN_NUM_THREADS = "")
  rstan_opts <- configure_threading(
    stan_options(chains = 4),
    list(parallel_chains = 4L, threads_per_chain = 3L)
  )
  expect_true(check_threaded(rstan_opts))

  cmdstanr_opts <- configure_threading(
    list(backend = "cmdstanr", chains = 4L),
    list(parallel_chains = 4L, threads_per_chain = 3L)
  )
  expect_true(check_threaded(cmdstanr_opts))
})
