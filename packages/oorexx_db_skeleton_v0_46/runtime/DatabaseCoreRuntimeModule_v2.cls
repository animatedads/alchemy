::class DatabaseCoreRuntimeModule public
::attribute context get
::attribute starts get
::attribute quiesces get
::attribute stops get

::method init
  expose context starts quiesces stops
  context = .nil
  starts = 0
  quiesces = 0
  stops = 0

::method runtimePrepare
  expose context
  use arg context
  return .true

::method runtimeSelfTest
  db = self~newDatabase
  tx = db~transaction
  tx~execute("SELECT 1")
  plan = tx~prepare
  return plan~validate~status = .Error~SUCCESS

::method runtimeStart
  expose starts
  starts += 1
  return .true

::method runtimeQuiesce
  expose quiesces
  quiesces += 1
  return .true

::method runtimeStop
  expose stops
  stops += 1
  return .true

::method generationLabel
  return "DBCORE-V2"

::method newDatabase
  conn = .DatabaseConnection~new("runtime.local", 5432, "runtime_db", "runtime_user", .nil, "postgresql")
  return .Database~new(conn)

::method beginTransaction
  db = self~newDatabase
  return db~transaction

::method beginTransactionWithEvidence
  use arg evidence, locator = ""
  db = self~newDatabase
  context = .DatabaseExecutionContext~new(evidence, locator)
  return db~transaction(context)

::method executionContextClass
  return .DatabaseExecutionContext

::method coreClass
  return .Database

::method errorClass
  return .Error

::method operationTypeClass
  return .DatabaseOperationType

::requires "database_core.cls"
