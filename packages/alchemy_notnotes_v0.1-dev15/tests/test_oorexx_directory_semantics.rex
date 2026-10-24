/* test_oorexx_directory_semantics.rex
 * Locks the ooRexx collection behaviour that notNotes intentionally exploits.
 */

activeMethod = .method~new("ACTIVE", .array~of('return "active:" || self~at("BASE")'))

directory = .directory~new
directory~put("value", "BASE")
directory~setMethod("ACTIVE", activeMethod)
call assertEqual "active:value", directory~Active, "Directory UNKNOWN executes active member"
call assertEqual "active:value", directory~at("ACTIVE"), "Directory AT executes active member"
call assertEqual .true, directory~hasIndex("ACTIVE"), "Directory indexes active member"

/* In this ooRexx build GET is not the active lookup path; preserve that fact. */
call assertEqual .nil, directory~get("ACTIVE"), "Directory GET does not execute active member"

/* StringTable exposes SETMETHOD through inheritance but does not acquire Directory semantics. */
stringTable = .stringtable~new
stringTable~put("value", "BASE")
stringTable~setMethod("ACTIVE", activeMethod)
call assertEqual .false, stringTable~hasIndex("ACTIVE"), "StringTable does not index active member"
call assertEqual .nil, stringTable~at("ACTIVE"), "StringTable AT remains plain lookup"
call assertEqual .nil, stringTable~Active, "StringTable UNKNOWN remains plain lookup"

say "PASS test_oorexx_directory_semantics"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1
