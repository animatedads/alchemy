/* Runtime Registry v0.9 NoSQLServer ability fixture.
 * The profile supplies logical resources. The client never supplies SQL.
 */

::class RuntimeNoSQLAbility public

::method runtimePrepare
  expose engine databaseRoot invocationCount
  use arg context
  invocationCount = 0
  databaseRoot = .NoSQLServerTestSupport~createBlankDatabase("ability-nosql")
  engine = .FederatedDatabaseEngine~new(databaseRoot)

  createResult = engine~execute("CREATE TABLE orders (id INTEGER PRIMARY KEY, customer_id INTEGER, total INTEGER)")
  if createResult~status <> .Error~SUCCESS then return .false
  insertResult = engine~execute("INSERT INTO orders VALUES (101,1,75),(102,2,20),(103,1,50)")
  if insertResult~status <> .Error~SUCCESS then return .false

  customers = .array~of(.RuntimeNoSQLCustomer~new(1,"Ada"), .RuntimeNoSQLCustomer~new(2,"Grace"))
  mapping = .ObjectTableMapping~new("customers_snapshot")
  ignored = mapping~column("id", "INTEGER", "id")
  ignored = mapping~column("name", "VARCHAR", "name")
  if \engine~registerSnapshot("customers_snapshot", customers, mapping) then return .false
  return .true

::method runtimeSelfTest
  expose engine
  if engine == .nil then return .false
  probe = engine~execute("SELECT o.id AS order_id,c.name AS customer_name,o.total AS total FROM orders o INNER JOIN customers_snapshot c ON o.customer_id=c.id ORDER BY o.id")
  if probe~status <> .Error~SUCCESS then return .false
  if probe~rows~items <> 3 then return .false
  if probe~rows[1]["customer_name"] <> "Ada" then return .false
  if probe~accessPath <> "FEDERATED_TABLE_SCAN" then return .false
  return .true

::method runtimeQuiesce
  return .true

::method runtimeStop
  expose engine databaseRoot
  engine = .nil
  if databaseRoot <> "" then ignored = .NoSQLServerTestSupport~removeDatabase(databaseRoot)
  databaseRoot = ""
  return .true

::method invocationCount
  expose invocationCount
  return invocationCount

::method runtimeInvokeAbility
  expose engine invocationCount
  use arg abilityId, context
  if abilityId <> "query" then return context~failure("ABILITY_UNKNOWN", abilityId)
  invocationCount = invocationCount + 1
  body = context~body
  logicalResource = body~at("resource")
  if logicalResource == .nil then return context~failure("RESOURCE_REQUIRED", "resource")
  logicalResource = logicalResource~string~strip~lower
  if \self~safeLogicalName(logicalResource) then return context~failure("RESOURCE_INVALID", logicalResource)

  binding = context~dataBinding(logicalResource)
  if binding == .nil then return context~failure("RESOURCE_NOT_GRANTED", logicalResource)
  if binding~accessMode~wordPos("READ") = 0 then return context~failure("RESOURCE_READ_REQUIRED", logicalResource)

  descriptor = binding~resourceName
  descriptorKind = ""
  if descriptor~left(6)~lower = "table:" then do
    descriptorKind = "table"
    tableName = descriptor~substr(7)~strip
    if \self~safeIdentifier(tableName) then return context~failure("RESOURCE_DESCRIPTOR_INVALID", descriptor)
    sqlText = "SELECT * FROM " || tableName
  end
  else if descriptor~left(4)~lower = "sql:" then do
    descriptorKind = "sql"
    sqlText = descriptor~substr(5)
    if sqlText~strip~left(6)~upper <> "SELECT" then return context~failure("RESOURCE_DESCRIPTOR_INVALID", descriptor)
  end
  else return context~failure("RESOURCE_DESCRIPTOR_INVALID", descriptor)

  /* Client ordering is accepted only for simple table descriptors.  Configured
   * SQL projections own their ordering as part of the server-side descriptor. */
  orderBy = body~at("order_by")
  if orderBy \== .nil then do
    if descriptorKind <> "table" then return context~failure("ORDER_BY_NOT_ALLOWED", "configured SQL owns its ordering")
    if \orderBy~isa(.Array) then return context~failure("ORDER_BY_INVALID", "order_by must be an array")
    if orderBy~items > 4 then return context~failure("ORDER_BY_INVALID", "too many order columns")
    orderText = ""
    do i = 1 to orderBy~items
      columnName = orderBy~at(i)~string~strip
      if \self~safeIdentifier(columnName) then return context~failure("ORDER_BY_INVALID", columnName)
      if i > 1 then orderText = orderText || ","
      orderText = orderText || columnName
    end
    if orderText <> "" then sqlText = sqlText || " ORDER BY " || orderText
  end

  limitValue = body~at("limit")
  if limitValue == .nil then limitValue = 100
  if \datatype(limitValue, "W") then return context~failure("LIMIT_INVALID", limitValue)
  if limitValue < 1 | limitValue > 100 then return context~failure("LIMIT_INVALID", limitValue)
  sqlText = sqlText || " LIMIT " || limitValue

  queryResult = engine~execute(sqlText)
  if queryResult~status <> .Error~SUCCESS then return context~failure(queryResult~error, queryResult~message)

  output = .directory~new
  output["resource"] = logicalResource
  output["rows"] = self~projectRows(queryResult)
  output["row_count"] = queryResult~rows~items
  output["query_evidence"] = .RuntimeNoSQLQueryEvidence~new(logicalResource, engine~version~release, queryResult)
  return context~success(output)

::method projectRows private
  use arg queryResult
  rows = .array~new
  metadata = queryResult~metadata
  columnNames = .array~new
  if metadata \== .nil then do
    columns = metadata~columns
    do i = 1 to columns~items
      columnNames~append(columns~at(i)~name)
    end
  end
  do sourceRow over queryResult~rows
    row = .directory~new
    if columnNames~items > 0 then do columnName over columnNames
      row[columnName] = sourceRow[columnName]
    end
    else do columnName over sourceRow~values
      row[columnName] = sourceRow[columnName]
    end
    rows~append(row)
  end
  return rows

::method safeLogicalName private
  use arg text
  if text = "" then return .false
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if (ch >= "a" & ch <= "z") | (ch >= "0" & ch <= "9") | ch = "." | ch = "_" | ch = "-" then iterate
    return .false
  end
  return .true

::method safeIdentifier private
  use arg text
  if text = "" then return .false
  do i = 1 to text~length
    ch = text~substr(i, 1)
    if (ch >= "A" & ch <= "Z") | (ch >= "a" & ch <= "z") | (ch >= "0" & ch <= "9") | ch = "_" | ch = "." then iterate
    return .false
  end
  return .true

::class RuntimeNoSQLCustomer
::attribute id
::attribute name
::method init
  expose id name
  use arg id, name

::class RuntimeNoSQLQueryEvidence public
::attribute value get
::attribute name get
::attribute semanticType get
::method init
  expose logicalResource version queryResult value name semanticType
  use arg logicalResource, version, queryResult
  value = queryResult~rows~items
  name = "query-provenance"
  semanticType = "NOSQL_QUERY_EXECUTION"
::method isEvidenceBearing
  return .true
::method sourcePath
  expose logicalResource
  return "nosql://" || logicalResource
::method provenance
  expose logicalResource version queryResult
  d = .directory~new
  d["product"] = "NoSQLServer"
  d["release"] = version
  d["resource"] = logicalResource
  d["access_path"] = queryResult~accessPath
  d["rows_scanned"] = queryResult~rowsScanned
  d["row_count"] = queryResult~rows~items
  if queryResult~snapshotGeneration \== .nil then d["snapshot_generation"] = queryResult~snapshotGeneration
  return d

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
