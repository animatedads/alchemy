doc = .XmlDocumentContext~new("fixtures/plain_order_invalid.xml")
provider = .XmlRelationProvider~new(.nil)
definition = provider~defineRelation("order_lines", doc, "/Order/Line")
definition~columnMap("sku", "SKU")
definition~columnMap("quantity", "Quantity", "INTEGER")
rows = provider~table("order_lines")~readRows
call assert rows~items = 1, "one projected row"
row = rows[1]

cell = row~cell("quantity")
call assert cell~isA(.RichProjectionValue), "projection uses format-neutral rich cell"
call assert cell~state = "TYPE_ERROR", "typed projection preserves type failure state"
call assert cell~lexicalValue = "BANANA", "raw lexical value retained"
call assert cell~value == .nil, "SQL-facing invalid numeric is non-value"
call assert cell~source~isA(.XmlNodeRef), "rich cell retains exact XML source object"
call assert cell~source~path~pos("Quantity") > 0, "rich cell source path retained"
call assert cell~diagnostics~items = 1, "cell owns its diagnostic evidence"

fact = row~fact("quantity")
call assert fact~isA(.RichBusinessFact), "XML fact conforms to format-neutral business fact"
call assert fact~isA(.XmlBusinessFact), "XML-specific fact identity retained"
call assert fact~lexicalValue = "BANANA", "fact keeps lexical evidence"
call assert fact~source == cell~source, "fact keeps exact source identity"
call assert fact~diagnostics~items = 1, "fact carries source-linked diagnostics"
fact~annotate("hardworldRule", "ORDER_QUANTITY_VALID")
call assert fact~annotation("hardworldRule") = "ORDER_QUANTITY_VALID", "HardWorld annotation can ride with fact"

ignore = provider~close
say "RICH PROJECTION FACT SMOKE: OK"
exit 0

assert: procedure
  use arg conditionValue, message, detail = ""
  if \conditionValue then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return .true

::requires "../src/XmlRelationAdapter.cls"
