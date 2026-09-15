failures = 0
cp = .CodePage037~new
model = .PresentationSpace5250~new
machine = .DataStream5250Machine~new(model, cp)

attrs = .directory~new
attrs["shift"] = "ALPHA_SHIFT"
field = model~defineField("CMD", 5, 10, 8, "", .true, .false, .false, .false, attrs)
call assertTrue field~ok, "define input field"
call assertTrue model~setInputField("CMD", "HELLO")~ok, "modify field"
call assertTrue model~setCursor(5, 12)~ok, "set cursor"

/* RFC 1205: x'83' is immediate, has no control bytes and returns AID x'00'. */
read = machine~consume("0483"x)
call assertTrue read~ok, "read modified immediate alternate"
call assertEq read~value~commandName, "READ_MDT_IMMEDIATE_ALT", "immediate command name"
payload = read~value~responsePayload
call assertEq payload~substr(1,3)~c2x, "050C00", "cursor plus immediate AID zero"
call assertEq payload~substr(4,3)~c2x, "11050A", "SBA + field address"
call assertEq cp~decode(payload~substr(7)), "HELLO", "modified field data"
call assertEq model~pendingReadKind, "", "immediate read does not queue READ"

/* Ordinary READ IMMEDIATE remains deliberately fail-closed until the byte-exact
 * format-table/regeneration image is represented. */
unsupported = machine~consume("0472"x)
call assertTrue \unsupported~ok, "read immediate not faked"
call assertEq unsupported~code, "5250_READ_IMMEDIATE_NOT_IMPLEMENTED", "read immediate boundary"

if failures > 0 then do
  say "FAIL test_5250_immediate_alt" failures
  exit 1
end
say "PASS test_5250_immediate_alt"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return
assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "DataStream5250.cls"
