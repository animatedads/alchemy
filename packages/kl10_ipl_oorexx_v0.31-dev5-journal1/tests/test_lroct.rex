numeric digits 30

call assertEq Oct("123456,,765432")~string, "123456,,765432", "LR notation"
call assertEq Oct("17")~string, "000000,,000017", "short octal normalization"
call assertEq Oct("123456,,765432")~left, "123456", "left half"
call assertEq Oct("123456,,765432")~right, "765432", "right half"
call assertEq Oct("000000,,000017")~rightDecimal, 15, "17 octal is decimal 15"

call assertEq (Oct("123456,,765432") & Oct("000000,,600000"))~string, "000000,,600000", "bitwise AND"
call assertEq (Oct("123456,,765432") | Oct("000000,,000345"))~string, "123456,,765777", "bitwise OR"
call assertEq (Oct("000000,,777777") && Oct("000000,,600000"))~string, "000000,,177777", "bitwise XOR"
call assertEq (\Oct("000000,,000000"))~string, "777777,,777777", "bitwise NOT"

call assertEq (Oct("000000,,777777") + Oct("000000,,000001"))~string, "000001,,000000", "36-bit addition"
call assertEq (Oct("000001,,000000") - Oct("000000,,000001"))~string, "000000,,777777", "36-bit subtraction"
call assertEq (-Oct("000000,,000001"))~string, "777777,,777777", "36-bit unary minus"
call assertEq (Oct("777777,,777777") + Oct("000000,,000001"))~string, "000000,,000000", "36-bit wrap"

call assertEq Oct("000000,,123456")~shl(18)~string, "123456,,000000", "left shift 18"
call assertEq Oct("123456,,000000")~shr(18)~string, "000000,,123456", "right shift 18"
call assertEq .LROct~fromDecimal(15)~string, "000000,,000017", "explicit decimal conversion"
call assertEq .LROct~fromDecimal(2 ** 36)~string, "000000,,000000", "decimal conversion wraps 36 bits"

/* This is the ANDI truth-serum expression in DEC notation. */
call assertEq (Oct("123456,,765432") & Oct("000000,,600000"))~string, "000000,,600000", "ANDI-style mask"

call assertEq Oct("123456,,000000")~compareTo(Oct("123457,,000000")), -1, "precision-safe compare less"
call assertEq Oct("123457,,000000")~compareTo(Oct("123456,,000000")), 1, "precision-safe compare greater"
call assertEq Oct("123456,,000000")~compareTo(Oct("123456,,000000")), 0, "precision-safe compare equal"
call assertEq Oct("123456,,000000")~equals(Oct("123456,,000000")), 1, "explicit value equality"
call assertEq Oct("123456,,000000")~equals(Oct("123456,,000001")), 0, "explicit value inequality"

say "LROct 36-bit octal algebra acceptance: PASS"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected" expected "got" actual
    exit 1
  end
  return 1

::requires "../lib/OctalBits.cls"
