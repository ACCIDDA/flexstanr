# flexstanr

A **portable Stan-backend layer** for R packages that fit a Stan model.
It gives a host package one interface for fitting through either
[rstan](https://mc-stan.org/rstan/) or (optionally)
[cmdstanr](https://mc-stan.org/cmdstanr/), so the same code works
whichever backend is installed.

flexstanr compiles no Stan of its own: the host package supplies its own
compiled models, and flexstanr resolves them from the calling package at
run time.

## What it provides

- [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  collects and validates sampler arguments for the chosen backend,
  forwarding them **verbatim** so calls feel native. Mixing one
  backend’s argument vocabulary into the other errors with a “did you
  mean” hint.
- [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
  dispatches the fit to the backend recorded on the options, resolving
  the compiled model by name from the calling package.
- The fit-consumption accessors read a fit backend-agnostically:
  [`backend_draws_array()`](https://accidda.github.io/flexstanr/reference/backend_draws_array.md),
  [`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md),
  [`backend_generate_quantities()`](https://accidda.github.io/flexstanr/reference/backend_generate_quantities.md),
  and
  [`backend_has_draws()`](https://accidda.github.io/flexstanr/reference/backend_has_draws.md).

## Installation

flexstanr is not yet on CRAN. Install the development version from
GitHub:

``` r

# install.packages("remotes")
remotes::install_github("ACCIDDA/flexstanr")
```

The default backend, rstan, is a hard dependency. cmdstanr is an
optional backend; it is not on CRAN, so a project that wants it installs
it separately (see the cmdstanr [getting-started
guide](https://mc-stan.org/cmdstanr/)).

## Using it in your package

Declare flexstanr as a dependency and call it from your own fitting
code:

``` r

# in your package
opts <- flexstanr::stan_options(chains = 4, iter = 2000, seed = 1)
fit  <- flexstanr::fit_model(
  "coverage",              # resolved from your package's stanmodels / inst/stan
  dat_stan  = data_list,
  init      = init_list,
  stan_opts = opts
)
draws <- flexstanr::backend_draws_array(fit)
```

The model name is resolved against your package’s own compiled models
(`stanmodels` for rstan, `inst/stan/<name>.stan` for cmdstanr); the
calling package is detected automatically. A `useFlexStanR()` setup
helper to wire the dependencies into a host package is planned.

> **Note.** flexstanr began as a `use_standalone()` script vendored into
> the ACCIDDA Stan packages (imuGAP, hestia, SeverityEstimate). It is
> now a proper package those consumers import rather than copy. See the
> [flexstanr 0.1.0 CRAN
> release](https://github.com/ACCIDDA/flexstanr/milestone/1) milestone.

## License

MIT (c) ACCIDDA.
