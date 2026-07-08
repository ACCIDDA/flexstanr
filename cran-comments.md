## Submission

This is a new package. flexstanr is a portable Stan-backend layer: it gives a
Stan-based R package one interface for fitting its models through either 'rstan'
or, optionally, 'cmdstanr', plus backend-agnostic accessors for reading a fit.

## R CMD check results

0 errors | 0 warnings | 1 note

The one note is the CRAN incoming-feasibility note, covering two expected
points:

* New submission.
* Suggests or Enhances not in mainstream repositories: cmdstanr. cmdstanr is an
  optional backend, used only through requireNamespace() guards, so the package
  installs, checks, and runs its tests without it. CmdStan's r-universe is
  declared in Additional_repositories, and the check confirms cmdstanr is
  reachable there.

## Examples

fit_model() and the backend_*() accessors use \dontrun because they need a host
package's compiled Stan model and a fitted object, neither of which can be
constructed inside the example. use_flexstanr() uses \dontrun because it edits
the DESCRIPTION of the package it is run from. stan_options() and
backend_has_draws() have fully runnable examples.

## Test environments

* GitHub Actions: ubuntu-latest (release, oldrel, devel), macOS-latest
  (release), windows-latest (release). All passing.
* win-builder (release and devel): to run immediately before submission.
* R-hub: to run immediately before submission.

## Before submitting (maintainer checklist)

* Remove the dev-only Remotes field from DESCRIPTION. pak-based CI uses it to
  install cmdstanr from GitHub; CRAN does not accept it, and
  Additional_repositories already covers the user-facing case.
* Run win-builder (release and devel) and R-hub, and fold their results into the
  test-environments section above.
