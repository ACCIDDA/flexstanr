# Extract parameters from a fit, in a chosen format

The backend-agnostic way to read a fit's posterior. `format` selects the
representation, and each format has the same shape whichever backend
produced the fit, so downstream math does not have to branch on the
backend:

- `"list"` (the default) matches
  [`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html):
  a named list with one entry per parameter, chains merged into a single
  draw dimension that comes first, a true scalar parameter collapsed to
  a bare length-`S` vector, and a `vector[1]` kept as an `S x 1` matrix.
  The rstan backend delegates to
  [`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)
  itself; the cmdstanr backend reshapes its draws to match.

- `"draws"` returns a
  [posterior::draws_array](https://mc-stan.org/posterior/reference/draws_array.html)
  (iteration x chain x variable), keeping the chain structure and the
  flat Stan variable names.

- `"matrix"` returns a plain base matrix with one row per draw (chains
  stacked) and one column per flat variable, the shape
  [`backend_generate_quantities()`](https://accidda.github.io/flexstanr/reference/backend_generate_quantities.md)
  takes as `draws_mat`.

`"draws"` and `"matrix"` preserve iteration-chain draw order on both
backends. `"list"` does not:
[`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)
permutes draws by default while the cmdstanr path does not, which is
immaterial for the exchangeable -sample uses these draws are put to but
means the two backends' `"list"` output agrees as a sample, not draw for
draw.

## Usage

``` r
backend_extract(
  raw_fit,
  pars = NULL,
  format = c("list", "draws", "matrix"),
  ...
)
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

- format:

  the representation to return, one of `"list"` (the default),
  `"draws"`, or `"matrix"`; see Description.

- ...:

  forwarded verbatim to the backend's own extractor, and accepted only
  by `format = "list"`. Arguments that change the return shape (for
  instance
  [`rstan::extract()`](https://mc-stan.org/rstan/reference/stanfit-method-extract.html)'s
  `permuted = FALSE`) take the result outside the contract above; prefer
  `format = "draws"` for a chain-preserving array.

## Value

the fit's draws for `pars`, in the requested `format`.

## See also

[`backend_draws_array()`](https://accidda.github.io/flexstanr/reference/backend_draws_array.md)
for the raw iterations x chains x parameters array, and
[`backend_generate_quantities()`](https://accidda.github.io/flexstanr/reference/backend_generate_quantities.md),
whose `draws_mat` argument takes `format = "matrix"` output.

## Examples

``` r
if (FALSE) { # \dontrun{
# rstan::extract()-compatible, the shape most existing code expects
post <- backend_extract(fit, pars = c("beta", "sigma"))
colMeans(post$beta)

# every parameter, no `pars` needed
all_post <- backend_extract(fit)

# backend-neutral posterior draws, chains kept
draws <- backend_extract(fit, format = "draws")

# a draws x parameters matrix, ready for backend_generate_quantities()
mat <- backend_extract(fit, format = "matrix")
} # }
```
