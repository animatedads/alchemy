/*
 * Semantic Source Control database provider: SQLite through Rexx/SQL.
 *
 * Architecture: Tom Dyer. This file: Claude (Opus 5.5), 2026-10-24.
 *
 * The Semantic Source Store is backend-neutral: its SemanticSourceDatabaseComposition
 * boundary takes an already-opened executor and knows nothing about provider packages.
 * This class is the provider-side half: given a database root, it opens a Rexx/SQL SQLite
 * executor (with the store's secondary-index plan) and hands back a ready
 * SemanticSourceDatabaseComposition. A service composition root that resolves
 * OOREXX_DATABASE_PROVIDER selects this provider by its id and calls composition().
 */

::class SemanticSourceRexxSqlProvider public
::constant PROVIDER_ID "rexxsql-sqlite"

/* Does this provider answer to the given OOREXX_DATABASE_PROVIDER value? */
::method handles class
  use strict arg providerId
  return providerId~caselessEquals(self~PROVIDER_ID)

/* The database file the store will use under a given root. */
::method databaseFile class
  use strict arg databaseRoot
  if databaseRoot = "" then raise syntax 88.900 array("databaseRoot must not be empty")
  return databaseRoot || "/ssc.sqlite"

/* Generic DatabaseBackendSelector provider contract.
 * Returns the SSC executor with the SSC index plan applied.
 */
::method open class
  use arg options = .nil
  if options == .nil then options = .directory~new
  databaseRoot = ""
  do key over .array~of("databaseRoot", "root")
    if options~hasIndex(key) then do
      valueText = options[key]
      if valueText \== .nil & valueText~string \= "" then databaseRoot = valueText~string
    end
  end
  if databaseRoot = "" then do
    envRoot = value("SSC_DATABASE_ROOT", , "ENVIRONMENT")
    if envRoot \== .nil then databaseRoot = envRoot~string
  end
  if databaseRoot = "" then
    return .SemanticSourceRexxSqlProviderError~new("SSC Rexx/SQL provider requires databaseRoot/root or SSC_DATABASE_ROOT")
  return self~openExecutor(databaseRoot)

/* Open the executor only (index plan applied). */
::method openExecutor class
  use strict arg databaseRoot
  return .SemanticSourceSqliteIndexPlan~open(self~databaseFile(databaseRoot))

/* The store's composition boundary, wired to a Rexx/SQL SQLite executor. */
::method composition class
  use strict arg databaseRoot
  executor = self~openExecutor(databaseRoot)
  return .SemanticSourceDatabaseComposition~new(executor, self~PROVIDER_ID, databaseRoot)

/* Convenience: a bootstrapped store, ready to use. (bootstrap returns verify, not the store.) */
::method newStore class
  use strict arg databaseRoot
  call SysMkDir databaseRoot
  store = self~composition(databaseRoot)~newStore
  store~bootstrap
  return store

::class SemanticSourceRexxSqlProviderError public
::attribute message
::method init
  use strict arg message
  self~message = message
::method string
  return self~message

::requires "SemanticSourceSqliteIndexPlan.cls"
::requires "SemanticSourceDatabaseComposition.cls"
