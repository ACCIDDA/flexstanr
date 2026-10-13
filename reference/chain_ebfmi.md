# Fallback E-BFMI for one chain's post-warmup energy

Used only when the reference cannot report a valid chain independently.

## Usage

``` r
chain_ebfmi(energy)
```

## Arguments

- energy:

  numeric vector of `energy__` values for one chain.

## Value

a numeric scalar, or `NA` when undefined (fewer than three iterations,
non-finite energy, zero variance, or numerical overflow).
