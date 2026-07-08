# Changelog

## flexstanr 0.1.0

Initial release: a portable Stan-backend layer that a Stan-based R
package can fit its models through, using either rstan (default) or,
optionally, cmdstanr.

- [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  collects and validates sampler options for the chosen backend,
  forwarding them verbatim and guarding against mixing one backend’s
  argument vocabulary into the other.
- [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
  dispatches a fit to the backend recorded on the options and resolves
  the calling package’s compiled model automatically.
- Backend-agnostic accessors read a fit without knowing which backend
  produced it:
  [`backend_draws_array()`](https://accidda.github.io/flexstanr/reference/backend_draws_array.md),
  [`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md),
  [`backend_generate_quantities()`](https://accidda.github.io/flexstanr/reference/backend_generate_quantities.md),
  and
  [`backend_has_draws()`](https://accidda.github.io/flexstanr/reference/backend_has_draws.md).
- [`use_flexstanr()`](https://accidda.github.io/flexstanr/reference/use_flexstanr.md)
  wires flexstanr into a host package’s DESCRIPTION.
- cmdstanr is an optional backend, used only through
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) guards;
  rstan is the default and only hard Stan dependency.
