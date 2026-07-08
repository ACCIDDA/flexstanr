# Resolve a host package's compiled rstan model

Looks up `model_name` in the calling package's `stanmodels` object (the
`rstantools`-generated registry of compiled models). This replaces the
ambient `stanmodels[[model_name]]` lookup that worked only when this
code was vendored into the host: as an imported package, flexstanr must
reach into the host's namespace explicitly.

## Usage

``` r
get_stanmodel(package, model_name)
```

## Arguments

- package:

  the host package name.

- model_name:

  the model to resolve.

## Value

the compiled `stanmodel` object.
