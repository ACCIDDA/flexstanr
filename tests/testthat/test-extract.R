# Tests for backend_extract()'s format contract (#34). Toolchain-free: a live
# fit needs a Stan install, so the rstan path is exercised through a stand-in
# for `as.array(stanfit)` -- an iterations x chains x parameters array with the
# flat Stan variable names, which is exactly what as_posterior_draws() consumes
# -- with fit_backend() mocked to route it down the rstan branch. The cmdstanr
# reshaping is covered against synthetic posterior draws in test-cmdstanr-read.R.

# Stand-in for `as.array(stanfit)`: 10 iterations x 2 chains, one scalar and a
# length-2 container, plus lp__ as a real fit carries.
fake_stanfit_array <- function(iter = 10L, chains = 2L) {
  vars <- c("mu", "theta[1]", "theta[2]", "lp__")
  array(
    seq_len(iter * chains * length(vars)),
    dim = c(iter, chains, length(vars)),
    dimnames = list(iterations = NULL, chains = NULL, parameters = vars)
  )
}

local_rstan_fit <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    fit_backend = function(raw_fit) "rstan",
    backend_installed = function(backend) TRUE,
    .env = env
  )
}

# --- helpers ------------------------------------------------------------------

test_that("par_base_names recovers container base names in order", {
  expect_identical(
    par_base_names(c("mu", "theta[1]", "theta[2]", "beta[1,1]", "lp__")),
    c("mu", "theta", "beta", "lp__")
  )
  expect_identical(par_base_names(character()), character())
})

test_that("assert_pars_present passes known parameters and names the unknown ones", {
  vars <- c("mu", "theta[1]", "theta[2]")
  expect_identical(assert_pars_present(vars, c("mu", "theta")), c("mu", "theta"))
  expect_error(assert_pars_present(vars, "sigma"), "parameter not found in the fit")
  expect_error(assert_pars_present(vars, "sigma"), "'sigma'")
  # a container is addressed by its base name, not a flat index
  expect_error(assert_pars_present(vars, "theta[1]"), "not found")
  err <- expect_error(assert_pars_present(vars, c("sigma", "nu")), "parameters not found")
  expect_match(conditionMessage(err), "'sigma', 'nu'")
})

test_that("plain_draws_matrix returns a bare draws x variables matrix", {
  skip_if_not_installed("posterior")
  d <- posterior::example_draws()
  m <- plain_draws_matrix(d)
  expect_true(is.matrix(m))
  expect_false(inherits(m, "draws_matrix"))
  expect_null(attr(m, "nchains"))
  expect_identical(nrow(m), posterior::ndraws(d))
  expect_identical(ncol(m), length(posterior::variables(d)))
})

# --- argument validation ------------------------------------------------------

test_that("backend_extract rejects an unknown format and a non-character pars", {
  fit <- structure(list(), class = "stanfit")
  expect_error(backend_extract(fit, format = "nonsense"), "should be one of")
  # A stray positional third argument lands on `format` and fails loudly rather
  # than silently changing the returned shape -- the case that matters, since
  # the pre-format signature sent a third positional argument to `...` (and so
  # to rstan::extract()'s `permuted`).
  expect_error(backend_extract(fit, "mu", TRUE), "must be NULL or a character vector")
  expect_error(backend_extract(fit, "mu", "permuted"), "should be one of")
  expect_error(backend_extract(fit, pars = 1), "`pars` must be a character vector")
  expect_error(backend_extract(fit, pars = list("mu")), "or NULL for all")
})

test_that("backend_extract refuses `...` for the formats that cannot forward it", {
  fit <- structure(list(), class = "stanfit")
  expect_error(
    backend_extract(fit, format = "draws", permuted = FALSE),
    "only format = \"list\" uses"
  )
  expect_error(
    backend_extract(fit, format = "matrix", inc_warmup = TRUE),
    "only format = \"list\" uses"
  )
})

# --- format = "draws" ---------------------------------------------------------

test_that("format = 'draws' returns a posterior draws_array, chains preserved", {
  skip_if_not_installed("posterior")
  local_rstan_fit()
  a <- fake_stanfit_array()

  d <- backend_extract(a, format = "draws")
  expect_s3_class(d, "draws_array")
  expect_identical(posterior::niterations(d), 10L)
  expect_identical(posterior::nchains(d), 2L)
  expect_identical(
    posterior::variables(d),
    c("mu", "theta[1]", "theta[2]", "lp__")
  )
  # draw order is preserved, not permuted
  expect_equal(as.numeric(d[, , "mu"]), as.numeric(a[, , "mu"]))
})

test_that("format = 'draws' subsets by container base name", {
  skip_if_not_installed("posterior")
  local_rstan_fit()
  d <- backend_extract(fake_stanfit_array(), pars = "theta", format = "draws")
  expect_identical(posterior::variables(d), c("theta[1]", "theta[2]"))

  # a single name is a valid `pars`, as is a vector of them
  one <- backend_extract(fake_stanfit_array(), pars = "mu", format = "draws")
  expect_identical(posterior::variables(one), "mu")
  both <- backend_extract(
    fake_stanfit_array(),
    pars = c("mu", "theta"), format = "draws"
  )
  expect_identical(posterior::variables(both), c("mu", "theta[1]", "theta[2]"))
})

test_that("an unknown parameter errors instead of coming back empty", {
  skip_if_not_installed("posterior")
  local_rstan_fit()
  expect_error(
    backend_extract(fake_stanfit_array(), pars = "sigma", format = "draws"),
    "not found in the fit"
  )
})

# --- format = "matrix" --------------------------------------------------------

test_that("format = 'matrix' stacks chains into a draws x variables matrix", {
  skip_if_not_installed("posterior")
  local_rstan_fit()
  a <- fake_stanfit_array()

  m <- backend_extract(a, format = "matrix")
  expect_true(is.matrix(m))
  expect_false(inherits(m, "draws_matrix"))
  # 10 iterations x 2 chains = 20 draws; one column per flat variable
  expect_identical(dim(m), c(20L, 4L))
  expect_identical(colnames(m), c("mu", "theta[1]", "theta[2]", "lp__"))

  sub <- backend_extract(a, pars = "theta", format = "matrix")
  expect_identical(dim(sub), c(20L, 2L))
  expect_identical(colnames(sub), c("theta[1]", "theta[2]"))
})

test_that("the 'matrix' format holds the same draws as the 'draws' format", {
  skip_if_not_installed("posterior")
  local_rstan_fit()
  a <- fake_stanfit_array()
  m <- backend_extract(a, pars = "mu", format = "matrix")
  d <- backend_extract(a, pars = "mu", format = "draws")
  expect_equal(sort(as.numeric(m)), sort(as.numeric(d)))
})

# --- format = "list": the cross-backend shape contract ------------------------

test_that("the cmdstanr 'list' reshaping matches rstan::extract()'s shapes", {
  skip_if_not_installed("posterior")
  # The reference dims below are what rstan::extract() returns for a fit with a
  # `real mu`, a `vector[2] theta` and a `vector[1] x`, verified against a live
  # rstan fit (a Stan toolchain is needed to produce one, so it cannot run here):
  #
  #   mu     dim = S        class array   <- 1-D array, NOT a dimensionless vector
  #   theta  dim = S x 2    class matrix
  #   x      dim = S x 1    class matrix  <- vector[1] is not collapsed
  #
  # This is the layout downstream cbind() / colMeans() / aperm() code is written
  # against, so a backend that diverges produces wrong numbers rather than an
  # error. Drive the cmdstanr reshaping off draws with the same variables and
  # assert it lands on exactly those shapes.
  vars <- c("mu", "theta[1]", "theta[2]", "x[1]")
  s <- 20L
  dm <- posterior::as_draws_matrix(
    matrix(seq_len(s * length(vars)), nrow = s, dimnames = list(NULL, vars))
  )
  ex <- cmdstanr_extract(posterior::as_draws_array(dm), c("mu", "theta", "x"))

  expect_identical(dim(ex$mu), s)
  expect_true(is.array(ex$mu))
  expect_false(is.matrix(ex$mu))
  expect_identical(dim(ex$theta), c(s, 2L))
  expect_true(is.matrix(ex$theta))
  expect_identical(dim(ex$x), c(s, 1L))
  expect_true(is.matrix(ex$x))
})

# --- format = "list": delegation ----------------------------------------------

test_that("format = 'list' forwards to rstan::extract, passing pars only when given", {
  # The rstan list path delegates to rstan::extract() so the shape is rstan's by
  # construction. Mock the extractor to assert the delegation contract itself:
  # `pars` is passed through when supplied and OMITTED when NULL, so pars = NULL
  # means "all" exactly as omitting the argument does.
  local_rstan_fit()
  seen <- NULL
  local_mocked_bindings(
    extract_par_list = function(raw_fit, pars = NULL, ...) {
      seen <<- list(pars = pars, dots = list(...))
      "extracted"
    }
  )
  expect_identical(backend_extract(fake_stanfit_array()), "extracted")
  expect_null(seen$pars)

  backend_extract(fake_stanfit_array(), pars = c("mu", "theta"))
  expect_identical(seen$pars, c("mu", "theta"))

  # `...` reaches the backend extractor for format = "list"
  backend_extract(fake_stanfit_array(), pars = "mu", inc_warmup = TRUE)
  expect_identical(seen$dots, list(inc_warmup = TRUE))
})
