parse source . . here
base = filespec("L", here)

workbook = .SpreadsheetReader~open(base || "/fixtures/nasty.xlsx")
catalog = .SpreadsheetRelationDiscoverer~new~discover(workbook)
call assertEq 3, catalog~relations~items, "relation count"
customers = catalog~relation("Customers")
call assertTrue customers \== .nil, "customers relation"
call assertEq 5, customers~fields~items, "customer fields"
call assertEq "NUMBER", customers~field("Customer ID")~inferredType, "id number"
call assertTrue customers~field("Customer ID")~probableKey, "probable key"
call assertEq 2, customers~selectRows("City", "EQ", "Rochdale")~items, "filter city"
call assertEq 4250, customers~sum("Credit Limit"), "sum numeric currency"

ledger = catalog~relation("Ledger")
call assertEq "MIXED", ledger~field("Amount")~inferredType, "mixed amount catches numeric text row"
call assertTrue ledger~field("Amount")~numericTextCount > 0, "numeric-looking text detected"
call assertEq 2, ledger~field("Formula Total")~formulaCount, "formula count"
call assertTrue catalog~diagnostics~items >= 3, "diagnostics produced"
call assertEq 1, catalog~relationships~items, "relationship count"
link = catalog~relationships~at(1)
call assertEq "Orders", link~fromRelation~name, "relationship source"
call assertEq "Customer ID", link~fromField~name, "relationship source field"
call assertEq "Customers", link~toRelation~name, "relationship target"
call assertEq 100, link~coverage, "relationship coverage"

workbook2 = .SpreadsheetReader~open(base || "/fixtures/nasty.ods")
catalog2 = .SpreadsheetRelationDiscoverer~new~discover(workbook2)
call assertEq 3, catalog2~relations~items, "ods relation count"
call assertEq 2, catalog2~relation("Customers")~selectRows("City", "EQ", "Rochdale")~items, "ods filter city"
call assertEq 4250, catalog2~relation("Customers")~sum("Credit Limit"), "ods sum"
call assertEq 1, catalog2~relationships~items, "ods relationship count"

regions = .SpreadsheetReader~open(base || "/fixtures/regions.xlsx")
regionCatalog = .SpreadsheetRelationDiscoverer~new~discover(regions)
call assertEq 2, regionCatalog~relations~items, "multi-region relation count"
regionCustomers = regionCatalog~relation("Customers")
regionOrders = regionCatalog~relation("Orders")
call assertTrue regionCustomers \== .nil, "multi-region customers"
call assertTrue regionOrders \== .nil, "multi-region orders"
call assertEq 3, regionCustomers~records~items, "customer summary excluded"
call assertEq 4, regionOrders~records~items, "order summary excluded"
call assertEq "NUMBER", regionCustomers~field("Customer ID")~inferredType, "summary excluded from type inference"
call assertTrue regionCustomers~field("Customer ID")~probableKey, "region customer key"
call assertEq 1, regionCatalog~relationships~items, "multi-region relationship count"
call assertEq 2, regionCustomers~selectRows("City", "EQ", "Rochdale")~items, "multi-region filter"

regionsOds = .SpreadsheetReader~open(base || "/fixtures/regions.ods")
regionCatalogOds = .SpreadsheetRelationDiscoverer~new~discover(regionsOds)
call assertEq 2, regionCatalogOds~relations~items, "ods multi-region relation count"
call assertEq 3, regionCatalogOds~relation("Customers")~records~items, "ods customer summary excluded"
call assertEq 4, regionCatalogOds~relation("Orders")~records~items, "ods order summary excluded"
call assertEq 1, regionCatalogOds~relationships~items, "ods multi-region relationship count"

say "PASS test_relations"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertTrue: procedure
  use arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

::requires "SpreadsheetRelations.cls"
