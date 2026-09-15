text = "UNA:+,? '" || "0a"x || -
       "UNH+1+INVOIC:D:96A:UN'" || "0a"x || -
       "MOA+9:123,45'" || "0a"x || -
       "UNT+3+1'"

doc = .EdiFactDocumentContext~fromText(text, "memory:decimal.edi")
provider = .EdiFactRelationProvider~new(.DecimalResult)
def = provider~defineRelation("invoice", doc, "MESSAGE:INVOIC")
def~columnMap("amount", "MOA[=9]/1/2", "DECIMAL")
row = provider~table("invoice")~readRows[1]
call assert row["amount"] = "123.45", "decimal normalized for relational semantics"
call assert row~rawAt("amount") = "123,45", "original decimal lexical value retained"
call assert row~sourceFor("amount")~value = "123,45", "source component retains decoded source value"
call assert row~fact("amount")~lexicalValue = "123,45", "business fact retains original lexical decimal"
call assert doc~separators~decimal = ",", "document decimal notation retained"
say "EDIFACT DECIMAL LEXICAL SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::class DecimalResult public
::method init
  use arg operation = "SELECT"

::requires "../src/EdiFactRelationAdapter.cls"
