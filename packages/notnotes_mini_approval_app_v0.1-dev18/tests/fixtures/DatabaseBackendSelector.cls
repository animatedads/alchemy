/* Mock ONLY for test_rexxsql_adapter_mock.rex, never ship on a product
 * REXX_PATH. Verifies the application requests the actual shared provider
 * identity and required fail-closed native capabilities. */
::class DatabaseBackendSelector public
::method open
  use strict arg options
  if options["provider"] \= "REXXSQL-SQLITE" then -
    raise syntax 93.900 array("Wrong native provider selected")
  if options["databaseFile"] == .nil then -
    raise syntax 93.900 array("SQLite file path not supplied")
  required = options["requiredCapabilities"]
  if required == .nil then -
    raise syntax 93.900 array("Missing native database capability requirements")
  do capability over .Array~of( -
    "KEYED_LOOKUP_INDEXED", "TRANSACTIONS", "ROLLBACK", "WAL", -
    "BIND_PLACEMARKERS", "BYTE_EXACT_TEXT")
    found = .false
    do actual over required
      if actual == capability then found = .true
    end
    if \found then -
      raise syntax 93.900 array("Required native database capability omitted:" capability)
  end
  if options["databaseFile"] \= "/tmp/notnotes-adapter-fake.sqlite" then -
    raise syntax 93.900 array("Unexpected SQLite test path")
  return .RexxSqlSqliteSession~open(options["databaseFile"])
::requires 'RexxSqlBackend.cls'
