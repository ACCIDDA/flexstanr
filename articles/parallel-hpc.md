# Parallel and threaded fitting (including HPC)

Fitting is the expensive part of most Stan analyses. flexstanr can put
your machine’s spare cores to work for you from a single switch:

``` r

stan_options(threading = TRUE)
```

That is the whole user story. This article explains what it does, how to
shape it (a core cap, HPC allocation), and the one thing a *model
author* has to add so the switch behaves well on a model that cannot
thread.

## What `threading = TRUE` does

A fit can use cores two ways at once:

1.  **Across chains.** MCMC chains are independent, so they run in
    parallel with near-linear speedup and no coordination overhead.
2.  **Within a chain (threading).** If your Stan model sums a
    conditionally-independent term with `reduce_sum()` (or `map_rect`),
    each chain can split that sum across threads.

`stan_options(threading = TRUE)` looks at the cores the process is
allowed to use, **fills chain-parallelism first** (it is “free” – no
threading overhead), gives the leftover cores to threads, writes the
result onto the options, and **tells you what it chose**:

``` r

opts <- stan_options(chains = 4, threading = TRUE)
#> flexstanr: threading enabled. Using 16 of 16 available cores: 4 chains in
#> parallel, 4 threads per chain. Pass max_cores to leave some cores free.
```

The split, given a pool of cores to divide (the pool is all your
machine’s cores, or your `max_cores`):

| chains | cores to split | chains in parallel | threads per chain |
|-------:|---------------:|-------------------:|------------------:|
|      4 |              4 |                  4 |      1 (no spare) |
|      4 |              8 |                  4 |                 2 |
|      4 |             16 |                  4 |                 4 |
|      2 |              8 |                  2 |                 4 |

So threading only “switches on” when the pool has more cores than chains
– otherwise every core is spent running chains. Because the default uses
all your cores, an 8-core machine running 4 chains splits a pool of 8 (4
chains, 2 threads each).

You then fit as usual;
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
applies the allocation to whichever backend you are on (and, for
cmdstanr, compiles the model with threading enabled):

``` r

fit <- fit_model("my_model", dat_stan = dat, init = init, stan_opts = opts)
```

## Capping the cores

By default `threading = TRUE` uses **all available cores**. If your
machine becomes unresponsive during a fit, cap it with `max_cores` (e.g.
`max_cores = 4`):

``` r

# use at most 4 cores, however many the machine has
stan_options(chains = 4, threading = TRUE, max_cores = 4)
```

`threading = FALSE` (the default) leaves parallelism untouched, so you
can still set `cores` (rstan) or `parallel_chains` / `threads_per_chain`
(cmdstanr) by hand if you want full manual control.

## Model authors: warn when threads can’t be used

Threading only helps if the model actually uses
`reduce_sum()`/`map_rect` and was compiled for threading. flexstanr
cannot know that about *your* model – so if you write a fit function on
top of flexstanr, check whether the caller asked for threads and warn
when your model can’t use them.
[`test_threaded()`](https://accidda.github.io/flexstanr/reference/test_threaded.md)
reports what the options request:

``` r

run_my_fit <- function(dat_stan, init, stan_opts = stan_options()) {
  if (test_threaded(stan_opts) && !model_is_threaded) {
    warning(
      "threads were requested but this model does not use reduce_sum(); ",
      "it will run one thread per chain. Run more chains, use the threaded ",
      "model variant, or set threading = FALSE.",
      call. = FALSE
    )
  }
  fit_model("my_model", dat_stan = dat_stan, init = init, stan_opts = stan_opts)
}
```

This keeps the division of labor clean: the *user* just says
`threading = TRUE`, and the *model author* – the only one who knows
whether the model can thread – tips them off when it won’t take effect.

## How flexstanr decides how many cores to use

It asks
[`parallelly::availableCores()`](https://parallelly.futureverse.org/)
for the number of cores the **process is allowed** to use – crucially
**not**
[`parallel::detectCores()`](https://rdrr.io/r/parallel/detectCores.html).
It respects

- the HPC scheduler’s allocation (`SLURM_CPUS_PER_TASK`, PBS, SGE, LSF),
- cgroup CPU quotas (containers, cpuset),
- `options(mc.cores = ...)`,

and returns 2 under `R CMD check`. This makes `threading = TRUE` safe to
use even on a shared cluster.

### Compiling your model for threading

Within-chain threads only do anything if the model was **compiled with
threading**:

- **cmdstanr** –
  [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
  compiles with `cpp_options = list(stan_threads = TRUE)` automatically
  when the allocation asks for more than one thread, into a separate
  cache directory so a threaded and a non-threaded build coexist.
  Nothing to do.
- **rstan** – the host package’s models must have been built with
  threading support (a package-build concern); flexstanr only sets
  `STAN_NUM_THREADS` around the fit. If a model was not built for
  threading, the setting is inert – which is exactly what
  [`test_threaded()`](https://accidda.github.io/flexstanr/reference/test_threaded.md)
  lets you warn about.

## On a laptop or workstation

Nothing to do: `threading = TRUE` detects your cores and splits them,
using all of them. To leave some free, use `max_cores`, or cap globally
with `mc.cores`:

``` r

options(mc.cores = 6)
stan_options(chains = 4, threading = TRUE)   # sees at most 6 cores
```

## On an HPC cluster

### The trap to avoid

[`parallel::detectCores()`](https://rdrr.io/r/parallel/detectCores.html)
reports **every** core on the compute node (often 64, 128+) regardless
of your job’s allocation. A fit sizing itself from that would launch
dozens of threads inside a job pinned to a handful of cores; the
scheduler’s cgroup would throttle it to a crawl. Because
`threading = TRUE` uses
[`parallelly::availableCores()`](https://parallelly.futureverse.org/reference/availableCores.html),
it reads your *allocation* instead.

### Single node: let flexstanr split your allocation

Request one task with several CPUs and let `threading = TRUE` divide
them. For 4 chains x 2 threads (8 cores):

``` bash
#!/bin/bash
#SBATCH --job-name=stan-fit
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8      # availableCores() will report 8
#SBATCH --mem=16G
#SBATCH --time=04:00:00
Rscript fit.R
```

``` r

# fit.R -- no core arithmetic; availableCores() picks up SLURM_CPUS_PER_TASK = 8
opts <- stan_options(chains = 4, iter = 2000, threading = TRUE)
fit  <- fit_model("my_model", dat_stan = dat, init = init, stan_opts = opts)
saveRDS(fit, "fit.rds")
```

### Many chains across nodes: one chain per array task

Chain-parallelism and threads are **shared-memory**: they cannot span
nodes. To scale beyond a single node, run **one chain per job** with a
SLURM array, give each job all its cores for threading, and combine the
single-chain fits after.

``` bash
#SBATCH --array=1-4            # one task per chain
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8      # all 8 cores -> threads for this one chain
```

``` r

i    <- Sys.getenv("SLURM_ARRAY_TASK_ID")
opts <- stan_options(chains = 1, seed = as.integer(i), threading = TRUE)
fit  <- fit_model("my_model", dat_stan = dat, init = init, stan_opts = opts)
saveRDS(fit, sprintf("chain-%s.rds", i))
```

[`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
is otherwise for how the sampler explores (`iter`, `warmup`, `seed`,
`control = list(adapt_delta = ...)`, …); `threading` is the one knob
that reaches out to the machine.
