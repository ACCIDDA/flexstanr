# Unit tests for the cmdstanr draws-reshaping helpers. These use synthetic
# posterior draws (posterior::example_draws()), so they run without cmdstanr or
# a CmdStan toolchain: they verify the reshaping that turns cmdstanr output into
# the shapes the rstan paths return. The live $draws() / generate_quantities()
# plumbing that feeds these helpers needs CmdStan and is out of scope here.

test_that("cmdstanr_draws_array returns a plain iter x chain x param array", {
  skip_if_not_installed("posterior")
  d <- posterior::example_draws() # 100 iter x 4 chains x 10 vars
  a <- cmdstanr_draws_array(d)
  expect_true(is.array(a))
  expect_false(inherits(a, "draws_array"))
  expect_identical(dim(a), dim(d))
  expect_identical(dimnames(a)$variable, dimnames(d)$variable)
})

test_that("cmdstanr_extract matches rstan::extract shapes", {
  skip_if_not_installed("posterior")
  d <- posterior::example_draws() # mu, tau (scalars), theta[1..8]
  n <- posterior::ndraws(d)
  ex <- cmdstanr_extract(d, c("mu", "theta"))

  expect_named(ex, c("mu", "theta"))
  # A scalar parameter comes back as a 1-D array of length S -- what
  # rstan::extract() returns for a scalar, verified against a live rstan fit.
  # NOT a dimensionless vector: callers reshape off dim().
  expect_identical(dim(ex$mu), n)
  expect_length(ex$mu, n)
  # a vector parameter comes back as an S x K matrix
  expect_identical(dim(ex$theta), c(n, 8L))
  # values agree (as a set) with a direct posterior pull
  direct <- as.numeric(posterior::as_draws_matrix(posterior::subset_draws(d, "mu")))
  expect_equal(sort(as.numeric(ex$mu)), sort(direct))
})

test_that("cmdstanr_extract errors on an unknown parameter", {
  skip_if_not_installed("posterior")
  d <- posterior::example_draws()
  expect_error(cmdstanr_extract(d, "not_a_param"), "not found")
})

test_that("cmdstanr_extract keeps a length-1 vector as an S x 1 matrix (rstan parity)", {
  skip_if_not_installed("posterior")
  # A scalar `mu` and a length-1 vector `x` (flat name "x[1]"). rstan::extract()
  # returns a 1-D array for the scalar but an S x 1 matrix for vector[1], so
  # cmdstanr_extract() must NOT collapse the vector[1] to the scalar shape.
  dm <- posterior::as_draws_matrix(
    matrix(rnorm(20), nrow = 10, ncol = 2, dimnames = list(NULL, c("mu", "x[1]")))
  )
  d <- posterior::as_draws_array(dm)
  ex <- cmdstanr_extract(d, c("mu", "x"))
  expect_identical(dim(ex$mu), 10L)        # true scalar -> 1-D array, like rstan
  expect_length(ex$mu, 10)
  expect_identical(dim(ex$x), c(10L, 1L))  # vector[1] -> S x 1 matrix, like rstan
})

test_that("cmdstanr_gq_matrix returns a plain draws x parameters matrix", {
  skip_if_not_installed("posterior")
  d <- posterior::subset_draws(posterior::example_draws(), variable = "theta")
  m <- cmdstanr_gq_matrix(d)
  expect_true(is.matrix(m))
  expect_false(inherits(m, "draws_matrix"))
  expect_identical(nrow(m), posterior::ndraws(d))
  expect_identical(ncol(m), 8L)
})

test_that("cmdstanr_extract handles the whole-fit parameter set", {
  skip_if_not_installed("posterior")
  # The pars = NULL call form resolves to every base name in the fit; check the
  # reshaping copes with the full set (scalars and containers together).
  d <- posterior::example_draws()
  pars <- par_base_names(posterior::variables(d))
  ex <- cmdstanr_extract(d, pars)
  expect_named(ex, c("mu", "tau", "theta"))
  expect_identical(dim(ex$mu), posterior::ndraws(d))
  expect_identical(dim(ex$theta), c(posterior::ndraws(d), 8L))
})
