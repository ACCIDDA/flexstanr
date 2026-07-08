# Fit a Stan model through the chosen backend

Dispatches a fit to the backend recorded on `stan_opts` (from
[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)).
The compiled model is resolved by `model_name` from the calling package:
for `"rstan"`, `package::stanmodels[[model_name]]`; for `"cmdstanr"`,
`inst/stan/<model_name>.stan` under `package`. The calling package is
detected automatically and can be overridden with `package`.

## Usage

``` r
fit_model(
  model_name,
  dat_stan,
  init,
  stan_opts,
  drop_pars = NULL,
  package = caller_package()
)
```

## Arguments

- model_name:

  name of the Stan model; used to look up the compiled model in the
  calling package's `stanmodels` (rstan) and to locate the `.stan`
  source file under its `inst/stan/` (cmdstanr).

- dat_stan:

  the Stan data list.

- init:

  the init list, sized to the chain count.

- stan_opts:

  the validated
  [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  list (carrying a `backend` element).

- drop_pars:

  character vector of parameter names to exclude from the saved draws,
  or `NULL` to keep everything. Honored by rstan; cmdstanr cannot drop
  parameters and warns if any are requested.

- package:

  name of the host package whose model is being fit. Defaults to the
  package that called `fit_model()`, which is correct for the usual case
  of a host package fitting one of its own models.

## Value

the backend's fit object (a `stanfit` or `CmdStanMCMC`).

## Examples

``` r
if (FALSE) { # \dontrun{
# From inside a host package that ships a compiled `coverage` model:
opts <- stan_options(chains = 2, iter = 500, seed = 1)
fit <- fit_model("coverage", dat_stan = data_list, init = init_list,
                 stan_opts = opts)
} # }
```
