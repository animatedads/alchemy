doc = .X12DocumentContext~new("fixtures/purchase_order_bad_envelope.x12")
report = doc~validateEnvelope
call assert report~status = "INVALID", "bad X12 envelope invalid"
call assert report~findings~items = 6, "six envelope findings"

foundTxCount = .false
foundTxControl = .false
foundGroupCount = .false
foundGroupControl = .false
foundInterchangeCount = .false
foundInterchangeControl = .false

do finding over report~findings
  select
    when finding~code = "X12.TRANSACTION.SEGMENT_COUNT" then do
      foundTxCount = .true
      call assert finding~source~isA(.X12Element), "SE01 source object retained"
      call assert finding~source~path~pos("/SE[1]/E1") > 0, "SE01 source path retained"
    end
    when finding~code = "X12.TRANSACTION.CONTROL_MISMATCH" then foundTxControl = .true
    when finding~code = "X12.GROUP.TRANSACTION_COUNT" then foundGroupCount = .true
    when finding~code = "X12.GROUP.CONTROL_MISMATCH" then foundGroupControl = .true
    when finding~code = "X12.INTERCHANGE.GROUP_COUNT" then foundInterchangeCount = .true
    when finding~code = "X12.INTERCHANGE.CONTROL_MISMATCH" then foundInterchangeControl = .true
    otherwise nop
  end
end
call assert foundTxCount, "SE01 segment count finding"
call assert foundTxControl, "SE02 control finding"
call assert foundGroupCount, "GE01 transaction count finding"
call assert foundGroupControl, "GE02 control finding"
call assert foundInterchangeCount, "IEA01 group count finding"
call assert foundInterchangeControl, "IEA02 control finding"

say "X12 ENVELOPE VALIDATION SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "../src/X12NativeSource.cls"
