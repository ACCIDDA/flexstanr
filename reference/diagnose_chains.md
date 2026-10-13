# Per-chain sampler diagnostics

Per-chain sampler diagnostics

## Usage

``` r
diagnose_chains(sampler, max_treedepth, reference = NULL)
```

## Arguments

- sampler:

  a plain iterations x chains x variables array of post-warmup sampler
  parameters (`divergent__`, `treedepth__`, `energy__`, ...).

- max_treedepth:

  the run's maximum tree depth setting.

- reference:

  named list or data frame of available backend summaries.

## Value

a base `data.frame` with one row per chain and columns `chain`,
`num_divergent`, `num_max_treedepth`, and `ebfmi`. A diagnostic whose
sampler column is absent (e.g. `algorithm = "Fixed_param"`) is `NA`.
