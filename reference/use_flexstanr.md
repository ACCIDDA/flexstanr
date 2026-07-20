# Wire flexstanr into a host package

A one-time setup helper, in the spirit of usethis's
`usethis::use_package()`, that declares flexstanr as a dependency of the
host package you run it from. It adds flexstanr (and rstan, the default
backend) to the host's `Imports`, optionally records a `Remotes` entry
for a non-CRAN install, and writes a generated re-export file
(`R/flexstanr.R`) so `host::stan_options()` keeps resolving and the
host's internal calls to
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
/ the `backend_*` accessors are imported.

The re-export file is generated: it carries a do-not-edit banner and is
overwritten on each run, so re-run `use_flexstanr()` to pick up changes
to flexstanr's re-exported surface. flexstanr resolves the host's own
compiled models automatically from the calling package.

## Usage

``` r
use_flexstanr(
  path = ".",
  min_version = NULL,
  remote = NULL,
  type = "Imports",
  reexport = TRUE,
  reexport_file = file.path("R", "flexstanr.R")
)
```

## Arguments

- path:

  path to the host package's root (the directory containing its
  `DESCRIPTION`). Defaults to the working directory.

- min_version:

  minimum flexstanr version for the `Imports` entry. `NULL` (the
  default) pins to the currently-installed flexstanr version; pass a
  version string to pin explicitly, or `FALSE` for no constraint.

- remote:

  optional `owner/repo` (or any `remotes`-style spec) recorded as a
  `Remotes` entry so `remotes` / `pak` can install flexstanr off-CRAN.
  `NULL` (the default) records nothing, which is what you want for the
  CRAN package; pass e.g. `"ACCIDDA/flexstanr"` to install a development
  build.

- type:

  the `DESCRIPTION` field flexstanr is added to. `"Imports"` by default,
  as with `usethis::use_package()`.

- reexport:

  whether to (over)write the generated `R/flexstanr.R` re-export file.
  `TRUE` by default; set `FALSE` to only edit `DESCRIPTION`.

- reexport_file:

  path, relative to `path`, of the generated re-export file.

## Value

the host package `path`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
# from the root of your Stan package (CRAN flexstanr, pinned to installed):
flexstanr::use_flexstanr()

# track a development build off GitHub instead:
flexstanr::use_flexstanr(remote = "ACCIDDA/flexstanr")
} # }
```
