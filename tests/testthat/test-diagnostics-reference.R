# Exercise the public backend reports without compiling or sampling a model.
# CmdStanMCMC objects are read from tiny synthetic CSV files. RStan's sampler
# accessor supplies the same fixture to its real exported diagnostic helpers.

reference_sampler_params <- function(chains = 2L, iter = 6L) {
  divergent <- list(c(0, 1, 0, 0, 1, 0), c(1, 0, 0, 0, 0, 0))
  treedepth <- list(c(2, 3, 4, 1, 3, 2), c(1, 1, 2, 2, 2, 3))
  energy <- list(c(1, 2, 3, 4, 2, 1), c(2, 1, 3, 2, 5, 4))
  lapply(seq_len(chains), function(k) {
    cbind(
      accept_stat__ = rep(0.9, iter),
      stepsize__ = rep(1, iter),
      treedepth__ = treedepth[[k]][seq_len(iter)],
      n_leapfrog__ = 2^treedepth[[k]][seq_len(iter)] - 1,
      divergent__ = divergent[[k]][seq_len(iter)],
      energy__ = energy[[k]][seq_len(iter)]
    )
  })
}

local_reference_cmdstan_fit <- function(sp, env = parent.frame()) {
  files <- vapply(seq_along(sp), function(k) {
    # Newer cmdstanr versions read lazily; keep each file for the whole test.
    file <- withr::local_tempfile(fileext = ".csv", .local_envir = env)
    writeLines(c(
      "# stan_version_major = 2", "# stan_version_minor = 21",
      "# stan_version_patch = 0", "# model = diagnostics_fixture",
      "# method = sample", paste0("# num_samples = ", nrow(sp[[k]])),
      "# num_warmup = 0", "# save_warmup = 0", "# thin = 1",
      paste0("# id = ", k), "# seed = 123", "# init = 2",
      "# algorithm = hmc", "# engine = nuts", "# max_depth = 3",
      "# metric = diag_e", "# stepsize = 1", "# engaged = 0",
      paste(c("lp__", colnames(sp[[k]]), "theta"), collapse = ",")
    ), file)
    rows <- cbind(
      lp__ = -seq_len(nrow(sp[[k]])), sp[[k]],
      theta = seq_len(nrow(sp[[k]])) / 10 + k
    )
    utils::write.table(
      rows, file, sep = ",", row.names = FALSE, col.names = FALSE,
      append = TRUE, quote = FALSE
    )
    file
  }, character(1L))
  cmdstanr::as_cmdstan_fit(
    files, check_diagnostics = FALSE, format = "draws_array"
  )
}

test_that("CSV CmdStanMCMC diagnostics match the public reference per chain", {
  skip_if_not_installed("cmdstanr", "0.5.0")
  skip_if_not_installed("posterior")
  for (chains in c(1L, 2L)) {
    fit <- local_reference_cmdstan_fit(reference_sampler_params(chains))
    expect_true(inherits(fit, "CmdStanMCMC"))
    expect_silent(reference <- fit$diagnostic_summary(quiet = TRUE))
    sampler <- fit_sampler_array(fit)
    expect_silent(summary <- fit_sampler_summary(fit, sampler))
    expect_equal(summary, reference)

    expect_silent(out <- backend_diagnostics(fit, pars = "theta"))
    expect_identical(out$n_chains, chains)
    expect_identical(out$n_iter, 6L)
    expect_identical(out$max_treedepth, 3L)
    expect_identical(out$parameters$variable, "theta")
    expect_identical(out$chains$chain, seq_len(chains))
    expect_identical(out$chains$num_divergent, c(2L, 1L)[seq_len(chains)])
    # Both the at-cap and deliberately over-cap rows must count as hits.
    expect_identical(out$chains$num_max_treedepth, c(3L, 1L)[seq_len(chains)])
    expect_equal(out$chains$num_divergent, reference$num_divergent)
    expect_equal(out$chains$num_max_treedepth, reference$num_max_treedepth)
    expect_equal(out$chains$ebfmi, unname(reference$ebfmi))

    withr::local_options(cmdstanr_draws_format = "draws_df")
    expect_silent(other_format <- backend_diagnostics(fit, pars = "theta"))
    expect_equal(other_format, out)
  }
})

test_that("CSV CmdStanMCMC short chains keep counts and undefined E-BFMI", {
  skip_if_not_installed("cmdstanr", "0.5.0")
  skip_if_not_installed("posterior")
  for (iter in c(1L, 2L)) {
    for (chains in c(1L, 2L)) {
      fit <- local_reference_cmdstan_fit(reference_sampler_params(chains, iter))
      reference <- fit$diagnostic_summary(
        diagnostics = c("divergences", "treedepth"), quiet = TRUE
      )
      expect_silent(summary <- fit_sampler_summary(fit, fit_sampler_array(fit)))
      expect_equal(summary, reference)
      expect_silent(out <- backend_diagnostics(fit, pars = "theta"))
      expect_identical(out$n_chains, chains)
      expect_identical(out$n_iter, iter)
      expect_identical(out$chains$chain, seq_len(chains))
      expect_equal(out$chains$num_divergent, reference$num_divergent)
      expect_equal(out$chains$num_max_treedepth, reference$num_max_treedepth)
      expect_identical(out$chains$ebfmi, rep(NA_real_, chains))
    }
  }
})

test_that("rstan sampler adapters match exported diagnostics without sampling", {
  skip_if_not_installed("rstan", "2.18.1")
  skip_if_not_installed("posterior")
  sp <- reference_sampler_params()
  fit <- methods::new(
    "stanfit", stan_args = list(list(control = list(max_treedepth = 3L)))
  )
  local_mocked_bindings(
    get_sampler_params = function(object, inc_warmup) {
      expect_identical(object, fit)
      expect_false(inc_warmup)
      sp
    },
    .package = "rstan"
  )
  # Only the draw input is substituted; sampler extraction and the public
  # RStan diagnostics below execute their real implementations.
  local_mocked_bindings(
    as_posterior_draws = function(raw_fit, pars = NULL) {
      expect_identical(raw_fit, fit)
      posterior::as_draws_array(array(
        seq_len(12L) / 10, dim = c(6L, 2L, 1L),
        dimnames = list(NULL, NULL, "theta")
      ))
    }
  )

  expect_silent(reference_bfmi <- rstan::get_bfmi(fit))
  sampler <- fit_sampler_array(fit)
  expect_silent(summary <- fit_sampler_summary(fit, sampler))
  expect_equal(summary, list(ebfmi = reference_bfmi))
  expect_silent(out <- backend_diagnostics(fit))
  expect_identical(out$n_chains, 2L)
  expect_identical(out$n_iter, 6L)
  expect_identical(out$max_treedepth, 3L)
  expect_identical(out$chains$chain, 1:2)
  expect_identical(out$chains$num_divergent, c(2L, 1L))
  expect_identical(out$chains$num_max_treedepth, c(3L, 1L))
  expect_equal(out$chains$ebfmi, unname(reference_bfmi))
  expect_equal(sum(out$chains$num_divergent), rstan::get_num_divergent(fit))
  expect_equal(sum(out$chains$num_max_treedepth), rstan::get_num_max_treedepth(fit))
})
