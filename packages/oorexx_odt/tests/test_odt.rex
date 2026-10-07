call rxfuncadd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

out = "fixtures/generated_tps.odt"
doc = .OdtAccess~create("TPS Review Report", "NotNotes")
doc~addHeading("TPS Review Report", 1)
doc~addParagraph("Generated from authoritative TPS report objects.")
t = .OdtTable~new("TPS Reports")
t~addValues(.Array~of("TPS Number", "User", "Cost", "Status"))
t~addValues(.Array~of("TPS-2026-101", "Angela", "1250.50", "DRAFT"))
t~addValues(.Array~of("TPS-2026-102", "Oscar", "800.00", "APPROVED"))
t~addValues(.Array~of("TPS-2026-103", "Kevin", "3.00", "KELEVEN"))
doc~addTable(t)
.OdtAccess~save(doc, out)

readBack = .OdtAccess~open(out)
call assertEq "TPS Review Report", readBack~title, "title round trip"
call assertEq 1, readBack~headings~items, "heading count"
call assertEq 1, readBack~tables~items, "table count"
call assertEq 4, readBack~tables~at(1)~rows~items, "table row count"
call assertEq "Kevin", readBack~tables~at(1)~rows~at(4)~at(2), "table cell round trip"
call assertEq 4, .OdtIntentionAccess~discover(readBack)~items, "dynamic access intentions"
if pos("authoritative TPS", readBack~plainText) == 0 then call fail "plain text extraction"
say "PASS test_odt"
exit 0

assertEq: procedure
  parse arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
fail: procedure
  parse arg label
  say "FAIL" label
  exit 1

::requires "OdtAccess.cls"
