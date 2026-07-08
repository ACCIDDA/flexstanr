# Wire flexstanr into a host package

A one-time setup helper, in the spirit of usethis's `use_*` functions,
that declares flexstanr as a dependency of the host package you run it
from. It adds flexstanr (and rstan, the default backend) to the host's
`Imports` and, until flexstanr is on CRAN, an interim `Remotes` entry so
`remotes` / `pak` can install it from GitHub.

No further wiring is needed: the host calls
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
and the `backend_*` accessors directly, and flexstanr resolves the
host's own compiled models automatically from the calling package.

## Usage

``` r
use_flexstanr(path = ".", remote = "ACCIDDA/flexstanr", on_cran = FALSE)
```

## Arguments

- path:

  path to the host package's root (the directory containing its
  `DESCRIPTION`). Defaults to the working directory.

- remote:

  the GitHub `owner/repo` used for the interim `Remotes` entry while
  flexstanr is pre-CRAN.

- on_cran:

  set `TRUE` once flexstanr is on CRAN to skip the interim `Remotes`
  entry; a plain `Imports` dependency is then enough.

## Value

the host package `path`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
# from the root of your Stan package:
flexstanr::use_flexstanr()
} # }
```
