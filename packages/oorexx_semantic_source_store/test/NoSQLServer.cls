/* Compile-only stub used to syntax-check SemanticSourceStore.cls without the full NoSQLServer package. */
::class FederatedDatabaseEngine public
::method init
  use arg root

::class NoSQLServerSQL public
::method init
  use arg engine
::method execute
  use arg statement
  return .StubDatabaseResult~new()

::class StubDatabaseResult
::attribute status
::attribute error
::attribute message
::attribute rows
::method init
  self~status = .Error~SUCCESS
  self~error = 0
  self~message = ""
  self~rows = .array~new

::class Error public
::constant SUCCESS 0
