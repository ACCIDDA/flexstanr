# flexstanr 0.2.0 (development version)

* `backend_extract()` now states its return shape as a contract rather than
  leaving it to the backend (#34). `pars` defaults to `NULL`, which extracts
  every parameter, and a new `format` argument picks the representation:
  `"list"` (the default) is `rstan::extract()`-compatible, `"draws"` returns a
  `posterior` draws array with the chain structure intact, and `"matrix"`
  returns a plain draws x variables matrix -- the shape
  `backend_generate_quantities()` takes as `draws_mat`. Each format has the same
  shape whichever backend produced the fit, so downstream code no longer has to
  branch on the backend. Existing calls are unaffected: `format` defaults to the
  shape `backend_extract()` already returned.
* Bug fix: the cmdstanr backend returned a scalar parameter as a dimensionless
  vector, while `rstan::extract()` returns a 1-D array of length `S` for a
  scalar in every call form. Code that reshapes off `dim()` (`aperm()` errors
  outright on a dimensionless vector) therefore behaved differently depending on
  which backend produced the fit. The cmdstanr path now matches rstan. A
  `vector[1]` is still kept as an `S x 1` matrix on both backends, as rstan does.
* `stan_options(threading = TRUE)` turns on scheduler-aware threading (ported
  from hestia): flexstanr splits the cores the process is allowed to use --
  detected with `parallelly::availableCores()`, respecting HPC schedulers and
  cgroup quotas -- between chain-parallelism and within-chain (`reduce_sum`)
  threads, using all available cores by default (cap with `max_cores`), and
  reports what it chose. `fit_model()` applies the split per
  backend, compiling the cmdstanr model with threading enabled when needed. The
  new exported `test_threaded()` lets a host package's fit function warn when
  its model cannot use the offered threads. See the new "Parallel and threaded
  fitting" vignette.
* rstan and cmdstanr are now equally optional backends. rstan moved from
  `Imports` to `Suggests`, so flexstanr installs and loads without either
  package; selecting a backend whose package is not installed fails with an
  actionable error, and an attach-time message points the way when neither is
  present. Install whichever backend you use (#30).
* `use_flexstanr()` now generates the host package's re-export file (with a
  do-not-edit banner) in addition to editing its `DESCRIPTION`, and its
  signature mirrors `usethis::use_package()` (`min_version`, `remote`). It wires
  in flexstanr only; pick and declare a backend (rstan or cmdstanr) yourself.

# flexstanr 0.1.0

Initial release: a portable Stan-backend layer that a Stan-based R package can
fit its models through, using either rstan (default) or, optionally, cmdstanr.

* `stan_options()` collects and validates sampler options for the chosen
  backend, forwarding them verbatim and guarding against mixing one backend's
  argument vocabulary into the other.
* `fit_model()` dispatches a fit to the backend recorded on the options and
  resolves the calling package's compiled model automatically.
* Backend-agnostic accessors read a fit without knowing which backend produced
  it: `backend_draws_array()`, `backend_extract()`,
  `backend_generate_quantities()`, and `backend_has_draws()`.
* `use_flexstanr()` wires flexstanr into a host package's DESCRIPTION.
* cmdstanr is an optional backend, used only through `requireNamespace()`
  guards; rstan is the default and only hard Stan dependency.
