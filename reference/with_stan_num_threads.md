# Run an expression with STAN_NUM_THREADS set, restoring it afterwards

rstan reads `STAN_NUM_THREADS` at sampling time. This sets it for the
duration of `expr` and restores the previous value afterwards (clearing
it if it was unset), so a fit does not leak its per-chain thread count
into the rest of the session.

## Usage

``` r
with_stan_num_threads(threads, expr)
```

## Arguments

- threads:

  the per-chain thread count to expose.

- expr:

  the expression to evaluate with the variable set (lazily, so it runs
  *after* the variable is in place).

## Value

the value of `expr`.
