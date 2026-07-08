# Getting started with flexstanr

flexstanr gives a Stan-based R package **one interface** for fitting its
models through either [rstan](https://mc-stan.org/rstan/) or
(optionally) [cmdstanr](https://mc-stan.org/cmdstanr/). Your package
supplies its own compiled models; flexstanr resolves them at run time,
so the same fitting code works whichever backend is installed.

This vignette walks through wiring flexstanr into a host package and
using it.

## Wiring it into your package

From the root of your Stan package, run the setup helper once:

``` r

flexstanr::use_flexstanr()
```

This adds `flexstanr` (and `rstan`, the default backend) to your
`Imports` and, while flexstanr is still pre-CRAN, an interim
`Remotes: ACCIDDA/flexstanr` entry so `remotes` / `pak` can install it
from GitHub. Once flexstanr is on CRAN, pass `on_cran = TRUE` to skip
the `Remotes` entry.

## Building sampler options

[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
collects and validates sampler arguments for the chosen backend,
forwarding them **verbatim** so a call feels native to that backend:

``` r

opts <- stan_options(chains = 2, iter = 500, seed = 1)
str(opts)
#> List of 4
#>  $ iter   : int 500
#>  $ seed   : int 1
#>  $ chains : int 2
#>  $ backend: chr "rstan"
```

Each backend has its own argument vocabulary, and mixing them is caught
early with a “did you mean” hint rather than failing deep inside the
sampler:

``` r

# `parallel_chains` is a cmdstanr word; the rstan backend rejects it.
try(stan_options(backend = "rstan", parallel_chains = 4))
#> Error : These stan_options() arguments are not valid for the 'rstan' backend:
#>   - `parallel_chains`: use `cores`
```

## Fitting a model

[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
dispatches to the backend recorded on the options and resolves the
compiled model by name from your package. A host fitting one of its own
models needs no extra arguments; the calling package is detected
automatically.

``` r

# `"coverage"` is resolved from your package's stanmodels (rstan) or
# inst/stan/coverage.stan (cmdstanr).
fit <- fit_model(
  "coverage",
  dat_stan  = data_list,
  init      = init_list,
  stan_opts = opts
)
```

## Reading a fit

The `backend_*` accessors read a fitted object without your code needing
to know which backend produced it:

``` r

# posterior draws as an iterations x chains x parameters array
draws <- backend_draws_array(fit)

# named parameters, matching rstan::extract()'s shape
post <- backend_extract(fit, pars = c("beta", "sigma"))

# guard against the degenerate "no draws" case before using a fit
stopifnot(backend_has_draws(fit))
```

Unrecognized objects pass through
[`backend_has_draws()`](https://accidda.github.io/flexstanr/reference/backend_has_draws.md)
as if they carry draws, so test doubles are left untouched:

``` r

backend_has_draws(list())
#> [1] TRUE
```

## Choosing cmdstanr

Pass `backend = "cmdstanr"` to
[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md).
cmdstanr is optional and not on CRAN, so install it separately (see the
cmdstanr [getting-started guide](https://mc-stan.org/cmdstanr/));
selecting it without the package installed errors early with an
actionable message.

``` r

opts <- stan_options(backend = "cmdstanr", parallel_chains = 4, iter_warmup = 500)
```
