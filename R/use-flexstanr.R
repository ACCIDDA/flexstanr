#' Wire flexstanr into a host package
#'
#' @description
#' A one-time setup helper, in the spirit of usethis's `use_*` functions, that
#' declares flexstanr as a dependency of the host package you run it from. It
#' adds flexstanr (and rstan, the default backend) to the host's `Imports` and,
#' until flexstanr is on CRAN, an interim `Remotes` entry so `remotes` / `pak`
#' can install it from GitHub.
#'
#' No further wiring is needed: the host calls [fit_model()] and the `backend_*`
#' accessors directly, and flexstanr resolves the host's own compiled models
#' automatically from the calling package.
#'
#' @param path path to the host package's root (the directory containing its
#'   `DESCRIPTION`). Defaults to the working directory.
#' @param remote the GitHub `owner/repo` used for the interim `Remotes` entry
#'   while flexstanr is pre-CRAN.
#' @param on_cran set `TRUE` once flexstanr is on CRAN to skip the interim
#'   `Remotes` entry; a plain `Imports` dependency is then enough.
#' @returns the host package `path`, invisibly.
#'
#' @examples
#' \dontrun{
#' # from the root of your Stan package:
#' flexstanr::useFlexStanR()
#' }
#'
#' @export
useFlexStanR <- function(path = ".", # nolint: object_name_linter.
                         remote = "ACCIDDA/flexstanr",
                         on_cran = FALSE) {
  if (!requireNamespace("desc", quietly = TRUE)) {
    stop(
      "useFlexStanR() needs the 'desc' package to edit DESCRIPTION; ",
      "install it with install.packages('desc').",
      call. = FALSE
    )
  }
  desc_path <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    stop(
      "no DESCRIPTION found at '", path, "'. Run useFlexStanR() from the root ",
      "of the package you are wiring flexstanr into.",
      call. = FALSE
    )
  }
  d <- desc::desc(file = desc_path)

  # Add flexstanr + the default backend to Imports, but do not clobber an
  # existing rstan version constraint the host already declares.
  have <- d$get_deps()$package
  if (!"flexstanr" %in% have) {
    d$set_dep("flexstanr", "Imports")
  }
  if (!"rstan" %in% have) {
    d$set_dep("rstan", "Imports")
  }

  # Interim Remotes entry so flexstanr installs from GitHub until it is on CRAN.
  if (!isTRUE(on_cran)) {
    remotes <- d$get_remotes()
    if (!remote %in% remotes) {
      d$set_remotes(unique(c(remotes, remote)))
    }
  }

  d$write(file = desc_path)
  invisible(path)
}
