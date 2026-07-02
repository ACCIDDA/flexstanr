# flexstanr

Canonical home for a **portable Stan-backend layer** shared across the ACCIDDA
Stan packages (imuGAP, hestia, SeverityEstimate). This is a non-package repo: it
hosts a single standalone R script that any Stan-based package can vendor in
verbatim, so the backend logic lives in one place instead of being copy-pasted.

## What it provides

`R/standalone-backends.R` gives a package a two-backend Stan interface selected
by `stan_options(backend = ...)`:

- **rstan** (default, a hard dependency) via `rstan::sampling()`.
- **cmdstanr** (optional) via `cmdstan_model()$sample()`.

It contains `stan_options()`, the per-backend fit dispatch (`fit_model()` ->
`fit_rstan()` / `fit_cmdstanr()`), the cross-backend argument-vocabulary guards,
`check_threaded()`, and the fit-consumption accessors (`fit_backend()`,
`backend_draws_array()`, `backend_extract()`, `backend_generate_quantities()`,
`backend_has_draws()`). The script is package-agnostic: the model is resolved
against each package's own `stanmodels`, the package name via
`utils::packageName()`, and dropped parameters via a `drop_pars` argument.

## Adopting it

From a host package:

```r
usethis::use_standalone("ACCIDDA/flexstanr", "backends")
```

This vendors `R/standalone-backends.R` into the host as
`R/import-standalone-backends.R`. Then declare the dependencies (see the notes
at the top of the standalone file):

```r
usethis::use_package("rstan")                # default backend (hard dependency)
usethis::use_package("utils")                # utils::packageName()
usethis::use_package("tools")                # tools::R_user_dir()
usethis::use_package("cmdstanr", "Suggests") # optional backend
```

cmdstanr is not on CRAN. A host that Suggests it also needs, in DESCRIPTION,
`Additional_repositories: https://stan-dev.r-universe.dev` and (for pak-based CI,
which does not read that field) `Remotes: stan-dev/cmdstanr`.

## Re-syncing

`use_standalone()` re-fetches the current version, so hosts stay in sync by
re-running it (this can be wired into CI). The standalone file is the source of
truth: edit it here, not in the vendored copies.

## History

Extracted from ACCIDDA/imuGAP (see imuGAP#112) so imuGAP, hestia, and
SeverityEstimate share one backend implementation.
