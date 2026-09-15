text = "UNA:+.?*'" || "0a"x || -
       "UNH+1+ORDERS:D:96A:UN'" || "0a"x || -
       "RFF+ON:PO1*VN:VENDOR9'" || "0a"x || -
       "UNT+3+1'"

doc = .EdiFactDocumentContext~fromText(text, "memory:repeat.edi")
message = doc~messages[1]
sel = doc~select("RFF/1", message)
call assert sel~count = 1, "repeated element selected as one structural element"
element = sel~firstNode
call assert element~isA(.EdiFactElement), "repeated source remains element object"
call assert element~repetitions~items = 2, "two repetitions retained"
call assert element~scalarValue == .nil, "repeated element refuses scalar flattening"
call assert element~string~pos("repetitions=2") > 0, "string representation does not expose joined data"
call assert element~lexicalValue = "ON:PO1*VN:VENDOR9", "whole lexical element retained"

sel = doc~select("RFF/1{1}/2", message)
call assert sel~firstNode~value = "PO1", "first repetition component selected"
sel = doc~select("RFF/1{2}/1", message)
call assert sel~firstNode~value = "VN", "second repetition qualifier selected"
call assert sel~firstNode~provenance["path"]~pos("/E1/R2/C1") > 0, "component keeps repetition-specific structural provenance"

say "EDIFACT REPETITION PRESERVATION SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "../src/EdiFactNativeSource.cls"
