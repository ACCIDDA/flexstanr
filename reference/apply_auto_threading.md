# Automatically allocate and record threading on a stan_options result

Backs
[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)'s
`threading = TRUE`. Detects the cores the process is *allowed* to use
with
[`parallelly::availableCores()`](https://parallelly.futureverse.org/reference/availableCores.html)
(which respects the HPC scheduler's allocation – `SLURM_CPUS_PER_TASK`,
PBS, SGE, LSF – cgroup CPU quotas, `getOption("mc.cores")`, and returns
2 under `R CMD check`, so it never over-subscribes a scheduled job),
uses all available cores by default (or caps the pool at `max_cores`),
splits them across the chains with
[`optimal_alloc()`](https://accidda.github.io/flexstanr/reference/optimal_alloc.md),
writes the result with
[`write_threading()`](https://accidda.github.io/flexstanr/reference/write_threading.md),
and messages the chosen allocation so the choice is never silent.

## Usage

``` r
apply_auto_threading(res, max_cores = NULL)
```

## Arguments

- res:

  a
  [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  result (backend and chains already recorded).

- max_cores:

  optional cap on the cores used; `NULL` uses all available cores.

## Value

`res`, with threading allocated and recorded.
