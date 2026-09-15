root = .NoSQLServerTestSupport~createBlankDatabase("xml-rich-v071")
fed = .FederatedDatabaseEngine~new(root)

doc = .XmlDocumentContext~new("fixtures/orders.xml")
doc~registerNamespace("o", "urn:example:orders")
doc~registerNamespace("c", "urn:example:common")

provider = .XmlRelationProvider~new(.DatabaseResult)
definition = provider~defineRelation("xml_order_lines", doc, "/o:Orders/o:Order/o:Line")
definition~columnMap("order_id", "../@id")
definition~columnMap("line_no", "@line", "INTEGER")
definition~columnMap("sku", "c:SKU")
definition~columnMap("quantity", "c:Quantity", "INTEGER")
definition~columnMap("currency", "c:Price/@currency")
definition~columnMap("price", "c:Price", "DECIMAL")
ignore = fed~addEngine(provider)

catalog = fed~readCatalog
call assert contains(catalog["tables"], "xml_order_lines"), "XML relation in federated catalog"

relation = provider~table("xml_order_lines")
rows = relation~readRows
call assert rows~items = 3, "three projected line rows"
call assert rows[2]["quantity"] = "50", "projected scalar value"
call assert rows[2]~originNode~path~pos("Line[2]") > 0, "row retains origin XML node"
call assert rows[2]~sourceFor("quantity")~isA(.XmlNodeRef), "column retains source node"
call assert rows[2]~sourceFor("quantity")~path~pos("Quantity") > 0, "column provenance path"
call assert rows[2]~fact("quantity")~value = "50", "HardWorld-style business fact value"
call assert rows[2]~fact("quantity")~source == rows[2]~sourceFor("quantity"), "business fact retains source identity"
call assert rows[3]~stateFor("quantity") = "PRESENT_EMPTY", "empty distinct from absent"

r = fed~execute("SELECT order_id, sku, quantity FROM xml_order_lines WHERE quantity > 20 ORDER BY quantity DESC")
call ok r
call assert r~rows~items = 1, "NoSQL predicate over XML projection"
call assert r~rows[1]["order_id"] = "PO-1001", "NoSQL projected order id"
call assert r~rows[1]["sku"] = "WIDGET-B", "NoSQL projected sku"
call assert r~accessPath = "XML_XPATH_PROJECTION", "provider access path retained"

meta = fed~tableMetadata("xml_order_lines")
call assert meta \== .nil, "provider-neutral metadata"
call assert meta~columns~items = 6, "metadata sees XML relation columns"

bad = fed~execute("UPDATE xml_order_lines SET quantity=99 WHERE sku='WIDGET-A'")
call assert bad~error = .Error~SQLUNSUPPORTED, "XML relation read-only capability boundary"

ignore = provider~close
ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "XML RELATION NOSQL V0.71 SMOKE: OK"
exit 0

contains: procedure
  use arg items, wanted
  do item over items
    if item~caselessEquals(wanted) then return .true
  end
  return .false

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "FAILED:" rs~status rs~error rs~message
    exit 1
  end
  return .true

assert: procedure
  use arg conditionValue, message, detail = ""
  if \conditionValue then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return .true

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "../src/XmlRelationAdapter.cls"
