# Assert a value is a positive integer (vector)

Errors on invalid input (non-numeric, empty, `NA`, non-integer, or
non-positive values); otherwise returns the value coerced to integer.
Used to validate count-like arguments.

## Usage

``` r
assert_positive_int(val, name)
```

## Arguments

- val:

  the value to validate.

- name:

  the argument name, used in error messages.

## Value

`val`, coerced to a positive integer (vector).
