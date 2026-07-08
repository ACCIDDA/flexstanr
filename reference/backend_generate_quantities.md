# Run generated quantities against a fit and return a parameter matrix

Run generated quantities against a fit and return a parameter matrix

## Usage

``` r
backend_generate_quantities(
  raw_fit,
  data,
  draws_mat,
  pars,
  model_name = NULL,
  package = caller_package()
)
```

## Arguments

- raw_fit:

  a backend-native fit object (an rstan `stanfit` or a cmdstanr
  `CmdStanMCMC`).

- data:

  the Stan data list for the generated-quantities run.

- draws_mat:

  a draws matrix (rows = draws, columns = parameters). Used by the rstan
  backend; the cmdstanr backend runs generated quantities against the
  fit's own draws and ignores this argument.

- pars:

  name of the generated parameter to return.

- model_name:

  name of the model whose generated-quantities block to run. Required by
  the cmdstanr backend, which recompiles the model to run it; ignored by
  rstan, which reuses the model carried on `raw_fit`.

- package:

  the host package the model belongs to; defaults to the calling package
  (see
  [`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)).
  Only used by the cmdstanr backend.

## Value

a matrix of the requested generated parameter (rows = draws).

## Examples

``` r
if (FALSE) { # \dontrun{
gen <- backend_generate_quantities(fit, data = data_list,
                                   draws_mat = as.matrix(fit), pars = "y_rep")
} # }
```
