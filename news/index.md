# Changelog

## flexstanr 0.2.0 (development version)

- `stan_options(threading = TRUE)` turns on scheduler-aware threading
  (ported from hestia): flexstanr splits the cores the process is
  allowed to use – detected with
  [`parallelly::availableCores()`](https://parallelly.futureverse.org/reference/availableCores.html),
  respecting HPC schedulers and cgroup quotas – between
  chain-parallelism and within-chain (`reduce_sum`) threads, using all
  available cores by default (cap with `max_cores`), and reports what it
  chose.
  [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
  applies the split per backend, compiling the cmdstanr model with
  threading enabled when needed. The new exported
  [`test_threaded()`](https://accidda.github.io/flexstanr/reference/test_threaded.md)
  lets a host package’s fit function warn when its model cannot use the
  offered threads. See the new “Parallel and threaded fitting” vignette.
- [`use_flexstanr()`](https://accidda.github.io/flexstanr/reference/use_flexstanr.md)
  now generates the host package’s re-export file (with a do-not-edit
  banner) in addition to editing its `DESCRIPTION`, and its signature
  mirrors `usethis::use_package()` (`min_version`, `remote`).

## flexstanr 0.1.0

CRAN release: 2026-07-17

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
