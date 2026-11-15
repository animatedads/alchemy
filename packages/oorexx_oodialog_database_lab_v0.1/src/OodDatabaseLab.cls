/* ooDialog Database Lab -- a bounded, disposable NoSQLServer FILE playground.
 * The editor/browser only projects this object's state. All SQL, DDL,
 * validation, cataloguing and row semantics remain with Alchemy NoSQLServer.
 * No native SQLite bridge or JS-owned database is involved.
 */

::requires "NoSQLServer.cls"

::class OodDatabaseLab public
::attribute base get
::attribute name get

::method init
  expose base name engine sql
  use arg base = "/home/rexx/db-lab"
  base = base~string~strip
  if base = "" then raise syntax 93.900 array("Database Lab needs a storage root")
  if base~right(1) = "/" then base = base~left(base~length - 1)
  name = ""
  engine = .nil
  sql = .nil

::method databaseNames
  expose base
  call SysFileTree base || "/*", found., "DO"
  names = .array~new
  do i = 1 to found.0
    path = found.i~changeStr("\\", "/")
    n = path~substr(path~lastPos("/") + 1)
    if self~validName(n) then do
      if stream(path || "/database.yaml", "c", "query exists") \= "" then names~append(n)
    end
  end
  if names~items = 0 then return ""
  return names~sort~makeString("L", "0a"x)

::method createDatabase
  expose base
  use strict arg name
  name = self~requireName(name)
  mkdirRc = SysMkDir(base)
  if mkdirRc \= 0 & \self~isDirectory(base) then raise syntax 93.900 array("Cannot create Database Lab storage root")
  path = base || "/" || name
  if self~isDirectory(path) | stream(path, "c", "query exists") \= "" then raise syntax 93.900 array("Database already exists:" name)
  if SysMkDir(path) \= 0 then raise syntax 93.900 array("Cannot create database directory:" name)
  db = .FileDatabaseEngine~new(path)
  catalog = .table~new
  catalog["name"] = name
  catalog["formatVersion"] = 1
  catalog["tables"] = .array~new
  db~writeCatalog(catalog)
  return self~openDatabase(name)

::method openDatabase
  expose base name engine sql
  use strict arg selected
  selected = self~requireName(selected)
  path = base || "/" || selected
  if stream(path || "/database.yaml", "c", "query exists") = "" then raise syntax 93.900 array("Database not found:" selected)
  engine = .FileDatabaseEngine~new(path)
  sql = .NoSQLServerSQL~new(engine)
  name = selected
  return .true

::method tableNames
  expose engine
  self~requireOpen
  names = engine~readCatalog["tables"]
  if names == .nil | names~items = 0 then return ""
  return names~makeString("L", "0a"x)

::method schema
  expose engine
  use strict arg tableName
  self~requireOpen
  tableName = self~requireName(tableName)
  t = engine~table(tableName)
  if t == .nil then raise syntax 93.900 array("Table not found:" tableName)
  out = .array~new
  do col over t~definition~columns
    out~append(col~name || "09"x || col~type || "09"x || col~nullable || "09"x || col~primaryKey || "09"x || col~unique)
  end
  return out~makeString("L", "0a"x)

/* One column per line: name TAB type TAB nullable(0/1) TAB primary(0/1)
 * TAB unique(0/1). Only explicit supported types can be used. This parser
 * deliberately does not accept arbitrary SQL or file paths as identifiers.
 */
::method createTable
  expose sql engine
  use strict arg tableName, columns
  self~requireOpen
  tableName = self~requireName(tableName)
  ddl = self~createDDL(tableName, columns)
  return self~ensureSQL(sql~execute(ddl))~status

/* A schema amendment on an EMPTY table is implemented with the backend's
 * public DROP/CREATE operations. A populated table is never silently rebuilt
 * or truncated. It requires a separate qualified data migration, not ALTER.
 */
::method replaceEmptyTable
  expose sql engine
  use strict arg tableName, columns
  self~requireOpen
  tableName = self~requireName(tableName)
  t = engine~table(tableName)
  if t == .nil then raise syntax 93.900 array("Table not found:" tableName)
  newDDL = self~createDDL(tableName, columns)  -- validate first
  if t~rowCount \= 0 then raise syntax 93.900 array("Table contains rows; schema migration is not yet supported")
  if t~definition~foreignKeys~items > 0 then raise syntax 93.900 array("Cannot rebuild a table with foreign keys")
  -- An unrelated table may still refer to this one. Never break that link.
  do otherName over engine~readCatalog["tables"]
    if otherName~caselessEquals(tableName) then iterate
    other = engine~table(otherName)
    if other == .nil then iterate
    do fk over other~definition~foreignKeys
      if fk~referencesTable~caselessEquals(tableName) then raise syntax 93.900 array("Table is referenced by a foreign key")
    end
  end
  oldDDL = self~ddlForExisting(t~definition)
  self~ensureSQL(sql~execute("DROP TABLE " || tableName))
  created = sql~execute(newDDL)
  if created~status = .Error~SUCCESS then return created~status
  -- Best-effort restoration of the empty original schema on a failed CREATE.
  restored = sql~execute(oldDDL)
  if restored~status \= .Error~SUCCESS then raise syntax 93.900 array("Table amendment failed; original schema could not be restored:" restored~message)
  raise syntax 93.900 array("Table amendment failed; original schema restored:" created~message)

::method dropTable
  expose sql
  use strict arg tableName
  self~requireOpen
  tableName = self~requireName(tableName)
  return self~ensureSQL(sql~execute("DROP TABLE " || tableName))~status

::method executeJSON
  expose sql
  use strict arg statement
  self~requireOpen
  statement = statement~string~strip
  if statement = "" then raise syntax 93.900 array("Enter one SQL statement")
  dbResult = sql~execute(statement)
  response = .directory~new
  response["status"] = dbResult~status
  response["error"] = dbResult~error
  response["message"] = dbResult~message
  response["affectedRows"] = dbResult~affectedRows
  response["rowCount"] = dbResult~rowCount
  response["accessPath"] = dbResult~accessPath
  rows = dbResult~asDirectories
  response["truncated"] = (rows~items > 200)
  if rows~items > 200 then do
    subset = .array~new
    do i = 1 to 200
      subset~append(rows[i])
    end
    rows = subset
  end
  response["rows"] = rows
  return .json~toJSON(response)

::method previewJSON
  use strict arg tableName
  tableName = self~requireName(tableName)
  return self~executeJSON("SELECT * FROM " || tableName || " LIMIT 25")

::method ddlForExisting private
  use arg definition
  out = .array~new
  do col over definition~columns
    part = col~name || " " || col~type
    if col~primaryKey then part ||= " PRIMARY KEY"
    if \col~nullable then if \col~primaryKey then part ||= " NOT NULL"
    if col~unique then part ||= " UNIQUE"
    out~append(part)
  end
  -- Only the constraints expressible as column annotations are reconstructed.
  -- The empty-schema editor refuses composite unique constraints instead.
  do key over definition~uniqueConstraints
    if key~items > 1 then raise syntax 93.900 array("Cannot rebuild a table with composite unique constraints")
  end
  if definition~primaryKey~items > 1 then raise syntax 93.900 array("Cannot rebuild a table with composite primary key")
  return "CREATE TABLE " || definition~name || " (" || out~makeString("L", ", ") || ")"

::method createDDL private
  use strict arg tableName, columns
  spec = columns~string~changeStr("0d"x, "")~makeArray("0a"x)
  if spec~items < 1 | spec~items > 64 then raise syntax 93.900 array("A table needs 1-64 columns")
  defs = .array~new
  seen = .set~new
  pks = 0
  do line over spec
    parts = line~makeArray("09"x)
    if parts~items \= 5 then raise syntax 93.900 array("Columns require name, type, nullable, primary and unique")
    column = self~requireName(parts[1])
    if seen~hasIndex(column~upper) then raise syntax 93.900 array("Duplicate column:" column)
    seen~put(column~upper)
    dtype = parts[2]~upper
    if wordpos(dtype, "INTEGER VARCHAR TEXT DECIMAL BOOLEAN DATE DATETIME BLOB") = 0 then raise syntax 93.900 array("Unsupported column type:" dtype)
    do i = 3 to 5
      if parts[i] \= "0" & parts[i] \= "1" then raise syntax 93.900 array("Column flags must be 0 or 1")
    end
    if parts[4] = "1" then pks += 1
    item = column || " " || dtype
    if parts[4] = "1" then item ||= " PRIMARY KEY"
    else if parts[3] = "0" then item ||= " NOT NULL"
    if parts[5] = "1" then item ||= " UNIQUE"
    defs~append(item)
  end
  if pks > 1 then raise syntax 93.900 array("Only one primary-key column is supported in the lab")
  return "CREATE TABLE " || tableName || " (" || defs~makeString("L", ", ") || ")"

::method validName private
  use strict arg candidate
  name = candidate~string~strip
  if name = "" | name~length > 64 then return .false
  if name~left(1)~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_") \= 0 then return .false
  if name~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789") \= 0 then return .false
  if wordpos(name~upper, "SELECT FROM TABLE CREATE DROP ALTER INSERT UPDATE DELETE WHERE ORDER GROUP") > 0 then return .false
  return .true

::method requireName private
  use strict arg candidate
  if \self~validName(candidate) then raise syntax 93.900 array("Invalid database, table or column name:" candidate)
  return candidate~string~strip

::method isDirectory private
  use strict arg path
  call SysFileTree path, directories., "DO"
  return directories.0 > 0

::method requireOpen private
  expose sql
  if sql == .nil then raise syntax 93.900 array("Create or open a database first")

::method ensureSQL private
  use strict arg result
  if result~status \= .Error~SUCCESS then raise syntax 93.900 array(result~error || ": " || result~message)
  return result
