# Tests for automatic thread allocation. The user-facing surface is
# stan_options(threading = TRUE); the allocation helpers (optimal_alloc,
# write_threading, apply_auto_threading, threading_cpp_options) and check_threaded
# are exercised here. All toolchain-free: no rstan/cmdstanr fit is run, and the
# cmdstanr paths use plain list(backend = "cmdstanr") stubs.

# --- optimal_alloc: the core split -------------------------------------------

test_that("optimal_alloc fills chains first, then hands leftovers to threads", {
  expect_equal(optimal_alloc(4, 8),  list(parallel_chains = 4L, threads_per_chain = 2L))
  expect_equal(optimal_alloc(2, 8),  list(parallel_chains = 2L, threads_per_chain = 4L))
  expect_equal(optimal_alloc(4, 16), list(parallel_chains = 4L, threads_per_chain = 4L))
  expect_equal(optimal_alloc(1, 8),  list(parallel_chains = 1L, threads_per_chain = 8L))
})

test_that("optimal_alloc gives one thread when there are no spare cores", {
  expect_equal(optimal_alloc(4, 4), list(parallel_chains = 4L, threads_per_chain = 1L))
  expect_equal(optimal_alloc(8, 4), list(parallel_chains = 4L, threads_per_chain = 1L))
})

test_that("optimal_alloc floors (leaves idle cores) when cores don't divide", {
  expect_equal(optimal_alloc(4, 6),  list(parallel_chains = 4L, threads_per_chain = 1L))
  expect_equal(optimal_alloc(3, 10), list(parallel_chains = 3L, threads_per_chain = 3L))
})

test_that("optimal_alloc returns integer elements", {
  a <- optimal_alloc(4, 8)
  expect_type(a$parallel_chains, "integer")
  expect_type(a$threads_per_chain, "integer")
})

test_that("optimal_alloc validates chains and cores", {
  expect_error(optimal_alloc(0, 8), "positive")
  expect_error(optimal_alloc(2.5, 8), "integer")
  expect_error(optimal_alloc(c(2, 4), 8), "single")
  expect_error(optimal_alloc(4, 0), "positive")
  expect_error(optimal_alloc(4, c(2, 4)), "single")
})

# --- write_threading: per-backend field placement ----------------------------

test_that("write_threading records rstan fields (cores + carried threads)", {
  res <- write_threading(
    list(backend = "rstan", chains = 4L),
    list(parallel_chains = 4L, threads_per_chain = 2L)
  )
  expect_equal(res$cores, 4L)
  expect_equal(res$threads_per_chain, 2L)  # carried; fit_rstan strips + applies it
  expect_null(res$parallel_chains)
})

test_that("write_threading records cmdstanr native fields", {
  res <- write_threading(
    list(backend = "cmdstanr", chains = 4L),
    list(parallel_chains = 4L, threads_per_chain = 2L)
  )
  expect_equal(res$parallel_chains, 4L)
  expect_equal(res$threads_per_chain, 2L)
  expect_null(res$cores)
})

# --- stan_options(threading = ...) integration -------------------------------

test_that("stan_options(threading = TRUE) allocates, records, and messages", {
  skip_if_not_installed("withr")
  # Constrain availableCores() to 2 (as under R CMD check) so the result is
  # deterministic: pool = max(1, 2 - 1) = 1 -> one chain, one thread.
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "TRUE")
  expect_message(
    opts <- stan_options(chains = 4, threading = TRUE),
    "threading enabled"
  )
  expect_equal(opts$cores, 1L)
  expect_equal(opts$threads_per_chain, 1L)
  expect_identical(opts$backend, "rstan")
})

test_that("stan_options(threading = TRUE) caps the pool at max_cores", {
  # max_cores = 1 forces a single-core pool regardless of the test machine.
  suppressMessages(
    opts <- stan_options(chains = 4, threading = TRUE, max_cores = 1)
  )
  expect_equal(opts$cores, 1L)
  expect_equal(opts$threads_per_chain, 1L)
})

test_that("apply_auto_threading splits a multi-core pool (mocked cores)", {
  testthat::local_mocked_bindings(detect_cores = function() 16L)
  # pool = 16 - 1 = 15; optimal_alloc(4, 15) -> 4 chains, 15 %/% 4 = 3 threads
  res <- suppressMessages(apply_auto_threading(list(backend = "rstan", chains = 4L)))
  expect_equal(res$cores, 4L)
  expect_equal(res$threads_per_chain, 3L)
  # cmdstanr, capped: pool = min(16, 8) = 8; optimal_alloc(2, 8) -> 2 chains, 4 threads
  res2 <- suppressMessages(
    apply_auto_threading(list(backend = "cmdstanr", chains = 2L), max_cores = 8)
  )
  expect_equal(res2$parallel_chains, 2L)
  expect_equal(res2$threads_per_chain, 4L)
})

test_that("apply_auto_threading messages the cores actually used, not the pool", {
  testthat::local_mocked_bindings(detect_cores = function() 8L)
  # 8 cores, reserve 1 -> pool 7; optimal_alloc(4, 7) -> 4 chains x 1 thread = 4 used
  expect_message(
    apply_auto_threading(list(backend = "rstan", chains = 4L)),
    "Using 4 of 8"
  )
})

test_that("threading = TRUE rejects a manually-supplied core argument", {
  expect_error(stan_options(cores = 8, threading = TRUE), "automatically")
})

test_that("stan_options(threading = FALSE) leaves parallelism untouched", {
  opts <- stan_options(chains = 4)
  expect_null(opts$cores)
  expect_null(opts$threads_per_chain)
  expect_false(check_threaded(opts))
})

test_that("stan_options validates the threading flag and max_cores", {
  expect_error(stan_options(threading = "yes"), "TRUE or FALSE")
  expect_error(stan_options(threading = NA), "TRUE or FALSE")
  expect_error(stan_options(threading = c(TRUE, FALSE)), "TRUE or FALSE")
  expect_error(stan_options(threading = TRUE, max_cores = 0), "positive")
  expect_error(stan_options(threading = TRUE, max_cores = 2.5), "integer")
  expect_error(stan_options(threading = TRUE, max_cores = c(2, 8)), "single")
})

# --- with_stan_num_threads: the rstan env-var seam ---------------------------

test_that("with_stan_num_threads sets the var during eval and restores it", {
  skip_if_not_installed("withr")
  withr::local_envvar(STAN_NUM_THREADS = "1")
  seen <- with_stan_num_threads(3L, Sys.getenv("STAN_NUM_THREADS"))
  expect_equal(seen, "3")                                   # set during eval
  expect_identical(Sys.getenv("STAN_NUM_THREADS"), "1")     # restored after
})

test_that("with_stan_num_threads restores a previously-unset var", {
  skip_if_not_installed("withr")
  withr::local_envvar(STAN_NUM_THREADS = NA)                # unset in scope
  during <- with_stan_num_threads(4L, Sys.getenv("STAN_NUM_THREADS", unset = "UNSET"))
  expect_equal(during, "4")
  expect_identical(Sys.getenv("STAN_NUM_THREADS", unset = "UNSET"), "UNSET")
})

# --- check_threaded ----------------------------------------------------------

test_that("check_threaded reflects the requested threads_per_chain", {
  expect_true(check_threaded(list(threads_per_chain = 4L)))
  expect_false(check_threaded(list(threads_per_chain = 1L)))
  expect_false(check_threaded(list()))
  expect_false(check_threaded(stan_options(chains = 2)))
})

# --- cmdstanr compile-time threading flag (toolchain-free) -------------------

test_that("threading_cpp_options enables stan_threads only above one thread", {
  expect_equal(threading_cpp_options(2L), list(stan_threads = TRUE))
  expect_equal(threading_cpp_options(4L), list(stan_threads = TRUE))
  expect_null(threading_cpp_options(1L))
  expect_null(threading_cpp_options(NULL))
})
