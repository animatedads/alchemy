call directory directory("S")

root = .NoSQLServerTestSupport~createBlankDatabase("v073-json")

json = .JsonDatabaseEngine~new("fixtures/v073_orders.json")
columns = .array~new
columns~append(.JsonColumnProjection~new("order_id", "$.order_id", "VARCHAR", .false))
columns~append(.JsonColumnProjection~new("order_date", "$.order_date", "VARCHAR", .false))
columns~append(.JsonColumnProjection~new("buyer_id", "$.buyer.id", "VARCHAR", .false))
columns~append(.JsonColumnProjection~new("buyer_name", "$.buyer.name", "VARCHAR", .true))
columns~append(.JsonColumnProjection~new("product", "$.items[0].product", "VARCHAR", .true))
columns~append(.JsonColumnProjection~new("qty", "$.items[0].qty", "INTEGER", .true))
columns~append(.JsonColumnProjection~new("active", "$.active", "BOOLEAN", .true))
columns~append(.JsonColumnProjection~new("tags_json", "$.tags", "TEXT", .true))
columns~append(.JsonColumnProjection~new("shipping_code", "$.shipping.code", "VARCHAR", .true))
call assert json~registerProjection("json_orders", "$.orders[*]", columns), "register explicit JSON projection"

buyerColumns = .array~new
buyerColumns~append(.JsonColumnProjection~new("buyer_id", "$.buyer_id", "VARCHAR", .false))
buyerColumns~append(.JsonColumnProjection~new("segment", "$.segment", "VARCHAR", .true))
buyerColumns~append(.JsonColumnProjection~new("active", "$.active", "BOOLEAN", .true))
call assert json~registerProjection("json_buyers", "$.buyers[*]", buyerColumns), "register second JSON projection"

call assert json~tableNames~items = 2, "JSON table catalog"
t = json~table("JSON_ORDERS")
call assert t \== .nil, "case-insensitive JSON table lookup"
call assert t~definition~columns~items = 9, "only explicitly projected columns exist"
call assert t~definition~column("metadata") == .nil, "document metadata is not auto-flattened"

r = json~execute("SELECT order_id,buyer_id,product,qty,active FROM json_orders WHERE buyer_id='123456' AND qty >= 2 ORDER BY qty DESC;")
call assert r~status = .Error~SUCCESS, "standalone JSON SQL query"
call assert r~rows~items = 2, "JSON nested-path predicate row count"
call assert r~rows[1]["order_id"] = "PO30000", "JSON ORDER BY numeric projected value"
call assert r~rows[2]["product"] = "ABC123", "JSON nested array scalar projection"

raw = json~execute("SELECT tags_json FROM json_orders WHERE order_id='PO12345';")
call assert raw~status = .Error~SUCCESS, "explicit nested JSON projection"
call assert raw~rows[1]["tags_json"] = '["priority","retail"]', "nested array preserved as canonical JSON text"

missing = json~execute("SELECT order_id FROM json_orders WHERE shipping_code IS NULL ORDER BY order_id;")
call assert missing~status = .Error~SUCCESS, "missing nested JSON path becomes SQL NULL"
call assert missing~rows~items = 3, "missing nested JSON path NULL row count"

fed = .FederatedDatabaseEngine~new(root)
fed~addEngine(json)
fr = fed~execute("SELECT j.order_id,j.product FROM json_orders j WHERE j.active=TRUE ORDER BY j.order_id;")
call assert fr~status = .Error~SUCCESS, "federated JSON SELECT"
call assert fr~rows~items = 2, "federated JSON rows"
call assert fed~tableMetadata("json_orders") \== .nil, "federated JSON metadata"
call assert fed~readCatalog["tables"]~items = 2, "federated JSON catalog"

joined = fed~execute("SELECT j.order_id,b.segment FROM json_orders j JOIN json_buyers b ON j.buyer_id=b.buyer_id AND j.active=b.active ORDER BY j.order_id;")
call assert joined~status = .Error~SUCCESS, "compound ON join across JSON projections"
call assert joined~rows~items = 3, "compound ON JSON join row count"
call assert joined~rows[1]["b.segment"] = "RETAIL", "JSON join projected value"

mr = fed~execute("UPDATE json_orders SET buyer_id='NOPE' WHERE order_id='PO12345';")
call assert mr~status = .Error~NOTEXECUTED, "JSON mutation rejected"
call assert mr~error = .Error~SQLUNSUPPORTED, "JSON mutation is SQLUNSUPPORTED"

badJson = .JsonDatabaseEngine~new("fixtures/v073_malformed.json")
badColumns = .array~of(.JsonColumnProjection~new("id", "$.id", "INTEGER", .true))
call assert badJson~registerProjection("bad_json", "$.orders[*]", badColumns), "register malformed JSON projection"
badResult = badJson~execute("SELECT * FROM bad_json;")
call assert badResult~status = .Error~NOTEXECUTED, "malformed JSON read rejected"
call assert badResult~error = .Error~STORAGEERROR, "malformed JSON is STORAGEERROR"

core = fed~databaseCore
coreRows = core~queryTable("json_orders")
call assert coreRows~status = .Error~SUCCESS, "Database Core JSON queryTable"
call assert coreRows~rows~items = 3, "Database Core JSON row count"

ignoredCleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "v0.73 JSON relation smoke PASS"
exit 0

assert: procedure
  use arg condition, description
  if \condition then do
    say "ASSERT FAILED:" description
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
