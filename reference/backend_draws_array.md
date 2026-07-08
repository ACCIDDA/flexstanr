# Posterior draws of a fit as an iterations x chains x parameters array

Posterior draws of a fit as an iterations x chains x parameters array

## Usage

``` r
backend_draws_array(raw_fit)
```

## Arguments

- raw_fit:

  a backend-native fit object (an rstan `stanfit` or a cmdstanr
  `CmdStanMCMC`).

## Value

a 3-D array, dimensions iterations x chains x parameters.

## Examples

``` r
if (FALSE) { # \dontrun{
draws <- backend_draws_array(fit)
dim(draws) # iterations x chains x parameters
} # }
```
