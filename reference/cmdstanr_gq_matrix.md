# Coerce cmdstanr generated-quantities draws to a draws x parameters matrix

Coerce cmdstanr generated-quantities draws to a draws x parameters
matrix

## Usage

``` r
cmdstanr_gq_matrix(gq_draws)
```

## Arguments

- gq_draws:

  a posterior `draws` object of the requested generated parameter(s).

## Value

a base matrix (rows = draws), matching the rstan path's
`as.matrix(gqs(...), pars = ...)`.
