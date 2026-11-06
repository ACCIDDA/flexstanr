test_that("stan_options returns a recognizable list for either backend", {
  local_mocked_bindings(backend_installed = function(backend) TRUE)

  for (backend in c("rstan", "cmdstanr")) {
    opts <- stan_options(backend = backend, chains = 2, seed = "17", refresh = 25)
    expect_s3_class(opts, c("flexstanr_options", "list"), exact = TRUE)
    expect_true(is.list(opts))
    expect_identical(
      unclass(opts),
      list(seed = 17L, refresh = 25, chains = 2L, backend = backend)
    )
    expect_identical(opts[["chains"]], 2L)
    opts$seed <- 18L
    expect_identical(opts$seed, 18L)
  }
})

test_that("automatic threading retains the options class and prints its allocation", {
  local_mocked_bindings(
    backend_installed = function(backend) TRUE,
    detect_cores = function() 8L
  )

  for (backend in c("rstan", "cmdstanr")) {
    opts <- suppressMessages(stan_options(backend = backend, chains = 2, threading = TRUE))
    expect_s3_class(opts, "flexstanr_options")
    expect_true(test_threaded(opts))
    parallel_arg <- if (backend == "rstan") "cores" else "parallel_chains"
    expect_identical(opts[[parallel_arg]], 2L)
    expect_identical(opts$threads_per_chain, 4L)
    expect_identical(capture.output(print(opts)), c(
      paste0("Stan sampler options (", backend, ")"),
      "  chains: 2L",
      paste0("  ", parallel_arg, ": 2L"),
      "  threads_per_chain: 4L"
    ))
  }
})

test_that("printing default options returns them invisibly without checking the backend", {
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  opts <- stan_options()
  before <- opts
  local_mocked_bindings(backend_installed = function(backend) stop("must not check"))

  output <- capture.output(printed <- withVisible(print(opts)))
  expect_identical(output, c("Stan sampler options (rstan)", "  chains: 4L"))
  expect_identical(printed$value, before)
  expect_false(printed$visible)
  expect_identical(opts, before)
})

test_that("printing shows nested and arbitrary options without evaluating them", {
  local_mocked_bindings(backend_installed = function(backend) TRUE)
  opts <- stan_options(
    chains = 2, iter = 500, seed = 17,
    control = list(adapt_delta = 0.9, max_treedepth = 12),
    refresh = 0, algorithm = "NUTS", extra = NULL,
    callback = function() stop("must not run")
  )
  expect_identical(capture.output(print(opts)), c(
    "Stan sampler options (rstan)",
    "  iter: 500L",
    "  seed: 17L",
    "  control: list(adapt_delta = 0.9, max_treedepth = 12)",
    "  refresh: 0",
    "  algorithm: \"NUTS\"",
    "  extra: NULL",
    "  callback: function () ",
    "    stop(\"must not run\")",
    "  chains: 2L"
  ))
  expect_output(print(stan_options(10)), "  \\[\\[1\\]\\]: 10")
})

test_that("classed options still forward the same sampler arguments through fit_model", {
  collect_args <- function(model_name, args, drop_pars, package) {
    do.call(function(...) list(...), args)
  }
  local_mocked_bindings(
    backend_installed = function(backend) TRUE,
    fit_rstan = collect_args,
    fit_cmdstanr = collect_args
  )

  for (backend in c("rstan", "cmdstanr")) {
    opts <- stan_options(backend = backend, chains = 2, seed = 17, refresh = 25)
    before <- opts
    args <- fit_model("model", list(n = 3L), list(), opts, package = "host")
    expect_identical(args, list(
      seed = 17L, refresh = 25, chains = 2L, data = list(n = 3L), init = list()
    ))
    expect_identical(opts, before)
  }
})
