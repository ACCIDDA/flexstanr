# Coerce a posterior draws object to a plain draws x parameters matrix

Chains are stacked, so the result is a base matrix with one row per draw
and one column per (flat) variable. Used for the `"matrix"` extraction
format and by the cmdstanr generated-quantities path, which need the
same shape.

## Usage

``` r
plain_draws_matrix(draws)
```

## Arguments

- draws:

  a posterior `draws` object.

## Value

a base matrix (rows = draws), matching the rstan path's `as.matrix(fit)`
/ `as.matrix(gqs(...), pars = ...)`.
