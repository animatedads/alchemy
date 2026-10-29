/* Mini NotNotes indexed SQLite persistence adapter.
 * Reuses RexxSqlSqliteSession from oorexx_rexxsql_backend_v0.1; not an SQL
 * provider, not a replacement for native NoSQLServer / NotNotes authority.
 */
::class MiniNotesRexxSqlEngine public

::method init
  expose path session
  use strict arg path
  path = path~string~strip
  if path = "" then raise syntax 93.900 array("SQLite path must not be empty")
  /* Select the existing indexed native backend through the shared provider
   * contract. Legacy file mode does not construct this adapter, so it remains
   * independent of the native SQLite function package. No silent fallback. */
  selectorPackage = .context~package~loadPackage("DatabaseBackendSelector.cls")
  selectorClass = selectorPackage~findPublicClass("DatabaseBackendSelector")
  if selectorClass == .nil then -
    raise syntax 93.900 array("DatabaseBackendSelector public class unavailable")
  options = .Directory~new
  options["provider"] = "REXXSQL-SQLITE"
  options["databaseFile"] = path
  options["requiredCapabilities"] = .Array~of( -
    "KEYED_LOOKUP_INDEXED", "TRANSACTIONS", "ROLLBACK", "WAL", -
    "BIND_PLACEMARKERS", "BYTE_EXACT_TEXT")
  selected = selectorClass~new~open(options)
  if selected == .nil then -
    raise syntax 93.900 array("Shared Rexx/SQL provider returned no SQLite session")
  if \selected~hasMethod("execute") | \selected~hasMethod("executeBound") then do
    reason = "Shared Rexx/SQL provider rejected indexed SQLite session"
    if selected~hasMethod("message") then reason = reason || ":" selected~message
    raise syntax 93.900 array(reason)
  end
  session = selected

::method path
  expose path
  return path

::method session
  expose session
  return session

::method backendId
  return "rexxsql-sqlite"

::method identifier private
  use strict arg name
  name = name~string
  alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
  allowed = alphabet || "0123456789"
  if name = "" then raise syntax 93.900 array("Empty SQL identifier")
  if verify(name~left(1), alphabet) > 0 | verify(name, allowed) > 0 then -
    raise syntax 93.900 array("Unsafe SQL identifier:" name)
  return '"' || name || '"'

::method valueFragment private
  use strict arg value, binds
  if value == .nil then return "NULL"
  text = value~string
  /* Patched Rexx/SQL binds empty text as SQL NULL. An explicit SQL literal
   * preserves the legacy difference between empty string and absent value. */
  if text == "" then return "''"
  binds~append(.Array~of("TEXT", text))
  return "?"

::method run private
  expose session
  use strict arg sql, binds = .nil
  if binds == .nil then return session~execute(sql)
  if binds~items = 0 then return session~execute(sql)
  return session~executeBound(sql, binds)

::method table
  use strict arg name
  quoted = self~identifier(name)
  plain = quoted~substr(2, quoted~length - 2)
  result = self~run("SELECT name FROM sqlite_master WHERE type='table' AND name=?", -
                     .Array~of(.Array~of("TEXT", plain)))
  if result~status \= "SUCCESS" then raise syntax 93.900 array("SQLite schema query failed:" result~message)
  if result~rows~items = 0 then return .nil
  return plain

::method createTable
  use strict arg name, columns, primaryKey = .nil
  sql = "CREATE TABLE " || self~identifier(name) || " ("
  first = .true
  do column over columns
    if \first then sql = sql || ", "
    first = .false
    /* Text affinity preserves ooRexx decimal and exact civil text values. */
    sql = sql || self~identifier(column~name) || " TEXT"
    if \column~nullable then sql = sql || " NOT NULL"
  end
  if primaryKey \== .nil then do
    if primaryKey~items > 0 then do
      sql = sql || ", PRIMARY KEY ("
      do i = 1 to primaryKey~items
        if i > 1 then sql = sql || ", "
        sql = sql || self~identifier(primaryKey[i])
      end
      sql = sql || ")"
    end
  end
  return self~run(sql || ")")

::method dropTable
  use strict arg name
  return self~run("DROP TABLE " || self~identifier(name))

::method selectAll
  use strict arg name
  return self~run("SELECT * FROM " || self~identifier(name) || " ORDER BY rowid")

::method selectPage
  use strict arg name, count = 100, offset = 0
  if \datatype(count, "W") | \datatype(offset, "W") then -
    raise syntax 93.900 array("Page size and offset must be integers")
  if count < 1 | count > 100 | offset < 0 then -
    raise syntax 93.900 array("Page size must be 1..100, offset nonnegative")
  return self~run("SELECT * FROM " || self~identifier(name) || -
                  " ORDER BY rowid LIMIT " || count || " OFFSET " || offset)

::method selectPageAfter
  use strict arg name, afterRowid = 0, count = 100
  /* Keyset pagination avoids a complete table read or deep OFFSET scan. */
  if \datatype(afterRowid, "W") | \datatype(count, "W") then -
    raise syntax 93.900 array("SQLite page cursor/count must be integers")
  if afterRowid < 0 | count < 1 | count > 100 then -
    raise syntax 93.900 array("Invalid SQLite page cursor/count")
  return self~run("SELECT rowid AS NN_CURSOR, * FROM " || self~identifier(name) || -
                  " WHERE rowid > " || afterRowid || -
                  " ORDER BY rowid LIMIT " || count)

::method selectWhereEquals
  use strict arg name, column, wanted
  binds = .Array~new
  fragment = self~valueFragment(wanted, binds)
  return self~run("SELECT * FROM " || self~identifier(name) || -
                  " WHERE " || self~identifier(column) || " = " || fragment, binds)

::method insert
  use strict arg name, values
  names = ""; fragments = ""; binds = .Array~new
  do column over values~allIndexes
    if names \= "" then do
      names = names || ", "
      fragments = fragments || ", "
    end
    names = names || self~identifier(column)
    fragments = fragments || self~valueFragment(values[column], binds)
  end
  if names = "" then raise syntax 93.900 array("Cannot insert an empty row")
  return self~run("INSERT INTO " || self~identifier(name) || " (" || names || -
                  ") VALUES (" || fragments || ")", binds)

::method updateWhereEquals
  use strict arg name, column, wanted, assignments
  if assignments~items = 0 then raise syntax 93.900 array("Empty SQLite update")
  binds = .Array~new; clauses = ""
  do item over assignments~allIndexes
    if clauses \= "" then clauses = clauses || ", "
    clauses = clauses || self~identifier(item) || " = " || self~valueFragment(assignments[item], binds)
  end
  predicate = self~valueFragment(wanted, binds)
  return self~run("UPDATE " || self~identifier(name) || " SET " || clauses || -
                  " WHERE " || self~identifier(column) || " = " || predicate, binds)


::method deleteWhereEquals
  use strict arg name, column, wanted
  binds = .Array~new
  predicate = self~valueFragment(wanted, binds)
  return self~run("DELETE FROM " || self~identifier(name) || -
                  " WHERE " || self~identifier(column) || " = " || predicate, binds)

::method beginTransaction
  return self~run("BEGIN IMMEDIATE TRANSACTION")
::method commitTransaction
  return self~run("COMMIT")
::method rollbackTransaction
  return self~run("ROLLBACK")

::method close
  expose session
  return session~close
