/*
 * Initialise SSC using an executor already opened by DatabaseBackendSelector.
 * This script is intentionally not a backend selector and does not load a
 * provider package.  Production composition should create SemanticSourceStore
 * from the selector-returned executor, then call bootstrap.
 */
use strict arg
say "ERROR: setup_semantic_source_db.rex no longer selects a database backend."
say "Resolve OOREXX_DATABASE_PROVIDER with DatabaseBackendSelector at the service composition root,"
say "construct SemanticSourceStore(databaseIdentity, executor, backendId), then call bootstrap."
exit 2
