call assertEq 0, .WLUUnits~parse("0"), "zero parse"
call assertEq 1000000, .WLUUnits~parse("1"), "one WLU"
call assertEq 1250000, .WLUUnits~parse("1.25"), "fraction parse"
call assertEq "1.25", .WLUUnits~format(1250000), "fraction format"

card = .WLURateCard~new("terminal.standard", "1")
card~addRule(.WLURateRule~new("FIELD_WRITE", 100000))
card~addRule(.WLURateRule~new("AID", 250000))
card~addRule(.WLURateRule~new("BYTES_RX", 1000, 1024))
card~addRule(.WLURateRule~new("SCREEN_UPDATE", 0))
card~seal
facts = .array~of(.WLUFact~new("FIELD_WRITE", 2), .WLUFact~new("AID", 1), .WLUFact~new("BYTES_RX", 2048), .WLUFact~new("SCREEN_UPDATE", 1))
quoted = card~quote(facts)
call assertTrue quoted~ok, "rate card quote"
call assertEq 452000, quoted~value~microWlu, "rate card total"

missing = card~quote(.array~of(.WLUFact~new("UNDECLARED", 1)))
call assertTrue \missing~ok, "unknown fact rejected"
call assertEq "WLU_UNMETERED_FACT", missing~code, "unknown fact code"

say "PASS test_units_ratecard"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WorkLoadUnits.cls"
