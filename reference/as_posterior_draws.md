# A fit's draws as a posterior draws_array, for either backend

The single conversion both backends route through for the `"draws"` and
`"matrix"` formats, so those two are identical across backends by
construction. Draw order is preserved (iteration-chain order); neither
path permutes.

## Usage

``` r
as_posterior_draws(raw_fit, pars = NULL)
```

## Arguments

- raw_fit:

  a backend-native fit object.

- pars:

  parameter base names to keep, or `NULL` for all.

## Value

a posterior `draws_array` (iteration x chain x variable).
