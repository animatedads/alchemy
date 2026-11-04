/* NoSQLServer v0.91: coherent WAL-capable writable SQLite engine.
 * Semantics: NoSQLServer parses SQL and evaluates predicates; this adapter
 * generates ONLY quoted/parameterized storage DML. Native SQLite supplies
 * WAL-aware consistent snapshot files for the ooRexx read parser and
 * transactional mutation batches. Existing read-only and GeoPackage engines
 * remain untouched. This is not an SQLite SQL interpreter. */

::class SQLiteNativeWriteBridge
::method apply external "LIBRARY nosqlsqlitewriter sqliteApplyBatch"
::method applyGuarded external "LIBRARY nosqlsqlitewriter sqliteApplyBatchGuarded"
::method createFile external "LIBRARY nosqlsqlitewriter sqliteCreateFile"
::method createSnapshot external "LIBRARY nosqlsqlitewriter sqliteCreateSnapshot"
::method deleteSnapshot external "LIBRARY nosqlsqlitewriter sqliteDeleteSnapshot"

::class SQLiteWritableDatabaseEngine subclass SQLiteDatabaseEngine public

::method create class
  -- Explicit new-database operation; ordinary NEW never creates files.
  use arg path, alchemySealer = .nil, alchemyAuthority = .nil
  outcome = .SQLiteNativeWriteBridge~new~createFile(path)
  if outcome["STATUS"] \= "SUCCESS" then raise syntax 93.900 additional(outcome["MESSAGE"])
  return self~new(path, alchemySealer, alchemyAuthority)

::method init
  use arg path, alchemySealer = .nil, alchemyAuthority = .nil
  outcome = .SQLiteNativeWriteBridge~new~createSnapshot(path)
  if outcome["STATUS"] \= "SUCCESS" then raise syntax 93.900 additional(outcome["MESSAGE"])
  snapshot = outcome["PATH"]
  -- Bootstrap the inherited native parser against the complete stable image.
  self~init:super(snapshot, alchemySealer, alchemyAuthority)
  self~path = path
  self~snapshotPath = snapshot
  self~inSQLStatement = .false
  self~registerNoSQLMethod("INSERT", "append SQLite relation rows", "MUTATE")
  self~registerNoSQLMethod("INSERTMANY", "atomically append SQLite rows", "MUTATE")
  self~registerNoSQLMethod("UPDATEWHERE", "atomically mutate selected SQLite rows", "MUTATE")
  self~registerNoSQLMethod("DELETEWHERE", "atomically delete selected SQLite rows", "MUTATE")
  self~registerNoSQLMethod("CREATETABLE", "create SQLite table through NoSQL schema", "MUTATE")
  self~registerNoSQLMethod("DROPTABLE", "remove SQLite table through NoSQL schema", "MUTATE")

::method version
  v = self~version:super
  v~storage = "SQLITE_NATIVE_READWRITE"
  v~features = .array~of("SQLITE_CONSISTENT_BACKUP_READ", "SQLITE_WAL_READ_WRITE", "SQLITE_PREPARED_ATOMIC_WRITE", "SQLITE_TABLE_SERIALIZABILITY_GUARD", "SQLITE_NATIVE_RELATION_PROVIDER", "DATABASE_CORE_V034_RELATIONAL_SOURCE", "MUTATION_RESULTS")
  return v


::attribute snapshotPath
::attribute inSQLStatement

::method selectWhere
  -- A direct engine selection gets a fresh snapshot. SQL executor selects
  -- reuse the single image acquired at its statement boundary (even joins).
  use arg tableName, predicate
  if \self~inSQLStatement then do
    refreshed = self~refreshNative
    if refreshed~isA(.DatabaseResult) then return refreshed
  end
  return self~selectWhere:super(tableName, predicate)

::method endSQLStatement
  self~inSQLStatement = .false

::method beginSQLStatement
  -- Construct one coherent image immediately before NoSQL parses and executes
  -- the statement. All joins and subqueries in it use the same image.
  outcome = self~refreshNative
  if outcome~isA(.DatabaseResult) then return outcome
  self~inSQLStatement = .true
  return .nil

::method refreshNative
  -- Unlike the inherited direct-file refresh, this does not touch the live
  -- SQLite file's bytes; WAL frames are applied by SQLite's backup API.
  bridge = .SQLiteNativeWriteBridge~new
  outcome = bridge~createSnapshot(self~path)
  if outcome["STATUS"] \= "SUCCESS" then return self~failWrite(.DatabaseOperationType~SELECT, .Error~STORAGEERROR, outcome["MESSAGE"])
  fresh = outcome["PATH"]
  old = self~snapshotPath
  originalPath = self~path
  self~path = fresh
  -- SQLiteDatabaseEngine already implements schema discovery and native rows.
  count = self~refreshNative:super
  self~path = originalPath
  self~snapshotPath = fresh
  if old \= .nil then do
    ignored = stream(old,"c","close")
    ignoreResult = bridge~deleteSnapshot(old)
  end
  return count

::method uninit
  if self~snapshotPath \= .nil then do
    old = self~snapshotPath
    self~snapshotPath = .nil
    ignored = stream(old,"c","close")
    outcome = .SQLiteNativeWriteBridge~new~deleteSnapshot(old)
  end

::method quoteName private
  use arg name
  return '"' || changestr('"', name~string, '""') || '"'

::method bind private
  use arg value, column
  if value == .nil then return .array~of("NULL", "")
  if value~isA(.SQLiteNativeBlob) then return .array~of("BLOB", value~bytes)
  type = "TEXT"
  if column  \= .nil then do
    if column~type = "INTEGER" then type = "INTEGER"
    if column~type = "DECIMAL" then type = "DECIMAL"
    if column~type = "BLOB" then type = "BLOB"
  end
  return .array~of(type, value~string)

::method failWrite private
  use arg op, code, message
  return .DatabaseResult~new(op)~fail(code, message)

::method apply private
  use arg operationType, ops, guardTable = .nil
  rs = .DatabaseResult~new(operationType)
  if ops~items = 0 & guardTable == .nil then do
    rs~affectedRows = 0
    return rs
  end
  bridge = .SQLiteNativeWriteBridge~new
  if guardTable == .nil then outcome = bridge~apply(self~path, ops)
  else outcome = bridge~applyGuarded(self~path, ops, self~snapshotPath, guardTable)
  if outcome["STATUS"]  \= "SUCCESS" then return rs~fail(.Error~STORAGEERROR, outcome["MESSAGE"])
  rs~affectedRows = outcome["AFFECTED"]
  rs~accessPath = "SQLITE_NATIVE_PREPARED_WRITE"
  -- Refresh only following durable successful commit; never on failure.
  refreshed = self~refreshNative
  if refreshed~isA(.DatabaseResult) then do
    -- Durable commit already happened: report success, never a fake rollback.
    rs~accessPath = "SQLITE_NATIVE_PREPARED_WRITE_SNAPSHOT_REFRESH_FAILED"
    rs~message = "SQLite write committed, but local read snapshot refresh failed: " || refreshed~message
  end
  return rs

::method insert
  use arg tableName, row
  return self~insertMany(tableName, .array~of(row))

::method insertMany
  use arg tableName, rows
  t = self~table(tableName)
  if t == .nil then return self~failWrite(.DatabaseOperationType~INSERT, .Error~NOTFOUND, "SQLite table not found")
  if t~nativeTable~withoutRowid then return self~failWrite(.DatabaseOperationType~INSERT, .Error~SQLUNSUPPORTED, "WITHOUT ROWID unsupported by native read path")
  def = t~definition
  ops = .array~new
  do row over rows
    rawValues = row
    if row~isA(.DatabaseRow) then rawValues = row~values
    -- Canonicalize SQL identifiers before building any native statement.
    values = .table~new
    do suppliedName over rawValues~allIndexes
      canonical = def~canonicalColumn(suppliedName)
      if canonical == .nil then return self~failWrite(.DatabaseOperationType~INSERT, .Error~SCHEMAERROR, "Unknown INSERT column:" suppliedName)
      if values~hasIndex(canonical) then return self~failWrite(.DatabaseOperationType~INSERT, .Error~SCHEMAERROR, "Duplicate INSERT column:" canonical)
      values[canonical] = rawValues[suppliedName]
    end
    cols = .array~new
    do colName over def~columnNames
      if values~hasIndex(colName) then cols~append(colName)
    end
    bindings = .array~new
    if cols~items = 0 then sql = "INSERT INTO " || self~quoteName(t~definition~name) || " DEFAULT VALUES"
    else do
      names = ""
      markers = ""
      do name over cols
        if names  \= "" then do
          names ||= ","
          markers ||= ","
        end
        names ||= self~quoteName(name)
        markers ||= "?"
        bindings~append(self~bind(values[name], def~column(name)))
      end
      sql = "INSERT INTO " || self~quoteName(def~name) || " (" || names || ") VALUES (" || markers || ")"
    end
    ops~append(.array~of(sql, bindings, 1))
  end
  return self~apply(.DatabaseOperationType~INSERT, ops)

::method buildGuard private
  use arg def, old, params
  -- A row is identified by its declared PK, AND guarded by ALL original
  -- columns to reject stale mutation snapshots (including NULL and BLOBs).
  guard = ""
  do name over def~primaryKey
    if guard  \= "" then guard ||= " AND "
    guard ||= self~quoteName(name) || " IS ?"
    params~append(self~bind(old[name], def~column(name)))
  end
  do name over def~columnNames
    if guard  \= "" then guard ||= " AND "
    guard ||= self~quoteName(name) || " IS ?"
    params~append(self~bind(old[name], def~column(name)))
  end
  return guard

::method updateWhere
  use arg tableName, predicate, assignments
  t = self~table(tableName)
  if t == .nil then return self~failWrite(.DatabaseOperationType~UPDATE, .Error~NOTFOUND, "SQLite table not found")
  def = t~definition
  if def~primaryKey~items = 0 | t~nativeTable~withoutRowid then return self~failWrite(.DatabaseOperationType~UPDATE, .Error~SQLUNSUPPORTED, "Writable UPDATE requires supported declared PRIMARY KEY")
  if assignments~items = 0 then return self~failWrite(.DatabaseOperationType~UPDATE, .Error~INVALIDARGUMENT, "UPDATE needs assignments")
  normalized = .table~new
  do name over assignments~allIndexes
    canonical = def~canonicalColumn(name)
    if canonical == .nil then return self~failWrite(.DatabaseOperationType~UPDATE, .Error~SCHEMAERROR, "Unknown UPDATE column:" name)
    if normalized~hasIndex(canonical) then return self~failWrite(.DatabaseOperationType~UPDATE, .Error~SCHEMAERROR, "Duplicate UPDATE column:" canonical)
    normalized[canonical] = assignments[name]
  end
  assignments = normalized
  ops = .array~new
  do old over t~readRows
    if predicate  \= .nil then do
      if \predicate~evaluate(old, def) then iterate
    end
    params = .array~new
    setter = ""
    do name over def~columnNames
      if assignments~hasIndex(name) then do
        if setter  \= "" then setter ||= ","
        setter ||= self~quoteName(name) || "=?"
        params~append(self~bind(assignments[name],def~column(name)))
      end
    end
    guard = self~buildGuard(def, old, params)
    sql = "UPDATE " || self~quoteName(def~name) || " SET " || setter || " WHERE " || guard
    ops~append(.array~of(sql, params, 1))
  end
  return self~apply(.DatabaseOperationType~UPDATE, ops, def~name)

::method deleteWhere
  use arg tableName, predicate
  t = self~table(tableName)
  if t == .nil then return self~failWrite(.DatabaseOperationType~DELETE, .Error~NOTFOUND, "SQLite table not found")
  def = t~definition
  if def~primaryKey~items = 0 | t~nativeTable~withoutRowid then return self~failWrite(.DatabaseOperationType~DELETE, .Error~SQLUNSUPPORTED, "Writable DELETE requires supported declared PRIMARY KEY")
  ops = .array~new
  do old over t~readRows
    if predicate  \= .nil then do
      if \predicate~evaluate(old, def) then iterate
    end
    params = .array~new
    guard = self~buildGuard(def,old,params)
    sql = "DELETE FROM " || self~quoteName(def~name) || " WHERE " || guard
    ops~append(.array~of(sql, params, 1))
  end
  return self~apply(.DatabaseOperationType~DELETE, ops, def~name)

::method createTable
  use arg name, columns, primaryKey = .nil, uniques = .nil, separator = ",", nullToken = "\\N", foreignKeys = .nil
  if self~table(name)  \= .nil then return self~failWrite(.DatabaseOperationType~CREATE, .Error~ALREADYEXISTS, "Table exists")
  if columns == .nil | columns~items = 0 then return self~failWrite(.DatabaseOperationType~CREATE, .Error~SCHEMAERROR, "Columns required")
  if primaryKey == .nil then primaryKey = .array~new
  if uniques == .nil then uniques = .array~new
  if foreignKeys == .nil then foreignKeys = .array~new
  parts = .array~new
  do col over columns
    t = col~type
    -- Never interpolate unvalidated arbitrary type tokens into native DDL.
    if t \= "INTEGER" & t \= "DECIMAL" & t \= "VARCHAR" & ,
       t \= "TEXT" & t \= "BLOB" & t \= "DATE" & t \= "DATETIME" then ,
       return self~failWrite(.DatabaseOperationType~CREATE, .Error~SQLUNSUPPORTED, "SQLite DDL type unsupported:" t)
    if t = "DECIMAL" then t = "REAL"
    if t = "VARCHAR" | t = "DATE" | t = "DATETIME" then t = "TEXT"
    fragment = self~quoteName(col~name) || " " || t
    if \col~nullable then fragment ||= " NOT NULL"
    if col~unique then fragment ||= " UNIQUE"
    parts~append(fragment)
  end
  if primaryKey~items > 0 then do
    names = ""
    do n over primaryKey
      if names  \= "" then names ||= ","
      names ||= self~quoteName(n)
    end
    parts~append("PRIMARY KEY (" || names || ")")
  end
  do u over uniques
    names = ""
    do n over u
      if names  \= "" then names ||= ","
      names ||= self~quoteName(n)
    end
    parts~append("UNIQUE (" || names || ")")
  end
  do fk over foreignKeys
    parts~append("FOREIGN KEY (" || self~quoteName(fk~column) || ") REFERENCES " || self~quoteName(fk~referencesTable) || "(" || self~quoteName(fk~referencesColumn) || ") ON DELETE " || fk~onDelete || " ON UPDATE " || fk~onUpdate)
  end
  body = ""
  do fragment over parts
    if body  \= "" then body ||= ","
    body ||= fragment
  end
  ops = .array~of(.array~of("CREATE TABLE " || self~quoteName(name) || " (" || body || ")", .array~new, 0))
  return self~apply(.DatabaseOperationType~CREATE, ops)

::method dropTable
  use arg name
  t = self~table(name)
  if t == .nil then return self~failWrite(.DatabaseOperationType~DROP, .Error~NOTFOUND, "Table not found")
  return self~apply(.DatabaseOperationType~DROP, .array~of(.array~of("DROP TABLE " || self~quoteName(t~definition~name), .array~new, 0)))

::requires "NoSQLServer.cls"
