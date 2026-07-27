# cmdstanr compile options for a threading allocation

Returns the `cpp_options` needed to compile a cmdstanr model with
within-chain threading, or `NULL` when the allocation asks for a single
thread (no threading). Split out of `fit_cmdstanr()` so the compile-time
decision is unit-testable without the CmdStan toolchain.

## Usage

``` r
threading_cpp_options(threads_per_chain)
```

## Arguments

- threads_per_chain:

  the per-chain thread count from the sampler options (may be `NULL`
  when unset).

## Value

`list(stan_threads = TRUE)` when more than one thread is requested,
otherwise `NULL`.
