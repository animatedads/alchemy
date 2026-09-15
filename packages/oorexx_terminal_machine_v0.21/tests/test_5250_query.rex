failures = 0
cp = .CodePage037~new
model = .PresentationSpace5250~new
machine = .DataStream5250Machine~new(model, cp)

/* RFC 1205 section 5.3 Query command: ESC F3 0005 D9 70 00. */
query = "04F30005D97000"x
parsed = machine~consume(query)
call assertTrue parsed~ok, "query accepted"
call assertEq parsed~value~commandName, "5250_QUERY", "query outcome"
reply = parsed~value~responsePayload
call assertEq reply~length, 61, "query reply total inbound length"
call assertEq reply~substr(1,2)~c2x, "0000", "cursor row/column zero"
call assertEq reply~substr(3,1)~c2x, "88", "WSF inbound AID"
call assertEq reply~substr(4,2)~c2x, "003A", "structured field length"
call assertEq reply~substr(6,3)~c2x, "D97080", "query reply class/type/flag"
call assertEq reply~substr(9,2)~c2x, "0600", "other WSF/emulator controller class"
call assertEq cp~decode(reply~substr(31,4)), "3179", "advertised device type"
call assertEq cp~decode(reply~substr(35,3)), "002", "advertised device model"
call assertEq reply~substr(50,1)~c2x, "59", "capability byte 49 including immediate-alt"
call assertEq reply~substr(51,1)~c2x, "11", "24x80 colour capability"

bad = machine~consume("04F30005D97100"x)
call assertTrue \bad~ok, "unsupported structured field rejected"
call assertEq bad~code, "5250_WSF_UNSUPPORTED", "WSF unsupported error"

if failures > 0 then do
  say "FAIL test_5250_query" failures
  exit 1
end
say "PASS test_5250_query"
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
