/*
 * RexxSqlBackend.cls - SQLite through Mark Hessling's Rexx/SQL, as a NativeDatabaseBackend.
 *
 * Architecture: Tom Dyer (NativeDatabaseBackend contract, backend-neutral Semantic Source Store).
 * Rexx/SQL: Mark Hessling (LGPL), 2.6B3 with the Alchemy patches in ../upstream/patches.
 * This file: Claude (Opus 5.5), 2026-10-24.
 *
 * Classes
 *   RexxSqlSqliteBackend  - family SQLITE, implementation "rexxsql"; publishes tested
 *                           capabilities and limitations; acquire(path) -> session.
 *   RexxSqlSqliteSession  - one Rexx/SQL connection. execute(sql) returns a result with
 *                           the shape the Semantic Source Store and NoSQLServerSQL callers
 *                           use: status ("SUCCESS"/"ERROR"), message, rows, rowCount.
 *   RexxSqlResult, RexxSqlRow
 *
 * Results: SQLCOMMAND sets STMT.COLUMN.n in the caller's variable pool. execute() runs in
 * its own method activation, so no tails survive from an earlier query, and it reads the
 * values through the stem object, never through compound symbols, so a variable that
 * happens to share a column's name cannot change which tail is read.
 */

::class RexxSqlFunctions public
::method load class
  expose loaded
  if symbol("LOADED") = "VAR" then return loaded
  loaded = .false
  signal on syntax name failed
  if RxFuncQuery("SQLLoadFuncs") then call RxFuncAdd "SQLLoadFuncs", "rexxsql", "SQLLoadFuncs"
  if SQLLoadFuncs() = 0 then loaded = .true
  return loaded
failed:
  return .false

::class RexxSqlSqliteBackend public subclass NativeDatabaseBackend
::constant VERSION "2.6B3+alchemy.1"
::method init
  self~init:super("SQLITE", "rexxsql", self~VERSION, "REXX_FUNCTION_PACKAGE", 10)
  self~addRequirement("LIBREXXSQL", .true, "librexxsql.so built from Rexx/SQL 2.6B3 with upstream/patches (tools/build_rexxsql.sh); on LD_LIBRARY_PATH")
  self~addRequirement("LIBSQLITE3", .true, "SQLite 3 shared library")
  ev = "tests/test_rexxsql_driver.rex, tests/test_rexxsql_backend.rex"
  self~addCapability("MUTATION", "SUPPORTED", "TESTED", "INSERT/UPDATE/DELETE; quoted literals are stored as written", ev)
  self~addCapability("KEYED_LOOKUP_INDEXED", "SUPPORTED", "TESTED", "PRIMARY KEY lookups use SQLite b-tree indexes (~80 us per call at 20,000 rows)", ev)
  self~addCapability("SECONDARY_INDEXES", "SUPPORTED", "TESTED", "CREATE INDEX", ev)
  self~addCapability("TRANSACTIONS", "SUPPORTED", "TESTED", "BEGIN/COMMIT/ROLLBACK; otherwise each statement commits", ev)
  self~addCapability("IN_LISTS", "SUPPORTED", "TESTED", "Native SQLite; no rewriting needed", ev)
  self~addCapability("BYTE_EXACT_TEXT", "SUPPORTED", "TESTED", "CRLF, NUL bytes, UTF-8 and 100 KB values round-trip (NUL needs the Alchemy patch)", ev)
  self~addCapability("BIND_PLACEMARKERS", "SUPPORTED", "TESTED", "'?' with datatype/value pairs via executeBound", ev)
  self~addCapability("BLOB_READ", "SUPPORTED", "TESTED", "BLOB columns return their bytes (needs the Alchemy patch)", ev)
  self~addCapability("BLOB_WRITE", "UNSUPPORTED", "TESTED", "Rexx/SQL binds every value as text")
  self~addCapability("NULL_EMPTY_DISTINCT", "UNSUPPORTED", "TESTED", "NULLSTRINGIN maps an empty bound string to SQL NULL; callers needing distinct NULL and empty-string semantics must encode or reject")
  self~addCapability("WAL", "SUPPORTED", "TESTED", "File-backed sessions default to PRAGMA journal_mode=WAL")
  self~addCapability("ROLLBACK", "SUPPORTED", "TESTED", "Explicit BEGIN/COMMIT/ROLLBACK is supported")
  self~addCapability("THREAD_SAFE_CONNECTIONS", "UNKNOWN", "UNTESTED", "Rexx/SQL maintains a process-wide current connection; multi-thread use is not qualified")
  self~addCapability("EXTERNAL_NATIVE_LIBRARY", "SUPPORTED", "TESTED", "Requires librexxsql.so and libsqlite3")
  self~addLimitation("RESULTS_IN_REXX_VARIABLES", "SQLCOMMAND materialises the whole result as Rexx variables; very large SELECTs cost memory. Narrow the SELECT.")
  self~addLimitation("COLUMN_NAMES_UPPERCASED", "Result column names come back upper case; RexxSqlRow lookups are case-insensitive.")
  self~addLimitation("EXPRESSION_COLUMNS_NEED_ALIASES", "A result column must be a valid Rexx tail: alias expressions (SELECT count(*) AS n).")
  self~addLimitation("SQL_TEXT_STOPS_AT_NUL", "Statement text is passed to sqlite3_prepare as a C string; send values containing NUL through executeBound.")
::method available
  return .RexxSqlFunctions~load
::method acquire
  use strict arg source, options = .nil
  path = source
  if source~hasMethod("DATABASENAME") then path = source~databaseName
  if path == .nil then return .nil
  return .RexxSqlSqliteSession~new(self, path~string, options)

::class RexxSqlSqliteSession public
/* Process-wide connection bookkeeping: Rexx/SQL keeps one current connection. */
::method nextConnection class
  expose counter
  if symbol("COUNTER") \= "VAR" then counter = 0
  counter += 1
  return "RXSQLC" || counter
::method current class
  expose current
  if symbol("CURRENT") \= "VAR" then current = ""
  return current
::method "current=" class
  expose current
  use strict arg current
::method open class
  use strict arg path, options = .nil
  return .RexxSqlSqliteBackend~new~acquire(path, options)

::method init
  expose backend path connection closed indexPlan
  use strict arg backend, path, options = .nil
  if \.RexxSqlFunctions~load then raise syntax 98.900 array("Rexx/SQL is not loadable: build librexxsql.so (tools/build_rexxsql.sh) and put it on LD_LIBRARY_PATH")
  connection = .RexxSqlSqliteSession~nextConnection
  closed = .true
  rc = SQLConnect(connection, , , path)
  if rc \= 0 then raise syntax 98.900 array("SQLConnect failed for" path || ":" sqlca.sqlerrm sqlca.interrm)
  .RexxSqlSqliteSession~current = connection
  closed = .false
  if options == .nil then options = .directory~new
  journal = options["journal_mode"]; if journal == .nil then journal = "WAL"
  sync = options["synchronous"]; if sync == .nil then sync = "NORMAL"
  if path \= ":memory:" then do
    r = self~execute("PRAGMA journal_mode=" || journal)
    r = self~execute("PRAGMA synchronous=" || sync)
  end
  /*
   * index_plan: Directory of table name -> Array of column lists ("object_id, revision_no").
   * Indexes are created for tables that already exist now, and for planned tables as soon as
   * the caller creates them, so a backend-neutral caller needs no SQLite-specific code.
   */
  indexPlan = options["index_plan"]
  if indexPlan == .nil then indexPlan = .directory~new
  do table over indexPlan~allIndexes
    ignored = self~ensureIndexes(table)
  end

::attribute backend get
::attribute path get
::attribute closed get
::attribute connection get

::method select private
  expose connection
  if .RexxSqlSqliteSession~current \== connection then do
    call SQLDefault connection
    .RexxSqlSqliteSession~current = connection
  end

/* Run one statement. Never raises for SQL errors: the result carries status and message. */
::method execute
  expose closed
  use strict arg statement
  if closed then raise syntax 93.900 array("Rexx/SQL session is closed")
  self~select
  rc = SQLCommand("RXQ", statement)
  res = self~collect(rc, statement, RXQ., SQLCA.)
  if res~status = "SUCCESS" then do
    parse upper value statement with verb1 verb2 rest
    if verb1 = "CREATE" & verb2 = "TABLE" then do
      parse var rest w1 w2 w3 table .
      if w1 = "IF" & w2 = "NOT" & w3 = "EXISTS" then nop
      else table = w1
      table = table~changestr("(", " ")~word(1)~lower
      ignored = self~ensureIndexes(table)
    end
  end
  return res

/* Create the planned indexes for one table (idempotent). Returns the number of indexes created or present. */
::method ensureIndexes
  expose indexPlan
  use strict arg table
  if \indexPlan~hasIndex(table) then return 0
  n = 0
  do columns over indexPlan[table]
    name = "rxidx_" || table || "_" || columns~space(0)~changestr(",", "_")
    r = self~execute("CREATE INDEX IF NOT EXISTS" name "ON" table "(" || columns || ")")
    if r~status = "SUCCESS" then n += 1
  end
  return n

/* Run one statement with '?' placemarkers: binds is an array of [datatype, value] pairs. */
::method executeBound
  expose closed
  use strict arg statement, binds
  if closed then raise syntax 93.900 array("Rexx/SQL session is closed")
  self~select
  dt. = ""; bv. = ""
  dt.0 = binds~items; bv.0 = binds~items
  do i = 1 to binds~items
    pair = binds[i]
    dt.i = pair[1]; bv.i = pair[2]
  end
  rc = SQLCommand("RXQ", statement, "dt.", "bv.")
  return self~collect(rc, statement, RXQ., SQLCA.)

/*
 * SQLCOMMAND sets RXQ.COLUMN.n and SQLCA.* in the calling activation, so the caller
 * passes both stem objects here. Tails are "COLUMN.n" and "COLUMN.0" (row count).
 */
::method collect private
  use strict arg rc, statement, q, ca
  res = .RexxSqlResult~new
  if rc \= 0 then do
    message = ca["SQLERRM"]; if message == .nil then message = ""
    if message = "" then do; message = ca["INTERRM"]; if message == .nil then message = ""; end
    res~fail(rc, message, statement)
    return res
  end
  columns = .array~new
  count = 0
  do tail over q~allIndexes
    dot = tail~lastPos(".")
    if dot = 0 then iterate
    if tail~substr(dot + 1) \== "0" then iterate
    name = tail~left(dot - 1)
    columns~append(name)
    count = q[tail]
  end
  rows = res~rows
  do n = 1 to count
    row = .RexxSqlRow~new
    do name over columns
      row~put(q[name || "." || n], name)
    end
    rows~append(row)
  end
  if columns~items > 0 then res~rowCount = count
  else do
    affected = ca["ROWCOUNT"]
    if datatype(affected, "W") then res~rowCount = affected
  end
  return res

::method close
  expose connection closed
  if closed then return self
  call SQLDisconnect connection
  if .RexxSqlSqliteSession~current == connection then .RexxSqlSqliteSession~current = ""
  closed = .true
  return self

::method uninit
  expose closed connection
  if symbol("CLOSED") = "VAR" then if \closed then call SQLDisconnect connection

::class RexxSqlResult public
::method init
  expose status message rows rowCount sqlText
  status = "SUCCESS"; message = ""; rows = .array~new; rowCount = 0; sqlText = ""
::attribute status
::attribute message
::attribute rows
::attribute rowCount
::attribute sqlText
::method accessPath
  return "SQLITE_REXXSQL"
::method fail
  expose status message sqlText
  use strict arg rc, text, statement
  status = "ERROR"
  message = "rc=" || rc text
  sqlText = statement

::class RexxSqlRow public
::method init
  expose values
  values = .directory~new
::method put
  expose values
  use strict arg value, name
  values[name~upper] = value
::method "[]"
  expose values
  use strict arg name
  return values[name~string~upper]
::method at
  forward message("[]")
::method hasIndex
  expose values
  use strict arg name
  return values~hasIndex(name~string~upper)
::method values
  expose values
  return values
::method allIndexes
  expose values
  return values~allIndexes

::requires "NativeDatabaseBackend.cls"
