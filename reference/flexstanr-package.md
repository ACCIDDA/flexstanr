# flexstanr: Portable Backend Layer for 'Stan' Models

Gives a 'Stan'-based R package one interface for fitting its models
through either 'rstan' or (optionally) 'cmdstanr'. Collects and
validates sampler options, guarding against mixing one backend's
argument vocabulary into the other, dispatches the fit to the chosen
backend, and exposes backend-agnostic accessors for reading posterior
draws, extracting parameters, and running generated quantities. The host
package supplies its own compiled models; flexstanr resolves them from
the calling package at run time, so the same code works whichever
backend is installed.

## See also

Useful links:

- <https://accidda.github.io/flexstanr/>

- <https://github.com/ACCIDDA/flexstanr>

- Report bugs at <https://github.com/ACCIDDA/flexstanr/issues>

## Author

**Maintainer**: Carl Pearson <carl.ab.pearson@gmail.com>
([ORCID](https://orcid.org/0000-0003-0701-7860))

Authors:

- Carl Pearson <carl.ab.pearson@gmail.com>
  ([ORCID](https://orcid.org/0000-0003-0701-7860))

- Weston Voglesonger <westonvogle@gmail.com>
