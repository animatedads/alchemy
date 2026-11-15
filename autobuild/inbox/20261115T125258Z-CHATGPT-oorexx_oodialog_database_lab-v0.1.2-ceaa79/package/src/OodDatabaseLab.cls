/* ooDialog Database Lab -- a bounded, disposable NoSQLServer FILE playground.
 * Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
 * The editor/browser only projects this object's state. All SQL, DDL,
 * validation, cataloguing and row semantics remain with Alchemy NoSQLServer.
 * No native SQLite bridge or JS-owned database is involved.
 */

::requires "NoSQLServer.cls"
::requires "OodNls.cls"

::class OodDatabaseLab public inherit OodNls
::method module_version class
  return "0.1.2"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.1.2"
::method module_lastChanged
  return "2026-11-15"

::attribute base get
::attribute name get

::method resources
  return .resources

::method language
  use strict arg lang = ""
  return self~nlsUse(lang, "en", self~resources)

::method refusal private
  use strict arg key, detail = .nil
  if detail == .nil then raise syntax 93.900 array(self~nls(key))
  raise syntax 93.900 array(self~nls(key, detail))

::method init
  expose base name engine sql
  use arg base = "/home/rexx/db-lab"
  base = base~string~strip
  self~language("")
  if base = "" then self~refusal("err.storageRoot")
  if base~right(1) = "/" then base = base~left(base~length - 1)
  name = ""
  engine = .nil
  sql = .nil

::method databaseNames
  expose base
  call SysFileTree base || "/*", found., "DO"
  names = .array~new
  do i = 1 to found.0
    path = found.i~changeStr("\", "/")
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
  if mkdirRc \= 0 & \self~isDirectory(base) then self~refusal("err.createRoot")
  path = base || "/" || name
  if self~isDirectory(path) | stream(path, "c", "query exists") \= "" then self~refusal("err.databaseExists", name)
  if SysMkDir(path) \= 0 then self~refusal("err.createDatabase", name)
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
  if stream(path || "/database.yaml", "c", "query exists") = "" then self~refusal("err.databaseNotFound", selected)
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

/* Typed, stable graph projection of the live NoSQLServer catalogue.
 * The optional OBJECT/PART lines are supplied by the mapped-object store;
 * unknown future line kinds are ignored. No SQL text is parsed here.
 */
::method graphLines
  expose engine
  use strict arg extraLines = ""
  self~requireOpen
  lines = .array~new
  names = engine~readCatalog["tables"]
  if names \== .nil then do tableName over names~sort
    table = engine~table(tableName)
    if table == .nil then iterate
    definition = table~definition
    lines~append("TABLE" || "09"x || tableName || "09"x || table~rowCount)
    do col over definition~columns
      lines~append("COLUMN" || "09"x || tableName || "09"x || col~name || "09"x || col~type || "09"x || -
        col~nullable || "09"x || col~primaryKey || "09"x || col~unique)
    end
    do fk over definition~foreignKeys
      lines~append("FK" || "09"x || tableName || "09"x || fk~column || "09"x || -
        fk~referencesTable || "09"x || fk~referencesColumn || "09"x || fk~onDelete)
    end
  end
  if extraLines \== "" then do line over extraLines~string~changeStr("0d"x, "")~makeArray("0a"x)
    fields = line~makeArray("09"x)
    kind = fields[1]~upper
    if kind = "OBJECT" & fields~items >= 3 then lines~append(line)
    if kind = "PART" & fields~items >= 7 then lines~append(line)
  end
  return lines~makeString("L", "0a"x)

::method schema
  expose engine
  use strict arg tableName
  self~requireOpen
  tableName = self~requireName(tableName)
  t = engine~table(tableName)
  if t == .nil then self~refusal("err.tableNotFound", tableName)
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
  if t == .nil then self~refusal("err.tableNotFound", tableName)
  newDDL = self~createDDL(tableName, columns)  -- validate first
  if t~rowCount \= 0 then self~refusal("err.tableHasRows")
  if t~definition~foreignKeys~items > 0 then self~refusal("err.hasForeignKeys")
  -- An unrelated table may still refer to this one. Never break that link.
  do otherName over engine~readCatalog["tables"]
    if otherName~caselessEquals(tableName) then iterate
    other = engine~table(otherName)
    if other == .nil then iterate
    do fk over other~definition~foreignKeys
      if fk~referencesTable~caselessEquals(tableName) then self~refusal("err.referencedTable")
    end
  end
  oldDDL = self~ddlForExisting(t~definition)
  self~ensureSQL(sql~execute("DROP TABLE " || tableName))
  created = sql~execute(newDDL)
  if created~status = .Error~SUCCESS then return created~status
  -- Best-effort restoration of the empty original schema on a failed CREATE.
  restored = sql~execute(oldDDL)
  if restored~status \= .Error~SUCCESS then self~refusal("err.restoreFailed", restored~message)
  self~refusal("err.amendFailed", created~message)

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
  if statement = "" then self~refusal("err.enterSQL")
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
    if key~items > 1 then self~refusal("err.compositeUnique")
  end
  if definition~primaryKey~items > 1 then self~refusal("err.compositePrimary")
  return "CREATE TABLE " || definition~name || " (" || out~makeString("L", ", ") || ")"

::method createDDL private
  use strict arg tableName, columns
  spec = columns~string~changeStr("0d"x, "")~makeArray("0a"x)
  if spec~items < 1 | spec~items > 64 then self~refusal("err.columnCount")
  defs = .array~new
  seen = .set~new
  pks = 0
  do line over spec
    parts = line~makeArray("09"x)
    if parts~items \= 5 then self~refusal("err.columnFields")
    column = self~requireName(parts[1])
    if seen~hasIndex(column~upper) then self~refusal("err.duplicateColumn", column)
    seen~put(column~upper)
    dtype = parts[2]~upper
    if wordpos(dtype, "INTEGER VARCHAR TEXT DECIMAL BOOLEAN DATE DATETIME BLOB") = 0 then self~refusal("err.columnType", dtype)
    do i = 3 to 5
      if parts[i] \= "0" & parts[i] \= "1" then self~refusal("err.columnFlags")
    end
    if parts[4] = "1" then pks += 1
    item = column || " " || dtype
    if parts[4] = "1" then item ||= " PRIMARY KEY"
    else if parts[3] = "0" then item ||= " NOT NULL"
    if parts[5] = "1" then item ||= " UNIQUE"
    defs~append(item)
  end
  if pks > 1 then self~refusal("err.primaryCount")
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
  if \self~validName(candidate) then self~refusal("err.invalidName", candidate)
  return candidate~string~strip

::method isDirectory private
  use strict arg path
  call SysFileTree path, directories., "DO"
  return directories.0 > 0

::method requireOpen private
  expose sql
  if sql == .nil then self~refusal("err.databaseClosed")

::method ensureSQL private
  use strict arg result
  if result~status \= .Error~SUCCESS then self~refusal("err.sqlFailed", result~error || ": " || result~message)
  return result

::resource strings.en
err.storageRoot = Database Lab needs a storage root
err.createRoot = Cannot create Database Lab storage root
err.databaseExists = Database already exists: %1
err.createDatabase = Cannot create database directory: %1
err.databaseNotFound = Database not found: %1
err.tableNotFound = Table not found: %1
err.tableHasRows = Table contains rows; schema migration is not yet supported
err.hasForeignKeys = Cannot rebuild a table with foreign keys
err.referencedTable = Table is referenced by a foreign key
err.restoreFailed = Table amendment failed; original schema could not be restored: %1
err.amendFailed = Table amendment failed; original schema restored: %1
err.enterSQL = Enter one SQL statement
err.compositeUnique = Cannot rebuild a table with composite unique constraints
err.compositePrimary = Cannot rebuild a table with composite primary key
err.columnCount = A table needs 1-64 columns
err.columnFields = Columns require name, type, nullable, primary and unique
err.duplicateColumn = Duplicate column: %1
err.columnType = Unsupported column type: %1
err.columnFlags = Column flags must be 0 or 1
err.primaryCount = Only one primary-key column is supported in the lab
err.invalidName = Invalid database, table or column name: %1
err.databaseClosed = Create or open a database first
err.sqlFailed = SQL failed: %1
::END

::resource strings.de
err.storageRoot = Das Datenbanklabor benötigt ein Speicherverzeichnis
err.createRoot = Das Speicherverzeichnis des Datenbanklabors konnte nicht erstellt werden
err.databaseExists = Datenbank ist bereits vorhanden: %1
err.createDatabase = Das Datenbankverzeichnis konnte nicht erstellt werden: %1
err.databaseNotFound = Datenbank nicht gefunden: %1
err.tableNotFound = Tabelle nicht gefunden: %1
err.tableHasRows = Die Tabelle enthält Zeilen; eine Schemamigration wird noch nicht unterstützt
err.hasForeignKeys = Eine Tabelle mit Fremdschlüsseln kann nicht neu aufgebaut werden
err.referencedTable = Andere Tabellen verweisen über einen Fremdschlüssel auf diese Tabelle
err.restoreFailed = Tabellenänderung fehlgeschlagen; ursprüngliches Schema konnte nicht wiederhergestellt werden: %1
err.amendFailed = Tabellenänderung fehlgeschlagen; ursprüngliches Schema wurde wiederhergestellt: %1
err.enterSQL = Eine SQL-Anweisung eingeben
err.compositeUnique = Tabelle mit zusammengesetzten Eindeutigkeitsregeln kann nicht neu aufgebaut werden
err.compositePrimary = Tabelle mit zusammengesetztem Primärschlüssel kann nicht neu aufgebaut werden
err.columnCount = Eine Tabelle benötigt 1 bis 64 Spalten
err.columnFields = Spalten benötigen Name, Typ, NULL-Erlaubnis, Primärschlüssel und Eindeutigkeit
err.duplicateColumn = Doppelte Spalte: %1
err.columnType = Nicht unterstützter Spaltentyp: %1
err.columnFlags = Spaltenkennzeichen müssen 0 oder 1 sein
err.primaryCount = Im Datenbanklabor ist nur eine Primärschlüsselspalte erlaubt
err.invalidName = Ungültiger Datenbank-, Tabellen- oder Spaltenname: %1
err.databaseClosed = Zuerst eine Datenbank erstellen oder öffnen
err.sqlFailed = SQL fehlgeschlagen: %1
::END
