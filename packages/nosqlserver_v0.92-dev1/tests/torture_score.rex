corpus = arg(1)
if corpus = "" then do
  say "usage: torture_score.rex CORPUS_SQL"
  exit 2
end
if stream(corpus, "c", "query exists") = "" then do
  say "corpus not found:" corpus
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("torture")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

ddlTotal = 0
ddlAccepted = 0
insertTotal = 0
insertAccepted = 0
insertRows = 0
queryTotal = 0
queryPass = 0
queryUnsupported = 0
queryParse = 0
queryWrong = 0
queryExecution = 0
phase = "LOAD"
currentTitle = ""
statement = ""

say "NOSQLSERVER TORTURE SCORE"
say "corpus:" corpus
say

do while lines(corpus) > 0
  line = linein(corpus)
  stripped = line~strip
  if stripped~startsWith("--") then do
    if stripped~pos("UNHELPFUL QUERIES") > 0 then phase = "QUERY"
    if phase = "QUERY" then do
      if stripped~startsWith("-- [") then do
        close = stripped~pos("]")
        if close > 0 then currentTitle = stripped~substr(close + 1)~strip
      end
    end
    iterate
  end
  if stripped = "" then iterate
  if statement = "" then statement = stripped
  else statement ||= " " || stripped
  if stripped~right(1) \= ";" then iterate

  upper = statement~strip~translate
  rs = sql~execute(statement)
  if upper~startsWith("CREATE TABLE ") then do
    ddlTotal += 1
    if rs~status = .Error~SUCCESS then ddlAccepted += 1
    else say "DDL" ddlTotal || ":" selfClass(rs) rs~error rs~message
  end
  else if upper~startsWith("INSERT INTO ") then do
    insertTotal += 1
    if rs~status = .Error~SUCCESS then do
      insertAccepted += 1
      insertRows += rs~affectedRows
    end
    else say "INSERT" insertTotal || ":" selfClass(rs) rs~error rs~message
  end
  else if phase = "QUERY" then do
    queryTotal += 1
    classification = classify(rs, queryTotal, engine)
    select
      when classification = "PASS" then queryPass += 1
      when classification = "UNSUPPORTED" then queryUnsupported += 1
      when classification = "PARSE_ERROR" then queryParse += 1
      when classification = "WRONG_RESULT" then queryWrong += 1
      otherwise queryExecution += 1
    end
    number = queryTotal~format(2,0)~changestr(" ", "0")
    say "QUERY" number || ":" classification "|" currentTitle
    if rs~status \= .Error~SUCCESS then say "       " rs~error "|" rs~message
  end
  statement = ""
end
call lineout corpus

say
say "DDL accepted :" ddlAccepted || "/" || ddlTotal
say "INSERT stmts :" insertAccepted || "/" || insertTotal
say "rows loaded  :" insertRows
say "queries      :" queryTotal
say "  PASS           :" queryPass
say "  UNSUPPORTED    :" queryUnsupported
say "  PARSE_ERROR    :" queryParse
say "  WRONG_RESULT   :" queryWrong "(all torture queries oracle-backed)"
say "  EXECUTION_ERROR:" queryExecution

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
if ddlAccepted \= ddlTotal then exit 1
if insertAccepted \= insertTotal then exit 1
exit 0

classify: procedure
  use arg rs, queryNumber, engine
  if rs~status = .Error~SUCCESS then do
    if queryNumber = 1 then do
      if \oracleKitchenSink(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 2 then do
      if \oracleCorrelatedSubqueries(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 3 then do
      if \oracleFunctionWrapped(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 4 then do
      if \oracleDistinctCommaJoin(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 5 then do
      if \oracleEmployeeHierarchy(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 6 then do
      if \oracleHavingDerivedAggregate(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 7 then do
      if \oracleAntiJoin(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 8 then do
      if \oracleUnionOrders(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 9 then do
      if \oracleNestedInProducts(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 10 then do
      if \oracleCaseOrder(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 11 then do
      if \oracleCrossJoin(rs, engine) then return "WRONG_RESULT"
    end
    if queryNumber = 12 then do
      if \oracleCorrelatedAggregateSummary(rs, engine) then return "WRONG_RESULT"
    end
    return "PASS"
  end
  if rs~error = .Error~SQLUNSUPPORTED then return "UNSUPPORTED"
  if rs~error = .Error~SQLPARSEERROR then return "PARSE_ERROR"
  return "EXECUTION_ERROR"

oracleKitchenSink: procedure
  use arg rs, engine
  customers = engine~table("customers")
  employees = engine~table("employees")
  products = engine~table("products")
  orders = engine~table("orders")
  items = engine~table("order_items")
  if customers == .nil | employees == .nil | products == .nil | orders == .nil | items == .nil then return .false
  customersById = .table~new
  employeesById = .table~new
  productsById = .table~new
  ordersById = .table~new
  do r over customers~storage~readRows; customersById[r["customer_id"]~string] = r; end
  do r over employees~storage~readRows; employeesById[r["employee_id"]~string] = r; end
  do r over products~storage~readRows; productsById[r["product_id"]~string] = r; end
  do r over orders~storage~readRows; ordersById[r["order_id"]~string] = r; end
  expected = .array~new
  do oi over items~storage~readRows
    o = ordersById[oi["order_id"]~string]
    if o == .nil then iterate
    c = customersById[o["customer_id"]~string]
    e = employeesById[o["employee_id"]~string]
    p = productsById[oi["product_id"]~string]
    if c == .nil | e == .nil | p == .nil then iterate
    x = .table~new
    x["city"] = c["city"]
    x["customer"] = c["full_name"]
    x["order_id"] = o["order_id"]
    x["order_date"] = o["order_date"]
    x["category"] = p["category"]
    x["product"] = p["product_name"]
    x["quantity"] = oi["quantity"]
    x["line_total"] = oi["quantity"] * oi["unit_price"]
    x["handled_by"] = e["full_name"]
    expected~append(x)
  end
  call sortKitchenExpected expected
  if rs~rows~items \= expected~items then return .false
  do i = 1 to expected~items
    want = expected[i]
    got = rs~rows[i]
    if got["c.full_name"] \= want["customer"] then return .false
    if got["c.city"] \= want["city"] then return .false
    if got["o.order_id"] \= want["order_id"] then return .false
    if got["o.order_date"] \= want["order_date"] then return .false
    if got["p.product_name"] \= want["product"] then return .false
    if got["oi.quantity"] \= want["quantity"] then return .false
    if got["line_total"] \= want["line_total"] then return .false
    if got["handled_by"] \= want["handled_by"] then return .false
  end
  return .true

sortKitchenExpected: procedure
  use arg rows
  i = 2
  do while i <= rows~items
    current = rows[i]
    j = i - 1
    do while j >= 1
      if compareKitchen(rows[j], current) <= 0 then leave
      rows[j + 1] = rows[j]
      j -= 1
    end
    rows[j + 1] = current
    i += 1
  end
  return

compareKitchen: procedure
  use arg a, b
  cmp = compareText(a["city"], b["city"]); if cmp \= 0 then return cmp
  cmp = compareText(a["customer"], b["customer"]); if cmp \= 0 then return cmp
  cmp = compareText(a["order_date"], b["order_date"]); if cmp \= 0 then return 0 - cmp
  cmp = compareText(a["category"], b["category"]); if cmp \= 0 then return cmp
  cmp = compareText(a["product"], b["product"]); if cmp \= 0 then return cmp
  if a["quantity"] < b["quantity"] then return 1
  if a["quantity"] > b["quantity"] then return -1
  return 0

compareText: procedure
  use arg a, b
  if a < b then return -1
  if a > b then return 1
  return 0


oracleCorrelatedSubqueries: procedure
  use arg rs, engine
  customers = engine~table("customers")
  orders = engine~table("orders")
  items = engine~table("order_items")
  if customers == .nil | orders == .nil | items == .nil then return .false
  customersById = .table~new
  itemBuckets = .table~new
  do c over customers~storage~readRows
    customersById[c["customer_id"]~string] = c
  end
  do oi over items~storage~readRows
    key = oi["order_id"]~string
    bucket = itemBuckets[key]
    if bucket == .nil then do
      bucket = .array~new
      itemBuckets[key] = bucket
    end
    bucket~append(oi)
  end
  expected = .array~new
  do o over orders~storage~readRows
    c = customersById[o["customer_id"]~string]
    if c == .nil then return .false
    bucket = itemBuckets[o["order_id"]~string]
    total = .nil
    count = 0
    if bucket \== .nil then do
      total = 0
      do oi over bucket
        total += oi["quantity"] * oi["unit_price"]
        count += 1
      end
    end
    x = .table~new
    x["order_id"] = o["order_id"]
    x["customer_name"] = c["full_name"]
    x["order_total"] = total
    x["item_count"] = count
    expected~append(x)
  end
  call sortCorrelatedExpected expected
  if rs~rows~items \= expected~items then return .false
  do i = 1 to expected~items
    want = expected[i]
    got = rs~rows[i]
    if got["o.order_id"] \= want["order_id"] then return .false
    if got["customer_name"] \= want["customer_name"] then return .false
    if want["order_total"] == .nil then do
      if got["order_total"] \== .nil then return .false
    end
    else if got["order_total"] \= want["order_total"] then return .false
    if got["item_count"] \= want["item_count"] then return .false
  end
  return .true

sortCorrelatedExpected: procedure
  use arg rows
  i = 2
  do while i <= rows~items
    current = rows[i]
    j = i - 1
    do while j >= 1
      if compareNullableNumericDesc(rows[j]["order_total"], current["order_total"]) <= 0 then leave
      rows[j + 1] = rows[j]
      j -= 1
    end
    rows[j + 1] = current
    i += 1
  end
  return

compareNullableNumericDesc: procedure
  use arg a, b
  if a == .nil then do
    if b == .nil then return 0
    return 1
  end
  if b == .nil then return -1
  if a > b then return -1
  if a < b then return 1
  return 0

oracleFunctionWrapped: procedure
  use arg rs, engine
  customers = engine~table("customers")
  if customers == .nil then return .false
  expected = .table~new
  expectedCount = 0
  do c over customers~storage~readRows
    cityUpper = c["city"]~string~translate
    emailFirst = ""
    if c["email"] \== .nil then do
      if c["email"]~string~length > 0 then emailFirst = translate(c["email"]~string~substr(1,1), "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    end
    if cityUpper~pos("ON") = 0 then iterate
    if emailFirst < "a" | emailFirst > "m" then iterate
    sig = c["customer_id"]~string || "1F"x || c["full_name"]~string || "1F"x || c["email"]~string || "1F"x || c["city"]~string || "1F"x || c["signup_date"]~string || "1F"x || c["loyalty_tier"]~string
    expected[sig] = .true
    expectedCount += 1
  end
  if rs~rows~items \= expectedCount then return .false
  seen = .table~new
  do row over rs~rows
    sig = row["customer_id"]~string || "1F"x || row["full_name"]~string || "1F"x || row["email"]~string || "1F"x || row["city"]~string || "1F"x || row["signup_date"]~string || "1F"x || row["loyalty_tier"]~string
    if expected[sig] == .nil then return .false
    if seen[sig] \== .nil then return .false
    seen[sig] = .true
  end
  return seen~items = expectedCount

oracleDistinctCommaJoin: procedure
  use arg rs, engine
  customers = engine~table("customers")
  orders = engine~table("orders")
  items = engine~table("order_items")
  products = engine~table("products")
  if customers == .nil then return .false
  if orders == .nil then return .false
  if items == .nil then return .false
  if products == .nil then return .false

  expected = .table~new
  expectedCount = 0
  do c over customers~storage~readRows
    do o over orders~storage~readRows
      if o["customer_id"] \= c["customer_id"] then iterate
      do oi over items~storage~readRows
        if oi["order_id"] \= o["order_id"] then iterate
        do p over products~storage~readRows
          if p["product_id"] \= oi["product_id"] then iterate
          sig = c["customer_id"] || "1F"x || c["full_name"] || "1F"x || c["city"] || "1F"x || p["category"]
          if expected[sig] == .nil then do
            expected[sig] = .true
            expectedCount += 1
          end
        end
      end
    end
  end
  if rs~rows~items \= expectedCount then return .false
  seen = .table~new
  do row over rs~rows
    sig = row["c.customer_id"] || "1F"x || row["c.full_name"] || "1F"x || row["c.city"] || "1F"x || row["p.category"]
    if expected[sig] == .nil then return .false
    if seen[sig] \== .nil then return .false
    seen[sig] = .true
  end
  if seen~items \= expectedCount then return .false
  return .true


oracleEmployeeHierarchy: procedure
  use arg rs, engine
  employees = engine~table("employees")
  if employees == .nil then return .false
  sourceRows = employees~storage~readRows
  byId = .table~new
  do e over sourceRows
    byId[e["employee_id"]~string] = e
  end
  expected = .table~new
  expectedCount = 0
  do e1 over sourceRows
    managerName = "<NULL>"
    directorName = "<NULL>"
    if e1["manager_id"] \== .nil then do
      e2 = byId[e1["manager_id"]~string]
      if e2 \== .nil then do
        managerName = e2["full_name"]
        if e2["manager_id"] \== .nil then do
          e3 = byId[e2["manager_id"]~string]
          if e3 \== .nil then directorName = e3["full_name"]
        end
      end
    end
    sig = e1["full_name"] || "1F"x || managerName || "1F"x || directorName
    count = expected[sig]
    if count == .nil then count = 0
    expected[sig] = count + 1
    expectedCount += 1
  end
  if rs~rows~items \= expectedCount then return .false
  previousDirector = .nil
  previousManager = .nil
  previousEmployee = .nil
  do row over rs~rows
    employee = row["employee"]
    manager = row["manager"]
    director = row["director"]
    managerText = "<NULL>"
    directorText = "<NULL>"
    if manager \== .nil then managerText = manager~string
    if director \== .nil then directorText = director~string
    sig = employee || "1F"x || managerText || "1F"x || directorText
    count = expected[sig]
    if count == .nil then return .false
    if count <= 0 then return .false
    expected[sig] = count - 1
  end
  do sig over expected
    if expected[sig] \= 0 then return .false
  end
  return .true

oracleHavingDerivedAggregate: procedure
  use arg rs, engine
  products = engine~table("products")
  items = engine~table("order_items")
  if products == .nil | items == .nil then return .false
  productById = .table~new
  do p over products~storage~readRows
    productById[p["product_id"]~string] = p
  end
  revenue = .table~new
  counts = .table~new
  categories = .array~new
  do oi over items~storage~readRows
    p = productById[oi["product_id"]~string]
    if p == .nil then iterate
    cat = p["category"]
    if revenue[cat] == .nil then do
      revenue[cat] = 0
      counts[cat] = 0
      categories~append(cat)
    end
    revenue[cat] = revenue[cat] + oi["quantity"] * oi["unit_price"]
    counts[cat] = counts[cat] + 1
  end
  if categories~items = 0 then avgRevenue = .nil
  else do
    total = 0
    do cat over categories
      total += revenue[cat]
    end
    avgRevenue = total / categories~items
  end
  expected = .array~new
  if avgRevenue \== .nil then do cat over categories
    if revenue[cat] > avgRevenue then do
      x = .table~new
      x["category"] = cat
      x["items_sold"] = counts[cat]
      x["revenue"] = revenue[cat]
      expected~append(x)
    end
  end
  -- descending revenue order
  i = 2
  do while i <= expected~items
    current = expected[i]
    j = i - 1
    do while j >= 1
      if expected[j]["revenue"] >= current["revenue"] then leave
      expected[j + 1] = expected[j]
      j -= 1
    end
    expected[j + 1] = current
    i += 1
  end
  if rs~rows~items \= expected~items then return .false
  do i = 1 to expected~items
    got = rs~rows[i]
    want = expected[i]
    if got["p.category"] \= want["category"] then return .false
    if got["items_sold"] \= want["items_sold"] then return .false
    if got["revenue"] \= want["revenue"] then return .false
  end
  return .true

oracleAntiJoin: procedure
  use arg rs, engine
  customers = engine~table("customers")
  orders = engine~table("orders")
  if customers == .nil then return .false
  if orders == .nil then return .false
  customerRows = customers~storage~readRows
  orderRows = orders~storage~readRows
  expected = .table~new
  expectedCount = 0
  do c over customerRows
    hasNonCancelled = .false
    do o over orderRows
      if o["customer_id"] \= c["customer_id"] then iterate
      if o["status"] \= "CANCELLED" then do
        hasNonCancelled = .true
        leave
      end
    end
    if hasNonCancelled then iterate
    sig = c["customer_id"] || "1F"x || c["full_name"]
    expected[sig] = .true
    expectedCount += 1
  end
  if rs~rows~items \= expectedCount then return .false
  previousName = .nil
  seen = .table~new
  do row over rs~rows
    name = row["c.full_name"]
    if name == .nil then return .false
    if previousName \== .nil then do
      if name~string < previousName~string then return .false
    end
    previousName = name
    sig = row["c.customer_id"] || "1F"x || name
    if expected[sig] == .nil then return .false
    if seen[sig] \== .nil then return .false
    seen[sig] = .true
  end
  if seen~items \= expectedCount then return .false
  return .true


oracleUnionOrders: procedure
  use arg rs, engine
  orders = engine~table("orders")
  customers = engine~table("customers")
  if orders == .nil then return .false
  if customers == .nil then return .false
  gold = .table~new
  do c over customers~storage~readRows
    if c["loyalty_tier"] = "GOLD" then gold[c["customer_id"]~string] = .true
  end
  expected = .table~new
  expectedCount = 0
  do o over orders~storage~readRows
    include = .false
    if o["status"] = "PENDING" then include = .true
    if o["status"] = "SHIPPED" then include = .true
    if gold[o["customer_id"]~string] \== .nil then include = .true
    if \include then iterate
    sig = o["order_id"]~string || "1F"x || o["customer_id"]~string || "1F"x || o["employee_id"]~string || "1F"x || o["order_date"]~string || "1F"x || o["status"]~string
    if expected[sig] == .nil then do
      expected[sig] = 1
      expectedCount += 1
    end
  end
  if rs~rows~items \= expectedCount then return .false
  previousDate = .nil
  seen = .table~new
  do row over rs~rows
    d = row["order_date"]
    if d == .nil then return .false
    if previousDate \== .nil then if d~string < previousDate~string then return .false
    previousDate = d
    sig = row["order_id"]~string || "1F"x || row["customer_id"]~string || "1F"x || row["employee_id"]~string || "1F"x || row["order_date"]~string || "1F"x || row["status"]~string
    if expected[sig] == .nil then return .false
    if seen[sig] \== .nil then return .false
    seen[sig] = .true
  end
  return seen~items = expectedCount


oracleNestedInProducts: procedure
  use arg rs, engine
  customers = engine~table("customers")
  orders = engine~table("orders")
  items = engine~table("order_items")
  products = engine~table("products")
  if customers == .nil then return .false
  if orders == .nil then return .false
  if items == .nil then return .false
  if products == .nil then return .false

  platinumCities = .table~new
  do c over customers~storage~readRows
    if c["loyalty_tier"] = "PLATINUM" then platinumCities[c["city"]~string] = .true
  end
  customerIds = .table~new
  do c over customers~storage~readRows
    if platinumCities[c["city"]~string] \== .nil then customerIds[c["customer_id"]~string] = .true
  end
  orderIds = .table~new
  do o over orders~storage~readRows
    if customerIds[o["customer_id"]~string] \== .nil then orderIds[o["order_id"]~string] = .true
  end
  productIds = .table~new
  do oi over items~storage~readRows
    if orderIds[oi["order_id"]~string] \== .nil then productIds[oi["product_id"]~string] = .true
  end

  expected = .table~new
  expectedCount = 0
  do p over products~storage~readRows
    if productIds[p["product_id"]~string] == .nil then iterate
    sig = p["product_id"]~string || "1F"x || p["product_name"]~string || "1F"x || p["category"]~string || "1F"x || p["unit_price"]~string || "1F"x || p["stock_qty"]~string
    expected[sig] = .true
    expectedCount += 1
  end
  if rs~rows~items \= expectedCount then return .false
  seen = .table~new
  do row over rs~rows
    sig = row["product_id"]~string || "1F"x || row["product_name"]~string || "1F"x || row["category"]~string || "1F"x || row["unit_price"]~string || "1F"x || row["stock_qty"]~string
    if expected[sig] == .nil then return .false
    if seen[sig] \== .nil then return .false
    seen[sig] = .true
  end
  return seen~items = expectedCount

oracleCaseOrder: procedure
  use arg rs, engine
  customers = engine~table("customers")
  orders = engine~table("orders")
  if customers == .nil | orders == .nil then return .false
  byCustomer = .table~new
  do c over customers~storage~readRows
    byCustomer[c["customer_id"]~string] = c
  end
  expected = .array~new
  do o over orders~storage~readRows
    c = byCustomer[o["customer_id"]~string]
    if c == .nil then iterate
    item = .table~new
    item["order_id"] = o["order_id"]
    item["status"] = o["status"]
    item["full_name"] = c["full_name"]
    item["order_date"] = o["order_date"]
    item["sort_name"] = c["city"]~string || "-" || c["full_name"]~string
    status = o["status"]~string
    if status = "CANCELLED" then rank = 3
    else if status = "RETURNED" then rank = 2
    else rank = 1
    item["rank"] = rank
    expected~append(item)
  end
  i = 2
  do while i <= expected~items
    current = expected[i]
    j = i - 1
    do while j >= 1
      if caseOracleCompare(expected[j], current) <= 0 then leave
      expected[j + 1] = expected[j]
      j -= 1
    end
    expected[j + 1] = current
    i += 1
  end
  if rs~rows~items \= expected~items then return .false
  i = 1
  do row over rs~rows
    want = expected[i]
    if row["o.order_id"]~string \= want["order_id"]~string then return .false
    if row["o.status"]~string \= want["status"]~string then return .false
    if row["c.full_name"]~string \= want["full_name"]~string then return .false
    if row["o.order_date"]~string \= want["order_date"]~string then return .false
    i += 1
  end
  return .true

caseOracleCompare: procedure
  use arg left, right
  if left["rank"] < right["rank"] then return -1
  if left["rank"] > right["rank"] then return 1
  if left["sort_name"]~string < right["sort_name"]~string then return -1
  if left["sort_name"]~string > right["sort_name"]~string then return 1
  if left["order_date"]~string > right["order_date"]~string then return -1
  if left["order_date"]~string < right["order_date"]~string then return 1
  return 0


oracleCorrelatedAggregateSummary: procedure
  use arg rs, engine
  customers = engine~table("customers")
  orders = engine~table("orders")
  items = engine~table("order_items")
  if customers == .nil | orders == .nil | items == .nil then return .false
  ordersByCustomer = .table~new
  do o over orders~storage~readRows
    key = o["customer_id"]~string
    bucket = ordersByCustomer[key]
    if bucket == .nil then do; bucket = .array~new; ordersByCustomer[key] = bucket; end
    bucket~append(o)
  end
  itemsByOrder = .table~new
  do oi over items~storage~readRows
    key = oi["order_id"]~string
    bucket = itemsByOrder[key]
    if bucket == .nil then do; bucket = .array~new; itemsByOrder[key] = bucket; end
    bucket~append(oi)
  end
  expected = .array~new
  do c over customers~storage~readRows
    x = .table~new
    x["customer_id"] = c["customer_id"]
    x["full_name"] = c["full_name"]
    x["order_count"] = 0
    x["lifetime_value"] = 0
    x["last_order"] = .nil
    customerOrders = ordersByCustomer[c["customer_id"]~string]
    if customerOrders \== .nil then do
      x["order_count"] = customerOrders~items
      do o over customerOrders
        if x["last_order"] == .nil then x["last_order"] = o["order_date"]
        else if o["order_date"]~string > x["last_order"]~string then x["last_order"] = o["order_date"]
        orderItems = itemsByOrder[o["order_id"]~string]
        if orderItems \== .nil then do oi over orderItems
          x["lifetime_value"] += oi["quantity"] * oi["unit_price"]
        end
      end
    end
    expected~append(x)
  end
  i = 2
  do while i <= expected~items
    current = expected[i]
    j = i - 1
    do while j >= 1
      if expected[j]["lifetime_value"] >= current["lifetime_value"] then leave
      expected[j + 1] = expected[j]
      j -= 1
    end
    expected[j + 1] = current
    i += 1
  end
  if rs~rows~items \= expected~items then return .false
  i = 1
  do row over rs~rows
    want = expected[i]
    if row["c.customer_id"]~string \= want["customer_id"]~string then return .false
    if row["c.full_name"]~string \= want["full_name"]~string then return .false
    if row["order_count"]~string \= want["order_count"]~string then return .false
    if row["lifetime_value"]~string \= want["lifetime_value"]~string then return .false
    if want["last_order"] == .nil then do
      if row["last_order"] \== .nil then return .false
    end
    else if row["last_order"]~string \= want["last_order"]~string then return .false
    i += 1
  end
  return .true

oracleCrossJoin: procedure
  use arg rs, engine
  customers = engine~table("customers")
  employees = engine~table("employees")
  if customers == .nil then return .false
  if employees == .nil then return .false
  expected = .table~new
  expectedCount = 0
  do c over customers~storage~readRows
    if c["city"] \= "Glasgow" then iterate
    do e over employees~storage~readRows
      sig = c["full_name"] || "1F"x || e["full_name"] || "1F"x || e["department"]
      count = expected[sig]
      if count == .nil then count = 0
      expected[sig] = count + 1
      expectedCount += 1
    end
  end
  if rs~rows~items \= expectedCount then return .false
  previousDepartment = .nil
  do row over rs~rows
    dept = row["e.department"]
    if dept == .nil then return .false
    if previousDepartment \== .nil then do
      if dept~string < previousDepartment~string then return .false
    end
    previousDepartment = dept
    sig = row["c.full_name"] || "1F"x || row["e.full_name"] || "1F"x || dept
    count = expected[sig]
    if count == .nil then return .false
    if count <= 0 then return .false
    expected[sig] = count - 1
  end
  do sig over expected
    if expected[sig] \= 0 then return .false
  end
  return .true

selfClass: procedure
  use arg rs
  if rs~status = .Error~SUCCESS then return "PASS"
  if rs~error = .Error~SQLUNSUPPORTED then return "UNSUPPORTED"
  if rs~error = .Error~SQLPARSEERROR then return "PARSE_ERROR"
  return "EXECUTION_ERROR"

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
