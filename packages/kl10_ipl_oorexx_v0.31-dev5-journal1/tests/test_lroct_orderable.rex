numeric digits 30

a = Oct("123456,,000000")
b = Oct("123456,,000000")
c = Oct("123457,,000000")

call assertBool (a = b), 1, "value ="
call assertBool (a \= b), 0, "value \\="
call assertBool (a <> b), 0, "value <>"
call assertBool (a >< b), 0, "value ><"
call assertBool (a == b), 1, "value =="
call assertBool (a \== b), 0, "value \\=="
call assertBool (a < c), 1, "value <"
call assertBool (c > a), 1, "value >"
call assertBool (a <= b), 1, "value <="
call assertBool (a >= b), 1, "value >="
call assertBool (a = c), 0, "unequal ="
call assertBool (a \= c), 1, "unequal \\="
call assertBool (a~equals(b)), 1, "explicit equals remains available"
call assertEq a~hashCode, b~hashCode, "equal-value hashCode"

/* Object identity differs, but value-strict equality supplied by Orderable does not. */
call assertBool (a~identityHash = b~identityHash), 0, "separate object identities"

/* Hash/equality contract: separately created equal values address one table key. */
t = .table~new
t[a] = "stored"
call assertEq t[b], "stored", "equal LROct table key"

/* compareTo still remains precision-safe at default method NUMERIC DIGITS. */
call assertEq a~compareTo(c), -1, "compareTo exact less"
call assertEq c~compareTo(a), 1, "compareTo exact greater"

say "LROct Orderable comparison acceptance: PASS"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected" expected "got" actual
    exit 1
  end
  return 1

assertBool: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected" expected "got" actual
    exit 1
  end
  return 1

::requires "../lib/OctalBits.cls"
