# Getting started with flexstanr

flexstanr gives a Stan-based R package **one interface** for fitting its
models through either [rstan](https://mc-stan.org/rstan/) or
[cmdstanr](https://mc-stan.org/cmdstanr/), neither of which flexstanr
requires (install whichever you use). Your package supplies its own
compiled models; flexstanr resolves them at run time, so the same
fitting code works whichever backend is installed.

This vignette walks through wiring flexstanr into a host package and
using it.

## Wiring it into your package

From the root of your Stan package, run the setup helper once:

``` r

flexstanr::use_flexstanr()
```

This adds `flexstanr` to your `Imports`. It does not add a Stan backend,
since flexstanr requires neither; declare `rstan` or `cmdstanr`
yourself. To track a development build off GitHub instead of the CRAN
release, pass `remote = "ACCIDDA/flexstanr"` to also record a
`Remotes: ACCIDDA/flexstanr` entry so `remotes` / `pak` can find it.

## Building sampler options

[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
validates common sampler arguments and forwards arbitrary same-backend
arguments **verbatim** to that backend’s native sampler. The native
sampler validates arguments that flexstanr does not recognize:

``` r

opts <- stan_options(chains = 2, iter = 500, seed = 1)
str(opts)
#> List of 4
#>  $ iter   : int 500
#>  $ seed   : int 1
#>  $ chains : int 2
#>  $ backend: chr "rstan"
```

For example, backend-native controls such as rstan’s `refresh` or
cmdstanr’s `open_progress` pass through unchanged.

The model object, data, and initial values are reserved for
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md).
Mixing known vocabulary from the other backend is also caught early with
a “did you mean” hint rather than failing deep inside the sampler:

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

# omit `pars` to take every parameter
all_post <- backend_extract(fit)

# guard against the degenerate "no draws" case before using a fit
stopifnot(backend_has_draws(fit))
```

[`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md)
guarantees its return shape, so the same downstream math works against
either backend. `format` picks the representation:

``` r

# "list" (the default): rstan::extract()'s shape -- one entry per parameter,
# draws first, a scalar as a 1-D array of length S, a vector[2] as S x 2
post$beta

# "draws": a posterior draws array, chains kept, flat Stan variable names
draws_arr <- backend_extract(fit, format = "draws")

# "matrix": one row per draw, one column per flat variable -- what
# backend_generate_quantities() takes as `draws_mat`
mat <- backend_extract(fit, format = "matrix")
gen <- backend_generate_quantities(fit, data = dat, draws_mat = mat, pars = "y_rep")
```

`"draws"` and `"matrix"` keep iteration-chain draw order on both
backends. `"list"` does not:
[`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)
permutes draws by default and the cmdstanr path does not, so the two
agree as a sample rather than draw for draw.

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
