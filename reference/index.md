# Package index

## Setup

Wire flexstanr into your own package.

- [`use_flexstanr()`](https://accidda.github.io/flexstanr/reference/use_flexstanr.md)
  : Wire flexstanr into a host package

## Fitting

Build sampler options and fit a model through the chosen backend.

- [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  : Stan Sampler Options
- [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
  : Fit a Stan model through the chosen backend

## Threading

Turn on scheduler-aware threading with stan_options(threading = TRUE); a
host’s fit function checks whether threads were requested so it can warn
on a model that cannot use them.

- [`test_threaded()`](https://accidda.github.io/flexstanr/reference/test_threaded.md)
  : Does a set of sampler options ask for within-chain threading?

## Reading a fit

Backend-agnostic accessors for a fitted model object.

- [`backend_draws_array()`](https://accidda.github.io/flexstanr/reference/backend_draws_array.md)
  : Posterior draws of a fit as an iterations x chains x parameters
  array
- [`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md)
  : Extract named parameters from a fit as a list of arrays
- [`backend_generate_quantities()`](https://accidda.github.io/flexstanr/reference/backend_generate_quantities.md)
  : Run generated quantities against a fit and return a parameter matrix
- [`backend_has_draws()`](https://accidda.github.io/flexstanr/reference/backend_has_draws.md)
  : Does a fit object carry usable posterior draws?
