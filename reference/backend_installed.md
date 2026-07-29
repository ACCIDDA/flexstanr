# Is a backend's package installed?

A one-line seam over
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) so tests can
simulate a missing backend (via
[`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html))
instead of uninstalling a package. Both backends are optional, so every
backend-availability decision routes through here.

## Usage

``` r
backend_installed(backend)
```

## Arguments

- backend:

  the backend package name (`"rstan"` or `"cmdstanr"`).

## Value

logical; `TRUE` if the backend package is installed.
