# flexstanr

<!-- badges: start -->
<!-- badges: end -->

A **portable Stan-backend layer** for R packages that fit a Stan model. It gives
a host package one interface for fitting through either
[rstan](https://mc-stan.org/rstan/) or
[cmdstanr](https://mc-stan.org/cmdstanr/), neither of which is required to
install flexstanr, so the same code works whichever backend is installed.

flexstanr compiles no Stan of its own: the host package supplies its own compiled
models, and flexstanr resolves them from the calling package at run time.

## What it provides

- `stan_options()` validates common sampler arguments and forwards arbitrary
  same-backend arguments **verbatim** to the native sampler for validation.
  Reserved fitting inputs are rejected, as is known vocabulary from the other
  backend (with a "did you mean" hint).
- `fit_model()` dispatches the fit to the backend recorded on the options,
  resolving the compiled model by name from the calling package.
- The fit-consumption accessors read a fit backend-agnostically:
  `backend_draws_array()`, `backend_extract()`, `backend_generate_quantities()`,
  and `backend_has_draws()`.
- `stan_options(threading = TRUE)` turns on scheduler-aware threading: it splits
  the cores the process is allowed to use (via `parallelly::availableCores()`,
  respecting HPC schedulers and cgroup quotas) between running chains in parallel
  and within-chain (`reduce_sum`) threads, draws on all available cores by default
  (cap the pool with `max_cores`), and messages what it chose. `test_threaded()`
  lets a host package's fit function detect that within-chain threads were
  requested, so it can warn when its own model cannot use them.
- `use_flexstanr()` wires flexstanr into a host package once: it adds flexstanr
  to the host's `Imports` and generates the re-export file that keeps
  `yourpkg::stan_options()` resolving. It adds no Stan backend of its own.

## Installation

Install the released version from CRAN:

```r
install.packages("flexstanr")
```

Or the development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("ACCIDDA/flexstanr")
```

flexstanr depends on neither backend directly: rstan and cmdstanr are both
optional, so you install whichever you use. rstan is the default backend and is
on CRAN (`install.packages("rstan")`); cmdstanr is not on CRAN, so install it
separately (see the cmdstanr [getting-started guide](https://mc-stan.org/cmdstanr/)).
Selecting a backend whose package is not installed fails with an actionable
message that names the install command (or points you at the other backend), and
loading flexstanr with neither backend installed prints a one-time startup
message at attach.

## Using it in your package

Declare flexstanr as a dependency and call it from your own fitting code:

```r
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

The model name is resolved against your package's own compiled models
(`stanmodels` for rstan, `inst/stan/<name>.stan` for cmdstanr); the calling
package is detected automatically. Run `flexstanr::use_flexstanr()` once from
your package root to add flexstanr to your `Imports` and generate the
`R/flexstanr.R` re-export file (so `yourpkg::stan_options()` keeps resolving). It
does not add a Stan backend, so declare whichever backend (rstan or cmdstanr) you
use yourself. Its signature mirrors `usethis::use_package()` (`min_version`,
`remote`).

## Parallel and threaded fitting

Turn on scheduler-aware parallelism with a single switch:

```r
opts <- flexstanr::stan_options(chains = 4, threading = TRUE)
#> flexstanr: threading enabled. Using 16 of 16 available cores: 4 chains in
#> parallel, 4 threads per chain. Pass max_cores to leave some cores free.
fit  <- flexstanr::fit_model(
  "coverage",
  dat_stan  = data_list,
  init      = init_list,
  stan_opts = opts
)
```

`threading = TRUE` fills chain-parallelism first (it carries no threading
overhead), gives the leftover cores to within-chain threads, and applies the
split to whichever backend you use. By default it draws on all available cores;
any that do not divide evenly across the chains are left idle rather than
rebalanced. Pass `max_cores` to cap the pool:

```r
opts <- flexstanr::stan_options(chains = 4, threading = TRUE, max_cores = 8)
```

For the cmdstanr backend `fit_model()` also compiles the model with threading
enabled; for rstan, the host package's models must already have been built with
threading support, and flexstanr only sets `STAN_NUM_THREADS` around the fit.
Within-chain threads only help a model that sums a conditionally-independent term
with `reduce_sum()`; flexstanr allocates the threads regardless, but whether they
speed anything up is a property of the model.

If you write a fit function on top of flexstanr, use `test_threaded()` to warn
when threads were requested but your model cannot use them:

```r
run_my_fit <- function(dat_stan, init, stan_opts = flexstanr::stan_options()) {
  # model_is_threaded: your own check of whether this model uses reduce_sum()
  if (flexstanr::test_threaded(stan_opts) && !model_is_threaded) {
    warning(
      "threads were requested but this model does not use reduce_sum(); ",
      "it will run one thread per chain.",
      call. = FALSE
    )
  }
  flexstanr::fit_model("coverage", dat_stan = dat_stan, init = init, stan_opts = stan_opts)
}
```

`test_threaded()` reports what the options ask for, not whether the model can
honor it, so the warning belongs in your fit function where the model is known.
See the "Parallel and threaded fitting" vignette
(`vignette("parallel-hpc", package = "flexstanr")`) for core caps and HPC
(SLURM) job layouts.

## Background

> **Note.** flexstanr began as a `use_standalone()` script vendored into the
> ACCIDDA Stan packages (imuGAP, hestia, SeverityEstimate). It is now a proper
> package those consumers import rather than copy. See the
> [flexstanr 0.1.0 CRAN release](https://github.com/ACCIDDA/flexstanr/milestone/1)
> milestone.

## License

MIT (c) ACCIDDA.
