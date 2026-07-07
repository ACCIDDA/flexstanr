# Tests for the useFlexStanR() setup helper. These operate on a throwaway
# fixture DESCRIPTION so nothing touches a real project.

make_fixture_pkg <- function(dir, remotes = NULL) {
  lines <- c(
    "Package: hostpkg",
    "Title: A Host",
    "Version: 0.0.1",
    "Imports:",
    "    rstan (>= 2.18.1)"
  )
  if (!is.null(remotes)) {
    lines <- c(lines, paste0("Remotes:\n    ", remotes))
  }
  writeLines(lines, file.path(dir, "DESCRIPTION"))
  dir
}

test_that("useFlexStanR adds flexstanr to Imports and an interim Remotes entry", {
  skip_if_not_installed("desc")
  dir <- withr::local_tempdir()
  make_fixture_pkg(dir)

  expect_identical(useFlexStanR(path = dir), dir)

  d <- desc::desc(file = file.path(dir, "DESCRIPTION"))
  deps <- d$get_deps()
  expect_true("flexstanr" %in% deps$package[deps$type == "Imports"])
  expect_true("ACCIDDA/flexstanr" %in% d$get_remotes())
})

test_that("useFlexStanR does not clobber an existing rstan version constraint", {
  skip_if_not_installed("desc")
  dir <- withr::local_tempdir()
  make_fixture_pkg(dir)

  useFlexStanR(path = dir)

  d <- desc::desc(file = file.path(dir, "DESCRIPTION"))
  deps <- d$get_deps()
  expect_identical(deps$version[deps$package == "rstan"], ">= 2.18.1")
})

test_that("on_cran = TRUE skips the interim Remotes entry", {
  skip_if_not_installed("desc")
  dir <- withr::local_tempdir()
  make_fixture_pkg(dir)

  useFlexStanR(path = dir, on_cran = TRUE)

  d <- desc::desc(file = file.path(dir, "DESCRIPTION"))
  expect_false("ACCIDDA/flexstanr" %in% d$get_remotes())
  expect_true("flexstanr" %in% d$get_deps()$package)
})

test_that("useFlexStanR errors when there is no DESCRIPTION", {
  skip_if_not_installed("desc")
  dir <- withr::local_tempdir()
  expect_error(useFlexStanR(path = dir), "no DESCRIPTION found")
})
