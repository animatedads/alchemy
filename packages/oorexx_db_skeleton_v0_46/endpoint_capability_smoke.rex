engine = .MySQLEngine~new
endpoint = .DatabaseEndpointCapabilities~new(engine~capabilities)

call assert endpoint~supports(.DatabaseCapability~GENERATEDKEYS), "inherits generated keys"
call assert endpoint~supports(.DatabaseCapability~TRANSACTIONTIMEOUT), "inherits timeout"

ignore = endpoint~disable(.DatabaseCapability~GENERATEDKEYS)
ignore = endpoint~disable(.DatabaseCapability~TRANSACTIONTIMEOUT)

call assert (\endpoint~supports(.DatabaseCapability~GENERATEDKEYS)), "generated keys masked"
call assert (\endpoint~supports(.DatabaseCapability~TRANSACTIONTIMEOUT)), "timeout masked"
call assert endpoint~supports(.DatabaseCapability~TRANSACTIONS), "transactions retained"

conn = .DatabaseConnection~new("127.0.0.1", 3333, "nosqlserver", "", .nil, "mysql")
db = .Database~new(conn, engine, .DatabaseNopCommandExecutor~new, .DatabaseExecutableResolver~new, endpoint)

call assert (\db~supports(.DatabaseCapability~GENERATEDKEYS)), "database endpoint mask"
call assert db~supports(.DatabaseCapability~TRANSACTIONS), "database transactions"

say "DATABASE ENDPOINT CAPABILITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
