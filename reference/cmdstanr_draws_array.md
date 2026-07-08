# Coerce a cmdstanr draws array to a plain iterations x chains x parameters array

Coerce a cmdstanr draws array to a plain iterations x chains x
parameters array

## Usage

``` r
cmdstanr_draws_array(draws)
```

## Arguments

- draws:

  a posterior `draws_array` (iteration x chain x variable).

## Value

a base 3-D array, matching
[`as.array()`](https://rdrr.io/r/base/array.html) on an rstan `stanfit`.
