# Stack rstan's per-chain sampler parameters into one array

Stack rstan's per-chain sampler parameters into one array

## Usage

``` r
rstan_sampler_array(sp)
```

## Arguments

- sp:

  the list returned by
  [`rstan::get_sampler_params()`](https://mc-stan.org/rstan/reference/stanfit-class.html):
  one iterations x variables matrix per chain.

## Value

a plain iterations x chains x variables array.
