doc = .X12DocumentContext~new("fixtures/purchase_order.x12")
call assert doc~separators~element = "*", "element delimiter discovered from ISA"
call assert doc~separators~repetition = "^", "repetition delimiter discovered from ISA11"
call assert doc~separators~component = ":", "component delimiter discovered from ISA16"
call assert doc~separators~segment = "~", "segment terminator discovered from ISA"
call assert doc~separators~interchangeVersion = "00501", "ISA12 version retained"
call assert doc~interchanges~items = 1, "one interchange"
call assert doc~groups~items = 1, "one functional group"
call assert doc~transactions~items = 1, "one transaction"

interchange = doc~interchanges[1]
group = doc~groups[1]
transaction = doc~transactions[1]
call assert interchange~controlNumber = "000000001", "ISA13 control retained"
call assert interchange~senderId = "SENDER", "ISA06 sender retained"
call assert interchange~receiverId = "RECEIVER", "ISA08 receiver retained"
call assert group~functionalCode = "PO", "GS01 functional code retained"
call assert group~controlNumber = "1", "GS06 control retained"
call assert group~version = "005010", "GS08 version retained"
call assert transaction~transactionSetId = "850", "ST01 transaction id retained"
call assert transaction~controlNumber = "0001", "ST02 control retained"
call assert transaction~group == group, "transaction group identity retained"
call assert transaction~interchange == interchange, "transaction interchange identity retained"

sel = doc~select("BEG/3", transaction)
call assert sel~count = 1, "BEG purchase order selected"
call assert sel~firstNode~isA(.X12Element), "BEG value remains element"
call assert sel~firstNode~scalarValue = "PO12345", "purchase order value"
call assert sel~firstNode~lexicalValue = "PO12345", "purchase order lexical value"
call assert sel~firstNode~path~pos("/GROUP[1]/TRANSACTION[1]/BEG[1]/E3") > 0, "full envelope path retained"

sel = doc~select("PO1/6{1}/2", transaction)
call assert sel~count = 1, "composite component selected"
call assert sel~firstNode~value = "ABC123", "composite component value"
call assert sel~firstNode~provenance["group"] == group, "component provenance carries group"

report = doc~validateEnvelope
call assert report~status = "VALID", "valid X12 envelope"
call assert report~findings~items = 0, "no X12 envelope findings"
call assert doc~history~items >= 4, "history retained"

say "X12 NATIVE MODEL SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "../src/X12NativeSource.cls"
