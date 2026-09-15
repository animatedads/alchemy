text = "UNB+UNOC:3+SENDER+RECEIVER+260820:1045+CTRL9'" || "0a"x || -
       "UNH+77+ORDERS:D:96A:UN'" || "0a"x || -
       "BGM+220+PO-BAD+9'" || "0a"x || -
       "UNT+99+WRONG'" || "0a"x || -
       "UNZ+2+WRONGCTRL'"

doc = .EdiFactDocumentContext~fromText(text, "memory:bad.edi")
report = doc~validateEnvelope
call assert report~status = "INVALID", "bad envelope invalid"
call assert report~findings~items = 4, "four envelope findings"

foundSegmentCount = .false
foundMessageRef = .false
foundMessageCount = .false
foundInterchangeRef = .false

do finding over report~findings
  if finding~code = "EDIFACT.MESSAGE.SEGMENT_COUNT" then do
    foundSegmentCount = .true
    call assert finding~source~isA(.EdiFactElement), "segment count source object retained"
    call assert finding~source~line = 4, "segment count line retained"
  end
  if finding~code = "EDIFACT.MESSAGE.REFERENCE_MISMATCH" then foundMessageRef = .true
  if finding~code = "EDIFACT.INTERCHANGE.MESSAGE_COUNT" then foundMessageCount = .true
  if finding~code = "EDIFACT.INTERCHANGE.REFERENCE_MISMATCH" then foundInterchangeRef = .true
end
call assert foundSegmentCount, "segment-count finding"
call assert foundMessageRef, "message-ref finding"
call assert foundMessageCount, "message-count finding"
call assert foundInterchangeRef, "interchange-ref finding"

say "EDIFACT ENVELOPE VALIDATION SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "../src/EdiFactNativeSource.cls"
