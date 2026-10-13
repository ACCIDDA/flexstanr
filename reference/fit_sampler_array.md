# A fit's post-warmup sampler parameters, for either backend

A fit's post-warmup sampler parameters, for either backend

## Usage

``` r
fit_sampler_array(raw_fit)
```

## Arguments

- raw_fit:

  a backend-native fit object.

## Value

a plain iterations x chains x variables array, or `NULL` for cmdstanr
fixed-parameter fits, which do not expose sampler diagnostics.
