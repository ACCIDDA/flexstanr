# Cores the process is allowed to use

A one-line seam over
[`parallelly::availableCores()`](https://parallelly.futureverse.org/reference/availableCores.html)
so tests can mock the core count (via
[`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html))
rather than the machine.

## Usage

``` r
detect_cores()
```

## Value

a single positive integer.
