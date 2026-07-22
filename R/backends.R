# A portable Stan-backend layer (rstan, with an optional cmdstanr backend) for R
# packages that fit a Stan model. Option construction, the cross-backend
# vocabulary guard, the per-backend fit functions, and the backend-agnostic
# fit-consumption accessors. Each fit function forwards the user's
# stan_options() verbatim to that backend's native sampler, so calls feel like
# using rstan / cmdstanr directly.
#
# flexstanr compiles no Stan of its own: the model is selected by `model_name`
# and resolved against the *calling* package's own `stanmodels` (rstan) or
# `inst/stan/` sources (cmdstanr). The calling package is detected automatically
# (see caller_package()) or passed explicitly via `package`.

# cmdstanr-only argument names, shown when the active backend is rstan (i.e. the
# user reached for a cmdstanr word), each mapped to the rstan way to do it.
cmdstanr_hints <- c(
  parallel_chains   = "use `cores`",
  iter_warmup       = "use `iter` (with `warmup`)",
  iter_sampling     = "use `iter` (with `warmup`)",
  adapt_delta       = "set inside `control = list(adapt_delta = ...)`",
  max_treedepth     = "set inside `control = list(max_treedepth = ...)`",
  step_size         = "set inside `control = list(stepsize = ...)`",
  threads_per_chain = "set `Sys.setenv(STAN_NUM_THREADS = n)`; chains parallelize via `cores`",
  output_dir        = "no rstan equivalent",
  sig_figs          = "no rstan equivalent"
)

# rstan-only argument names, shown when the active backend is cmdstanr, mapped to
# the cmdstanr way to do it.
rstan_hints <- c(
  cores           = "use `parallel_chains`",
  control         = "set `adapt_delta`/`max_treedepth`/`step_size` as top-level arguments",
  iter            = "use `iter_warmup` and `iter_sampling`",
  warmup          = "use `iter_warmup`",
  pars            = "not supported by the cmdstanr backend",
  include         = "not supported by the cmdstanr backend",
  sample_file     = "no cmdstanr equivalent",
  diagnostic_file = "no cmdstanr equivalent"
)

#' Assert that no foreign-backend argument vocabulary was used
#'
#' Errors if any argument name belongs to the *other* backend's vocabulary,
#' with a "did you mean" hint. On success returns the argument names invisibly.
#'
#' @param arg_names names of the arguments supplied to [stan_options()].
#' @param backend the backend the options are being built for.
#' @returns `arg_names`, invisibly.
#' @keywords internal
assert_backend_vocab <- function(arg_names, backend) {
  foreign <- switch(
    backend,
    rstan    = cmdstanr_hints,
    cmdstanr = rstan_hints
  )
  bad <- intersect(arg_names, names(foreign))
  if (length(bad) > 0) {
    bullets <- paste0("  - `", bad, "`: ", foreign[bad], collapse = "\n")
    stop(
      "These stan_options() arguments are not valid for the '", backend,
      "' backend:\n", bullets,
      call. = FALSE
    )
  }
  invisible(arg_names)
}

#' Assert a backend name is valid and its package is installed
#'
#' Validates `backend` against the known choices (so it also subsumes
#' `match.arg()`) and, for the optional cmdstanr backend, that its package is
#' installed. rstan is always available (a hard dependency); cmdstanr is
#' optional, so selecting it without the package installed fails early here
#' rather than deep inside the fit. Returns the validated backend invisibly.
#'
#' @param backend the backend to validate.
#' @returns the validated backend string, invisibly.
#' @keywords internal
assert_backend_available <- function(backend) {
  backend <- match.arg(backend, c("rstan", "cmdstanr"))
  if (backend == "cmdstanr" && !requireNamespace("cmdstanr", quietly = TRUE)) {
    stop(
      "backend = 'cmdstanr' requires the cmdstanr package, which is not ",
      "installed. Install it from https://mc-stan.org/cmdstanr/, or use ",
      "backend = 'rstan'.",
      call. = FALSE
    )
  }
  invisible(backend)
}

#' Positive-integer count arguments native to a backend's sampler
#'
#' @param backend one of `"rstan"` or `"cmdstanr"`.
#' @returns a character vector of argument names that must be positive integers.
#' @keywords internal
backend_int_args <- function(backend) {
  switch(
    backend,
    rstan    = c("iter", "chains", "warmup", "cores"),
    cmdstanr = c(
      "iter_warmup", "iter_sampling", "thin", "parallel_chains", "chains",
      "threads_per_chain"
    )
  )
}

#' Assert a value is a positive integer (vector)
#'
#' Errors on invalid input (non-numeric, empty, `NA`, non-integer, or
#' non-positive values); otherwise returns the value coerced to integer. Used to
#' validate count-like arguments.
#'
#' @param val the value to validate.
#' @param name the argument name, used in error messages.
#' @returns `val`, coerced to a positive integer (vector).
#' @keywords internal
assert_positive_int <- function(val, name) {
  if (!is.numeric(val)) {
    stop(sprintf("'%s' must be numeric", name), call. = FALSE)
  }
  if (length(val) < 1L) {
    stop(sprintf("length('%s') must be >= 1", name), call. = FALSE)
  }
  if (any(is.na(val))) {
    stop(sprintf("'%s' may not contain NAs", name), call. = FALSE)
  }
  if (any(val != as.integer(val))) {
    stop(sprintf("'%s' must be integers", name), call. = FALSE)
  }
  if (any(val < 1L)) {
    stop(sprintf("'%s' must be positive", name), call. = FALSE)
  }
  as.integer(val)
}

#' @title Stan Sampler Options
#'
#' @description
#' Collects and validates sampler arguments for the chosen `backend`, forwarding
#' them **verbatim** so calls feel native to that backend. Use the backend's own
#' argument names; mixing one backend's vocabulary into the other errors with a
#' hint. The model object is supplied separately (via [fit_model()]), while
#' `data` and `init` are constructed internally, so none of these may be set
#' here. `chains` defaults to `4` so downstream code can always size per-chain
#' structures from it.
#'
#' @inheritParams rstan::sampling
#' @param ... sampler arguments forwarded verbatim to the chosen backend's
#'   sampler. Use the backend's own names: for `"rstan"`, the
#'   [rstan::sampling()] arguments (`iter`, `cores`, `seed`); for
#'   `"cmdstanr"`, the `$sample()` arguments (`iter_warmup`, `iter_sampling`,
#'   `parallel_chains`, ...).
#' @param backend which Stan interface to target, one of `"rstan"` (default) or
#'   `"cmdstanr"`. Determines which argument vocabulary is accepted and which
#'   sampler [fit_model()] calls. Selecting `"cmdstanr"` errors if the cmdstanr
#'   package is not installed.
#'
#' @examples
#' stan_options()
#' stan_options(chains = 2, iter = 500)
#' if (requireNamespace("cmdstanr", quietly = TRUE)) {
#'   stan_options(backend = "cmdstanr", parallel_chains = 4, iter_warmup = 500)
#' }
#'
#' @return a named list of validated sampler arguments, carrying a `backend`
#'   element recording the backend it was built for
#' @export
stan_options <- function(..., chains = 4L, backend = "rstan") {
  backend <- assert_backend_available(backend)
  res <- list(...)
  if ("object" %in% names(res)) {
    stop(
      "Passing 'object' in stan_options is not allowed; ",
      "the model object should be supplied via fit_model() instead."
    )
  }
  if ("data" %in% names(res)) {
    stop(
      "Passing 'data' in stan_options is not allowed; ",
      "the 'data' argument is constructed internally by the fitting functions."
    )
  }
  if ("init" %in% names(res)) {
    stop(
      "Passing 'init' in stan_options is not allowed; ",
      "the 'init' values are constructed internally by the fitting functions."
    )
  }

  # Reject the other backend's vocabulary with a "did you mean" hint.
  assert_backend_vocab(names(res), backend)

  # `chains` is an explicit argument (default 4, valid for both backends); fold
  # it into the forwarded options so it is validated and passed through below.
  res$chains <- chains

  # Validate the positive-integer count arguments native to this backend.
  for (arg in intersect(names(res), backend_int_args(backend))) {
    if (length(res[[arg]]) != 1L) {
      stop(
        sprintf("'%s' must be a single positive integer", arg),
        call. = FALSE
      )
    }
    res[[arg]] <- assert_positive_int(res[[arg]], arg)
  }
  if ("seed" %in% names(res)) {
    val <- res[["seed"]]
    if (length(val) != 1L) {
      stop("'seed' must be a single value", call. = FALSE)
    }
    val <- suppressWarnings(as.integer(val))
    if (is.na(val)) {
      stop("'seed' must be coercible to an integer", call. = FALSE)
    }
    res[["seed"]] <- val
  }
  # Record the backend as an inspectable element; fit_model() reads it back and
  # the fit functions strip it before forwarding to the native sampler.
  res$backend <- backend
  res
}

#' Check whether per-chain threading is enabled for the active backend
#'
#' cmdstanr configures threading through the `threads_per_chain` sampler
#' argument; rstan reads the `STAN_NUM_THREADS` environment variable at run
#' time (`-1` meaning all available cores). Only the run-time configuration is
#' checked, not whether the model was compiled with threading support. The fit
#' functions do not consult this themselves: a host package running a threaded
#' model calls it to warn when the user has not made threads available.
#'
#' @param stan_opts a [stan_options()] result.
#' @returns logical; `TRUE` if per-chain threading is enabled, otherwise `FALSE`.
#' @keywords internal
check_threaded <- function(stan_opts) {
  switch(
    stan_opts$backend,
    rstan = {
      threads <- suppressWarnings(
        as.integer(Sys.getenv("STAN_NUM_THREADS", unset = "1"))
      )
      !is.na(threads) && (threads > 1L || threads == -1L)
    },
    cmdstanr = isTRUE(stan_opts$threads_per_chain > 1L)
  )
}

#' Name of the package that called into flexstanr
#'
#' flexstanr resolves a host's compiled model from the host's own namespace, so
#' it must know which package called it. This walks out to the top-level
#' environment of the calling frame and returns its package name. Returns `NULL`
#' when called from the global environment or another context without a package
#' (e.g. interactively), so callers can fail with an actionable message.
#'
#' @param env the environment to resolve from; defaults to the caller's frame.
#' @returns the calling package's name, or `NULL` if there is none.
#' @keywords internal
caller_package <- function(env = parent.frame()) {
  nm <- environmentName(topenv(env))
  if (is.null(nm) || nm %in% c("", "R_GlobalEnv", "R_EmptyEnv", "base")) {
    return(NULL)
  }
  nm
}

#' Resolve a host package's compiled rstan model
#'
#' Looks up `model_name` in the calling package's `stanmodels` object (the
#' `rstantools`-generated registry of compiled models). This replaces the
#' ambient `stanmodels[[model_name]]` lookup that worked only when this code was
#' vendored into the host: as an imported package, flexstanr must reach into the
#' host's namespace explicitly.
#'
#' @param package the host package name.
#' @param model_name the model to resolve.
#' @returns the compiled `stanmodel` object.
#' @keywords internal
get_stanmodel <- function(package, model_name) {
  ns <- tryCatch(asNamespace(package), error = function(e) NULL)
  if (is.null(ns) || !exists("stanmodels", envir = ns, inherits = FALSE)) {
    stop(
      "cannot resolve Stan models: package '", package, "' has no 'stanmodels' ",
      "object. flexstanr resolves the compiled model from the calling package; ",
      "pass `package` explicitly if it was not detected correctly.",
      call. = FALSE
    )
  }
  models <- get("stanmodels", envir = ns, inherits = FALSE)
  model <- models[[model_name]]
  if (is.null(model)) {
    stop(
      "model '", model_name, "' was not found in ", package, "::stanmodels.",
      call. = FALSE
    )
  }
  model
}

#' Fit a Stan model through the chosen backend
#'
#' Dispatches a fit to the backend recorded on `stan_opts` (from
#' [stan_options()]). The compiled model is resolved by `model_name` from the
#' calling package: for `"rstan"`, `package::stanmodels[[model_name]]`; for
#' `"cmdstanr"`, `inst/stan/<model_name>.stan` under `package`. The calling
#' package is detected automatically and can be overridden with `package`.
#'
#' @param model_name name of the Stan model; used to look up the compiled model
#'   in the calling package's `stanmodels` (rstan) and to locate the `.stan`
#'   source file under its `inst/stan/` (cmdstanr).
#' @param dat_stan the Stan data list.
#' @param init the init list, sized to the chain count.
#' @param stan_opts the validated [stan_options()] list (carrying a `backend`
#'   element).
#' @param drop_pars character vector of parameter names to exclude from the
#'   saved draws, or `NULL` to keep everything. Honored by rstan; cmdstanr
#'   cannot drop parameters and warns if any are requested.
#' @param package name of the host package whose model is being fit. Defaults to
#'   the package that called `fit_model()`, which is correct for the usual case
#'   of a host package fitting one of its own models.
#' @returns the backend's fit object (a `stanfit` or `CmdStanMCMC`).
#'
#' @examples
#' \dontrun{
#' # From inside a host package that ships a compiled `coverage` model:
#' opts <- stan_options(chains = 2, iter = 500, seed = 1)
#' fit <- fit_model("coverage", dat_stan = data_list, init = init_list,
#'                  stan_opts = opts)
#' }
#'
#' @export
fit_model <- function(model_name, dat_stan, init, stan_opts, drop_pars = NULL,
                      package = NULL) {
  # backend rides on stan_opts; assert_* also subsumes match.arg + installed check.
  backend <- assert_backend_available(stan_opts$backend)
  # Resolve the host package from the CALLER's frame. This MUST happen in the
  # body: a `package = caller_package()` default is evaluated in fit_model's own
  # frame, so it would always resolve to flexstanr rather than the caller.
  if (is.null(package)) {
    package <- caller_package(parent.frame())
  }
  if (is.null(package) || !nzchar(package)) {
    stop(
      "could not determine the host package for model '", model_name,
      "'; pass `package` explicitly.",
      call. = FALSE
    )
  }
  # Build the sampler argument list once: drop the backend marker (the native
  # samplers don't accept it) and inject the internally-built data and init, so
  # each fit_BACKEND() receives a ready-to-forward `args` list.
  args <- stan_opts
  args$backend <- NULL
  args$data <- dat_stan
  args$init <- init
  switch(
    backend,
    rstan    = fit_rstan(model_name, args, drop_pars, package),
    cmdstanr = fit_cmdstanr(model_name, args, drop_pars, package)
  )
}

#' @keywords internal
fit_rstan <- function(model_name, args, drop_pars = NULL, package) {
  args$object <- get_stanmodel(package, model_name)
  if (length(drop_pars) > 0) {
    # Exclude the named parameters from the saved output.
    args$pars    <- drop_pars
    args$include <- FALSE
  }
  do.call(rstan::sampling, args)
}

#' cmdstanr compile options for a threading allocation
#'
#' Returns the `cpp_options` needed to compile a cmdstanr model with within-chain
#' threading, or `NULL` when the allocation asks for a single thread (no
#' threading). Split out of [fit_cmdstanr()] so the compile-time decision is
#' unit-testable without the CmdStan toolchain.
#'
#' @param threads_per_chain the per-chain thread count from the sampler options
#'   (may be `NULL` when unset).
#' @returns `list(stan_threads = TRUE)` when more than one thread is requested,
#'   otherwise `NULL`.
#' @keywords internal
threading_cpp_options <- function(threads_per_chain) {
  if (isTRUE(threads_per_chain > 1L)) list(stan_threads = TRUE) else NULL
}

#' @keywords internal
fit_cmdstanr <- function(model_name, args, drop_pars = NULL, package) {
  # nocov start: needs the CmdStan toolchain, unavailable on CI/CRAN.
  # cmdstanr availability is already guaranteed by assert_backend_available().
  # The cmdstanr package is only a wrapper; compiling and running also need the
  # CmdStan toolchain. cmdstan_version() errors when CmdStan is not installed, so
  # probe it and fail early with an actionable message rather than deep inside
  # cmdstan_model().
  if (inherits(try(cmdstanr::cmdstan_version(), silent = TRUE), "try-error")) {
    stop(
      "backend = 'cmdstanr' requires a CmdStan installation, which was not ",
      "found. Install it with cmdstanr::install_cmdstan().",
      call. = FALSE
    )
  }
  if (length(drop_pars) > 0) {
    warning(
      "dropping parameters is not supported by the cmdstanr backend; ",
      paste(drop_pars, collapse = ", "), " will be written to the output.",
      call. = FALSE
    )
  }
  stan_file <- system.file(
    "stan", paste0(model_name, ".stan"),
    package = package, mustWork = TRUE
  )
  # Compile into a writable user cache, not next to the installed .stan file
  # (the package directory may be read-only, and stray executables there trip
  # R CMD check's "executable files" warning). cmdstan_model() reuses the cached
  # executable across sessions and recompiles only when the .stan source is
  # newer than it -- e.g. after a package update reinstalls the .stan file.
  exe_dir <- tools::R_user_dir(package, "cache")
  dir.create(exe_dir, showWarnings = FALSE, recursive = TRUE)
  # Enable within-chain threading in the compiled model when the options carry a
  # multi-thread allocation (from configure_threading()); cmdstan caches per
  # (source, cpp_options), so threaded and non-threaded builds coexist.
  compile_args <- list(stan_file, dir = exe_dir)
  cpp_options <- threading_cpp_options(args$threads_per_chain)
  if (!is.null(cpp_options)) {
    compile_args$cpp_options <- cpp_options
  }
  # A single thread per chain means no within-chain threading; drop it so
  # $sample() does not warn about a threads setting on a non-threaded build.
  if (isTRUE(args$threads_per_chain <= 1L)) {
    args$threads_per_chain <- NULL
  }
  mod <- do.call(cmdstanr::cmdstan_model, compile_args)
  do.call(mod$sample, args)
  # nocov end
}

# --- Fit consumption ---------------------------------------------------------
# The fit_BACKEND() functions above produce a backend-native fit object (an
# rstan stanfit or a cmdstanr CmdStanMCMC). Downstream code (prediction,
# parameter extraction) needs to read draws and run generated quantities off
# that object without knowing which backend produced it. These accessors are
# that portable seam: dispatch on the fit object's backend, so callers stay
# backend-agnostic. Only the rstan paths are implemented today; the cmdstanr
# paths are stubs pending backend support downstream (they require the CmdStan
# toolchain, so they cannot run on CI/CRAN regardless).

#' Identify the backend that produced a fit object
#'
#' @param raw_fit a backend-native fit object (an rstan `stanfit` or a cmdstanr
#'   `CmdStanMCMC`).
#' @returns `"rstan"` or `"cmdstanr"`.
#' @keywords internal
fit_backend <- function(raw_fit) {
  if (inherits(raw_fit, "stanfit")) {
    "rstan"
  } else if (inherits(raw_fit, "CmdStanMCMC")) {
    "cmdstanr"
  } else {
    stop(
      "unrecognized fit object; expected an rstan 'stanfit' or a cmdstanr ",
      "'CmdStanMCMC'.",
      call. = FALSE
    )
  }
}

# --- cmdstanr draws reshaping -------------------------------------------------
# These helpers turn a cmdstanr fit's posterior draws into the same shapes the
# rstan paths return, so callers stay backend-agnostic. They operate on plain
# posterior draws objects (not a live fit), so they are unit-tested against
# synthetic draws without a CmdStan toolchain. The thin `raw_fit$draws()` /
# generate_quantities() plumbing that feeds them still needs CmdStan and stays
# untested (# nocov).

#' Coerce a cmdstanr draws array to a plain iterations x chains x parameters array
#'
#' @param draws a posterior `draws_array` (iteration x chain x variable).
#' @returns a base 3-D array, matching `as.array()` on an rstan `stanfit`.
#' @keywords internal
cmdstanr_draws_array <- function(draws) {
  array(draws, dim = dim(draws), dimnames = dimnames(draws))
}

#' Reshape cmdstanr draws into rstan::extract()'s list-of-arrays
#'
#' Groups the flat, indexed variables (`theta[1]`, `theta[2]`, ...) back into one
#' array per parameter with draws merged across chains, matching the shape
#' [rstan::extract()] returns: a bare vector for a scalar parameter, an
#' `S x dims` array otherwise. Unlike rstan's default the draws are not randomly
#' permuted; they keep iteration-chain order, which is immaterial for the
#' exchangeable-sample uses these draws are put to.
#'
#' @param draws a posterior `draws` object for the requested parameters.
#' @param pars the parameter base names to extract.
#' @returns a named list of draw arrays, one per parameter.
#' @keywords internal
cmdstanr_extract <- function(draws, pars) {
  if (!requireNamespace("posterior", quietly = TRUE)) {
    stop("reading a cmdstanr fit needs the 'posterior' package.", call. = FALSE)
  }
  # A true scalar's flat variable name is the bare `p` (no index); a length-1
  # vector/array is `p[1]`. Both give draws_of() shape S x 1, but only a true
  # scalar should collapse to a bare vector -- rstan::extract() keeps a
  # `vector[1]` as an S x 1 matrix -- so distinguish them by name.
  flat <- posterior::variables(draws)
  rvars <- posterior::as_draws_rvars(draws)
  out <- lapply(pars, function(p) {
    rv <- rvars[[p]]
    if (is.null(rv)) {
      stop("parameter '", p, "' was not found in the fit.", call. = FALSE)
    }
    a <- posterior::draws_of(rv)
    if (p %in% flat && length(dim(a)) == 2L && dim(a)[2L] == 1L) {
      as.numeric(a)  # true scalar -> bare vector, matching rstan::extract()
    } else {
      a
    }
  })
  names(out) <- pars
  out
}

#' Coerce cmdstanr generated-quantities draws to a draws x parameters matrix
#'
#' @param gq_draws a posterior `draws` object of the requested generated
#'   parameter(s).
#' @returns a base matrix (rows = draws), matching the rstan path's
#'   `as.matrix(gqs(...), pars = ...)`.
#' @keywords internal
cmdstanr_gq_matrix <- function(gq_draws) {
  if (!requireNamespace("posterior", quietly = TRUE)) {
    stop("reading a cmdstanr fit needs the 'posterior' package.", call. = FALSE)
  }
  out <- unclass(posterior::as_draws_matrix(gq_draws))
  attr(out, "nchains") <- NULL
  out
}

#' Run cmdstanr generated quantities for a host model
#'
#' Resolves the host's `.stan` model the same way [fit_model()] does, compiles it
#' into a writable cache, and runs its generated-quantities block against the
#' fitted draws.
#'
#' @param model_name the model to run.
#' @param package the host package the model belongs to.
#' @param raw_fit the fitted `CmdStanMCMC` supplying the parameter draws.
#' @param data the Stan data list for the generated-quantities run.
#' @returns a `CmdStanGQ` object.
#' @keywords internal
run_cmdstanr_gq <- function(model_name, package, raw_fit, data) {
  # nocov start: needs the cmdstanr backend + CmdStan toolchain.
  if (is.null(package) || !nzchar(package)) {
    stop(
      "could not determine the host package for model '", model_name,
      "'; pass `package` explicitly.",
      call. = FALSE
    )
  }
  stan_file <- system.file(
    "stan", paste0(model_name, ".stan"),
    package = package, mustWork = TRUE
  )
  exe_dir <- tools::R_user_dir(package, "cache")
  dir.create(exe_dir, showWarnings = FALSE, recursive = TRUE)
  mod <- cmdstanr::cmdstan_model(stan_file, dir = exe_dir)
  mod$generate_quantities(fitted_params = raw_fit, data = data)
  # nocov end
}

#' Posterior draws of a fit as an iterations x chains x parameters array
#'
#' @param raw_fit a backend-native fit object (an rstan `stanfit` or a cmdstanr
#'   `CmdStanMCMC`).
#' @returns a 3-D array, dimensions iterations x chains x parameters.
#'
#' @examples
#' \dontrun{
#' draws <- backend_draws_array(fit)
#' dim(draws) # iterations x chains x parameters
#' }
#'
#' @export
backend_draws_array <- function(raw_fit) {
  switch(
    fit_backend(raw_fit),
    rstan = as.array(raw_fit),
    # nocov start: needs a live cmdstanr fit + CmdStan toolchain for $draws().
    cmdstanr = cmdstanr_draws_array(raw_fit$draws())
    # nocov end
  )
}

#' Extract named parameters from a fit as a list of arrays
#'
#' Matches the shape returned by [rstan::extract()].
#'
#' @param raw_fit a backend-native fit object (an rstan `stanfit` or a cmdstanr
#'   `CmdStanMCMC`).
#' @param pars character vector of parameter names to extract.
#' @param ... forwarded to the backend's extractor.
#' @returns a named list of draw arrays, one per parameter.
#' @importFrom rstan extract
#'
#' @examples
#' \dontrun{
#' post <- backend_extract(fit, pars = c("beta", "sigma"))
#' }
#'
#' @export
backend_extract <- function(raw_fit, pars, ...) {
  switch(
    fit_backend(raw_fit),
    rstan = rstan::extract(raw_fit, pars = pars, ...),
    # nocov start: needs a live cmdstanr fit + CmdStan toolchain for $draws().
    cmdstanr = cmdstanr_extract(raw_fit$draws(variables = pars), pars)
    # nocov end
  )
}

#' Run generated quantities against a fit and return a parameter matrix
#'
#' @param raw_fit a backend-native fit object (an rstan `stanfit` or a cmdstanr
#'   `CmdStanMCMC`).
#' @param data the Stan data list for the generated-quantities run.
#' @param draws_mat a draws matrix (rows = draws, columns = parameters). Used by
#'   the rstan backend; the cmdstanr backend runs generated quantities against
#'   the fit's own draws and ignores this argument.
#' @param pars name of the generated parameter to return.
#' @param model_name name of the model whose generated-quantities block to run.
#'   Required by the cmdstanr backend, which recompiles the model to run it;
#'   ignored by rstan, which reuses the model carried on `raw_fit`.
#' @param package the host package the model belongs to; defaults to the calling
#'   package (see [fit_model()]). Only used by the cmdstanr backend.
#' @returns a matrix of the requested generated parameter (rows = draws).
#' @importFrom rstan gqs
#'
#' @examples
#' \dontrun{
#' gen <- backend_generate_quantities(fit, data = data_list,
#'                                    draws_mat = as.matrix(fit), pars = "y_rep")
#' }
#'
#' @export
backend_generate_quantities <- function(raw_fit, data, draws_mat, pars,
                                        model_name = NULL,
                                        package = NULL) {
  # Resolve from the CALLER's frame in the body (see fit_model): a default-arg
  # caller_package() would resolve to flexstanr, not the caller.
  if (is.null(package)) {
    package <- caller_package(parent.frame())
  }
  switch(
    fit_backend(raw_fit),
    rstan = as.matrix(
      rstan::gqs(raw_fit@stanmodel, data = data, draws = draws_mat),
      pars = pars
    ),
    cmdstanr = {
      if (is.null(model_name)) {
        stop(
          "the cmdstanr backend needs `model_name` to locate the ",
          "generated-quantities model.",
          call. = FALSE
        )
      }
      # nocov start: needs the cmdstanr backend + CmdStan toolchain.
      gq <- run_cmdstanr_gq(model_name, package, raw_fit, data)
      cmdstanr_gq_matrix(gq$draws(variables = pars))
      # nocov end
    }
  )
}

#' Does a fit object carry usable posterior draws?
#'
#' @description Detect the degenerate "no draws" case after a fit, so a caller
#' can fail loudly instead of returning an empty fit. This is backend-aware:
#' rstan returns a mode-2 `stanfit` with an empty `@sim` when the sampler fails
#' to initialize (rather than erroring), while cmdstanr exposes its draws through
#' `$draws()`. Unrecognized objects (e.g. test mocks) are treated as having draws
#' so they pass through untouched.
#'
#' @param raw_fit a backend-native fit object (an rstan `stanfit` or a cmdstanr
#'   `CmdStanMCMC`).
#' @returns logical; `TRUE` if the fit carries usable draws.
#'
#' @examples
#' # Unrecognized objects are treated as carrying draws (pass-through).
#' backend_has_draws(list())
#'
#' @export
backend_has_draws <- function(raw_fit) {
  if (methods::is(raw_fit, "stanfit")) {
    length(raw_fit@sim) > 0L && isTRUE(raw_fit@mode == 0L)
  } else if (methods::is(raw_fit, "CmdStanMCMC")) {
    # nocov start: needs the cmdstanr backend + CmdStan toolchain.
    tryCatch(prod(dim(raw_fit$draws())) > 0L, error = function(e) FALSE)
    # nocov end
  } else {
    TRUE
  }
}
