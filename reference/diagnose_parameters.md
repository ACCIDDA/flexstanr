# Per-parameter convergence summaries

Per-parameter convergence summaries

## Usage

``` r
diagnose_parameters(draws)
```

## Arguments

- draws:

  a posterior `draws` object.

## Value

a base `data.frame` with one row per flat variable and columns
`variable`, `rhat`, `ess_bulk`, and `ess_tail`.
