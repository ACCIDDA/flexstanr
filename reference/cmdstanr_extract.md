# Reshape cmdstanr draws into rstan::extract()'s list-of-arrays

Groups the flat, indexed variables (`theta[1]`, `theta[2]`, ...) back
into one array per parameter with draws merged across chains, matching
the shape
[`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)
returns: a **1-D array** of length `S` for a scalar parameter, an
`S x dims` array otherwise. Unlike rstan's default the draws are not
randomly permuted; they keep iteration-chain order, which is immaterial
for the exchangeable-sample uses these draws are put to. Dimension
*names* are not part of the shape contract (rstan labels the iteration
margin, this does not); [`dim()`](https://rdrr.io/r/base/dim.html) and
the class are.

## Usage

``` r
cmdstanr_extract(draws, pars)
```

## Arguments

- draws:

  a posterior `draws` object for the requested parameters.

- pars:

  the parameter base names to extract.

## Value

a named list of draw arrays, one per parameter.
