doc = .X12DocumentContext~new("fixtures/purchase_order_preservation.x12")
provider = .X12RelationProvider~new(.PreservationResult)
def = provider~defineRelation("facts", doc, "TRANSACTION:850")
def~columnMap("empty_beg", "BEG/4")
def~columnMap("missing_beg", "BEG/9")
def~columnMap("bad_qty", "PO1/2", "INTEGER")
def~columnMap("multi_ref", "REF[=IA]/2")
def~columnMap("multi_ref_many", "REF[=IA]/2", "VARCHAR", "MANY")
def~columnMap("repeated_note", "NTE/2")
def~columnMap("repeated_note_structured", "NTE/2", "VARCHAR", "STRUCTURED")

rows = provider~table("facts")~readRows
call assert rows~items = 1, "one transaction row"
row = rows[1]

call assert row~stateFor("empty_beg") = "PRESENT_EMPTY", "empty distinct from absent"
call assert row~sourceFor("empty_beg")~isA(.X12Element), "empty retains X12 element"
call assert row~rawAt("empty_beg") = "", "empty lexeme retained"

call assert row~stateFor("missing_beg") = "ABSENT", "missing distinct from empty"
call assert row~sourceFor("missing_beg")~isA(.X12Selection), "absence retains selector/context"
call assert row~sourceFor("missing_beg")~context == row~origin, "absence context retained"

call assert row~stateFor("bad_qty") = "TYPE_ERROR", "type error explicit"
call assert row["bad_qty"] == .nil, "bad numeric has no SQL scalar"
call assert row~rawAt("bad_qty") = "BANANA", "bad numeric lexeme retained"
call assert row~sourceFor("bad_qty")~isA(.X12Element), "type error exact X12 source"
call assert row~cell("bad_qty")~diagnostics~items = 1, "type diagnostic attached to cell"
fact = row~fact("bad_qty")
call assert fact~isA(.X12BusinessFact), "X12 business fact type"
call assert fact~isA(.RichBusinessFact), "shared rich business fact contract"
call assert fact~lexicalValue = "BANANA", "HardWorld fact retains bad lexeme"
call assert fact~source == row~sourceFor("bad_qty"), "HardWorld fact retains source identity"
call assert fact~provenance["group"] == doc~groups[1], "fact retains functional group provenance"
call assert fact~provenance["interchange"] == doc~interchanges[1], "fact retains interchange provenance"

call assert row~stateFor("multi_ref") = "CARDINALITY_ERROR", "multiple source values not flattened"
call assert row~rawAt("multi_ref")~isA(.X12Selection), "cardinality error retains selection"
call assert row~rawAt("multi_ref")~nodes~items = 2, "all cardinality sources retained"

call assert row~stateFor("multi_ref_many") = "MULTI", "MANY explicitly preserves collection"
call assert row["multi_ref_many"]~isA(.X12Selection), "MANY is X12 selection object"
call assert row["multi_ref_many"]~string = "X12-NODESET(2)", "MANY string does not join values"

call assert row~stateFor("repeated_note") = "STRUCTURED_VALUE", "repetition refuses scalar projection"
call assert row~rawAt("repeated_note") = "ALPHA^BETA", "repetition lexical form retained"
call assert row~sourceFor("repeated_note")~repetitions~items = 2, "repetition structure retained"
call assert row~stateFor("repeated_note_structured") = "STRUCTURED", "structured projection explicit"
call assert row["repeated_note_structured"] == row~sourceFor("repeated_note_structured"), "structured value remains source object"

say "X12 INFORMATION PRESERVATION SMOKE: OK"
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

::requires "../src/X12RelationAdapter.cls"
