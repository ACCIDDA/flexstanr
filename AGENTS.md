# Repository conventions

Conventions for anyone (human or agent) working in this package. Keep this file
current as conventions are settled.

## Validation-helper naming (checkmate style)

Name argument-validation helpers after `checkmate`, so behavior is predictable
from the prefix:

- **`assert_*(x, ...)`** -- errors if `x` is invalid; otherwise returns `x`
  (usually invisibly). Use inside a function to enforce a contract, e.g.
  `assert_positive_int(chains, "chains")`.
- **`check_*(x, ...)`** -- returns `TRUE` if valid, otherwise a string describing
  the problem. Reserve the `check_` prefix for that `TRUE`-or-message shape.
- **`test_*(x, ...)`** -- returns a single `TRUE`/`FALSE`. Use for a plain
  yes/no predicate, e.g. `test_threaded(stan_opts)`.

When adding a helper, match the prefix to the return contract: a predicate that
answers yes/no is `test_*`, not `check_*`.
