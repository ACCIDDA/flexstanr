# flexstanr 0.2.0 (development version)

* `optimal_alloc()` and `configure_threading()` bring scheduler-aware thread
  allocation into flexstanr (ported from hestia): split the cores a process is
  allowed to use between chain-parallelism and within-chain threads, detecting
  the allocation with `parallelly::availableCores()` (respecting HPC schedulers
  and cgroup quotas), then apply it to a `stan_options()` object for either
  backend. `fit_model()` compiles the cmdstanr backend with threading enabled
  when the options carry a multi-thread allocation. See the new "Parallel and
  threaded fitting" vignette.
* `use_flexstanr()` now generates the host package's re-export file (with a
  do-not-edit banner) in addition to editing its `DESCRIPTION`, and its
  signature mirrors `usethis::use_package()` (`min_version`, `remote`).

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
