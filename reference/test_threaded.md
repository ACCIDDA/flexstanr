# Does a set of sampler options ask for within-chain threading?

A host package's fit function calls this to learn whether the caller
requested within-chain threading – via `stan_options(threading = TRUE)`,
or by setting `threads_per_chain` directly – so it can warn when its
model cannot make use of the offered threads (for example a model with
no `reduce_sum` term, or one the host did not compile for threading). It
reports what the *options* ask for, not whether the model can honor it:
only the model's author knows that, which is why the check (and any
resulting warning) belongs in the host's fit function rather than in
flexstanr.

## Usage

``` r
test_threaded(stan_opts)
```

## Arguments

- stan_opts:

  a
  [`stan_options()`](https://accidda.github.io/flexstanr/reference/stan_options.md)
  result.

## Value

logical; `TRUE` if the options request more than one thread per chain,
otherwise `FALSE`.

## Examples

``` r
test_threaded(stan_options(chains = 2))                 # FALSE (not requested)
#> [1] FALSE
test_threaded(list(threads_per_chain = 4L))             # TRUE
#> [1] TRUE
```
