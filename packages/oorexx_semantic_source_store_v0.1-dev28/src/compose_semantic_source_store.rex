/*
 * Configuration-only Semantic Source Store composition root.
 *
 * DatabaseBackendSelector loads only the selected provider package.  SSC itself
 * never ::requires NoSQLServer, Database Core, PostgreSQL, MySQL, or another
 * provider implementation.  Backend changes are environment/config changes.
 *
 * Usage:
 *   OOREXX_DATABASE_PROVIDER=POSTGRESQL rexx compose_semantic_source_store.rex /var/lib/ssc
 *   OOREXX_DATABASE_PROVIDER=NOSQLSERVER OOREXX_NOSQL_ROOT=/var/lib/ssc rexx compose_semantic_source_store.rex /var/lib/ssc
 */
parse arg databaseRoot
if databaseRoot = "" then databaseRoot = value("SSC_DATABASE_ROOT", , "ENVIRONMENT")
if databaseRoot = "" then do
  say "ERROR: database root is required (argument or SSC_DATABASE_ROOT)."
  exit 2
end

options = .directory~new
options["databaseRoot"] = databaseRoot
options["root"] = databaseRoot

selector = .DatabaseBackendSelector~new
executor = selector~open(options)
if executor~isA(.DatabaseBackendSelectionError) then do
  say "ERROR:" executor~message
  exit 2
end

composition = .SemanticSourceDatabaseComposition~new(executor, selector~selectedProvider, databaseRoot)
store = composition~newStore
verify = store~bootstrap
say "Semantic Source Store ready: provider=" || selector~selectedProvider || " root=" || databaseRoot
exit 0

::requires "DatabaseBackendSelector.cls"
::requires "SemanticSourceDatabaseComposition.cls"
