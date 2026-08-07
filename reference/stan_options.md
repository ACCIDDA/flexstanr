# Stan Sampler Options

Collects sampler arguments for the chosen `backend`, validating common
arguments and forwarding all other same-backend arguments **verbatim**
to the native sampler. The native sampler remains responsible for
validating those forwarded arguments. Mixing one backend's known
vocabulary into the other errors with a hint. The model object is
supplied separately (via
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)),
while `data` and `init` are constructed internally, so none of these may
be set here. `chains` defaults to `4` so downstream code can always size
per-chain structures from it.

## Usage

``` r
stan_options(
  ...,
  chains = 4L,
  backend = "rstan",
  threading = FALSE,
  max_cores = NULL
)
```

## Arguments

- ...:

  arbitrary sampler arguments forwarded verbatim to the chosen backend's
  sampler. Use the backend's own names: for `"rstan"`, the
  [`rstan::sampling()`](https://mc-stan.org/rstan/reference/stanmodel-method-sampling.html)
  arguments (`iter`, `cores`, `seed`); for `"cmdstanr"`, the `$sample()`
  arguments (`iter_warmup`, `iter_sampling`, `parallel_chains`, ...).

- chains:

  number of Markov chains to run. Defaults to `4` for both backends.

- backend:

  which Stan interface to target, one of `"rstan"` (default) or
  `"cmdstanr"`. Determines which argument vocabulary is accepted and
  which sampler
  [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
  calls. Both backends are optional; selecting one errors if its package
  is not installed.

- threading:

  `TRUE` to let flexstanr use the machine's spare cores: it splits the
  cores the process is allowed to use across the chains and the
  within-chain (`reduce_sum`) threads, and messages what it chose.
  `FALSE` (the default) leaves parallelism untouched, so you can still
  set `cores` (rstan) or `parallel_chains` / `threads_per_chain`
  (cmdstanr) by hand. A model that cannot use the offered threads should
  say so; see
  [`test_threaded()`](https://accidda.github.io/flexstanr/reference/test_threaded.md).

- max_cores:

  when `threading = TRUE`, an optional cap on the cores used. `NULL`
  (the default) uses all available cores; set it to leave some free /
  cap usage for other work. Ignored when `threading = FALSE`.

## Value

a named list of validated sampler arguments, carrying a `backend`
element recording the backend it was built for

## See also

[`test_threaded()`](https://accidda.github.io/flexstanr/reference/test_threaded.md)

## Examples

``` r
if (requireNamespace("rstan", quietly = TRUE)) {
  stan_options()
  stan_options(chains = 2, iter = 500)
  stan_options(chains = 4, threading = TRUE)  # allocate spare cores to threads
}
#> flexstanr: threading enabled. Using 4 of 4 available cores: 4 chains in parallel, 1 thread per chain. Pass max_cores to leave some cores free.
#> $chains
#> [1] 4
#> 
#> $backend
#> [1] "rstan"
#> 
#> $cores
#> [1] 4
#> 
#> $threads_per_chain
#> [1] 1
#> 
if (requireNamespace("cmdstanr", quietly = TRUE)) {
  stan_options(backend = "cmdstanr", parallel_chains = 4, iter_warmup = 500)
}
#> $parallel_chains
#> [1] 4
#> 
#> $iter_warmup
#> [1] 500
#> 
#> $chains
#> [1] 4
#> 
#> $backend
#> [1] "cmdstanr"
#> 
```
