/* PostgreSQLProcessFallbackBackend.cls - existing Database Core psql route described as a backend v0.1 */

::class PostgreSQLProcessFallbackBackend public subclass NativeDatabaseBackend
::method init
  self~init:super("POSTGRESQL","database-core-psql-process","0.1",.NativeDatabaseImplementationKind~PROCESS_BRIDGE,100)
  self~addRequirement("PSQL_CLIENT",.true,"psql executable available through DatabaseExecutableResolver")
  self~addCapability("TRANSACTIONS","SUPPORTED","TESTED","Existing Database Core PostgreSQL command compiler/process executor")
  self~addCapability("PREPARED_STATEMENTS","SUPPORTED","TESTED","Server PREPARE/EXECUTE emitted by Database Core")
  self~addCapability("TYPED_RESULTS","SUPPORTED","TESTED","Existing PostgreSQL result parser")
  self~addCapability("TABLE_DISCOVERY","SUPPORTED","TESTED","information_schema discovery")
  self~addCapability("NATIVE_LIBRARY_REQUIRED","UNSUPPORTED","DECLARED","Process fallback does not require libpq linkage")
  self~addCapability("ASYNC_QUERY","UNSUPPORTED","DECLARED","Process execution is transaction-stream oriented")
  self~addCapability("COPY_STREAMING","UNSUPPORTED","DECLARED","No streaming COPY contract in current Database Core process route")
  self~addLimitation("PROCESS_BOUNDARY","Uses an external psql process and text framing")
  self~addLimitation("NO_MID_TRANSACTION_FALLBACK","This route is selected before execution and is pinned for the transaction")
::method available
  address system "command -v psql >/dev/null 2>&1"
  return rc=0
::method commandExecutor
  return .DatabaseProcessCommandExecutor~new
::method database
  use strict arg connection
  return .Database~new(connection,.PostgreSQLEngine~new,self~commandExecutor)
::method acquire
  use strict arg connection
  if \self~available then return .nil
  return .PostgreSQLProcessFallbackSession~new(self,connection)

::class PostgreSQLProcessFallbackSession public
::method init
  expose backend connection closed
  use strict arg backend, connection
  closed=.false
::attribute backend get
::attribute connection get
::attribute closed get
::method database
  expose backend connection closed
  if closed then return .nil
  return backend~database(connection)
::method close
  expose closed
  closed=.true
  return self

::requires "NativeDatabaseBackend.cls"
::requires "database_core.cls"
