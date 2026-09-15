/* Type failure must preserve lexical/source material instead of becoming dumb NULL. */
doc = .XmlDocumentContext~new("fixtures/orders_invalid.xml")
provider = .XmlRelationProvider~new(.DummyResult)
definition = provider~defineRelation("invalid_lines", doc, "/Orders/Order/Line")
definition~columnMap("quantity", "Quantity", "INTEGER")
row = provider~table("invalid_lines")~readRows[1]
call assert row["quantity"] == .nil, "SQL-facing invalid INTEGER is non-value"
call assert row~rawAt("quantity") = "BANANA", "raw lexical value preserved"
call assert row~stateFor("quantity") = "TYPE_ERROR", "type failure state preserved"
call assert row~diagnostics~items = 1, "projection diagnostic retained"
call assert row~diagnostics[1]~source~isA(.XmlNodeRef), "diagnostic points to source node"
call assert row~diagnostics[1]~source~path~pos("Quantity") > 0, "diagnostic source path"
fact = row~fact("quantity")
call assert fact~value == .nil, "business fact semantic value remains invalid"
call assert fact~lexicalValue = "BANANA", "business fact retains lexical evidence"
call assert fact~source == row~sourceFor("quantity"), "business fact source identity"

/* Multi-node projection must remain an XmlSelection, never a joined text list. */
ignore = doc~close
doc2 = .XmlDocumentContext~new("fixtures/orders.xml")
doc2~registerNamespace("o", "urn:example:orders")
doc2~registerNamespace("c", "urn:example:common")
provider2 = .XmlRelationProvider~new(.DummyResult)
def2 = provider2~defineRelation("orders", doc2, "/o:Orders/o:Order[1]")
def2~columnMap("skus", "o:Line/c:SKU")
row2 = provider2~table("orders")~readRows[1]
call assert row2["skus"] == .nil, "cardinality error not flattened into SQL text"
call assert row2~stateFor("skus") = "CARDINALITY_ERROR", "cardinality error retained"
call assert row2~rawAt("skus")~isA(.XmlSelection), "raw multi-value remains XmlSelection"
call assert row2~rawAt("skus")~nodes~items = 2, "all source nodes retained"
call assert row2~diagnostics~items = 1, "cardinality diagnostic retained"

/* MANY is explicit opt-in and still remains an object, never a comma list. */
def3 = provider2~defineRelation("orders_many", doc2, "/o:Orders/o:Order[1]")
def3~columnMap("skus", "o:Line/c:SKU", "UNKNOWN", "MANY")
row3 = provider2~table("orders_many")~readRows[1]
call assert row3~stateFor("skus") = "MULTI", "explicit many state"
call assert row3["skus"]~isA(.XmlSelection), "MANY value is rich selection"
call assert row3["skus"]~string = "XML-NODESET(2)", "string representation is summary, not flattened payload"
call assert row3["skus"]~nodes[1]~text = "WIDGET-A", "first node still individually addressable"
call assert row3["skus"]~nodes[2]~text = "WIDGET-B", "second node still individually addressable"

ignore = provider2~close
say "XML INFORMATION PRESERVATION SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message, detail = ""
  if \conditionValue then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return .true

::class DummyResult
::attribute status
::attribute error
::attribute message
::attribute rows
::attribute affectedRows
::attribute rowsScanned
::attribute accessPath
::method init
  use arg operation = "SELECT"
  self~status = "SUCCESS"
  self~error = "SUCCESS"
  self~message = ""
  self~rows = .array~new
  self~affectedRows = 0
  self~rowsScanned = 0
  self~accessPath = "UNPLANNED"

::requires "../src/XmlRelationAdapter.cls"
