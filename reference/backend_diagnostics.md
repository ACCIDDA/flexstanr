# Convergence and sampler diagnostics for a fit

The backend-agnostic way to read the numbers used to judge whether a fit
can be trusted. The result has the same shape whichever backend produced
the fit.

`backend_diagnostics()` only reports; it applies no thresholds and
signals no warnings. Deciding what counts as a failed fit is left to the
caller. The current Stan guidance (Vehtari et al. 2021) is R-hat below
1.01, bulk and tail ESS of at least 100 per chain, and no divergent
transitions.

R-hat and ESS are computed by the 'posterior' package on both backends.
The sampler diagnostics delegate to cmdstanr's `diagnostic_summary()`
and rstan's `get_bfmi()`. RStan's divergence and treedepth helpers
return totals, so their counts are computed per chain here. Undefined
E-BFMI values are normalized to `NA`; a per-chain fallback preserves
valid chains when cmdstanr cannot report them independently of a chain
with missing energy. A post-warmup transition whose tree depth reaches
`max_treedepth` counts as a hit, and E-BFMI is
`sum(diff(energy)^2) / (N * var(energy))` for each chain, where `N` is
its number of post-warmup iterations.

## Usage

``` r
backend_diagnostics(raw_fit, pars = NULL)
```

## Arguments

- raw_fit:

  a backend-native fit object (an rstan `stanfit` or a cmdstanr
  `CmdStanMCMC`).

- pars:

  character vector of parameter base names to summarize, with the same
  meaning as in
  [`backend_extract()`](https://accidda.github.io/flexstanr/reference/backend_extract.md).
  `NULL`, the default, summarizes every parameter, including `lp__`,
  transformed parameters, and generated quantities; pass the parameters
  you care about to limit the cost on large models. The per-chain
  diagnostics are unaffected by `pars`.

## Value

a list with elements:

- `parameters`: a `data.frame` with one row per flat variable and
  columns `variable`, `rhat`, `ess_bulk`, and `ess_tail`. A value is
  `NA` when it cannot be computed, e.g. for a variable that is constant
  across draws.

- `chains`: a `data.frame` with one row per chain and columns `chain`,
  `num_divergent`, `num_max_treedepth`, and `ebfmi` (all post-warmup). A
  column is `NA` when the sampler did not record it (e.g.
  `algorithm = "Fixed_param"`); `ebfmi` is also `NA` for chains shorter
  than three iterations, non-finite energy, zero energy variance, or
  numerical overflow.

- `n_chains`: the number of chains.

- `n_iter`: the number of post-warmup iterations per chain.

- `max_treedepth`: the maximum tree depth setting the fit ran with, or
  `NA` when unavailable (e.g. a cmdstanr fixed-parameter fit).

## See also

[`backend_has_draws()`](https://accidda.github.io/flexstanr/reference/backend_has_draws.md)
for the earlier check that a fit produced any draws at all.

## Examples

``` r
if (FALSE) { # \dontrun{
diag <- backend_diagnostics(fit, pars = c("beta", "sigma"))
max(diag$parameters$rhat, na.rm = TRUE) < 1.01
sum(diag$chains$num_divergent) == 0
} # }
```
