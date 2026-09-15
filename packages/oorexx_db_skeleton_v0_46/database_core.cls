/* ooRexx database virtualization skeleton v0.1
 * Structure-first package. Operational methods are deliberately NOP-like.
 */

::class Error public
::constant SUCCESS          "SUCCESS"
::constant NOTEXECUTED      "NOTEXECUTED"
::constant FAILED           "FAILED"
::constant UNKNOWN          "UNKNOWN"

::constant COMMITTED        "COMMITTED"
::constant ROLLEDBACK       "ROLLEDBACK"

::constant INVALIDSTATE     "INVALIDSTATE"
::constant INVALIDARGUMENT  "INVALIDARGUMENT"
::constant INVALIDCONNECTION "INVALIDCONNECTION"
::constant UNSUPPORTED      "UNSUPPORTED"

::constant COMMANDFAILED    "COMMANDFAILED"
::constant COMMANDNOTFOUND  "COMMANDNOTFOUND"
::constant TIMEOUT          "TIMEOUT"

::constant DATABASEERROR        "DATABASEERROR"
::constant CONNECTIONFAILED     "CONNECTIONFAILED"
::constant AUTHENTICATIONFAILED "AUTHENTICATIONFAILED"
::constant TRANSACTIONFAILED    "TRANSACTIONFAILED"
::constant STATEMENTFAILED      "STATEMENTFAILED"
::constant PREPAREFAILED        "PREPAREFAILED"
::constant INVALIDPLAN          "INVALIDPLAN"
::constant PARAMETERCOUNT       "PARAMETERCOUNT"
::constant DUPLICATEPREPARED    "DUPLICATEPREPARED"
::constant INVALIDSAVEPOINT     "INVALIDSAVEPOINT"
::constant INVALIDOPERATION     "INVALIDOPERATION"
::constant SOURCECONFORMANCE    "SOURCECONFORMANCE"
::constant CREDENTIALERROR       "CREDENTIALERROR"
::constant EXECUTABLENOTFOUND    "EXECUTABLENOTFOUND"
::constant EXECUTIONFAILED        "EXECUTIONFAILED"
::constant DATABASEUNAVAILABLE     "DATABASEUNAVAILABLE"
::constant PERMISSIONDENIED        "PERMISSIONDENIED"
::constant SYNTAXERROR              "SYNTAXERROR"
::constant CONSTRAINTVIOLATION      "CONSTRAINTVIOLATION"
::constant DUPLICATEKEY             "DUPLICATEKEY"
::constant DATABASENOTFOUND         "DATABASENOTFOUND"
::constant INVALIDENVIRONMENT       "INVALIDENVIRONMENT"
::constant INVALIDPARAMETER         "INVALIDPARAMETER"
::constant TEMPFILEFAILED           "TEMPFILEFAILED"
::constant INPUTFAILED            "INPUTFAILED"
::constant DEADLOCK               "DEADLOCK"
::constant SERIALIZATIONFAILURE   "SERIALIZATIONFAILURE"
::constant LOCKTIMEOUT            "LOCKTIMEOUT"

::class DatabaseOperationType public
::constant OPERATION              "OPERATION"
::constant STATEMENT              "STATEMENT"
::constant EXECUTE                "EXECUTE"
::constant QUERY                  "QUERY"
::constant PREPAREDSTATEMENT      "PREPAREDSTATEMENT"
::constant PREPAREDEXECUTION      "PREPAREDEXECUTION"
::constant PREPAREDBATCH          "PREPAREDBATCH"
::constant SAVEPOINT              "SAVEPOINT"
::constant ROLLBACKTOSAVEPOINT    "ROLLBACKTOSAVEPOINT"

::constant BEGIN                  "BEGIN"
::constant COMMIT                 "COMMIT"
::constant ROLLBACK               "ROLLBACK"

::constant CREATE                 "CREATE"
::constant DROP                   "DROP"
::constant BACKUP                 "BACKUP"
::constant RESTORE                "RESTORE"
::constant EXPORT                 "EXPORT"
::constant IMPORT                 "IMPORT"
::constant INSPECT                "INSPECT"
::constant MAINTENANCE            "MAINTENANCE"
::constant REPLICATION            "REPLICATION"

::constant INSERT                 "INSERT"
::constant UPDATE                 "UPDATE"
::constant DELETE                 "DELETE"

::class DatabaseSourceKind public
::constant DATABASE "DATABASE"
::constant TABLE    "TABLE"

::class DatabaseConnection public
::method init
  expose host port databaseName userName credential engineName
  use arg host = "localhost", port = 0, databaseName = "", userName = "", credential = .nil, engineName = ""
::attribute host
::attribute port
::attribute databaseName
::attribute userName
::attribute credential
::attribute status
::attribute error
::attribute engineName

::class DatabaseCredential public
::method init
  expose kind value sensitive
  use arg kind = "none", value = .nil
  sensitive = .true
::attribute kind
::attribute value
::attribute sensitive
::method applyToEnvironment
  expose kind value
  use arg engineName, environment
  if kind = "none" then return .Error~SUCCESS
  if kind = "environment" then do
    if value = "" then return .Error~CREDENTIALERROR
    return .Error~SUCCESS
  end
  if kind = "password" then do
    if engineName = "postgresql" then environment["PGPASSWORD"] = value
    else if engineName = "mysql" then environment["MYSQL_PWD"] = value
    else return .Error~UNSUPPORTED
    return .Error~SUCCESS
  end
  return .Error~UNSUPPORTED
::method masked
  expose sensitive value
  if sensitive then return "***"
  return value

::class DatabaseConformanceResult public
::method init
  expose backendName passed failed skipped details
  use arg backendName = ""
  passed = 0
  failed = 0
  skipped = 0
  details = .array~new
::attribute backendName get
::attribute passed get
::attribute failed get
::attribute skipped get
::attribute details get
::method pass
  expose passed details
  use arg name
  passed += 1
  details~append("PASS " || name)
  return self
::method fail
  expose failed details
  use arg name, reason = ""
  failed += 1
  details~append("FAIL " || name || " " || reason)
  return self
::method skip
  expose skipped details
  use arg name, reason = ""
  skipped += 1
  details~append("SKIP " || name || " " || reason)
  return self
::method success
  expose failed
  return failed = 0

::class DatabaseConformanceProvider public
::method name abstract
::method supports abstract
::method reset abstract
::method database abstract
::method readFixtureValue abstract
::method fixtureRowCount
  return .nil

::class DatabaseBackendConformanceSuite public
::method run
  use arg provider
  suiteResult = .DatabaseConformanceResult~new(provider~name)
  self~runScenario(suiteResult, provider, "transaction_commit")
  self~runScenario(suiteResult, provider, "rollback_before_commit")
  self~runScenario(suiteResult, provider, "prepared_statement")
  self~runScenario(suiteResult, provider, "prepared_batch")
  self~runScenario(suiteResult, provider, "deferred_query")
  self~runScenario(suiteResult, provider, "mutation_results")
  self~runScenario(suiteResult, provider, "generated_keys")
  self~runScenario(suiteResult, provider, "transaction_retry")
  return suiteResult

::method runScenario private
  use arg suiteResult, provider, scenario
  select
    when scenario = "transaction_commit" then self~scenarioTransactionCommit(suiteResult, provider)
    when scenario = "rollback_before_commit" then self~scenarioRollbackBeforeCommit(suiteResult, provider)
    when scenario = "prepared_statement" then self~scenarioPreparedStatement(suiteResult, provider)
    when scenario = "prepared_batch" then self~scenarioPreparedBatch(suiteResult, provider)
    when scenario = "deferred_query" then self~scenarioDeferredQuery(suiteResult, provider)
    when scenario = "mutation_results" then self~scenarioMutationResults(suiteResult, provider)
    when scenario = "generated_keys" then self~scenarioGeneratedKeys(suiteResult, provider)
    when scenario = "transaction_retry" then self~scenarioTransactionRetry(suiteResult, provider)
    otherwise suiteResult~fail(scenario, "unknown scenario")
  end

::method scenarioTransactionCommit private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~TRANSACTIONS) then do
    suiteResult~skip("transaction_commit", "capability")
    return
  end
  ignore = provider~reset("transaction_commit")
  db = provider~database
  tx = db~transaction
  ignore = tx~execute("UPDATE conformance SET value = 2 WHERE id = 1")
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("transaction_commit", txResult~error)
    return
  end
  if provider~readFixtureValue \= "2" then do
    suiteResult~fail("transaction_commit", "committed value not visible")
    return
  end
  suiteResult~pass("transaction_commit")

::method scenarioRollbackBeforeCommit private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~TRANSACTIONS) then do
    suiteResult~skip("rollback_before_commit", "capability")
    return
  end
  ignore = provider~reset("rollback_before_commit")
  db = provider~database
  tx = db~transaction
  ignore = tx~execute("UPDATE conformance SET value = 3 WHERE id = 1")
  txResult = tx~rollback
  if txResult~status \= .Error~NOTEXECUTED then do
    suiteResult~fail("rollback_before_commit", txResult~status)
    return
  end
  if provider~readFixtureValue \= "1" then do
    suiteResult~fail("rollback_before_commit", "rollback changed fixture")
    return
  end
  suiteResult~pass("rollback_before_commit")

::method scenarioPreparedStatement private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~PREPAREDSTATEMENTS) then do
    suiteResult~skip("prepared_statement", "capability")
    return
  end
  ignore = provider~reset("prepared_statement")
  db = provider~database
  tx = db~transaction
  ps = tx~prepareStatement("u", "UPDATE conformance SET value = ? WHERE id = ?")
  params = .DatabaseParameterSet~new
  ignore = params~add(.DatabaseParameter~new("5", "integer"))
  ignore = params~add(.DatabaseParameter~new("1", "integer"))
  ignore = tx~executePrepared(ps, params)
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("prepared_statement", txResult~error)
    return
  end
  if provider~readFixtureValue \= "5" then do
    suiteResult~fail("prepared_statement", "prepared mutation not visible")
    return
  end
  suiteResult~pass("prepared_statement")

::method scenarioPreparedBatch private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~PREPAREDBATCH) then do
    suiteResult~skip("prepared_batch", "capability")
    return
  end
  ignore = provider~reset("prepared_batch")
  db = provider~database
  tx = db~transaction
  ps = tx~prepareStatement("b", "UPDATE conformance SET value = ? WHERE id = ?")
  batch = .DatabasePreparedBatch~new(ps)

  p1 = .DatabaseParameterSet~new
  ignore = p1~add(.DatabaseParameter~new("6", "integer"))
  ignore = p1~add(.DatabaseParameter~new("1", "integer"))
  ignore = batch~add(.DatabasePreparedExecution~new(ps, p1))

  p2 = .DatabaseParameterSet~new
  ignore = p2~add(.DatabaseParameter~new("7", "integer"))
  ignore = p2~add(.DatabaseParameter~new("1", "integer"))
  ignore = batch~add(.DatabasePreparedExecution~new(ps, p2))

  ignore = tx~operations~append(batch)
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("prepared_batch", txResult~error)
    return
  end
  if provider~readFixtureValue \= "7" then do
    suiteResult~fail("prepared_batch", "batch final value incorrect")
    return
  end
  suiteResult~pass("prepared_batch")

::method scenarioDeferredQuery private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~TYPEDRESULTS) then do
    suiteResult~skip("deferred_query", "capability")
    return
  end
  ignore = provider~reset("deferred_query")
  db = provider~database
  tx = db~transaction
  ref = tx~query("SELECT id, value FROM conformance WHERE id = 1")
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("deferred_query", txResult~error)
    return
  end
  if \ref~resolved then do
    suiteResult~fail("deferred_query", "unresolved")
    return
  end
  if ref~result~rowCount \= 1 then do
    suiteResult~fail("deferred_query", "wrong row count")
    return
  end
  if ref~result~rows[1]~rawAt("value") \= "1" then do
    suiteResult~fail("deferred_query", "wrong query value")
    return
  end
  suiteResult~pass("deferred_query")

::method scenarioMutationResults private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~MUTATIONRESULTS) then do
    suiteResult~skip("mutation_results", "capability")
    return
  end
  ignore = provider~reset("mutation_results")
  db = provider~database
  tx = db~transaction
  ignore = tx~execute("UPDATE conformance SET value = 8 WHERE id = 1")
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("mutation_results", txResult~error)
    return
  end
  if txResult~mutationResults~items < 1 then do
    suiteResult~fail("mutation_results", "missing mutation result")
    return
  end
  if txResult~mutationResults[1]~affectedRows \= 1 then do
    suiteResult~fail("mutation_results", "wrong affected row count")
    return
  end
  if provider~readFixtureValue \= "8" then do
    suiteResult~fail("mutation_results", "mutation not visible")
    return
  end
  suiteResult~pass("mutation_results")

::method scenarioGeneratedKeys private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~GENERATEDKEYS) then do
    suiteResult~skip("generated_keys", "capability")
    return
  end
  ignore = provider~reset("generated_keys")
  db = provider~database
  tx = db~transaction
  ignore = tx~insertReturningKey("INSERT INTO conformance(value) VALUES (9)", "id")
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("generated_keys", txResult~error)
    return
  end
  if txResult~mutationResults~items < 1 then do
    suiteResult~fail("generated_keys", "missing mutation result")
    return
  end
  if txResult~mutationResults[1]~generatedKey == .nil then do
    suiteResult~fail("generated_keys", "missing generated key")
    return
  end
  rowCount = provider~fixtureRowCount
  if rowCount \== .nil then do
    if rowCount \= 2 then do
      suiteResult~fail("generated_keys", "insert not visible")
      return
    end
  end
  suiteResult~pass("generated_keys")

::method scenarioTransactionRetry private
  use arg suiteResult, provider
  if \provider~supports(.DatabaseCapability~TRANSACTIONRETRY) then do
    suiteResult~skip("transaction_retry", "capability")
    return
  end
  ignore = provider~reset("transaction_retry")
  db = provider~database
  tx = db~transaction
  retryStatus = tx~setRetryAttempts(2)
  if retryStatus \= .Error~SUCCESS then do
    suiteResult~fail("transaction_retry", retryStatus)
    return
  end
  ignore = tx~execute("UPDATE conformance SET value = 10 WHERE id = 1")
  txResult = tx~commit
  if txResult~status \= .Error~SUCCESS then do
    suiteResult~fail("transaction_retry", txResult~error)
    return
  end
  if txResult~attemptCount < 2 then do
    suiteResult~fail("transaction_retry", "retry was not exercised")
    return
  end
  if provider~readFixtureValue \= "10" then do
    suiteResult~fail("transaction_retry", "retried transaction not visible")
    return
  end
  suiteResult~pass("transaction_retry")

::class DatabaseBackendContract public
::method name abstract
::method capabilities abstract
::method compile abstract
::method parser abstract
::method supports
  use arg capability
  return self~capabilities~supports(capability)

::class DatabaseEngine public subclass DatabaseBackendContract
::method init
  expose name
  use arg name = "generic"
::attribute name
::method capabilities
  caps = .DatabaseCapabilities~new
  caps~add(.DatabaseCapability~TRANSACTIONS)
  caps~add(.DatabaseCapability~SAVEPOINTS)
  caps~add(.DatabaseCapability~PREPAREDSTATEMENTS)
  caps~add(.DatabaseCapability~PREPAREDBATCH)
  caps~add(.DatabaseCapability~TYPEDRESULTS)
  caps~add(.DatabaseCapability~RESULTMETADATA)
  caps~add(.DatabaseCapability~RESULTSCHEMA)
  caps~add(.DatabaseCapability~MUTATIONRESULTS)
  caps~add(.DatabaseCapability~PREPAREDMUTATIONRESULTS)
  caps~add(.DatabaseCapability~TRANSACTIONRETRY)
  caps~add(.DatabaseCapability~TRANSACTIONREADONLY)
  caps~add(.DatabaseCapability~TRANSACTIONISOLATION)
  caps~add(.DatabaseCapability~TRANSACTIONTIMEOUT)
  return caps
::method createTransactionPlan
  use arg transaction
  return .DatabaseTransactionPlan~new(transaction, self)
::method compile
  use arg plan
  validation = plan~validate
  if validation~status \= .Error~SUCCESS then return self~invalidCommand(validation)
  return .DatabaseCommand~new(self~name, "NOP", .array~new, self~compileTransactionSql(plan))
::method invalidCommand
  use arg validation
  command = .DatabaseCommand~new(self~name, "NOP", .array~new, "")
  command~status = .Error~NOTEXECUTED
  command~error = validation~error
  return command
::method finalizeCommand
  use arg plan, command
  database = plan~transaction~database
  executable = database~executableResolver~resolve(self~name)
  if executable = "" then do
    command~status = .Error~NOTEXECUTED
    command~error = .Error~EXECUTABLENOTFOUND
    return command
  end
  command~executable = executable
  command~timeout = plan~transaction~timeout
  credential = database~connection~credential
  if credential \== .nil then do
    credentialStatus = credential~applyToEnvironment(self~name, command~environment~values)
    if credentialStatus \= .Error~SUCCESS then do
      command~status = .Error~NOTEXECUTED
      command~error = credentialStatus
    end
  end
  return command
::method compileTransactionSql
  use arg plan
  sql = self~compileTransactionBegin(plan) || .endOfLine
  frameNumber = 0
  do operation over plan~operations
    fragment = self~compileOperationSql(operation)
    if fragment = "" then iterate
    if self~operationReturnsResult(operation) then do
      frameNumber += 1
      beginMarker = "__OOREXX_RESULT_BEGIN_" || frameNumber || "__"
      endMarker = "__OOREXX_RESULT_END_" || frameNumber || "__"
      sql ||= "SELECT " || self~quoteSqlLiteral(beginMarker) || " AS __oorexx_frame;" || .endOfLine
      sql ||= fragment || .endOfLine
      sql ||= "SELECT " || self~quoteSqlLiteral(endMarker) || " AS __oorexx_frame;" || .endOfLine
    end
    else sql ||= fragment || .endOfLine
  end
  sql ||= "COMMIT;" || .endOfLine
  return sql
::method compileTransactionBegin
  use arg plan
  return "BEGIN;"
::method operationReturnsResult
  use arg operation
  if operation~operationType = .DatabaseOperationType~STATEMENT then return operation~expectedResult
  if operation~operationType = .DatabaseOperationType~PREPAREDEXECUTION then return operation~expectedResult
  return .false
::method operationIsMutation
  use arg operation
  sqlText = ""
  if operation~operationType = .DatabaseOperationType~STATEMENT then sqlText = operation~sql~strip~upper
  else if operation~operationType = .DatabaseOperationType~PREPAREDEXECUTION then sqlText = operation~statement~sql~strip~upper
  else if operation~operationType = .DatabaseOperationType~PREPAREDBATCH then sqlText = operation~statement~sql~strip~upper
  else return .false
  if sqlText~pos("INSERT ") = 1 then return .true
  if sqlText~pos("UPDATE ") = 1 then return .true
  if sqlText~pos("DELETE ") = 1 then return .true
  return .false
::method operationMutationKind
  use arg operation
  sqlText = ""
  if operation~operationType = .DatabaseOperationType~STATEMENT then sqlText = operation~sql~strip~upper
  else if operation~operationType = .DatabaseOperationType~PREPAREDEXECUTION then sqlText = operation~statement~sql~strip~upper
  else if operation~operationType = .DatabaseOperationType~PREPAREDBATCH then sqlText = operation~statement~sql~strip~upper
  else return ""
  if sqlText~pos("INSERT ") = 1 then return "INSERT"
  if sqlText~pos("UPDATE ") = 1 then return "UPDATE"
  if sqlText~pos("DELETE ") = 1 then return "DELETE"
  return ""
::method compileOperationSql
  use arg operation
  select
    when operation~operationType = .DatabaseOperationType~STATEMENT then return operation~sql || ";"
    when operation~operationType = .DatabaseOperationType~PREPAREDSTATEMENT then return self~compilePreparedStatementSql(operation)
    when operation~operationType = .DatabaseOperationType~PREPAREDEXECUTION then return self~compilePreparedExecutionSql(operation)
    when operation~operationType = .DatabaseOperationType~PREPAREDBATCH then return self~compilePreparedBatchSql(operation)
    when operation~operationType = .DatabaseOperationType~SAVEPOINT then return "SAVEPOINT " || operation~name || ";"
    when operation~operationType = .DatabaseOperationType~ROLLBACKTOSAVEPOINT then return "ROLLBACK TO SAVEPOINT " || operation~tag || ";"
    otherwise return ""
  end
::method compilePreparedStatementSql
  use arg statement
  return ""
::method compilePreparedExecutionSql
  use arg execution
  return ""
::method compilePreparedBatchSql
  use arg batch
  sql = ""
  do execution over batch~executions
    fragment = self~compilePreparedExecutionSql(execution)
    if fragment <> "" then sql ||= fragment || .endOfLine
  end
  return sql~strip("T")
::method renderParameter
  use arg parameter
  if parameter~isNull then return "NULL"
  value = parameter~value
  typeName = parameter~typeName~lower
  if typeName = "integer" then do
    if \value~datatype("W") then return .nil
    return value
  end
  if typeName = "decimal" then do
    if \value~datatype("N") then return .nil
    return value
  end
  if typeName = "numeric" then do
    if \value~datatype("N") then return .nil
    return value
  end
  if typeName = "boolean" then do
    if value = .true then return "TRUE"
    if value = .false then return "FALSE"
    return .nil
  end
  return self~quoteSqlLiteral(value)
::method quoteSqlLiteral
  use arg value
  text = value~string
  text = text~changeStr("'", "''")
  return "'" || text || "'"
::method validSqlIdentifier
  use arg name
  if name = "" then return .false
  first = name~substr(1, 1)
  if \first~datatype("A") then do
    if first \= "_" then return .false
  end
  do i = 2 to name~length
    ch = name~substr(i, 1)
    if \ch~datatype("A") then do
      if \ch~datatype("N") then do
        if ch \= "_" then return .false
      end
    end
  end
  return .true
::method quoteIdentifier
  use arg name
  if \self~validSqlIdentifier(name) then return ""
  return name
::method parser
  return .DatabaseResultParser~new(self~name)
::method endpointIdentityQuery
  return ""
::method parseEndpointIdentity
  use arg queryResult
  return .DatabaseEndpointIdentity~new(self~name, self~name, "", "")
::method tableDiscoveryQuery
  return ""
::method parseTableDiscoveryRows
  use arg queryResult
  return .array~new
::method metadataQueryForRelation
  use arg schemaName, tableName
  return self~metadataQueryForTable(tableName)
::method quoteRelationIdentifier
  use arg name
  escapedName = name~changestr('"', '""')
  return '"' || escapedName || '"'
::method qualifiedRelationName
  use arg schemaName, tableName
  if schemaName = "" then return self~quoteRelationIdentifier(tableName)
  return self~quoteRelationIdentifier(schemaName) || "." || self~quoteRelationIdentifier(tableName)
::method metadataQueryForTable
  use arg tableName
  return ""
::method parseMetadataRows
  use arg queryResult
  return .DatabaseResultMetadata~new

::class PostgreSQLEngine public subclass DatabaseEngine
::method capabilities
  caps = self~capabilities:super
  caps~add(.DatabaseCapability~GENERATEDKEYS)
  caps~add(.DatabaseCapability~TABLEDISCOVERY)
  return caps
::method init
  self~init:super("postgresql")
::method parser
  return .PostgreSQLResultParser~new
::method endpointIdentityQuery
  return "SELECT version() AS __oorexx_server_version"
::method parseEndpointIdentity
  use arg queryResult
  rawVersion = ""
  if queryResult~rows~items > 0 then rawVersion = queryResult~rows[1]~rawAt("__oorexx_server_version")
  product = "postgresql"
  version = rawVersion
  return .DatabaseEndpointIdentity~new("postgresql", product, version, rawVersion)
::method tableDiscoveryQuery
  return "SELECT table_schema, table_name, table_type FROM information_schema.tables " || -
         "WHERE table_schema NOT IN ('pg_catalog', 'information_schema') " || -
         "ORDER BY table_schema, table_name"
::method parseTableDiscoveryRows
  use arg queryResult
  descriptors = .array~new
  do row over queryResult~rows
    descriptors~append(.DatabaseRelationDescriptor~new( -
      row~rawAt("table_schema"), row~rawAt("table_name"), row~rawAt("table_type")))
  end
  return descriptors
::method metadataQueryForRelation
  use arg schemaName, tableName
  schemaPredicate = "table_schema = current_schema()"
  if schemaName <> "" then schemaPredicate = "table_schema = " || self~quoteSqlLiteral(schemaName)
  return "SELECT column_name, CASE WHEN data_type = 'USER-DEFINED' THEN udt_name ELSE data_type END AS data_type, " || -
         "is_nullable, ordinal_position FROM information_schema.columns WHERE " || schemaPredicate || " " || -
         "AND table_name = " || self~quoteSqlLiteral(tableName) || " ORDER BY ordinal_position"
::method metadataQueryForTable
  use arg tableName
  return self~metadataQueryForRelation("", tableName)
::method parseMetadataRows
  use arg queryResult
  metadata = .DatabaseResultMetadata~new
  do row over queryResult~rows
    engineType = row~rawAt("data_type")
    nullableText = row~rawAt("is_nullable")
    ordinalText = row~rawAt("ordinal_position")
    nullable = .false
    if nullableText = "YES" then nullable = .true
    column = .DatabaseColumnMetadata~new(row~rawAt("column_name"), engineType, -
      .DatabaseType~fromPostgreSQL(engineType), nullable, ordinalText)
    metadata~add(column)
  end
  return metadata
::method compile
  use arg plan
  validation = plan~validate
  if validation~status \= .Error~SUCCESS then return self~invalidCommand(validation)
  connection = plan~transaction~database~connection
  args = .array~new
  args~append("-X")
  args~append("--no-psqlrc")
  args~append("-v")
  args~append("ON_ERROR_STOP=1")
  args~append("-A")
  args~append("-F")
  args~append("09"x)
  if connection~host <> "" then do
    args~append("-h")
    args~append(connection~host)
  end
  if connection~port > 0 then do
    args~append("-p")
    args~append(connection~port)
  end
  if connection~userName <> "" then do
    args~append("-U")
    args~append(connection~userName)
  end
  if connection~databaseName <> "" then args~append(connection~databaseName)
  return self~finalizeCommand(plan, .DatabaseCommand~new(self~name, "psql", args, self~compileTransactionSql(plan)))
::method compileOperationSql
  use arg operation
  if operation~operationType = .DatabaseOperationType~STATEMENT then do
    if operation~generatedKeyRequest \== .nil then do
      sqlText = operation~sql~strip("T")
      if sqlText~right(1) = ";" then sqlText = sqlText~left(sqlText~length - 1)
      keyColumn = self~quoteIdentifier(operation~generatedKeyRequest~columnName)
      return sqlText || " RETURNING " || keyColumn || " AS __oorexx_generated_key;"
    end
  end
  return self~compileOperationSql:super(operation)
::method compileTransactionBegin
  use arg plan
  tx = plan~transaction
  clauses = ""
  select
    when tx~isolationLevel = .DatabaseIsolation~DEFAULT then nop
    when tx~isolationLevel = .DatabaseIsolation~READUNCOMMITTED then clauses ||= " ISOLATION LEVEL READ UNCOMMITTED"
    when tx~isolationLevel = .DatabaseIsolation~READCOMMITTED then clauses ||= " ISOLATION LEVEL READ COMMITTED"
    when tx~isolationLevel = .DatabaseIsolation~REPEATABLEREAD then clauses ||= " ISOLATION LEVEL REPEATABLE READ"
    when tx~isolationLevel = .DatabaseIsolation~SERIALIZABLE then clauses ||= " ISOLATION LEVEL SERIALIZABLE"
    otherwise nop
  end
  select
    when tx~accessMode = .DatabaseAccessMode~READONLY then clauses ||= " READ ONLY"
    when tx~accessMode = .DatabaseAccessMode~READWRITE then clauses ||= " READ WRITE"
    otherwise nop
  end
  return "BEGIN" || clauses || ";"
::method compilePreparedStatementSql
  use arg statement
  sql = statement~sql
  paramCount = sql~countStr("?")
  pgSql = ""
  start = 1
  do i = 1 to paramCount
    qpos = sql~pos("?", start)
    pgSql ||= sql~substr(start, qpos - start) || "$" || i
    start = qpos + 1
  end
  pgSql ||= sql~substr(start)
  return "PREPARE " || statement~name || " AS " || pgSql || ";"
::method compilePreparedExecutionSql
  use arg execution
  values = ""
  do i = 1 to execution~parameters~count
    if i > 1 then values ||= ", "
    values ||= self~renderParameter(execution~parameters~at(i))
  end
  return "EXECUTE " || execution~statement~name || "(" || values || ");"

::class MySQLEngine public subclass DatabaseEngine
::method capabilities
  caps = self~capabilities:super
  caps~add(.DatabaseCapability~GENERATEDKEYS)
  caps~add(.DatabaseCapability~TABLEDISCOVERY)
  return caps
::method init
  self~init:super("mysql")
::method parser
  return .MySQLResultParser~new
::method endpointIdentityQuery
  return "SELECT VERSION() AS __oorexx_server_version"
::method parseEndpointIdentity
  use arg queryResult
  rawVersion = ""
  if queryResult~rows~items > 0 then rawVersion = queryResult~rows[1]~rawAt("__oorexx_server_version")
  lowerVersion = rawVersion~lower
  product = "mysql-compatible"
  if lowerVersion~pos("mariadb") > 0 then product = "mariadb"
  else if lowerVersion~pos("nosqlserver") > 0 then product = "nosqlserver"
  else if lowerVersion~pos("mysql") > 0 then product = "mysql"
  return .DatabaseEndpointIdentity~new("mysql", product, rawVersion, rawVersion)
::method tableDiscoveryQuery
  return "SELECT TABLE_SCHEMA AS table_schema, TABLE_NAME AS table_name, " || -
         "TABLE_TYPE AS table_type FROM information_schema.tables " || -
         "WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME"
::method parseTableDiscoveryRows
  use arg queryResult
  descriptors = .array~new
  do row over queryResult~rows
    descriptors~append(.DatabaseRelationDescriptor~new( -
      row~rawAt("table_schema"), row~rawAt("table_name"), row~rawAt("table_type")))
  end
  return descriptors
::method quoteRelationIdentifier
  use arg name
  escapedName = name~changestr("`", "``")
  return "`" || escapedName || "`"
::method metadataQueryForRelation
  use arg schemaName, tableName
  schemaPredicate = "table_schema = DATABASE()"
  if schemaName <> "" then schemaPredicate = "table_schema = " || self~quoteSqlLiteral(schemaName)
  return "SELECT COLUMN_NAME AS column_name, COLUMN_TYPE AS data_type, " || -
         "IS_NULLABLE AS is_nullable, ORDINAL_POSITION AS ordinal_position " || -
         "FROM information_schema.columns WHERE " || schemaPredicate || " " || -
         "AND table_name = " || self~quoteSqlLiteral(tableName) || " ORDER BY ordinal_position"
::method metadataQueryForTable
  use arg tableName
  return self~metadataQueryForRelation("", tableName)
::method parseMetadataRows
  use arg queryResult
  metadata = .DatabaseResultMetadata~new
  do row over queryResult~rows
    engineType = row~rawAt("data_type")
    nullableText = row~rawAt("is_nullable")
    ordinalText = row~rawAt("ordinal_position")
    nullable = .false
    if nullableText = "YES" then nullable = .true
    column = .DatabaseColumnMetadata~new(row~rawAt("column_name"), engineType, -
      .DatabaseType~fromMySQL(engineType), nullable, ordinalText)
    metadata~add(column)
  end
  return metadata
::method compile
  use arg plan
  validation = plan~validate
  if validation~status \= .Error~SUCCESS then return self~invalidCommand(validation)
  connection = plan~transaction~database~connection
  args = .array~new
  args~append("--batch")
  args~append("--raw")
  if connection~host <> "" then do
    args~append("--host")
    args~append(connection~host)
  end
  if connection~port > 0 then do
    args~append("--port")
    args~append(connection~port)
  end
  if connection~userName <> "" then do
    args~append("--user")
    args~append(connection~userName)
  end
  if connection~databaseName <> "" then args~append(connection~databaseName)
  return self~finalizeCommand(plan, .DatabaseCommand~new(self~name, "mysql", args, self~compileTransactionSql(plan)))
::method compileOperationSql
  use arg operation
  fragment = self~compileOperationSql:super(operation)
  if fragment = "" then return fragment
  if operation~operationType = .DatabaseOperationType~PREPAREDBATCH then return fragment
  if self~operationIsMutation(operation) then do
    if operation~operationType = .DatabaseOperationType~STATEMENT then do
      if operation~generatedKeyRequest \== .nil then do
        return fragment || .endOfLine || -
          "SELECT CONCAT('__OOREXX_MUTATION_RESULT__:', ROW_COUNT(), ':', LAST_INSERT_ID()) AS __oorexx_mutation;"
      end
    end
    return fragment || .endOfLine || -
      "SELECT CONCAT('__OOREXX_MUTATION_COUNT__:', ROW_COUNT()) AS __oorexx_mutation;"
  end
  return fragment
::method compilePreparedBatchSql
  use arg batch
  sql = ""
  do execution over batch~executions
    fragment = self~compilePreparedExecutionSql(execution)
    if fragment = "" then iterate
    sql ||= fragment || .endOfLine
    if self~operationIsMutation(execution) then do
      sql ||= "SELECT CONCAT('__OOREXX_MUTATION_COUNT__:', ROW_COUNT()) AS __oorexx_mutation;" || .endOfLine
    end
  end
  return sql~strip("T")
::method compileTransactionBegin
  use arg plan
  tx = plan~transaction
  sql = ""
  if tx~isolationLevel \= .DatabaseIsolation~DEFAULT then do
    level = ""
    select
      when tx~isolationLevel = .DatabaseIsolation~READUNCOMMITTED then level = "READ UNCOMMITTED"
      when tx~isolationLevel = .DatabaseIsolation~READCOMMITTED then level = "READ COMMITTED"
      when tx~isolationLevel = .DatabaseIsolation~REPEATABLEREAD then level = "REPEATABLE READ"
      when tx~isolationLevel = .DatabaseIsolation~SERIALIZABLE then level = "SERIALIZABLE"
      otherwise nop
    end
    if level <> "" then sql ||= "SET TRANSACTION ISOLATION LEVEL " || level || ";" || .endOfLine
  end
  start = "START TRANSACTION"
  select
    when tx~accessMode = .DatabaseAccessMode~READONLY then start ||= " READ ONLY"
    when tx~accessMode = .DatabaseAccessMode~READWRITE then start ||= " READ WRITE"
    otherwise nop
  end
  sql ||= start || ";"
  return sql
::method compilePreparedStatementSql
  use arg statement
  return "PREPARE " || statement~name || " FROM " || self~quoteSqlLiteral(statement~sql) || ";"
::method compilePreparedExecutionSql
  use arg execution
  sql = ""
  names = ""
  do i = 1 to execution~parameters~count
    variableName = "@dbp_" || execution~statement~name || "_" || i
    if i > 1 then names ||= ", "
    names ||= variableName
    sql ||= "SET " || variableName || " = " || self~renderParameter(execution~parameters~at(i)) || ";" || .endOfLine
  end
  sql ||= "EXECUTE " || execution~statement~name
  if names <> "" then sql ||= " USING " || names
  sql ||= ";"
  return sql

::class DatabaseExecutionContext public
::method init
  expose evidence locator attributes
  use arg evidence = .nil, locator = "", attributes = .nil
  if attributes == .nil then attributes = .directory~new
::attribute evidence get
::attribute locator get
::attribute attributes get
::method isEvidenceBearing
  expose evidence
  return evidence \== .nil
::method provenance
  expose evidence locator
  p = .directory~new
  p["kind"] = "DATABASE_EXECUTION_CONTEXT"
  p["locator"] = locator
  if evidence \== .nil then do
    if evidence~hasMethod("PROVENANCE") then p["evidence"] = evidence~provenance
    else p["evidence"] = evidence
  end
  return p

::class Database public
::method init
  expose connection engine executor executableResolver endpointCapabilities
  use arg connection, engine = .nil, executor = .nil, executableResolver = .nil, endpointCapabilities = .nil
  if engine == .nil then engine = self~resolveEngine(connection)
  if executor == .nil then executor = .DatabaseCommandExecutor~new
  if executableResolver == .nil then executableResolver = .DatabaseExecutableResolver~new
  if endpointCapabilities == .nil then endpointCapabilities = .DatabaseEndpointCapabilities~new(engine~capabilities)
::attribute connection get
::attribute engine get
::method capabilities
  expose endpointCapabilities
  return endpointCapabilities
::method supports
  expose endpointCapabilities
  use arg capability
  return endpointCapabilities~supports(capability)
::method endpointIdentity
  expose engine
  identitySql = engine~endpointIdentityQuery
  if identitySql = "" then return .DatabaseEndpointIdentity~new(engine~name, engine~name, "", "")
  qr = self~query(identitySql)
  if \qr~isA(.DatabaseQueryResult) then return .DatabaseEndpointIdentity~new(engine~name, engine~name, "", "")
  return engine~parseEndpointIdentity(qr)
::attribute executor get
::attribute executableResolver get
::attribute endpointCapabilities get
::method resolveEngine private
  use arg connection
  engineName = connection~engineName~lower
  if engineName = "postgres" then return .PostgreSQLEngine~new
  if engineName = "postgresql" then return .PostgreSQLEngine~new
  if engineName = "mysql" then return .MySQLEngine~new
  return .DatabaseEngine~new
::method transaction
  use arg executionContext = .nil, transactionIdentity = .nil
  return .DatabaseTransaction~new(self, executionContext, transactionIdentity)
::method relationalSource
  return .DatabaseRelationalSource~new(self)
::method tableSource
  use arg tableName
  source = self~relationalSource
  return source~table(tableName)
::method query
  use arg sql
  tx = self~transaction
  ref = tx~query(sql)
  transactionResult = tx~commit
  if transactionResult~status \= .Error~SUCCESS then return transactionResult
  if \ref~resolved then return .DatabaseQueryResult~new(.Error~FAILED, .Error~DATABASEERROR)
  return ref~result
::method queryWithSchema
  use arg sql, resultSchema
  tx = self~transaction
  ref = tx~queryWithSchema(sql, resultSchema)
  transactionResult = tx~commit
  if transactionResult~status \= .Error~SUCCESS then return transactionResult
  if \ref~resolved then return .DatabaseQueryResult~new(.Error~FAILED, .Error~DATABASEERROR)
  return ref~result
::method tables
  expose engine
  if \self~supports(.DatabaseCapability~TABLEDISCOVERY) then return .array~new
  discoverySql = engine~tableDiscoveryQuery
  if discoverySql = "" then return .array~new
  queryResult = self~query(discoverySql)
  if \queryResult~isA(.DatabaseQueryResult) then return .array~new
  return engine~parseTableDiscoveryRows(queryResult)
::method relationMetadata
  expose engine
  use arg schemaName, tableName
  if schemaName = "" then return self~tableMetadata(tableName)
  metadataSql = engine~metadataQueryForRelation(schemaName, tableName)
  if metadataSql = "" then return .DatabaseResultMetadata~new
  qr = self~query(metadataSql)
  if \qr~isA(.DatabaseQueryResult) then return .DatabaseResultMetadata~new
  return engine~parseMetadataRows(qr)
::method tableMetadata
  expose engine
  use arg tableName
  metadataSql = engine~metadataQueryForTable(tableName)
  if metadataSql = "" then return .DatabaseResultMetadata~new
  qr = self~query(metadataSql)
  if \qr~isA(.DatabaseQueryResult) then return .DatabaseResultMetadata~new
  return engine~parseMetadataRows(qr)
::method queryRelation
  expose engine
  use arg schemaName, tableName
  metadata = self~relationMetadata(schemaName, tableName)
  qualifiedName = engine~qualifiedRelationName(schemaName, tableName)
  qr = self~query("SELECT * FROM " || qualifiedName)
  if \qr~isA(.DatabaseQueryResult) then return qr
  types = metadata~types
  reparsedRows = .array~new
  do row over qr~rows
    newRow = .DatabaseRow~new
    do c = 1 to qr~columns~items
      rawValue = row~rawAt(qr~columns[c])
      requestedType = .DatabaseType~UNKNOWN
      if c <= types~items then requestedType = types[c]
      newRow~put(qr~columns[c], .DatabaseValue~fromText(rawValue, requestedType))
    end
    reparsedRows~append(newRow)
  end
  return .DatabaseQueryResult~new(qr~status, qr~error, qr~columns, reparsedRows, types)
::method queryTable
  use arg tableName
  return self~queryRelation("", tableName)
::method execute
  use arg sql
  tx = self~transaction
  tx~execute(sql)
  return tx~commit

::class DatabaseOperation public
::method init
  expose operationType tag transactionId operationSequence operationId
  use arg operationType = .nil, tag = ""
  if operationType == .nil then operationType = .DatabaseOperationType~OPERATION
  transactionId = ""
  operationSequence = 0
  operationId = ""
::attribute operationType
::attribute tag
::attribute transactionId get
::attribute operationSequence get
::attribute operationId get
::method bindTransaction
  expose transactionId operationSequence operationId
  use arg newTransactionId, newSequence
  if transactionId <> "" then do
    if transactionId = newTransactionId then do
      if operationSequence = newSequence then return .Error~SUCCESS
    end
    return .Error~INVALIDSTATE
  end
  transactionId = newTransactionId
  operationSequence = newSequence
  operationId = transactionId || ":op:" || operationSequence
  return .Error~SUCCESS

::class DatabaseStatement public subclass DatabaseOperation
::method init
  expose sql statementType expectedResult generatedKeyRequest tag
  use arg sql = "", statementType = .nil, tag = ""
  if statementType == .nil then statementType = .DatabaseOperationType~EXECUTE
  self~init:super(.DatabaseOperationType~STATEMENT, tag)
  expectedResult = .false
  generatedKeyRequest = .nil
::attribute sql
::attribute statementType
::attribute expectedResult
::attribute generatedKeyRequest

::class DatabasePreparedStatement public subclass DatabaseOperation
::method init
  expose name sql scope parameterDefinitions tag
  use arg name = "", sql = "", scope = "transaction", tag = ""
  self~init:super(.DatabaseOperationType~PREPAREDSTATEMENT, tag)
  parameterDefinitions = .array~new
::attribute name
::attribute sql
::attribute scope
::attribute parameterDefinitions get

::class DatabaseParameter public
::method init
  expose value typeName isNull sensitive
  use arg value = .nil, typeName = "auto", sensitive = .false
  isNull = (value == .nil)
::attribute value
::attribute typeName
::attribute isNull
::attribute sensitive

::class DatabaseParameterSet public
::method init
  expose parameters
  parameters = .array~new
::attribute parameters get
::method add
  expose parameters
  use arg parameter
  if \parameter~isA(.DatabaseParameter) then parameter = .DatabaseParameter~new(parameter)
  parameters~append(parameter)
  return parameter
::method count
  expose parameters
  return parameters~items
::method at
  expose parameters
  use arg index
  return parameters[index]

::class DatabasePreparedExecution public subclass DatabaseOperation
::method init
  expose statement parameters expectedResult tag
  use arg statement, parameters = .nil, expectedResult = .false, tag = ""
  self~init:super(.DatabaseOperationType~PREPAREDEXECUTION, tag)
  if parameters == .nil then parameters = .DatabaseParameterSet~new
  self~statement = statement
  self~parameters = parameters
  self~expectedResult = expectedResult
::attribute statement
::attribute parameters
::attribute expectedResult

::class DatabasePreparedBatch public subclass DatabaseOperation
::method init
  expose statement executions tag
  use arg statement, tag = ""
  self~init:super(.DatabaseOperationType~PREPAREDBATCH, tag)
  self~statement = statement
  executions = .array~new
::attribute statement
::attribute executions get
::method add
  expose executions
  use arg execution
  executions~append(execution)
  return execution
::method count
  expose executions
  return executions~items

::class DatabaseSavepoint public subclass DatabaseOperation
::method init
  expose name sequence state tag
  use arg name = "", sequence = 0, tag = ""
  self~init:super(.DatabaseOperationType~SAVEPOINT, tag)
  state = "active"
::attribute name
::attribute sequence
::attribute state

::class DatabaseResultReference public
::method init
  expose producer rowIndex columnName
  use arg producer, rowIndex = 1, columnName = ""
::attribute producer get
::attribute rowIndex get
::attribute columnName get

::class DatabaseDeferredResult public
::method init
  expose operation result resolved resultSchema executionContext
  use arg operation, resultSchema = .nil, executionContext = .nil
  result = .nil
  resolved = .false
::attribute operation get
::attribute result
::attribute resolved
::attribute resultSchema get
::attribute executionContext get
::method operationId
  expose operation
  return operation~operationId
::method transactionId
  expose operation
  return operation~transactionId
::method setExecutionContext
  expose executionContext
  use arg newContext
  executionContext = newContext
  return self
::method evidence
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("EVIDENCE") then return executionContext~evidence
  return .nil
::method resolve
  expose operation result resolved executionContext
  use arg value
  if value \== .nil then do
    if value~hasMethod("SETEXECUTIONCONTEXT") then contextResult = value~setExecutionContext(executionContext)
    if value~hasMethod("SETOPERATIONIDENTITY") then -
      identityResult = value~setOperationIdentity(operation~transactionId, operation~operationId, operation~operationSequence)
  end
  result = value
  resolved = .true
  return value

::class DatabaseOperationDescriptor public
::method init
  expose transactionId operationId operationSequence operationType tag statementType expectedResult sqlText preparedName parameterCount batchCount savepointName
  use arg transactionId = "", operationId = "", operationSequence = 0, operationType = "", tag = "", -
    statementType = "", expectedResult = .false, sqlText = "", preparedName = "", parameterCount = 0, -
    batchCount = 0, savepointName = ""
::attribute transactionId get
::attribute operationId get
::attribute operationSequence get
::attribute operationType get
::attribute tag get
::attribute statementType get
::attribute expectedResult get
::attribute sqlText get
::attribute preparedName get
::attribute parameterCount get
::attribute batchCount get
::attribute savepointName get

::class DatabaseTransactionManifest public
::method init
  expose transactionIdentity isolationLevel accessMode timeout retryMaxAttempts operations executionContext
  use arg transactionIdentity = .nil, isolationLevel = .nil, accessMode = .nil, timeout = 0, -
    retryMaxAttempts = 1, operations = .nil, executionContext = .nil
  if operations == .nil then operations = .array~new
::attribute transactionIdentity get
::attribute isolationLevel get
::attribute accessMode get
::attribute timeout get
::attribute retryMaxAttempts get
::attribute operations get
::attribute executionContext get
::method transactionId
  expose transactionIdentity
  if transactionIdentity == .nil then return ""
  return transactionIdentity~id
::method operationCount
  expose operations
  return operations~items
::method operationIds
  expose operations
  ids = .array~new
  do descriptor over operations
    ids~append(descriptor~operationId)
  end
  return ids

::class DatabaseTransactionIdentity public
::method init
  expose id createdAt
  use arg id = ""
  if id = "" then id = self~newId
  createdAt = .DateTime~new
::attribute id get
::attribute createdAt get
::method string
  expose id
  return id
::method newId private
  timestamp = .DateTime~new~string
  timestamp = timestamp~changeStr("-", "")
  timestamp = timestamp~changeStr(":", "")
  timestamp = timestamp~changeStr("T", "_")
  timestamp = timestamp~changeStr(".", "")
  return "tx_" || timestamp || "_" || random(100000, 999999)

::class DatabaseTransaction public
::method init
  expose database operations state savepointSequence deferredResults isolationLevel accessMode timeout retryPolicy executionContext transactionIdentity operationSequence
  use arg database, executionContext = .nil, transactionIdentity = .nil
  if transactionIdentity == .nil then transactionIdentity = .DatabaseTransactionIdentity~new
  operations = .array~new
  operationSequence = 0
  deferredResults = .array~new
  state = "building"
  savepointSequence = 0
  isolationLevel = .DatabaseIsolation~DEFAULT
  accessMode = .DatabaseAccessMode~DEFAULT
  timeout = 0
  retryPolicy = .DatabaseRetryPolicy~new(1)
::attribute database get
::attribute operations get
::attribute state get
::attribute deferredResults get
::attribute isolationLevel get
::attribute accessMode get
::attribute timeout get
::attribute retryPolicy get
::attribute executionContext get
::attribute transactionIdentity get
::method transactionId
  expose transactionIdentity
  return transactionIdentity~id
::method setExecutionContext
  expose state executionContext deferredResults
  use arg newContext
  if state \= "building" then return .Error~INVALIDSTATE
  executionContext = newContext
  do deferredResult over deferredResults
    contextResult = deferredResult~setExecutionContext(newContext)
  end
  return .Error~SUCCESS
::method isolation
  expose state isolationLevel
  use arg newIsolation
  if state \= "building" then return .Error~INVALIDSTATE
  select
    when newIsolation = .DatabaseIsolation~DEFAULT then nop
    when newIsolation = .DatabaseIsolation~READUNCOMMITTED then nop
    when newIsolation = .DatabaseIsolation~READCOMMITTED then nop
    when newIsolation = .DatabaseIsolation~REPEATABLEREAD then nop
    when newIsolation = .DatabaseIsolation~SERIALIZABLE then nop
    otherwise return .Error~INVALIDARGUMENT
  end
  isolationLevel = newIsolation
  return .Error~SUCCESS
::method readOnly
  expose state accessMode
  if state \= "building" then return .Error~INVALIDSTATE
  accessMode = .DatabaseAccessMode~READONLY
  return .Error~SUCCESS
::method readWrite
  expose state accessMode
  if state \= "building" then return .Error~INVALIDSTATE
  accessMode = .DatabaseAccessMode~READWRITE
  return .Error~SUCCESS
::method setTimeout
  expose state timeout
  use arg seconds
  if state \= "building" then return .Error~INVALIDSTATE
  if \seconds~datatype("W") then return .Error~INVALIDARGUMENT
  if seconds < 0 then return .Error~INVALIDARGUMENT
  timeout = seconds
  return .Error~SUCCESS
::method setRetryAttempts
  expose state retryPolicy
  use arg attempts
  if state \= "building" then return .Error~INVALIDSTATE
  if \attempts~datatype("W") then return .Error~INVALIDARGUMENT
  if attempts < 1 then return .Error~INVALIDARGUMENT
  retryPolicy = .DatabaseRetryPolicy~new(attempts)
  return .Error~SUCCESS
::method execute
  expose operations
  use arg sql
  stmt = .DatabaseStatement~new(sql, .DatabaseOperationType~EXECUTE)
  bindStatus = self~appendOperation(stmt)
  return stmt
::method insertReturningKey
  expose operations
  use arg sql, columnName
  stmt = .DatabaseStatement~new(sql, .DatabaseOperationType~EXECUTE)
  stmt~generatedKeyRequest = .DatabaseGeneratedKeyRequest~new(columnName)
  bindStatus = self~appendOperation(stmt)
  return stmt
::method query
  expose operations deferredResults executionContext
  use arg sql
  stmt = .DatabaseStatement~new(sql, .DatabaseOperationType~QUERY)
  stmt~expectedResult = .true
  bindStatus = self~appendOperation(stmt)
  ref = .DatabaseDeferredResult~new(stmt, .nil, executionContext)
  deferredResults~append(ref)
  return ref
::method queryWithSchema
  expose operations deferredResults executionContext
  use arg sql, resultSchema
  stmt = .DatabaseStatement~new(sql, .DatabaseOperationType~QUERY)
  stmt~expectedResult = .true
  bindStatus = self~appendOperation(stmt)
  ref = .DatabaseDeferredResult~new(stmt, resultSchema, executionContext)
  deferredResults~append(ref)
  return ref
::method prepareStatement
  expose operations
  use arg name, sql, scope = "transaction"
  stmt = .DatabasePreparedStatement~new(name, sql, scope)
  bindStatus = self~appendOperation(stmt)
  return stmt
::method executePrepared
  expose operations
  use arg statement, values = .nil
  params = self~normalizeParameters(values)
  execution = .DatabasePreparedExecution~new(statement, params, .false)
  bindStatus = self~appendOperation(execution)
  return execution
::method queryPrepared
  expose operations deferredResults executionContext
  use arg statement, values = .nil
  params = self~normalizeParameters(values)
  execution = .DatabasePreparedExecution~new(statement, params, .true)
  bindStatus = self~appendOperation(execution)
  ref = .DatabaseDeferredResult~new(execution, .nil, executionContext)
  deferredResults~append(ref)
  return ref
::method savepoint
  expose operations savepointSequence
  use arg name = ""
  savepointSequence += 1
  if name = "" then name = "sp_" || savepointSequence
  sp = .DatabaseSavepoint~new(name, savepointSequence)
  bindStatus = self~appendOperation(sp)
  return sp
::method rollbackTo
  expose operations
  use arg savepoint
  op = .DatabaseOperation~new(.DatabaseOperationType~ROLLBACKTOSAVEPOINT, savepoint~name)
  bindStatus = self~appendOperation(op)
  return op
::method applyResultSchema private
  use arg queryResult, resultSchema
  types = resultSchema~types
  reparsedRows = .array~new
  do row over queryResult~rows
    newRow = .DatabaseRow~new
    do c = 1 to queryResult~columns~items
      rawValue = row~rawAt(queryResult~columns[c])
      requestedType = .DatabaseType~UNKNOWN
      if c <= types~items then requestedType = types[c]
      newRow~put(queryResult~columns[c], .DatabaseValue~fromText(rawValue, requestedType))
    end
    reparsedRows~append(newRow)
  end
  return .DatabaseQueryResult~new(queryResult~status, queryResult~error, queryResult~columns, reparsedRows, types)
::method manifest
  expose isolationLevel accessMode timeout retryPolicy transactionIdentity operations executionContext
  identityStatus = self~ensureOperationIdentities
  if identityStatus \= .Error~SUCCESS then return .DatabaseResult~new(.Error~NOTEXECUTED, identityStatus)
  descriptors = .array~new
  do operation over operations
    descriptors~append(self~describeOperation(operation))
  end
  return .DatabaseTransactionManifest~new(transactionIdentity, isolationLevel, accessMode, timeout, -
    retryPolicy~maxAttempts, descriptors, executionContext)
::method describeOperation private
  use arg operation
  operationType = operation~operationType
  tag = operation~tag
  statementType = ""
  expectedResult = .false
  sqlText = ""
  preparedName = ""
  parameterCount = 0
  batchCount = 0
  savepointName = ""

  if operation~isA(.DatabaseStatement) then do
    statementType = operation~statementType
    expectedResult = operation~expectedResult
    sqlText = operation~sql
  end
  else if operation~isA(.DatabasePreparedStatement) then do
    preparedName = operation~name
    sqlText = operation~sql
  end
  else if operation~isA(.DatabasePreparedExecution) then do
    preparedName = operation~statement~name
    expectedResult = operation~expectedResult
    parameterCount = operation~parameters~count
  end
  else if operation~isA(.DatabasePreparedBatch) then do
    preparedName = operation~statement~name
    batchCount = operation~count
  end
  else if operation~isA(.DatabaseSavepoint) then savepointName = operation~name
  else if operationType = .DatabaseOperationType~ROLLBACKTOSAVEPOINT then savepointName = operation~tag

  return .DatabaseOperationDescriptor~new(operation~transactionId, operation~operationId, -
    operation~operationSequence, operationType, tag, statementType, expectedResult, sqlText, -
    preparedName, parameterCount, batchCount, savepointName)
::method rollback
  expose state operations executionContext transactionIdentity
  if state = "building" then do
    transactionManifest = self~manifest
    state = "rolled-back"
    return .DatabaseTransactionResult~new(.Error~NOTEXECUTED, .Error~SUCCESS, .nil, operations~items, 1, -
      .nil, executionContext, .nil, transactionIdentity, transactionManifest)
  end
  return .DatabaseTransactionResult~new(.Error~UNKNOWN, .Error~INVALIDSTATE, .nil, operations~items, 1, .nil, executionContext, .nil, transactionIdentity)
::method prepare
  expose database
  return database~engine~createTransactionPlan(self)
::method commit
  expose database state operations deferredResults retryPolicy executionContext transactionIdentity operationSequence
  if state \= "building" then return .DatabaseTransactionResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE, .nil, operations~items, 0, .nil, executionContext, .nil, transactionIdentity)
  identityStatus = self~ensureOperationIdentities
  if identityStatus \= .Error~SUCCESS then -
    return .DatabaseTransactionResult~new(.Error~NOTEXECUTED, identityStatus, .nil, operations~items, 0, .nil, executionContext, .nil, transactionIdentity)
  transactionManifest = self~manifest
  if \transactionManifest~isA(.DatabaseTransactionManifest) then -
    return .DatabaseTransactionResult~new(.Error~NOTEXECUTED, .Error~INVALIDPLAN, .nil, operations~items, 0, .nil, executionContext, .nil, transactionIdentity)
  state = "executing"
  plan = self~prepare
  attemptCount = 0
  attempts = .array~new
  commandResult = .nil
  outcome = .Error~UNKNOWN
  error = .Error~UNKNOWN

  do while attemptCount < retryPolicy~maxAttempts
    attemptCount += 1
    command = database~engine~compile(plan)
    commandResult = database~executor~execute(command)
    if commandResult~hasMethod("SETEXECUTIONCONTEXT") then contextResult = commandResult~setExecutionContext(executionContext)

    if commandResult~status = .Error~SUCCESS then do
      outcome = .Error~COMMITTED
      error = .Error~SUCCESS
      attempts~append(.DatabaseExecutionAttempt~new(attemptCount, .Error~SUCCESS, .Error~SUCCESS, -
        commandResult, .false, executionContext, transactionIdentity~id))
      leave
    end

    if commandResult~status = .Error~NOTEXECUTED then do
      outcome = .Error~NOTEXECUTED
      error = commandResult~error
      attempts~append(.DatabaseExecutionAttempt~new(attemptCount, .Error~NOTEXECUTED, error, -
        commandResult, .false, executionContext, transactionIdentity~id))
      leave
    end

    parsedResult = database~engine~parser~parse(commandResult)
    if parsedResult~hasMethod("SETEXECUTIONCONTEXT") then contextResult = parsedResult~setExecutionContext(executionContext)
    error = parsedResult~error
    outcome = .Error~ROLLEDBACK
    retryable = retryPolicy~isRetryable(error)
    attempts~append(.DatabaseExecutionAttempt~new(attemptCount, parsedResult~status, error, -
      commandResult, retryable, executionContext, transactionIdentity~id))

    if \retryable then leave
    if attemptCount >= retryPolicy~maxAttempts then leave
  end

  mutationResults = .array~new
  if outcome = .Error~COMMITTED then do
    mutationResults = database~engine~parser~parseMutationResults(commandResult)
    mutationOperationIds = self~mutationResultOperationIds
    do i = 1 to mutationResults~items
      mutationResult = mutationResults[i]
      if mutationResult~hasMethod("SETEXECUTIONCONTEXT") then contextResult = mutationResult~setExecutionContext(executionContext)
      if i <= mutationOperationIds~items then do
        mutationOperation = mutationOperationIds[i]
        if mutationResult~hasMethod("SETOPERATIONIDENTITY") then -
          identityResult = mutationResult~setOperationIdentity(mutationOperation~transactionId, -
            mutationOperation~operationId, mutationOperation~operationSequence)
      end
    end
  end
  transactionResult = .DatabaseTransactionResult~new(outcome, error, commandResult, operations~items, -
    attemptCount, mutationResults, executionContext, attempts, transactionIdentity, transactionManifest)

  if outcome = .Error~COMMITTED then state = "committed"
  else if outcome = .Error~NOTEXECUTED then state = "not-executed"
  else state = "failed"

  if outcome = .Error~COMMITTED then do
    if deferredResults~items > 0 then do
      queryResults = database~engine~parser~parseQueryFrames(commandResult)
      if queryResults~items = deferredResults~items then do
        do i = 1 to deferredResults~items
          frameResult = queryResults[i]
          resultSchema = deferredResults[i]~resultSchema
          if resultSchema \== .nil then frameResult = self~applyResultSchema(frameResult, resultSchema)
          deferredResults[i]~resolve(frameResult)
        end
      end
    end
  end
  return transactionResult
::method ensureOperationIdentities private
  expose operations transactionIdentity operationSequence
  operationSequence = operations~items
  do i = 1 to operations~items
    operation = operations[i]
    bindStatus = operation~bindTransaction(transactionIdentity~id, i)
    if bindStatus \= .Error~SUCCESS then return bindStatus
  end
  return .Error~SUCCESS
::method mutationResultOperationIds private
  expose operations
  producers = .array~new
  do operation over operations
    opType = operation~operationType
    if opType = .DatabaseOperationType~STATEMENT then do
      if \operation~expectedResult then producers~append(operation)
    end
    else if opType = .DatabaseOperationType~PREPAREDEXECUTION then do
      if \operation~expectedResult then producers~append(operation)
    end
    else if opType = .DatabaseOperationType~PREPAREDBATCH then do
      do batchIndex = 1 to operation~count
        producers~append(operation)
      end
    end
  end
  return producers
::method appendOperation private
  expose operations transactionIdentity operationSequence
  use arg operation
  operationSequence += 1
  bindStatus = operation~bindTransaction(transactionIdentity~id, operationSequence)
  if bindStatus \= .Error~SUCCESS then return bindStatus
  operations~append(operation)
  return .Error~SUCCESS
::method normalizeParameters private
  use arg values
  if values == .nil then return .DatabaseParameterSet~new
  if values~isA(.DatabaseParameterSet) then return values
  params = .DatabaseParameterSet~new
  if values~isA(.Array) then do
    do item over values
      params~add(item)
    end
  end
  else params~add(values)
  return params

::class DatabaseValidationResult public subclass DatabaseResult
::method init
  expose status error message operationIndex success warnings
  use arg status = .nil, error = .nil, message = "", operationIndex = 0
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~init:super(status, error)
::attribute message get
::attribute operationIndex get

::class DatabaseTransactionPlan public
::method init
  expose transaction engine operations prepared validationResult
  use arg transaction, engine
  operations = transaction~operations
  prepared = .true
  validationResult = .nil
::attribute transaction get
::attribute engine get
::attribute operations get
::attribute prepared get
::attribute validationResult get
::method statementCount
  expose operations
  return operations~items
::method validate
  expose operations validationResult engine
  preparedNames = .directory~new
  savepoints = .directory~new
  index = 0
  do operation over operations
    index += 1
    opType = operation~operationType
    select
      when opType = .DatabaseOperationType~STATEMENT then do
        if operation~generatedKeyRequest \== .nil then do
          sqlText = operation~sql~strip~upper
          if sqlText~pos("INSERT ") \= 1 then return self~validationFailure(.Error~INVALIDOPERATION, "generated key request requires INSERT", index)
          keyColumn = operation~generatedKeyRequest~columnName
          if keyColumn = "" then return self~validationFailure(.Error~INVALIDARGUMENT, "generated key column is empty", index)
          if \engine~validSqlIdentifier(keyColumn) then return self~validationFailure(.Error~INVALIDARGUMENT, "generated key column is invalid", index)
        end
      end
      when opType = .DatabaseOperationType~PREPAREDSTATEMENT then do
        name = operation~name
        if name = "" then return self~validationFailure(.Error~INVALIDPLAN, "prepared statement name is empty", index)
        if preparedNames~hasIndex(name) then return self~validationFailure(.Error~DUPLICATEPREPARED, "duplicate prepared statement: " || name, index)
        preparedNames[name] = operation
      end
      when opType = .DatabaseOperationType~PREPAREDEXECUTION then do
        statement = operation~statement
        if statement == .nil then return self~validationFailure(.Error~INVALIDPLAN, "prepared execution has no statement", index)
        name = statement~name
        if \preparedNames~hasIndex(name) then return self~validationFailure(.Error~PREPAREFAILED, "prepared statement not declared before execution: " || name, index)
        expected = statement~sql~countStr("?")
        actual = operation~parameters~count
        if expected \= actual then return self~validationFailure(.Error~PARAMETERCOUNT, "parameter count mismatch for " || name, index)
        parameterStatus = self~validateParameters(operation~parameters)
        if parameterStatus \= .Error~SUCCESS then return self~validationFailure(parameterStatus, "invalid typed parameter for " || name, index)
      end
      when opType = .DatabaseOperationType~PREPAREDBATCH then do
        statement = operation~statement
        if statement == .nil then return self~validationFailure(.Error~INVALIDPLAN, "prepared batch has no statement", index)
        name = statement~name
        if \preparedNames~hasIndex(name) then return self~validationFailure(.Error~PREPAREFAILED, "prepared statement not declared before batch: " || name, index)
        expected = statement~sql~countStr("?")
        do execution over operation~executions
          actual = execution~parameters~count
          if expected \= actual then return self~validationFailure(.Error~PARAMETERCOUNT, "parameter count mismatch in batch for " || name, index)
          parameterStatus = self~validateParameters(execution~parameters)
          if parameterStatus \= .Error~SUCCESS then return self~validationFailure(parameterStatus, "invalid typed parameter in batch for " || name, index)
        end
      end
      when opType = .DatabaseOperationType~SAVEPOINT then do
        if operation~name = "" then return self~validationFailure(.Error~INVALIDSAVEPOINT, "savepoint name is empty", index)
        savepoints[operation~name] = operation
      end
      when opType = .DatabaseOperationType~ROLLBACKTOSAVEPOINT then do
        if \savepoints~hasIndex(operation~tag) then return self~validationFailure(.Error~INVALIDSAVEPOINT, "unknown savepoint: " || operation~tag, index)
      end
      otherwise return self~validationFailure(.Error~INVALIDOPERATION, "unsupported operation in transaction plan", index)
    end
  end
  validationResult = .DatabaseValidationResult~new(.Error~SUCCESS, .Error~SUCCESS, "", 0)
  return validationResult
::method validateParameters private
  use arg parameters
  do i = 1 to parameters~count
    parameter = parameters~at(i)
    if parameter~isNull then iterate
    typeName = parameter~typeName~lower
    value = parameter~value
    if typeName = "integer" then do
      if \value~datatype("W") then return .Error~INVALIDPARAMETER
    end
    else if typeName = "decimal" then do
      if \value~datatype("N") then return .Error~INVALIDPARAMETER
    end
    else if typeName = "numeric" then do
      if \value~datatype("N") then return .Error~INVALIDPARAMETER
    end
    else if typeName = "boolean" then do
      if value \= .true then do
        if value \= .false then return .Error~INVALIDPARAMETER
      end
    end
  end
  return .Error~SUCCESS
::method validationFailure private
  expose validationResult
  use arg error, message, operationIndex
  validationResult = .DatabaseValidationResult~new(.Error~FAILED, error, message, operationIndex)
  return validationResult

::class DatabaseRelationDescriptor public
::method init
  expose schemaName name relationType
  use arg schemaName = "", name = "", relationType = ""
::attribute schemaName get
::attribute name get
::attribute relationType get
::method qualifiedName
  expose schemaName name
  if schemaName = "" then return name
  return schemaName || "." || name
::method string
  return self~qualifiedName

::class DatabaseSourceConformanceMode public
::constant OBSERVATIONAL "OBSERVATIONAL"
::constant READ          "READ"

::class DatabaseSourceConformanceResult public
::method init
  expose passed failed skipped details mode
  use arg mode = "READ"
  passed = 0
  failed = 0
  skipped = 0
  details = .array~new
::attribute mode get
::attribute passed get
::attribute failed get
::attribute skipped get
::attribute details get
::method pass
  expose passed details
  use arg name
  passed += 1
  details~append("PASS " || name)
  return self
::method fail
  expose failed details
  use arg name, message = ""
  failed += 1
  detail = "FAIL " || name
  if message <> "" then detail ||= " - " || message
  details~append(detail)
  return self
::method skip
  expose skipped details
  use arg name, message = ""
  skipped += 1
  detail = "SKIP " || name
  if message <> "" then detail ||= " - " || message
  details~append(detail)
  return self
::method ok
  expose failed
  return failed = 0

::class DatabaseSourceConformanceSuite public
::method run
  use arg source, mode = "READ"
  if mode \= .DatabaseSourceConformanceMode~READ then do
    if mode \= .DatabaseSourceConformanceMode~OBSERVATIONAL then mode = .DatabaseSourceConformanceMode~READ
  end
  conformance = .DatabaseSourceConformanceResult~new(mode)
  checkStatus = self~checkIdentity(source, conformance)
  checkStatus = self~checkCapabilities(source, conformance)
  checkStatus = self~checkDiscovery(source, conformance, mode)
  return conformance
::method runObservational
  use arg source
  return self~run(source, .DatabaseSourceConformanceMode~OBSERVATIONAL)
::method runRead
  use arg source
  return self~run(source, .DatabaseSourceConformanceMode~READ)
::method checkIdentity private
  use arg source, conformance
  if \source~hasMethod("identity") then do
    conformance~fail("identity", "source has no identity method")
    return .Error~SUCCESS
  end
  sourceIdentity = source~identity
  if sourceIdentity == .nil then do
    conformance~fail("identity", "identity returned NIL")
    return .Error~SUCCESS
  end
  if \sourceIdentity~isA(.DatabaseSourceIdentity) then do
    conformance~fail("identity", "identity is not DatabaseSourceIdentity")
    return .Error~SUCCESS
  end
  if sourceIdentity~engineName = "" then do
    conformance~fail("identity", "engine name is empty")
    return .Error~SUCCESS
  end
  conformance~pass("identity")
  return .Error~SUCCESS
::method checkCapabilities private
  use arg source, conformance
  if \source~hasMethod("capabilities") then do
    conformance~fail("capabilities", "source has no capabilities method")
    return .Error~SUCCESS
  end
  sourceCapabilities = source~capabilities
  if sourceCapabilities == .nil then do
    conformance~fail("capabilities", "capabilities returned NIL")
    return .Error~SUCCESS
  end
  if \sourceCapabilities~hasMethod("all") then do
    conformance~fail("capabilities", "capabilities object has no all method")
    return .Error~SUCCESS
  end
  capabilityList = sourceCapabilities~all
  if \capabilityList~isA(.Array) then do
    conformance~fail("capabilities", "capability enumeration is not an Array")
    return .Error~SUCCESS
  end
  conformance~pass("capabilities")
  return .Error~SUCCESS
::method checkDiscovery private
  use arg source, conformance, mode
  if source~hasMethod("supports") then do
    if \source~supports(.DatabaseCapability~TABLEDISCOVERY) then do
      conformance~skip("table_discovery", "TABLEDISCOVERY not advertised")
      return .Error~SUCCESS
    end
  end
  if \source~hasMethod("tables") then do
    conformance~fail("table_discovery", "TABLEDISCOVERY advertised but tables method missing")
    return .Error~SUCCESS
  end
  relations = source~tables
  if \relations~isA(.Array) then do
    conformance~fail("table_discovery", "tables did not return an Array")
    return .Error~SUCCESS
  end
  do relation over relations
    if \relation~isA(.DatabaseRelationDescriptor) then do
      conformance~fail("table_discovery", "non-descriptor returned")
      return .Error~SUCCESS
    end
    if relation~name = "" then do
      conformance~fail("table_discovery", "descriptor name is empty")
      return .Error~SUCCESS
    end
    if source~hasMethod("relation") then table = source~relation(relation)
    else table = source~table(relation~name)
    checkStatus = self~checkTable(table, relation, conformance, mode)
    if conformance~failed > 0 then return
  end
  conformance~pass("table_discovery")
  return .Error~SUCCESS
::method checkTable private
  use arg table, relation, conformance, mode
  if table == .nil then do
    conformance~fail("table_binding", "source returned NIL table binding")
    return .Error~SUCCESS
  end
  if \table~isA(.DatabaseTableSource) then do
    conformance~fail("table_binding", "binding is not DatabaseTableSource")
    return .Error~SUCCESS
  end
  tableIdentity = table~identity
  if tableIdentity~sourceKind \= .DatabaseSourceKind~TABLE then do
    conformance~fail("table_identity", "wrong source kind")
    return .Error~SUCCESS
  end
  if relation~isA(.DatabaseRelationDescriptor) then do
    if table~tableName \= relation~name then do
      conformance~fail("table_identity", "relation name changed during binding")
      return .Error~SUCCESS
    end
    if table~schemaName \= relation~schemaName then do
      conformance~fail("table_identity", "schema name changed during binding")
      return .Error~SUCCESS
    end
    if table~relationType \= relation~relationType then do
      conformance~fail("table_identity", "relation type changed during binding")
      return .Error~SUCCESS
    end
    if tableIdentity~schemaName \= relation~schemaName then do
      conformance~fail("table_identity", "identity lost schema name")
      return .Error~SUCCESS
    end
    if tableIdentity~qualifiedName = "" then do
      conformance~fail("table_identity", "identity has empty qualified name")
      return .Error~SUCCESS
    end
  end
  tableMetadata = table~metadata
  if \tableMetadata~isA(.DatabaseResultMetadata) then do
    conformance~fail("table_metadata", "metadata is not DatabaseResultMetadata")
    return .Error~SUCCESS
  end
  description = table~describe
  if \description~isA(.Directory) then do
    conformance~fail("table_describe", "describe is not a Directory")
    return .Error~SUCCESS
  end
  if description["name"] \= table~tableName then do
    conformance~fail("table_describe", "describe changed table name")
    return .Error~SUCCESS
  end
  conformance~pass("table_binding")
  conformance~pass("table_metadata")
  conformance~pass("table_describe")

  if mode = .DatabaseSourceConformanceMode~OBSERVATIONAL then do
    conformance~skip("table_rows", "observational conformance does not demand rows")
    return .Error~SUCCESS
  end

  rowResult = table~rows
  if \rowResult~isA(.DatabaseQueryResult) then do
    conformance~fail("table_rows", "rows is not DatabaseQueryResult")
    return .Error~SUCCESS
  end
  do row over rowResult~rows
    if \row~isA(.DatabaseRow) then do
      conformance~fail("table_rows", "row is not DatabaseRow")
      return .Error~SUCCESS
    end
  end
  conformance~pass("table_rows")
  return .Error~SUCCESS

::class DatabaseRelationalSource public
::method init
  expose database cachedEndpointIdentity
  use arg database
  cachedEndpointIdentity = .nil
::attribute database get
::method endpointIdentity
  expose database cachedEndpointIdentity
  if cachedEndpointIdentity == .nil then cachedEndpointIdentity = database~endpointIdentity
  return cachedEndpointIdentity
::method identity
  expose database
  endpoint = self~endpointIdentity
  return .DatabaseSourceIdentity~new(.DatabaseSourceKind~DATABASE, database~engine~name, -
    database~connection~databaseName, endpoint)
::method capabilities
  expose database
  return database~capabilities
::method supports
  expose database
  use arg capability
  return database~supports(capability)
::method tables
  expose database
  return database~tables
::method relation
  expose database
  use arg descriptor
  if descriptor~isA(.DatabaseRelationDescriptor) then -
    return .DatabaseTableSource~new(database, descriptor~name, self, descriptor~schemaName, descriptor~relationType)
  return .DatabaseTableSource~new(database, descriptor~string, self)
::method table
  expose database
  use arg tableName
  return .DatabaseTableSource~new(database, tableName, self)

::class DatabaseTableSource public
::method init
  expose database tableName parentSource schemaName relationType
  use arg database, tableName, parentSource = .nil, schemaName = "", relationType = ""
  if parentSource == .nil then parentSource = .DatabaseRelationalSource~new(database)
::attribute database get
::attribute tableName get
::attribute schemaName get
::attribute relationType get
::attribute parentSource get
::method qualifiedName
  expose database schemaName tableName
  return database~engine~qualifiedRelationName(schemaName, tableName)
::method endpointIdentity
  expose parentSource
  return parentSource~endpointIdentity
::method identity
  expose database tableName schemaName
  endpoint = self~endpointIdentity
  qualifiedName = self~qualifiedName
  return .DatabaseSourceIdentity~new(.DatabaseSourceKind~TABLE, database~engine~name, -
    tableName, endpoint, schemaName, qualifiedName)
::method capabilities
  expose database
  return database~capabilities
::method supports
  expose database
  use arg capability
  return database~supports(capability)
::method metadata
  expose database schemaName tableName
  return database~relationMetadata(schemaName, tableName)
::method rows
  expose database schemaName tableName
  return database~queryRelation(schemaName, tableName)
::method query
  expose database
  use arg sql
  return database~query(sql)
::method describe
  expose tableName
  description = .directory~new
  sourceIdentity = self~identity
  sourceCapabilities = self~capabilities
  capabilityList = sourceCapabilities~all
  tableMetadata = self~metadata
  description["name"] = tableName
  description["schema"] = self~schemaName
  description["qualifiedName"] = self~qualifiedName
  description["relationType"] = self~relationType
  description["engine"] = sourceIdentity~engineName
  description["protocol"] = sourceIdentity~protocol
  description["product"] = sourceIdentity~product
  description["version"] = sourceIdentity~version
  description["capabilities"] = capabilityList
  description["metadata"] = tableMetadata
  return description

::class DatabaseSourceIdentity public
::method init
  expose sourceKind engineName name endpointIdentity schemaName qualifiedName
  use arg sourceKind = .nil, engineName = "", name = "", endpointIdentity = .nil, schemaName = "", qualifiedName = ""
  if sourceKind == .nil then sourceKind = .DatabaseSourceKind~DATABASE
  if qualifiedName = "" then qualifiedName = name
::attribute sourceKind get
::attribute engineName get
::attribute name get
::attribute endpointIdentity get
::attribute schemaName get
::attribute qualifiedName get
::method protocol
  expose endpointIdentity engineName
  if endpointIdentity == .nil then return engineName
  return endpointIdentity~protocol
::method product
  expose endpointIdentity engineName
  if endpointIdentity == .nil then return engineName
  return endpointIdentity~product
::method version
  expose endpointIdentity
  if endpointIdentity == .nil then return ""
  return endpointIdentity~version
::method string
  expose sourceKind engineName name endpointIdentity
  base = sourceKind || ":" || engineName || ":" || name
  if endpointIdentity == .nil then return base
  return base || ":" || endpointIdentity~product

::class DatabaseCommandEnvironment public
::method init
  expose values
  values = .directory~new
::attribute values get
::method put
  expose values
  use arg name, value
  values[name] = value
  return value
::method at
  expose values
  use arg name
  if values~hasIndex(name) then return values[name]
  return .nil
::method has
  expose values
  use arg name
  return values~hasIndex(name)

::class DatabaseExecutableResolver public
::method init
  expose overrides
  overrides = .directory~new
::method setOverride
  expose overrides
  use arg engineName, path
  overrides[engineName] = path
  return path
::method resolve
  expose overrides
  use arg engineName
  if overrides~hasIndex(engineName) then return overrides[engineName]
  select
    when engineName = "postgresql" then return "psql"
    when engineName = "mysql" then return "mysql"
    otherwise return ""
  end

::class DatabaseCommand public
::method init
  expose status error engineName executable arguments stdinText environment timeout
  use arg engineName = "generic", executable = "NOP", arguments = .nil, stdinText = ""
  if arguments == .nil then arguments = .array~new
  status = .Error~SUCCESS
  error = .Error~SUCCESS
  environment = .DatabaseCommandEnvironment~new
  timeout = 0
::attribute status
::attribute error
::attribute engineName
::attribute executable
::attribute arguments get
::attribute stdinText
::attribute environment get
::attribute timeout

::class DatabaseCommandExecutor public
::method execute
  use arg command
  if command~status = .Error~NOTEXECUTED then return .DatabaseCommandResult~notExecuted(command, command~error)
  return .DatabaseCommandResult~new(0, "", "", command, "NOP")

::class DatabaseNopCommandExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  if command~status = .Error~NOTEXECUTED then return .DatabaseCommandResult~notExecuted(command, command~error)
  return .DatabaseCommandResult~new(0, "", "", command, "NOP")

::class DatabaseProcessCommandExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  if command~status = .Error~NOTEXECUTED then return .DatabaseCommandResult~notExecuted(command, command~error)

  if \self~executableAvailable(command~executable) then -
    return .DatabaseCommandResult~notExecuted(command, .Error~EXECUTABLENOTFOUND)

  stdinFile = self~temporaryPath("stdin")
  stdoutFile = self~temporaryPath("stdout")
  stderrFile = self~temporaryPath("stderr")
  if stdinFile = "" then return .DatabaseCommandResult~executionError(command, .Error~TEMPFILEFAILED)
  if stdoutFile = "" then do
    deleteStatus = self~deleteFile(stdinFile)
    return .DatabaseCommandResult~executionError(command, .Error~TEMPFILEFAILED)
  end
  if stderrFile = "" then do
    deleteStatus = self~deleteFile(stdinFile)
    deleteStatus = self~deleteFile(stdoutFile)
    return .DatabaseCommandResult~executionError(command, .Error~TEMPFILEFAILED)
  end

  writeStatus = self~writeTextFile(stdinFile, command~stdinText)
  if writeStatus \= .Error~SUCCESS then return .DatabaseCommandResult~executionError(command, .Error~INPUTFAILED)

  environmentStatus = self~validateEnvironment(command~environment)
  if environmentStatus \= .Error~SUCCESS then do
    deleteStatus = self~deleteFile(stdinFile)
    deleteStatus = self~deleteFile(stdoutFile)
    deleteStatus = self~deleteFile(stderrFile)
    return .DatabaseCommandResult~executionError(command, environmentStatus)
  end

  commandLine = self~buildCommandLine(command, stdinFile, stdoutFile, stderrFile)
  address system commandLine
  commandRc = rc

  stdoutText = self~readTextFile(stdoutFile)
  stderrText = self~readTextFile(stderrFile)

  deleteStatus = self~deleteFile(stdinFile)
  deleteStatus = self~deleteFile(stdoutFile)
  deleteStatus = self~deleteFile(stderrFile)

  if command~timeout > 0 then do
    if commandRc = 124 then return .DatabaseCommandResult~new(commandRc, stdoutText, stderrText, command, "TIMEOUT")
  end
  return .DatabaseCommandResult~new(commandRc, stdoutText, stderrText, command, "PROCESS")
::method executableAvailable private
  use arg executable
  if executable = "" then return .false
  if executable~pos("/") > 0 then do
    address system "test -x " || self~shellQuote(executable) || " >/dev/null 2>&1"
    return rc = 0
  end
  address system "command -v " || self~shellQuote(executable) || " >/dev/null 2>&1"
  return rc = 0
::method validateEnvironment private
  use arg environment
  values = environment~values
  do name over values
    if \self~validEnvironmentName(name) then return .Error~INVALIDENVIRONMENT
  end
  return .Error~SUCCESS
::method buildCommandLine private
  use arg command, stdinFile, stdoutFile, stderrFile
  line = ""
  values = command~environment~values
  do name over values
    line ||= name || "=" || self~shellQuote(values[name]) || " "
  end
  if command~timeout > 0 then do
    line ||= "timeout --signal=TERM " || self~shellQuote(command~timeout) || " "
  end
  line ||= self~shellQuote(command~executable)
  do argument over command~arguments
    line ||= " " || self~shellQuote(argument)
  end
  line ||= " < " || self~shellQuote(stdinFile)
  line ||= " > " || self~shellQuote(stdoutFile)
  line ||= " 2> " || self~shellQuote(stderrFile)
  return line
::method validEnvironmentName private
  use arg name
  if name = "" then return .false
  first = name~substr(1, 1)
  if \first~datatype("A") then do
    if first \= "_" then return .false
  end
  do i = 2 to name~length
    ch = name~substr(i, 1)
    if \ch~datatype("A") then do
      if \ch~datatype("N") then do
        if ch \= "_" then return .false
      end
    end
  end
  return .true
::method shellQuote private
  use arg value
  text = value~string
  text = text~changeStr("'", "'\''")
  return "'" || text || "'"
::method temporaryPath private
  use arg kind
  do attempt = 1 to 50
    timestamp = .DateTime~new~string
    timestamp = timestamp~changeStr("-", "")
    timestamp = timestamp~changeStr(":", "")
    timestamp = timestamp~changeStr("T", "_")
    timestamp = timestamp~changeStr(".", "")
    path = "/tmp/oorexx_db_" || kind || "_" || timestamp || "_" || random(100000, 999999)
    address system "set -C; : > " || self~shellQuote(path) || " 2>/dev/null"
    if rc = 0 then return path
  end
  return ""
::method writeTextFile private
  use arg path, text
  if path = "" then return .Error~INPUTFAILED
  stream = .stream~new(path)
  openStatus = stream~open("write replace")
  if openStatus \= "READY:" then return .Error~INPUTFAILED
  stream~charout(text)
  stream~close
  return .Error~SUCCESS
::method readTextFile private
  use arg path
  stream = .stream~new(path)
  if stream~open("read") \= "READY:" then return ""
  text = stream~charin(, stream~chars)
  stream~close
  return text
::method deleteFile private
  use arg path
  address system "rm -f " || self~shellQuote(path)
  return .Error~SUCCESS

::class DatabaseCommandResult public
::method init
  expose status error rc stdout stderr command terminationReason executionContext
  use arg rc = 0, stdout = "", stderr = "", command = .nil, terminationReason = "", executionContext = .nil
  if rc = 0 then do
    status = .Error~SUCCESS
    error = .Error~SUCCESS
  end
  else do
    status = .Error~FAILED
    error = .Error~COMMANDFAILED
  end
::attribute status get
::attribute error get
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute command get
::attribute terminationReason get
::attribute executionContext get
::method setExecutionContext
  expose executionContext
  use arg newContext
  executionContext = newContext
  return self
::method evidence
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("EVIDENCE") then return executionContext~evidence
  return .nil
::method provenance
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("PROVENANCE") then return executionContext~provenance
  return executionContext
::method notExecuted class
  use arg command, error = .nil
  if error == .nil then error = .Error~INVALIDPLAN
  commandResult = self~new(0, "", "", command, "NOTEXECUTED")
  commandResult~setStatus(.Error~NOTEXECUTED, error)
  return commandResult
::method setStatus
  expose status error
  use arg newStatus, newError
  status = newStatus
  error = newError
  return self
::method executionError class
  use arg command, error = .nil
  if error == .nil then error = .Error~EXECUTIONFAILED
  commandResult = self~new(1, "", "", command, "PROCESS")
  commandResult~setStatus(.Error~FAILED, error)
  return commandResult

::class DatabaseResult public
::method init
  expose status error success warnings executionContext transactionId operationId operationSequence
  use arg status = .nil, error = .nil, executionContext = .nil
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  success = (status = .Error~SUCCESS)
  warnings = .array~new
  transactionId = ""
  operationId = ""
  operationSequence = 0
::attribute status get
::attribute error get
::attribute success get
::attribute warnings get
::attribute executionContext get
::attribute transactionId get
::attribute operationId get
::attribute operationSequence get
::method setOperationIdentity
  expose transactionId operationId operationSequence
  use arg newTransactionId, newOperationId, newOperationSequence = 0
  transactionId = newTransactionId
  operationId = newOperationId
  operationSequence = newOperationSequence
  return self
::method setExecutionContext
  expose executionContext
  use arg newContext
  executionContext = newContext
  return self
::method evidence
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("EVIDENCE") then return executionContext~evidence
  return .nil
::method provenance
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("PROVENANCE") then return executionContext~provenance
  return executionContext

::class DatabaseType public
::constant NULL       "NULL"
::constant BOOLEAN    "BOOLEAN"
::constant INTEGER    "INTEGER"
::constant DECIMAL    "DECIMAL"
::constant VARCHAR    "VARCHAR"
::constant DATE       "DATE"
::constant DATETIME   "DATETIME"
::constant BLOB       "BLOB"
::constant GEOMETRY   "GEOMETRY"
::constant UNKNOWN    "UNKNOWN"
::method fromPostgreSQL class
  use arg typeName
  t = typeName~lower
  if t = "smallint" then return self~INTEGER
  if t = "integer" then return self~INTEGER
  if t = "bigint" then return self~INTEGER
  if t = "numeric" then return self~DECIMAL
  if t = "decimal" then return self~DECIMAL
  if t = "real" then return self~DECIMAL
  if t = "double precision" then return self~DECIMAL
  if t = "boolean" then return self~BOOLEAN
  if t = "date" then return self~DATE
  if t = "timestamp without time zone" then return self~DATETIME
  if t = "timestamp with time zone" then return self~DATETIME
  if t = "character varying" then return self~VARCHAR
  if t = "character" then return self~VARCHAR
  if t = "text" then return self~VARCHAR
  if t = "bytea" then return self~BLOB
  if t = "geometry" then return self~GEOMETRY
  if t = "geography" then return self~GEOMETRY
  return self~UNKNOWN
::method fromMySQL class
  use arg typeName
  t = typeName~lower
  if t~pos("tinyint(1)") = 1 then return self~BOOLEAN
  if t~pos("tinyint") = 1 then return self~INTEGER
  if t~pos("smallint") = 1 then return self~INTEGER
  if t~pos("mediumint") = 1 then return self~INTEGER
  if t~pos("int") = 1 then return self~INTEGER
  if t~pos("bigint") = 1 then return self~INTEGER
  if t~pos("decimal") = 1 then return self~DECIMAL
  if t~pos("numeric") = 1 then return self~DECIMAL
  if t~pos("float") = 1 then return self~DECIMAL
  if t~pos("double") = 1 then return self~DECIMAL
  if t = "date" then return self~DATE
  if t~pos("datetime") = 1 then return self~DATETIME
  if t~pos("timestamp") = 1 then return self~DATETIME
  if t~pos("varchar") = 1 then return self~VARCHAR
  if t~pos("char") = 1 then return self~VARCHAR
  if t~pos("text") > 0 then return self~VARCHAR
  if t~pos("blob") > 0 then return self~BLOB
  if t~pos("binary") > 0 then return self~BLOB
  if t = "geometry" then return self~GEOMETRY
  if t = "point" then return self~GEOMETRY
  if t = "linestring" then return self~GEOMETRY
  if t = "polygon" then return self~GEOMETRY
  if t = "multipoint" then return self~GEOMETRY
  if t = "multilinestring" then return self~GEOMETRY
  if t = "multipolygon" then return self~GEOMETRY
  if t = "geometrycollection" then return self~GEOMETRY
  return self~UNKNOWN

::class DatabaseIsolation public
::constant DEFAULT          "DEFAULT"
::constant READUNCOMMITTED  "READUNCOMMITTED"
::constant READCOMMITTED    "READCOMMITTED"
::constant REPEATABLEREAD   "REPEATABLEREAD"
::constant SERIALIZABLE     "SERIALIZABLE"

::class DatabaseAccessMode public
::constant DEFAULT    "DEFAULT"
::constant READONLY   "READONLY"
::constant READWRITE  "READWRITE"

::class DatabaseRetryPolicy public
::method init
  expose maxAttempts
  use arg maxAttempts = 1
  if \maxAttempts~datatype("W") then maxAttempts = 1
  if maxAttempts < 1 then maxAttempts = 1
::attribute maxAttempts get
::method isRetryable
  use arg error
  if error = .Error~DEADLOCK then return .true
  if error = .Error~SERIALIZATIONFAILURE then return .true
  if error = .Error~LOCKTIMEOUT then return .true
  return .false

::class DatabaseCapability public
::constant TRANSACTIONS                "TRANSACTIONS"
::constant SAVEPOINTS                  "SAVEPOINTS"
::constant PREPAREDSTATEMENTS          "PREPAREDSTATEMENTS"
::constant PREPAREDBATCH               "PREPAREDBATCH"
::constant TYPEDRESULTS                "TYPEDRESULTS"
::constant RESULTMETADATA              "RESULTMETADATA"
::constant RESULTSCHEMA                "RESULTSCHEMA"
::constant MUTATIONRESULTS             "MUTATIONRESULTS"
::constant PREPAREDMUTATIONRESULTS     "PREPAREDMUTATIONRESULTS"
::constant GENERATEDKEYS               "GENERATEDKEYS"
::constant TRANSACTIONRETRY            "TRANSACTIONRETRY"
::constant TRANSACTIONREADONLY         "TRANSACTIONREADONLY"
::constant TRANSACTIONISOLATION        "TRANSACTIONISOLATION"
::constant TRANSACTIONTIMEOUT          "TRANSACTIONTIMEOUT"
::constant SPATIALTYPES                "SPATIALTYPES"
::constant SPATIALFUNCTIONS            "SPATIALFUNCTIONS"
::constant TABLEDISCOVERY              "TABLEDISCOVERY"

::class DatabaseCapabilities public
::method init
  expose values
  values = .set~new
::method add
  expose values
  use arg capability
  values~put(capability)
  return self
::method supports
  expose values
  use arg capability
  return values~hasIndex(capability)
::method all
  expose values
  capabilityList = values~makeArray
  return capabilityList

::class DatabaseEndpointCapabilities public
::method init
  expose base disabled enabled
  use arg base
  if base == .nil then base = .DatabaseCapabilities~new
  disabled = .set~new
  enabled = .set~new
::attribute base get
::method disable
  expose disabled enabled
  use arg capability
  enabled~remove(capability)
  disabled~put(capability)
  return self
::method enable
  expose disabled enabled
  use arg capability
  disabled~remove(capability)
  enabled~put(capability)
  return self
::method supports
  expose base disabled enabled
  use arg capability
  if disabled~hasIndex(capability) then return .false
  if enabled~hasIndex(capability) then return .true
  return base~supports(capability)
::method all
  expose base enabled
  capabilityList = .array~new
  seen = .set~new
  baseCapabilities = base~all
  do capability over baseCapabilities
    if self~supports(capability) then do
      capabilityList~append(capability)
      seen~put(capability)
    end
  end
  enabledCapabilities = enabled~makeArray
  do capability over enabledCapabilities
    if \seen~hasIndex(capability) then capabilityList~append(capability)
  end
  return capabilityList

::class DatabaseEndpointIdentity public
::method init
  expose protocol product version rawVersion
  use arg protocol = "", product = "", version = "", rawVersion = ""
::attribute protocol get
::attribute product get
::attribute version get
::attribute rawVersion get
::method string
  expose protocol product version
  return protocol || ":" || product || ":" || version

::class DatabaseSpatialEncoding public
::constant OPAQUE       "OPAQUE"
::constant WKT          "WKT"
::constant WKBHEX       "WKBHEX"
::constant EWKBHEX      "EWKBHEX"
::constant GPKGBLOBHEX  "GPKGBLOBHEX"

::class DatabaseGeometryValue public subclass DatabaseValue
::method init
  expose geometryType srid encoding
  use arg raw = "", geometryType = "", srid = 0, encoding = .nil, value = .nil
  if encoding == .nil then encoding = .DatabaseSpatialEncoding~OPAQUE
  self~init:super(raw, .DatabaseType~GEOMETRY, value, .false)
::attribute geometryType get
::attribute srid get
::attribute encoding get
::method string
  expose geometryType srid encoding
  type = geometryType
  if type = "" then type = .DatabaseType~GEOMETRY
  return type || "(SRID=" || srid || "," || encoding || "=" || self~raw~left(24) || "...)"
::method fromText class
  use arg text, geometryType = "", srid = 0, encoding = .nil
  if text == .nil then return .DatabaseValue~new("", .DatabaseType~NULL, .nil, .true)
  return self~new(text, geometryType, srid, encoding, text)

::class DatabaseValue public
::method init
  expose raw value typeName isNull
  use arg raw = "", typeName = .nil, value = .nil, isNull = .false
  if typeName == .nil then typeName = .DatabaseType~UNKNOWN
::attribute raw get
::attribute value get
::attribute typeName get
::attribute isNull get
::method string
  expose raw isNull
  if isNull then return "NULL"
  return raw
::method fromText class
  use arg text, requestedType = .nil
  if requestedType == .nil then requestedType = .DatabaseType~UNKNOWN
  if text == .nil then return self~new("", .DatabaseType~NULL, .nil, .true)
  if requestedType = .DatabaseType~NULL then return self~new("", .DatabaseType~NULL, .nil, .true)
  select
    when requestedType = .DatabaseType~INTEGER then do
      if \text~datatype("W") then return self~new(text, .DatabaseType~UNKNOWN, text, .false)
      return self~new(text, requestedType, text, .false)
    end
    when requestedType = .DatabaseType~DECIMAL then do
      if \text~datatype("N") then return self~new(text, .DatabaseType~UNKNOWN, text, .false)
      return self~new(text, requestedType, text, .false)
    end
    when requestedType = .DatabaseType~BOOLEAN then do
      lowerText = text~lower
      if lowerText = "true" then return self~new(text, requestedType, .true, .false)
      if lowerText = "t" then return self~new(text, requestedType, .true, .false)
      if lowerText = "1" then return self~new(text, requestedType, .true, .false)
      if lowerText = "false" then return self~new(text, requestedType, .false, .false)
      if lowerText = "f" then return self~new(text, requestedType, .false, .false)
      if lowerText = "0" then return self~new(text, requestedType, .false, .false)
      return self~new(text, .DatabaseType~UNKNOWN, text, .false)
    end
    when requestedType = .DatabaseType~GEOMETRY then return .DatabaseGeometryValue~fromText(text)
    otherwise return self~new(text, requestedType, text, .false)
  end

::class DatabaseColumnMetadata public
::method init
  expose name engineType databaseType nullable ordinal geometryType srid
  use arg name = "", engineType = "", databaseType = .nil, nullable = .true, ordinal = 0, geometryType = "", srid = 0
  if databaseType == .nil then databaseType = .DatabaseType~UNKNOWN
::attribute name get
::method capabilities
  caps = .DatabaseCapabilities~new
  caps~add(.DatabaseCapability~TRANSACTIONS)
  caps~add(.DatabaseCapability~SAVEPOINTS)
  caps~add(.DatabaseCapability~PREPAREDSTATEMENTS)
  caps~add(.DatabaseCapability~PREPAREDBATCH)
  caps~add(.DatabaseCapability~TYPEDRESULTS)
  caps~add(.DatabaseCapability~RESULTMETADATA)
  caps~add(.DatabaseCapability~RESULTSCHEMA)
  caps~add(.DatabaseCapability~MUTATIONRESULTS)
  caps~add(.DatabaseCapability~PREPAREDMUTATIONRESULTS)
  caps~add(.DatabaseCapability~TRANSACTIONRETRY)
  caps~add(.DatabaseCapability~TRANSACTIONREADONLY)
  caps~add(.DatabaseCapability~TRANSACTIONISOLATION)
  caps~add(.DatabaseCapability~TRANSACTIONTIMEOUT)
  return caps
::attribute engineType get
::attribute databaseType get
::attribute nullable get
::attribute ordinal get
::attribute geometryType get
::attribute srid get

::class DatabaseResultMetadata public
::method init
  expose columns
  columns = .array~new
::attribute columns get
::method add
  expose columns
  use arg column
  columns~append(column)
  return column
::method types
  expose columns
  resultTypes = .array~new
  do column over columns
    resultTypes~append(column~databaseType)
  end
  return resultTypes

::class DatabaseResultSchema public
::method init
  expose columns
  columns = .array~new
::attribute columns get
::method add
  expose columns
  use arg name, databaseType = .nil
  if databaseType == .nil then databaseType = .DatabaseType~UNKNOWN
  column = .DatabaseColumnMetadata~new(name, "", databaseType, .true, columns~items + 1)
  columns~append(column)
  return self
::method types
  expose columns
  resultTypes = .array~new
  do column over columns
    resultTypes~append(column~databaseType)
  end
  return resultTypes

::class DatabaseRow public
::method init
  expose values
  values = .directory~new
::attribute values get
::method put
  expose values
  use arg name, value
  if \value~isA(.DatabaseValue) then value = .DatabaseValue~fromText(value, .DatabaseType~VARCHAR)
  values[name] = value
  return value
::method at
  expose values
  use arg name
  if values~hasIndex(name) then return values[name]
  return .nil
::method rawAt
  expose values
  use arg name
  if \values~hasIndex(name) then return .nil
  return values[name]~raw
::method valueAt
  expose values
  use arg name
  if \values~hasIndex(name) then return .nil
  return values[name]~value

::class DatabaseQueryResult public subclass DatabaseResult
::method init
  expose columns columnTypes rows rowCount status error success warnings
  use arg status = .nil, error = .nil, columns = .nil, rows = .nil, columnTypes = .nil
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~init:super(status, error)
  if columns == .nil then columns = .array~new
  if rows == .nil then rows = .array~new
  if columnTypes == .nil then columnTypes = .array~new
  rowCount = rows~items
::attribute columns get
::attribute columnTypes get
::attribute rows get
::attribute rowCount get

::class DatabaseGeneratedKeyRequest public
::method init
  expose columnName
  use arg columnName = ""
::attribute columnName get

::class DatabaseMutationResult public subclass DatabaseResult
::method init
  expose affectedRows generatedKey status error success warnings
  use arg status = .nil, error = .nil, affectedRows = 0, generatedKey = .nil
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~init:super(status, error)
::attribute affectedRows get
::attribute generatedKey get

::class DatabaseStatementResult public subclass DatabaseResult
::method init
  expose operation rows rowCount affectedRows status error success warnings
  use arg operation = .nil, status = .nil, rows = .nil, error = .nil
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~init:super(status, error)
  if rows == .nil then rows = .array~new
  rowCount = rows~items
  affectedRows = 0
::attribute operation get
::attribute rows get
::attribute rowCount
::attribute affectedRows

::class DatabaseExecutionAttempt public
::method init
  expose attemptNumber status error commandResult retryable executionContext transactionId attemptId
  use arg attemptNumber = 0, status = .nil, error = .nil, commandResult = .nil, retryable = .false, executionContext = .nil, transactionId = ""
  if status == .nil then status = .Error~UNKNOWN
  if error == .nil then error = .Error~UNKNOWN
  attemptId = transactionId || ":attempt:" || attemptNumber
::attribute attemptNumber get
::attribute attemptId get
::attribute transactionId get
::attribute status get
::attribute error get
::attribute commandResult get
::attribute retryable get
::attribute executionContext get
::method evidence
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("EVIDENCE") then return executionContext~evidence
  return .nil
::method provenance
  expose executionContext
  if executionContext == .nil then return .nil
  if executionContext~hasMethod("PROVENANCE") then return executionContext~provenance
  return executionContext

::class DatabaseTransactionResult public subclass DatabaseResult
::method init
  expose outcome status error commandResult operationCount attemptCount mutationResults executionContext success warnings attempts transactionIdentity manifest
  use arg outcome = .nil, error = .nil, commandResult = .nil, operationCount = 0, attemptCount = 1, mutationResults = .nil, executionContext = .nil, attempts = .nil, transactionIdentity = .nil, manifest = .nil
  if outcome == .nil then outcome = .Error~UNKNOWN
  if error == .nil then error = .Error~SUCCESS
  if outcome = .Error~COMMITTED then status = .Error~SUCCESS
  else status = outcome
  if mutationResults == .nil then mutationResults = .array~new
  if attempts == .nil then attempts = .array~new
  self~init:super(status, error, executionContext)
::attribute outcome get
::attribute commandResult get
::attribute operationCount get
::attribute attemptCount get
::attribute mutationResults get
::attribute attempts get
::attribute transactionIdentity get
::attribute manifest get
::method transactionId
  expose transactionIdentity
  if transactionIdentity == .nil then return ""
  return transactionIdentity~id
::method operationIds
  expose transactionIdentity operationCount
  ids = .array~new
  if transactionIdentity == .nil then return ids
  do i = 1 to operationCount
    ids~append(transactionIdentity~id || ":op:" || i)
  end
  return ids
::method lastAttempt
  expose attempts
  if attempts~items = 0 then return .nil
  return attempts[attempts~items]
::method committed
  expose outcome
  return outcome = .Error~COMMITTED
::method rolledBack
  expose outcome
  return outcome = .Error~ROLLEDBACK
::method retried
  expose attemptCount
  return attemptCount > 1

::class DatabaseResultParser public
::method init
  expose engineName
  use arg engineName = "generic"
::attribute engineName get
::method parse
  use arg commandResult
  if commandResult~status = .Error~SUCCESS then return .DatabaseResult~new(.Error~SUCCESS, .Error~SUCCESS)
  return .DatabaseResult~new(.Error~FAILED, self~classifyError(commandResult))
::method classifyError
  use arg commandResult
  return commandResult~error
::method parseMutationResults
  use arg commandResult
  return .array~new
::method parseQueryFrames
  use arg commandResult
  frameResults = .array~new
  if commandResult~status \= .Error~SUCCESS then do
    frameResults~append(.DatabaseQueryResult~new(.Error~FAILED, self~classifyError(commandResult)))
    return frameResults
  end
  lines = commandResult~stdout~makeArray(.endOfLine)
  frameNumber = 1
  inFrame = .false
  frameLines = .array~new
  do i = 1 to lines~items
    line = lines[i]
    beginMarker = "__OOREXX_RESULT_BEGIN_" || frameNumber || "__"
    endMarker = "__OOREXX_RESULT_END_" || frameNumber || "__"
    if \inFrame then do
      if line = beginMarker then do
        inFrame = .true
        frameLines = .array~new
      end
    end
    else do
      if line = endMarker then do
        if frameLines~items > 0 then do
          if frameLines[frameLines~items] = "__oorexx_frame" then frameLines~delete(frameLines~items)
        end
        frameResults~append(self~parseTabularLines(frameLines))
        frameNumber += 1
        inFrame = .false
        frameLines = .array~new
      end
      else frameLines~append(line)
    end
  end
  return frameResults
::method parseTabularLines
  use arg lines, columnTypes = .nil
  columns = .array~new
  rows = .array~new
  if columnTypes == .nil then columnTypes = .array~new
  if lines~items = 0 then return .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows, columnTypes)
  header = lines[1]~makeArray("09"x)
  do item over header
    columns~append(item)
  end
  do i = 2 to lines~items
    if lines[i] = "" then iterate
    fields = lines[i]~makeArray("09"x)
    row = .DatabaseRow~new
    do c = 1 to columns~items
      fieldText = ""
      if c <= fields~items then fieldText = fields[c]
      requestedType = .DatabaseType~UNKNOWN
      if c <= columnTypes~items then requestedType = columnTypes[c]
      row~put(columns[c], .DatabaseValue~fromText(fieldText, requestedType))
    end
    rows~append(row)
  end
  return .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows, columnTypes)

/* Client stderr classification is intentionally provisional.
 * Prefer structured/native error codes when the client surface exposes them
 * reliably across supported versions and locales.
 */
::class PostgreSQLResultParser public subclass DatabaseResultParser
::method init
  self~init:super("postgresql")
::method parseMutationResults
  use arg commandResult
  results = .array~new
  if commandResult~status \= .Error~SUCCESS then return results
  lines = commandResult~stdout~makeArray(.endOfLine)
  pendingKey = .nil
  expectKey = .false
  do line over lines
    if line = "__oorexx_generated_key" then do
      expectKey = .true
      iterate
    end
    if expectKey then do
      pendingKey = line
      expectKey = .false
      iterate
    end
    upper = line~upper
    affected = .nil
    if upper~pos("INSERT ") = 1 then do
      if line~words >= 3 then affected = line~word(3)
    end
    else if upper~pos("UPDATE ") = 1 then do
      if line~words >= 2 then affected = line~word(2)
    end
    else if upper~pos("DELETE ") = 1 then do
      if line~words >= 2 then affected = line~word(2)
    end
    if affected \== .nil then do
      if affected~datatype("W") then do
        results~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, affected, pendingKey))
        pendingKey = .nil
      end
    end
  end
  return results
::method classifyError
  use arg commandResult
  stderr = commandResult~stderr~lower
  if commandResult~terminationReason = "TIMEOUT" then return .Error~TIMEOUT
  if stderr~pos("deadlock detected") > 0 then return .Error~DEADLOCK
  if stderr~pos("could not serialize access") > 0 then return .Error~SERIALIZATIONFAILURE
  if stderr~pos("serialization failure") > 0 then return .Error~SERIALIZATIONFAILURE
  if stderr~pos("canceling statement due to lock timeout") > 0 then return .Error~LOCKTIMEOUT
  if stderr~pos("connection refused") > 0 then return .Error~CONNECTIONFAILED
  if stderr~pos("no such file or directory") > 0 then do
    if stderr~pos(".s.pgsql.") > 0 then return .Error~CONNECTIONFAILED
  end
  if stderr~pos("could not connect to server") > 0 then return .Error~CONNECTIONFAILED
  if stderr~pos("password authentication failed") > 0 then return .Error~AUTHENTICATIONFAILED
  if stderr~pos("peer authentication failed") > 0 then return .Error~AUTHENTICATIONFAILED
  if stderr~pos("no pg_hba.conf entry") > 0 then return .Error~AUTHENTICATIONFAILED
  if stderr~pos("permission denied") > 0 then return .Error~PERMISSIONDENIED
  if stderr~pos("database") > 0 then do
    if stderr~pos("does not exist") > 0 then return .Error~DATABASENOTFOUND
  end
  if stderr~pos("syntax error") > 0 then return .Error~SYNTAXERROR
  if stderr~pos("duplicate key value violates unique constraint") > 0 then return .Error~DUPLICATEKEY
  if stderr~pos("violates unique constraint") > 0 then return .Error~CONSTRAINTVIOLATION
  if stderr~pos("violates foreign key constraint") > 0 then return .Error~CONSTRAINTVIOLATION
  if stderr~pos("violates not-null constraint") > 0 then return .Error~CONSTRAINTVIOLATION
  if stderr~pos("check constraint") > 0 then return .Error~CONSTRAINTVIOLATION
  return .Error~DATABASEERROR

/* MariaDB/MySQL client text differs across versions/locales; keep this
 * classifier as a compatibility layer, not the final authority model.
 */
::class MySQLResultParser public subclass DatabaseResultParser
::method init
  self~init:super("mysql")
::method parseMutationResults
  use arg commandResult
  results = .array~new
  if commandResult~status \= .Error~SUCCESS then return results
  lines = commandResult~stdout~makeArray(.endOfLine)
  countPrefix = "__OOREXX_MUTATION_COUNT__:"
  resultPrefix = "__OOREXX_MUTATION_RESULT__:"
  do line over lines
    if line~pos(resultPrefix) = 1 then do
      payload = line~substr(resultPrefix~length + 1)
      splitAt = payload~pos(":")
      if splitAt > 0 then do
        countText = payload~left(splitAt - 1)
        keyText = payload~substr(splitAt + 1)
        if countText~datatype("W") then results~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, countText, keyText))
      end
    end
    else if line~pos(countPrefix) = 1 then do
      countText = line~substr(countPrefix~length + 1)
      if countText~datatype("W") then results~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, countText))
    end
  end
  return results
::method classifyError
  use arg commandResult
  stderr = commandResult~stderr~lower
  if commandResult~terminationReason = "TIMEOUT" then return .Error~TIMEOUT
  if stderr~pos("error 1213") > 0 then return .Error~DEADLOCK
  if stderr~pos("deadlock found") > 0 then return .Error~DEADLOCK
  if stderr~pos("error 1205") > 0 then return .Error~LOCKTIMEOUT
  if stderr~pos("lock wait timeout exceeded") > 0 then return .Error~LOCKTIMEOUT
  if stderr~pos("serialization failure") > 0 then return .Error~SERIALIZATIONFAILURE
  if stderr~pos("can't connect") > 0 then return .Error~CONNECTIONFAILED
  if stderr~pos("can't connect to local server") > 0 then return .Error~CONNECTIONFAILED
  if stderr~pos("connection refused") > 0 then return .Error~CONNECTIONFAILED
  if stderr~pos("error 1045") > 0 then return .Error~AUTHENTICATIONFAILED
  if stderr~pos("access denied for user") > 0 then do
    if stderr~pos("to database") > 0 then return .Error~PERMISSIONDENIED
    return .Error~AUTHENTICATIONFAILED
  end
  if stderr~pos("unknown database") > 0 then return .Error~DATABASENOTFOUND
  if stderr~pos("you have an error in your sql syntax") > 0 then return .Error~SYNTAXERROR
  if stderr~pos("error 1062") > 0 then return .Error~DUPLICATEKEY
  if stderr~pos("duplicate entry") > 0 then return .Error~DUPLICATEKEY
  if stderr~pos("cannot add or update a child row") > 0 then return .Error~CONSTRAINTVIOLATION
  if stderr~pos("cannot delete or update a parent row") > 0 then return .Error~CONSTRAINTVIOLATION
  if stderr~pos("constraint fails") > 0 then return .Error~CONSTRAINTVIOLATION
  if stderr~pos("doesn't exist") > 0 then return .Error~DATABASEERROR
  return .Error~DATABASEERROR
