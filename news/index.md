# Changelog

## flexstanr 0.2.0 (development version)

- [`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md)
  now states its return shape as a contract rather than leaving it to
  the backend ([\#34](https://github.com/ACCIDDA/flexstanr/issues/34)).
  `pars` defaults to `NULL`, which extracts every parameter, and a new
  `format` argument picks the representation: `"list"` (the default) is
  [`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)-compatible,
  `"draws"` returns a `posterior` draws array with the chain structure
  intact, and `"matrix"` returns a plain draws x variables matrix – the
  shape
  [`backend_generate_quantities()`](https://accidda.github.io/flexstanr/reference/backend_generate_quantities.md)
  takes as `draws_mat`. Each format has the same shape whichever backend
  produced the fit, so downstream code no longer has to branch on the
  backend. Existing calls are unaffected: `format` defaults to the shape
  [`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md)
  already returned.
- Bug fix: the cmdstanr backend returned a scalar parameter as a
  dimensionless vector, while
  [`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)
  returns a 1-D array of length `S` for a scalar in every call form.
  Code that reshapes off [`dim()`](https://rdrr.io/r/base/dim.html)
  ([`aperm()`](https://rdrr.io/r/base/aperm.html) errors outright on a
  dimensionless vector) therefore behaved differently depending on which
  backend produced the fit. The cmdstanr path now matches rstan. A
  `vector[1]` is still kept as an `S x 1` matrix on both backends, as
  rstan does.
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
- rstan and cmdstanr are now equally optional backends. rstan moved from
  `Imports` to `Suggests`, so flexstanr installs and loads without
  either package; selecting a backend whose package is not installed
  fails with an actionable error, and an attach-time message points the
  way when neither is present. Install whichever backend you use
  ([\#30](https://github.com/ACCIDDA/flexstanr/issues/30)).
- [`use_flexstanr()`](https://accidda.github.io/flexstanr/reference/use_flexstanr.md)
  now generates the host package’s re-export file (with a do-not-edit
  banner) in addition to editing its `DESCRIPTION`, and its signature
  mirrors `usethis::use_package()` (`min_version`, `remote`). It wires
  in flexstanr only; pick and declare a backend (rstan or cmdstanr)
  yourself.

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
