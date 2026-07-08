# Run cmdstanr generated quantities for a host model

Resolves the host's `.stan` model the same way
[`fit_model()`](https://accidda.github.io/flexstanr/reference/fit_model.md)
does, compiles it into a writable cache, and runs its
generated-quantities block against the fitted draws.

## Usage

``` r
run_cmdstanr_gq(model_name, package, raw_fit, data)
```

## Arguments

- model_name:

  the model to run.

- package:

  the host package the model belongs to.

- raw_fit:

  the fitted `CmdStanMCMC` supplying the parameter draws.

- data:

  the Stan data list for the generated-quantities run.

## Value

a `CmdStanGQ` object.
