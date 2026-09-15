root = .NoSQLServerTestSupport~createBlankDatabase("x12-rich-v071")
fed = .FederatedDatabaseEngine~new(root)

doc = .X12DocumentContext~new("fixtures/purchase_order.x12")
report = doc~validateEnvelope
call assert report~status = "VALID", "fixture X12 envelope valid"

provider = .X12RelationProvider~new(.DatabaseResult)
definition = provider~defineRelation("x12_orders", doc, "TRANSACTION:850")
definition~columnMap("transaction_control", "@control")
definition~columnMap("order_id", "BEG/3")
definition~columnMap("purpose", "BEG/2")
definition~columnMap("quantity", "PO1/2", "INTEGER")
definition~columnMap("price", "PO1/4", "DECIMAL")
definition~columnMap("vendor_item", "PO1/6{1}/2")
ignore = fed~addEngine(provider)

catalog = fed~readCatalog
call assert contains(catalog["tables"], "x12_orders"), "X12 relation in federated catalog"

relation = provider~table("x12_orders")
rows = relation~readRows
call assert rows~items = 1, "one projected X12 transaction"
call assert rows[1]["order_id"] = "PO12345", "order id projection"
call assert rows[1]["quantity"] = 2, "numeric quantity projection"
call assert rows[1]["price"] = "10.50", "decimal lexical numeric projection"
call assert rows[1]~origin~isA(.X12TransactionSet), "row retains transaction object"
call assert rows[1]~sourceFor("order_id")~isA(.X12Element), "cell retains X12 element"
call assert rows[1]~sourceFor("order_id")~path~pos("/BEG[1]/E3") > 0, "cell structural path"
call assert rows[1]~rawAt("order_id") = "PO12345", "raw lexical value retained"

fact = rows[1]~fact("order_id")
call assert fact~isA(.X12BusinessFact), "X12 business fact type"
call assert fact~value = "PO12345", "business fact value"
call assert fact~source == rows[1]~sourceFor("order_id"), "business fact source identity"
prov = fact~provenance
call assert prov["document"] == doc, "fact provenance document"
call assert prov["transaction"] == rows[1]~origin, "fact provenance transaction"
call assert prov["group"] == doc~groups[1], "fact provenance group"
call assert prov["interchange"] == doc~interchanges[1], "fact provenance interchange"

r = fed~execute("SELECT order_id, quantity, vendor_item FROM x12_orders WHERE order_id='PO12345'")
call ok r
call assert r~rows~items = 1, "NoSQL predicate over X12 projection"
call assert r~rows[1]["vendor_item"] = "ABC123", "NoSQL projected composite component"
call assert r~accessPath = "X12_RICH_PROJECTION", "provider access path"

meta = fed~tableMetadata("x12_orders")
call assert meta \== .nil, "provider-neutral metadata"
call assert meta~columns~items = 6, "metadata sees X12 columns"

bad = fed~execute("UPDATE x12_orders SET order_id='X' WHERE order_id='PO12345'")
call assert bad~error = .Error~SQLUNSUPPORTED, "X12 relation read-only capability boundary"

ignore = provider~close
ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "X12 RELATION NOSQL V0.71 SMOKE: OK"
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
  use arg conditionValue, message
  if \conditionValue then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return .true

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "../src/X12RelationAdapter.cls"
