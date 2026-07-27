# Write a thread allocation onto sampler options, per backend

Records an
[`optimal_alloc()`](https://accidda.github.io/flexstanr/reference/optimal_alloc.md)
split on a
[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
list using each backend's own field names. No environment variable is
touched here: rstan's per-chain thread count rides along as
`threads_per_chain` (metadata that
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
strips and applies via `STAN_NUM_THREADS` at fit time), while cmdstanr
consumes `parallel_chains` / `threads_per_chain` natively.

## Usage

``` r
write_threading(res, alloc)
```

## Arguments

- res:

  a
  [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  result (backend already recorded).

- alloc:

  an
  [`optimal_alloc()`](https://accidda.github.io/flexstanr/reference/optimal_alloc.md)
  result.

## Value

`res`, with the backend's parallelism fields set.
