# Name of the package that called into flexstanr

flexstanr resolves a host's compiled model from the host's own
namespace, so it must know which package called it. This walks out to
the top-level environment of the calling frame and returns its package
name. Returns `NULL` when called from the global environment or another
context without a package (e.g. interactively), so callers can fail with
an actionable message.

## Usage

``` r
caller_package(env = parent.frame())
```

## Arguments

- env:

  the environment to resolve from; defaults to the caller's frame.

## Value

the calling package's name, or `NULL` if there is none.
