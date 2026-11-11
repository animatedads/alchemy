/*
 * RexxSqlDatabaseProvider.cls - generic DatabaseBackendSelector provider
 * for the existing ooRexx Rexx/SQL SQLite backend.
 *
 * This is deliberately a thin composition adapter. It does not implement
 * SQLite, duplicate Rexx/SQL, or change NativeDatabaseBackend authority.
 *
 * open(options) returns a RexxSqlSqliteSession. Required capabilities may be
 * supplied as options["requiredCapabilities"]; any unsupported capability
 * fails closed before a session is opened.
 */
::class RexxSqlDatabaseProvider public
::constant PROVIDER_ID "REXXSQL-SQLITE"

::method open class
  use arg options = .nil
  if options == .nil then options = .directory~new

  path = self~databasePath(options)
  if path = "" then
    return .RexxSqlDatabaseProviderError~new("Rexx/SQL SQLite provider requires a database path")

  backend = .RexxSqlSqliteBackend~new
  if \backend~available then
    return .RexxSqlDatabaseProviderError~new("Rexx/SQL SQLite backend is unavailable; librexxsql.so must be built and loadable")

  required = options["requiredCapabilities"]
  if required \== .nil then do capability over required
    if \backend~supports(capability) then
      return .RexxSqlDatabaseProviderError~new("Rexx/SQL SQLite backend does not support required capability " || capability)
  end

  sqliteOptions = .directory~new
  do key over .array~of("journal_mode", "synchronous", "index_plan")
    if options~hasIndex(key) then sqliteOptions[key] = options[key]
  end
  return backend~acquire(path, sqliteOptions)

::method backend class
  return .RexxSqlSqliteBackend~new

::method databasePath class
  use arg options = .nil
  if options == .nil then options = .directory~new

  do key over .array~of("databaseFile", "database", "path")
    if options~hasIndex(key) then do
      valueText = options[key]
      if valueText \== .nil & valueText~string \= "" then return valueText~string
    end
  end

  envPath = value("OOREXX_DATABASE_PATH", , "ENVIRONMENT")
  if envPath \== .nil & envPath \= "" then return envPath~string
  envPath = value("OOREXX_REXXSQL_SQLITE_PATH", , "ENVIRONMENT")
  if envPath \== .nil & envPath \= "" then return envPath~string

  root = ""
  do key over .array~of("databaseRoot", "root")
    if options~hasIndex(key) then do
      valueText = options[key]
      if valueText \== .nil & valueText~string \= "" then root = valueText~string
    end
  end
  if root = "" then do
    envRoot = value("SSC_DATABASE_ROOT", , "ENVIRONMENT")
    if envRoot \== .nil then root = envRoot~string
  end
  if root \= "" then return root || "/app.sqlite"
  return ""

::class RexxSqlDatabaseProviderError public
::attribute message
::method init
  use strict arg message
  self~message = message
::method string
  return self~message

::requires "RexxSqlBackend.cls"
