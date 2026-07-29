# Assert a backend name is valid and its package is installed

Validates `backend` against the known choices (so it also subsumes
[`match.arg()`](https://rdrr.io/r/base/match.arg.html)) and that the
selected backend's package is installed. rstan and cmdstanr are both
optional (each lives in `Suggests`), so selecting either without its
package installed fails early here, with an actionable install hint,
rather than deep inside the fit. Returns the validated backend
invisibly.

## Usage

``` r
assert_backend_available(backend)
```

## Arguments

- backend:

  the backend to validate.

## Value

the validated backend string, invisibly.
