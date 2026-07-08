## Submission

This is a new package. flexstanr is a portable Stan-backend layer: it gives a
Stan-based R package one interface for fitting its models through either rstan
or, optionally, cmdstanr, plus backend-agnostic accessors for reading a fit.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
    Maintainer: 'Carl Pearson <carl.ab.pearson@gmail.com>'
    New submission.

The only note is the standard new-submission note.

## Test environments

* GitHub Actions: ubuntu-latest (release, oldrel, devel), macOS-latest
  (release), windows-latest (release) -- all passing.
* win-builder (release + devel) -- to run immediately before submission.
* R-hub -- to run immediately before submission.

## Optional cmdstanr backend

cmdstanr is an optional backend. It is used only through `requireNamespace()`
guards, so the package installs, checks, and runs its tests without it. cmdstanr
is not on CRAN; CmdStan's r-universe is declared in `Additional_repositories`
for users who want that backend.

## Before submitting (maintainer checklist)

* Remove the dev-only `Remotes:` field from DESCRIPTION (it exists so pak-based
  CI can install cmdstanr from GitHub; CRAN does not accept it, and
  `Additional_repositories` already covers the user-facing case).
* Run win-builder (release + devel) and R-hub, and fold their results into the
  "Test environments" section above.
