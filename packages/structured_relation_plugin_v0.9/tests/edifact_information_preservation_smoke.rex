text = "UNA:+.?*'" || "0a"x || -
       "UNH+1+ORDERS:D:96A:UN'" || "0a"x || -
       "NAD+BY++91'" || "0a"x || -
       "QTY+21:BANANA'" || "0a"x || -
       "DTM+137:20260820:102'" || "0a"x || -
       "DTM+137:20260821:102'" || "0a"x || -
       "RFF+ON:PO1*VN:VENDOR9'" || "0a"x || -
       "UNT+7+1'"

doc = .EdiFactDocumentContext~fromText(text, "memory:preservation.edi")
provider = .EdiFactRelationProvider~new(.PreservationResult)
def = provider~defineRelation("facts", doc, "MESSAGE:ORDERS")
def~columnMap("empty_party", "NAD[=BY]/2")
def~columnMap("missing_party", "NAD[=BY]/5")
def~columnMap("bad_qty", "QTY[=21]/1/2", "INTEGER")
def~columnMap("multi_date", "DTM[=137]/1/2")
def~columnMap("multi_date_many", "DTM[=137]/1/2", "VARCHAR", "MANY")
def~columnMap("repeated_ref", "RFF/1")
def~columnMap("repeated_ref_structured", "RFF/1", "VARCHAR", "STRUCTURED")

rows = provider~table("facts")~readRows
call assert rows~items = 1, "one message row"
row = rows[1]

call assert row~stateFor("empty_party") = "PRESENT_EMPTY", "empty distinct from absent"
call assert row~sourceFor("empty_party")~isA(.EdiFactElement), "empty retains element source"
call assert row~rawAt("empty_party") = "", "empty lexical retained"

call assert row~stateFor("missing_party") = "ABSENT", "missing distinct from empty"
call assert row~sourceFor("missing_party")~isA(.EdiFactSelection), "absence retains selector/context"
call assert row~sourceFor("missing_party")~context == row~origin, "absence context retained"

call assert row~stateFor("bad_qty") = "TYPE_ERROR", "type error explicit"
call assert row["bad_qty"] == .nil, "type error has no SQL scalar"
call assert row~rawAt("bad_qty") = "BANANA", "type error lexical value retained"
call assert row~sourceFor("bad_qty")~isA(.EdiFactComponent), "type error exact component source"
call assert row~cell("bad_qty")~diagnostics~items = 1, "type error diagnostic attached to cell"
call assert row~fact("bad_qty")~lexicalValue = "BANANA", "HardWorld fact retains bad lexeme"
call assert row~fact("bad_qty")~source == row~sourceFor("bad_qty"), "HardWorld fact retains source identity"

call assert row~stateFor("multi_date") = "CARDINALITY_ERROR", "multiple matches not flattened"
call assert row~rawAt("multi_date")~isA(.EdiFactSelection), "cardinality error retains selection"
call assert row~rawAt("multi_date")~nodes~items = 2, "all cardinality-error sources retained"

call assert row~stateFor("multi_date_many") = "MULTI", "MANY explicitly preserves collection"
call assert row["multi_date_many"]~isA(.EdiFactSelection), "MANY is a selection object"
call assert row["multi_date_many"]~string = "EDIFACT-NODESET(2)", "MANY string does not join values"

call assert row~stateFor("repeated_ref") = "STRUCTURED_VALUE", "repeated element refuses scalar projection"
call assert row~rawAt("repeated_ref") = "ON:PO1*VN:VENDOR9", "repeated lexical form retained"
call assert row~sourceFor("repeated_ref")~repetitions~items = 2, "repetition structure retained"
call assert row~stateFor("repeated_ref_structured") = "STRUCTURED", "structured projection explicit"
call assert row["repeated_ref_structured"] == row~sourceFor("repeated_ref_structured"), "structured value remains source object"

say "EDIFACT INFORMATION PRESERVATION SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::class PreservationResult public
::attribute status
::attribute error
::attribute message
::attribute rows
::attribute affectedRows
::attribute rowsScanned
::attribute accessPath
::method init
  use arg operation = "SELECT"

::requires "../src/EdiFactRelationAdapter.cls"
