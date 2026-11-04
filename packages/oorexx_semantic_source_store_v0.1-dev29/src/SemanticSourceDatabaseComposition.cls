/*
 * Semantic Source Control database composition boundary.
 *
 * Backend discovery/loading is owned by the registered DatabaseBackendSelector
 * framework.  This class intentionally knows nothing about provider package
 * paths or backend implementation classes.  The composition root supplies the
 * executor returned by the selected provider's open(options) operation.
 */
::class SemanticSourceDatabaseComposition public

::method init
  use strict arg executor, backendId, databaseIdentity = ""
  if executor == .nil then raise syntax 88.900 array("executor must not be .nil")
  if backendId = "" then raise syntax 88.900 array("backendId must not be empty")
  self~executor = executor
  self~backendId = backendId
  self~databaseIdentity = databaseIdentity

::attribute executor get
::attribute executor set private
::attribute backendId get
::attribute backendId set private
::attribute databaseIdentity get
::attribute databaseIdentity set private

::method newStore
  use strict arg databaseRoot = ""
  if databaseRoot = "" then databaseRoot = self~databaseIdentity
  if databaseRoot = "" then databaseRoot = self~backendId
  return .SemanticSourceStore~new(databaseRoot, self~executor, self~backendId)

::requires "SemanticSourceStore.cls"
