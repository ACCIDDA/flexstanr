# Generate a host package's flexstanr re-export file

Returns the text that
[`use_flexstanr()`](https://accidda.github.io/flexstanr/reference/use_flexstanr.md)
writes to the host's `R/flexstanr.R`. It carries a do-not-edit banner
(the file is generated, in the spirit of a roxygen artifact) and, using
the canonical surface lists above, imports flexstanr's backend entry
points for internal use and re-exports the public constructor(s) so
`host::stan_options()` keeps resolving.

Exposed (internal) so the generation can be tested and regenerated
independently. See the fixture-package test.

## Usage

``` r
flexstanr_reexport_source()
```

## Value

a single string: the full file contents, banner included.
