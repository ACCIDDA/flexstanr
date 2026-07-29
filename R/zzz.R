# flexstanr fits through rstan or cmdstanr but hard-requires neither: both live
# in Suggests and are resolved at run time (see assert_backend_available()). Warn
# once, at attach, only when NEITHER backend is installed, so the missing-backend
# failure is visible up front rather than at the first stan_options() call.
# Auto-installing a backend is CRAN-forbidden, so this only points the user at
# the install commands.
.onAttach <- function(libname, pkgname) {
  msg <- missing_backend_message()
  if (!is.null(msg)) {
    packageStartupMessage(msg)
  }
}

# The attach-time guidance, or NULL when at least one backend is installed.
# Factored out of .onAttach() so it is unit-testable without invoking the hook.
missing_backend_message <- function() {
  if (backend_installed("rstan") || backend_installed("cmdstanr")) {
    return(NULL)
  }
  paste0(
    "flexstanr needs a Stan backend, but neither 'rstan' nor 'cmdstanr' is ",
    "installed.\n",
    "Install one to fit models: install.packages('rstan'), or cmdstanr from ",
    "https://mc-stan.org/cmdstanr/."
  )
}
