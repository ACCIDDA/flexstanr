# Extract a fit into rstan::extract()'s list-of-arrays shape

Extract a fit into rstan::extract()'s list-of-arrays shape

## Usage

``` r
extract_par_list(raw_fit, pars = NULL, ...)
```

## Arguments

- raw_fit:

  a backend-native fit object (an rstan `stanfit` or a cmdstanr
  `CmdStanMCMC`).

- pars:

  character vector of parameter names to extract (a single name is
  fine). Use the base name of a container parameter (`"theta"`, not
  `"theta[1]"`). `NULL`, the default, extracts every parameter,
  including `lp__`.

- ...:

  forwarded verbatim to the backend's own extractor, and accepted only
  by `format = "list"`. Arguments that change the return shape (for
  instance
  [`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)'s
  `permuted = FALSE`) take the result outside the contract above; prefer
  `format = "draws"` for a chain-preserving array.

## Value

a named list of draw arrays, one per parameter.
