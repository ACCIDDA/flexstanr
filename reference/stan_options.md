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

# S3 method for class 'flexstanr_options'
print(x, ...)
```

## Arguments

- ...:

  arbitrary sampler arguments forwarded verbatim to the chosen backend's
  sampler. Use the backend's own names: for `"rstan"`, the
  [`rstan::sampling()`](https://mc-stan.org/rstan/reference/stanmodel-method-sampling.html)
  arguments (`iter`, `cores`, `seed`); for `"cmdstanr"`, the `$sample()`
  arguments (`iter_warmup`, `iter_sampling`, `parallel_chains`, ...).
  For the print method, additional arguments are accepted but unused.

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

- x:

  A `stan_options()` result.

## Value

A named list of class `c("flexstanr_options", "list")`, containing
validated sampler arguments and a `backend` element recording the
backend it was built for. Use `inherits(x, "flexstanr_options")` to
recognize these options in a host package. Ordinary list access and
modification still work. Printing shows the backend and the stored
options; defaults left to the native sampler are not filled in. The
print method returns its input invisibly.

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
#> Stan sampler options (rstan)
#>   chains: 4L
#>   cores: 4L
#>   threads_per_chain: 1L
if (requireNamespace("cmdstanr", quietly = TRUE)) {
  stan_options(backend = "cmdstanr", parallel_chains = 4, iter_warmup = 500)
}
#> Stan sampler options (cmdstanr)
#>   parallel_chains: 4L
#>   iter_warmup: 500L
#>   chains: 4L
```
