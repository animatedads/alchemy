doc = .X12DocumentContext~new("fixtures/purchase_order.x12")
tx = doc~transactions[1]
sel = doc~select("NTE/2", tx)
call assert sel~count = 1, "repeated element selected as one source object"
element = sel~firstNode
call assert element~isA(.X12Element), "repeated value remains X12 element"
call assert element~repetitions~items = 2, "two repetitions retained"
call assert element~scalarValue == .nil, "repeated element refuses implicit scalar flattening"
call assert element~lexicalValue = "ALPHA^BETA", "whole repeated lexeme retained"
call assert element~string~pos("repetitions=2") > 0, "string representation does not join repeated values"

sel = doc~select("PO1/6{1}/2", tx)
call assert sel~firstNode~value = "ABC123", "first repeated composite component"
sel = doc~select("PO1/6{2}/1", tx)
call assert sel~firstNode~value = "BP", "second repetition qualifier"
call assert sel~firstNode~path~pos("/E6/R2/C1") > 0, "repetition-specific structural path"

oldDoc = .X12DocumentContext~new("fixtures/purchase_order_00401.x12")
call assert oldDoc~separators~interchangeVersion = "00401", "old ISA version retained"
call assert oldDoc~separators~repetition = "", "pre-00402 ISA11 is not misread as repetition separator"
oldSel = oldDoc~select("NTE/2", oldDoc~transactions[1])
call assert oldSel~firstNode~scalarValue = "ALPHA^BETA", "non-delimiter caret preserved as data in 00401"
call assert oldSel~firstNode~repetitions~items = 1, "00401 element not falsely split"

say "X12 REPETITION PRESERVATION SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "../src/X12NativeSource.cls"
