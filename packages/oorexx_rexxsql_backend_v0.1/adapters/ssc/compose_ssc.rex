/*
 * Service composition root for the Semantic Source Store (Rexx/SQL provider).
 * Architecture: Tom Dyer. This script: Claude (Opus 5.5), 2026-10-24.
 *
 * Resolves OOREXX_DATABASE_PROVIDER to a provider, opens the executor, and prints the
 * backend the store is bootstrapped on. This is the piece setup_semantic_source_db.rex
 * says belongs at the composition root: it loads the provider package, the store does not.
 *
 *   OOREXX_DATABASE_PROVIDER=rexxsql-sqlite  rexx compose_ssc.rex <database-root>
 *
 * Through the shared DatabaseBackendSelector, preserve this SSC-specific provider:
 *   OOREXX_DATABASE_PROVIDER=REXXSQL-SQLITE
 *   OOREXX_DATABASE_PROVIDER_PACKAGE=SemanticSourceRexxSqlProvider.cls
 *   OOREXX_DATABASE_PROVIDER_CLASS=SemanticSourceRexxSqlProvider
 *
 * A real deployment registers several providers and selects among them; this root knows
 * the Rexx/SQL SQLite provider and defers anything else to its own composition root.
 */
parse arg databaseRoot
if databaseRoot = "" then databaseRoot = value("SSC_DATABASE_ROOT", , "ENVIRONMENT")
if databaseRoot = "" then do; say "usage: rexx compose_ssc.rex <database-root>"; exit 2; end
providerId = value("OOREXX_DATABASE_PROVIDER", , "ENVIRONMENT")
if providerId = "" then providerId = .SemanticSourceRexxSqlProvider~PROVIDER_ID

if \.SemanticSourceRexxSqlProvider~handles(providerId) then do
  say "ERROR: provider '" || providerId || "' is not the Rexx/SQL SQLite provider."
  say "Resolve OOREXX_DATABASE_PROVIDER with DatabaseBackendSelector at the service"
  say "composition root, or set it to '" || .SemanticSourceRexxSqlProvider~PROVIDER_ID || "'."
  exit 2
end

store = .SemanticSourceRexxSqlProvider~newStore(databaseRoot)
say "Semantic Source Store ready: provider=" || providerId || " backend=" || store~backendId || " root=" || databaseRoot
exit 0

::requires "SemanticSourceRexxSqlProvider.cls"
