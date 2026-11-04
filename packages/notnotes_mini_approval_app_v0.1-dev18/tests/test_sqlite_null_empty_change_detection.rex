/* Exact MiniNotesPersistence comparison regression: SQL NULL must not be
 * silently treated as empty TEXT when deciding whether to UPDATE.
 * Runnable with run_tests.sh; no live SQLite provider is needed.
 */
persistence = .ComparisonOnlyPersistence~new
checks = 0
call check .true,  persistence~columnDiffers(.nil, ""),             "NULL -> empty"
call check .true,  persistence~columnDiffers("", .nil),             "empty -> NULL"
call check .false, persistence~columnDiffers(.nil, .nil),           "NULL unchanged"
call check .false, persistence~columnDiffers("", ""),               "empty unchanged"
call check .false, persistence~columnDiffers("abc", "abc"),         "text unchanged"
call check .true,  persistence~columnDiffers("abc", "abC"),         "case preserves exact bytes"
call check .true,  persistence~columnDiffers("abc", "abc "),        "trailing whitespace"
call check .true,  persistence~columnDiffers("A" || x2c("00"), "A"), "embedded NUL"
say "NOTNOTES_SQLITE_NULL_EMPTY_CHANGE_DETECTION_PASS checks=" checks
exit 0

check: procedure expose checks
  use strict arg expected, actual, label
  if expected \= actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  checks = checks + 1
  return

/* Bypass persistence constructor: the test inspects the exact production
 * comparison method without touching a database, path or SQL driver. */
::class ComparisonOnlyPersistence subclass MiniNotesPersistence
::method init
  return

::requires 'src/MiniNotesPersistence.cls'
