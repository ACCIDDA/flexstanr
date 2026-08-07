# Parameter base names behind a set of flat draw variable names

Stan flattens a container parameter into indexed variables (`theta[1]`,
`theta[2]`, ...). This strips the index suffix to recover the base names
callers use with `pars`, keeping first-appearance order.

## Usage

``` r
par_base_names(vars)
```

## Arguments

- vars:

  flat variable names, e.g. from
  [`posterior::variables()`](https://mc-stan.org/posterior/reference/variables.html).

## Value

unique base names, in order.
