root = .NoSQLServerTestSupport~createBlankDatabase("edifact-rich-v071")
fed = .FederatedDatabaseEngine~new(root)

doc = .EdiFactDocumentContext~new("fixtures/orders.edi")
report = doc~validateEnvelope
call assert report~status = "VALID", "fixture envelope valid"

provider = .EdiFactRelationProvider~new(.DatabaseResult)
definition = provider~defineRelation("edi_orders", doc, "MESSAGE:ORDERS")
definition~columnMap("message_ref", "@reference")
definition~columnMap("order_id", "BGM/2")
definition~columnMap("document_code", "BGM/1")
definition~columnMap("order_date", "DTM[=137]/1/2")
definition~columnMap("buyer", "NAD[=BY]/2/1")
ignore = fed~addEngine(provider)

catalog = fed~readCatalog
call assert contains(catalog["tables"], "edi_orders"), "EDIFACT relation in federated catalog"

relation = provider~table("edi_orders")
rows = relation~readRows
call assert rows~items = 2, "two projected messages"
call assert rows[1]["order_id"] = "PO12345", "first order id"
call assert rows[2]["buyer"] = "654321", "second buyer"
call assert rows[1]~origin~isA(.EdiFactMessage), "row retains message object"
call assert rows[1]~sourceFor("order_id")~isA(.EdiFactElement), "cell retains EDIFACT element"
call assert rows[1]~sourceFor("order_id")~path~pos("/BGM[1]/E2") > 0, "cell structural path"
call assert rows[1]~rawAt("order_id") = "PO12345", "raw lexical value retained"

fact = rows[1]~fact("order_id")
call assert fact~isA(.EdiFactBusinessFact), "EDIFACT business fact type"
call assert fact~value = "PO12345", "business fact value"
call assert fact~source == rows[1]~sourceFor("order_id"), "business fact source identity"
prov = fact~provenance
call assert prov["document"] == doc, "fact provenance document"
call assert prov["message"] == rows[1]~origin, "fact provenance message"

r = fed~execute("SELECT order_id, buyer, order_date FROM edi_orders WHERE buyer='654321'")
call ok r
call assert r~rows~items = 1, "NoSQL predicate over EDIFACT projection"
call assert r~rows[1]["order_id"] = "PO12346", "NoSQL projected second order"
call assert r~accessPath = "EDIFACT_RICH_PROJECTION", "provider access path"

meta = fed~tableMetadata("edi_orders")
call assert meta \== .nil, "provider-neutral metadata"
call assert meta~columns~items = 5, "metadata sees EDIFACT columns"

bad = fed~execute("UPDATE edi_orders SET buyer='X' WHERE order_id='PO12345'")
call assert bad~error = .Error~SQLUNSUPPORTED, "EDIFACT relation read-only capability boundary"

ignore = provider~close
ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "EDIFACT RELATION NOSQL V0.71 SMOKE: OK"
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
::requires "../src/EdiFactRelationAdapter.cls"
