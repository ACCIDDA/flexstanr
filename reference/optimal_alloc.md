# Split available cores between chain-parallelism and within-chain threads

Decides how many chains to run in parallel and how many threads each
chain gets. Chain-parallelism has no threading overhead and scales
~linearly, so it is filled first; any leftover cores become per-chain
threads: `parallel_chains = min(chains, cores)` and
`threads_per_chain = max(1L, cores %/% parallel_chains)`. Cores that do
not divide evenly are left idle rather than rebalanced.

## Usage

``` r
optimal_alloc(chains, cores)
```

## Arguments

- chains:

  number of MCMC chains (a single positive integer).

- cores:

  total cores to split (a single positive integer).

## Value

a list with integer elements `parallel_chains` and `threads_per_chain`.
