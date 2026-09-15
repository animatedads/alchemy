/* NoSQLServer v0.77 - Alchemy Object house-base integration for engine/facade objects */

::requires "csvStream.cls"
::requires "yaml.cls"
::requires "json.cls"
::requires "AlchemyObject.cls"

::class Error public
::constant SUCCESS          "SUCCESS"
::constant NOTEXECUTED      "NOTEXECUTED"
::constant FAILED           "FAILED"
::constant INVALIDSTATE     "INVALIDSTATE"
::constant INVALIDARGUMENT  "INVALIDARGUMENT"
::constant NOTFOUND         "NOTFOUND"
::constant ALREADYEXISTS    "ALREADYEXISTS"
::constant SCHEMAERROR      "SCHEMAERROR"
::constant STORAGEERROR     "STORAGEERROR"
::constant SQLERROR         "SQLERROR"
::constant SQLPARSEERROR    "SQLPARSEERROR"
::constant SQLUNSUPPORTED   "SQLUNSUPPORTED"
::constant CONSTRAINT       "CONSTRAINT"
::constant TYPEERROR        "TYPEERROR"
::constant UNKNOWN          "UNKNOWN"
::constant COMMITTED        "COMMITTED"
::constant ROLLEDBACK       "ROLLEDBACK"
::constant UNSUPPORTED      "SQLUNSUPPORTED"
::constant DATABASEERROR    "SQLERROR"
::constant TRANSACTIONFAILED "TRANSACTIONFAILED"
::constant STATEMENTFAILED  "SQLERROR"
::constant PREPAREFAILED    "PREPAREFAILED"
::constant PARAMETERCOUNT   "PARAMETERCOUNT"
::constant DUPLICATEPREPARED "DUPLICATEPREPARED"
::constant INVALIDSAVEPOINT "INVALIDSAVEPOINT"
::constant INVALIDOPERATION "INVALIDOPERATION"
::constant SYNTAXERROR      "SQLPARSEERROR"
::constant CONSTRAINTVIOLATION "CONSTRAINT"
::constant DUPLICATEKEY     "CONSTRAINT"
::constant DATABASENOTFOUND "NOTFOUND"
::constant CONNECTIONFAILED "CONNECTIONFAILED"
::constant PERMISSIONDENIED "PERMISSIONDENIED"
::constant TIMEOUT          "TIMEOUT"
::constant INVALIDPARAMETER "TYPEERROR"
::constant AUTHENTICATIONFAILED "AUTHENTICATIONFAILED"
::constant DATABASEUNAVAILABLE "DATABASEUNAVAILABLE"
::constant INVALIDCONNECTION "INVALIDCONNECTION"
::constant DEADLOCK "DEADLOCK"
::constant SERIALIZATIONFAILURE "SERIALIZATIONFAILURE"
::constant LOCKTIMEOUT "LOCKTIMEOUT"

::class NoSQLServerBuild public
::constant PRODUCT       "NoSQLServer"
::constant RELEASE       "0.77"
::constant SQLLEVEL      "0.77"
::constant ENGINE        "FILE"
::constant STORAGE       "YAML+DELIMITED"

/*
 * House-object integration.
 *
 * Data/value objects remain deliberately lightweight. Stateful engines,
 * runtime/facade objects and transaction/core adapters inherit AlchemyObject
 * so identity, lifecycle evidence, contracts, telemetry and sealed
 * introspection are available at the service boundary.
 *
 * Security/sealing remain host-configured: existing constructor calls require
 * no new arguments and preserve classic NoSQLServer behaviour.
 */
::class NoSQLAlchemyObject subclass AlchemyObject public
::constant ALCHEMY_OBJECTS_VERSION "0.4.4"

::method initNoSQLAlchemy protected
  expose nosqlAlchemySealer nosqlAlchemyAuthority
  use arg role, sealer = .nil, authority = .nil
  nosqlAlchemySealer = sealer
  nosqlAlchemyAuthority = authority
  role = role~string~translate
  metadata = .directory~new
  metadata["PURPOSE"] = "NoSQLServer " || role
  metadata["PRODUCT"] = .NoSQLServerBuild~PRODUCT
  metadata["PACKAGE_VERSION"] = .NoSQLServerBuild~RELEASE
  metadata["ROLE"] = role
  self~initAlchemy(metadata, sealer, authority)
  self~registerExternalRequirement("library", "alchemy_objects", self~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerInstrumentationPoint("NOSQL." || role || ".USE", "NoSQLServer service-boundary usage", .true, "COLLAPSE", "INTERNAL")
  return self

::method noSQLAlchemySealer protected
  expose nosqlAlchemySealer
  return nosqlAlchemySealer

::method noSQLAlchemyAuthority protected
  expose nosqlAlchemyAuthority
  return nosqlAlchemyAuthority

::method registerNoSQLMethod protected
  use arg name, purpose, sideEffects = "UNKNOWN", securitySensitivity = "NORMAL", authorityEffect = "NONE"
  self~registerMethodContract(name, purpose, .array~new, "ANY", .false, "AUTO", "CUSTOMER", securitySensitivity, sideEffects, authorityEffect)
  return self


/*
 * Optional Unicode text support.
 *
 * NoSQLServer remains classic-string first.  TUTOR is deliberately not a
 * ::REQUIRES dependency: applications opt in by calling
 *   .NoSQLUnicodeSupport~enable(tutorRoot)
 * and by declaring textMode: UNICODE on the relevant VARCHAR/TEXT columns.
 *
 * TUTOR Text values validate UTF-8, normalize to NFC and expose grapheme-aware
 * length/substr/case operations.  Ordering remains deterministic Unicode
 * code-point/UTF-8 order; locale collation is not claimed.
 */
::class NoSQLUnicodeSupport public

::method available class
  if \.local~hasIndex("TEXT") then return .false
  if \.local~hasIndex("CODEPOINTS") then return .false
  return .true

::method enable class
  use arg tutorRoot
  if self~available then return .true
  if tutorRoot == .nil then raise syntax 93.900 additional("Unicode support requires a TUTOR root")
  root = tutorRoot~string~strip
  if root = "" then raise syntax 93.900 additional("Unicode support requires a TUTOR root")

  unicodeFile = root || "/bin/Unicode.cls"
  if stream(unicodeFile, "c", "query exists") = "" then do
    unicodeFile = root || "/Unicode.cls"
    if stream(unicodeFile, "c", "query exists") = "" then ,
      raise syntax 93.900 additional("TUTOR Unicode.cls not found under:" root)
  end

  call (unicodeFile)
  if \self~available then raise syntax 93.900 additional("TUTOR loaded without Text/Codepoints classes")
  return .true

::method require class
  if \self~available then raise syntax 93.900 additional("UNICODE text mode requires optional TUTOR support; call NoSQLUnicodeSupport~enable(tutorRoot)")
  return .true

::method isUnicodeValue class
  use arg value
  if value == .nil then return .false
  if \self~available then return .false
  if value~isA(.Text) then return .true
  if value~isA(.Graphemes) then return .true
  if value~isA(.Codepoints) then return .true
  return .false

::method text class
  use arg value
  self~require
  if value == .nil then return .nil
  if value~isA(.Text) then return value
  return .Text~new(value~string)

::method raw class
  use arg value
  if value == .nil then return .nil
  if self~isUnicodeValue(value) then return value~makeString
  return value~string

::method compare class
  use arg left, operator, right
  if left == .nil then return .false
  if right == .nil then return .false
  l = self~text(left)~makeString
  r = self~text(right)~makeString
  op = operator~string
  select
    when op = "=" then return l == r
    when op = "<>" then return l \== r
    when op = "!=" then return l \== r
    when op = "<" then return l < r
    when op = "<=" then return l <= r
    when op = ">" then return l > r
    when op = ">=" then return l >= r
    otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
  end

::method compareValues class
  use arg left, right
  l = self~text(left)~makeString
  r = self~text(right)~makeString
  if l < r then return -1
  if l > r then return 1
  return 0

::method characterLength class
  use arg value
  if value == .nil then return .nil
  if self~isUnicodeValue(value) then return value~length
  return value~string~length

::method octetLength class
  use arg value
  if value == .nil then return .nil
  return self~raw(value)~length

::class NoSQLServerVersionInfo public
::attribute product
::attribute release
::attribute engine
::attribute storage
::attribute storageFormatVersion
::attribute sqlLevel
::attribute runtimeVersion
::attribute runtimeLanguageLevel
::attribute platform
::attribute architecture
::attribute features

::method init
  use arg storageFormatVersion = 1
  self~product = .NoSQLServerBuild~PRODUCT
  self~release = .NoSQLServerBuild~RELEASE
  self~engine = .NoSQLServerBuild~ENGINE
  self~storage = .NoSQLServerBuild~STORAGE
  self~storageFormatVersion = storageFormatVersion
  self~sqlLevel = .NoSQLServerBuild~SQLLEVEL
  self~runtimeVersion = .rexxinfo~version
  self~runtimeLanguageLevel = .rexxinfo~languageLevel
  self~platform = .rexxinfo~platform
  self~architecture = .rexxinfo~architecture
  f = .array~new
  f~append("DDL")
  f~append("CRUD")
  f~append("PER_TABLE_DELIMITERS")
  f~append("ADAPTIVE_INDEXES")
  f~append("JOIN_MAPS")
  f~append("LEFT_JOIN")
  f~append("RIGHT_JOIN")
  f~append("FULL_OUTER_JOIN")
  f~append("UNION")
  f~append("INTERSECT")
  f~append("EXCEPT")
  f~append("CORRELATED_UPDATE")
  f~append("SUBQUERY_DELETE")
  f~append("CROSS_JOIN_SCALAR_FILTER")
  f~append("CAST_VARCHAR")
  f~append("WINDOW_RUNNING_AGGREGATE")
  f~append("WINDOW_RUNNING_SUM")
  f~append("WINDOW_RUNNING_COUNT")
  f~append("WINDOW_RUNNING_AVG")
  f~append("WINDOW_RUNNING_MIN_MAX")
  f~append("WINDOW_PARTITION_AGGREGATE")
  f~append("DERIVED_WINDOW_FILTER")
  f~append("WINDOW_LAG_LEAD")
  f~append("WINDOW_NTILE")
  f~append("AGGREGATE_FILTER")
  f~append("NAMED_WINDOWS")
  f~append("ORDER_BY_NULLS")
  f~append("INSERT_POSITIONAL_VALUES")
  f~append("INSERT_FLEXIBLE_WHITESPACE")
  f~append("SQL_FLEXIBLE_WHITESPACE")
  f~append("LIMIT_OFFSET")
  f~append("FETCH_WITH_TIES")
  f~append("DATABASE_EVENTS")
  f~append("MUTATION_EVENT_VETO")
  f~append("FOREIGN_KEYS")
  f~append("FOREIGN_KEY_RESTRICT")
  f~append("STAGED_MUTATION_GRAPH")
  f~append("FOREIGN_KEY_CASCADE")
  f~append("FOREIGN_KEY_SET_NULL")
  f~append("COMMIT_EVENTS")
  f~append("ORDER_BY_MERGESORT")
  f~append("ORDER_BY_TOP_N")
  f~append("VALUES_TABLE_SOURCE")
  f~append("APPEND_ONLY_SINGLE_INSERT")
  f~append("PHYSICAL_TOMBSTONES")
  f~append("APPEND_TOMBSTONE_UPDATE")
  f~append("TOMBSTONE_DELETE")
  f~append("TABLE_COMPACTION")
  f~append("RUNTIME_PK_CACHE")
  f~append("PK_PHYSICAL_LOCATOR")
  f~append("SQL_SINGLE_INSERT_APPEND")
  f~append("TABLE_READ_PORT")
  f~append("OBJECT_TABLE_SELECT")
  f~append("OBJECT_TABLE_JOIN")
  f~append("OBJECT_TABLE_AGGREGATE")
  f~append("OBJECT_TABLE_UPDATE")
  f~append("OBJECT_TABLE_INSERT")
  f~append("OBJECT_TABLE_DELETE")
  f~append("OBJECT_TABLE_SNAPSHOT")
  f~append("OBJECT_TABLE_EVENTS")
  f~append("FEDERATED_CATALOG")
  f~append("FILE_OBJECT_JOIN")
  f~append("WINDOW_ROW_NUMBER")
  f~append("WINDOW_RANK")
  f~append("WINDOW_DENSE_RANK")
  f~append("WINDOW_PARTITION_BY")
  f~append("WINDOW_ORDER_BY")
  f~append("RECURSIVE_CTE")
  f~append("PREDICATE_CONCAT_EXPRESSION")
  f~append("JOIN_ON_SCALAR_SUBQUERY")
  f~append("UPDATE_FROM")
  f~append("DELETE_USING")
  f~append("JOURNAL_UTC_TIMESTAMP")
  f~append("UNION_CORRESPONDING")
  f~append("SET_CORRESPONDING_BY")
  f~append("MULTI_CTE")
  f~append("NATURAL_JOIN")
  f~append("GROUPING_SETS")
  f~append("ROLLUP")
  f~append("CUBE")
  f~append("GEOPACKAGE_FEDERATION")
  f~append("SQLITE_NATIVE_BINARY_READ")
  f~append("SQLITE_NATIVE_RELATION_PROVIDER")
  f~append("GEOMETRY_TYPED_VALUE")
  f~append("SPATIAL_POINT_POLYGON_FUNCTIONS")
  f~append("ALCHEMY_OBJECT_BASE_0_4_4")
  f~append("ST_WITHIN_POINT_POLYGON")
  f~append("ST_INTERSECTS_POINT_POLYGON")
  f~append("ST_GEOMETRY_ACCESSORS")
  f~append("DATABASE_CORE_V034_GEOMETRY")
  f~append("DATABASE_CORE_V034_RELATIONAL_SOURCE")
  f~append("FEDERATED_DATABASE_FACADE")
  f~append("FEDERATED_PROVIDER_NEUTRAL_METADATA")
  f~append("FEDERATED_PROVIDER_NEUTRAL_MUTATION_DISPATCH")
  f~append("RECURSIVE_CTE_UNION_ALL")
  f~append("RECURSIVE_IN_SUBQUERY")
  f~append("AGGREGATES")
  f~append("GROUP_BY")
  f~append("PREDICATE_FUNCTIONS")
  f~append("MULTI_INNER_JOIN")
  f~append("INNER_JOIN_GENERAL_ON_PREDICATE")
  f~append("JSON_EXPLICIT_RELATION_PROJECTION")
  f~append("JSON_NESTED_PATH_PROJECTION")
  f~append("OPTIONAL_TUTOR_UNICODE")
  f~append("UNICODE_NFC_TEXT")
  f~append("UNICODE_GRAPHEME_FUNCTIONS")
  f~append("PROJECTION_ARITHMETIC")
  f~append("CASE_EXPRESSIONS")
  f~append("STRING_CONCAT")
  f~append("ORDER_BY_EXPRESSIONS")
  f~append("CORRELATED_SCALAR_SUBQUERY")
  f~append("SELECT_LIST_SUBQUERY")
  f~append("AGGREGATE_EXPRESSIONS")
  f~append("SELECT_SCALAR_FUNCTIONS")
  f~append("SELECT_CASE_EXPRESSIONS")
  f~append("HAVING")
  f~append("DERIVED_TABLES")
  f~append("AGGREGATE_JOIN_SOURCES")
  f~append("DERIVED_AGGREGATES")
  f~append("COALESCE")
  f~append("CORRELATED_AGGREGATE_SUBQUERY")
  f~append("EXISTS_SUBQUERY")
  f~append("NOT_EXISTS_SUBQUERY")
  f~append("CORRELATED_HAVING")
  f~append("NESTED_CORRELATION")
  f~append("POSITIONAL_UNION")
  f~append("DERIVED_UNION")
  f~append("ROW_VALUE_IN")
  f~append("QUANTIFIED_COMPARISON")
  f~append("GROUP_BY_EXPRESSIONS")
  f~append("COUNT_DISTINCT")
  f~append("ORDER_BY_PROJECTION_ALIAS")
  f~append("NESTED_CASE_SUBQUERY")
  f~append("ANY_SOME")
  f~append("ALL")
  f~append("LIKE")
  f~append("BETWEEN")
  f~append("TRANSACTIONS")
  f~append("TRANSACTION_RECOVERY")
  f~append("SAVEPOINTS")
  f~append("PREPARED_STATEMENTS")
  f~append("PREPARED_BATCH")
  f~append("TYPED_RESULTS")
  f~append("NOT_IN_SUBQUERY")
  f~append("NULLIF")
  f~append("AGGREGATE_ARITHMETIC")
  f~append("CORRELATED_DELETE_AGGREGATE")
  f~append("NESTED_CORRELATED_CASE")
  f~append("RESULT_METADATA")
  f~append("DATABASE_CORE_ADAPTER")
  f~append("RESULT_SCHEMA")
  f~append("MUTATION_RESULTS")
  f~append("PREPARED_MUTATION_RESULTS")
  f~append("TRANSACTION_RETRY")
  f~append("TRANSACTION_ISOLATION")
  f~append("TRANSACTION_READ_ONLY")
  self~features = f

::method supports
  use arg feature
  if feature == .nil then return .false
  wanted = feature~string
  do item over self~features
    if item~string~caselessEquals(wanted) then return .true
  end
  return .false

::method string
  return self~product || " " || self~release || -
    " [engine=" || self~engine || -
    "; storage=" || self~storage || -
    "; format=" || self~storageFormatVersion || -
    "; SQL=" || self~sqlLevel || -
    "; ooRexx=" || self~runtimeVersion || -
    " lang=" || self~runtimeLanguageLevel || -
    "; " || self~platform || "/" || self~architecture || "]"

::class DatabaseOperationType public
::constant OPERATION          "OPERATION"
::constant STATEMENT          "STATEMENT"
::constant EXECUTE            "EXECUTE"
::constant QUERY              "SELECT"
::constant PREPAREDSTATEMENT  "PREPAREDSTATEMENT"
::constant PREPAREDEXECUTION  "PREPAREDEXECUTION"
::constant PREPAREDBATCH      "PREPAREDBATCH"
::constant SAVEPOINT          "SAVEPOINT"
::constant ROLLBACKTOSAVEPOINT "ROLLBACKTOSAVEPOINT"
::constant BEGIN              "BEGIN"
::constant COMMIT             "COMMIT"
::constant ROLLBACK           "ROLLBACK"
::constant CREATE             "CREATE_TABLE"
::constant DROP               "DROP_TABLE"
::constant INSERT             "INSERT"
::constant UPDATE             "UPDATE"
::constant DELETE             "DELETE"
::constant INSPECT            "INSPECT"
::constant MAINTENANCE        "MAINTENANCE"
::constant CREATE_TABLE       "CREATE_TABLE"
::constant DROP_TABLE         "DROP_TABLE"
::constant SELECT             "SELECT"
::constant BUILD_INDEX        "BUILD_INDEX"
::constant BUILD_JOIN_MAP     "BUILD_JOIN_MAP"
::constant BACKUP             "BACKUP"
::constant RESTORE            "RESTORE"
::constant EXPORT             "EXPORT"
::constant IMPORT             "IMPORT"
::constant REPLICATION        "REPLICATION"

::class DatabaseResult public
::attribute status
::attribute error
::attribute message
::attribute operationType
::attribute rows
::attribute affectedRows
::attribute accessPath
::attribute rowsScanned
::attribute snapshotGeneration
::attribute indexedThrough
::attribute leftIndexedThrough
::attribute rightIndexedThrough
::attribute metadata
::attribute mutationGraph

::method init
  use arg operationType = .nil
  self~operationType = operationType
  self~status = .Error~SUCCESS
  self~error = .Error~SUCCESS
  self~message = ""
  self~rows = .array~new
  self~affectedRows = 0
  self~accessPath = "UNPLANNED"
  self~rowsScanned = 0
  self~snapshotGeneration = 0
  self~indexedThrough = 0
  self~leftIndexedThrough = 0
  self~rightIndexedThrough = 0
  self~metadata = .nil

::method rowCount
  return self~rows~items

::method fail
  use arg errorCode, message = ""
  self~status = .Error~NOTEXECUTED
  self~error = errorCode
  self~message = message
  return self

::class DelimiterDefinition public
::attribute kind
::attribute source
::attribute resolved
::attribute display

::method init
  use arg spec
  if spec == .nil then spec = ","

  if spec~isA(.table) then do
    hexValue = spec["hex"]
    if hexValue == .nil then hexValue = spec["HEX"]
    if hexValue \== .nil then do
      hexValue = hexValue~string~strip~translate
      valid = .true
      if hexValue~length // 2 \= 0 then valid = .false
      if valid then do
        if hexValue~verify("0123456789ABCDEF") \= 0 then valid = .false
      end
      if \valid then raise syntax 93.900 additional("Invalid hexadecimal delimiter:" hexValue)
      self~kind = "HEX"
      self~source = hexValue
      self~resolved = x2c(hexValue)
      self~display = "HEX:" || hexValue
      return
    end
  end

  value = spec~string
  if value~translate~startsWith("HEX:") then do
    hexValue = value~substr(5)~strip~translate
    valid = .true
    if hexValue~length // 2 \= 0 then valid = .false
    if valid then do
      if hexValue~verify("0123456789ABCDEF") \= 0 then valid = .false
    end
    if \valid then raise syntax 93.900 additional("Invalid hexadecimal delimiter:" hexValue)
    self~kind = "HEX"
    self~source = hexValue
    self~resolved = x2c(hexValue)
    self~display = "HEX:" || hexValue
    return
  end

  select
    when value~caselessEquals("TAB") then do
      self~kind = "TAB"
      self~source = "TAB"
      self~resolved = "09"x
      self~display = "TAB"
    end
    when value~caselessEquals("COMMA") then do
      self~kind = "CHAR"
      self~source = ","
      self~resolved = ","
      self~display = ","
    end
    otherwise do
      self~kind = "CHAR"
      self~source = value
      self~resolved = value
      self~display = value
    end
  end

  if self~resolved~length = 0 then raise syntax 93.900 additional("Delimiter may not be empty")

::method yamlValue
  if self~kind = "HEX" then do
    t = .table~new
    t["hex"] = self~source
    return t
  end
  return self~source

::class DatabaseColumn public
::attribute name
::attribute type
::attribute nullable
::attribute unique
::attribute primaryKey
::attribute textMode

::method init
  use arg name, type = "VARCHAR", nullable = .true, unique = .false, primaryKey = .false, textMode = "CLASSIC"
  self~name = name~string
  self~type = type~string~translate
  self~nullable = nullable
  self~unique = unique
  self~primaryKey = primaryKey
  self~textMode = textMode~string~translate
  if self~textMode \= "CLASSIC" & self~textMode \= "UNICODE" then ,
    raise syntax 93.900 additional("Unsupported textMode for" self~name || ":" self~textMode)
  if self~textMode = "UNICODE" then do
    if self~type \= "VARCHAR" & self~type \= "TEXT" then ,
      raise syntax 93.900 additional("textMode UNICODE is only valid for VARCHAR/TEXT columns:" self~name)
  end
  if self~primaryKey then self~nullable = .false

::method coerce
  use arg value
  if value == .nil then return .nil
  text = value~string
  select
    when self~type = "VARCHAR" then do
      if self~textMode = "UNICODE" then return .NoSQLUnicodeSupport~text(text)
      return text
    end
    when self~type = "TEXT" then do
      if self~textMode = "UNICODE" then return .NoSQLUnicodeSupport~text(text)
      return text
    end
    when self~type = "INTEGER" then do
      if \datatype(text, "W") then raise syntax 93.900 additional("Invalid INTEGER for" self~name || ":" text)
      return text
    end
    when self~type = "DECIMAL" then do
      if \datatype(text, "N") then raise syntax 93.900 additional("Invalid DECIMAL for" self~name || ":" text)
      return text
    end
    when self~type = "BOOLEAN" then do
      u = text~strip~translate
      if u = "TRUE" then return "TRUE"
      if u = "FALSE" then return "FALSE"
      if u = "1" then return "TRUE"
      if u = "0" then return "FALSE"
      raise syntax 93.900 additional("Invalid BOOLEAN for" self~name || ":" text)
    end
    when self~type = "DATE" then return text
    when self~type = "DATETIME" then return text
    when self~type = "BLOB" then return text
    when self~type = "GEOMETRY" then return value
    when self~type = "UNKNOWN" then return text
    otherwise raise syntax 93.900 additional("Unsupported column type:" self~type)
  end

::method compare
  use arg left, operator, right
  if left == .nil then return .false
  if right == .nil then return .false
  leftValue = self~coerce(left)
  rightValue = self~coerce(right)
  op = operator~string

  if self~type = "INTEGER" then do
    return self~numericCompare(leftValue, op, rightValue)
  end
  if self~type = "DECIMAL" then do
    return self~numericCompare(leftValue, op, rightValue)
  end
  if self~textMode = "UNICODE" then return .NoSQLUnicodeSupport~compare(leftValue, op, rightValue)

  select
    when op = "=" then return leftValue == rightValue
    when op = "<>" then return leftValue \== rightValue
    when op = "!=" then return leftValue \== rightValue
    when op = "<" then return leftValue < rightValue
    when op = "<=" then return leftValue <= rightValue
    when op = ">" then return leftValue > rightValue
    when op = ">=" then return leftValue >= rightValue
    otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
  end

::method numericCompare private
  use arg leftValue, op, rightValue
  select
    when op = "=" then return leftValue = rightValue
    when op = "<>" then return leftValue \= rightValue
    when op = "!=" then return leftValue \= rightValue
    when op = "<" then return leftValue < rightValue
    when op = "<=" then return leftValue <= rightValue
    when op = ">" then return leftValue > rightValue
    when op = ">=" then return leftValue >= rightValue
    otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
  end

::class TableDefinition public
::attribute name
::attribute columns
::attribute columnNames
::attribute delimiterDefinition
::attribute header
::attribute qualifier
::attribute nullToken
::attribute tombstoneHex
::attribute tombstoneByte
::attribute tombstoneThresholdBytes
::attribute yamlPath
::attribute primaryKey
::attribute uniqueConstraints
::attribute foreignKeys
::attribute generation
::attribute rowCount
::attribute defaultTextMode

::method init
  use arg source
  if source~isA(.table) then do
    self~yamlPath = ""
    self~loadRaw(source)
    return
  end
  self~yamlPath = source
  raw = .Yaml~new~parseFile(source)
  self~loadRaw(raw)

::method loadRaw private
  use arg raw
  if \raw~isA(.table) then raise syntax 93.900 additional("Table YAML root must be a mapping")

  self~name = raw["name"]
  if self~name == .nil then raise syntax 93.900 additional("Table YAML requires name")

  generation = raw["generation"]
  if generation == .nil then generation = 0
  self~generation = generation
  self~rowCount = raw["rowCount"]

  defaultTextMode = raw["textMode"]
  if defaultTextMode == .nil then defaultTextMode = "CLASSIC"
  self~defaultTextMode = defaultTextMode~string~translate
  if self~defaultTextMode \= "CLASSIC" & self~defaultTextMode \= "UNICODE" then ,
    raise syntax 93.900 additional("Table textMode must be CLASSIC or UNICODE")

  storage = raw["storage"]
  if storage == .nil then storage = .table~new
  separator = storage["separator"]
  if separator == .nil then separator = ","
  self~delimiterDefinition = .DelimiterDefinition~new(separator)

  header = storage["header"]
  if header == .nil then header = .true
  self~header = header

  qualifier = storage["qualifier"]
  if qualifier == .nil then qualifier = '"'
  self~qualifier = qualifier~string

  nullToken = storage["nullToken"]
  if nullToken == .nil then nullToken = "\\N"
  self~nullToken = nullToken~string

  tombstoneHex = storage["tombstoneHex"]
  if tombstoneHex == .nil then tombstoneHex = "FD"
  tombstoneHex = tombstoneHex~string~translate
  if tombstoneHex~length \= 2 | \datatype(tombstoneHex, "X") then raise syntax 93.900 additional("storage.tombstoneHex must be exactly one hexadecimal byte")
  tombstoneByte = x2c(tombstoneHex)
  if tombstoneByte = self~delimiterDefinition~resolved then raise syntax 93.900 additional("Tombstone byte may not equal table delimiter")
  if tombstoneByte = self~qualifier then raise syntax 93.900 additional("Tombstone byte may not equal CSV qualifier")
  if tombstoneByte = x2c("0A") | tombstoneByte = x2c("0D") then raise syntax 93.900 additional("Tombstone byte may not be a line terminator")
  self~tombstoneHex = tombstoneHex
  self~tombstoneByte = tombstoneByte

  tombstoneThresholdBytes = storage["tombstoneThresholdBytes"]
  if tombstoneThresholdBytes == .nil then tombstoneThresholdBytes = 65536
  if \datatype(tombstoneThresholdBytes~string, "W") then raise syntax 93.900 additional("storage.tombstoneThresholdBytes must be a non-negative integer")
  if tombstoneThresholdBytes < 0 then raise syntax 93.900 additional("storage.tombstoneThresholdBytes must be a non-negative integer")
  self~tombstoneThresholdBytes = tombstoneThresholdBytes

  cols = raw["columns"]
  if cols == .nil then raise syntax 93.900 additional("Table YAML requires columns sequence")
  if \cols~isA(.array) then raise syntax 93.900 additional("Table YAML requires columns sequence")

  self~columns = .array~new
  self~columnNames = .array~new
  self~primaryKey = .array~new
  self~uniqueConstraints = .array~new
  self~foreignKeys = .array~new

  do c over cols
    if \c~isA(.table) then raise syntax 93.900 additional("Column definition must be a mapping")
    n = c["name"]
    if n == .nil then raise syntax 93.900 additional("Column requires name")
    t = c["type"]
    if t == .nil then t = "VARCHAR"
    nullable = c["nullable"]
    if nullable == .nil then nullable = .true
    unique = c["unique"]
    if unique == .nil then unique = .false
    pk = c["primaryKey"]
    if pk == .nil then pk = .false
    textMode = c["textMode"]
    if textMode == .nil then textMode = self~defaultTextMode
    col = .DatabaseColumn~new(n, t, nullable, unique, pk, textMode)
    self~columns~append(col)
    self~columnNames~append(col~name)
    if pk then self~primaryKey~append(col~name)
    if unique then do
      u = .array~new
      u~append(col~name)
      self~uniqueConstraints~append(u)
    end
  end

  rawPk = raw["primaryKey"]
  if rawPk \== .nil then do
    self~primaryKey = self~normalizeConstraint(rawPk)
  end

  rawUnique = raw["unique"]
  if rawUnique \== .nil then do
    if rawUnique~isA(.array) then do
      do u over rawUnique
        self~uniqueConstraints~append(self~normalizeConstraint(u))
      end
    end
    else self~uniqueConstraints~append(self~normalizeConstraint(rawUnique))
  end

  rawFks = raw["foreignKeys"]
  if rawFks \== .nil then do
    if \rawFks~isA(.array) then raise syntax 93.900 additional("foreignKeys must be a sequence")
    do fkRaw over rawFks
      if \fkRaw~isA(.table) then raise syntax 93.900 additional("Foreign key definition must be a mapping")
      fk = .DatabaseForeignKeyDefinition~new(fkRaw["column"], fkRaw["referencesTable"], fkRaw["referencesColumn"], fkRaw["onDelete"], fkRaw["onUpdate"])
      if self~canonicalColumn(fk~column) == .nil then raise syntax 93.900 additional("Foreign key references unknown child column:" fk~column)
      self~foreignKeys~append(fk)
    end
  end

  do pkName over self~primaryKey
    col = self~column(pkName)
    if col == .nil then raise syntax 93.900 additional("Primary key references unknown column:" pkName)
    col~primaryKey = .true
    col~nullable = .false
  end

::method normalizeConstraint private
  use arg value
  out = .array~new
  if value~isA(.array) then do
    do item over value
      canonical = self~canonicalColumn(item)
      if canonical == .nil then raise syntax 93.900 additional("Constraint references unknown column:" item)
      out~append(canonical)
    end
  end
  else do
    canonical = self~canonicalColumn(value)
    if canonical == .nil then raise syntax 93.900 additional("Constraint references unknown column:" value)
    out~append(canonical)
  end
  return out

::method hasColumn
  use arg wanted
  do n over self~columnNames
    if n~caselessEquals(wanted~string) then return .true
  end
  return .false

::method canonicalColumn
  use arg wanted
  do n over self~columnNames
    if n~caselessEquals(wanted~string) then return n
  end
  return .nil

::method column
  use arg wanted
  canonical = self~canonicalColumn(wanted)
  if canonical == .nil then return .nil
  do c over self~columns
    if c~name == canonical then return c
  end
  return .nil

::method coerceRow
  use arg row
  out = .DatabaseRow~new
  do key over row~values
    canonical = self~canonicalColumn(key)
    if canonical == .nil then raise syntax 93.900 additional("Unknown column:" key)
    col = self~column(canonical)
    out[canonical] = col~coerce(row[key])
  end
  do col over self~columns
    if out[col~name] == .nil then do
      if \col~nullable then raise syntax 93.900 additional("NOT NULL constraint failed:" col~name)
    end
  end
  return out

::class DatabaseRow public
::attribute values
::attribute rawValues
::attribute typeNames

::method init
  use arg values = .nil, rawValues = .nil, typeNames = .nil
  if values == .nil then values = .table~new
  if rawValues == .nil then rawValues = values~copy
  if typeNames == .nil then typeNames = .table~new
  self~values = values
  self~rawValues = rawValues
  self~typeNames = typeNames

::method "[]"
  use arg name
  return self~values[name]

::method "[]="
  use arg value, name
  self~values[name] = value
  if self~rawValues[name] == .nil then self~rawValues[name] = value
  return value

::method at
  use arg name
  return self~values[name]

::method rawAt
  use arg name
  return self~rawValues[name]

::method valueAt
  use arg name
  typeName = self~typeNames[name]
  if typeName == .nil then typeName = "UNKNOWN"
  return .DatabaseValue~new(self~rawValues[name], self~values[name], typeName)

::method copy
  return .DatabaseRow~new(self~values~copy, self~rawValues~copy, self~typeNames~copy)

::class SQLPredicate public
::method evaluate abstract

::class SQLValueExpression public
::method evaluate abstract

::class SQLColumnValueExpression subclass SQLValueExpression public
::attribute reference
::method init
  use arg reference
  self~reference = reference
::method evaluate
  use arg row, definition
  canonical = definition~canonicalColumn(self~reference)
  if canonical == .nil then raise syntax 93.900 additional("Unknown column:" self~reference)
  return row[canonical]

::class SQLLiteralValueExpression subclass SQLValueExpression public
::attribute value
::method init
  use arg value
  self~value = value
::method evaluate
  use arg row, definition
  return self~value

::class SQLConcatValueExpression subclass SQLValueExpression public
::attribute left
::attribute right
::method init
  use arg left, right
  self~left = left
  self~right = right
::method evaluate
  use arg row, definition
  leftValue = self~left~evaluate(row, definition)
  rightValue = self~right~evaluate(row, definition)
  if leftValue == .nil | rightValue == .nil then return .nil
  if .NoSQLUnicodeSupport~isUnicodeValue(leftValue) then ,
    return .NoSQLUnicodeSupport~text(.NoSQLUnicodeSupport~raw(leftValue) || .NoSQLUnicodeSupport~raw(rightValue))
  if .NoSQLUnicodeSupport~isUnicodeValue(rightValue) then ,
    return .NoSQLUnicodeSupport~text(.NoSQLUnicodeSupport~raw(leftValue) || .NoSQLUnicodeSupport~raw(rightValue))
  return leftValue~string || rightValue~string

::class SQLCastValueExpression subclass SQLValueExpression public
::attribute child
::attribute targetType
::method init
  use arg child, targetType
  self~child = child
  self~targetType = targetType~translate
::method evaluate
  use arg row, definition
  value = self~child~evaluate(row, definition)
  if value == .nil then return .nil
  if self~targetType = "VARCHAR" then do
    if .NoSQLUnicodeSupport~isUnicodeValue(value) then return value
    return value~string
  end
  raise syntax 93.900 additional("Unsupported CAST target:" self~targetType)

::class SQLFunctionValueExpression subclass SQLValueExpression public
::attribute functionName
::attribute arguments
::method init
  use arg functionName, arguments
  self~functionName = functionName~translate
  self~arguments = arguments
::method evaluate
  use arg row, definition
  name = self~functionName
  if name = "UPPER" then do
    if self~arguments~items \= 1 then raise syntax 93.900 additional("UPPER requires one argument")
    value = self~arguments[1]~evaluate(row, definition)
    if value == .nil then return .nil
    if .NoSQLUnicodeSupport~isUnicodeValue(value) then return value~upper
    return value~string~translate
  end
  if name = "LOWER" then do
    if self~arguments~items \= 1 then raise syntax 93.900 additional("LOWER requires one argument")
    value = self~arguments[1]~evaluate(row, definition)
    if value == .nil then return .nil
    if .NoSQLUnicodeSupport~isUnicodeValue(value) then return value~lower
    return translate(value~string, "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  end
  if name = "SUBSTR" then do
    if self~arguments~items < 2 | self~arguments~items > 3 then raise syntax 93.900 additional("SUBSTR requires two or three arguments")
    value = self~arguments[1]~evaluate(row, definition)
    if value == .nil then return .nil
    start = self~arguments[2]~evaluate(row, definition)
    if \datatype(start~string, "W") then raise syntax 93.900 additional("SUBSTR start must be integer")
    if self~arguments~items = 2 then do
      if .NoSQLUnicodeSupport~isUnicodeValue(value) then return value~substr(start)
      return value~string~substr(start)
    end
    length = self~arguments[3]~evaluate(row, definition)
    if \datatype(length~string, "W") then raise syntax 93.900 additional("SUBSTR length must be integer")
    if .NoSQLUnicodeSupport~isUnicodeValue(value) then return value~substr(start, length)
    return value~string~substr(start, length)
  end
  if name = "CHAR_LENGTH" | name = "CHARACTER_LENGTH" then do
    if self~arguments~items \= 1 then raise syntax 93.900 additional(name "requires one argument")
    value = self~arguments[1]~evaluate(row, definition)
    return .NoSQLUnicodeSupport~characterLength(value)
  end
  if name = "OCTET_LENGTH" then do
    if self~arguments~items \= 1 then raise syntax 93.900 additional("OCTET_LENGTH requires one argument")
    value = self~arguments[1]~evaluate(row, definition)
    return .NoSQLUnicodeSupport~octetLength(value)
  end
  if name = "ST_SRID" | name = "ST_GEOMETRYTYPE" | name = "ST_X" | name = "ST_Y" then do
    if self~arguments~items \= 1 then raise syntax 93.900 additional(name "requires one argument")
    value = self~arguments[1]~evaluate(row, definition)
    if value == .nil then return .nil
    select
      when name = "ST_SRID" then return .NoSQLSpatialSupport~srid(value)
      when name = "ST_GEOMETRYTYPE" then return .NoSQLSpatialSupport~geometryType(value)
      when name = "ST_X" then return .NoSQLSpatialSupport~x(value)
      when name = "ST_Y" then return .NoSQLSpatialSupport~y(value)
      otherwise nop
    end
  end
  if name = "ST_WITHIN" | name = "ST_INTERSECTS" then do
    if self~arguments~items \= 2 then raise syntax 93.900 additional(name "requires two arguments")
    left = self~arguments[1]~evaluate(row, definition)
    right = self~arguments[2]~evaluate(row, definition)
    if left == .nil | right == .nil then return .nil
    if name = "ST_WITHIN" then do
      if .NoSQLSpatialSupport~within(left, right) then return "TRUE"
      return "FALSE"
    end
    if .NoSQLSpatialSupport~intersects(left, right) then return "TRUE"
    return "FALSE"
  end
  raise syntax 93.900 additional("Unsupported SQL function:" name)

::class SQLExpressionComparisonPredicate subclass SQLPredicate public
::attribute leftExpression
::attribute operator
::attribute rightExpression
::method init
  use arg leftExpression, operator, rightExpression
  self~leftExpression = leftExpression
  self~operator = operator
  self~rightExpression = rightExpression
::method evaluate
  use arg row, definition
  left = self~leftExpression~evaluate(row, definition)
  right = self~rightExpression~evaluate(row, definition)
  if left == .nil | right == .nil then return .false
  op = self~operator
  if .NoSQLUnicodeSupport~isUnicodeValue(left) then return .NoSQLUnicodeSupport~compare(left, op, right)
  if .NoSQLUnicodeSupport~isUnicodeValue(right) then return .NoSQLUnicodeSupport~compare(left, op, right)
  if datatype(left~string, "N") & datatype(right~string, "N") then do
    select
      when op = "=" then return left = right
      when op = "<>" | op = "!=" then return left \= right
      when op = "<" then return left < right
      when op = "<=" then return left <= right
      when op = ">" then return left > right
      when op = ">=" then return left >= right
      otherwise return .false
    end
  end
  l = left~string
  r = right~string
  select
    when op = "=" then return l == r
    when op = "<>" | op = "!=" then return l \== r
    when op = "<" then return l < r
    when op = "<=" then return l <= r
    when op = ">" then return l > r
    when op = ">=" then return l >= r
    otherwise return .false
  end

::class SQLLikePredicate subclass SQLPredicate public
::attribute valueExpression
::attribute patternExpression
::method init
  use arg valueExpression, patternExpression
  self~valueExpression = valueExpression
  self~patternExpression = patternExpression
::method evaluate
  use arg row, definition
  value = self~valueExpression~evaluate(row, definition)
  pattern = self~patternExpression~evaluate(row, definition)
  if value == .nil | pattern == .nil then return .false
  if .NoSQLUnicodeSupport~isUnicodeValue(value) then do
    value = .NoSQLUnicodeSupport~text(value)
    pattern = .NoSQLUnicodeSupport~text(pattern)
  end
  else if .NoSQLUnicodeSupport~isUnicodeValue(pattern) then do
    value = .NoSQLUnicodeSupport~text(value)
    pattern = .NoSQLUnicodeSupport~text(pattern)
  end
  else do
    value = value~string
    pattern = pattern~string
  end
  return self~matches(value, pattern, 1, 1)
::method matches private
  use arg text, pattern, textPos, patternPos
  if patternPos > pattern~length then return textPos > text~length
  p = pattern~substr(patternPos, 1)
  pRaw = p~string
  if .NoSQLUnicodeSupport~isUnicodeValue(p) then pRaw = p~makeString
  if pRaw = "%" then do
    if self~matches(text, pattern, textPos, patternPos + 1) then return .true
    if textPos <= text~length then return self~matches(text, pattern, textPos + 1, patternPos)
    return .false
  end
  if textPos > text~length then return .false
  if pRaw = "_" then return self~matches(text, pattern, textPos + 1, patternPos + 1)
  tc = text~substr(textPos, 1)
  if .NoSQLUnicodeSupport~isUnicodeValue(tc) then do
    if tc~makeString \= p~makeString then return .false
  end
  else if tc \= p then return .false
  return self~matches(text, pattern, textPos + 1, patternPos + 1)

::class SQLBetweenPredicate subclass SQLPredicate public
::attribute valueExpression
::attribute lowExpression
::attribute highExpression
::method init
  use arg valueExpression, lowExpression, highExpression
  self~valueExpression = valueExpression
  self~lowExpression = lowExpression
  self~highExpression = highExpression
::method evaluate
  use arg row, definition
  value = self~valueExpression~evaluate(row, definition)
  low = self~lowExpression~evaluate(row, definition)
  high = self~highExpression~evaluate(row, definition)
  if value == .nil | low == .nil | high == .nil then return .false
  if .NoSQLUnicodeSupport~isUnicodeValue(value) | .NoSQLUnicodeSupport~isUnicodeValue(low) | .NoSQLUnicodeSupport~isUnicodeValue(high) then do
    if \.NoSQLUnicodeSupport~compare(value, ">=", low) then return .false
    return .NoSQLUnicodeSupport~compare(value, "<=", high)
  end
  if datatype(value~string, "N") & datatype(low~string, "N") & datatype(high~string, "N") then return value >= low & value <= high
  text = value~string
  return text >= low~string & text <= high~string

::class SQLComparisonPredicate subclass SQLPredicate public
::attribute column
::attribute operator
::attribute value

::method init
  use arg column, operator, value
  self~column = column
  self~operator = operator
  self~value = value

::method evaluate
  use arg row, definition
  col = definition~column(self~column)
  if col == .nil then raise syntax 93.900 additional("Unknown column:" self~column)
  actual = row[col~name]
  return col~compare(actual, self~operator, self~value)

::class SQLColumnComparisonPredicate subclass SQLPredicate public
::attribute leftReference
::attribute operator
::attribute rightReference

::method init
  use arg leftReference, operator, rightReference
  self~leftReference = leftReference
  self~operator = operator
  self~rightReference = rightReference

::method evaluate
  use arg row, definition
  leftResolved = definition~resolve(self~leftReference)
  rightResolved = definition~resolve(self~rightReference)
  if leftResolved == .nil then raise syntax 93.900 additional("Unknown column:" self~leftReference)
  if rightResolved == .nil then raise syntax 93.900 additional("Unknown column:" self~rightReference)
  leftValue = row[leftResolved["physicalName"]]
  rightValue = row[rightResolved["physicalName"]]
  return leftResolved["column"]~compare(leftValue, self~operator, rightValue)

::class SQLNullPredicate subclass SQLPredicate public
::attribute column
::attribute negate

::method init
  use arg column, negate = .false
  self~column = column
  self~negate = negate

::method evaluate
  use arg row, definition
  canonical = definition~canonicalColumn(self~column)
  if canonical == .nil then raise syntax 93.900 additional("Unknown column:" self~column)
  isNull = (row[canonical] == .nil)
  if self~negate then return \isNull
  return isNull

::class SQLLogicalPredicate subclass SQLPredicate public
::attribute operator
::attribute left
::attribute right

::method init
  use arg operator, left, right
  self~operator = operator~translate
  self~left = left
  self~right = right

::method evaluate
  use arg row, definition
  if self~operator = "AND" then do
    if \self~left~evaluate(row, definition) then return .false
    return self~right~evaluate(row, definition)
  end
  if self~operator = "OR" then do
    if self~left~evaluate(row, definition) then return .true
    return self~right~evaluate(row, definition)
  end
  raise syntax 93.900 additional("Invalid logical predicate:" self~operator)

::class SQLNotPredicate subclass SQLPredicate public
::attribute child
::method init
  use arg child
  self~child = child
::method evaluate
  use arg row, definition
  return \self~child~evaluate(row, definition)


::class SQLRelationDefinition public
::attribute leftDefinition
::attribute rightDefinition
::attribute leftAlias
::attribute rightAlias

::method init
  use arg leftDefinition, leftAlias = .nil, rightDefinition = .nil, rightAlias = .nil
  self~leftDefinition = leftDefinition
  self~rightDefinition = rightDefinition
  if leftAlias == .nil then leftAlias = leftDefinition~name
  self~leftAlias = leftAlias
  if rightDefinition \== .nil then do
    if rightAlias == .nil then rightAlias = rightDefinition~name
  end
  self~rightAlias = rightAlias

::method resolve
  use arg reference
  ref = reference~string~strip
  dot = ref~pos(".")
  if dot > 0 then do
    qualifier = ref~left(dot - 1)~strip
    columnName = ref~substr(dot + 1)~strip
    if self~matchesLeft(qualifier) then return self~resolvedFor(self~leftDefinition, columnName, self~leftDefinition~name)
    if self~rightDefinition \== .nil then do
      if self~matchesRight(qualifier) then return self~resolvedFor(self~rightDefinition, columnName, self~rightDefinition~name)
    end
    return .nil
  end

  leftColumn = self~leftDefinition~column(ref)
  rightColumn = .nil
  if self~rightDefinition \== .nil then rightColumn = self~rightDefinition~column(ref)
  if leftColumn \== .nil then do
    if rightColumn \== .nil then return .nil
    return self~resolvedFor(self~leftDefinition, ref, self~leftDefinition~name)
  end
  if rightColumn \== .nil then return self~resolvedFor(self~rightDefinition, ref, self~rightDefinition~name)
  return .nil

::method column
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["column"]

::method canonicalColumn
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["physicalName"]

::method sideFor
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return ""
  return resolved["side"]

::method sourceColumn
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["sourceColumn"]

::method matchesLeft private
  use arg qualifier
  if qualifier~caselessEquals(self~leftAlias) then return .true
  return qualifier~caselessEquals(self~leftDefinition~name)

::method matchesRight private
  use arg qualifier
  if qualifier~caselessEquals(self~rightAlias) then return .true
  return qualifier~caselessEquals(self~rightDefinition~name)

::method resolvedFor private
  use arg definition, wanted, tableName
  source = definition~column(wanted)
  if source == .nil then return .nil
  physicalName = source~name
  side = "LEFT"
  if self~rightDefinition \== .nil then do
    if definition == self~rightDefinition then side = "RIGHT"
    physicalName = tableName || "." || source~name
  end
  wrapper = .DatabaseColumn~new(physicalName, source~type, source~nullable, source~unique, source~primaryKey)
  out = .table~new
  out["column"] = wrapper
  out["physicalName"] = physicalName
  out["sourceColumn"] = source~name
  out["side"] = side
  return out

::class SQLVirtualDefinition public
::attribute name
::attribute columns
::attribute columnNames

::method init
  use arg name, names
  self~name = name
  self~columns = .array~new
  self~columnNames = .array~new
  do n over names
    col = .DatabaseColumn~new(n, "UNKNOWN", .true, .false, .false)
    self~columns~append(col)
    self~columnNames~append(n)
  end

::method column
  use arg wanted
  do col over self~columns
    if col~name~caselessEquals(wanted) then return col
  end
  return .nil

::class SQLDerivedRelationDefinition public
::attribute alias
::attribute names

::method init
  use arg alias, names
  self~alias = alias
  self~names = names

::method resolve
  use arg reference
  ref = reference~string~strip
  dot = ref~pos(".")
  if dot > 0 then do
    qualifier = ref~left(dot - 1)~strip
    wanted = ref~substr(dot + 1)~strip
    if \qualifier~caselessEquals(self~alias) then return .nil
  end
  else wanted = ref
  found = ""
  do name over self~names
    if name~caselessEquals(wanted) then do
      if found \= "" then return .nil
      found = name
    end
  end
  if found = "" then return .nil
  physicalName = self~alias || "." || found
  col = .DatabaseColumn~new(physicalName, "UNKNOWN", .true, .false, .false)
  out = .table~new
  out["column"] = col
  out["physicalName"] = physicalName
  out["sourceColumn"] = found
  out["alias"] = self~alias
  return out

::method column
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["column"]

::method canonicalColumn
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["physicalName"]

::class SQLMultiRelationDefinition public
::attribute relations

::method init
  use arg relations
  self~relations = relations

::method resolve
  use arg reference
  ref = reference~string~strip
  dot = ref~pos(".")
  if dot > 0 then do
    qualifier = ref~left(dot - 1)~strip
    columnName = ref~substr(dot + 1)~strip
    do entry over self~relations
      if qualifier~caselessEquals(entry["alias"]) then return self~resolvedFor(entry, columnName)
      if qualifier~caselessEquals(entry["definition"]~name) then return self~resolvedFor(entry, columnName)
    end
    return .nil
  end

  found = .nil
  do entry over self~relations
    source = entry["definition"]~column(ref)
    if source == .nil then iterate
    if found \== .nil then return .nil
    found = self~resolvedFor(entry, ref)
  end
  return found

::method column
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["column"]

::method canonicalColumn
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["physicalName"]

::method resolvedFor private
  use arg entry, wanted
  definition = entry["definition"]
  source = definition~column(wanted)
  if source == .nil then return .nil
  physicalName = definition~name || "." || source~name
  wrapper = .DatabaseColumn~new(physicalName, source~type, source~nullable, source~unique, source~primaryKey)
  out = .table~new
  out["column"] = wrapper
  out["physicalName"] = physicalName
  out["sourceColumn"] = source~name
  out["tableName"] = definition~name
  out["alias"] = entry["alias"]
  return out

::class SQLAliasRelationDefinition public
::attribute relations

::method init
  use arg relations
  self~relations = relations

::method resolve
  use arg reference
  ref = reference~string~strip
  dot = ref~pos(".")
  if dot > 0 then do
    qualifier = ref~left(dot - 1)~strip
    columnName = ref~substr(dot + 1)~strip
    found = .nil
    do entry over self~relations
      if qualifier~caselessEquals(entry["alias"]) then do
        if found \== .nil then return .nil
        found = self~resolvedFor(entry, columnName)
      end
    end
    return found
  end

  found = .nil
  do entry over self~relations
    source = entry["definition"]~column(ref)
    if source == .nil then iterate
    if found \== .nil then return .nil
    found = self~resolvedFor(entry, ref)
  end
  return found

::method column
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["column"]

::method canonicalColumn
  use arg reference
  resolved = self~resolve(reference)
  if resolved == .nil then return .nil
  return resolved["physicalName"]

::method resolvedFor private
  use arg entry, wanted
  definition = entry["definition"]
  source = definition~column(wanted)
  if source == .nil then return .nil
  physicalName = entry["alias"] || "." || source~name
  wrapper = .DatabaseColumn~new(physicalName, source~type, source~nullable, source~unique, source~primaryKey)
  out = .table~new
  out["column"] = wrapper
  out["physicalName"] = physicalName
  out["sourceColumn"] = source~name
  out["tableName"] = definition~name
  out["alias"] = entry["alias"]
  return out

::class SQLSyntheticDefinition public
::attribute name
::attribute columns
::attribute columnNames
::method init
  use arg name, names
  self~name = name; self~columns = .array~new; self~columnNames = .array~new
  do n over names
    self~columns~append(.DatabaseColumn~new(n, "UNKNOWN", .true, .false, .false)); self~columnNames~append(n)
  end
::method column
  use arg wanted
  do c over self~columns
    if c~name~caselessEquals(wanted) then return c
  end
  return .nil

::method canonicalColumn
  use arg wanted
  c = self~column(wanted)
  if c == .nil then return .nil
  return c~name

::class SQLMaterializedTable public
::attribute definition
::attribute rows
::attribute generation

::method init
  use arg name, names, rows
  self~definition = .SQLSyntheticDefinition~new(name, names)
  self~rows = .array~new
  do row over rows
    self~rows~append(row~copy)
  end
  self~generation = 0

::method readRows
  out = .array~new
  do row over self~rows
    out~append(row~copy)
  end
  return out

::method rowCount
  return self~rows~items

::class SQLCTEEngineOverlay public
::attribute baseEngine
::attribute cteTables

::method init
  use arg baseEngine
  self~baseEngine = baseEngine
  self~cteTables = .table~new

::method registerCTE
  use arg name, table
  self~cteTables[name~translate] = table
  return .true

::method table
  use arg name
  t = self~cteTables[name~translate]
  if t \== .nil then return t
  return self~baseEngine~table(name)

::method tableRowCount
  use arg name
  t = self~table(name)
  if t == .nil then return .nil
  return t~rowCount

::method selectAll
  use arg name
  return self~selectWhere(name, .nil)

::method selectWhere
  use arg name, predicate
  t = self~cteTables[name~translate]
  if t == .nil then return self~baseEngine~selectWhere(name, predicate)
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  allRows = t~readRows
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "CTE_SCAN"
  return rs

::method selectJoin
  use arg leftName,leftColumn,rightName,rightColumn
  if self~cteTables[leftName~translate] == .nil & self~cteTables[rightName~translate] == .nil then ,
    return self~baseEngine~selectJoin(leftName,leftColumn,rightName,rightColumn)
  return self~genericJoin(leftName,leftColumn,rightName,rightColumn)

::method selectJoinWithSidePredicate
  use arg leftName,leftColumn,rightName,rightColumn,side,predicate
  rs = self~selectJoin(leftName,leftColumn,rightName,rightColumn)
  if rs~status \= .Error~SUCCESS then return rs
  return rs

::method selectCrossJoin
  use arg leftName,rightName
  if self~cteTables[leftName~translate] == .nil & self~cteTables[rightName~translate] == .nil then ,
    return self~baseEngine~selectCrossJoin(leftName,rightName)
  rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
  left=self~table(leftName); right=self~table(rightName)
  if left==.nil | right==.nil then return rs~fail(.Error~NOTFOUND,"Cross join table not found")
  out=.array~new
  leftRows=left~readRows; rightRows=right~readRows
  do lrow over leftRows
    do rrow over rightRows
      out~append(self~qualifiedJoinRow(left,lrow,right,rrow))
    end
  end
  rs~rows=out; rs~affectedRows=out~items; rs~rowsScanned=leftRows~items+rightRows~items
  rs~accessPath="CTE_CROSS_SCAN"
  return rs

::method selectCrossJoinWithSidePredicate
  use arg leftName,rightName,side,predicate
  return self~selectCrossJoin(leftName,rightName)

::method genericJoin private
  use arg leftName,leftColumn,rightName,rightColumn
  rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
  left=self~table(leftName); right=self~table(rightName)
  if left==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" leftName)
  if right==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" rightName)
  lc=left~definition~canonicalColumn(leftColumn)
  rc=right~definition~canonicalColumn(rightColumn)
  if lc==.nil | rc==.nil then return rs~fail(.Error~SCHEMAERROR,"Unknown join column")
  leftRows=left~readRows; rightRows=right~readRows
  buckets=.table~new
  do rrow over rightRows
    v=rrow[rc]
    if v==.nil then iterate
    arr=buckets[v~string]
    if arr==.nil then arr=.array~new
    arr~append(rrow)
    buckets[v~string]=arr
  end
  out=.array~new
  do lrow over leftRows
    v=lrow[lc]
    if v==.nil then iterate
    matches=buckets[v~string]
    if matches==.nil then iterate
    do rrow over matches
      out~append(self~qualifiedJoinRow(left,lrow,right,rrow))
    end
  end
  rs~rows=out; rs~affectedRows=out~items; rs~rowsScanned=leftRows~items+rightRows~items
  rs~accessPath="CTE_JOIN_SCAN"
  return rs

::method qualifiedJoinRow private
  use arg left,lrow,right,rrow
  values=.table~new
  do col over left~definition~columns
    values[left~definition~name || "." || col~name]=lrow[col~name]
  end
  do col over right~definition~columns
    values[right~definition~name || "." || col~name]=rrow[col~name]
  end
  return .DatabaseRow~new(values)

::method currentIndexCandidateCount
  use arg tableName,column,wanted
  if self~cteTables[tableName~translate] \== .nil then return .nil
  return self~baseEngine~currentIndexCandidateCount(tableName,column,wanted)

::method joinMapSnapshot
  return self~baseEngine~joinMapSnapshot

::method queryPatternLog
  return self~baseEngine~queryPatternLog

::method tableMetadata
  use arg name
  t = self~cteTables[name~translate]
  if t == .nil then return self~baseEngine~tableMetadata(name)
  return t~definition

::method version
  return self~baseEngine~version
::method transaction
  return self~baseEngine~transaction
::method events
  return self~baseEngine~events
::method insert
  forward to (self~baseEngine)
::method insertMany
  forward to (self~baseEngine)
::method updateWhere
  forward to (self~baseEngine)
::method deleteWhere
  forward to (self~baseEngine)
::method createTable
  forward to (self~baseEngine)
::method dropTable
  forward to (self~baseEngine)
::method query
  forward to (self~baseEngine)
::method root
  return self~baseEngine~root
::method runtime
  return self~baseEngine~runtime

::class SQLPredicateParser public
::attribute tokens
::attribute position

::method parse
  use arg text
  self~tokens = self~tokenize(text)
  self~position = 1
  if self~tokens~items = 0 then raise syntax 93.900 additional("Empty WHERE predicate")
  tree = self~parseOr
  if self~position <= self~tokens~items then raise syntax 93.900 additional("Unexpected predicate token:" self~peek)
  return tree

::method parseOr private
  left = self~parseAnd
  do while self~peek~translate = "OR"
    self~take
    right = self~parseAnd
    left = .SQLLogicalPredicate~new("OR", left, right)
  end
  return left

::method parseAnd private
  left = self~parseNot
  do while self~peek~translate = "AND"
    self~take
    right = self~parseNot
    left = .SQLLogicalPredicate~new("AND", left, right)
  end
  return left

::method parseNot private
  if self~peek~translate = "NOT" then do
    self~take
    return .SQLNotPredicate~new(self~parseNot)
  end
  return self~parsePrimary

::method parsePrimary private
  if self~peek = "(" then do
    self~take
    node = self~parseOr
    if self~take \= ")" then raise syntax 93.900 additional("Missing ')' in WHERE predicate")
    return node
  end

  leftExpression = self~parseValueExpression
  next = self~take
  if next == .nil then raise syntax 93.900 additional("Expected predicate operator")
  upper = next~translate
  if upper = "IS" then do
    if \leftExpression~isA(.SQLColumnValueExpression) then raise syntax 93.900 additional("IS NULL requires a column reference")
    maybeNot = self~take
    if maybeNot == .nil then raise syntax 93.900 additional("IS requires NULL or NOT NULL")
    if maybeNot~translate = "NULL" then return .SQLNullPredicate~new(leftExpression~reference, .false)
    if maybeNot~translate = "NOT" then do
      nullWord = self~take
      if nullWord == .nil then raise syntax 93.900 additional("IS NOT requires NULL")
      if nullWord~translate \= "NULL" then raise syntax 93.900 additional("IS NOT requires NULL")
      return .SQLNullPredicate~new(leftExpression~reference, .true)
    end
    raise syntax 93.900 additional("IS requires NULL or NOT NULL")
  end

  if upper = "LIKE" then do
    rightExpression = self~parseValueExpression
    return .SQLLikePredicate~new(leftExpression, rightExpression)
  end

  if upper = "NOT" then do
    likeWord = self~take
    if likeWord == .nil then raise syntax 93.900 additional("NOT requires LIKE")
    if likeWord~translate \= "LIKE" then raise syntax 93.900 additional("Unsupported predicate operator: NOT " || likeWord)
    rightExpression = self~parseValueExpression
    return .SQLNotPredicate~new(.SQLLikePredicate~new(leftExpression, rightExpression))
  end

  if upper = "BETWEEN" then do
    lowExpression = self~parseValueExpression
    andWord = self~take
    if andWord == .nil then raise syntax 93.900 additional("BETWEEN requires AND")
    if andWord~translate \= "AND" then raise syntax 93.900 additional("BETWEEN requires AND")
    highExpression = self~parseValueExpression
    return .SQLBetweenPredicate~new(leftExpression, lowExpression, highExpression)
  end

  validOp = .false
  if next = "=" then validOp = .true
  if next = "<>" then validOp = .true
  if next = "!=" then validOp = .true
  if next = "<" then validOp = .true
  if next = "<=" then validOp = .true
  if next = ">" then validOp = .true
  if next = ">=" then validOp = .true
  if \validOp then raise syntax 93.900 additional("Unsupported predicate operator:" next)

  rightExpression = self~parseValueExpression
  if leftExpression~isA(.SQLColumnValueExpression) then do
    if rightExpression~isA(.SQLColumnValueExpression) then return .SQLColumnComparisonPredicate~new(leftExpression~reference, next, rightExpression~reference)
    if rightExpression~isA(.SQLLiteralValueExpression) then return .SQLComparisonPredicate~new(leftExpression~reference, next, rightExpression~value)
  end
  return .SQLExpressionComparisonPredicate~new(leftExpression, next, rightExpression)

::method parseValueExpression private
  left = self~parseValueAtom
  do while self~peek = "||"
    self~take
    right = self~parseValueAtom
    left = .SQLConcatValueExpression~new(left, right)
  end
  return left

::method parseValueAtom private
  token = self~take
  if token == .nil then raise syntax 93.900 additional("Expected value expression")
  upper = token~translate
  if self~peek = "(" then do
    if upper = "CAST" then do
      self~take
      child = self~parseValueExpression
      asToken = self~take
      if asToken == .nil then raise syntax 93.900 additional("CAST requires AS")
      if asToken~translate \= "AS" then raise syntax 93.900 additional("CAST requires AS")
      target = self~take
      if target == .nil then raise syntax 93.900 additional("CAST requires target type")
      if target~translate \= "VARCHAR" then raise syntax 93.900 additional("Unsupported CAST target:" target)
      if self~take \= ")" then raise syntax 93.900 additional("Missing ')' in CAST")
      return .SQLCastValueExpression~new(child, target)
    end
    if upper \= "UPPER" & upper \= "LOWER" & upper \= "SUBSTR" & upper \= "CHAR_LENGTH" & upper \= "CHARACTER_LENGTH" & upper \= "OCTET_LENGTH" & ,
       upper \= "ST_SRID" & upper \= "ST_GEOMETRYTYPE" & upper \= "ST_X" & upper \= "ST_Y" & ,
       upper \= "ST_WITHIN" & upper \= "ST_INTERSECTS" then ,
      raise syntax 93.900 additional("Unsupported SQL function:" token)
    self~take
    args = .array~new
    if self~peek \= ")" then do
      do forever
        args~append(self~parseValueExpression)
        if self~peek = "," then do
          self~take
          iterate
        end
        leave
      end
    end
    if self~take \= ")" then raise syntax 93.900 additional("Missing ')' in SQL function")
    return .SQLFunctionValueExpression~new(upper, args)
  end
  if token~translate = "NULL" then return .SQLLiteralValueExpression~new(.nil)
  if token~translate = "TRUE" then return .SQLLiteralValueExpression~new("TRUE")
  if token~translate = "FALSE" then return .SQLLiteralValueExpression~new("FALSE")
  if token~length >= 2 then do
    first = token~left(1)
    last = token~right(1)
    if first = "'" & last = "'" then return .SQLLiteralValueExpression~new(self~literalValue(token))
    if first = '"' & last = '"' then return .SQLLiteralValueExpression~new(self~literalValue(token))
  end
  if datatype(token, "N") then return .SQLLiteralValueExpression~new(token)
  return .SQLColumnValueExpression~new(token)

::method looksLikeColumnReference private
  use arg token
  text = token~strip
  if text~pos(".") = 0 then return .false
  if datatype(text, "N") then return .false
  first = text~left(1)
  if first = "'" then return .false
  if first = '"' then return .false
  return .true

::method peek private
  if self~position > self~tokens~items then return ""
  return self~tokens[self~position]

::method take private
  if self~position > self~tokens~items then return .nil
  value = self~tokens[self~position]
  self~position += 1
  return value

::method literalValue private
  use arg token
  if token~translate = "NULL" then return .nil
  if token~length >= 2 then do
    first = token~left(1)
    last = token~right(1)
    quoted = .false
    if first = "'" then do
      if last = "'" then quoted = .true
    end
    if first = '"' then do
      if last = '"' then quoted = .true
    end
    if quoted then do
      inner = token~substr(2, token~length - 2)
      return inner~changeStr(first || first, first)
    end
  end
  return token

::method tokenize private
  use arg text
  out = .array~new
  current = ""
  quote = ""
  i = 1
  do while i <= text~length
    ch = text~substr(i, 1)
    if quote \= "" then do
      current ||= ch
      if ch = quote then do
        doubled = .false
        if i < text~length then do
          if text~substr(i + 1, 1) = quote then doubled = .true
        end
        if doubled then do
          current ||= quote
          i += 1
        end
        else quote = ""
      end
    end
    else if ch = "'" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      quote = ch
      current = ch
    end
    else if ch = '"' then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      quote = ch
      current = ch
    end
    else if ch = " " then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
    end
    else if ch = "09"x then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
    end
    else if ch = "(" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      out~append(ch)
    end
    else if ch = "," then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      out~append(ch)
    end
    else if ch = ")" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      out~append(ch)
    end
    else if ch = "<" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      op = ch
      if i < text~length then do
        n = text~substr(i + 1, 1)
        if n = "=" then do
          op ||= n
          i += 1
        end
        else if n = ">" then do
          op ||= n
          i += 1
        end
      end
      out~append(op)
    end
    else if ch = ">" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      op = ch
      if i < text~length then do
        if text~substr(i + 1, 1) = "=" then do
          op ||= "="
          i += 1
        end
      end
      out~append(op)
    end
    else if ch = "|" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      if i < text~length then do
        if text~substr(i + 1, 1) = "|" then do
          out~append("||")
          i += 1
        end
        else raise syntax 93.900 additional("Unexpected predicate token: |")
      end
      else raise syntax 93.900 additional("Unexpected predicate token: |")
    end
    else if ch = "!" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      if i < text~length then do
        if text~substr(i + 1, 1) = "=" then do
          out~append("!=")
          i += 1
        end
        else out~append(ch)
      end
      else out~append(ch)
    end
    else if ch = "=" then do
      if current \= "" then do
        out~append(current)
        current = ""
      end
      out~append(ch)
    end
    else current ||= ch
    i += 1
  end
  if quote \= "" then raise syntax 93.900 additional("Unterminated quoted literal")
  if current \= "" then out~append(current)
  return out

::class DelimitedTableStorage public
::attribute tablePath
::attribute definition
::attribute dataPath

::method init
  use arg tablePath, definition
  self~tablePath = tablePath
  self~definition = definition
  self~dataPath = tablePath || "/data"

::method newCsv
  use arg path = .nil, headers = .true
  if path == .nil then path = self~dataPath
  csv = .CsvStream~new(path, headers)
  csv~delimiter = self~definition~delimiterDefinition~resolved
  csv~qualifier = self~definition~qualifier
  return csv

::method isTombstoneFields private
  use arg fields
  if fields == .nil then return .false
  if fields~items \= 1 then return .false
  value = fields[1]
  if value == .nil then return .false
  value = value~string
  if value~length = 0 then return .false
  if value~verify(self~definition~tombstoneByte, "N") = 0 then return .true
  return .false

::method fieldsToRow private
  use arg fields
  vals = .table~new
  rawVals = .table~new
  typeNames = .table~new
  i = 1
  do col over self~definition~columns
    value = fields[i]
    if value == .nil then value = ""
    rawVals[col~name] = value
    typeNames[col~name] = col~type
    if value == self~definition~nullToken then do
      vals[col~name] = .nil
      rawVals[col~name] = .nil
    end
    else vals[col~name] = col~coerce(value)
    i += 1
  end
  return .DatabaseRow~new(vals, rawVals, typeNames)

::method readLocatedRows
  entries = .array~new
  if stream(self~dataPath, "c", "query exists") = "" then return entries

  csv = self~newCsv(self~dataPath, self~definition~header)
  csv~open("READ")
  state = csv~state
  if state \= "READY:" then do
    if state \= "READY" then raise syntax 93.900 additional("Unable to open table data:" self~dataPath)
  end

  nextPhysicalLine = 1
  if self~definition~header then nextPhysicalLine = 2

  do while csv~chars > 0
    startLine = nextPhysicalLine
    fields = csv~csvLineIn
    rawText = csv~rawText
    consumedLines = rawText~countStr(csv~lineEnd) + 1
    nextPhysicalLine += consumedLines

    if fields~items = 0 then iterate
    if self~isTombstoneFields(fields) then iterate

    entry = .table~new
    entry["row"] = self~fieldsToRow(fields)
    entry["line"] = startLine
    entry["lineCount"] = consumedLines
    entries~append(entry)
  end
  csv~close
  return entries

::method readRows
  rowsOut = .array~new
  do entry over self~readLocatedRows
    rowsOut~append(entry["row"])
  end
  return rowsOut

::method validateWritableValue private
  use arg value
  if value == .nil then return .true
  text = value~string
  if text~pos(self~definition~tombstoneByte) > 0 then raise syntax 93.900 additional("Value contains reserved table tombstone byte x" || self~definition~tombstoneHex)
  return .true

::method writeRows
  use arg rows
  tmp = self~dataPath || ".new"
  csv = self~newCsv(tmp, .true)
  csv~open("WRITE REPLACE")
  headers = csv~getHeaders
  i = 1
  do name over self~definition~columnNames
    headers~field(i)~name = name
    i += 1
  end
  csv~setHeaders(headers)
  do row over rows
    values = .array~new
    i = 1
    do name over self~definition~columnNames
      v = row[name]
      if v == .nil then v = self~definition~nullToken
      ignore = self~validateWritableValue(v)
      if .NoSQLUnicodeSupport~isUnicodeValue(v) then values[i] = .NoSQLUnicodeSupport~raw(v)
      else values[i] = v
      i += 1
    end
    csv~csvLineOut(values)
  end
  csv~close
  call SysFileDelete self~dataPath || ".old"
  if stream(self~dataPath, "c", "query exists") \= "" then do
    moveRc = SysFileMove(self~dataPath, self~dataPath || ".old")
    if moveRc \= 0 then raise syntax 93.900 additional("Unable to retire old table data")
  end
  moveRc = SysFileMove(tmp, self~dataPath)
  if moveRc \= 0 then raise syntax 93.900 additional("Unable to install new table data")
  call SysFileDelete self~dataPath || ".old"
  return rows~items

::method appendRow
  use arg row
  csv = self~newCsv(self~dataPath, self~definition~header)
  csv~open("WRITE APPEND")
  values = .array~new
  i = 1
  do name over self~definition~columnNames
    v = row[name]
    if v == .nil then v = self~definition~nullToken
    ignore = self~validateWritableValue(v)
    if .NoSQLUnicodeSupport~isUnicodeValue(v) then values[i] = .NoSQLUnicodeSupport~raw(v)
    else values[i] = v
    i += 1
  end
  csv~csvLineOut(values)
  csv~close
  return 1

::method preferTombstoneMutation
  size = stream(self~dataPath, "c", "query size")
  if size == "" then size = 0
  return size >= self~definition~tombstoneThresholdBytes

::method physicalLineCount
  if stream(self~dataPath, "c", "query exists") = "" then return 0
  s = .stream~new(self~dataPath)
  s~open("READ")
  count = 0
  do while s~lines > 0
    ignore = s~linein
    count += 1
  end
  s~close
  return count

::method rawPhysicalLine
  use arg lineNumber
  s = .stream~new(self~dataPath)
  s~open("READ")
  line = s~linein(lineNumber)
  s~close
  return line

::method isPhysicalLineTombstone
  use arg lineNumber
  line = self~rawPhysicalLine(lineNumber)
  if line~length = 0 then return .false
  if line~verify(self~definition~tombstoneByte, "N") = 0 then return .true
  return .false

::method physicalLineStartByte private
  use arg lineNumber
  if lineNumber < 1 then raise syntax 93.900 additional("Physical line number must be positive")
  s = .stream~new(self~dataPath)
  s~open("READ")
  data = s~charin(, s~chars)
  s~close
  pos = 1
  if lineNumber = 1 then return pos
  do n = 1 to lineNumber - 1
    nl = data~pos(x2c("0A"), pos)
    if nl = 0 then raise syntax 93.900 additional("Physical line does not exist:" lineNumber)
    pos = nl + 1
  end
  return pos

::method tombstonePhysicalLine
  use arg lineNumber
  oldLine = self~rawPhysicalLine(lineNumber)
  if oldLine~length = 0 then raise syntax 93.900 additional("Cannot tombstone empty/nonexistent physical line:" lineNumber)
  filler = self~definition~tombstoneByte~copies(oldLine~length)
  bytePos = self~physicalLineStartByte(lineNumber)
  s = .stream~new(self~dataPath)
  s~open("WRITE")
  rc = s~charout(filler, bytePos)
  s~close
  if rc \= 0 then raise syntax 93.900 additional("Unable to tombstone physical line:" lineNumber)
  return oldLine~length

::method compact
  rows = self~readRows
  self~writeRows(rows)
  return rows~items

::class FileDatabaseTable public
::attribute path
::attribute definition
::attribute storage
::attribute engine

::method init
  use arg path, engine = .nil
  self~path = path
  self~engine = engine
  self~definition = .TableDefinition~new(path || "/table.yaml")
  self~storage = .DelimitedTableStorage~new(path, self~definition)
  self~recoverPendingPhysicalMutation

::method pendingMutationPath private
  return self~path || "/pending-mutation.yaml"

::method beginPendingPhysicalMutation private
  use arg operation, oldLine, expectedNewLine, changes, rowCount
  raw = .table~new
  raw["operation"] = operation
  raw["timestamp"] = .DateTime~new~utcIsoDate
  raw["oldLine"] = oldLine
  raw["expectedNewLine"] = expectedNewLine
  raw["changes"] = changes
  raw["rowCount"] = rowCount
  raw["targetGeneration"] = self~definition~generation + 1
  raw["phase"] = "PREPARED"
  .Yaml~toYamlFile(raw, self~pendingMutationPath)
  return raw["targetGeneration"]

::method setPendingPhysicalPhase private
  use arg phase
  p = self~pendingMutationPath
  if stream(p, "c", "query exists") = "" then return .false
  raw = .Yaml~new~parseFile(p)
  raw["phase"] = phase
  .Yaml~toYamlFile(raw, p)
  return .true

::method clearPendingPhysicalMutation private
  call SysFileDelete self~pendingMutationPath
  return .true

::method ensureMutationJournal private
  use arg generation, operation, changes, timestamp = .nil
  journalPath = self~path || "/journal"
  call SysMkDir journalPath
  fileName = generation~format(10,0)~strip~changestr(" ", "0") || ".yaml"
  journalFile = journalPath || "/" || fileName
  if stream(journalFile, "c", "query exists") \= "" then return .true
  event = .table~new
  event["generation"] = generation
  event["operation"] = operation
  if timestamp == .nil then timestamp = .DateTime~new~utcIsoDate
  event["timestamp"] = timestamp
  if changes \== .nil then event["changes"] = changes
  .Yaml~toYamlFile(event, journalFile)
  return .true

::method recordMutationAtGeneration private
  use arg operation, changes, rowCount, targetGeneration, timestamp = .nil
  raw = .Yaml~new~parseFile(self~path || "/table.yaml")
  current = raw["generation"]
  if current == .nil then current = 0
  if current < targetGeneration then do
    raw["generation"] = targetGeneration
    if rowCount \== .nil then raw["rowCount"] = rowCount
    .Yaml~toYamlFile(raw, self~path || "/table.yaml")
    self~definition~generation = targetGeneration
    if rowCount \== .nil then self~definition~rowCount = rowCount
  end
  ignore = self~ensureMutationJournal(targetGeneration, operation, changes, timestamp)
  return targetGeneration

::method recoverPendingPhysicalMutation private
  p = self~pendingMutationPath
  if stream(p, "c", "query exists") = "" then return .true

  raw = .Yaml~new~parseFile(p)
  operation = raw["operation"]
  mutationTimestamp = raw["timestamp"]
  oldLine = raw["oldLine"]
  expectedNewLine = raw["expectedNewLine"]
  changes = raw["changes"]
  rowCount = raw["rowCount"]
  targetGeneration = raw["targetGeneration"]

  if self~definition~generation >= targetGeneration then do
    ignore = self~ensureMutationJournal(targetGeneration, operation, changes, mutationTimestamp)
    self~clearPendingPhysicalMutation
    return .true
  end

  if operation = "UPDATE" then do
    newExists = self~storage~physicalLineCount >= expectedNewLine
    if newExists then do
      if \self~storage~isPhysicalLineTombstone(oldLine) then ignore = self~storage~tombstonePhysicalLine(oldLine)
      ignore = self~recordMutationAtGeneration(operation, changes, rowCount, targetGeneration, mutationTimestamp)
    end
    -- If the append never happened, authoritative old row is intact: abort intent.
    self~clearPendingPhysicalMutation
    return .true
  end

  if operation = "DELETE" then do
    if self~storage~isPhysicalLineTombstone(oldLine) then ,
      ignore = self~recordMutationAtGeneration(operation, changes, rowCount, targetGeneration, mutationTimestamp)
    self~clearPendingPhysicalMutation
    return .true
  end

  self~clearPendingPhysicalMutation
  return .true

::method readRows
  return self~storage~readRows

::method rowCount
  count = self~definition~rowCount
  if count == .nil then return self~readRows~items
  return count

::method selectAll
  return self~storage~readRows

::method selectWhere
  use arg predicate
  found = .array~new
  do row over self~storage~readRows
    if predicate == .nil then found~append(row)
    else do
      if predicate~evaluate(row, self~definition) then found~append(row)
    end
  end
  return found

::method emitMutationEvent private
  use arg type, operation, changes, canVeto = .false
  if self~engine == .nil then return .nil
  event = .DatabaseEvent~new(type, self~definition~name, operation, changes, self~engine, canVeto)
  if canVeto then do
    self~engine~events~dispatch(event)
    if event~vetoed then raise syntax 93.900 additional(event~vetoMessage)
    return event
  end
  signal on syntax name afterEventError
  self~engine~events~dispatch(event)
  signal off syntax
  return event
afterEventError:
  signal off syntax
  return event

::method primaryKeyFastCache private
  if self~engine == .nil then return .nil
  if self~definition~primaryKey~items \= 1 then return .nil
  if self~definition~uniqueConstraints~items > 0 then return .nil
  return self~engine~primaryKeyCache(self~definition~name)

::method primaryKeyEntryForPredicate private
  use arg predicate
  cache = self~primaryKeyFastCache
  if cache == .nil then return .nil
  if \predicate~isA(.SQLComparisonPredicate) then return .nil
  if predicate~operator \= "=" then return .nil
  pkName = self~definition~primaryKey[1]
  canonical = self~definition~canonicalColumn(predicate~column)
  if canonical == .nil then return .nil
  if \canonical~caselessEquals(pkName) then return .nil
  col = self~definition~column(pkName)
  wanted = col~coerce(predicate~value)
  probe = .DatabaseRow~new
  probe[pkName] = wanted
  sig = self~primaryKeySignature(probe)
  out = .table~new
  out["cache"] = cache
  out["signature"] = sig
  out["entry"] = cache~lookup(sig)
  return out

::method validateFastPrimaryKeyCandidate private
  use arg candidate, cache, ignoreSignature = .nil
  do col over self~definition~columns
    if candidate[col~name] == .nil then do
      if \col~nullable then raise syntax 93.900 additional("NOT NULL constraint failed:" col~name)
    end
  end
  pkName = self~definition~primaryKey[1]
  if candidate[pkName] == .nil then raise syntax 93.900 additional("PRIMARY KEY may not contain NULL:" pkName)
  sig = self~primaryKeySignature(candidate)
  existing = cache~lookup(sig)
  if existing \== .nil then do
    if ignoreSignature == .nil then raise syntax 93.900 additional("PRIMARY KEY constraint failed")
    if sig \= ignoreSignature then raise syntax 93.900 additional("PRIMARY KEY constraint failed")
  end
  return sig

::method rowPhysicalLineCount private
  use arg row
  count = 1
  do name over self~definition~columnNames
    v = row[name]
    if v == .nil then iterate
    count += v~string~countStr(x2c("0A"))
  end
  return count

::method insert
  use arg values
  if values~isA(.DatabaseRow) then inputRow = values
  else inputRow = .DatabaseRow~new(values)
  row = self~definition~coerceRow(inputRow)

  cache = self~primaryKeyFastCache
  if cache \== .nil then do
    sig = self~validateFastPrimaryKeyCandidate(row, cache)
    changes = .array~new
    change = .table~new
    change["after"] = row~values~copy
    changes~append(change)
    ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_INSERT, "INSERT", changes, .true)

    physicalLine = cache~lastPhysicalLine + 1
    lineCount = self~rowPhysicalLineCount(row)
    change["newPhysicalLine"] = physicalLine
    self~storage~appendRow(row)
    rowCount = self~definition~rowCount
    if rowCount == .nil then rowCount = cache~entries~items
    rowCount += 1
    generation = self~recordMutation("INSERT", changes, rowCount)
    ignore = cache~add(sig, row, physicalLine, lineCount, generation)
    ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_INSERT, "INSERT", changes, .false)
    return 1
  end

  rows = self~storage~readRows
  self~validateConstraints(row, rows, .nil)
  rows~append(row)
  changes = .array~new
  change = .table~new
  change["after"] = row~values~copy
  changes~append(change)
  ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_INSERT, "INSERT", changes, .true)
  self~storage~appendRow(row)
  generation = self~recordMutation("INSERT", changes, rows~items)
  if self~engine \== .nil then ignore = self~engine~invalidatePrimaryKeyCache(self~definition~name)
  ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_INSERT, "INSERT", changes, .false)
  return 1

::method insertMany
  use arg valuesRows
  rows = self~storage~readRows
  candidateRows = .array~new
  do existingRow over rows
    candidateRows~append(existingRow)
  end
  insertedRows = .array~new
  do values over valuesRows
    if values~isA(.DatabaseRow) then inputRow = values
    else inputRow = .DatabaseRow~new(values)
    row = self~definition~coerceRow(inputRow)
    candidateRows~append(row)
    insertedRows~append(row)
  end
  checkNumber = 0
  do candidate over candidateRows
    checkNumber += 1
    self~validateConstraints(candidate, candidateRows, checkNumber)
  end
  if insertedRows~items > 0 then do
    changes = .array~new
    do row over insertedRows
      change = .table~new
      change["after"] = row~values~copy
      changes~append(change)
    end
    ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_INSERT, "INSERT", changes, .true)
    self~storage~writeRows(candidateRows)
    self~recordMutation("INSERT", changes, candidateRows~items)
    if self~engine \== .nil then ignore = self~engine~invalidatePrimaryKeyCache(self~definition~name)
    ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_INSERT, "INSERT", changes, .false)
  end
  return insertedRows~items

::method updateWhere
  use arg predicate, assignments
  normalized = .table~new
  do key over assignments
    c = self~definition~canonicalColumn(key)
    if c == .nil then raise syntax 93.900 additional("Unknown column:" key)
    col = self~definition~column(c)
    normalized[c] = col~coerce(assignments[key])
  end

  fast = self~primaryKeyEntryForPredicate(predicate)
  if fast \== .nil then do
    entry = fast["entry"]
    if entry == .nil then return 0
    if entry["lineCount"] = 1 then do
      if self~storage~preferTombstoneMutation then do
        row = entry["row"]
        candidate = row~copy
        do key over normalized
          candidate[key] = normalized[key]
        end
        candidate = self~definition~coerceRow(candidate)
        newSig = self~validateFastPrimaryKeyCandidate(candidate, fast["cache"], fast["signature"])

        changes = .array~new
        change = .table~new
        change["before"] = row~values~copy
        change["after"] = candidate~values~copy
        change["oldPhysicalLine"] = entry["line"]
        changes~append(change)
        ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_UPDATE, "UPDATE", changes, .true)

        expectedNewLine = fast["cache"]~lastPhysicalLine + 1
        change["newPhysicalLine"] = expectedNewLine
        targetGeneration = self~beginPendingPhysicalMutation("UPDATE", entry["line"], expectedNewLine, changes, self~definition~rowCount)
        self~storage~appendRow(candidate)
        ignore = self~setPendingPhysicalPhase("APPENDED")
        ignore = self~storage~tombstonePhysicalLine(entry["line"])
        ignore = self~setPendingPhysicalPhase("TOMBSTONED")
        generation = self~recordMutationAtGeneration("UPDATE", changes, self~definition~rowCount, targetGeneration)
        self~clearPendingPhysicalMutation
        ignore = fast["cache"]~replace(fast["signature"], newSig, candidate, expectedNewLine, self~rowPhysicalLineCount(candidate), generation)
        ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_UPDATE, "UPDATE", changes, .false)
        return 1
      end
    end
  end

  located = self~storage~readLocatedRows
  rows = .array~new
  do entry over located
    rows~append(entry["row"])
  end

  newRows = .array~new
  changes = .array~new
  changedCandidates = .array~new
  changedRowNumbers = .array~new
  affected = 0
  matchedEntry = .nil
  matchedCandidate = .nil
  rowNumber = 0

  do entry over located
    row = entry["row"]
    rowNumber += 1
    matched = .true
    if predicate \== .nil then matched = predicate~evaluate(row, self~definition)
    if matched then do
      candidate = row~copy
      do key over normalized
        candidate[key] = normalized[key]
      end
      candidate = self~definition~coerceRow(candidate)
      newRows~append(candidate)
      changedCandidates~append(candidate)
      changedRowNumbers~append(rowNumber)

      change = .table~new
      change["before"] = row~values~copy
      change["after"] = candidate~values~copy
      change["oldPhysicalLine"] = entry["line"]
      changes~append(change)

      affected += 1
      matchedEntry = entry
      matchedCandidate = candidate
    end
    else newRows~append(row)
  end

  if affected > 0 then do
    do checkNumber = 1 to changedCandidates~items
      candidate = changedCandidates[checkNumber]
      self~validateConstraints(candidate, newRows, changedRowNumbers[checkNumber])
    end

    ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_UPDATE, "UPDATE", changes, .true)

    -- Fast path: one single-physical-line row. Append replacement first, then
    -- tombstone old line. The pending intent makes an interrupted append-first
    -- update recoverable without ever preferring data loss.
    useFastPhysical = .false
    if affected = 1 then do
      if matchedEntry \== .nil then do
        if matchedEntry["lineCount"] = 1 then do
          if self~storage~preferTombstoneMutation then useFastPhysical = .true
        end
      end
    end
    if useFastPhysical then do
      expectedNewLine = self~storage~physicalLineCount + 1
      changes[1]["newPhysicalLine"] = expectedNewLine
      targetGeneration = self~beginPendingPhysicalMutation("UPDATE", matchedEntry["line"], expectedNewLine, changes, rows~items)
      self~storage~appendRow(matchedCandidate)
      ignore = self~setPendingPhysicalPhase("APPENDED")
      ignore = self~storage~tombstonePhysicalLine(matchedEntry["line"])
      ignore = self~setPendingPhysicalPhase("TOMBSTONED")
      ignore = self~recordMutationAtGeneration("UPDATE", changes, rows~items, targetGeneration)
      self~clearPendingPhysicalMutation
    end
    else do
      self~storage~writeRows(newRows)
      self~recordMutation("UPDATE", changes, newRows~items)
      if self~engine \== .nil then ignore = self~engine~invalidatePrimaryKeyCache(self~definition~name)
    end

    ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_UPDATE, "UPDATE", changes, .false)
  end
  return affected

::method deleteWhere
  use arg predicate

  fast = self~primaryKeyEntryForPredicate(predicate)
  if fast \== .nil then do
    entry = fast["entry"]
    if entry == .nil then return 0
    if entry["lineCount"] = 1 then do
      if self~storage~preferTombstoneMutation then do
        row = entry["row"]
        changes = .array~new
        change = .table~new
        change["before"] = row~values~copy
        change["oldPhysicalLine"] = entry["line"]
        changes~append(change)
        ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_DELETE, "DELETE", changes, .true)

        newRowCount = self~definition~rowCount
        if newRowCount == .nil then newRowCount = fast["cache"]~entries~items
        newRowCount -= 1
        targetGeneration = self~beginPendingPhysicalMutation("DELETE", entry["line"], .nil, changes, newRowCount)
        ignore = self~storage~tombstonePhysicalLine(entry["line"])
        ignore = self~setPendingPhysicalPhase("TOMBSTONED")
        generation = self~recordMutationAtGeneration("DELETE", changes, newRowCount, targetGeneration)
        self~clearPendingPhysicalMutation
        ignore = fast["cache"]~remove(fast["signature"], generation)
        ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_DELETE, "DELETE", changes, .false)
        return 1
      end
    end
  end

  located = self~storage~readLocatedRows
  rows = .array~new
  kept = .array~new
  changes = .array~new
  affected = 0
  matchedEntry = .nil

  do entry over located
    row = entry["row"]
    rows~append(row)
    matched = .true
    if predicate \== .nil then matched = predicate~evaluate(row, self~definition)
    if matched then do
      affected += 1
      matchedEntry = entry
      change = .table~new
      change["before"] = row~values~copy
      change["oldPhysicalLine"] = entry["line"]
      changes~append(change)
    end
    else kept~append(row)
  end

  if affected > 0 then do
    ignore = self~emitMutationEvent(.DatabaseEventType~BEFORE_DELETE, "DELETE", changes, .true)

    useFastPhysical = .false
    if affected = 1 then do
      if matchedEntry \== .nil then do
        if matchedEntry["lineCount"] = 1 then do
          if self~storage~preferTombstoneMutation then useFastPhysical = .true
        end
      end
    end
    if useFastPhysical then do
      targetGeneration = self~beginPendingPhysicalMutation("DELETE", matchedEntry["line"], .nil, changes, kept~items)
      ignore = self~storage~tombstonePhysicalLine(matchedEntry["line"])
      ignore = self~setPendingPhysicalPhase("TOMBSTONED")
      ignore = self~recordMutationAtGeneration("DELETE", changes, kept~items, targetGeneration)
      self~clearPendingPhysicalMutation
    end
    else do
      self~storage~writeRows(kept)
      self~recordMutation("DELETE", changes, kept~items)
      if self~engine \== .nil then ignore = self~engine~invalidatePrimaryKeyCache(self~definition~name)
    end

    ignore = self~emitMutationEvent(.DatabaseEventType~AFTER_DELETE, "DELETE", changes, .false)
  end
  return affected

::method compactStorage
  count = self~storage~compact
  if self~engine \== .nil then ignore = self~engine~invalidatePrimaryKeyCache(self~definition~name)
  return count

::method generation
  return self~definition~generation

::method recordMutation private
  use arg operation, changes = .nil, rowCount = .nil
  nextGeneration = self~definition~generation + 1
  raw = .Yaml~new~parseFile(self~path || "/table.yaml")
  raw["generation"] = nextGeneration
  if rowCount \== .nil then raw["rowCount"] = rowCount
  .Yaml~toYamlFile(raw, self~path || "/table.yaml")
  self~definition~generation = nextGeneration
  if rowCount \== .nil then self~definition~rowCount = rowCount

  journalPath = self~path || "/journal"
  call SysMkDir journalPath
  event = .table~new
  event["generation"] = nextGeneration
  event["operation"] = operation
  event["timestamp"] = .DateTime~new~utcIsoDate
  if changes \== .nil then event["changes"] = changes
  fileName = nextGeneration~format(10,0)~strip~changestr(" ", "0") || ".yaml"
  .Yaml~toYamlFile(event, journalPath || "/" || fileName)
  return nextGeneration

::method primaryKeySignature
  use arg row
  sig = ""
  first = .true
  do name over self~definition~primaryKey
    if \first then sig ||= "1F"x
    v = row[name]
    if v == .nil then v = ""
    sig ||= v~string
    first = .false
  end
  return sig

::method selectWhereEquals
  use arg column, wanted
  return self~selectWhere(.SQLComparisonPredicate~new(column, "=", wanted))

::method updateWhereEquals
  use arg whereColumn, wanted, assignments
  return self~updateWhere(.SQLComparisonPredicate~new(whereColumn, "=", wanted), assignments)

::method deleteWhereEquals
  use arg whereColumn, wanted
  return self~deleteWhere(.SQLComparisonPredicate~new(whereColumn, "=", wanted))

::method validateConstraints private
  use arg candidate, existingRows, ignoreRowNumber = .nil

  do col over self~definition~columns
    if candidate[col~name] == .nil then do
      if \col~nullable then raise syntax 93.900 additional("NOT NULL constraint failed:" col~name)
    end
  end

  pk = self~definition~primaryKey
  if pk~items > 0 then do
    do name over pk
      if candidate[name] == .nil then raise syntax 93.900 additional("PRIMARY KEY may not contain NULL:" name)
    end
    if self~constraintExists(candidate, existingRows, pk, ignoreRowNumber) then
      raise syntax 93.900 additional("PRIMARY KEY constraint failed")
  end

  do constraint over self~definition~uniqueConstraints
    anyNull = .false
    do name over constraint
      if candidate[name] == .nil then anyNull = .true
    end
    if \anyNull then do
      if self~constraintExists(candidate, existingRows, constraint, ignoreRowNumber) then
        raise syntax 93.900 additional("UNIQUE constraint failed")
    end
  end

::method constraintExists private
  use arg candidate, existingRows, columns, ignoreRowNumber = .nil
  rowNumber = 0
  do row over existingRows
    rowNumber += 1
    skip = .false
    if ignoreRowNumber \== .nil then do
      if rowNumber = ignoreRowNumber then skip = .true
    end
    if \skip then do
      same = .true
      do name over columns
        if candidate[name] == .nil then do
          if row[name] \== .nil then same = .false
        end
        else do
          if row[name] == .nil then same = .false
          else do
            col = self~definition~column(name)
            if \col~compare(row[name], "=", candidate[name]) then same = .false
          end
        end
      end
      if same then return .true
    end
  end
  return .false

::class ObjectTableMapping public
::attribute tableName
::attribute columns
::attribute identityColumn
::attribute factoryObject
::attribute factoryMessage
::attribute removalPolicy

::method init
  use arg tableName = ""
  self~tableName = tableName
  self~columns = .array~new
  self~identityColumn = ""
  self~factoryObject = .nil
  self~factoryMessage = ""
  self~removalPolicy = ""

::method table
  use arg name
  self~tableName = name
  return self

::method column
  use arg name, typeName, getter, setter = ""
  spec = .table~new
  spec["name"] = name~string
  spec["type"] = typeName~string~translate
  spec["getter"] = getter~string
  spec["setter"] = setter~string
  self~columns~append(spec)
  return self

::method identity
  use arg columnName
  self~identityColumn = columnName~string
  return self

::method columnSpec
  use arg wanted
  do spec over self~columns
    if spec["name"]~caselessEquals(wanted) then return spec
  end
  return .nil

::method factory
  use arg factoryObject, factoryMessage = "newRow"
  self~factoryObject = factoryObject
  self~factoryMessage = factoryMessage~string
  return self

::method removal
  use arg policy
  self~removalPolicy = policy~string~translate
  return self

::class ObjectTableDefinition public
::attribute name
::attribute columns
::attribute columnNames
::attribute primaryKey
::attribute uniqueConstraints
::attribute rowCount

::method init
  use arg mapping, rowCount = 0
  self~name = mapping~tableName
  self~columns = .array~new
  self~columnNames = .array~new
  self~primaryKey = .array~new
  self~uniqueConstraints = .array~new
  self~rowCount = rowCount
  do spec over mapping~columns
    pk = .false
    if mapping~identityColumn \= "" then do
      if spec["name"]~caselessEquals(mapping~identityColumn) then pk = .true
    end
    col = .DatabaseColumn~new(spec["name"], spec["type"], .true, pk, pk)
    self~columns~append(col)
    self~columnNames~append(spec["name"])
    if pk then self~primaryKey~append(spec["name"])
  end

::method canonicalColumn
  use arg wanted
  do col over self~columns
    if col~name~caselessEquals(wanted) then return col~name
  end
  return .nil

::method column
  use arg wanted
  canonical = self~canonicalColumn(wanted)
  if canonical == .nil then return .nil
  do col over self~columns
    if col~name = canonical then return col
  end
  return .nil

::class ObjectTableStorage public
::attribute collection
::attribute mapping
::attribute definition

::method init
  use arg collection, mapping
  self~collection = collection
  self~mapping = mapping
  self~definition = .ObjectTableDefinition~new(mapping, collection~items)

::method locatedRows
  entries = .array~new
  objectIndex = 0
  do object over self~collection
    objectIndex += 1
    values = .table~new
    rawValues = .table~new
    typeNames = .table~new
    do spec over self~mapping~columns
      getter = spec["getter"]
      signal on syntax name getterFailure
      value = object~send(getter)
      signal off syntax
      col = self~definition~column(spec["name"])
      if value == .nil then coerced = .nil
      else coerced = col~coerce(value)
      values[spec["name"]] = coerced
      rawValues[spec["name"]] = value
      typeNames[spec["name"]] = spec["type"]
    end
    entry=.table~new
    entry["object"]=object
    entry["index"]=objectIndex
    entry["row"]=.DatabaseRow~new(values,rawValues,typeNames)
    entries~append(entry)
  end
  self~definition~rowCount = entries~items
  return entries
getterFailure:
  signal off syntax
  raise syntax 93.900 additional("Object table getter failed: " || getter)

::method readRows
  rows=.array~new
  do entry over self~locatedRows
    rows~append(entry["row"])
  end
  return rows

::method freeze
  rows=.array~new
  do row over self~readRows
    rows~append(row~copy)
  end
  return .ObjectSnapshotTableStorage~new(self~definition, rows)

::class ObjectSnapshotTableStorage public
::attribute definition
::attribute rows

::method init
  use arg sourceDefinition, sourceRows
  self~definition = sourceDefinition
  self~rows = .array~new
  do row over sourceRows
    self~rows~append(row~copy)
  end
  self~definition~rowCount = self~rows~items

::method readRows
  out=.array~new
  do row over self~rows
    out~append(row~copy)
  end
  return out

::class ObjectSnapshotDatabaseTable public
::attribute definition
::attribute storage
::attribute generation
::attribute mapping

::method init
  use arg storage, mapping, generation = 0
  self~storage = storage
  self~definition = storage~definition
  self~mapping = mapping
  self~generation = generation

::method readRows
  return self~storage~readRows

::method rowCount
  return self~definition~rowCount

::method isSnapshot
  return .true

::class ObjectDatabaseTable public
::attribute definition
::attribute storage
::attribute mapping
::attribute generation
::attribute engine

::method init
  use arg collection, mapping, engine = .nil
  self~engine = engine
  self~mapping = mapping
  self~storage = .ObjectTableStorage~new(collection, mapping)
  self~definition = self~storage~definition
  self~generation = 0

::method readRows
  return self~storage~readRows

::method rowCount
  return self~readRows~items

::method isSnapshot
  return .false

::method freeze
  return .ObjectSnapshotDatabaseTable~new(self~storage~freeze, self~mapping, self~generation)

::method insertRow
  use arg inputRow
  if self~mapping~factoryObject == .nil then raise syntax 93.900 additional("Object table INSERT requires an explicit mapping factory")
  if self~mapping~factoryMessage = "" then raise syntax 93.900 additional("Object table INSERT factory message is empty")

  values=.table~new
  rawValues=.table~new
  typeNames=.table~new
  do spec over self~mapping~columns
    name=spec["name"]
    col=self~definition~column(name)
    value=inputRow[name]
    if value==.nil then coerced=.nil
    else coerced=col~coerce(value)
    values[name]=coerced
    rawValues[name]=value
    typeNames[name]=spec["type"]
  end
  row=.DatabaseRow~new(values,rawValues,typeNames)

  -- Identity collision check is explicit and happens before factory side effects.
  if self~mapping~identityColumn \= "" then do
    idName=self~definition~canonicalColumn(self~mapping~identityColumn)
    wanted=row[idName]
    do existing over self~storage~readRows
      if existing[idName] == .nil then iterate
      if wanted == .nil then iterate
      if existing[idName]~string = wanted~string then raise syntax 93.900 additional("Object table identity constraint failed:" idName)
    end
  end

  signal on syntax name factoryFailure
  object=self~mapping~factoryObject~send(self~mapping~factoryMessage,row)
  signal off syntax
  if object == .nil then raise syntax 93.900 additional("Object table factory returned NIL")

  -- Prove mapped getters exist before mutating the collection.
  do spec over self~mapping~columns
    if \object~hasMethod(spec["getter"]) then raise syntax 93.900 additional("Factory object lacks mapped getter:" spec["getter"])
  end

  changes=.array~new
  change=.table~new
  change["after"]=row~values~copy
  changes~append(change)
  if self~engine \== .nil then do
    event=.DatabaseEvent~new(.DatabaseEventType~BEFORE_INSERT,self~definition~name,"INSERT",changes,self~engine,.true)
    self~engine~events~dispatch(event)
    if event~vetoed then raise syntax 93.900 additional(event~vetoMessage)
  end

  self~storage~collection~append(object)
  self~generation += 1
  self~definition~rowCount = self~storage~collection~items

  if self~engine \== .nil then do
    event=.DatabaseEvent~new(.DatabaseEventType~AFTER_INSERT,self~definition~name,"INSERT",changes,self~engine,.false)
    signal on syntax name insertAfterIgnored
    self~engine~events~dispatch(event)
    signal off syntax
  end
  return 1
factoryFailure:
  signal off syntax
  raise syntax 93.900 additional("Object table factory failed")
insertAfterIgnored:
  signal off syntax
  return 1

::method deleteWhere
  use arg predicate
  if self~mapping~removalPolicy \= "ARRAY_DELETE" then raise syntax 93.900 additional("Object table DELETE requires ARRAY_DELETE removal policy")

  targets=.array~new
  changes=.array~new
  do entry over self~storage~locatedRows
    row=entry["row"]
    matched=.true
    if predicate \== .nil then matched=predicate~evaluate(row,self~definition)
    if matched then do
      targets~append(entry)
      change=.table~new
      change["before"]=row~values~copy
      changes~append(change)
    end
  end
  if targets~items=0 then return 0

  if self~engine \== .nil then do
    event=.DatabaseEvent~new(.DatabaseEventType~BEFORE_DELETE,self~definition~name,"DELETE",changes,self~engine,.true)
    self~engine~events~dispatch(event)
    if event~vetoed then raise syntax 93.900 additional(event~vetoMessage)
  end

  -- Delete descending indexes so earlier removals never shift later targets.
  do i=targets~items to 1 by -1
    entry=targets[i]
    ignore=self~storage~collection~delete(entry["index"])
  end
  self~generation += 1
  self~definition~rowCount = self~storage~collection~items

  if self~engine \== .nil then do
    event=.DatabaseEvent~new(.DatabaseEventType~AFTER_DELETE,self~definition~name,"DELETE",changes,self~engine,.false)
    signal on syntax name deleteAfterIgnored
    self~engine~events~dispatch(event)
    signal off syntax
  end
  return targets~items
deleteAfterIgnored:
  signal off syntax
  return targets~items

::method updateWhere
  use arg predicate, assignments
  normalized=.table~new
  do key over assignments
    canonical=self~definition~canonicalColumn(key)
    if canonical==.nil then raise syntax 93.900 additional("Unknown object column:" key)
    spec=self~mapping~columnSpec(canonical)
    if spec["setter"]="" then raise syntax 93.900 additional("Object column is read-only:" canonical)
    normalized[canonical]=self~definition~column(canonical)~coerce(assignments[key])
  end

  targets=.array~new
  changes=.array~new
  do entry over self~storage~locatedRows
    row=entry["row"]
    matched=.true
    if predicate \== .nil then matched=predicate~evaluate(row,self~definition)
    if matched then do
      candidate=row~copy
      do key over normalized
        candidate[key]=normalized[key]
      end
      target=.table~new; target["object"]=entry["object"]; target["before"]=row; target["after"]=candidate
      targets~append(target)
      change=.table~new; change["before"]=row~values~copy; change["after"]=candidate~values~copy
      changes~append(change)
    end
  end
  if targets~items=0 then return 0

  -- Validate all mapped setters before the first side effect.
  do target over targets
    object=target["object"]
    do key over normalized
      spec=self~mapping~columnSpec(key)
      if \object~hasMethod(spec["setter"]) then raise syntax 93.900 additional("Mapped object setter not found:" spec["setter"])
    end
  end

  if self~engine \== .nil then do
    event=.DatabaseEvent~new(.DatabaseEventType~BEFORE_UPDATE,self~definition~name,"UPDATE",changes,self~engine,.true)
    self~engine~events~dispatch(event)
    if event~vetoed then raise syntax 93.900 additional(event~vetoMessage)
  end

  do target over targets
    object=target["object"]
    after=target["after"]
    do key over normalized
      spec=self~mapping~columnSpec(key)
      signal on syntax name setterFailure
      object~send(spec["setter"],after[key])
      signal off syntax
    end
  end

  self~generation += 1
  if self~engine \== .nil then do
    event=.DatabaseEvent~new(.DatabaseEventType~AFTER_UPDATE,self~definition~name,"UPDATE",changes,self~engine,.false)
    signal on syntax name afterIgnored
    self~engine~events~dispatch(event)
    signal off syntax
  end
  return targets~items
setterFailure:
  signal off syntax
  raise syntax 93.900 additional("Object table setter failed")
afterIgnored:
  signal off syntax
  return targets~items

::class ObjectQueryPatternLog public
::method record
  return 0
::method recordJoin
  return 0
::method candidates
  return .array~new
::method joinCandidates
  return .array~new

::class ObjectUnsupportedTransaction public
::method execute
  rs=.DatabaseResult~new(.DatabaseOperationType~STATEMENT)
  return rs~fail(.Error~SQLUNSUPPORTED,"Transactions over live object tables require a unit-of-work model")
::method query
  forward message "EXECUTE"
::method commit
  rs=.DatabaseResult~new(.DatabaseOperationType~COMMIT)
  return rs~fail(.Error~SQLUNSUPPORTED,"Transactions over live object tables require a unit-of-work model")
::method rollback
  rs=.DatabaseResult~new(.DatabaseOperationType~ROLLBACK)
  return rs~fail(.Error~SQLUNSUPPORTED,"No object-table transaction was started")

::class ObjectDatabaseEngine subclass NoSQLAlchemyObject public
::attribute tables
::attribute queryLog
::attribute events

::method init
  use arg alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("OBJECT_ENGINE", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("REGISTER", "register a live object relation", "MUTATE")
  self~registerNoSQLMethod("REGISTERSNAPSHOT", "register a frozen object relation", "MUTATE")
  self~registerNoSQLMethod("SELECTWHERE", "query object relations with a predicate", "READ")
  self~registerNoSQLMethod("TRANSACTION", "return the object-relation unit-of-work boundary", "READ")
  self~tables = .table~new
  self~queryLog = .ObjectQueryPatternLog~new
  self~events = .DatabaseEventRegistry~new("OBJECT")

::method register
  use arg name, collection, mapping
  if mapping == .nil then return .false
  if mapping~tableName = "" then mapping~tableName = name
  self~tables[name~translate] = .ObjectDatabaseTable~new(collection, mapping, self)
  return .true

::method registerSnapshot
  use arg name, collection, mapping
  if mapping == .nil then return .false
  if mapping~tableName = "" then mapping~tableName = name
  live = .ObjectDatabaseTable~new(collection, mapping, self)
  self~tables[name~translate] = live~freeze
  return .true

::method snapshotTable
  use arg sourceName, snapshotName
  source=self~table(sourceName)
  if source==.nil then return .false
  if source~isSnapshot then do
    self~tables[snapshotName~translate]=source
    return .true
  end
  self~tables[snapshotName~translate]=source~freeze
  return .true

::method table
  use arg name
  return self~tables[name~translate]

::method version
  v = .NoSQLServerVersionInfo~new(0)
  v~engine = "OBJECT"
  v~storage = "LIVE_OBJECTS"
  filtered=.array~new
  do feature over v~features
    upper=feature~translate
    if upper~startsWith("TRANSACTION") then iterate
    if upper="SAVEPOINTS" then iterate
    if upper~startsWith("PREPARED_") then iterate
    filtered~append(feature)
  end
  v~features=filtered
  return v

::method transaction
  return .ObjectUnsupportedTransaction~new

::method mutationGraph
  return .nil

::method queryPatternLog
  return self~queryLog

::method tableRowCount
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return t~rowCount

::method currentIndexCandidateCount
  return .nil

::method joinMapSnapshot
  return .nil

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::method selectWhere
  use arg tableName, predicate
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  allRows = t~readRows
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "OBJECT_TABLE_SCAN"
  rs~snapshotGeneration = t~generation
  return rs

::method selectJoin
  use arg leftTableName, leftColumn, rightTableName, rightColumn
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  left = self~table(leftTableName); right = self~table(rightTableName)
  if left == .nil then return rs~fail(.Error~NOTFOUND,"Table not found:" leftTableName)
  if right == .nil then return rs~fail(.Error~NOTFOUND,"Table not found:" rightTableName)
  lc = left~definition~canonicalColumn(leftColumn); rc = right~definition~canonicalColumn(rightColumn)
  if lc == .nil | rc == .nil then return rs~fail(.Error~SCHEMAERROR,"Unknown join column")
  leftRows=left~readRows; rightRows=right~readRows
  buckets=.table~new
  do row over rightRows
    value=row[rc]
    if value==.nil then iterate
    arr=buckets[value~string]
    if arr==.nil then arr=.array~new
    arr~append(row); buckets[value~string]=arr
  end
  out=.array~new
  do lrow over leftRows
    value=lrow[lc]
    if value==.nil then iterate
    matches=buckets[value~string]
    if matches==.nil then iterate
    do rrow over matches
      out~append(self~qualifiedJoinRow(left,lrow,right,rrow))
    end
  end
  rs~rows=out; rs~affectedRows=out~items
  rs~rowsScanned=leftRows~items+rightRows~items
  rs~accessPath="OBJECT_JOIN_SCAN"
  return rs

::method selectJoinWithSidePredicate
  use arg leftTableName,leftColumn,rightTableName,rightColumn,side,predicate
  -- v0.53 correctness-first: materialize join then evaluate qualified predicate
  rs=self~selectJoin(leftTableName,leftColumn,rightTableName,rightColumn)
  if rs~status \= .Error~SUCCESS then return rs
  left=self~table(leftTableName); right=self~table(rightTableName)
  entries=.array~new
  e=.table~new; e["definition"]=left~definition; e["alias"]=left~definition~name; entries~append(e)
  e=.table~new; e["definition"]=right~definition; e["alias"]=right~definition~name; entries~append(e)
  relation=.SQLAliasRelationDefinition~new(entries)
  out=.array~new
  do row over rs~rows
    if predicate~evaluate(row,relation) then out~append(row)
  end
  rs~rows=out; rs~affectedRows=out~items; rs~accessPath="OBJECT_JOIN_PREFILTER_SCAN"
  return rs

::method selectCrossJoin
  use arg leftTableName,rightTableName
  rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
  left=self~table(leftTableName); right=self~table(rightTableName)
  if left==.nil | right==.nil then return rs~fail(.Error~NOTFOUND,"Cross join table not found")
  leftRows=left~readRows; rightRows=right~readRows; out=.array~new
  do lrow over leftRows
    do rrow over rightRows
      out~append(self~qualifiedJoinRow(left,lrow,right,rrow))
    end
  end
  rs~rows=out; rs~affectedRows=out~items; rs~rowsScanned=leftRows~items+rightRows~items; rs~accessPath="OBJECT_CROSS_SCAN"
  return rs

::method selectCrossJoinWithSidePredicate
  use arg leftTableName,rightTableName,side,predicate
  rs=self~selectCrossJoin(leftTableName,rightTableName)
  return rs

::method qualifiedJoinRow private
  use arg left,leftRow,right,rightRow
  values=.table~new
  do col over left~definition~columns
    values[left~definition~name || "." || col~name]=leftRow[col~name]
  end
  do col over right~definition~columns
    values[right~definition~name || "." || col~name]=rightRow[col~name]
  end
  return .DatabaseRow~new(values)

::method insert
  use arg tableName, values
  rs=.DatabaseResult~new(.DatabaseOperationType~INSERT)
  t=self~table(tableName)
  if t==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" tableName)
  if t~isSnapshot then return rs~fail(.Error~SQLUNSUPPORTED,"Object snapshot tables are read-only")
  signal on syntax name objectInsertError
  rs~affectedRows=t~insertRow(values)
  signal off syntax
  return rs
objectInsertError:
  conditionObject=condition("O"); signal off syntax
  messageText=conditionObject["MESSAGE"]
  if messageText==.nil | messageText="" then messageText=conditionObject["ADDITIONAL"]
  if messageText==.nil then messageText="Object INSERT failed"
  return rs~fail(.Error~STATEMENTFAILED,messageText~string)

::method insertMany
  use arg tableName, rows
  rs=.DatabaseResult~new(.DatabaseOperationType~INSERT)
  return rs~fail(.Error~SQLUNSUPPORTED,"Object-table multi-row INSERT requires an atomic factory batch contract")
::method updateWhere
  use arg tableName,predicate,assignments
  rs=.DatabaseResult~new(.DatabaseOperationType~UPDATE)
  t=self~table(tableName)
  if t==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" tableName)
  if t~isSnapshot then return rs~fail(.Error~SQLUNSUPPORTED,"Object snapshot tables are read-only")
  signal on syntax name objectUpdateError
  rs~affectedRows=t~updateWhere(predicate,assignments)
  signal off syntax
  return rs
objectUpdateError:
  conditionObject=condition("O"); signal off syntax
  messageText=conditionObject["MESSAGE"]
  if messageText==.nil | messageText="" then messageText=conditionObject["ADDITIONAL"]
  if messageText==.nil then messageText="Object UPDATE failed"
  return rs~fail(.Error~STATEMENTFAILED,messageText~string)
::method deleteWhere
  use arg tableName,predicate
  rs=.DatabaseResult~new(.DatabaseOperationType~DELETE)
  t=self~table(tableName)
  if t==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" tableName)
  if t~isSnapshot then return rs~fail(.Error~SQLUNSUPPORTED,"Object snapshot tables are read-only")
  signal on syntax name objectDeleteError
  rs~affectedRows=t~deleteWhere(predicate)
  signal off syntax
  return rs
objectDeleteError:
  conditionObject=condition("O"); signal off syntax
  messageText=conditionObject["MESSAGE"]
  if messageText==.nil | messageText="" then messageText=conditionObject["ADDITIONAL"]
  if messageText==.nil then messageText="Object DELETE failed"
  return rs~fail(.Error~STATEMENTFAILED,messageText~string)
::method createTable
  rs=.DatabaseResult~new(.DatabaseOperationType~CREATE_TABLE)
  return rs~fail(.Error~SQLUNSUPPORTED,"DDL does not create ooRexx classes")
::method dropTable
  rs=.DatabaseResult~new(.DatabaseOperationType~DROP_TABLE)
  return rs~fail(.Error~SQLUNSUPPORTED,"DDL does not destroy ooRexx classes")




/*
 * v0.73 JSON relation provider
 *
 * JSON remains a structured document.  SQL sees only projections explicitly
 * registered by the caller; nested objects/arrays are never recursively
 * flattened by NoSQLServer.  A projected object/array is carried as canonical
 * JSON text at that explicit projection boundary.
 */
::class JsonColumnProjection public
::attribute name
::attribute path
::attribute type
::attribute nullable
::attribute textMode

::method init
  use arg name, path, type = "VARCHAR", nullable = .true, textMode = "CLASSIC"
  self~name = name~string
  self~path = path~string
  self~type = type~string~translate
  self~nullable = nullable
  self~textMode = textMode~string~translate

/*
 * Deliberately small JSONPath subset used only at the explicit relational
 * projection boundary: $, .member, [index], and [*] for row selection.
 * JSON array indexes are zero-based; ooRexx arrays are one-based internally.
 */
::class JsonProjectionPath public
::method validate class
  use arg path, wildcardAllowed = .false
  if path == .nil then return .false
  text = path~string
  if text = "" | text~left(1) \= "$" then return .false
  i = 2
  do while i <= text~length
    ch = text~substr(i, 1)
    if ch = "." then do
      i += 1
      start = i
      do while i <= text~length
        c = text~substr(i, 1)
        if c = "." | c = "[" then leave
        i += 1
      end
      if i = start then return .false
    end
    else if ch = "[" then do
      close = text~pos("]", i + 1)
      if close = 0 then return .false
      inner = text~substr(i + 1, close - i - 1)
      if inner = "*" then do
        if \wildcardAllowed then return .false
      end
      else do
        if \datatype(inner, "W") then return .false
        if inner < 0 then return .false
      end
      i = close + 1
    end
    else return .false
  end
  return .true

::method resolve class
  use arg root, path
  if \self~validate(path, .false) then raise syntax 93.900 additional("Invalid JSON projection path:" path)
  current = root
  text = path~string
  i = 2
  do while i <= text~length
    ch = text~substr(i, 1)
    if ch = "." then do
      i += 1
      start = i
      do while i <= text~length
        c = text~substr(i, 1)
        if c = "." | c = "[" then leave
        i += 1
      end
      name = text~substr(start, i - start)
      if current == .nil then return .nil
      if \current~isA(.Directory) then return .nil
      current = current[name]
    end
    else if ch = "[" then do
      close = text~pos("]", i + 1)
      inner = text~substr(i + 1, close - i - 1)
      if current == .nil then return .nil
      if \current~isA(.Array) then return .nil
      index = inner + 1
      if index < 1 | index > current~items then return .nil
      current = current[index]
      i = close + 1
    end
  end
  return current

::method resolveRows class
  use arg root, path
  if \self~validate(path, .true) then raise syntax 93.900 additional("Invalid JSON row path:" path)
  current = .array~of(root)
  text = path~string
  i = 2
  lastWasWildcard = .false
  do while i <= text~length
    ch = text~substr(i, 1)
    next = .array~new
    if ch = "." then do
      i += 1
      start = i
      do while i <= text~length
        c = text~substr(i, 1)
        if c = "." | c = "[" then leave
        i += 1
      end
      name = text~substr(start, i - start)
      do item over current
        if item == .nil then iterate
        if \item~isA(.Directory) then iterate
        value = item[name]
        if value \== .nil then next~append(value)
      end
      lastWasWildcard = .false
    end
    else if ch = "[" then do
      close = text~pos("]", i + 1)
      inner = text~substr(i + 1, close - i - 1)
      if inner = "*" then do
        do item over current
          if item == .nil then iterate
          if \item~isA(.Array) then iterate
          do value over item
            next~append(value)
          end
        end
        lastWasWildcard = .true
      end
      else do
        index = inner + 1
        do item over current
          if item == .nil then iterate
          if \item~isA(.Array) then iterate
          if index >= 1 & index <= item~items then next~append(item[index])
        end
        lastWasWildcard = .false
      end
      i = close + 1
    end
    current = next
  end
  -- Convenience: a row path resolving to one array implies its members.
  if \lastWasWildcard & current~items = 1 then do
    only = current[1]
    if only~isA(.Array) then do
      expanded = .array~new
      do value over only
        expanded~append(value)
      end
      return expanded
    end
  end
  return current

::method relationalValue class
  use arg value
  if value == .nil then return .nil
  if value~isA(.JsonBoolean) then do
    if value~value then return "TRUE"
    return "FALSE"
  end
  if value~isA(.Directory) | value~isA(.Array) then return .json~toJSON(value)
  return value~string

::class JsonDatabaseTable public
::attribute path
::attribute rowPath
::attribute projections
::attribute definition
::attribute generation

::method init
  use arg path, name, rowPath, projections
  self~path = path
  self~rowPath = rowPath
  self~projections = projections
  self~generation = 0

  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["columns"] = .array~new
  do projection over projections
    c = .table~new
    c["name"] = projection~name
    c["type"] = projection~type
    c["nullable"] = projection~nullable
    c["textMode"] = projection~textMode
    raw["columns"]~append(c)
  end
  self~definition = .TableDefinition~new(raw)

::method readRows
  document = .json~fromJsonFile(self~path)
  sourceRows = .JsonProjectionPath~resolveRows(document, self~rowPath)
  rows = .array~new
  do sourceRow over sourceRows
    values = .table~new
    rawValues = .table~new
    typeNames = .table~new
    do projection over self~projections
      raw = .JsonProjectionPath~resolve(sourceRow, projection~path)
      value = .JsonProjectionPath~relationalValue(raw)
      values[projection~name] = value
      rawValues[projection~name] = value
      typeNames[projection~name] = projection~type
    end
    projected = .DatabaseRow~new(values, rawValues, typeNames)
    rows~append(self~definition~coerceRow(projected))
  end
  return rows

::method rowCount
  return self~readRows~items

::class JsonDatabaseEngine subclass NoSQLAlchemyObject public
::attribute path
::attribute tables
::attribute queryLog

::method init
  use arg path, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("JSON_ENGINE", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("REGISTERPROJECTION", "register an explicit JSON relational projection", "MUTATE")
  self~registerNoSQLMethod("EXECUTE", "execute SQL against JSON projections", "READ")
  self~registerNoSQLMethod("QUERY", "query JSON projections", "READ")
  self~path = path
  self~tables = .table~new
  self~queryLog = .NullQueryPatternLog~new

::method registerProjection
  use arg name, rowPath, projections
  if name == .nil | name~string~strip = "" then return .false
  if rowPath == .nil | \ .JsonProjectionPath~validate(rowPath, .true) then return .false
  if projections == .nil | \projections~isA(.array) | projections~items = 0 then return .false
  do projection over projections
    if \projection~isA(.JsonColumnProjection) then return .false
    if \.JsonProjectionPath~validate(projection~path, .false) then return .false
  end
  key = name~string~translate
  self~tables[key] = .JsonDatabaseTable~new(self~path, name~string, rowPath~string, projections)
  return .true

::method table
  use arg name
  return self~tables[name~string~translate]

::method tableNames
  names = .array~new
  do key over self~tables~allIndexes
    names~append(self~tables[key]~definition~name)
  end
  return names

::method readCatalog
  catalog = .table~new
  catalog["tables"] = self~tableNames
  return catalog

::method tableRowCount
  use arg name
  t = self~table(name)
  if t == .nil then return .nil
  return t~rowCount

::method queryPatternLog
  return self~queryLog

::method currentIndexCandidateCount
  return .nil

::method joinMapSnapshot
  return .nil

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::method selectWhere
  use arg tableName, predicate
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "JSON projection not found:" tableName)
  signal on syntax name jsonReadError
  allRows = t~readRows
  signal off syntax
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "JSON_PROJECTION_SCAN"
  return rs
jsonReadError:
  conditionObject = condition("O"); signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "JSON projection read failed"
  return rs~fail(.Error~STORAGEERROR, messageText~string)

::method execute
  use arg sqlText
  return .NoSQLServerSQL~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)~execute(sqlText)

::method query
  use arg sqlText
  return self~execute(sqlText)

::method version
  v = .NoSQLServerVersionInfo~new(0)
  v~engine = "JSON"
  v~storage = "JSON_READ_ONLY"
  v~features = .array~of("JSON_EXPLICIT_RELATION_PROJECTION", "JSON_NESTED_PATH_PROJECTION", "DATABASE_CORE_V034_RELATIONAL_SOURCE")
  return v

::class SQLiteDatabaseTable public
::attribute definition
::attribute nativeDatabase
::attribute nativeTable
::attribute generation

::method init
  use arg nativeDatabase, nativeTable, rawDefinition
  self~nativeDatabase = nativeDatabase
  self~nativeTable = nativeTable
  self~definition = .TableDefinition~new(rawDefinition)
  self~generation = 0

::method readRows
  nativeRows = self~nativeDatabase~rows(self~definition~name)
  rows = .array~new
  do nativeRow over nativeRows
    values = .table~new
    do name over nativeRow~allIndexes
      values[name] = nativeRow[name]
    end
    rows~append(.DatabaseRow~new(values))
  end
  return rows

::method rowCount
  return self~definition~rowCount


::class SQLiteDatabaseEngine subclass NoSQLAlchemyObject public
::attribute path
::attribute tables
::attribute queryLog
::attribute nativeDatabase

::method init
  use arg path, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("SQLITE_ENGINE", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("EXECUTE", "execute read-only SQL against native SQLite relations", "READ")
  self~registerNoSQLMethod("QUERY", "query native SQLite relations", "READ")
  self~path = path
  self~tables = .table~new
  self~queryLog = .NullQueryPatternLog~new
  self~nativeDatabase = .SQLiteNativeDatabase~new(path)
  self~discover

::method sqliteType private
  use arg declaredType
  upper = declaredType~translate
  if upper~pos("INT") > 0 then return "INTEGER"
  if upper~pos("REAL") > 0 | upper~pos("FLOA") > 0 | upper~pos("DOUB") > 0 | upper~pos("NUM") > 0 | upper~pos("DEC") > 0 then return "DECIMAL"
  if upper = "DATE" then return "DATE"
  if upper = "DATETIME" then return "DATETIME"
  if upper~pos("BLOB") > 0 then return "BLOB"
  return "TEXT"

::method discover private
  native = self~nativeDatabase
  do nativeTable over native~schema
    raw = .table~new
    raw["name"] = nativeTable~name
    raw["columns"] = .array~new
    raw["generation"] = 0
    if nativeTable~withoutRowid then raw["rowCount"] = .nil
    else raw["rowCount"] = native~rowCount(nativeTable~name)
    do nativeColumn over nativeTable~columns
      col = .table~new
      col["name"] = nativeColumn~name
      col["type"] = self~sqliteType(nativeColumn~declaredType)
      col["nullable"] = \nativeColumn~notNull
      col["primaryKey"] = nativeColumn~primaryKey
      raw["columns"]~append(col)
    end
    self~tables[nativeTable~name] = .SQLiteDatabaseTable~new(native, nativeTable, raw)
  end
  return self~tables~items

::method table
  use arg name
  direct = self~tables[name]
  if direct \== .nil then return direct
  do key over self~tables~allIndexes
    if key~caselessEquals(name) then return self~tables[key]
  end
  return .nil

::method tableNames
  names = .array~new
  do name over self~tables~allIndexes
    names~append(name)
  end
  return names

::method tableRowCount
  use arg name
  t = self~table(name)
  if t == .nil then return .nil
  return t~rowCount

::method queryPatternLog
  return self~queryLog

::method currentIndexCandidateCount
  return .nil

::method joinMapSnapshot
  return .nil

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::method selectWhere
  use arg tableName, predicate
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "SQLite table not found:" tableName)
  signal on syntax name sqliteReadError
  allRows = t~readRows
  signal off syntax
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "SQLITE_NATIVE_SCAN"
  return rs
sqliteReadError:
  conditionObject = condition("O"); signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Native SQLite read failed"
  return rs~fail(.Error~STORAGEERROR, messageText~string)

::method execute
  use arg sqlText
  return .NoSQLServerSQL~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)~execute(sqlText)

::method query
  use arg sqlText
  return self~execute(sqlText)

::method databaseCore
  return .NoSQLDatabaseCoreAdapter~new(self)

::method tableMetadata
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return .DatabaseTableMetadata~new(t~definition)

::method queryTable
  use arg tableName
  queryResult = self~selectAll(tableName)
  if queryResult~status = .Error~SUCCESS then queryResult~metadata = self~tableMetadata(tableName)
  return queryResult

::method readCatalog
  raw = .table~new
  raw["name"] = self~path
  raw["formatVersion"] = 1
  raw["tables"] = self~tableNames
  return raw

::method version
  v = .NoSQLServerVersionInfo~new
  v~engine = "SQLITE"
  v~storage = "SQLITE_NATIVE_READONLY"
  v~features = .array~of("SQLITE_NATIVE_BINARY_READ","SQLITE_NATIVE_RELATION_PROVIDER","DATABASE_CORE_V034_RELATIONAL_SOURCE")
  return v

::method eventLog
  return .array~new

::method transactionManager
  return .nil


::class GeoPackageGeometry public
::attribute hex
::attribute geometryType
::attribute srid

::method init
  use arg hex, geometryType = "", srid = 0
  self~hex = hex~string~translate
  self~geometryType = geometryType
  self~srid = srid

::method string
  type = self~geometryType
  if type = "" then type = "GEOMETRY"
  return type || "(SRID=" || self~srid || ",GPKG_BLOB=" || self~hex~left(24) || "...)"

/*
 * v0.76 spatial kernel.
 *
 * Deliberately narrow and exact: decode GeoPackage binary containing 2D WKB
 * POINT or POLYGON.  ST_WITHIN is implemented for POINT within POLYGON;
 * ST_INTERSECTS supports POINT/POINT and POINT/POLYGON in either order.
 * Unsupported geometry kinds fail explicitly instead of being approximated.
 */
::class NoSQLSpatialSupport public

::method geometryObject class private
  use arg value
  if value == .nil then return .nil
  if value~isA(.GeoPackageGeometry) then return value
  if value~isA(.DatabaseGeometryValue) then do
    inner = value~value
    if inner \== .nil then do
      if inner~isA(.GeoPackageGeometry) then return inner
    end
    if value~encoding = .DatabaseSpatialEncoding~GPKGBLOBHEX then ,
      return .GeoPackageGeometry~new(value~rawValue, value~geometryType, value~srid)
  end
  raise syntax 93.900 additional("Spatial function requires a typed GeoPackage geometry value")

::method parse class
  numeric digits 40
  use arg value
  geometry = self~geometryObject(value)
  if geometry == .nil then return .nil
  hex = geometry~hex~string~translate
  if hex~length // 2 \= 0 then raise syntax 93.900 additional("Invalid GeoPackage geometry hex length")
  bytes = x2c(hex)
  if bytes~length < 13 then raise syntax 93.900 additional("Truncated GeoPackage geometry")
  if bytes~substr(1, 2) \= "GP" then raise syntax 93.900 additional("GeoPackage geometry magic is missing")
  flags = c2d(bytes~substr(4, 1))
  little = flags // 2
  envelopeCode = (flags % 2) // 8
  emptyFlag = (flags % 16) // 2
  if emptyFlag = 1 then raise syntax 93.900 additional("Empty GeoPackage geometry is not supported by spatial predicates")
  envelopeBytes = 0
  select
    when envelopeCode = 0 then envelopeBytes = 0
    when envelopeCode = 1 then envelopeBytes = 32
    when envelopeCode = 2 | envelopeCode = 3 then envelopeBytes = 48
    when envelopeCode = 4 then envelopeBytes = 64
    otherwise raise syntax 93.900 additional("Invalid GeoPackage envelope code")
  end
  blobSrid = self~uint32(bytes, 5, little)
  wkbOffset = 9 + envelopeBytes
  if wkbOffset + 4 > bytes~length then raise syntax 93.900 additional("Truncated GeoPackage WKB")
  parsed = self~parseWkb(bytes, wkbOffset)
  declaredSrid = geometry~srid
  if declaredSrid \= 0 & blobSrid \= 0 & declaredSrid \= blobSrid then ,
    raise syntax 93.900 additional("GeoPackage geometry metadata/blob SRID mismatch:" declaredSrid "vs" blobSrid)
  if declaredSrid \= 0 then parsed["srid"] = declaredSrid
  else parsed["srid"] = blobSrid
  parsed["declaredType"] = geometry~geometryType~string~translate
  if parsed["declaredType"] \= "" & parsed["declaredType"] \= parsed["type"] then ,
    raise syntax 93.900 additional("GeoPackage geometry metadata/WKB type mismatch")
  return parsed

::method parseWkb class private
  numeric digits 40
  use arg bytes, offset
  byteOrder = c2d(bytes~substr(offset, 1))
  if byteOrder \= 0 & byteOrder \= 1 then raise syntax 93.900 additional("Invalid WKB byte order")
  little = byteOrder = 1
  typeCode = self~uint32(bytes, offset + 1, little)
  if typeCode = 1 then do
    if offset + 20 > bytes~length then raise syntax 93.900 additional("Truncated WKB POINT")
    out = .directory~new
    out["type"] = "POINT"
    out["x"] = self~float64(bytes, offset + 5, little)
    out["y"] = self~float64(bytes, offset + 13, little)
    return out
  end
  if typeCode = 3 then do
    ringCount = self~uint32(bytes, offset + 5, little)
    pos = offset + 9
    rings = .array~new
    do r = 1 to ringCount
      if pos + 3 > bytes~length then raise syntax 93.900 additional("Truncated WKB POLYGON ring count")
      pointCount = self~uint32(bytes, pos, little)
      pos += 4
      ring = .array~new
      do i = 1 to pointCount
        if pos + 15 > bytes~length then raise syntax 93.900 additional("Truncated WKB POLYGON coordinate")
        point = .directory~new
        point["x"] = self~float64(bytes, pos, little)
        point["y"] = self~float64(bytes, pos + 8, little)
        ring~append(point)
        pos += 16
      end
      if ring~items < 4 then raise syntax 93.900 additional("WKB POLYGON ring requires at least four positions")
      rings~append(ring)
    end
    if rings~items = 0 then raise syntax 93.900 additional("Empty WKB POLYGON is not supported")
    out = .directory~new
    out["type"] = "POLYGON"
    out["rings"] = rings
    return out
  end
  raise syntax 93.900 additional("Spatial WKB geometry type is not supported:" typeCode)

::method uint32 class private
  numeric digits 40
  use arg bytes, offset, little
  raw = bytes~substr(offset, 4)
  if raw~length \= 4 then raise syntax 93.900 additional("Truncated WKB uint32")
  if little then raw = self~reverseBytes(raw)
  return c2d(raw)

::method float64 class private
  numeric digits 40
  use arg bytes, offset, little
  raw = bytes~substr(offset, 8)
  if raw~length \= 8 then raise syntax 93.900 additional("Truncated WKB float64")
  if little then raw = self~reverseBytes(raw)
  bits = c2d(raw)
  sign = 1
  if bits >= 2 ** 63 then do
    sign = -1
    bits -= 2 ** 63
  end
  exponent = bits % (2 ** 52)
  fraction = bits // (2 ** 52)
  if exponent = 2047 then raise syntax 93.900 additional("WKB NaN/Infinity coordinate is not supported")
  if exponent = 0 then do
    if fraction = 0 then return 0 * sign
    value = (fraction / (2 ** 52)) * (2 ** -1022)
  end
  else value = (1 + fraction / (2 ** 52)) * (2 ** (exponent - 1023))
  return sign * value

::method reverseBytes class private
  use arg bytes
  out = ""
  do i = bytes~length to 1 by -1
    out ||= bytes~substr(i, 1)
  end
  return out

::method srid class
  use arg value
  parsed = self~parse(value)
  if parsed == .nil then return .nil
  return parsed["srid"]

::method geometryType class
  use arg value
  parsed = self~parse(value)
  if parsed == .nil then return .nil
  return parsed["type"]

::method x class
  use arg value
  parsed = self~parse(value)
  if parsed["type"] \= "POINT" then raise syntax 93.900 additional("ST_X requires POINT geometry")
  return parsed["x"]

::method y class
  use arg value
  parsed = self~parse(value)
  if parsed["type"] \= "POINT" then raise syntax 93.900 additional("ST_Y requires POINT geometry")
  return parsed["y"]

::method ensureSameSrid class private
  use arg left, right
  ls = left["srid"]
  rs = right["srid"]
  if ls \= 0 & rs \= 0 & ls \= rs then raise syntax 93.900 additional("Spatial predicate SRID mismatch:" ls "vs" rs)

::method within class
  use arg leftValue, rightValue
  left = self~parse(leftValue)
  right = self~parse(rightValue)
  self~ensureSameSrid(left, right)
  if left["type"] \= "POINT" | right["type"] \= "POLYGON" then ,
    raise syntax 93.900 additional("ST_WITHIN v0.76 supports POINT within POLYGON only")
  location = self~pointInPolygon(left["x"], left["y"], right["rings"])
  return location = "INSIDE"

::method intersects class
  use arg leftValue, rightValue
  left = self~parse(leftValue)
  right = self~parse(rightValue)
  self~ensureSameSrid(left, right)
  if left["type"] = "POINT" & right["type"] = "POINT" then ,
    return left["x"] = right["x"] & left["y"] = right["y"]
  if left["type"] = "POINT" & right["type"] = "POLYGON" then ,
    return self~pointInPolygon(left["x"], left["y"], right["rings"]) \= "OUTSIDE"
  if left["type"] = "POLYGON" & right["type"] = "POINT" then ,
    return self~pointInPolygon(right["x"], right["y"], left["rings"]) \= "OUTSIDE"
  raise syntax 93.900 additional("ST_INTERSECTS v0.76 supports POINT/POINT and POINT/POLYGON only")

::method pointInPolygon class private
  numeric digits 40
  use arg x, y, rings
  outer = self~pointInRing(x, y, rings[1])
  if outer = "BOUNDARY" then return "BOUNDARY"
  if outer = "OUTSIDE" then return "OUTSIDE"
  do r = 2 to rings~items
    hole = self~pointInRing(x, y, rings[r])
    if hole = "BOUNDARY" then return "BOUNDARY"
    if hole = "INSIDE" then return "OUTSIDE"
  end
  return "INSIDE"

::method pointInRing class private
  numeric digits 40
  use arg x, y, ring
  inside = .false
  do i = 1 to ring~items - 1
    a = ring[i]
    b = ring[i + 1]
    x1 = a["x"]; y1 = a["y"]
    x2 = b["x"]; y2 = b["y"]
    if self~pointOnSegment(x, y, x1, y1, x2, y2) then return "BOUNDARY"
    crosses = ((y1 > y) & (y2 <= y)) | ((y2 > y) & (y1 <= y))
    if crosses then do
      crossingX = x1 + ((y - y1) * (x2 - x1) / (y2 - y1))
      if crossingX > x then inside = \inside
    end
  end
  if inside then return "INSIDE"
  return "OUTSIDE"

::method pointOnSegment class private
  numeric digits 40
  use arg x, y, x1, y1, x2, y2
  cross = (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1)
  epsilon = 0.000000001
  if abs(cross) > epsilon then return .false
  if x < min(x1, x2) - epsilon | x > max(x1, x2) + epsilon then return .false
  if y < min(y1, y2) - epsilon | y > max(y1, y2) + epsilon then return .false
  return .true

::class GeoPackageDatabaseTable public
::attribute path
::attribute bridge
::attribute definition
::attribute geometryColumn
::attribute geometryType
::attribute srid
::attribute generation
::attribute nativeDatabase

::method init
  use arg path, bridge, rawDefinition, geometryColumn = "", geometryType = "", srid = 0, nativeDatabase = .nil
  self~path = path
  -- Kept only as a compatibility attribute for callers that inspect it.
  -- v0.74 never executes this value and never shells to a SQLite helper.
  self~bridge = bridge
  self~definition = .TableDefinition~new(rawDefinition)
  self~geometryColumn = geometryColumn
  self~geometryType = geometryType
  self~srid = srid
  self~generation = 0
  if nativeDatabase == .nil then nativeDatabase = .SQLiteNativeDatabase~new(path)
  self~nativeDatabase = nativeDatabase

::method readRows
  nativeRows = self~nativeDatabase~rows(self~definition~name)
  rows = .array~new
  do nativeRow over nativeRows
    values = .table~new
    do name over nativeRow~allIndexes
      value = nativeRow[name]
      if name~caselessEquals(self~geometryColumn) & value \== .nil then do
        if value~isA(.SQLiteNativeBlob) then value = .GeoPackageGeometry~new(value~hex, self~geometryType, self~srid)
      end
      values[name] = value
    end
    rows~append(.DatabaseRow~new(values))
  end
  return rows

::method rowCount
  return self~definition~rowCount

::class NullQueryPatternLog public
::method record
  return 0

::class GeoPackageDatabaseEngine subclass NoSQLAlchemyObject public
::attribute path
::attribute bridge
::attribute tables
::attribute queryLog
::attribute nativeDatabase

::method init
  use arg path, bridge = "", alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("GEOPACKAGE_ENGINE", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("EXECUTE", "execute read-only SQL against GeoPackage relations", "READ")
  self~registerNoSQLMethod("QUERY", "query GeoPackage relations", "READ")
  self~path = path
  -- The bridge argument remains accepted for source compatibility with v0.67+
  -- callers, but v0.74 is native ooRexx and does not invoke it.
  self~bridge = bridge
  self~tables = .table~new
  self~queryLog = .NullQueryPatternLog~new
  self~nativeDatabase = .SQLiteNativeDatabase~new(path)
  self~discover

::method sqliteType private
  use arg declaredType, isGeometry = .false
  if isGeometry then return "GEOMETRY"
  upper = declaredType~translate
  if upper~pos("INT") > 0 then return "INTEGER"
  if upper~pos("REAL") > 0 | upper~pos("FLOA") > 0 | upper~pos("DOUB") > 0 | upper~pos("NUM") > 0 | upper~pos("DEC") > 0 then return "DECIMAL"
  if upper = "DATE" then return "DATE"
  if upper = "DATETIME" then return "DATETIME"
  if upper~pos("BLOB") > 0 then return "BLOB"
  return "TEXT"

::method discover private
  native = self~nativeDatabase
  contentsTable = native~table("gpkg_contents")
  geometryTable = native~table("gpkg_geometry_columns")
  if contentsTable == .nil then raise syntax 93.900 additional("GeoPackage gpkg_contents table not found")

  geometryColumns = .table~new
  geometryTypes = .table~new
  geometrySrids = .table~new
  if geometryTable \== .nil then do
    do row over native~rows("gpkg_geometry_columns")
      tableName = row["table_name"]
      if tableName == .nil then iterate
      geometryColumns[tableName] = row["column_name"]
      geometryTypes[tableName] = row["geometry_type_name"]
      geometrySrids[tableName] = row["srs_id"]
    end
  end

  do content over native~rows("gpkg_contents")
    tableName = content["table_name"]
    if tableName == .nil then iterate
    nativeTable = native~table(tableName)
    if nativeTable == .nil then iterate
    if nativeTable~withoutRowid then raise syntax 93.900 additional("GeoPackage table uses unsupported WITHOUT ROWID storage:" tableName)

    geometryColumn = geometryColumns[tableName]
    if geometryColumn == .nil then geometryColumn = ""
    geometryType = geometryTypes[tableName]
    if geometryType == .nil then geometryType = ""
    srid = geometrySrids[tableName]
    if srid == .nil then srid = content["srs_id"]
    if srid == .nil then srid = 0

    raw = .table~new
    raw["name"] = tableName
    raw["columns"] = .array~new
    raw["generation"] = 0
    raw["rowCount"] = native~rowCount(tableName)

    do nativeColumn over nativeTable~columns
      col = .table~new
      col["name"] = nativeColumn~name
      isGeometry = nativeColumn~name~caselessEquals(geometryColumn)
      col["type"] = self~sqliteType(nativeColumn~declaredType, isGeometry)
      col["nullable"] = \nativeColumn~notNull
      col["primaryKey"] = nativeColumn~primaryKey
      raw["columns"]~append(col)
    end

    self~tables[tableName] = .GeoPackageDatabaseTable~new(self~path, self~bridge, raw, geometryColumn, geometryType, srid, native)
  end
  return self~tables~items

::method table
  use arg name
  direct = self~tables[name]
  if direct \== .nil then return direct
  do key over self~tables~allIndexes
    if key~caselessEquals(name) then return self~tables[key]
  end
  return .nil

::method tableNames
  names = .array~new
  do name over self~tables~allIndexes
    names~append(name)
  end
  return names

::method tableRowCount
  use arg name
  t = self~table(name)
  if t == .nil then return .nil
  return t~rowCount

::method queryPatternLog
  return self~queryLog

::method currentIndexCandidateCount
  return .nil

::method joinMapSnapshot
  return .nil

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::method selectWhere
  use arg tableName, predicate
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "GeoPackage table not found:" tableName)
  signal on syntax name nativeReadError
  allRows = t~readRows
  signal off syntax
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "GEOPACKAGE_NATIVE_SQLITE_SCAN"
  return rs
nativeReadError:
  conditionObject = condition("O"); signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Native SQLite/GeoPackage read failed"
  return rs~fail(.Error~STORAGEERROR, messageText~string)

::method execute
  use arg sqlText
  return .NoSQLServerSQL~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)~execute(sqlText)

::method query
  use arg sqlText
  return self~execute(sqlText)

::method databaseCore
  return .NoSQLDatabaseCoreAdapter~new(self)

::method tableMetadata
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return .DatabaseTableMetadata~new(t~definition, t~geometryColumn, t~geometryType, t~srid)

::method queryTable
  use arg tableName
  queryResult = self~selectAll(tableName)
  if queryResult~status = .Error~SUCCESS then queryResult~metadata = self~tableMetadata(tableName)
  return queryResult

::method readCatalog
  raw = .table~new
  raw["name"] = self~path
  raw["formatVersion"] = 1
  raw["tables"] = self~tableNames
  return raw

::method version
  v = .NoSQLServerVersionInfo~new
  v~engine = "GEOPACKAGE"
  v~storage = "SQLITE_GPKG_NATIVE_READONLY"
  v~features = .array~of("GEOPACKAGE_READ","GEOPACKAGE_SCHEMA_DISCOVERY","SQLITE_NATIVE_BINARY_READ","GEOMETRY_TYPED_VALUE","SPATIAL_POINT_POLYGON_FUNCTIONS","ST_WITHIN_POINT_POLYGON","ST_INTERSECTS_POINT_POLYGON","ST_GEOMETRY_ACCESSORS","DATABASE_CORE_V034_GEOMETRY","DATABASE_CORE_V034_RELATIONAL_SOURCE")
  return v

::method eventLog
  return .array~new

::method transactionManager
  return .nil

::class FederatedDatabaseEngine subclass NoSQLAlchemyObject public
::attribute fileEngine
::attribute objectEngine
::attribute externalEngines

::method init
  use arg fileRoot, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("FEDERATED_ENGINE", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("ADDENGINE", "attach an external relation provider", "MUTATE")
  self~registerNoSQLMethod("EXECUTE", "execute SQL across federated relation providers", "UNKNOWN")
  self~registerNoSQLMethod("QUERY", "query federated relations", "READ")
  self~fileEngine=.FileDatabaseEngine~new(fileRoot, .nil, alchemySealer, alchemyAuthority)
  self~objectEngine=.ObjectDatabaseEngine~new(alchemySealer, alchemyAuthority)
  self~externalEngines=.array~new

::method addEngine
  use arg engine
  self~externalEngines~append(engine)
  return engine

::method register
  use arg name,collection,mapping
  return self~objectEngine~register(name,collection,mapping)

::method registerSnapshot
  use arg name,collection,mapping
  return self~objectEngine~registerSnapshot(name,collection,mapping)

::method snapshotTable
  use arg sourceName,snapshotName
  return self~objectEngine~snapshotTable(sourceName,snapshotName)

/*
 * Federated engine facade parity.  Consumers above the database layer should
 * not need to know whether a table is FILE, OBJECT/SNAPSHOT, GeoPackage, or
 * another registered external provider.
 */
::method execute
  use arg sqlText
  return .NoSQLServerSQL~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)~execute(sqlText)

::method query
  use arg sqlText
  return self~execute(sqlText)

::method databaseCore
  return .NoSQLDatabaseCoreAdapter~new(self)

::method tableMetadata
  use arg tableName
  t = self~objectEngine~table(tableName)
  if t \== .nil then return self~metadataForTable(t)
  t = self~fileEngine~table(tableName)
  if t \== .nil then return self~metadataForTable(t)
  do engine over self~externalEngines
    t = engine~table(tableName)
    if t \== .nil then return self~metadataForTable(t)
  end
  return .nil

/*
 * Build metadata from the relation object rather than calling back into an
 * external engine package.  Older external adapters were written for the
 * v0.68 contract where federation owned DatabaseTableMetadata construction;
 * making the adapter instantiate NoSQLServer classes leaks package identity
 * across the provider boundary and can fail even when its relation definition
 * is otherwise perfectly usable.
 *
 * Geometry is capability-shaped: a relation that exposes geometryColumn,
 * geometryType and srid contributes those facts.  Ordinary FILE, OBJECT,
 * SNAPSHOT and Algorithm Relation tables need no provider-specific branch.
 */
::method metadataForTable private
  use arg t
  geometryColumn = ""
  geometryType = ""
  srid = 0
  if t~hasMethod("geometryColumn") then geometryColumn = t~geometryColumn
  if t~hasMethod("geometryType") then geometryType = t~geometryType
  if t~hasMethod("srid") then srid = t~srid
  return .DatabaseTableMetadata~new(t~definition, geometryColumn, geometryType, srid)

::method queryTable
  use arg tableName
  queryResult = self~selectAll(tableName)
  if queryResult~status = .Error~SUCCESS then queryResult~metadata = self~tableMetadata(tableName)
  return queryResult

::method appendCatalogName private
  use arg names, seen, tableName
  if tableName == .nil then return .false
  key = tableName~string~translate
  if seen~hasIndex(key) then return .false
  names~append(tableName~string)
  seen[key] = .true
  return .true

::method readCatalog
  raw = self~fileEngine~readCatalog
  merged = raw~copy
  names = .array~new
  seen = .table~new

  existing = raw["tables"]
  if existing \== .nil then do tableName over existing
    ignore = self~appendCatalogName(names, seen, tableName)
  end

  do key over self~objectEngine~tables~allIndexes
    objectTable = self~objectEngine~tables[key]
    if objectTable == .nil then iterate
    ignore = self~appendCatalogName(names, seen, objectTable~definition~name)
  end

  do external over self~externalEngines
    if external~hasMethod("readCatalog") then do
      externalCatalog = external~readCatalog
      externalNames = externalCatalog["tables"]
      if externalNames \== .nil then do externalName over externalNames
        ignore = self~appendCatalogName(names, seen, externalName)
      end
    end
    else if external~hasMethod("tableNames") then do
      externalNames = external~tableNames
      do externalName over externalNames
        ignore = self~appendCatalogName(names, seen, externalName)
      end
    end
  end

  names~sort
  merged["tables"] = names
  return merged

::method table
  use arg name
  t=self~objectEngine~table(name)
  if t \== .nil then return t
  t=self~fileEngine~table(name)
  if t \== .nil then return t
  do engine over self~externalEngines
    t=engine~table(name)
    if t \== .nil then return t
  end
  return .nil

::method engineForTable private
  use arg name
  if self~objectEngine~table(name) \== .nil then return self~objectEngine
  if self~fileEngine~table(name) \== .nil then return self~fileEngine
  do engine over self~externalEngines
    if engine~table(name) \== .nil then return engine
  end
  return .nil

::method version
  v=self~fileEngine~version
  v~engine="FEDERATED"
  if self~externalEngines~items > 0 then v~storage="FILE+LIVE_OBJECTS+EXTERNAL"
  else v~storage="FILE+LIVE_OBJECTS"
  filtered=.array~new
  do feature over v~features
    upper=feature~translate
    if upper~startsWith("TRANSACTION") then iterate
    if upper="SAVEPOINTS" then iterate
    if upper~startsWith("PREPARED_") then iterate
    filtered~append(feature)
  end
  v~features=filtered
  return v

::method transaction
  return .ObjectUnsupportedTransaction~new

::method events
  return self~objectEngine~events

::method mutationGraph
  return .nil

::method queryPatternLog
  return self~fileEngine~queryPatternLog

::method tableRowCount
  use arg tableName
  t=self~table(tableName)
  if t==.nil then return .nil
  return t~rowCount

::method currentIndexCandidateCount
  use arg tableName,column,wanted
  owner = self~engineForTable(tableName)
  if owner == .nil then return .nil
  if \owner~hasMethod("currentIndexCandidateCount") then return .nil
  return owner~currentIndexCandidateCount(tableName,column,wanted)

::method joinMapSnapshot
  return .nil

::method selectAll
  use arg tableName
  return self~selectWhere(tableName,.nil)

::method selectWhere
  use arg tableName,predicate
  owner = self~engineForTable(tableName)
  if owner == .nil then do
    rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
    return rs~fail(.Error~NOTFOUND,"Table not found:" tableName)
  end
  if \owner~hasMethod("selectWhere") then do
    rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
    return rs~fail(.Error~SQLUNSUPPORTED,"Table provider does not support SELECT:" tableName)
  end
  return owner~selectWhere(tableName,predicate)

::method selectJoin
  use arg leftName,leftColumn,rightName,rightColumn
  rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
  left=self~table(leftName); right=self~table(rightName)
  if left==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" leftName)
  if right==.nil then return rs~fail(.Error~NOTFOUND,"Table not found:" rightName)
  lc=left~definition~canonicalColumn(leftColumn); rc=right~definition~canonicalColumn(rightColumn)
  if lc==.nil | rc==.nil then return rs~fail(.Error~SCHEMAERROR,"Unknown join column")
  leftRows=left~readRows; rightRows=right~readRows
  buckets=.table~new
  do rrow over rightRows
    v=rrow[rc]
    if v==.nil then iterate
    arr=buckets[v~string]
    if arr==.nil then arr=.array~new
    arr~append(rrow); buckets[v~string]=arr
  end
  out=.array~new
  do lrow over leftRows
    v=lrow[lc]
    if v==.nil then iterate
    matches=buckets[v~string]
    if matches==.nil then iterate
    do rrow over matches
      out~append(self~qualifiedJoinRow(left,lrow,right,rrow))
    end
  end
  rs~rows=out; rs~affectedRows=out~items; rs~rowsScanned=leftRows~items+rightRows~items
  rs~accessPath="FEDERATED_TABLE_SCAN"
  return rs

::method selectJoinWithSidePredicate
  use arg leftName,leftColumn,rightName,rightColumn,side,predicate
  rs=self~selectJoin(leftName,leftColumn,rightName,rightColumn)
  if rs~status \= .Error~SUCCESS then return rs
  -- correctness-first: SQL executor may still apply its own WHERE later.
  return rs

::method selectCrossJoin
  use arg leftName,rightName
  rs=.DatabaseResult~new(.DatabaseOperationType~SELECT)
  left=self~table(leftName); right=self~table(rightName)
  if left==.nil | right==.nil then return rs~fail(.Error~NOTFOUND,"Cross join table not found")
  out=.array~new; leftRows=left~readRows; rightRows=right~readRows
  do lrow over leftRows
    do rrow over rightRows
      out~append(self~qualifiedJoinRow(left,lrow,right,rrow))
    end
  end
  rs~rows=out; rs~affectedRows=out~items; rs~rowsScanned=leftRows~items+rightRows~items; rs~accessPath="FEDERATED_CROSS_SCAN"
  return rs

::method selectCrossJoinWithSidePredicate
  use arg leftName,rightName,side,predicate
  return self~selectCrossJoin(leftName,rightName)

::method qualifiedJoinRow private
  use arg left,lrow,right,rrow
  values=.table~new
  do col over left~definition~columns
    values[left~definition~name || "." || col~name]=lrow[col~name]
  end
  do col over right~definition~columns
    values[right~definition~name || "." || col~name]=rrow[col~name]
  end
  return .DatabaseRow~new(values)

::method insert
  use arg tableName,values
  return self~dispatchTableMutation(tableName, "INSERT", "insert", .array~of(tableName, values))
::method insertMany
  use arg tableName,values
  return self~dispatchTableMutation(tableName, "INSERT", "insertMany", .array~of(tableName, values))
::method updateWhere
  use arg tableName,predicate,assignments
  return self~dispatchTableMutation(tableName, "UPDATE", "updateWhere", .array~of(tableName, predicate, assignments))
::method deleteWhere
  use arg tableName,predicate
  return self~dispatchTableMutation(tableName, "DELETE", "deleteWhere", .array~of(tableName, predicate))

/*
 * Resolve mutations by relation ownership, not by assuming that every
 * non-object table belongs to the FILE engine.  This keeps read-only external
 * relations honest (SQLUNSUPPORTED rather than a misleading FILE NOTFOUND)
 * while allowing a future writable external provider to implement the normal
 * mutation messages without adding a provider-specific branch here.
 */
::method dispatchTableMutation private
  use arg tableName, operation, messageName, arguments
  owner = self~engineForTable(tableName)
  rs = .DatabaseResult~new(operation)
  if owner == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  if \owner~hasMethod(messageName) then return rs~fail(.Error~SQLUNSUPPORTED, "Table provider does not support " || operation || ":" tableName)
  return owner~sendWith(messageName, arguments)
::method createTable
  forward to (self~fileEngine)
::method dropTable
  forward to (self~fileEngine)

::class FileDatabaseEngine subclass NoSQLAlchemyObject public
::attribute root
::attribute queryLog
::attribute runtime
::attribute mutationGraph

::method init
  use arg root, mutationGraph = .nil, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("FILE_ENGINE", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("EXECUTE", "execute SQL against durable file relations", "UNKNOWN")
  self~registerNoSQLMethod("QUERY", "query durable file relations", "READ")
  self~registerNoSQLMethod("TRANSACTION", "create a staged database transaction", "MUTATE")
  self~mutationGraph = mutationGraph
  recovered = .DatabaseFileSystem~recoverPublication(root)
  self~root = .DatabaseFileSystem~canonicalRoot(root)
  rt = .local["NOSQLSERVER.RUNTIME"]
  if rt == .nil then do
    rt = .NoSQLServerRuntime~new(alchemySealer, alchemyAuthority)
    .local["NOSQLSERVER.RUNTIME"] = rt
  end
  self~runtime = rt
  self~queryLog = rt~queryPatternLog(root)
  self~installForeignKeyRules

::method installForeignKeyRules private
  raw = self~readCatalog
  names = raw["tables"]
  if names == .nil then return .true
  do tableName over names
    ignore = self~installForeignKeyRulesForTable(tableName)
  end
  return .true

::method installForeignKeyRulesForTable private
  use arg tableName
  child = self~table(tableName)
  if child == .nil then return .false
  do fk over child~definition~foreignKeys
    rule = .DatabaseForeignKeyRule~new(self, fk, child~definition~name)
    base = "FK." || child~definition~name~translate || "." || fk~column~translate || "->" || fk~referencesTable~translate || "." || fk~referencesColumn~translate
    ignore = self~events~onUnique(base || ".CHILD.INSERT", .DatabaseEventType~BEFORE_INSERT, child~definition~name, rule)
    ignore = self~events~onUnique(base || ".CHILD.UPDATE", .DatabaseEventType~BEFORE_UPDATE, child~definition~name, rule)
    ignore = self~events~onUnique(base || ".PARENT.DELETE", .DatabaseEventType~BEFORE_DELETE, fk~referencesTable, rule)
    ignore = self~events~onUnique(base || ".PARENT.UPDATE", .DatabaseEventType~BEFORE_UPDATE, fk~referencesTable, rule)
    ignore = self~events~onUnique(base || ".PARENT.UPDATE.AFTER", .DatabaseEventType~AFTER_UPDATE, fk~referencesTable, rule)
  end
  return .true

::method validateForeignKeyDefinition private
  use arg childTableName, fk
  parent = self~table(fk~referencesTable)
  if parent == .nil then raise syntax 93.900 additional("FOREIGN KEY parent table not found:" fk~referencesTable)
  parentColumn = parent~definition~canonicalColumn(fk~referencesColumn)
  if parentColumn == .nil then raise syntax 93.900 additional("FOREIGN KEY parent column not found:" fk~referencesColumn)
  fk~referencesColumn = parentColumn

  parentIsKey = .false
  if parent~definition~primaryKey~items = 1 then do
    if parent~definition~primaryKey[1]~caselessEquals(parentColumn) then parentIsKey = .true
  end
  do uniqueKey over parent~definition~uniqueConstraints
    if uniqueKey~items = 1 then do
      if uniqueKey[1]~caselessEquals(parentColumn) then parentIsKey = .true
    end
  end
  if \parentIsKey then raise syntax 93.900 additional("FOREIGN KEY target must be PRIMARY KEY or UNIQUE:" fk~referencesTable || "." || parentColumn)

  child = self~table(childTableName)
  if child \== .nil then do
    childCol = child~definition~column(fk~column)
    parentCol = parent~definition~column(parentColumn)
    if childCol \== .nil then if childCol~type \= parentCol~type then raise syntax 93.900 additional("FOREIGN KEY column types must match")
  end

  if fk~onDelete \= "RESTRICT" & fk~onDelete \= "NO ACTION" & fk~onDelete \= "CASCADE" & fk~onDelete \= "SET NULL" then raise syntax 93.900 additional("Unsupported FOREIGN KEY ON DELETE action:" fk~onDelete)
  if fk~onUpdate \= "RESTRICT" & fk~onUpdate \= "NO ACTION" & fk~onUpdate \= "CASCADE" & fk~onUpdate \= "SET NULL" then raise syntax 93.900 additional("Unsupported FOREIGN KEY ON UPDATE action:" fk~onUpdate)
  return .true

::method version
  raw = self~readCatalog
  formatVersion = raw["formatVersion"]
  if formatVersion == .nil then formatVersion = 1
  return .NoSQLServerVersionInfo~new(formatVersion)

::method execute
  use arg sqlText
  return .NoSQLServerSQL~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)~execute(sqlText)

::method query
  use arg sqlText
  return self~execute(sqlText)

::method primaryKeyCache
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return self~runtime~primaryKeyCache(self~root, t)

::method invalidatePrimaryKeyCache
  use arg tableName
  return self~runtime~invalidatePrimaryKeyCache(self~root, tableName)

::method stagedMutationGraph
  return .DatabaseMutationGraph~new(self)

::method requiresMutationGraph private
  use arg parentTable, operation
  raw = self~readCatalog
  names = raw["tables"]
  if names == .nil then return .false
  do childName over names
    child = self~table(childName)
    if child == .nil then iterate
    do fk over child~definition~foreignKeys
      if \fk~referencesTable~caselessEquals(parentTable) then iterate
      if operation~translate = "DELETE" then do
        if fk~onDelete = "CASCADE" | fk~onDelete = "SET NULL" then return .true
      end
      if operation~translate = "UPDATE" then do
        if fk~onUpdate = "CASCADE" | fk~onUpdate = "SET NULL" then return .true
      end
    end
  end
  return .false

::method transaction
  return .DatabaseTransaction~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)

::method databaseCore
  return .NoSQLDatabaseCoreAdapter~new(self, self~noSQLAlchemySealer, self~noSQLAlchemyAuthority)

::method tableMetadata
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return .DatabaseTableMetadata~new(t~definition)

::method queryTable
  use arg tableName
  queryResult = self~selectAll(tableName)
  if queryResult~status = .Error~SUCCESS then queryResult~metadata = self~tableMetadata(tableName)
  return queryResult

::method databaseSignature
  return .DatabaseFileSystem~signature(self~root)

::method table
  use arg name
  path = self~root || "/tables/" || name
  if stream(path || "/table.yaml", "c", "query exists") = "" then return .nil
  return .FileDatabaseTable~new(path, self)

::method compactTable
  use arg name
  rs = .DatabaseResult~new(.DatabaseOperationType~MAINTENANCE)
  t = self~table(name)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" name)
  signal on syntax name compactError
  rs~affectedRows = t~compactStorage
  signal off syntax
  rs~message = "COMPACTED"
  return rs
compactError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Unable to compact table"
  return rs~fail(.Error~STORAGEERROR, messageText~string)

::method events
  if self~mutationGraph \== .nil then return self~mutationGraph~eventRegistry
  return self~runtime~eventRegistry(self~root)

::method readCatalog
  catalogPath = self~root || "/database.yaml"
  if stream(catalogPath, "c", "query exists") \= "" then return .Yaml~new~parseFile(catalogPath)
  raw = .table~new
  slash = self~root~lastPos("/")
  if slash = 0 then dbName = self~root
  else dbName = self~root~substr(slash + 1)
  if dbName = "" then dbName = "filedb"
  raw["name"] = dbName
  raw["formatVersion"] = 1
  raw["tables"] = .array~new
  return raw

::method writeCatalog
  use arg raw
  .Yaml~toYamlFile(raw, self~root || "/database.yaml")

::method registerTable private
  use arg name
  raw = self~readCatalog
  names = raw["tables"]
  if names == .nil then names = .array~new
  found = .false
  do existing over names
    if existing~string~caselessEquals(name~string) then found = .true
  end
  if \found then names~append(name)
  raw["tables"] = names
  self~writeCatalog(raw)

::method unregisterTable private
  use arg name
  raw = self~readCatalog
  names = raw["tables"]
  kept = .array~new
  if names \== .nil then do
    do existing over names
      if \existing~string~caselessEquals(name~string) then kept~append(existing)
    end
  end
  raw["tables"] = kept
  self~writeCatalog(raw)

::method createTable
  use arg name, columns, primaryKey = .nil, uniqueConstraints = .nil, separator = ",", nullToken = "\\N", foreignKeys = .nil, tombstoneHex = "FD", tombstoneThresholdBytes = 65536
  rs = .DatabaseResult~new(.DatabaseOperationType~CREATE_TABLE)
  if self~table(name) \== .nil then return rs~fail(.Error~ALREADYEXISTS, "Table already exists:" name)
  if columns == .nil then return rs~fail(.Error~SCHEMAERROR, "CREATE TABLE requires columns")
  if columns~items = 0 then return rs~fail(.Error~SCHEMAERROR, "CREATE TABLE requires columns")

  if foreignKeys \== .nil then do
    signal on syntax name createForeignKeyValidationError
    do fk over foreignKeys
      parent = self~table(fk~referencesTable)
      if parent == .nil then raise syntax 93.900 additional("FOREIGN KEY parent table not found:" fk~referencesTable)
      parentColumn = parent~definition~canonicalColumn(fk~referencesColumn)
      if parentColumn == .nil then raise syntax 93.900 additional("FOREIGN KEY parent column not found:" fk~referencesColumn)
      fk~referencesColumn = parentColumn

      parentIsKey = .false
      if parent~definition~primaryKey~items = 1 then do
        if parent~definition~primaryKey[1]~caselessEquals(parentColumn) then parentIsKey = .true
      end
      do uniqueKey over parent~definition~uniqueConstraints
        if uniqueKey~items = 1 then do
          if uniqueKey[1]~caselessEquals(parentColumn) then parentIsKey = .true
        end
      end
      if \parentIsKey then raise syntax 93.900 additional("FOREIGN KEY target must be PRIMARY KEY or UNIQUE:" fk~referencesTable || "." || parentColumn)

      childType = ""
      do childCol over columns
        if childCol~name~caselessEquals(fk~column) then childType = childCol~type
      end
      if childType = "" then raise syntax 93.900 additional("FOREIGN KEY child column not found:" fk~column)
      parentType = parent~definition~column(parentColumn)~type
      if childType \= parentType then raise syntax 93.900 additional("FOREIGN KEY column types must match")

      if fk~onDelete \= "RESTRICT" & fk~onDelete \= "NO ACTION" & fk~onDelete \= "CASCADE" & fk~onDelete \= "SET NULL" then raise syntax 93.900 additional("Unsupported FOREIGN KEY ON DELETE action:" fk~onDelete)
      if fk~onUpdate \= "RESTRICT" & fk~onUpdate \= "NO ACTION" & fk~onUpdate \= "CASCADE" & fk~onUpdate \= "SET NULL" then raise syntax 93.900 additional("Unsupported FOREIGN KEY ON UPDATE action:" fk~onUpdate)
      if fk~onDelete = "SET NULL" | fk~onUpdate = "SET NULL" then do
        childNullable = .false
        do childCol over columns
          if childCol~name~caselessEquals(fk~column) then childNullable = childCol~nullable
        end
        if \childNullable then raise syntax 93.900 additional("FOREIGN KEY SET NULL requires nullable child column:" fk~column)
      end
    end
    signal off syntax
  end

  tablesPath = self~root || "/tables"
  tablePath = tablesPath || "/" || name
  call SysMkDir self~root
  call SysMkDir tablesPath
  mkdirRc = SysMkDir(tablePath)
  if mkdirRc \= 0 then do
    if stream(tablePath, "c", "query exists") = "" then return rs~fail(.Error~STORAGEERROR, "Unable to create table directory")
  end

  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["rowCount"] = 0
  storage = .table~new
  storage["format"] = "delimited"
  delimiter = .DelimiterDefinition~new(separator)
  storage["separator"] = delimiter~yamlValue
  storage["header"] = .true
  storage["nullToken"] = nullToken
  storage["tombstoneHex"] = tombstoneHex
  storage["tombstoneThresholdBytes"] = tombstoneThresholdBytes
  raw["storage"] = storage

  yamlCols = .array~new
  do col over columns
    item = .table~new
    item["name"] = col~name
    item["type"] = col~type
    item["nullable"] = col~nullable
    if col~unique then item["unique"] = .true
    if col~primaryKey then item["primaryKey"] = .true
    yamlCols~append(item)
  end
  raw["columns"] = yamlCols
  if foreignKeys \== .nil then do
    if foreignKeys~items > 0 then do
      yamlFks = .array~new
      do fk over foreignKeys
        item = .table~new
        item["column"] = fk~column
        item["referencesTable"] = fk~referencesTable
        item["referencesColumn"] = fk~referencesColumn
        item["onDelete"] = fk~onDelete
        item["onUpdate"] = fk~onUpdate
        yamlFks~append(item)
      end
      raw["foreignKeys"] = yamlFks
    end
  end
  if primaryKey \== .nil then do
    if primaryKey~items > 0 then raw["primaryKey"] = primaryKey
  end
  if uniqueConstraints \== .nil then do
    if uniqueConstraints~items > 0 then raw["unique"] = uniqueConstraints
  end

  .Yaml~toYamlFile(raw, tablePath || "/table.yaml")
  empty = .array~new
  t = self~table(name)
  if t == .nil then return rs~fail(.Error~STORAGEERROR, "Created table could not be reopened")
  t~storage~writeRows(empty)
  self~registerTable(name)
  if foreignKeys \== .nil then ignore = self~installForeignKeyRulesForTable(name)
  rs~affectedRows = 0
  return rs
createForeignKeyValidationError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  return rs~fail(.Error~CONSTRAINT, messageText~string)

::method dropTable
  use arg name
  rs = .DatabaseResult~new(.DatabaseOperationType~DROP_TABLE)
  t = self~table(name)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" name)
  call SysFileDelete t~path || "/data"
  call SysFileDelete t~path || "/data.new"
  call SysFileDelete t~path || "/data.old"
  call SysFileTree t~path || "/journal/*", journalFiles., "FO"
  do i = 1 to journalFiles.0
    call SysFileDelete journalFiles.i
  end
  call SysRmDir t~path || "/journal"
  call SysFileTree t~path || "/indexes/*", indexFiles., "FO"
  do i = 1 to indexFiles.0
    call SysFileDelete indexFiles.i
  end
  call SysRmDir t~path || "/indexes"
  self~removeJoinMapsForTable(name)
  call SysFileDelete t~path || "/table.yaml"
  rmRc = SysRmDir(t~path)
  if rmRc \= 0 then return rs~fail(.Error~STORAGEERROR, "Unable to remove table directory")
  self~unregisterTable(name)
  return rs

::method removeJoinMapsForTable private
  use arg tableName
  joinRoot = self~root || "/joinmaps"
  call SysFileTree joinRoot || "/*.yaml", joinFiles., "FO"
  do i = 1 to joinFiles.0
    raw = .Yaml~new~parseFile(joinFiles.i)
    remove = .false
    if raw["leftTable"] \== .nil then do
      if raw["leftTable"]~string~caselessEquals(tableName~string) then remove = .true
    end
    if raw["rightTable"] \== .nil then do
      if raw["rightTable"]~string~caselessEquals(tableName~string) then remove = .true
    end
    if remove then call SysFileDelete joinFiles.i
  end
  return 0

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::method selectWhere
  use arg tableName, predicate
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  rs~snapshotGeneration = t~generation

  if predicate \== .nil then do
    if predicate~isA(.SQLComparisonPredicate) then do
      if predicate~operator = "=" then do
        planned = self~selectEqualityWithIndex(t, predicate, rs~snapshotGeneration)
        if planned \== .nil then do
          rs~rows = planned["rows"]
          rs~accessPath = planned["accessPath"]
          rs~rowsScanned = planned["rowsScanned"]
          rs~indexedThrough = planned["indexedThrough"]
          rs~affectedRows = rs~rows~items
          return rs
        end
      end
    end
  end

  allRows = t~storage~readRows
  rs~rowsScanned = allRows~items
  rs~accessPath = "TABLE_SCAN"
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  return rs

::method selectEqualityWithIndex private
  use arg t, predicate, snapshotGeneration
  canonical = t~definition~canonicalColumn(predicate~column)
  if canonical == .nil then return .nil
  snap = self~indexSnapshot(t~definition~name, canonical)
  if snap == .nil then return .nil
  relation = snap~relationTo(snapshotGeneration)
  if relation = "AHEAD_INVALID" then return .nil
  col = t~definition~column(canonical)
  signal on syntax name indexPlanFailure
  wanted = col~coerce(predicate~value)
  signal off syntax

  if relation = "CURRENT" then do
    rows = snap~lookupRows(wanted)
    if self~table(t~definition~name)~generation \= snapshotGeneration then return .nil
    return self~plannedRows(rows, "INDEX_CURRENT", rows~items, snap~indexedThrough)
  end

  rows = self~reconcileIndexRows(t, snap, canonical, wanted, snapshotGeneration)
  if rows == .nil then return .nil
  if self~table(t~definition~name)~generation \= snapshotGeneration then return .nil
  return self~plannedRows(rows, "INDEX_DELTA", rows~items, snap~indexedThrough)
indexPlanFailure:
  signal off syntax
  return .nil

::method plannedRows private
  use arg rows, accessPath, rowsScanned, indexedThrough
  out = .table~new
  out["rows"] = rows
  out["accessPath"] = accessPath
  out["rowsScanned"] = rowsScanned
  out["indexedThrough"] = indexedThrough
  return out

::method reconcileIndexRows private
  use arg t, snap, canonical, wanted, snapshotGeneration
  candidates = .table~new
  do row over snap~lookupRows(wanted)
    candidates[t~primaryKeySignature(row)] = row
  end
  startGeneration = snap~indexedThrough + 1
  do generation = startGeneration to snapshotGeneration
    journal = self~readJournal(t, generation)
    if journal == .nil then return .nil
    changes = journal["changes"]
    if changes == .nil then return .nil
    do change over changes
      beforeRaw = change["before"]
      if beforeRaw \== .nil then do
        beforeRow = .DatabaseRow~new(beforeRaw)
        beforeValue = beforeRow[canonical]
        if self~valueEquals(t~definition~column(canonical), beforeValue, wanted) then do
          candidates~remove(t~primaryKeySignature(beforeRow))
        end
      end
      afterRaw = change["after"]
      if afterRaw \== .nil then do
        afterRow = .DatabaseRow~new(afterRaw)
        afterValue = afterRow[canonical]
        if self~valueEquals(t~definition~column(canonical), afterValue, wanted) then do
          candidates[t~primaryKeySignature(afterRow)] = afterRow
        end
      end
    end
  end
  rows = .array~new
  do sig over candidates
    row = candidates[sig]
    if .SQLComparisonPredicate~new(canonical, "=", wanted)~evaluate(row, t~definition) then rows~append(row)
  end
  return rows

::method valueEquals private
  use arg column, actual, wanted
  if actual == .nil then return .false
  if wanted == .nil then return .false
  return column~compare(actual, "=", wanted)

::method readJournal private
  use arg t, generation
  fileName = generation~format(10,0)~strip~changestr(" ", "0") || ".yaml"
  path = t~path || "/journal/" || fileName
  if stream(path, "c", "query exists") = "" then return .nil
  raw = .Yaml~new~parseFile(path)
  if raw["generation"] \= generation then return .nil
  return raw

::method selectWhereEquals
  use arg tableName, column, wanted
  return self~selectWhere(tableName, .SQLComparisonPredicate~new(column, "=", wanted))

::method insert
  use arg tableName, values
  rs = .DatabaseResult~new(.DatabaseOperationType~INSERT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  signal on syntax name insertError
  rs~affectedRows = t~insert(values)
  signal off syntax
  return rs
insertError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Constraint operation failed"
  return rs~fail(.Error~CONSTRAINT, messageText~string)

::method insertMany
  use arg tableName, valuesRows
  rs = .DatabaseResult~new(.DatabaseOperationType~INSERT)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  signal on syntax name insertManyError
  rs~affectedRows = t~insertMany(valuesRows)
  signal off syntax
  return rs
insertManyError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Constraint operation failed"
  return rs~fail(.Error~CONSTRAINT, messageText~string)

::method updateWhere
  use arg tableName, predicate, assignments
  if self~mutationGraph == .nil then do
    if self~requiresMutationGraph(tableName, "UPDATE") then do
      graph = self~stagedMutationGraph
      return graph~updateWhereAndCommit(tableName, predicate, assignments)
    end
  end
  rs = .DatabaseResult~new(.DatabaseOperationType~UPDATE)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  signal on syntax name updateError
  rs~affectedRows = t~updateWhere(predicate, assignments)
  signal off syntax
  return rs
updateError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Constraint operation failed"
  return rs~fail(.Error~CONSTRAINT, messageText~string)

::method updateWhereEquals
  use arg tableName, whereColumn, wanted, assignments
  return self~updateWhere(tableName, .SQLComparisonPredicate~new(whereColumn, "=", wanted), assignments)

::method deleteWhere
  use arg tableName, predicate
  if self~mutationGraph == .nil then do
    if self~requiresMutationGraph(tableName, "DELETE") then do
      graph = self~stagedMutationGraph
      return graph~deleteWhereAndCommit(tableName, predicate)
    end
  end
  rs = .DatabaseResult~new(.DatabaseOperationType~DELETE)
  t = self~table(tableName)
  if t == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" tableName)
  signal on syntax name deleteError
  rs~affectedRows = t~deleteWhere(predicate)
  signal off syntax
  return rs
deleteError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "Constraint operation failed"
  return rs~fail(.Error~CONSTRAINT, messageText~string)

::method deleteWhereEquals
  use arg tableName, whereColumn, wanted
  return self~deleteWhere(tableName, .SQLComparisonPredicate~new(whereColumn, "=", wanted))



::method queryPatternLog
  return self~queryLog

::method indexSnapshot
  use arg tableName, column
  t = self~table(tableName)
  if t == .nil then return .nil
  canonical = t~definition~canonicalColumn(column)
  if canonical == .nil then return .nil
  path = t~path || "/indexes/idx_" || canonical~translate || ".yaml"
  if stream(path, "c", "query exists") = "" then return .nil
  return .DatabaseIndexSnapshot~new(path)

::method beginBuild
  use arg key
  return self~runtime~beginBuild(self~root, key)

::method buildFinished
  use arg key
  return self~runtime~buildFinished(self~root, key)

::method buildInFlight
  use arg key
  return self~runtime~buildInFlight(self~root, key)

::method startIndexBuild
  use arg tableName, column
  t = self~table(tableName)
  if t == .nil then return .nil
  canonical = t~definition~canonicalColumn(column)
  if canonical == .nil then return .nil
  key = "INDEX." || t~definition~name~translate || "." || canonical~translate
  if \self~beginBuild(key) then return .nil
  return .DatabaseIndexer~new(t, canonical, self, key)~start

::method adviseIndexes
  use arg threshold = 3
  messages = .array~new
  do candidate over self~queryPatternLog~candidates(threshold)
    if self~indexSnapshot(candidate["table"], candidate["column"]) == .nil then do
      msg = self~startIndexBuild(candidate["table"], candidate["column"])
      if msg \== .nil then messages~append(msg)
    end
  end
  return messages

::method adviseJoinMaps
  use arg threshold = 3
  messages = .array~new
  do candidate over self~queryPatternLog~joinCandidates(threshold)
    snap = self~joinMapSnapshot(candidate["leftTable"], candidate["leftColumn"], candidate["rightTable"], candidate["rightColumn"])
    if snap == .nil then do
      msg = self~startJoinMapBuild(candidate["leftTable"], candidate["leftColumn"], candidate["rightTable"], candidate["rightColumn"])
      if msg \== .nil then messages~append(msg)
    end
  end
  return messages

::method startJoinMapBuild
  use arg leftTableName, leftColumn, rightTableName, rightColumn
  leftTable = self~table(leftTableName)
  rightTable = self~table(rightTableName)
  if leftTable == .nil then return .nil
  if rightTable == .nil then return .nil
  leftCanonical = leftTable~definition~canonicalColumn(leftColumn)
  rightCanonical = rightTable~definition~canonicalColumn(rightColumn)
  if leftCanonical == .nil then return .nil
  if rightCanonical == .nil then return .nil
  key = "JOIN." || leftTable~definition~name~translate || "." || leftCanonical~translate || "." || rightTable~definition~name~translate || "." || rightCanonical~translate
  if \self~beginBuild(key) then return .nil
  root = self~root || "/joinmaps"
  return .DatabaseJoinMapBuilder~new(leftTable, leftCanonical, rightTable, rightCanonical, root, self, key)~start

::method joinMapPath private
  use arg leftTableName, leftColumn, rightTableName, rightColumn
  return self~root || "/joinmaps/" || leftTableName || "_" || leftColumn || "__" || rightTableName || "_" || rightColumn || ".yaml"

::method joinMapSnapshot
  use arg leftTableName, leftColumn, rightTableName, rightColumn
  leftTable = self~table(leftTableName)
  rightTable = self~table(rightTableName)
  if leftTable == .nil then return .nil
  if rightTable == .nil then return .nil
  leftCanonical = leftTable~definition~canonicalColumn(leftColumn)
  rightCanonical = rightTable~definition~canonicalColumn(rightColumn)
  if leftCanonical == .nil then return .nil
  if rightCanonical == .nil then return .nil
  path = self~joinMapPath(leftTable~definition~name, leftCanonical, rightTable~definition~name, rightCanonical)
  if stream(path, "c", "query exists") = "" then return .nil
  return .DatabaseJoinMapSnapshot~new(path)

::method tableRowCount
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return t~definition~rowCount

::method currentIndexCandidateCount
  use arg tableName, column, wanted
  t = self~table(tableName)
  if t == .nil then return .nil
  snap = self~indexSnapshot(tableName, column)
  if snap == .nil then return .nil
  if snap~relationTo(t~generation) \= "CURRENT" then return .nil
  return snap~lookupRows(wanted)~items

::method selectJoin
  use arg leftTableName, leftColumn, rightTableName, rightColumn
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  leftTable = self~table(leftTableName)
  rightTable = self~table(rightTableName)
  if leftTable == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" leftTableName)
  if rightTable == .nil then return rs~fail(.Error~NOTFOUND, "Table not found:" rightTableName)
  leftCanonical = leftTable~definition~canonicalColumn(leftColumn)
  rightCanonical = rightTable~definition~canonicalColumn(rightColumn)
  if leftCanonical == .nil then return rs~fail(.Error~SCHEMAERROR, "Unknown join column:" leftColumn)
  if rightCanonical == .nil then return rs~fail(.Error~SCHEMAERROR, "Unknown join column:" rightColumn)

  leftGeneration = leftTable~generation
  rightGeneration = rightTable~generation
  snap = self~joinMapSnapshot(leftTableName, leftCanonical, rightTableName, rightCanonical)
  if snap \== .nil then do
    relation = snap~relationTo(leftGeneration, rightGeneration)
    if relation = "CURRENT" then do
      rows = self~rowsFromJoinMap(leftTable, rightTable, snap~leftRows, snap~rightRows)
      if self~table(leftTableName)~generation = leftGeneration then do
        if self~table(rightTableName)~generation = rightGeneration then do
          rs~rows = rows
          rs~affectedRows = rows~items
          rs~accessPath = "JOIN_MAP_CURRENT"
          rs~rowsScanned = snap~rowSnapshotCount
          rs~leftIndexedThrough = snap~leftIndexedThrough
          rs~rightIndexedThrough = snap~rightIndexedThrough
          return rs
        end
      end
    end
    else if relation = "BEHIND" then do
      reconciled = self~reconcileJoinMap(leftTable, rightTable, snap, leftGeneration, rightGeneration)
      if reconciled \== .nil then do
        if self~table(leftTableName)~generation = leftGeneration then do
          if self~table(rightTableName)~generation = rightGeneration then do
            rows = self~rowsFromJoinMap(leftTable, rightTable, reconciled["left"], reconciled["right"])
            rs~rows = rows
            rs~affectedRows = rows~items
            rs~accessPath = "JOIN_MAP_DELTA"
            rs~rowsScanned = reconciled["rowsScanned"]
            rs~leftIndexedThrough = snap~leftIndexedThrough
            rs~rightIndexedThrough = snap~rightIndexedThrough
            return rs
          end
        end
      end
    end
  end

  return self~joinByAuthoritativeScan(leftTable, leftCanonical, rightTable, rightCanonical)

::method selectJoinWithSidePredicate
  use arg leftTableName, leftColumn, rightTableName, rightColumn, side, predicate
  leftTable = self~table(leftTableName)
  rightTable = self~table(rightTableName)
  if leftTable == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~NOTFOUND, "Table not found:" leftTableName)
  if rightTable == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~NOTFOUND, "Table not found:" rightTableName)
  leftCanonical = leftTable~definition~canonicalColumn(leftColumn)
  rightCanonical = rightTable~definition~canonicalColumn(rightColumn)
  if leftCanonical == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~SCHEMAERROR, "Unknown join column:" leftColumn)
  if rightCanonical == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~SCHEMAERROR, "Unknown join column:" rightColumn)

  if side = "LEFT" then do
    filtered = self~selectWhere(leftTableName, predicate)
    if filtered~status \= .Error~SUCCESS then return filtered
    leftRows = filtered~rows
    rightRows = rightTable~storage~readRows
    sidePath = filtered~accessPath
  end
  else do
    filtered = self~selectWhere(rightTableName, predicate)
    if filtered~status \= .Error~SUCCESS then return filtered
    leftRows = leftTable~storage~readRows
    rightRows = filtered~rows
    sidePath = filtered~accessPath
  end

  rs = self~joinMaterializedRows(leftTable, leftCanonical, leftRows, rightTable, rightCanonical, rightRows)
  rs~accessPath = "JOIN_PREFILTER_" || side || "_" || sidePath
  rs~rowsScanned = filtered~rowsScanned
  if side = "LEFT" then rs~rowsScanned += rightRows~items
  else rs~rowsScanned += leftRows~items
  rs~indexedThrough = filtered~indexedThrough
  return rs

::method selectCrossJoin
  use arg leftTableName, rightTableName
  leftTable = self~table(leftTableName)
  rightTable = self~table(rightTableName)
  if leftTable == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~NOTFOUND, "Table not found:" leftTableName)
  if rightTable == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~NOTFOUND, "Table not found:" rightTableName)
  leftRows = leftTable~storage~readRows
  rightRows = rightTable~storage~readRows
  return self~crossJoinMaterializedRows(leftTable, leftRows, rightTable, rightRows, "CROSS_TABLE_SCAN", leftRows~items + rightRows~items)

::method selectCrossJoinWithSidePredicate
  use arg leftTableName, rightTableName, side, predicate
  leftTable = self~table(leftTableName)
  rightTable = self~table(rightTableName)
  if leftTable == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~NOTFOUND, "Table not found:" leftTableName)
  if rightTable == .nil then return .DatabaseResult~new(.DatabaseOperationType~SELECT)~fail(.Error~NOTFOUND, "Table not found:" rightTableName)
  if side = "LEFT" then do
    filtered = self~selectWhere(leftTableName, predicate)
    if filtered~status \= .Error~SUCCESS then return filtered
    leftRows = filtered~rows
    rightRows = rightTable~storage~readRows
    scanned = filtered~rowsScanned + rightRows~items
  end
  else do
    filtered = self~selectWhere(rightTableName, predicate)
    if filtered~status \= .Error~SUCCESS then return filtered
    leftRows = leftTable~storage~readRows
    rightRows = filtered~rows
    scanned = filtered~rowsScanned + leftRows~items
  end
  path = "CROSS_PREFILTER_" || side || "_" || filtered~accessPath
  rs = self~crossJoinMaterializedRows(leftTable, leftRows, rightTable, rightRows, path, scanned)
  rs~indexedThrough = filtered~indexedThrough
  return rs

::method crossJoinMaterializedRows private
  use arg leftTable, leftRows, rightTable, rightRows, path, scanned
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  out = .array~new
  do leftRow over leftRows
    do rightRow over rightRows
      out~append(self~qualifiedJoinRow(leftTable, leftRow, rightTable, rightRow))
    end
  end
  rs~rows = out
  rs~affectedRows = out~items
  rs~accessPath = path
  rs~rowsScanned = scanned
  return rs

::method joinMaterializedRows private
  use arg leftTable, leftColumn, leftRows, rightTable, rightColumn, rightRows
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  buckets = .table~new
  do row over rightRows
    value = row[rightColumn]
    if value == .nil then iterate
    key = value~string
    arr = buckets[key]
    if arr == .nil then arr = .array~new
    arr~append(row)
    buckets[key] = arr
  end
  out = .array~new
  do leftRow over leftRows
    value = leftRow[leftColumn]
    if value == .nil then iterate
    matches = buckets[value~string]
    if matches == .nil then iterate
    do rightRow over matches
      out~append(self~qualifiedJoinRow(leftTable, leftRow, rightTable, rightRow))
    end
  end
  rs~rows = out
  rs~affectedRows = out~items
  return rs

::method joinByAuthoritativeScan private
  use arg leftTable, leftColumn, rightTable, rightColumn
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  leftRows = leftTable~storage~readRows
  rightRows = rightTable~storage~readRows
  buckets = .table~new
  do row over rightRows
    value = row[rightColumn]
    if value == .nil then iterate
    key = value~string
    arr = buckets[key]
    if arr == .nil then arr = .array~new
    arr~append(row)
    buckets[key] = arr
  end
  out = .array~new
  do leftRow over leftRows
    value = leftRow[leftColumn]
    if value == .nil then iterate
    matches = buckets[value~string]
    if matches == .nil then iterate
    do rightRow over matches
      out~append(self~qualifiedJoinRow(leftTable, leftRow, rightTable, rightRow))
    end
  end
  rs~rows = out
  rs~affectedRows = out~items
  rs~accessPath = "JOIN_TABLE_SCAN"
  rs~rowsScanned = leftRows~items + rightRows~items
  rs~leftIndexedThrough = 0
  rs~rightIndexedThrough = 0
  return rs

::method rowsFromJoinMap private
  use arg leftTable, rightTable, leftRowsByKey, rightRowsByKey
  out = .array~new
  do key over leftRowsByKey
    leftRows = leftRowsByKey[key]
    rightRows = rightRowsByKey[key]
    if rightRows == .nil then iterate
    do leftRow over leftRows
      do rightRow over rightRows
        out~append(self~qualifiedJoinRow(leftTable, leftRow, rightTable, rightRow))
      end
    end
  end
  return out

::method qualifiedJoinRow private
  use arg leftTable, leftRow, rightTable, rightRow
  values = .table~new
  leftName = leftTable~definition~name
  rightName = rightTable~definition~name
  do col over leftTable~definition~columns
    values[leftName || "." || col~name] = leftRow[col~name]
  end
  do col over rightTable~definition~columns
    values[rightName || "." || col~name] = rightRow[col~name]
  end
  return .DatabaseRow~new(values)

::method reconcileJoinMap private
  use arg leftTable, rightTable, snap, leftGeneration, rightGeneration
  leftState = self~copyJoinSide(snap~leftRows, leftTable)
  rightState = self~copyJoinSide(snap~rightRows, rightTable)
  scanned = snap~rowSnapshotCount

  leftState = self~reconcileJoinSide(leftTable, snap~leftColumn, leftState, snap~leftIndexedThrough + 1, leftGeneration)
  if leftState == .nil then return .nil
  rightState = self~reconcileJoinSide(rightTable, snap~rightColumn, rightState, snap~rightIndexedThrough + 1, rightGeneration)
  if rightState == .nil then return .nil

  out = .table~new
  out["left"] = self~joinStateToRows(leftState)
  out["right"] = self~joinStateToRows(rightState)
  out["rowsScanned"] = scanned + (leftGeneration - snap~leftIndexedThrough) + (rightGeneration - snap~rightIndexedThrough)
  return out

::method copyJoinSide private
  use arg rowsByKey, table
  state = .table~new
  do key over rowsByKey
    pkMap = .table~new
    do row over rowsByKey[key]
      pkMap[table~primaryKeySignature(row)] = row~copy
    end
    state[key] = pkMap
  end
  return state

::method reconcileJoinSide private
  use arg table, column, state, startGeneration, endGeneration
  if startGeneration > endGeneration then return state
  do generation = startGeneration to endGeneration
    journal = self~readJournal(table, generation)
    if journal == .nil then return .nil
    changes = journal["changes"]
    if changes == .nil then return .nil
    do change over changes
      beforeRaw = change["before"]
      if beforeRaw \== .nil then do
        beforeRow = .DatabaseRow~new(beforeRaw)
        self~removeJoinStateRow(state, table, column, beforeRow)
      end
      afterRaw = change["after"]
      if afterRaw \== .nil then do
        afterRow = .DatabaseRow~new(afterRaw)
        self~addJoinStateRow(state, table, column, afterRow)
      end
    end
  end
  return state

::method removeJoinStateRow private
  use arg state, table, column, row
  value = row[column]
  if value == .nil then return
  key = value~string
  pkMap = state[key]
  if pkMap == .nil then return
  pkMap~remove(table~primaryKeySignature(row))
  if pkMap~items = 0 then state~remove(key)

::method addJoinStateRow private
  use arg state, table, column, row
  value = row[column]
  if value == .nil then return
  key = value~string
  pkMap = state[key]
  if pkMap == .nil then pkMap = .table~new
  pkMap[table~primaryKeySignature(row)] = row
  state[key] = pkMap

::method joinStateToRows private
  use arg state
  rowsByKey = .table~new
  do key over state
    arr = .array~new
    pkMap = state[key]
    do sig over pkMap
      arr~append(pkMap[sig])
    end
    rowsByKey[key] = arr
  end
  return rowsByKey

::class DatabaseCostModel public
::method chooseJoinPlan
  use arg joinMapCost = .nil, prefilterCost = .nil
  if joinMapCost == .nil then do
    if prefilterCost == .nil then return "DEFAULT"
    return "PREFILTER"
  end
  if prefilterCost == .nil then return "JOIN_MAP"
  if prefilterCost < joinMapCost then return "PREFILTER"
  return "JOIN_MAP"

::method equalityPrefilterCost
  use arg candidateRows, otherRows
  if candidateRows == .nil then return .nil
  if otherRows == .nil then return .nil
  return candidateRows + otherRows

::class NoSQLServerRuntime subclass NoSQLAlchemyObject public
::attribute logs
::attribute builds
::attribute transactionPublishes
::attribute eventRegistries
::attribute primaryKeyCaches

::method init
  use arg alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("RUNTIME", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("QUERYPATTERNLOG", "obtain a database query-pattern log", "READ")
  self~registerNoSQLMethod("EVENTREGISTRY", "obtain the database event registry", "READ")
  self~logs = .table~new
  self~builds = .table~new
  self~transactionPublishes = .table~new
  self~eventRegistries = .table~new
  self~primaryKeyCaches = .table~new

::method primaryKeyCache
  use arg root, table
  key = root || "::" || table~definition~name~translate
  guard on
  cache = self~primaryKeyCaches[key]
  if cache \== .nil then do
    if cache~generation = table~generation then do
      guard off
      return cache
    end
  end
  guard off

  rebuilt = .DatabasePrimaryKeyCache~new(table)

  guard on
  current = self~primaryKeyCaches[key]
  if current \== .nil then do
    if current~generation = table~generation then do
      guard off
      return current
    end
  end
  self~primaryKeyCaches[key] = rebuilt
  guard off
  return rebuilt

::method invalidatePrimaryKeyCache
  use arg root, tableName
  guard on
  self~primaryKeyCaches~remove(root || "::" || tableName~translate)
  guard off
  return .true

::method eventRegistry
  use arg root
  guard on
  registry = self~eventRegistries[root]
  if registry == .nil then do
    registry = .DatabaseEventRegistry~new(root)
    self~eventRegistries[root] = registry
  end
  guard off
  return registry

::method queryPatternLog
  use arg root
  guard on
  log = self~logs[root]
  if log == .nil then do
    log = .QueryPatternLog~new(root)
    self~logs[root] = log
  end
  guard off
  return log

::method beginBuild
  use arg root, key
  guard on
  fullKey = root || "::" || key
  if self~builds[fullKey] \== .nil then do
    guard off
    return .false
  end
  self~builds[fullKey] = .true
  guard off
  return .true

::method buildFinished
  use arg root, key
  guard on
  self~builds~remove(root || "::" || key)
  guard off
  return .true

::method buildInFlight
  use arg root, key
  guard on
  present = self~builds[root || "::" || key] \== .nil
  guard off
  return present


::method beginTransactionPublish
  use arg root, token
  guard on
  if self~transactionPublishes[root] \== .nil then do
    guard off
    return .false
  end
  self~transactionPublishes[root] = token
  guard off
  return .true

::method endTransactionPublish
  use arg root, token
  guard on
  current = self~transactionPublishes[root]
  if current \== .nil then do
    if current == token then self~transactionPublishes~remove(root)
  end
  guard off
  return .true

::class DatabasePrimaryKeyCache public
::attribute tableName
::attribute generation
::attribute entries
::attribute lastPhysicalLine
::attribute usable

::method init
  use arg table
  self~tableName = table~definition~name
  self~generation = table~generation
  self~entries = .table~new
  self~lastPhysicalLine = table~storage~physicalLineCount
  self~usable = table~definition~primaryKey~items = 1
  if \self~usable then return

  do located over table~storage~readLocatedRows
    row = located["row"]
    sig = table~primaryKeySignature(row)
    entry = .table~new
    entry["row"] = row
    entry["line"] = located["line"]
    entry["lineCount"] = located["lineCount"]
    self~entries[sig] = entry
  end

::method lookup
  use arg signature
  if \self~usable then return .nil
  return self~entries[signature]

::method contains
  use arg signature
  if \self~usable then return .false
  return self~entries[signature] \== .nil

::method add
  use arg signature, row, line, lineCount, newGeneration
  if \self~usable then return .false
  entry = .table~new
  entry["row"] = row
  entry["line"] = line
  entry["lineCount"] = lineCount
  self~entries[signature] = entry
  if line > self~lastPhysicalLine then self~lastPhysicalLine = line
  self~generation = newGeneration
  return .true

::method remove
  use arg signature, newGeneration
  if self~usable then self~entries~remove(signature)
  self~generation = newGeneration
  return .true

::method replace
  use arg oldSignature, newSignature, row, line, lineCount, newGeneration
  if \self~usable then return .false
  self~entries~remove(oldSignature)
  entry = .table~new
  entry["row"] = row
  entry["line"] = line
  entry["lineCount"] = lineCount
  self~entries[newSignature] = entry
  if line > self~lastPhysicalLine then self~lastPhysicalLine = line
  self~generation = newGeneration
  return .true

::class DatabaseForeignKeyDefinition public
::attribute column
::attribute referencesTable
::attribute referencesColumn
::attribute onDelete
::attribute onUpdate

::method init
  use arg column, referencesTable, referencesColumn, onDelete = "RESTRICT", onUpdate = "RESTRICT"
  self~column = column~string
  self~referencesTable = referencesTable~string
  self~referencesColumn = referencesColumn~string
  if onDelete == .nil | onDelete = "" then onDelete = "RESTRICT"
  if onUpdate == .nil | onUpdate = "" then onUpdate = "RESTRICT"
  self~onDelete = onDelete~string~translate
  self~onUpdate = onUpdate~string~translate

::class DatabaseForeignKeyRule public
::attribute engine
::attribute childTable
::attribute childColumn
::attribute parentTable
::attribute parentColumn
::attribute onDelete
::attribute onUpdate

::method init
  use arg engine, fk, childTable
  self~engine = engine
  self~childTable = childTable
  self~childColumn = fk~column
  self~parentTable = fk~referencesTable
  self~parentColumn = fk~referencesColumn
  self~onDelete = fk~onDelete
  self~onUpdate = fk~onUpdate

::method onDatabaseEvent
  use arg event
  select
    when event~type = .DatabaseEventType~BEFORE_INSERT then return self~validateChild(event)
    when event~type = .DatabaseEventType~BEFORE_UPDATE then do
      if event~tableName~caselessEquals(self~childTable) then return self~validateChild(event)
      if event~tableName~caselessEquals(self~parentTable) then return self~protectParentUpdate(event)
    end
    when event~type = .DatabaseEventType~AFTER_UPDATE then do
      if event~tableName~caselessEquals(self~parentTable) then return self~cascadeParentUpdateAfter(event)
    end
    when event~type = .DatabaseEventType~BEFORE_DELETE then return self~protectParentDelete(event)
    otherwise nop
  end
  return .true

::method validateChild private
  use arg event
  if \event~tableName~caselessEquals(self~childTable) then return .true
  parent = event~engine~table(self~parentTable)
  if parent == .nil then do
    ignore = event~veto("FOREIGN KEY parent table not found: " || self~parentTable)
    return .false
  end
  parentCol = parent~definition~column(self~parentColumn)
  do change over event~changes
    after = change["after"]
    value = after[self~childColumn]
    if value == .nil then iterate
    found = .false
    do prow over parent~storage~readRows
      if parentCol~compare(prow[self~parentColumn], "=", value) then do
        found = .true
        leave
      end
    end
    if \found then do
      ignore = event~veto("FOREIGN KEY constraint failed: " || self~childTable || "." || self~childColumn || " -> " || self~parentTable || "." || self~parentColumn)
      return .false
    end
  end
  return .true

::method protectParentDelete private
  use arg event
  if \event~tableName~caselessEquals(self~parentTable) then return .true
  child = event~engine~table(self~childTable)
  if child == .nil then return .true
  childCol = child~definition~column(self~childColumn)

  if self~onDelete = "CASCADE" | self~onDelete = "SET NULL" then do
    graph = event~mutationGraph
    if graph == .nil then do
      ignore = event~veto("FOREIGN KEY cascading action requires staged mutation graph")
      return .false
    end
    do change over event~changes
      before = change["before"]
      parentValue = before[self~parentColumn]
      if self~onDelete = "CASCADE" then graph~stageDeleteWhereEquals(self~childTable, self~childColumn, parentValue)
      else graph~stageSetNullWhereEquals(self~childTable, self~childColumn, parentValue)
      if graph~state = "FAILED" then do
        ignore = event~veto(graph~message)
        return .false
      end
    end
    return .true
  end

  if self~onDelete = "NO ACTION" | self~onDelete = "RESTRICT" then do
    do change over event~changes
      before = change["before"]
      parentValue = before[self~parentColumn]
      do crow over child~storage~readRows
        childValue = crow[self~childColumn]
        if childValue == .nil then iterate
        if childCol~compare(childValue, "=", parentValue) then do
          ignore = event~veto("FOREIGN KEY restrict failed: " || self~childTable || "." || self~childColumn || " references " || self~parentTable || "." || self~parentColumn)
          return .false
        end
      end
    end
  end
  return .true

::method protectParentUpdate private
  use arg event
  if \event~tableName~caselessEquals(self~parentTable) then return .true
  child = event~engine~table(self~childTable)
  if child == .nil then return .true
  parent = event~engine~table(self~parentTable)
  parentCol = parent~definition~column(self~parentColumn)
  childCol = child~definition~column(self~childColumn)

  do change over event~changes
    before = change["before"]
    after = change["after"]
    oldValue = before[self~parentColumn]
    newValue = after[self~parentColumn]
    changed = .false
    if oldValue == .nil & newValue \== .nil then changed = .true
    else if oldValue \== .nil & newValue == .nil then changed = .true
    else if oldValue \== .nil & newValue \== .nil then changed = \parentCol~compare(oldValue, "=", newValue)
    if \changed then iterate

    if self~onUpdate = "CASCADE" | self~onUpdate = "SET NULL" then do
      if event~mutationGraph == .nil then do
        ignore = event~veto("FOREIGN KEY cascading update requires staged mutation graph")
        return .false
      end
      iterate
    end

    if self~onUpdate = "NO ACTION" | self~onUpdate = "RESTRICT" then do
      do crow over child~storage~readRows
        childValue = crow[self~childColumn]
        if childValue == .nil then iterate
        if childCol~compare(childValue, "=", oldValue) then do
          ignore = event~veto("FOREIGN KEY update restrict failed: " || self~childTable || "." || self~childColumn || " references " || self~parentTable || "." || self~parentColumn)
          return .false
        end
      end
    end
  end
  return .true

::method cascadeParentUpdateAfter private
  use arg event
  if \event~tableName~caselessEquals(self~parentTable) then return .true
  if self~onUpdate \= "CASCADE" & self~onUpdate \= "SET NULL" then return .true
  graph = event~mutationGraph
  if graph == .nil then return .false

  parent = event~engine~table(self~parentTable)
  parentCol = parent~definition~column(self~parentColumn)
  do change over event~changes
    before = change["before"]
    after = change["after"]
    oldValue = before[self~parentColumn]
    newValue = after[self~parentColumn]
    changed = .false
    if oldValue == .nil & newValue \== .nil then changed = .true
    else if oldValue \== .nil & newValue == .nil then changed = .true
    else if oldValue \== .nil & newValue \== .nil then changed = \parentCol~compare(oldValue, "=", newValue)
    if \changed then iterate

    if self~onUpdate = "CASCADE" then graph~stageUpdateWhereEquals(self~childTable, self~childColumn, oldValue, self~childColumn, newValue)
    else graph~stageSetNullWhereEquals(self~childTable, self~childColumn, oldValue)
    if graph~state = "FAILED" then return .false
  end
  return .true

::class DatabaseEventType public
::constant BEFORE_INSERT "BEFORE_INSERT"
::constant AFTER_INSERT  "AFTER_INSERT"
::constant BEFORE_UPDATE "BEFORE_UPDATE"
::constant AFTER_UPDATE  "AFTER_UPDATE"
::constant BEFORE_DELETE "BEFORE_DELETE"
::constant AFTER_DELETE  "AFTER_DELETE"
::constant BEFORE_COMMIT "BEFORE_COMMIT"
::constant AFTER_COMMIT  "AFTER_COMMIT"

::class DatabaseEvent public
::attribute type
::attribute phase
::attribute operation
::attribute tableName
::attribute changes
::attribute engine
::attribute vetoed
::attribute vetoMessage
::attribute canVeto
::attribute metadata
::attribute mutationGraph

::method init
  use arg type, tableName, operation, changes, engine, canVeto = .false
  self~type = type
  self~tableName = tableName
  self~operation = operation
  self~changes = changes
  self~engine = engine
  self~canVeto = canVeto
  self~vetoed = .false
  self~vetoMessage = ""
  self~metadata = .table~new
  self~mutationGraph = engine~mutationGraph
  if type~translate~startsWith("BEFORE_") then self~phase = "BEFORE"
  else self~phase = "AFTER"

::method veto
  use arg message = "Database event vetoed"
  if \self~canVeto then return .false
  self~vetoed = .true
  self~vetoMessage = message~string
  return .true

::method rowCount
  if self~changes == .nil then return 0
  return self~changes~items

::class DatabaseEventRegistration public
::attribute id
::attribute eventType
::attribute tableName
::attribute handler
::attribute enabled

::method init
  use arg id, eventType, tableName, handler
  self~id = id
  self~eventType = eventType~string~translate
  self~tableName = tableName~string
  self~handler = handler
  self~enabled = .true

::class DatabaseEventRegistry public
::attribute root
::attribute registrations
::attribute nextId
::attribute systemKeys

::method init
  use arg root
  self~root = root
  self~registrations = .array~new
  self~nextId = 1
  self~systemKeys = .table~new

::method on
  guard on
  use arg eventType, tableName, handler
  if handler == .nil then do
    guard off
    return .nil
  end
  id = self~nextId
  self~nextId = id + 1
  registration = .DatabaseEventRegistration~new(id, eventType, tableName, handler)
  self~registrations~append(registration)
  guard off
  return registration

::method onUnique
  guard on
  use arg key, eventType, tableName, handler
  existing = self~systemKeys[key]
  if existing \== .nil then do
    guard off
    return existing
  end
  id = self~nextId
  self~nextId = id + 1
  registration = .DatabaseEventRegistration~new(id, eventType, tableName, handler)
  self~registrations~append(registration)
  self~systemKeys[key] = registration
  guard off
  return registration

::method off
  guard on
  use arg registration
  if registration == .nil then do
    guard off
    return .false
  end
  do item over self~registrations
    if item == registration then do
      item~enabled = .false
      guard off
      return .true
    end
  end
  guard off
  return .false

::method dispatch
  use arg event
  -- Snapshot the registration list under guard; callbacks execute outside the
  -- guard so a handler may safely register/unregister other listeners.
  guard on
  snapshot = .array~new
  do item over self~registrations
    if item~enabled then snapshot~append(item)
  end
  guard off

  do item over snapshot
    if \item~enabled then iterate
    if \item~eventType~caselessEquals(event~type) then iterate
    if item~tableName \= "*" then do
      if \item~tableName~caselessEquals(event~tableName) then iterate
    end
    handler = item~handler
    if handler~hasMethod("ON_DATABASE_EVENT") then ignore = handler~on_database_event(event)
    else if handler~hasMethod("ONDATABASEEVENT") then ignore = handler~onDatabaseEvent(event)
    else raise syntax 93.900 additional("Database event handler requires onDatabaseEvent(event)")
    if event~vetoed then leave
  end
  return event

::class QueryPatternLog public
::attribute root

::method init
  use arg root
  self~root = root

::method record
  guard on
  use arg tableName, predicate, rowsScanned = 0, rowsReturned = 0
  if predicate == .nil then return .nil
  if \predicate~isA(.SQLComparisonPredicate) then return .nil
  if predicate~operator \= "=" then return .nil
  dir = self~root || "/querylog"
  call SysMkDir dir
  path = dir || "/patterns.yaml"
  if stream(path, "c", "query exists") \= "" then raw = .Yaml~new~parseFile(path)
  else raw = .table~new
  key = tableName~translate || "." || predicate~column~translate || ".EQ"
  item = raw[key]
  if item == .nil then do
    item = .table~new
    item["table"] = tableName
    item["column"] = predicate~column
    item["kind"] = "EQUALITY"
    item["operator"] = "="
    item["count"] = 0
    item["rowsScanned"] = 0
    item["rowsReturned"] = 0
  end
  item["count"] = item["count"] + 1
  item["rowsScanned"] = item["rowsScanned"] + rowsScanned
  item["rowsReturned"] = item["rowsReturned"] + rowsReturned
  raw[key] = item
  self~publish(raw, path)
  return item

::method recordJoin
  guard on
  use arg leftTable, leftColumn, rightTable, rightColumn, rowsScanned = 0, rowsReturned = 0
  dir = self~root || "/querylog"
  call SysMkDir dir
  path = dir || "/patterns.yaml"
  if stream(path, "c", "query exists") \= "" then raw = .Yaml~new~parseFile(path)
  else raw = .table~new
  key = "JOIN." || leftTable~translate || "." || leftColumn~translate || "." || rightTable~translate || "." || rightColumn~translate
  item = raw[key]
  if item == .nil then do
    item = .table~new
    item["kind"] = "JOIN"
    item["leftTable"] = leftTable
    item["leftColumn"] = leftColumn
    item["rightTable"] = rightTable
    item["rightColumn"] = rightColumn
    item["count"] = 0
    item["rowsScanned"] = 0
    item["rowsReturned"] = 0
  end
  item["count"] = item["count"] + 1
  item["rowsScanned"] = item["rowsScanned"] + rowsScanned
  item["rowsReturned"] = item["rowsReturned"] + rowsReturned
  raw[key] = item
  self~publish(raw, path)
  return item

::method publish private
  use arg raw, path
  tmp = path || ".new"
  old = path || ".old"
  .Yaml~toYamlFile(raw, tmp)
  call SysFileDelete old
  if stream(path, "c", "query exists") \= "" then call SysFileMove path, old
  moveRc = SysFileMove(tmp, path)
  if moveRc \= 0 then do
    if stream(old, "c", "query exists") \= "" then call SysFileMove old, path
    raise syntax 93.900 additional("Unable to publish query pattern log")
  end
  call SysFileDelete old
  return .true

::method candidates
  guard on
  use arg threshold = 3
  out = .array~new
  path = self~root || "/querylog/patterns.yaml"
  if stream(path, "c", "query exists") = "" then return out
  raw = .Yaml~new~parseFile(path)
  do key over raw
    item = raw[key]
    kind = item["kind"]
    if kind == .nil then kind = "EQUALITY"
    if kind = "EQUALITY" then do
      if item["count"] >= threshold then out~append(item)
    end
  end
  return out

::method joinCandidates
  guard on
  use arg threshold = 3
  out = .array~new
  path = self~root || "/querylog/patterns.yaml"
  if stream(path, "c", "query exists") = "" then return out
  raw = .Yaml~new~parseFile(path)
  do key over raw
    item = raw[key]
    if item["kind"] = "JOIN" then do
      if item["count"] >= threshold then out~append(item)
    end
  end
  return out

::class DatabaseIndexSnapshot public
::attribute name
::attribute tableName
::attribute column
::attribute indexedThrough
::attribute state
::attribute path
::attribute map
::attribute rowsMap

::method init
  use arg path
  self~path = path
  raw = .Yaml~new~parseFile(path)
  self~name = raw["name"]
  self~tableName = raw["table"]
  self~column = raw["column"]
  self~indexedThrough = raw["indexedThrough"]
  self~state = raw["state"]
  self~map = raw["map"]
  self~rowsMap = raw["rows"]
  if self~rowsMap == .nil then self~rowsMap = .table~new

::method lookup
  use arg key
  values = self~map[key~string]
  if values == .nil then return .array~new
  return values

::method lookupRows
  use arg key
  rawRows = self~rowsMap[key~string]
  out = .array~new
  if rawRows == .nil then return out
  do rawRow over rawRows
    out~append(.DatabaseRow~new(rawRow))
  end
  return out

::method relationTo
  use arg tableGeneration
  if self~indexedThrough = tableGeneration then return "CURRENT"
  if self~indexedThrough < tableGeneration then return "BEHIND"
  return "AHEAD_INVALID"

::class DatabaseIndexer public
::attribute table
::attribute column
::attribute indexRoot
::attribute state
::attribute indexedThrough

::attribute owner
::attribute buildKey

::method init
  use arg table, column, owner = .nil, buildKey = .nil
  self~table = table
  self~owner = owner
  self~buildKey = buildKey
  canonical = table~definition~canonicalColumn(column)
  if canonical == .nil then raise syntax 93.900 additional("Unknown index column:" column)
  if table~definition~primaryKey~items = 0 then raise syntax 93.900 additional("Adaptive indexes currently require a PRIMARY KEY")
  self~column = canonical
  self~indexRoot = table~path || "/indexes"
  self~state = "MISSING"
  self~indexedThrough = 0

::method start
  msg = .Message~new(self, "BUILD")
  msg~start
  return msg

::method build
  self~state = "BUILDING"
  stable = .false
  do attempt = 1 to 8 while \stable
    targetGeneration = self~table~generation
    rows = self~table~storage~readRows
    stable = self~table~generation = targetGeneration
  end
  if \stable then do
    self~state = "DEFERRED"
    if self~owner \== .nil then self~owner~buildFinished(self~buildKey)
    return .nil
  end
  indexMap = .table~new
  rowMap = .table~new
  do row over rows
    value = row[self~column]
    if value == .nil then iterate
    key = value~string
    refs = indexMap[key]
    if refs == .nil then refs = .array~new
    refs~append(self~table~primaryKeySignature(row))
    indexMap[key] = refs
    indexedRows = rowMap[key]
    if indexedRows == .nil then indexedRows = .array~new
    indexedRows~append(row~values~copy)
    rowMap[key] = indexedRows
  end
  call SysMkDir self~indexRoot
  name = "idx_" || self~column~translate
  tmp = self~indexRoot || "/" || name || ".yaml.new"
  final = self~indexRoot || "/" || name || ".yaml"
  raw = .table~new
  raw["name"] = name
  raw["type"] = "value-index"
  raw["table"] = self~table~definition~name
  raw["column"] = self~column
  raw["state"] = "USABLE"
  raw["indexedThrough"] = targetGeneration
  raw["targetGeneration"] = targetGeneration
  raw["map"] = indexMap
  raw["rows"] = rowMap
  .Yaml~toYamlFile(raw, tmp)
  call SysFileDelete final || ".old"
  if stream(final, "c", "query exists") \= "" then call SysFileMove final, final || ".old"
  moveRc = SysFileMove(tmp, final)
  if moveRc \= 0 then raise syntax 93.900 additional("Unable to publish index")
  call SysFileDelete final || ".old"
  self~indexedThrough = targetGeneration
  self~state = "USABLE"
  if self~owner \== .nil then self~owner~buildFinished(self~buildKey)
  return .DatabaseIndexSnapshot~new(final)

::class DatabaseJoinMapSnapshot public
::attribute path
::attribute leftTableName
::attribute leftColumn
::attribute leftIndexedThrough
::attribute rightTableName
::attribute rightColumn
::attribute rightIndexedThrough
::attribute state
::attribute map
::attribute leftRows
::attribute rightRows

::method init
  use arg path
  self~path = path
  raw = .Yaml~new~parseFile(path)
  self~leftTableName = raw["leftTable"]
  self~leftColumn = raw["leftColumn"]
  self~leftIndexedThrough = raw["leftIndexedThrough"]
  self~rightTableName = raw["rightTable"]
  self~rightColumn = raw["rightColumn"]
  self~rightIndexedThrough = raw["rightIndexedThrough"]
  self~state = raw["state"]
  self~map = raw["map"]
  self~leftRows = self~decodeSide(raw["leftRows"])
  self~rightRows = self~decodeSide(raw["rightRows"])

::method decodeSide private
  use arg rawSide
  out = .table~new
  if rawSide == .nil then return out
  do key over rawSide
    arr = .array~new
    rawRows = rawSide[key]
    if rawRows \== .nil then do rawRow over rawRows
      arr~append(.DatabaseRow~new(rawRow))
    end
    out[key] = arr
  end
  return out

::method relationTo
  use arg leftGeneration, rightGeneration
  if self~leftIndexedThrough > leftGeneration then return "AHEAD_INVALID"
  if self~rightIndexedThrough > rightGeneration then return "AHEAD_INVALID"
  if self~leftIndexedThrough = leftGeneration then do
    if self~rightIndexedThrough = rightGeneration then return "CURRENT"
  end
  return "BEHIND"

::method rowSnapshotCount
  count = 0
  do key over self~leftRows
    count += self~leftRows[key]~items
  end
  do key over self~rightRows
    count += self~rightRows[key]~items
  end
  return count

::class DatabaseJoinMapBuilder public
::attribute leftTable
::attribute leftColumn
::attribute rightTable
::attribute rightColumn
::attribute mapRoot
::attribute owner
::attribute buildKey

::method init
  use arg leftTable, leftColumn, rightTable, rightColumn, mapRoot, owner = .nil, buildKey = .nil
  self~leftTable = leftTable
  self~rightTable = rightTable
  self~owner = owner
  self~buildKey = buildKey
  if leftTable~definition~primaryKey~items = 0 then raise syntax 93.900 additional("Join maps currently require a left PRIMARY KEY")
  if rightTable~definition~primaryKey~items = 0 then raise syntax 93.900 additional("Join maps currently require a right PRIMARY KEY")
  self~leftColumn = leftTable~definition~canonicalColumn(leftColumn)
  self~rightColumn = rightTable~definition~canonicalColumn(rightColumn)
  if self~leftColumn == .nil then raise syntax 93.900 additional("Unknown left join column")
  if self~rightColumn == .nil then raise syntax 93.900 additional("Unknown right join column")
  self~mapRoot = mapRoot

::method start
  msg = .Message~new(self, "BUILD")
  msg~start
  return msg

::method build
  stable = .false
  do attempt = 1 to 8 while \stable
    leftGeneration = self~leftTable~generation
    rightGeneration = self~rightTable~generation
    leftSide = self~mapSide(self~leftTable, self~leftColumn)
    rightSide = self~mapSide(self~rightTable, self~rightColumn)
    stable = self~leftTable~generation = leftGeneration
    if stable then stable = self~rightTable~generation = rightGeneration
  end
  if \stable then do
    if self~owner \== .nil then self~owner~buildFinished(self~buildKey)
    return .nil
  end
  leftMap = leftSide["refs"]
  rightMap = rightSide["refs"]
  keys = .table~new
  do key over leftMap
    if rightMap[key] \== .nil then do
      entry = .table~new
      entry["left"] = leftMap[key]
      entry["right"] = rightMap[key]
      keys[key] = entry
    end
  end
  call SysMkDir self~mapRoot
  raw = .table~new
  raw["type"] = "join-map"
  raw["leftTable"] = self~leftTable~definition~name
  raw["leftColumn"] = self~leftColumn
  raw["leftIndexedThrough"] = leftGeneration
  raw["rightTable"] = self~rightTable~definition~name
  raw["rightColumn"] = self~rightColumn
  raw["rightIndexedThrough"] = rightGeneration
  raw["state"] = "USABLE"
  raw["map"] = keys
  raw["leftRows"] = leftSide["rows"]
  raw["rightRows"] = rightSide["rows"]
  name = self~leftTable~definition~name || "_" || self~leftColumn || "__" || self~rightTable~definition~name || "_" || self~rightColumn || ".yaml"
  tmp = self~mapRoot || "/" || name || ".new"
  path = self~mapRoot || "/" || name
  .Yaml~toYamlFile(raw, tmp)
  call SysFileDelete path || ".old"
  if stream(path, "c", "query exists") \= "" then call SysFileMove path, path || ".old"
  moveRc = SysFileMove(tmp, path)
  if moveRc \= 0 then raise syntax 93.900 additional("Unable to publish join map")
  call SysFileDelete path || ".old"
  if self~owner \== .nil then self~owner~buildFinished(self~buildKey)
  return path

::method mapSide private
  use arg table, column
  refsMap = .table~new
  rowsMap = .table~new
  do row over table~storage~readRows
    v = row[column]
    if v == .nil then iterate
    key = v~string
    refs = refsMap[key]
    if refs == .nil then refs = .array~new
    refs~append(self~pkSignature(table, row))
    refsMap[key] = refs
    rows = rowsMap[key]
    if rows == .nil then rows = .array~new
    rows~append(row~values~copy)
    rowsMap[key] = rows
  end
  side = .table~new
  side["refs"] = refsMap
  side["rows"] = rowsMap
  return side


::method pkSignature private
  use arg table, row
  sig = ""
  first = .true
  do name over table~definition~primaryKey
    if \first then sig ||= "1F"x
    v = row[name]
    if v == .nil then v = ""
    sig ||= v~string
    first = .false
  end
  return sig

::class NoSQLServerSQL subclass NoSQLAlchemyObject public
::attribute engine

::method init
  use arg engine, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("SQL_EXECUTOR", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("EXECUTE", "parse and execute one SQL statement", "UNKNOWN")
  self~registerNoSQLMethod("VERSION", "return backend version information", "READ")
  self~engine = engine

::method version
  return self~engine~version

::method execute
  use arg sql
  text = self~normalizeSQLGrammarWhitespace(sql~string)
  if text~right(1) = ";" then text = text~left(text~length - 1)~strip
  upper = text~translate

  signal on syntax name sqlSyntaxError
  select
    when upper~startsWith("CREATE TABLE ") then return self~executeCreateTable(text)
    when upper~startsWith("DROP TABLE ") then return self~executeDropTable(text)
    when upper~startsWith("WITH RECURSIVE ") then return self~executeRecursiveCTE(text)
    when upper~startsWith("WITH ") then return self~executeCTEQuery(text)
    when upper~startsWith("SELECT ") then do
      fetched = self~splitTopLevelFetchWithTies(text)
      if fetched["error"] \== .nil then return fetched["error"]
      limited = self~splitTopLevelLimit(fetched["sql"])
      if limited["error"] \== .nil then return limited["error"]
      if fetched["count"] \== .nil & limited["limit"] \== .nil then return self~sqlParseFailure("FETCH FIRST and LIMIT may not be combined")
      selectText = limited["sql"]
      if self~hasTopLevelSetOperation(selectText) then rs = self~executeSetSelect(selectText)
      else if self~hasTopLevelUnion(selectText) then rs = self~executeUnionSelect(selectText)
      else do
        sortBound = .nil
        if limited["limit"] \== .nil then sortBound = limited["offset"] + limited["limit"]
        rs = self~executeSelect(selectText, sortBound)
      end
      if rs~status \= .Error~SUCCESS then return rs
      if fetched["count"] \== .nil then return self~applyFetchWithTies(rs, fetched["count"], fetched["orderBy"])
      return self~applyLimitOffset(rs, limited["limit"], limited["offset"])
    end
    when upper~word(1) = "INSERT" & upper~word(2) = "INTO" then return self~executeInsert(text)
    when upper~startsWith("UPDATE ") then return self~executeUpdate(text)
    when upper~startsWith("DELETE FROM ") then return self~executeDelete(text)
    otherwise do
      firstWord = upper~word(1)
      if wordpos(firstWord, "CREATE DROP SELECT INSERT UPDATE DELETE ALTER BEGIN COMMIT ROLLBACK WITH EXPLAIN MERGE") = 0 then ,
        return self~sqlParseFailure("Unknown SQL statement keyword: " || firstWord)
      return self~sqlUnsupported("Unsupported SQL statement")
    end
  end
sqlSyntaxError:
  conditionObject = condition("O")
  signal off syntax
  messageText = conditionObject["MESSAGE"]
  if messageText == .nil | messageText = "" then messageText = conditionObject["ADDITIONAL"]
  if messageText == .nil then messageText = "SQL parser raised an ooRexx SYNTAX condition"
  return self~sqlParseFailure(messageText~string)

::method normalizeSQLGrammarWhitespace private
  use arg sqlText
  text = sqlText~string
  out = ""
  quote = ""
  pendingSpace = .false
  i = 1
  do while i <= text~length
    ch = text~substr(i, 1)
    if quote \= "" then do
      out ||= ch
      if ch = quote then do
        doubled = .false
        if i < text~length then do
          if text~substr(i + 1, 1) = quote then doubled = .true
        end
        if doubled then do
          out ||= quote
          i += 1
        end
        else quote = ""
      end
      i += 1
      iterate
    end

    if ch = "'" | ch = '"' then do
      if pendingSpace & out \= "" then out ||= " "
      pendingSpace = .false
      quote = ch
      out ||= ch
      i += 1
      iterate
    end

    if self~isSQLWhitespace(ch) then do
      pendingSpace = .true
      i += 1
      iterate
    end

    if pendingSpace & out \= "" then out ||= " "
    pendingSpace = .false
    out ||= ch
    i += 1
  end
  return out~strip

::method splitTopLevelFetchWithTies private
  use arg text
  out = .table~new
  out["sql"] = text
  out["count"] = .nil
  out["orderBy"] = ""
  out["error"] = .nil

  fetchPos = self~findTopLevelKeyword(text, " FETCH FIRST ")
  if fetchPos = 0 then return out

  clause = text~substr(fetchPos + 13)~strip
  base = text~left(fetchPos - 1)~strip
  words = clause~space~makeArray(" ")
  if words~items \= 4 then do
    out["error"] = self~sqlParseFailure("FETCH FIRST syntax is FETCH FIRST count ROWS WITH TIES")
    return out
  end
  if \datatype(words[1], "W") | words[1] < 0 then do
    out["error"] = self~sqlParseFailure("FETCH FIRST requires a non-negative integer")
    return out
  end
  if words[2]~translate \= "ROWS" | words[3]~translate \= "WITH" | words[4]~translate \= "TIES" then do
    out["error"] = self~sqlParseFailure("FETCH FIRST syntax is FETCH FIRST count ROWS WITH TIES")
    return out
  end

  orderPos = self~findTopLevelKeyword(base, " ORDER BY ")
  if orderPos = 0 then do
    out["error"] = self~sqlUnsupported("FETCH FIRST WITH TIES requires ORDER BY")
    return out
  end

  out["sql"] = base
  out["count"] = words[1]
  out["orderBy"] = base~substr(orderPos + 10)~strip
  return out

::method applyFetchWithTies private
  use arg rs, count, orderBy
  selected = .array~new
  if count = 0 | rs~rows~items = 0 then do
    rs~rows = selected
    rs~affectedRows = 0
    return rs
  end

  if count >= rs~rows~items then return rs

  do i = 1 to count
    selected~append(rs~rows[i])
  end

  boundary = rs~rows[count]
  i = count + 1
  do while i <= rs~rows~items
    if self~compareOrderRows(boundary, rs~rows[i], orderBy) \= 0 then leave
    selected~append(rs~rows[i])
    i += 1
  end

  rs~rows = selected
  rs~affectedRows = selected~items
  return rs

::method splitTopLevelLimit private
  use arg text
  out = .table~new
  out["sql"] = text
  out["limit"] = .nil
  out["offset"] = 0
  out["error"] = .nil

  limitPos = self~findTopLevelKeyword(text, " LIMIT ")
  if limitPos = 0 then return out

  clause = text~substr(limitPos + 7)~strip
  base = text~left(limitPos - 1)~strip
  if clause = "" then do
    out["error"] = self~sqlParseFailure("LIMIT requires a row count")
    return out
  end

  commaPos = clause~pos(",")
  if commaPos > 0 then do
    if clause~pos(",", commaPos + 1) > 0 then do
      out["error"] = self~sqlParseFailure("LIMIT accepts only offset,count")
      return out
    end
    offsetText = clause~left(commaPos - 1)~strip
    limitText = clause~substr(commaPos + 1)~strip
  end
  else do
    words = clause~space~makeArray(" ")
    if words~items = 1 then do
      limitText = words[1]
      offsetText = "0"
    end
    else if words~items = 3 then do
      if words[2]~translate \= "OFFSET" then do
        out["error"] = self~sqlParseFailure("LIMIT syntax is LIMIT count [OFFSET offset]")
        return out
      end
      limitText = words[1]
      offsetText = words[3]
    end
    else do
      out["error"] = self~sqlParseFailure("LIMIT syntax is LIMIT count [OFFSET offset]")
      return out
    end
  end

  if \datatype(limitText, "W") | \datatype(offsetText, "W") then do
    out["error"] = self~sqlParseFailure("LIMIT and OFFSET require non-negative integers")
    return out
  end
  if limitText < 0 | offsetText < 0 then do
    out["error"] = self~sqlParseFailure("LIMIT and OFFSET require non-negative integers")
    return out
  end

  out["sql"] = base
  out["limit"] = limitText
  out["offset"] = offsetText
  return out

::method applyLimitOffset private
  use arg rs, limit, offset = 0
  if limit == .nil then return rs
  selected = .array~new
  first = offset + 1
  if first > rs~rows~items then do
    rs~rows = selected
    rs~affectedRows = 0
    return rs
  end
  last = first + limit - 1
  if last > rs~rows~items then last = rs~rows~items
  if limit > 0 then do i = first to last
    selected~append(rs~rows[i])
  end
  rs~rows = selected
  rs~affectedRows = selected~items
  return rs

::method cteOutputShape private
  use arg selectText
  out = .table~new
  out["names"] = .array~new
  out["sourceNames"] = .array~new
  fromPos = self~findTopLevelKeyword(selectText, " FROM ")
  if fromPos = 0 then return .nil
  projection = selectText~substr(8, fromPos - 8)~strip
  if projection~translate~startsWith("DISTINCT ") then projection = projection~substr(10)~strip
  if projection = "*" then return .nil

  do item over self~splitList(projection)
    spec = self~parseProjectionSpec(item)
    if spec == .nil then return .nil
    sourceName = spec["alias"]
    if sourceName = "" then sourceName = spec["expression"]~strip
    outputName = spec["alias"]
    if outputName = "" then do
      outputName = spec["expression"]~strip
      dot = outputName~lastPos(".")
      if dot > 0 & outputName~pos("(") = 0 & outputName~pos(" ") = 0 then outputName = outputName~substr(dot + 1)
    end
    out["sourceNames"]~append(sourceName)
    out["names"]~append(outputName)
  end
  return out

::method materializeCTEResult private
  use arg cteName, bodyText, rs
  shape = self~cteOutputShape(bodyText)
  if shape == .nil then return .nil
  names = shape["names"]
  sourceNames = shape["sourceNames"]
  rows = .array~new
  do raw over rs~rows
    vals = .table~new
    do i = 1 to names~items
      vals[names[i]] = raw[sourceNames[i]]
    end
    rows~append(.DatabaseRow~new(vals))
  end
  return .SQLMaterializedTable~new(cteName, names, rows)

::method executeCTEQuery private
  use arg text
  after = text~substr(6)~strip
  overlay = .SQLCTEEngineOverlay~new(self~engine)
  child = .NoSQLServerSQL~new(overlay)
  cteCount = 0

  do forever
    asPos = self~findTopLevelKeyword(after, " AS ")
    if asPos = 0 then return self~sqlParseFailure("WITH requires CTE name and AS")
    cteName = after~left(asPos - 1)~strip
    if cteName = "" | cteName~words \= 1 then return self~sqlParseFailure("WITH currently requires simple CTE names")
    if cteName~pos("(") > 0 then return self~sqlUnsupported("WITH column-name lists are not implemented")

    tail = after~substr(asPos + 4)~strip
    if tail~left(1) \= "(" then return self~sqlParseFailure("WITH CTE AS requires a parenthesized query")
    close = self~matchingParen(tail, 1)
    if close = 0 then return self~sqlParseFailure("WITH CTE body is missing ')'")

    body = tail~substr(2, close - 2)~strip
    if \body~translate~startsWith("SELECT ") then return self~sqlUnsupported("WITH CTE body currently requires SELECT")
    bodyRs = child~execute(body)
    if bodyRs~status \= .Error~SUCCESS then return bodyRs

    table = self~materializeCTEResult(cteName, body, bodyRs)
    if table == .nil then return self~sqlUnsupported("WITH CTE requires explicit named/projectable SELECT columns")
    if overlay~cteTables[cteName~translate] \== .nil then return self~sqlParseFailure("Duplicate CTE name: " || cteName)
    overlay~registerCTE(cteName, table)
    cteCount += 1

    remainder = tail~substr(close + 1)~strip
    if remainder = "" then return self~sqlParseFailure("WITH requires an outer query")
    if remainder~left(1) = "," then do
      after = remainder~substr(2)~strip
      iterate
    end

    outerRs = child~execute(remainder)
    if outerRs~status = .Error~SUCCESS then do
      if cteCount > 1 then outerRs~accessPath = "MULTI_CTE_" || outerRs~accessPath
      else outerRs~accessPath = "CTE_" || outerRs~accessPath
    end
    return outerRs
  end

::method executeRecursiveCTE private
  use arg text
  prefix = "WITH RECURSIVE "
  after = text~substr(prefix~length + 1)~strip
  asPos = self~findTopLevelKeyword(after, " AS ")
  if asPos = 0 then return self~sqlParseFailure("WITH RECURSIVE requires CTE name and AS")
  cteName = after~left(asPos - 1)~strip
  if cteName = "" | cteName~words \= 1 then return self~sqlParseFailure("WITH RECURSIVE requires one simple CTE name")
  tail = after~substr(asPos + 4)~strip
  if tail~left(1) \= "(" then return self~sqlParseFailure("WITH RECURSIVE AS requires parenthesized CTE body")
  close = self~matchingParen(tail, 1)
  if close = 0 then return self~sqlParseFailure("WITH RECURSIVE CTE body is missing ')'")
  body = tail~substr(2, close - 2)~strip
  outer = tail~substr(close + 1)~strip
  if outer~translate~startsWith("SEARCH ") | outer~translate~startsWith("CYCLE ") then return self~sqlUnsupported("Recursive CTE SEARCH/CYCLE clauses are not implemented")
  unionPos = self~findTopLevelKeyword(body, " UNION ALL ")
  if unionPos = 0 then return self~sqlUnsupported("Recursive CTE requires anchor UNION ALL recursive term")
  anchorText = body~left(unionPos - 1)~strip
  recursiveText = body~substr(unionPos + 11)~strip
  anchorRs = self~executeSelect(anchorText)
  if anchorRs~status \= .Error~SUCCESS then return anchorRs
  names = self~selectOutputNames(anchorText)
  if names == .nil then return self~sqlUnsupported("Recursive CTE anchor '*' projection is not implemented")
  parse = self~parseRecursiveTerm(recursiveText, cteName, names)
  if parse["error"] \== .nil then return parse["error"]
  sourceObj = self~engine~table(parse["sourceTable"])
  if sourceObj == .nil then return self~sqlFailure("Table not found: " || parse["sourceTable"])
  cteDef = .SQLSyntheticDefinition~new(cteName, names)
  entries = .array~new
  sourceEntry = .table~new; sourceEntry["definition"] = sourceObj~definition; sourceEntry["alias"] = parse["sourceAlias"]; entries~append(sourceEntry)
  cteEntry = .table~new; cteEntry["definition"] = cteDef; cteEntry["alias"] = parse["cteAlias"]; entries~append(cteEntry)
  relation = .SQLAliasRelationDefinition~new(entries)
  onPredicate = .SQLPredicateParser~new~parse(parse["onText"])
  allRows = .array~new; delta = .array~new
  do row over anchorRs~rows; allRows~append(row~copy); delta~append(row~copy); end
  sourceRows = sourceObj~readRows
  iterations = 0
  do while delta~items > 0
    iterations += 1
    if iterations > 64 then return self~sqlFailure("Recursive CTE exceeded 64 iterations; possible cycle")
    nextDelta = .array~new
    do prior over delta
      do raw over sourceRows
        values = .table~new
        do col over sourceObj~definition~columns; values[parse["sourceAlias"] || "." || col~name] = raw[col~name]; end
        do i = 1 to names~items; values[parse["cteAlias"] || "." || names[i]] = prior[names[i]]; end
        combined = .DatabaseRow~new(values)
        if onPredicate~evaluate(combined, relation) then do
          if parse["whereText"] \= "" then do
            whereOk = self~evaluateRecursiveWhere(parse["whereText"], combined, relation)
            if whereOk == .nil then return self~sqlUnsupported("Recursive CTE WHERE expression is not implemented")
            if \whereOk then iterate
          end
          projected = self~projectRecursiveRow(parse["projection"], names, combined, relation)
          if projected == .nil then return self~sqlUnsupported("Recursive CTE projection expression is not implemented")
          nextDelta~append(projected); allRows~append(projected)
        end
      end
    end
    delta = nextDelta
  end
  return self~executeRecursiveOuter(outer, cteName, allRows)

::method parseRecursiveTerm private
  use arg text, cteName, names
  out = .table~new; out["error"] = .nil
  fromPos = self~findTopLevelKeyword(text, " FROM ")
  if fromPos = 0 then do; out["error"] = self~sqlParseFailure("Recursive term requires FROM"); return out; end
  projection = text~substr(8, fromPos - 8)~strip
  rest = self~normalizeInnerJoinSyntax(text~substr(fromPos + 6)~strip)
  joinPos = rest~translate~pos(" JOIN ")
  if joinPos = 0 then do; out["error"] = self~sqlUnsupported("Recursive term requires JOIN back to the CTE"); return out; end
  sourceRef = self~parseTableRef(rest~left(joinPos - 1)~strip)
  afterJoin = rest~substr(joinPos + 6)~strip; onPos = afterJoin~translate~pos(" ON ")
  if sourceRef == .nil | onPos = 0 then do; out["error"] = self~sqlParseFailure("Invalid recursive JOIN"); return out; end
  cteRef = self~parseTableRef(afterJoin~left(onPos - 1)~strip)
  if cteRef == .nil | \cteRef["table"]~caselessEquals(cteName) then do; out["error"] = self~sqlUnsupported("Recursive JOIN must reference the declared CTE"); return out; end
  recursiveSpecs = self~splitList(projection)
  if recursiveSpecs~items \= names~items then do; out["error"] = self~sqlParseFailure("Recursive CTE terms must project the same number of columns"); return out; end
  onAndWhere = afterJoin~substr(onPos + 4)~strip
  wherePos = self~findTopLevelKeyword(onAndWhere, " WHERE ")
  if wherePos > 0 then do
    out["onText"] = onAndWhere~left(wherePos - 1)~strip
    out["whereText"] = onAndWhere~substr(wherePos + 7)~strip
  end
  else do
    out["onText"] = onAndWhere
    out["whereText"] = ""
  end
  out["projection"] = projection
  out["sourceTable"] = sourceRef["table"]
  out["sourceAlias"] = sourceRef["alias"]
  out["cteAlias"] = cteRef["alias"]
  return out

::method evaluateRecursiveWhere private
  use arg whereText, row, relation
  signal on syntax name predicateFailure
  predicate = .SQLPredicateParser~new~parse(whereText)
  signal off syntax
  return predicate~evaluate(row, relation)

predicateFailure:
  signal off syntax
  return .nil

::method projectRecursiveRow private
  use arg projection, names, sourceRow, relation
  specs = self~splitList(projection); values = .table~new
  do i = 1 to specs~items
    expression = specs[i]~strip
    asPos = self~findTopLevelKeyword(expression, " AS ")
    if asPos > 0 then expression = expression~left(asPos - 1)~strip
    evaluated = self~evaluateProjectionExpression(expression, sourceRow, relation)
    if \evaluated["ok"] then return .nil
    values[names[i]] = evaluated["value"]
  end
  return .DatabaseRow~new(values)

::method executeRecursiveOuter private
  use arg outer, cteName, rows
  fromPos = self~findTopLevelKeyword(outer, " FROM ")
  if fromPos = 0 then return self~sqlParseFailure("Recursive CTE outer SELECT requires FROM")
  projection = outer~substr(8, fromPos - 8)~strip; rest = outer~substr(fromPos + 6)~strip; orderBy = ""
  orderPos = self~findTopLevelKeyword(rest, " ORDER BY ")
  if orderPos > 0 then do; orderBy = rest~substr(orderPos + 10)~strip; rest = rest~left(orderPos - 1)~strip; end
  ref = self~parseTableRef(rest)
  if ref == .nil | \ref["table"]~caselessEquals(cteName) then return self~sqlUnsupported("Recursive CTE outer SELECT must read the recursive CTE")
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = rows
  rs~affectedRows = rows~items
  rs~rowsScanned = rows~items
  rs~accessPath = "RECURSIVE_CTE_ITERATION"
  if projection \= "*" then do
    names = .array~new
    if rows~items > 0 then do key over rows[1]~values~allIndexes
      names~append(key)
    end
    definition = .SQLSyntheticDefinition~new(cteName, names)
    entries = .array~new
    entry = .table~new; entry["definition"] = definition; entry["alias"] = ref["alias"]; entries~append(entry)
    relation = .SQLAliasRelationDefinition~new(entries)
    qualifiedRows = .array~new
    do rawRow over rs~rows
      qualifiedRows~append(self~qualifiedAliasRow(entry, rawRow))
    end
    rs~rows = qualifiedRows
    rs = self~applyProjection(rs, projection, relation)
    if rs~status \= .Error~SUCCESS then return rs
  end
  return self~applyOrderBy(rs, orderBy)

::method hasTopLevelUnion private
  use arg text
  parts = self~splitTopLevelUnion(text)
  return parts~items > 1

::method hasTopLevelSetOperation private
  use arg text
  if self~findTopLevelKeyword(text, " INTERSECT ") > 0 then return .true
  if self~findTopLevelKeyword(text, " EXCEPT ") > 0 then return .true
  return .false

::method executeSetSelect private
  use arg text
  op = ""
  pos = self~findTopLevelKeyword(text, " INTERSECT ")
  if pos > 0 then op = "INTERSECT"
  else do
    pos = self~findTopLevelKeyword(text, " EXCEPT ")
    if pos > 0 then op = "EXCEPT"
  end
  if op = "" then return self~executeSelect(text)

  leftText = text~left(pos - 1)~strip
  rightText = text~substr(pos + op~length + 2)~strip

  corresponding = .false
  byNames = .nil
  if rightText~translate~startsWith("CORRESPONDING") then do
    corresponding = .true
    tail = rightText~substr(14)~strip
    if tail~translate~startsWith("BY ") then do
      tail = tail~substr(4)~strip
      if tail~left(1) \= "(" then return self~sqlParseFailure(op || " CORRESPONDING BY requires '(column,...)'")
      close = self~matchingParen(tail, 1)
      if close = 0 then return self~sqlParseFailure(op || " CORRESPONDING BY has unmatched '('")
      byText = tail~substr(2, close - 2)~strip
      if byText = "" then return self~sqlParseFailure(op || " CORRESPONDING BY requires at least one column")
      byNames = .array~new
      seenBy = .table~new
      do item over self~splitList(byText)
        name = item~strip
        if name = "" then return self~sqlParseFailure(op || " CORRESPONDING BY contains an empty column")
        if name~pos(".") > 0 | name~pos("(") > 0 | name~pos(" ") > 0 then ,
          return self~sqlUnsupported(op || " CORRESPONDING BY currently requires output column names")
        key = name~translate
        if seenBy[key] \== .nil then return self~sqlParseFailure(op || " CORRESPONDING BY repeats column: " || name)
        seenBy[key] = .true
        byNames~append(name)
      end
      rightText = tail~substr(close + 1)~strip
    end
    else rightText = tail
  end

  finalOrder = ""
  orderPos = self~findTopLevelKeyword(rightText, " ORDER BY ")
  if orderPos > 0 then do
    finalOrder = rightText~substr(orderPos + 10)~strip
    rightText = rightText~left(orderPos - 1)~strip
  end

  leftRs = self~executeSelect(leftText)
  if leftRs~status \= .Error~SUCCESS then return leftRs
  rightRs = self~executeSelect(rightText)
  if rightRs~status \= .Error~SUCCESS then return rightRs

  leftNames = self~selectOutputNames(leftText)
  rightNames = self~selectOutputNames(rightText)
  if leftNames == .nil | rightNames == .nil then return self~sqlUnsupported(op || " with '*' projection is not implemented")

  outputNames = .array~new
  if corresponding then do
    leftLookup = .table~new
    rightLookup = .table~new
    do n over leftNames; leftLookup[n~translate] = n; end
    do n over rightNames; rightLookup[n~translate] = n; end

    if byNames \== .nil then do
      do requested over byNames
        key = requested~translate
        if leftLookup[key] == .nil then return self~sqlParseFailure(op || " CORRESPONDING BY column is absent from left branch: " || requested)
        if rightLookup[key] == .nil then return self~sqlParseFailure(op || " CORRESPONDING BY column is absent from right branch: " || requested)
        outputNames~append(leftLookup[key])
      end
    end
    else do
      do ln over leftNames
        if rightLookup[ln~translate] \== .nil then outputNames~append(ln)
      end
      if outputNames~items = 0 then return self~sqlParseFailure(op || " CORRESPONDING requires at least one common output column")
    end
  end
  else do
    if leftNames~items \= rightNames~items then return self~sqlParseFailure(op || " branches must project the same number of columns")
    do n over leftNames; outputNames~append(n); end
  end

  rightSet = .table~new
  do row over rightRs~rows
    vals = .table~new
    if corresponding then do
      rightLookup = .table~new
      do n over rightNames; rightLookup[n~translate] = n; end
      do name over outputNames
        sourceName = rightLookup[name~translate]
        vals[name] = row[sourceName]
      end
    end
    else do
      do i = 1 to outputNames~items
        vals[outputNames[i]] = row[rightNames[i]]
      end
    end
    normalized = .DatabaseRow~new(vals)
    rightSet[self~rowSignature(normalized)] = .true
  end

  out = .array~new
  emitted = .table~new
  do row over leftRs~rows
    vals = .table~new
    do name over outputNames
      vals[name] = row[name]
    end
    normalized = .DatabaseRow~new(vals)
    sig = self~rowSignature(normalized)
    include = .false
    if op = "INTERSECT" then include = (rightSet[sig] \== .nil)
    else include = (rightSet[sig] == .nil)
    if include & emitted[sig] == .nil then do
      emitted[sig] = .true
      out~append(normalized)
    end
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = out
  rs~affectedRows = out~items
  rs~rowsScanned = leftRs~rowsScanned + rightRs~rowsScanned
  rs~accessPath = "SET_" || op
  if corresponding then rs~accessPath ||= "_CORRESPONDING"

  if finalOrder \= "" then do
    words = finalOrder~space~makeArray(" ")
    if words~items >= 1 then do
      if words[1]~datatype("W") then do
        ord = words[1]
        if ord >= 1 & ord <= outputNames~items then do
          replacement = outputNames[ord]
          if words~items > 1 then replacement ||= " " || words[2]
          finalOrder = replacement
        end
      end
    end
  end
  return self~applyOrderBy(rs, finalOrder)

::method executeUnionCorrespondingSelect private
  use arg text
  unionPos = self~findTopLevelKeyword(text, " UNION CORRESPONDING ")
  if unionPos = 0 then return self~sqlParseFailure("UNION CORRESPONDING boundary not found")

  leftText = text~left(unionPos - 1)~strip
  rightText = text~substr(unionPos + 21)~strip
  finalOrder = ""
  orderPos = self~findTopLevelKeyword(rightText, " ORDER BY ")
  if orderPos > 0 then do
    finalOrder = rightText~substr(orderPos + 10)~strip
    rightText = rightText~left(orderPos - 1)~strip
  end

  leftRs = self~executeSelect(leftText)
  if leftRs~status \= .Error~SUCCESS then return leftRs
  rightRs = self~executeSelect(rightText)
  if rightRs~status \= .Error~SUCCESS then return rightRs

  leftNames = self~selectOutputNames(leftText)
  rightNames = self~selectOutputNames(rightText)
  if leftNames == .nil | rightNames == .nil then return self~sqlUnsupported("UNION CORRESPONDING with '*' projection is not implemented")

  common = .array~new
  rightLookup = .table~new
  do rn over rightNames
    rightLookup[rn~translate] = rn
  end
  do ln over leftNames
    if rightLookup[ln~translate] \== .nil then common~append(ln)
  end
  if common~items = 0 then return self~sqlParseFailure("UNION CORRESPONDING requires at least one common output column")

  outRows = .array~new
  seen = .table~new
  do side = 1 to 2
    if side = 1 then do
      rs = leftRs
      names = leftNames
    end
    else do
      rs = rightRs
      names = rightNames
    end
    lookup = .table~new
    do n over names
      lookup[n~translate] = n
    end
    do row over rs~rows
      values = .table~new
      do name over common
        sourceName = lookup[name~translate]
        values[name] = row[sourceName]
      end
      normalized = .DatabaseRow~new(values)
      sig = self~rowSignature(normalized)
      if seen[sig] \== .nil then iterate
      seen[sig] = .true
      outRows~append(normalized)
    end
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = outRows
  rs~affectedRows = outRows~items
  rs~rowsScanned = leftRs~rowsScanned + rightRs~rowsScanned
  rs~accessPath = "UNION_CORRESPONDING"
  return self~applyOrderBy(rs, finalOrder)

::method executeUnionSelect private
  use arg text
  if self~findTopLevelKeyword(text, " UNION CORRESPONDING ") > 0 then return self~executeUnionCorrespondingSelect(text)
  parts = self~splitTopLevelUnion(text)
  if parts~items < 2 then return self~executeSelect(text)
  finalOrder = ""
  last = parts[parts~items]
  pos = self~findTopLevelKeyword(last, " ORDER BY ")
  if pos > 0 then do
    finalOrder = last~substr(pos + 10)~strip
    parts[parts~items] = last~left(pos - 1)~strip
  end
  outRows = .array~new
  seen = .table~new
  totalScanned = 0
  firstNames = .nil
  normalizeByOrdinal = .true
  do part over parts
    branchText = part~strip
    rs = self~executeSelect(branchText)
    if rs~status \= .Error~SUCCESS then return rs
    totalScanned += rs~rowsScanned
    branchNames = self~selectOutputNames(branchText)
    if branchNames == .nil then normalizeByOrdinal = .false
    else if firstNames == .nil then firstNames = branchNames
    else if branchNames~items \= firstNames~items then return self~sqlParseFailure("UNION branches must project the same number of columns")
    do row over rs~rows
      normalizedRow = row
      if normalizeByOrdinal & firstNames \== .nil & branchNames \== .nil then do
        values = .table~new
        do i = 1 to firstNames~items
          values[firstNames[i]] = row[branchNames[i]]
        end
        normalizedRow = .DatabaseRow~new(values)
      end
      sig = self~rowSignature(normalizedRow)
      if seen[sig] \== .nil then iterate
      seen[sig] = .true
      outRows~append(normalizedRow)
    end
  end
  resultSet = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  resultSet~rows = outRows
  resultSet~affectedRows = outRows~items
  resultSet~rowsScanned = totalScanned
  resultSet~accessPath = "UNION_DISTINCT"
  return self~applyOrderBy(resultSet, finalOrder)


::method selectOutputNames private
  use arg selectText
  fromPos = self~findTopLevelKeyword(selectText, " FROM ")
  if fromPos = 0 then return .nil
  projection = selectText~substr(8, fromPos - 8)~strip
  if projection~translate~startsWith("DISTINCT ") then projection = projection~substr(10)~strip
  if projection = "*" then return .nil
  names = .array~new
  do item over self~splitList(projection)
    spec = self~parseProjectionSpec(item)
    if spec == .nil then return .nil
    name = spec["alias"]
    if name = "" then name = spec["expression"]~strip
    names~append(name)
  end
  return names

::method expandSetSubqueryPredicates private
  use arg predicateText
  out = .table~new
  out["error"] = .nil
  work = predicateText

  -- Scalar NOT IN subquery.  WHERE semantics must preserve SQL's NULL trap:
  -- if the subquery contains any NULL, NOT IN is UNKNOWN for every non-matching
  -- candidate (and therefore does not pass WHERE).
  do forever
    upper = work~translate
    inPos = upper~pos(" NOT IN (")
    if inPos = 0 then leave
    prefix = work~left(inPos - 1)~strip
    andPos = prefix~translate~lastPos(" AND ")
    orPos = prefix~translate~lastPos(" OR ")
    cut = andPos
    if orPos > cut then cut = orPos
    if cut > 0 then lhs = prefix~substr(cut + 5)~strip
    else lhs = prefix
    if lhs = "" then do
      out["error"] = self~sqlParseFailure("NOT IN requires a left expression")
      return out
    end
    openPos = work~pos("(", inPos)
    closePos = self~matchingParen(work, openPos)
    if closePos = 0 then do
      out["error"] = self~sqlParseFailure("NOT IN subquery has unmatched '('")
      return out
    end
    subText = work~substr(openPos + 1, closePos - openPos - 1)~strip
    if \subText~translate~startsWith("SELECT ") then do
      out["error"] = self~sqlUnsupported("NOT IN lists are not implemented; SELECT subquery required")
      return out
    end
    subRs = self~executeSelect(subText)
    if subRs~status \= .Error~SUCCESS then do; out["error"] = subRs; return out; end
    names = self~selectOutputNames(subText)
    if names == .nil | names~items \= 1 then do
      out["error"] = self~sqlParseFailure("NOT IN subquery must project one column")
      return out
    end
    hasNull = .false
    replacement = ""
    do row over subRs~rows
      value = row[names[1]]
      if value == .nil then do; hasNull = .true; iterate; end
      piece = lhs || " <> " || self~sqlLiteralForDynamicValue(value)
      if replacement = "" then replacement = piece
      else replacement ||= " AND " || piece
    end
    if hasNull then replacement = "1 = 0"
    else if replacement = "" then replacement = "1 = 1"
    if cut > 0 then before = prefix~left(cut + 4)
    else before = ""
    work = before || "(" || replacement || ")" || work~substr(closePos + 1)
  end

  -- Row-value IN: (a,b) IN (SELECT x,y ...)
  do forever
    upper = work~translate
    inPos = upper~pos(" IN (")
    if inPos = 0 then leave
    prefix = work~left(inPos - 1)~strip
    if prefix~right(1) \= ")" then leave   -- scalar IN remains on the established path
    tupleOpen = prefix~lastPos("(")
    if tupleOpen = 0 then leave
    tupleText = prefix~substr(tupleOpen + 1, prefix~length - tupleOpen - 1)
    leftItems = self~splitList(tupleText)
    if leftItems~items < 2 then leave
    openPos = work~pos("(", inPos)
    closePos = self~matchingParen(work, openPos)
    if closePos = 0 then do
      out["error"] = self~sqlParseFailure("IN subquery has unmatched '('")
      return out
    end
    subText = work~substr(openPos + 1, closePos - openPos - 1)~strip
    if \subText~translate~startsWith("SELECT ") then do
      out["error"] = self~sqlUnsupported("Row-value IN lists are not implemented")
      return out
    end
    subRs = self~executeSelect(subText)
    if subRs~status \= .Error~SUCCESS then do
      out["error"] = subRs
      return out
    end
    names = self~selectOutputNames(subText)
    if names == .nil then do
      out["error"] = self~sqlUnsupported("Row-value IN subquery requires explicit projection")
      return out
    end
    if names~items \= leftItems~items then do
      out["error"] = self~sqlParseFailure("Row-value IN arity does not match subquery projection")
      return out
    end
    replacement = ""
    do row over subRs~rows
      term = ""
      do i = 1 to leftItems~items
        value = row[names[i]]
        literal = self~sqlLiteralForDynamicValue(value)
        piece = leftItems[i]~strip || " = " || literal
        if term = "" then term = piece
        else term ||= " AND " || piece
      end
      if replacement = "" then replacement = "(" || term || ")"
      else replacement ||= " OR (" || term || ")"
    end
    if replacement = "" then replacement = "1 = 0"
    before = prefix~left(tupleOpen - 1)
    work = before || "(" || replacement || ")" || work~substr(closePos + 1)
  end

  -- Scalar IN subquery in compound predicates: x IN (SELECT y ...).
  -- The dedicated SELECT fast path remains available, but mutation/join callers
  -- can use this positional expansion too.
  do forever
    upper = work~translate
    inPos = upper~pos(" IN (")
    if inPos = 0 then leave
    prefix = work~left(inPos - 1)~strip
    -- Row-value IN was handled above; leave non-scalar shapes alone.
    if prefix~right(1) = ")" then leave
    andPos = prefix~translate~lastPos(" AND ")
    orPos = prefix~translate~lastPos(" OR ")
    cut = andPos
    if orPos > cut then cut = orPos
    if cut > 0 then lhs = prefix~substr(cut + 5)~strip
    else lhs = prefix
    if lhs = "" then leave
    openPos = work~pos("(", inPos)
    closePos = self~matchingParen(work, openPos)
    if closePos = 0 then do
      out["error"] = self~sqlParseFailure("IN subquery has unmatched '('")
      return out
    end
    subText = work~substr(openPos + 1, closePos - openPos - 1)~strip
    if \subText~translate~startsWith("SELECT ") then leave
    subRs = self~executeSelect(subText)
    if subRs~status \= .Error~SUCCESS then do
      out["error"] = subRs
      return out
    end
    replacement = ""
    do row over subRs~rows
      keys = row~values~allIndexes
      if keys~items \= 1 then do
        out["error"] = self~sqlUnsupported("IN subquery must project one column")
        return out
      end
      value = row[keys[1]]
      if value == .nil then iterate
      piece = lhs || " = " || self~sqlLiteralForDynamicValue(value)
      if replacement = "" then replacement = piece
      else replacement ||= " OR " || piece
    end
    if replacement = "" then replacement = "1 = 0"
    if cut > 0 then before = prefix~left(cut + 4)
    else before = ""
    work = before || "(" || replacement || ")" || work~substr(closePos + 1)
  end

  -- Quantified comparisons: lhs OP ALL/ANY/SOME (SELECT one_col ...)
  do forever
    upper = work~translate
    quant = ""
    qPos = upper~pos(" ALL (")
    if qPos > 0 then quant = "ALL"
    anyPos = upper~pos(" ANY (")
    if anyPos > 0 then do
      if qPos = 0 | anyPos < qPos then do; qPos = anyPos; quant = "ANY"; end
    end
    somePos = upper~pos(" SOME (")
    if somePos > 0 then do
      if qPos = 0 | somePos < qPos then do; qPos = somePos; quant = "SOME"; end
    end
    if qPos = 0 then leave

    prefix = work~left(qPos - 1)~strip
    operator = ""
    lhs = ""
    do op over ">= <= <> != = > <"~makeArray(" ")
      if prefix~right(op~length) = op then do
        operator = op
        lhs = prefix~left(prefix~length - op~length)~strip
        leave
      end
    end
    if operator = "" | lhs = "" then do
      out["error"] = self~sqlParseFailure("Quantified comparison requires left expression and comparison operator")
      return out
    end
    -- Current quantified surface deliberately accepts a single predicate term on the left.
    -- Compound predicates after the quantified expression remain intact.
    if lhs~translate~pos(" AND ") > 0 | lhs~translate~pos(" OR ") > 0 then do
      out["error"] = self~sqlUnsupported("Quantified comparison inside a compound left expression is not implemented")
      return out
    end
    openPos = work~pos("(", qPos)
    closePos = self~matchingParen(work, openPos)
    if closePos = 0 then do
      out["error"] = self~sqlParseFailure("Quantified subquery has unmatched '('")
      return out
    end
    subText = work~substr(openPos + 1, closePos - openPos - 1)~strip
    if \subText~translate~startsWith("SELECT ") then do
      out["error"] = self~sqlUnsupported("Quantified comparison requires SELECT subquery")
      return out
    end
    subRs = self~executeSelect(subText)
    if subRs~status \= .Error~SUCCESS then do
      out["error"] = subRs
      return out
    end
    names = self~selectOutputNames(subText)
    if names == .nil | names~items \= 1 then do
      out["error"] = self~sqlParseFailure("Quantified subquery must project one column")
      return out
    end
    replacement = ""
    glue = " OR "
    if quant = "ALL" then glue = " AND "
    do row over subRs~rows
      literal = self~sqlLiteralForDynamicValue(row[names[1]])
      piece = lhs || " " || operator || " " || literal
      if replacement = "" then replacement = piece
      else replacement ||= glue || piece
    end
    if replacement = "" then do
      if quant = "ALL" then replacement = "1 = 1"
      else replacement = "1 = 0"
    end
    work = "(" || replacement || ")" || work~substr(closePos + 1)
  end

  out["text"] = work
  return out

::method executeExistsSubquerySelect private
  use arg projection, tableRefText, predicateText, orderBy, distinct
  trimmed = predicateText~strip
  upper = trimmed~translate
  negate = .false
  if upper~startsWith("NOT EXISTS (") then do
    negate = .true
    openPos = trimmed~pos("(")
  end
  else if upper~startsWith("EXISTS (") then openPos = trimmed~pos("(")
  else return .nil
  closePos = self~matchingParen(trimmed, openPos)
  if closePos = 0 then return self~sqlParseFailure("EXISTS subquery has unmatched '('")
  if trimmed~substr(closePos + 1)~strip \= "" then return self~sqlUnsupported("Compound EXISTS predicates are not implemented")
  subText = trimmed~substr(openPos + 1, closePos - openPos - 1)~strip
  if \subText~translate~startsWith("SELECT ") then return self~sqlParseFailure("EXISTS requires SELECT subquery")
  ref = self~parseTableRef(tableRefText)
  if ref == .nil then return self~sqlFailure("Invalid table reference")
  t = self~engine~table(ref["table"])
  if t == .nil then return self~sqlFailure("Table not found: " || ref["table"])
  relation = .SQLRelationDefinition~new(t~definition, ref["alias"])
  base = self~engine~selectAll(ref["table"])
  if base~status \= .Error~SUCCESS then return base
  filtered = .array~new
  do outerRow over base~rows
    boundText = self~bindOuterReferences(subText, outerRow, relation)
    subRs = self~executeSelect(boundText)
    if subRs~status \= .Error~SUCCESS then return subRs
    exists = (subRs~rows~items > 0)
    keep = exists
    if negate then keep = \exists
    if keep then filtered~append(outerRow)
  end
  base~rows = filtered
  base~affectedRows = filtered~items
  if negate then base~accessPath = "NOT_EXISTS_CORRELATED"
  else base~accessPath = "EXISTS_CORRELATED"
  preOrder = self~resolvedOrderBy(orderBy, relation)
  if preOrder \== .nil then do
    base = self~applyOrderBy(base, preOrder)
    if base~status \= .Error~SUCCESS then return base
    orderBy = ""
  end
  base = self~applyProjection(base, projection, relation)
  if base~status \= .Error~SUCCESS then return base
  if distinct then base = self~applyDistinct(base)
  return self~applyOrderBy(base, orderBy)

::method executeInSubquerySelect private
  use arg projection, tableRefText, predicateText, orderBy, distinct
  u = predicateText~translate
  inPos = u~pos(" IN (")
  if inPos = 0 then return .nil
  outerColumn = predicateText~left(inPos - 1)~strip
  if outerColumn = "" then return self~sqlParseFailure("IN requires left column")
  openPos = predicateText~pos("(", inPos)
  closePos = self~matchingParen(predicateText, openPos)
  if closePos = 0 then return self~sqlParseFailure("IN subquery has unmatched '('")
  if predicateText~substr(closePos + 1)~strip \= "" then return self~sqlUnsupported("Compound IN predicates are not implemented")
  subText = predicateText~substr(openPos + 1, closePos - openPos - 1)~strip
  if \subText~translate~startsWith("SELECT ") then return self~sqlUnsupported("IN lists are not implemented")
  subRs = self~executeSelect(subText)
  if subRs~status \= .Error~SUCCESS then return subRs
  allowed = .table~new
  do r over subRs~rows
    keys = r~values~allIndexes
    if keys~items \= 1 then return self~sqlUnsupported("IN subquery must project one column")
    v = r[keys[1]]
    if v \== .nil then allowed[v~string] = .true
  end
  ref = self~parseTableRef(tableRefText)
  if ref == .nil then return self~sqlFailure("Invalid table reference")
  t = self~engine~table(ref["table"])
  if t == .nil then return self~engine~selectAll(ref["table"])
  relation = .SQLRelationDefinition~new(t~definition, ref["alias"])
  resolved = relation~resolve(outerColumn)
  if resolved == .nil then return self~sqlFailure("Unknown or ambiguous WHERE column")
  base = self~engine~selectAll(ref["table"])
  if base~status \= .Error~SUCCESS then return base
  filtered = .array~new
  do r over base~rows
    v = r[resolved["sourceColumn"]]
    if v == .nil then iterate
    if allowed[v~string] \== .nil then filtered~append(r)
  end
  base~rows = filtered
  base~affectedRows = filtered~items
  base~accessPath = "IN_SUBQUERY_SCAN"
  base = self~applyProjection(base, projection, relation)
  if base~status \= .Error~SUCCESS then return base
  if distinct then base = self~applyDistinct(base)
  return self~applyOrderBy(base, orderBy)

::method splitTopLevelUnion private
  use arg text
  out = .array~new
  start = 1
  depth = 0
  quote = ""
  i = 1
  upper = text~translate
  do while i <= text~length
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then do
        if i < text~length then do
          if text~substr(i+1,1) = quote then do; i += 2; iterate; end
        end
        quote = ""
      end
      i += 1
      iterate
    end
    if ch = "'" | ch = '"' then do; quote = ch; i += 1; iterate; end
    if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if depth = 0 then do
      if upper~substr(i,7) = " UNION " then do
        out~append(text~substr(start, i-start)~strip)
        start = i + 7
        i = start
        iterate
      end
    end
    i += 1
  end
  out~append(text~substr(start)~strip)
  return out

::method findTopLevelKeyword private
  use arg text, keyword
  depth=0; quote=""; i=1; upper=text~translate; key=keyword~translate
  do while i <= text~length-key~length+1
    ch=text~substr(i,1)
    if quote \= "" then do
      if ch=quote then quote=""
      i+=1; iterate
    end
    if ch="'" | ch='"' then do; quote=ch; i+=1; iterate; end
    if ch="(" then depth+=1
    else if ch=")" then depth-=1
    if depth=0 then if upper~substr(i,key~length)=key then return i
    i+=1
  end
  return 0

::method executeCreateTable private
  use arg text
  rest = text~substr(14)~strip
  openPos = rest~pos("(")
  if openPos = 0 then return self~sqlFailure("CREATE TABLE requires column definitions")
  tableName = rest~left(openPos - 1)~strip
  if tableName = "" then return self~sqlFailure("CREATE TABLE requires table name")
  closePos = self~matchingParen(rest, openPos)
  if closePos = 0 then return self~sqlFailure("CREATE TABLE has unmatched '('")
  body = rest~substr(openPos + 1, closePos - openPos - 1)
  tail = rest~substr(closePos + 1)~strip

  columns = .array~new
  primaryKey = .array~new
  uniques = .array~new
  foreignKeys = .array~new
  do part over self~splitList(body)
    item = part~strip
    upper = item~translate
    if upper~startsWith("PRIMARY KEY") then do
      p = item~pos("(")
      if p = 0 then return self~sqlFailure("PRIMARY KEY requires column list")
      q = self~matchingParen(item, p)
      if q = 0 then return self~sqlFailure("PRIMARY KEY has unmatched '('")
      primaryKey = self~trimmedList(item~substr(p + 1, q - p - 1))
    end
    else if upper~startsWith("UNIQUE") then do
      p = item~pos("(")
      if p = 0 then return self~sqlFailure("UNIQUE requires column list")
      q = self~matchingParen(item, p)
      if q = 0 then return self~sqlFailure("UNIQUE has unmatched '('")
      uniques~append(self~trimmedList(item~substr(p + 1, q - p - 1)))
    end
    else do
      words = item~space~makeArray(" ")
      if words~items < 2 then return self~sqlFailure("Column requires name and type")
      name = words[1]
      type = words[2]~translate
      typeParen = type~pos("(")
      if typeParen > 0 then type = type~left(typeParen - 1)
      nullable = .true
      unique = .false
      pk = .false
      modifierText = " " || item~translate || " "
      if modifierText~pos(" NOT NULL ") > 0 then nullable = .false
      if modifierText~pos(" UNIQUE ") > 0 then unique = .true
      if modifierText~pos(" PRIMARY KEY ") > 0 then do
        pk = .true
        nullable = .false
        primaryKey~append(name)
      end

      refPos = modifierText~pos(" REFERENCES ")
      if refPos > 0 then do
        originalRefPos = item~translate~pos(" REFERENCES ")
        refTail = item~substr(originalRefPos + 12)~strip
        parentOpen = refTail~pos("(")
        if parentOpen = 0 then return self~sqlFailure("REFERENCES requires parent table(column)")
        parentClose = self~matchingParen(refTail, parentOpen)
        if parentClose = 0 then return self~sqlFailure("REFERENCES has unmatched '('")
        parentTable = refTail~left(parentOpen - 1)~strip
        parentColumn = refTail~substr(parentOpen + 1, parentClose - parentOpen - 1)~strip
        if parentTable = "" | parentColumn = "" then return self~sqlFailure("REFERENCES requires parent table(column)")
        actionTail = refTail~substr(parentClose + 1)~strip~translate
        onDelete = "RESTRICT"
        onUpdate = "RESTRICT"
        if actionTail \= "" then do
          if actionTail~pos("ON DELETE CASCADE") > 0 then onDelete = "CASCADE"
          else if actionTail~pos("ON DELETE SET NULL") > 0 then onDelete = "SET NULL"
          else if actionTail~pos("ON DELETE SET DEFAULT") > 0 then return self~sqlUnsupported("FOREIGN KEY SET DEFAULT is not implemented")
          else if actionTail~pos("ON DELETE NO ACTION") > 0 then onDelete = "NO ACTION"
          else if actionTail~pos("ON DELETE RESTRICT") > 0 then onDelete = "RESTRICT"

          if actionTail~pos("ON UPDATE CASCADE") > 0 then onUpdate = "CASCADE"
          else if actionTail~pos("ON UPDATE SET NULL") > 0 then onUpdate = "SET NULL"
          else if actionTail~pos("ON UPDATE SET DEFAULT") > 0 then return self~sqlUnsupported("FOREIGN KEY SET DEFAULT is not implemented")
          else if actionTail~pos("ON UPDATE NO ACTION") > 0 then onUpdate = "NO ACTION"
          else if actionTail~pos("ON UPDATE RESTRICT") > 0 then onUpdate = "RESTRICT"
        end
        foreignKeys~append(.DatabaseForeignKeyDefinition~new(name, parentTable, parentColumn, onDelete, onUpdate))
      end

      columns~append(.DatabaseColumn~new(name, type, nullable, unique, pk))
    end
  end

  separator = ","
  nullToken = "\\N"
  if tail \= "" then do
    tailUpper = tail~translate
    if \tailUpper~startsWith("WITH") then return self~sqlFailure("Unexpected CREATE TABLE tail")
    options = tail~substr(5)~strip
    if options~left(1) \= "(" then return self~sqlFailure("WITH requires parenthesized options")
    q = self~matchingParen(options, 1)
    if q = 0 then return self~sqlFailure("WITH has unmatched '('")
    do option over self~splitList(options~substr(2, q - 2))
      pair = self~parseEquals(option)
      if pair == .nil then return self~sqlFailure("Invalid CREATE TABLE WITH option")
      key = pair[1]~translate
      if key = "SEPARATOR" then separator = pair[2]
      else if key = "NULLTOKEN" then nullToken = pair[2]
      else return self~sqlFailure("Unknown CREATE TABLE WITH option:" pair[1])
    end
  end

  return self~engine~createTable(tableName, columns, primaryKey, uniques, separator, nullToken, foreignKeys, "FD", 65536)

::method executeDropTable private
  use arg text
  tableName = text~substr(12)~strip
  if tableName = "" then return self~sqlFailure("DROP TABLE requires table name")
  return self~engine~dropTable(tableName)

::method executeSelect private
  use arg text, sortBound = .nil
  upper = text~translate
  unsupported = self~unsupportedSelectReason(text)
  if unsupported \= "" then return self~sqlUnsupported(unsupported)
  fromPos = self~findTopLevelKeyword(text, " FROM ")
  if fromPos = 0 then return self~sqlFailure("SELECT requires FROM")
  projection = text~substr(8, fromPos - 8)~strip
  if projection = "" then return self~sqlFailure("SELECT requires projection")
  distinct = .false
  projectionUpper = projection~translate
  if projectionUpper~startsWith("DISTINCT ") then do
    distinct = .true
    projection = projection~substr(10)~strip
    if projection = "" then return self~sqlFailure("DISTINCT requires projection")
  end
  rest = text~substr(fromPos + 6)~strip
  rest = self~normalizeInnerJoinSyntax(rest)
  rest = self~normalizeOuterJoinSyntax(rest)
  restUpper = rest~translate
  if restUpper~endsWith(" WHERE") then return self~sqlParseFailure("WHERE requires a predicate")

  if distinct then do
    semanticOrderPos = self~findTopLevelKeyword(rest, " ORDER BY ")
    semanticGroupPos = self~findTopLevelKeyword(rest, " GROUP BY ")
    if semanticOrderPos > 0 & semanticGroupPos = 0 then do
      semanticOrder = rest~substr(semanticOrderPos + 10)~strip
      if self~projectionHasTopLevelAggregate(semanticOrder) & \self~projectionHasTopLevelAggregate(projection) then ,
        return self~sqlParseFailure("DISTINCT ORDER BY aggregate requires an explicit GROUP BY or projected aggregate")
    end
  end

  if self~projectionHasWindow(projection) then return self~executeWindowSelect(projection, rest, distinct)

  aggregateResult = self~executeAggregateSelect(projection, rest, distinct)
  if aggregateResult \== .nil then return aggregateResult

  orderBy = ""
  orderPos = self~findTopLevelKeyword(rest, " ORDER BY ")
  if orderPos > 0 then do
    orderBy = rest~substr(orderPos + 10)~strip
    if orderBy~translate~pos("CASE ") > 0 then orderBy = self~expandOrderByProjectionAliases(orderBy, projection)
    rest = rest~left(orderPos - 1)~strip
    restUpper = rest~translate
  end

  if rest~strip~left(1) = "(" then do
    derivedResult = self~executeDerivedSelect(projection, rest, orderBy, distinct)
    if derivedResult \== .nil then return derivedResult
  end

  fullJoinPos = restUpper~pos(" FULL JOIN ")
  if fullJoinPos > 0 then do
    queryResult = self~executeFullJoinSelect(projection, rest, orderBy, distinct)
    return queryResult
  end

  rightJoinPos = restUpper~pos(" RIGHT JOIN ")
  if rightJoinPos > 0 then do
    queryResult = self~executeRightJoinSelect(projection, rest, orderBy, distinct)
    return queryResult
  end

  leftJoinPos = restUpper~pos(" LEFT JOIN ")
  if leftJoinPos > 0 then do
    queryResult = self~executeLeftJoinSelect(projection, rest, orderBy, distinct)
    return queryResult
  end

  naturalJoinPos = restUpper~pos(" NATURAL JOIN ")
  if naturalJoinPos > 0 then return self~executeNaturalJoinSelect(projection, rest, orderBy, distinct)

  joinPos = restUpper~pos(" JOIN ")
  if joinPos > 0 then do
    nextJoinPos = restUpper~pos(" JOIN ", joinPos + 1)
    if nextJoinPos > 0 then return self~executeInnerJoinChainSelect(projection, rest, orderBy, distinct)
    queryResult = self~executeJoinSelect(projection, rest, joinPos, orderBy)
    if queryResult~status \= .Error~SUCCESS then return queryResult
    if distinct then queryResult = self~applyDistinct(queryResult)
    return queryResult
  end

  fromHead = rest
  whereHeadPos = restUpper~pos(" WHERE ")
  if whereHeadPos > 0 then fromHead = rest~left(whereHeadPos - 1)~strip
  if fromHead~pos(",") > 0 then return self~executeCrossJoinSelect(projection, rest, orderBy, distinct)

  wherePos = restUpper~pos(" WHERE ")
  if wherePos = 0 then do
    tableRefText = rest
    predicate = .nil
  end
  else do
    tableRefText = rest~left(wherePos - 1)~strip
    predicateText = rest~substr(wherePos + 7)~strip
    if predicateText = "" then return self~sqlParseFailure("WHERE requires a predicate")
    existsResult = self~executeExistsSubquerySelect(projection, tableRefText, predicateText, orderBy, distinct)
    if existsResult \== .nil then return existsResult
    expandedSet = self~expandSetSubqueryPredicates(predicateText)
    if expandedSet["error"] \== .nil then return expandedSet["error"]
    predicateText = expandedSet["text"]
    inResult = self~executeInSubquerySelect(projection, tableRefText, predicateText, orderBy, distinct)
    if inResult \== .nil then return inResult
    predicate = .SQLPredicateParser~new~parse(predicateText)
  end
  ref = self~parseTableRef(tableRefText)
  if ref == .nil then return self~sqlFailure("Invalid table reference")
  tableName = ref["table"]
  alias = ref["alias"]
  t = self~engine~table(tableName)
  if t == .nil then do
    if predicate == .nil then return self~engine~selectAll(tableName)
    return self~engine~selectWhere(tableName, predicate)
  end
  relation = .SQLRelationDefinition~new(t~definition, alias)
  if predicate \== .nil then do
    if \self~normalizeSinglePredicate(predicate, relation) then return self~sqlFailure("Unknown or ambiguous WHERE column")
    queryResult = self~engine~selectWhere(tableName, predicate)
    if queryResult~status = .Error~SUCCESS then self~engine~queryPatternLog~record(tableName, predicate, queryResult~rowsScanned, queryResult~rows~items)
  end
  else queryResult = self~engine~selectAll(tableName)
  if queryResult~status \= .Error~SUCCESS then return queryResult
  preOrder = self~resolvedOrderBy(orderBy, relation)
  if preOrder \== .nil then do
    queryResult = self~applyOrderBy(queryResult, preOrder, sortBound)
    if queryResult~status \= .Error~SUCCESS then return queryResult
    orderBy = ""
  end
  else if orderBy \= "" then do
    orderUpper = orderBy~translate
    if orderUpper~pos("CASE ") > 0 | orderBy~pos("||") > 0 | orderBy~pos("(") > 0 then do
      queryResult = self~applyExpressionOrderBy(queryResult, orderBy, relation)
      if queryResult~status \= .Error~SUCCESS then return queryResult
      orderBy = ""
    end
  end
  queryResult = self~applyProjection(queryResult, projection, relation)
  if queryResult~status \= .Error~SUCCESS then return queryResult
  if distinct then queryResult = self~applyDistinct(queryResult)
  return self~applyOrderBy(queryResult, orderBy, sortBound)

::method projectionHasWindow private
  use arg projection
  upper = projection~translate
  return upper~pos(" OVER ") > 0

::method executeWindowSelect private
  use arg projection, rest, distinct = .false
  if distinct then return self~sqlUnsupported("DISTINCT with window projection is not implemented")

  orderBy = ""
  orderPos = self~findTopLevelKeyword(rest, " ORDER BY ")
  if orderPos > 0 then do
    orderBy = rest~substr(orderPos + 10)~strip
    rest = rest~left(orderPos - 1)~strip
  end

  -- DISTINCT does not create an implicit grouping context.  In particular,
  -- SELECT DISTINCT x ORDER BY AVG(y) must not be "repaired" into GROUP BY x.
  if distinct & groupPos = 0 then do
    if self~projectionHasTopLevelAggregate(orderBy) & \self~projectionHasTopLevelAggregate(projection) then ,
      return self~sqlParseFailure("DISTINCT ORDER BY aggregate requires an explicit GROUP BY or projected aggregate")
  end

  namedWindowName = ""
  namedWindowBody = ""
  windowClausePos = self~findTopLevelKeyword(rest, " WINDOW ")
  if windowClausePos > 0 then do
    windowClause = rest~substr(windowClausePos + 8)~strip
    rest = rest~left(windowClausePos - 1)~strip
    asPos = self~findTopLevelKeyword(" " || windowClause, " AS ")
    if asPos = 0 then return self~sqlParseFailure("Invalid WINDOW clause")
    asPos -= 1
    namedWindowName = windowClause~left(asPos - 1)~strip
    namedWindowBody = windowClause~substr(asPos + 4)~strip
    if namedWindowName = "" | namedWindowName~space~words \= 1 then return self~sqlParseFailure("Invalid WINDOW name")
    if namedWindowBody~left(1) \= "(" then return self~sqlParseFailure("WINDOW definition requires parentheses")
    if self~matchingParen(namedWindowBody, 1) \= namedWindowBody~length then return self~sqlParseFailure("Invalid WINDOW definition")
  end

  whereText = ""
  wherePos = self~findTopLevelKeyword(rest, " WHERE ")
  if wherePos > 0 then do
    whereText = rest~substr(wherePos + 7)~strip
    rest = rest~left(wherePos - 1)~strip
  end

  sourceRows = .nil
  sourceScanned = 0
  if rest~strip~left(1) = "(" then do
    source = self~buildDerivedAggregateSource(rest)
    if source == .nil then return self~sqlUnsupported("Window FROM source is not implemented")
    relation = source["relation"]
    sourceRows = source["rows"]
    sourceScanned = source["rowsScanned"]
  end
  else do
    ref = self~parseTableRef(rest)
    if ref == .nil then return self~sqlUnsupported("Window FROM source is not implemented")
    tableObj = self~engine~table(ref["table"])
    if tableObj == .nil then return self~sqlFailure("Table not found: " || ref["table"])
    relation = .SQLRelationDefinition~new(tableObj~definition, ref["alias"])
    sourceRows = tableObj~readRows
    sourceScanned = sourceRows~items
  end

  specs = .array~new
  windowDefinition = .nil
  do specText over self~splitList(projection)
    spec = self~parseProjectionSpec(specText)
    if spec == .nil then return self~sqlParseFailure("Invalid window projection: " || specText)
    expression = spec["expression"]
    if expression~translate~pos(" OVER ") > 0 then do
      windowExpression = expression
      if namedWindowName \= "" then do
        overPos = self~findTopLevelKeyword(expression, " OVER ")
        if overPos > 0 then do
          overTarget = expression~substr(overPos + 6)~strip
          if overTarget~caselessEquals(namedWindowName) then windowExpression = expression~left(overPos - 1)~strip || " OVER " || namedWindowBody
        end
      end
      win = self~parseWindowExpression(windowExpression, relation)
      if win == .nil then return self~sqlUnsupported("Window expression is outside the supported window surface: " || expression)
      if win["orderPhysical"] \= "" then do
        if windowDefinition == .nil then windowDefinition = win
        else do
          if win["partitionPhysical"] \= windowDefinition["partitionPhysical"] then return self~sqlUnsupported("Multiple differing ordered window definitions are not implemented")
          if \win["orderPhysical"]~caselessEquals(windowDefinition["orderPhysical"]) then return self~sqlUnsupported("Multiple differing ordered window definitions are not implemented")
          if win["orderDirection"] \= windowDefinition["orderDirection"] then return self~sqlUnsupported("Multiple differing ordered window definitions are not implemented")
        end
      end
      spec["window"] = win
    end
    specs~append(spec)
  end
  rows = sourceRows
  if whereText \= "" then do
    predicate = .SQLPredicateParser~new~parse(whereText)
    if predicate == .nil then return self~sqlParseFailure("Invalid window WHERE predicate")
    filtered = .array~new
    do row over rows
      if predicate~evaluate(row, relation) then filtered~append(row)
    end
    rows = filtered
  end

  -- Ordered windows use one compatible physical ordering. Partition-wide
  -- aggregates do not impose an ordering and are evaluated over the complete
  -- partition independently.
  if windowDefinition \== .nil then do
    i = 2
    do while i <= rows~items
      current = rows[i]
      j = i - 1
      do while j >= 1
        if self~compareWindowRows(rows[j], current, windowDefinition) <= 0 then leave
        rows[j + 1] = rows[j]
        j -= 1
      end
      rows[j + 1] = current
      i += 1
    end
  end

  outRows = .array~new

  -- The rows are now in the common ordered-window sequence.  Precompute each
  -- row's partition bounds so offset/navigation and NTILE functions can look
  -- sideways without disturbing the running aggregate state.
  partitionStarts = .array~new
  partitionEnds = .array~new
  if windowDefinition \== .nil & rows~items > 0 then do
    startAt = 1
    do i = 1 to rows~items
      atEnd = i = rows~items
      if \atEnd then do
        samePartition = .true
        if windowDefinition["partitionPhysical"] \= "" then do
          lv = rows[i][windowDefinition["partitionPhysical"]]
          rv = rows[i + 1][windowDefinition["partitionPhysical"]]
          samePartition = self~compareScalarValues(lv, rv) = 0
        end
        if samePartition then iterate
      end
      do j = startAt to i
        partitionStarts[j] = startAt
        partitionEnds[j] = i
      end
      startAt = i + 1
    end
  end

  currentPartition = .nil
  runningStates = .table~new
  rowNumber = 0
  currentRank = 0
  denseRank = 0
  previousOrder = .nil
  havePreviousOrder = .false

  rowIndex = 0
  do sourceRow over rows
    rowIndex += 1
    partitionKey = "<ALL>"
    if windowDefinition \== .nil then do
      if windowDefinition["partitionPhysical"] \= "" then do
        partitionValue = sourceRow[windowDefinition["partitionPhysical"]]
        partitionKey = "<NULL>"
        if partitionValue \== .nil then partitionKey = partitionValue~string
      end
    end
    if currentPartition == .nil | currentPartition \= partitionKey then do
      currentPartition = partitionKey
      runningStates = .table~new
      rowNumber = 0
      currentRank = 0
      denseRank = 0
      previousOrder = .nil
      havePreviousOrder = .false
    end

    rowNumber += 1
    if windowDefinition \== .nil then do
      orderValue = sourceRow[windowDefinition["orderPhysical"]]
      if \havePreviousOrder then do
        currentRank = 1
        denseRank = 1
        previousOrder = orderValue
        havePreviousOrder = .true
      end
      else if self~compareScalarValues(orderValue, previousOrder) \= 0 then do
        currentRank = rowNumber
        denseRank += 1
        previousOrder = orderValue
      end
    end

    values = .table~new
    do spec over specs
      outputName = spec["alias"]
      if spec["window"] \== .nil then do
        win = spec["window"]
        functionName = win["function"]
        if outputName = "" then outputName = spec["expression"]

        if win["orderPhysical"] = "" then values[outputName] = self~partitionWindowAggregate(rows, sourceRow, win)
        else select
          when functionName = "ROW_NUMBER" then values[outputName] = rowNumber
          when functionName = "RANK" then values[outputName] = currentRank
          when functionName = "DENSE_RANK" then values[outputName] = denseRank
          when functionName = "LAG" then do
            targetIndex = rowIndex - win["offset"]
            if targetIndex < partitionStarts[rowIndex] then values[outputName] = win["defaultValue"]
            else values[outputName] = rows[targetIndex][win["valuePhysical"]]
          end
          when functionName = "LEAD" then do
            targetIndex = rowIndex + win["offset"]
            if targetIndex > partitionEnds[rowIndex] then values[outputName] = win["defaultValue"]
            else values[outputName] = rows[targetIndex][win["valuePhysical"]]
          end
          when functionName = "NTILE" then do
            partitionSize = partitionEnds[rowIndex] - partitionStarts[rowIndex] + 1
            position = rowIndex - partitionStarts[rowIndex] + 1
            bucketCount = win["ntileBuckets"]
            baseSize = partitionSize % bucketCount
            largerBuckets = partitionSize // bucketCount
            largeSpan = (baseSize + 1) * largerBuckets
            if position <= largeSpan then values[outputName] = trunc((position - 1) / (baseSize + 1)) + 1
            else do
              if baseSize = 0 then values[outputName] = largerBuckets
              else values[outputName] = largerBuckets + trunc((position - largeSpan - 1) / baseSize) + 1
            end
          end
          otherwise do
            stateKey = spec["expression"]~translate
            state = runningStates[stateKey]
            if state == .nil then do
              state = .table~new
              state["sum"] = 0
              state["count"] = 0
              state["min"] = .nil
              state["max"] = .nil
            end

            sourceValue = .nil
            if win["valuePhysical"] \= "*" then sourceValue = sourceRow[win["valuePhysical"]]

            if functionName = "COUNT" then do
              if win["valuePhysical"] = "*" | sourceValue \== .nil then state["count"] = state["count"] + 1
              values[outputName] = state["count"]
            end
            else do
              if sourceValue \== .nil then do
                if (functionName = "SUM" | functionName = "AVG") & \datatype(sourceValue~string, "N") then return self~sqlFailure("Window " || functionName || " requires numeric values")
                if functionName = "SUM" | functionName = "AVG" then state["sum"] = state["sum"] + sourceValue
                state["count"] = state["count"] + 1
                if state["min"] == .nil | self~compareScalarValues(sourceValue, state["min"]) < 0 then state["min"] = sourceValue
                if state["max"] == .nil | self~compareScalarValues(sourceValue, state["max"]) > 0 then state["max"] = sourceValue
              end
              select
                when functionName = "SUM" then do
                  if state["count"] = 0 then values[outputName] = .nil
                  else values[outputName] = state["sum"]
                end
                when functionName = "AVG" then do
                  if state["count"] = 0 then values[outputName] = .nil
                  else values[outputName] = state["sum"] / state["count"]
                end
                when functionName = "MIN" then values[outputName] = state["min"]
                when functionName = "MAX" then values[outputName] = state["max"]
                otherwise return self~sqlUnsupported("Window function is not implemented: " || functionName)
              end
            end
            runningStates[stateKey] = state
          end
        end
      end
      else do
        evaluated = self~evaluateProjectionExpression(spec["expression"], sourceRow, relation)
        if \evaluated["ok"] then return self~sqlUnsupported("Window SELECT projection expression is not implemented: " || spec["expression"])
        if outputName = "" then do
          resolved = relation~resolve(spec["expression"])
          if resolved == .nil then outputName = spec["expression"]
          else if spec["expression"]~pos(".") > 0 then outputName = spec["expression"]
          else outputName = resolved["sourceColumn"]
        end
        values[outputName] = evaluated["value"]
      end
    end
    outRows~append(.DatabaseRow~new(values))
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = outRows
  rs~affectedRows = outRows~items
  rs~rowsScanned = sourceScanned
  rs~accessPath = "WINDOW_RUNNING_SCAN"
  return self~applyOrderBy(rs, orderBy)

::method parseWindowExpression private
  use arg expression, relation
  text = expression~strip
  overPos = self~findTopLevelKeyword(text, " OVER ")
  if overPos = 0 then return .nil
  functionText = text~left(overPos - 1)~strip
  windowText = text~substr(overPos + 6)~strip
  functionUpper = functionText~translate

  functionName = ""
  valueRef = ""
  valuePhysical = ""
  offset = 1
  defaultValue = .nil
  ntileBuckets = 0
  if functionUpper = "ROW_NUMBER()" then functionName = "ROW_NUMBER"
  else if functionUpper = "RANK()" then functionName = "RANK"
  else if functionUpper = "DENSE_RANK()" then functionName = "DENSE_RANK"
  else do
    open = functionText~pos("(")
    if open = 0 then return .nil
    if self~matchingParen(functionText, open) \= functionText~length then return .nil
    functionName = functionText~left(open - 1)~strip~translate
    args = self~splitList(functionText~substr(open + 1, functionText~length - open - 1)~strip)

    if functionName = "LAG" | functionName = "LEAD" then do
      if args~items < 1 | args~items > 3 then return .nil
      valueRef = args[1]~strip
      valueResolved = relation~resolve(valueRef)
      if valueResolved == .nil then return .nil
      valuePhysical = valueResolved["physicalName"]
      if args~items >= 2 then do
        offsetText = args[2]~strip
        if \datatype(offsetText, "W") then return .nil
        offset = offsetText
        if offset < 0 then return .nil
      end
      if args~items = 3 then do
        defaultText = args[3]~strip
        if defaultText~translate = "NULL" then defaultValue = .nil
        else if datatype(defaultText, "N") then defaultValue = defaultText
        else if defaultText~length >= 2 & defaultText~left(1) = "'" & defaultText~right(1) = "'" then defaultValue = self~unquote(defaultText)
        else return .nil
      end
    end
    else if functionName = "NTILE" then do
      if args~items \= 1 then return .nil
      bucketText = args[1]~strip
      if \datatype(bucketText, "W") then return .nil
      ntileBuckets = bucketText
      if ntileBuckets <= 0 then return .nil
    end
    else do
      if functionName \= "SUM" & functionName \= "COUNT" & functionName \= "AVG" & functionName \= "MIN" & functionName \= "MAX" then return .nil
      if args~items \= 1 then return .nil
      valueRef = args[1]~strip
      if functionName = "COUNT" & valueRef = "*" then valuePhysical = "*"
      else do
        valueResolved = relation~resolve(valueRef)
        if valueResolved == .nil then return .nil
        valuePhysical = valueResolved["physicalName"]
      end
    end
  end

  if windowText~left(1) \= "(" then return .nil
  close = self~matchingParen(windowText, 1)
  if close \= windowText~length then return .nil
  body = windowText~substr(2, windowText~length - 2)~strip

  partitionPhysical = ""
  orderPhysical = ""
  orderDirection = "ASC"
  frameText = ""

  -- Empty OVER() and PARTITION BY-only windows are complete-partition
  -- aggregates. Ranking functions still require ORDER BY.
  if body = "" then do
    if functionName = "ROW_NUMBER" | functionName = "RANK" | functionName = "DENSE_RANK" then return .nil
  end
  else do
    if body~translate~startsWith("ORDER BY ") then do
      beforeOrder = ""
      afterOrder = body~substr(10)~strip
    end
    else do
      orderPos = self~findTopLevelKeyword(" " || body, " ORDER BY ")
      if orderPos > 0 then do
        orderPos -= 1
        beforeOrder = body~left(orderPos - 1)~strip
        afterOrder = body~substr(orderPos + 10)~strip
      end
      else do
        beforeOrder = body
        afterOrder = ""
      end
    end

    if beforeOrder \= "" then do
      if \beforeOrder~translate~startsWith("PARTITION BY ") then return .nil
      partitionRef = beforeOrder~substr(14)~strip
      if partitionRef~space~words \= 1 then return .nil
      partitionResolved = relation~resolve(partitionRef)
      if partitionResolved == .nil then return .nil
      partitionPhysical = partitionResolved["physicalName"]
    end

    if afterOrder \= "" then do
      rowsPos = afterOrder~translate~pos(" ROWS BETWEEN ")
      if rowsPos > 0 then do
        orderPart = afterOrder~left(rowsPos - 1)~strip
        frameText = afterOrder~substr(rowsPos + 14)~strip~translate
        if frameText \= "UNBOUNDED PRECEDING AND CURRENT ROW" then return .nil
      end
      else orderPart = afterOrder

      orderDirection = "ASC"
      words = orderPart~space
      if words~words = 2 then do
        maybeDir = words~word(2)~translate
        if maybeDir \= "ASC" & maybeDir \= "DESC" then return .nil
        orderDirection = maybeDir
        orderRef = words~word(1)
      end
      else if words~words = 1 then orderRef = words
      else return .nil
      orderResolved = relation~resolve(orderRef)
      if orderResolved == .nil then return .nil
      orderPhysical = orderResolved["physicalName"]
    end
  end

  if functionName = "ROW_NUMBER" | functionName = "RANK" | functionName = "DENSE_RANK" | functionName = "LAG" | functionName = "LEAD" | functionName = "NTILE" then do
    if orderPhysical = "" then return .nil
    if frameText \= "" then return .nil
  end
  else do
    -- If an aggregate window has ORDER BY, require the explicit running ROWS
    -- frame. Without ORDER BY it is a whole-partition aggregate.
    if orderPhysical \= "" & frameText = "" then return .nil
  end

  win = .table~new
  win["function"] = functionName
  win["valuePhysical"] = valuePhysical
  win["offset"] = offset
  win["defaultValue"] = defaultValue
  win["ntileBuckets"] = ntileBuckets
  win["partitionPhysical"] = partitionPhysical
  win["orderPhysical"] = orderPhysical
  win["orderDirection"] = orderDirection
  return win

::method partitionWindowAggregate private
  use arg rows, currentRow, win
  functionName = win["function"]
  partitionPhysical = win["partitionPhysical"]
  valuePhysical = win["valuePhysical"]
  sum = 0
  count = 0
  minValue = .nil
  maxValue = .nil

  currentPartition = .nil
  if partitionPhysical \= "" then currentPartition = currentRow[partitionPhysical]

  do row over rows
    if partitionPhysical \= "" then do
      candidatePartition = row[partitionPhysical]
      samePartition = .false
      if currentPartition == .nil & candidatePartition == .nil then samePartition = .true
      else if currentPartition \== .nil & candidatePartition \== .nil then ,
        samePartition = self~compareScalarValues(currentPartition, candidatePartition) = 0
      if \samePartition then iterate
    end

    if functionName = "COUNT" & valuePhysical = "*" then do
      count += 1
      iterate
    end

    value = row[valuePhysical]
    if value == .nil then iterate
    if (functionName = "SUM" | functionName = "AVG") & \datatype(value~string, "N") then return .nil
    count += 1
    if functionName = "SUM" | functionName = "AVG" then sum += value
    if minValue == .nil | self~compareScalarValues(value, minValue) < 0 then minValue = value
    if maxValue == .nil | self~compareScalarValues(value, maxValue) > 0 then maxValue = value
  end

  select
    when functionName = "COUNT" then return count
    when functionName = "SUM" then do
      if count = 0 then return .nil
      return sum
    end
    when functionName = "AVG" then do
      if count = 0 then return .nil
      return sum / count
    end
    when functionName = "MIN" then return minValue
    when functionName = "MAX" then return maxValue
    otherwise return .nil
  end

::method compareWindowRows private
  use arg leftRow, rightRow, win
  if win["partitionPhysical"] \= "" then do
    lp = leftRow[win["partitionPhysical"]]
    rp = rightRow[win["partitionPhysical"]]
    cmp = self~compareScalarValues(lp, rp)
    if cmp \= 0 then return cmp
  end
  cmp = self~compareScalarValues(leftRow[win["orderPhysical"]], rightRow[win["orderPhysical"]])
  if win["orderDirection"] = "DESC" then cmp = 0 - cmp
  return cmp

::method executeJoinSelect private
  use arg projection, rest, joinPos, orderBy = ""
  leftRefText = rest~left(joinPos - 1)~strip
  leftRef = self~parseTableRef(leftRefText)
  if leftRef == .nil then return self~sqlFailure("Invalid left table reference")
  afterJoin = rest~substr(joinPos + 6)~strip
  afterUpper = afterJoin~translate
  onPos = afterUpper~pos(" ON ")
  if onPos = 0 then return self~sqlFailure("JOIN requires ON")
  rightRefText = afterJoin~left(onPos - 1)~strip
  rightRef = self~parseTableRef(rightRefText)
  if rightRef == .nil then return self~sqlFailure("Invalid right table reference")
  -- v0.22: the two-table engine join qualifies rows by physical table name.
  -- A self-join therefore needs the alias-aware relational path or the two
  -- copies overwrite each other. Reuse the generic inner hash-chain executor.
  if leftRef["table"]~caselessEquals(rightRef["table"]) then return self~executeInnerJoinChainSelect(projection, rest, orderBy, .false)
  onAndWhere = afterJoin~substr(onPos + 4)~strip
  onUpper = onAndWhere~translate
  wherePos = onUpper~pos(" WHERE ")
  if wherePos = 0 then do
    onText = onAndWhere
    predicate = .nil
  end
  else do
    onText = onAndWhere~left(wherePos - 1)~strip
    predicateText = onAndWhere~substr(wherePos + 7)~strip
    expandedSet = self~expandSetSubqueryPredicates(predicateText)
    if expandedSet["error"] \== .nil then return expandedSet["error"]
    predicateText = expandedSet["text"]
    predicate = .SQLPredicateParser~new~parse(predicateText)
  end
  -- v0.72: keep the specialised two-table engine path only for a single
  -- column equality.  Compound/general ON expressions belong to the
  -- alias-aware relational join evaluator, which can use an equality term as
  -- an optimisation without mistaking the rest of the predicate for a column.
  onPredicate = .SQLPredicateParser~new~parse(onText)
  if onPredicate == .nil then return self~sqlParseFailure("Invalid JOIN ON predicate")
  if \onPredicate~isA(.SQLColumnComparisonPredicate) then return self~executeInnerJoinChainSelect(projection, rest, orderBy, .false)
  if onPredicate~operator \= "=" then return self~executeInnerJoinChainSelect(projection, rest, orderBy, .false)
  leftOnRef = onPredicate~leftReference
  rightOnRef = onPredicate~rightReference

  leftTable = leftRef["table"]
  leftAlias = leftRef["alias"]
  rightTable = rightRef["table"]
  rightAlias = rightRef["alias"]
  leftObj = self~engine~table(leftTable)
  rightObj = self~engine~table(rightTable)
  if leftObj == .nil then return self~sqlFailure("Table not found: " || leftTable)
  if rightObj == .nil then return self~sqlFailure("Table not found: " || rightTable)
  relation = .SQLRelationDefinition~new(leftObj~definition, leftAlias, rightObj~definition, rightAlias)
  leftResolved = relation~resolve(leftOnRef)
  rightResolved = relation~resolve(rightOnRef)
  if leftResolved == .nil then return self~sqlFailure("Unknown or ambiguous JOIN left column")
  if rightResolved == .nil then return self~sqlFailure("Unknown or ambiguous JOIN right column")
  if leftResolved["side"] = rightResolved["side"] then return self~sqlFailure("JOIN ON must reference both tables")
  if leftResolved["side"] = "LEFT" then do
    leftColumn = leftResolved["sourceColumn"]
    rightColumn = rightResolved["sourceColumn"]
  end
  else do
    leftColumn = rightResolved["sourceColumn"]
    rightColumn = leftResolved["sourceColumn"]
  end

  prefilter = .nil
  if predicate \== .nil then prefilter = self~simpleJoinPrefilter(predicate, relation)
  usePrefilter = .false
  snap = self~engine~joinMapSnapshot(leftTable, leftColumn, rightTable, rightColumn)
  if prefilter \== .nil then do
    if snap == .nil then usePrefilter = .true
    else do
      joinMapCost = .nil
      if snap~relationTo(leftObj~generation, rightObj~generation) = "CURRENT" then joinMapCost = snap~rowSnapshotCount
      if prefilter["side"] = "LEFT" then do
        candidates = self~engine~currentIndexCandidateCount(leftTable, prefilter["predicate"]~column, prefilter["predicate"]~value)
        otherRows = self~engine~tableRowCount(rightTable)
      end
      else do
        candidates = self~engine~currentIndexCandidateCount(rightTable, prefilter["predicate"]~column, prefilter["predicate"]~value)
        otherRows = self~engine~tableRowCount(leftTable)
      end
      prefilterCost = .DatabaseCostModel~new~equalityPrefilterCost(candidates, otherRows)
      choice = .DatabaseCostModel~new~chooseJoinPlan(joinMapCost, prefilterCost)
      if choice = "PREFILTER" then usePrefilter = .true
    end
  end

  if usePrefilter then do
    queryResult = self~engine~selectJoinWithSidePredicate(leftTable, leftColumn, rightTable, rightColumn, prefilter["side"], prefilter["predicate"])
  end
  else queryResult = self~engine~selectJoin(leftTable, leftColumn, rightTable, rightColumn)
  if queryResult~status \= .Error~SUCCESS then return queryResult

  self~engine~queryPatternLog~recordJoin(leftTable, leftColumn, rightTable, rightColumn, queryResult~rowsScanned, queryResult~rows~items)
  if predicate \== .nil then do
    filteredRows = .array~new
    do row over queryResult~rows
      if predicate~evaluate(row, relation) then filteredRows~append(row)
    end
    queryResult~rows = filteredRows
    queryResult~affectedRows = filteredRows~items
  end
  if orderBy \= "" then do
    queryResult = self~applyExpressionOrderBy(queryResult, orderBy, relation)
    if queryResult~status \= .Error~SUCCESS then return queryResult
  end
  return self~applyProjection(queryResult, projection, relation)

::method normalizeInnerJoinSyntax private
  use arg text
  out = text
  do forever
    upper = out~translate
    p = upper~pos(" INNER JOIN ")
    if p = 0 then leave
    out = out~left(p) || out~substr(p + 7)
  end
  return out

::method normalizeOuterJoinSyntax private
  use arg text
  out = text
  do forever
    upper = out~translate
    p = upper~pos(" RIGHT OUTER JOIN ")
    if p = 0 then leave
    out = out~left(p) || "RIGHT JOIN " || out~substr(p + 18)
  end
  do forever
    upper = out~translate
    p = upper~pos(" FULL OUTER JOIN ")
    if p = 0 then leave
    out = out~left(p) || "FULL JOIN " || out~substr(p + 17)
  end
  return out

::method naturalJoinKey private
  use arg row, names
  key = ""
  do name over names
    value = row[name]
    if value == .nil then return .nil
    s = value~string
    key ||= s~length || ":" || s || ";"
  end
  return key

::method executeNaturalJoinSelect private
  use arg projection, rest, orderBy, distinct = .false

  whereText = ""
  wherePos = self~findTopLevelKeyword(rest, " WHERE ")
  if wherePos > 0 then do
    whereText = rest~substr(wherePos + 7)~strip
    rest = rest~left(wherePos - 1)~strip
    if whereText = "" then return self~sqlParseFailure("WHERE requires a predicate")
  end

  naturalPos = rest~translate~pos(" NATURAL JOIN ")
  if naturalPos = 0 then return self~sqlParseFailure("NATURAL JOIN requires a joined table")
  if rest~translate~pos(" NATURAL JOIN ", naturalPos + 1) > 0 then ,
    return self~sqlUnsupported("Multiple NATURAL JOIN clauses are not implemented in one SELECT")

  leftRef = self~parseTableRef(rest~left(naturalPos - 1)~strip)
  rightRef = self~parseTableRef(rest~substr(naturalPos + 14)~strip)
  if leftRef == .nil then return self~sqlParseFailure("Invalid NATURAL JOIN left table reference")
  if rightRef == .nil then return self~sqlParseFailure("Invalid NATURAL JOIN right table reference")

  leftObj = self~engine~table(leftRef["table"])
  rightObj = self~engine~table(rightRef["table"])
  if leftObj == .nil then return self~sqlFailure("Table not found: " || leftRef["table"])
  if rightObj == .nil then return self~sqlFailure("Table not found: " || rightRef["table"])

  common = .array~new
  commonLookup = .table~new
  outputNames = .array~new
  do col over leftObj~definition~columns
    outputNames~append(col~name)
    if rightObj~definition~column(col~name) \== .nil then do
      common~append(col~name)
      commonLookup[col~name~translate] = .true
    end
  end
  do col over rightObj~definition~columns
    if commonLookup[col~name~translate] == .nil then outputNames~append(col~name)
  end

  leftRows = leftObj~readRows
  rightRows = rightObj~readRows
  outRows = .array~new

  if common~items = 0 then do
    do lrow over leftRows
      do rrow over rightRows
        vals = .table~new
        do col over leftObj~definition~columns
          vals[col~name] = lrow[col~name]
        end
        do col over rightObj~definition~columns
          vals[col~name] = rrow[col~name]
        end
        outRows~append(.DatabaseRow~new(vals))
      end
    end
  end
  else do
    buckets = .table~new
    do rrow over rightRows
      k = self~naturalJoinKey(rrow, common)
      if k == .nil then iterate
      arr = buckets[k]
      if arr == .nil then arr = .array~new
      arr~append(rrow)
      buckets[k] = arr
    end

    do lrow over leftRows
      k = self~naturalJoinKey(lrow, common)
      if k == .nil then iterate
      matches = buckets[k]
      if matches == .nil then iterate
      do rrow over matches
        vals = .table~new
        do col over leftObj~definition~columns
          vals[col~name] = lrow[col~name]
        end
        do col over rightObj~definition~columns
          if commonLookup[col~name~translate] == .nil then vals[col~name] = rrow[col~name]
        end
        outRows~append(.DatabaseRow~new(vals))
      end
    end
  end

  definition = .SQLSyntheticDefinition~new("__NATURAL__", outputNames)
  relation = .SQLRelationDefinition~new(definition)

  if whereText \= "" then do
    predicate = .SQLPredicateParser~new~parse(whereText)
    if predicate == .nil then return self~sqlParseFailure("Invalid NATURAL JOIN WHERE predicate")
    if \self~normalizeSinglePredicate(predicate, relation) then return self~sqlParseFailure("Unknown or ambiguous NATURAL JOIN WHERE column")
    filtered = .array~new
    do row over outRows
      if predicate~evaluate(row, definition) then filtered~append(row)
    end
    outRows = filtered
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = outRows
  rs~affectedRows = outRows~items
  rs~rowsScanned = leftRows~items + rightRows~items
  if common~items = 0 then rs~accessPath = "NATURAL_CROSS_SCAN"
  else rs~accessPath = "NATURAL_HASH_JOIN"

  preOrder = self~resolvedOrderBy(orderBy, relation)
  if preOrder \== .nil then do
    rs = self~applyOrderBy(rs, preOrder)
    if rs~status \= .Error~SUCCESS then return rs
    orderBy = ""
  end

  rs = self~applyProjection(rs, projection, relation)
  if rs~status \= .Error~SUCCESS then return rs
  if distinct then rs = self~applyDistinct(rs)
  return self~applyOrderBy(rs, orderBy)

::method executeInnerJoinChainSelect private
  use arg projection, rest, orderBy, distinct = .false
  restUpper = rest~translate
  wherePos = self~findTopLevelKeyword(rest, " WHERE ")
  if wherePos > 0 then do
    joinText = rest~left(wherePos - 1)~strip
    predicateText = rest~substr(wherePos + 7)~strip
    if predicateText = "" then return self~sqlParseFailure("WHERE requires a predicate")
    expandedSet = self~expandSetSubqueryPredicates(predicateText)
    if expandedSet["error"] \== .nil then return expandedSet["error"]
    predicateText = expandedSet["text"]
    predicate = .SQLPredicateParser~new~parse(predicateText)
  end
  else do
    joinText = rest
    predicate = .nil
  end
  firstPos = joinText~translate~pos(" JOIN ")
  if firstPos = 0 then return self~sqlFailure("JOIN requires joined table")
  baseRef = self~parseTableRef(joinText~left(firstPos - 1)~strip)
  if baseRef == .nil then return self~sqlFailure("Invalid JOIN base table reference")
  baseObj = self~engine~table(baseRef["table"])
  if baseObj == .nil then return self~sqlFailure("Table not found: " || baseRef["table"])
  entries = .array~new
  baseEntry = .table~new
  baseEntry["table"] = baseObj
  baseEntry["definition"] = baseObj~definition
  baseEntry["alias"] = baseRef["alias"]
  entries~append(baseEntry)
  joinSpecs = .array~new
  cursor = firstPos
  do while cursor > 0
    segmentStart = cursor + 6
    remaining = joinText~substr(segmentStart)~strip
    nextRel = remaining~translate~pos(" JOIN ")
    if nextRel > 0 then segment = remaining~left(nextRel - 1)~strip
    else segment = remaining
    onPos = segment~translate~pos(" ON ")
    if onPos = 0 then return self~sqlFailure("JOIN requires ON")
    rightRef = self~parseTableRef(segment~left(onPos - 1)~strip)
    if rightRef == .nil then return self~sqlFailure("Invalid JOIN table reference")
    rightObj = self~engine~table(rightRef["table"])
    if rightObj == .nil then return self~sqlFailure("Table not found: " || rightRef["table"])
    spec = .table~new
    spec["onText"] = segment~substr(onPos + 4)~strip
    spec["entry"] = .table~new
    spec["entry"]["table"] = rightObj
    spec["entry"]["definition"] = rightObj~definition
    spec["entry"]["alias"] = rightRef["alias"]
    entries~append(spec["entry"])
    joinSpecs~append(spec)
    if nextRel = 0 then leave
    cursor = segmentStart - 1 + nextRel
  end
  relation = .SQLAliasRelationDefinition~new(entries)
  rows = .array~new
  if baseEntry["rows"] \== .nil then do
    baseRows = baseEntry["rows"]
    scanned = baseEntry["derivedRowsScanned"]
    if scanned == .nil then scanned = baseRows~items
  end
  else do
    baseRows = baseObj~readRows
    scanned = baseRows~items
  end
  do rawRow over baseRows
    rows~append(self~qualifiedAliasRow(baseEntry, rawRow))
  end
  joinedAliases = .table~new
  joinedAliases[baseEntry["alias"]~translate] = .true
  usedPredicateFallback = .false
  do spec over joinSpecs
    entry = spec["entry"]
    onText = spec["onText"]
    onPredicate = .nil
    if self~findScalarSubqueryOpen(onText) > 0 then connector = self~findAliasJoinConnectorFromText(onText, relation, entry["alias"], joinedAliases)
    else do
      onPredicate = .SQLPredicateParser~new~parse(onText)
      if onPredicate == .nil then return self~sqlParseFailure("Invalid JOIN ON predicate")
      connector = self~findAliasJoinConnector(onPredicate, relation, entry["alias"], joinedAliases)
    end
    rightRows = entry["table"]~readRows
    scanned += rightRows~items
    if connector == .nil then do
      rows = self~extendByInnerPredicateCrossJoin(rows, entry, rightRows, onPredicate, relation, onText)
      usedPredicateFallback = .true
    end
    else rows = self~extendByInnerPredicateJoin(rows, entry, rightRows, connector, onPredicate, relation, onText)
    joinedAliases[entry["alias"]~translate] = .true
  end
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = rows
  rs~affectedRows = rows~items
  rs~rowsScanned = scanned
  if usedPredicateFallback then rs~accessPath = "INNER_PREDICATE_CHAIN"
  else rs~accessPath = "INNER_HASH_CHAIN"
  if predicate \== .nil then do
    filtered = .array~new
    do row over rs~rows
      if predicate~evaluate(row, relation) then filtered~append(row)
    end
    rs~rows = filtered
    rs~affectedRows = filtered~items
  end
  preOrder = self~resolvedOrderBy(orderBy, relation)
  if preOrder \== .nil then do
    rs = self~applyOrderBy(rs, preOrder)
    if rs~status \= .Error~SUCCESS then return rs
    orderBy = ""
  end
  rs = self~applyProjection(rs, projection, relation)
  if rs~status \= .Error~SUCCESS then return rs
  if distinct then rs = self~applyDistinct(rs)
  return self~applyOrderBy(rs, orderBy)

::method extendByInnerPredicateJoin private
  use arg currentRows, entry, newRows, connector, onPredicate, relation, onText = ""
  leftResolved = relation~resolve(connector~leftReference)
  rightResolved = relation~resolve(connector~rightReference)
  if leftResolved == .nil then return .array~new
  if rightResolved == .nil then return .array~new
  alias = entry["alias"]
  if leftResolved["alias"]~caselessEquals(alias) then do
    newResolved = leftResolved
    existingResolved = rightResolved
  end
  else if rightResolved["alias"]~caselessEquals(alias) then do
    newResolved = rightResolved
    existingResolved = leftResolved
  end
  else return .array~new
  buckets = .table~new
  do rawRow over newRows
    value = rawRow[newResolved["sourceColumn"]]
    if value == .nil then iterate
    key = value~string
    arr = buckets[key]
    if arr == .nil then arr = .array~new
    arr~append(rawRow)
    buckets[key] = arr
  end
  out = .array~new
  do current over currentRows
    value = current[existingResolved["physicalName"]]
    if value == .nil then iterate
    matches = buckets[value~string]
    if matches == .nil then iterate
    do rawRow over matches
      values = current~values~copy
      do col over entry["definition"]~columns
        values[alias || "." || col~name] = rawRow[col~name]
      end
      combined = .DatabaseRow~new(values)
      candidatePredicate = onPredicate
      if candidatePredicate == .nil then do
        bound = self~bindScalarSubqueries(onText, combined, relation)
        if bound == .nil then iterate
        candidatePredicate = .SQLPredicateParser~new~parse(bound)
        if candidatePredicate == .nil then iterate
      end
      if candidatePredicate~evaluate(combined, relation) then out~append(combined)
    end
  end
  return out

::method extendByInnerPredicateCrossJoin private
  use arg currentRows, entry, newRows, onPredicate, relation, onText = ""
  out = .array~new
  alias = entry["alias"]
  do current over currentRows
    do rawRow over newRows
      values = current~values~copy
      do col over entry["definition"]~columns
        values[alias || "." || col~name] = rawRow[col~name]
      end
      combined = .DatabaseRow~new(values)
      candidatePredicate = onPredicate
      if candidatePredicate == .nil then do
        bound = self~bindScalarSubqueries(onText, combined, relation)
        if bound == .nil then iterate
        candidatePredicate = .SQLPredicateParser~new~parse(bound)
        if candidatePredicate == .nil then iterate
      end
      if candidatePredicate~evaluate(combined, relation) then out~append(combined)
    end
  end
  return out

::method executeRightJoinSelect private
  use arg projection, rest, orderBy, distinct = .false
  restUpper = rest~translate
  wherePos = restUpper~pos(" WHERE ")
  if wherePos > 0 then do
    joinText = rest~left(wherePos - 1)~strip
    whereText = rest~substr(wherePos)~strip
  end
  else do
    joinText = rest
    whereText = ""
  end
  joinPos = joinText~translate~pos(" RIGHT JOIN ")
  if joinPos = 0 then return self~sqlFailure("RIGHT JOIN requires joined table")
  leftText = joinText~left(joinPos - 1)~strip
  afterJoin = joinText~substr(joinPos + 12)~strip
  onPos = afterJoin~translate~pos(" ON ")
  if onPos = 0 then return self~sqlFailure("RIGHT JOIN requires ON")
  rightText = afterJoin~left(onPos - 1)~strip
  onText = afterJoin~substr(onPos + 4)~strip
  rewritten = rightText || " LEFT JOIN " || leftText || " ON " || onText
  if whereText \= "" then rewritten = rewritten || " " || whereText
  rs = self~executeLeftJoinSelect(projection, rewritten, orderBy, distinct)
  if rs~status = .Error~SUCCESS then rs~accessPath = "RIGHT_HASH_CHAIN"
  return rs

::method executeFullJoinSelect private
  use arg projection, rest, orderBy, distinct = .false
  restUpper = rest~translate
  wherePos = restUpper~pos(" WHERE ")
  if wherePos > 0 then do
    joinText = rest~left(wherePos - 1)~strip
    predicateText = rest~substr(wherePos + 7)~strip
    if predicateText = "" then return self~sqlParseFailure("WHERE requires a predicate")
    expandedSet = self~expandSetSubqueryPredicates(predicateText)
    if expandedSet["error"] \== .nil then return expandedSet["error"]
    predicate = .SQLPredicateParser~new~parse(expandedSet["text"])
  end
  else do
    joinText = rest
    predicate = .nil
  end

  joinPos = joinText~translate~pos(" FULL JOIN ")
  if joinPos = 0 then return self~sqlFailure("FULL JOIN requires joined table")
  leftRef = self~parseTableRef(joinText~left(joinPos - 1)~strip)
  if leftRef == .nil then return self~sqlFailure("Invalid FULL JOIN left table reference")
  afterJoin = joinText~substr(joinPos + 11)~strip
  onPos = afterJoin~translate~pos(" ON ")
  if onPos = 0 then return self~sqlFailure("FULL JOIN requires ON")
  rightRef = self~parseTableRef(afterJoin~left(onPos - 1)~strip)
  if rightRef == .nil then return self~sqlFailure("Invalid FULL JOIN right table reference")
  onText = afterJoin~substr(onPos + 4)~strip

  leftObj = self~engine~table(leftRef["table"])
  rightObj = self~engine~table(rightRef["table"])
  if leftObj == .nil then return self~sqlFailure("Table not found: " || leftRef["table"])
  if rightObj == .nil then return self~sqlFailure("Table not found: " || rightRef["table"])

  entries = .array~new
  leftEntry = .table~new
  leftEntry["table"] = leftObj
  leftEntry["definition"] = leftObj~definition
  leftEntry["alias"] = leftRef["alias"]
  rightEntry = .table~new
  rightEntry["table"] = rightObj
  rightEntry["definition"] = rightObj~definition
  rightEntry["alias"] = rightRef["alias"]
  entries~append(leftEntry)
  entries~append(rightEntry)
  relation = .SQLAliasRelationDefinition~new(entries)
  onPredicate = .SQLPredicateParser~new~parse(onText)

  leftRows = leftObj~readRows
  rightRows = rightObj~readRows
  matchedRight = .table~new
  out = .array~new

  do leftRaw over leftRows
    leftQualified = self~qualifiedAliasRow(leftEntry, leftRaw)
    matchedLeft = .false
    rightIndex = 0
    do rightRaw over rightRows
      rightIndex += 1
      values = leftQualified~values~copy
      do col over rightEntry["definition"]~columns
        values[rightEntry["alias"] || "." || col~name] = rightRaw[col~name]
      end
      combined = .DatabaseRow~new(values)
      if onPredicate~evaluate(combined, relation) then do
        out~append(combined)
        matchedLeft = .true
        matchedRight[rightIndex] = .true
      end
    end
    if \matchedLeft then do
      values = leftQualified~values~copy
      do col over rightEntry["definition"]~columns
        values[rightEntry["alias"] || "." || col~name] = .nil
      end
      out~append(.DatabaseRow~new(values))
    end
  end

  rightIndex = 0
  do rightRaw over rightRows
    rightIndex += 1
    if matchedRight[rightIndex] \== .nil then iterate
    values = .table~new
    do col over leftEntry["definition"]~columns
      values[leftEntry["alias"] || "." || col~name] = .nil
    end
    do col over rightEntry["definition"]~columns
      values[rightEntry["alias"] || "." || col~name] = rightRaw[col~name]
    end
    out~append(.DatabaseRow~new(values))
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = out
  rs~affectedRows = out~items
  rs~rowsScanned = leftRows~items + rightRows~items
  rs~accessPath = "FULL_OUTER_NESTED_LOOP"

  if predicate \== .nil then do
    filtered = .array~new
    do row over rs~rows
      if predicate~evaluate(row, relation) then filtered~append(row)
    end
    rs~rows = filtered
    rs~affectedRows = filtered~items
  end

  preOrder = self~resolvedOrderBy(orderBy, relation)
  if preOrder \== .nil then do
    rs = self~applyOrderBy(rs, preOrder)
    if rs~status \= .Error~SUCCESS then return rs
    orderBy = ""
  end
  else if orderBy \= "" then do
    rs = self~applyExpressionOrderBy(rs, orderBy, relation)
    if rs~status \= .Error~SUCCESS then return rs
    orderBy = ""
  end
  rs = self~applyProjection(rs, projection, relation)
  if rs~status \= .Error~SUCCESS then return rs
  if distinct then rs = self~applyDistinct(rs)
  return self~applyOrderBy(rs, orderBy)

::method buildValuesTableSource private
  use arg sourceText
  text = sourceText~strip
  if text~left(1) \= "(" then return .nil
  closePos = self~matchingParen(text, 1)
  if closePos = 0 then return .nil
  inner = text~substr(2, closePos - 2)~strip
  if \inner~translate~startsWith("VALUES ") then return .nil

  tail = text~substr(closePos + 1)~strip
  if tail~translate~startsWith("AS ") then tail = tail~substr(4)~strip
  aliasOpen = tail~pos("(")
  if aliasOpen = 0 then return .nil
  aliasClose = self~matchingParen(tail, aliasOpen)
  if aliasClose \= tail~length then return .nil
  alias = tail~left(aliasOpen - 1)~strip
  if alias = "" | alias~space~words \= 1 then return .nil
  columnText = tail~substr(aliasOpen + 1, aliasClose - aliasOpen - 1)
  names = self~trimmedList(columnText)
  if names~items = 0 then return .nil

  tuplesText = inner~substr(8)~strip
  tupleTexts = self~splitList(tuplesText)
  rawRows = .array~new
  do tupleText over tupleTexts
    tuple = tupleText~strip
    if tuple~left(1) \= "(" then return .nil
    tupleClose = self~matchingParen(tuple, 1)
    if tupleClose \= tuple~length then return .nil
    values = self~splitList(tuple~substr(2, tuple~length - 2))
    if values~items \= names~items then return .nil
    rowValues = .table~new
    do i = 1 to names~items
      rowValues[names[i]] = self~literal(values[i]~strip)
    end
    rawRows~append(.DatabaseRow~new(rowValues))
  end

  out = .table~new
  out["alias"] = alias
  out["definition"] = .SQLVirtualDefinition~new(alias, names)
  out["rows"] = rawRows
  out["rowsScanned"] = rawRows~items
  return out

::method executeLeftJoinSelect private
  use arg projection, rest, orderBy, distinct = .false
  restUpper = rest~translate
  wherePos = restUpper~pos(" WHERE ")
  if wherePos > 0 then do
    joinText = rest~left(wherePos - 1)~strip
    predicateText = rest~substr(wherePos + 7)~strip
    if predicateText = "" then return self~sqlParseFailure("WHERE requires a predicate")
    expandedSet = self~expandSetSubqueryPredicates(predicateText)
    if expandedSet["error"] \== .nil then return expandedSet["error"]
    predicateText = expandedSet["text"]
    predicate = .SQLPredicateParser~new~parse(predicateText)
  end
  else do
    joinText = rest
    predicate = .nil
  end

  firstPos = self~findTopLevelKeyword(joinText, " LEFT JOIN ")
  if firstPos = 0 then return self~sqlFailure("LEFT JOIN requires joined table")
  baseText = joinText~left(firstPos - 1)~strip

  entries = .array~new
  baseEntry = .table~new
  if baseText~left(1) = "(" then do
    valuesSource = self~buildValuesTableSource(baseText)
    if valuesSource == .nil then return self~sqlFailure("Invalid LEFT JOIN base table reference")
    baseObj = .nil
    baseEntry["table"] = .nil
    baseEntry["definition"] = valuesSource["definition"]
    baseEntry["alias"] = valuesSource["alias"]
    baseEntry["rows"] = valuesSource["rows"]
    baseEntry["derivedRowsScanned"] = valuesSource["rowsScanned"]
  end
  else do
    baseRef = self~parseTableRef(baseText)
    if baseRef == .nil then return self~sqlFailure("Invalid LEFT JOIN base table reference")
    baseObj = self~engine~table(baseRef["table"])
    if baseObj == .nil then return self~sqlFailure("Table not found: " || baseRef["table"])
    baseEntry["table"] = baseObj
    baseEntry["definition"] = baseObj~definition
    baseEntry["alias"] = baseRef["alias"]
  end
  entries~append(baseEntry)

  joinSpecs = .array~new
  cursor = firstPos
  do while cursor > 0
    segmentStart = cursor + 11
    remaining = joinText~substr(segmentStart)~strip
    nextRel = remaining~translate~pos(" LEFT JOIN ")
    if nextRel > 0 then segment = remaining~left(nextRel - 1)~strip
    else segment = remaining
    onPos = segment~translate~pos(" ON ")
    if onPos = 0 then return self~sqlFailure("LEFT JOIN requires ON")
    rightText = segment~left(onPos - 1)~strip
    spec = .table~new
    spec["onText"] = segment~substr(onPos + 4)~strip
    spec["entry"] = .table~new
    if rightText~left(1) = "(" then do
      valuesSource = self~buildValuesTableSource(rightText)
      if valuesSource \== .nil then do
        spec["entry"]["table"] = .nil
        spec["entry"]["definition"] = valuesSource["definition"]
        spec["entry"]["alias"] = valuesSource["alias"]
        spec["entry"]["rows"] = valuesSource["rows"]
        spec["entry"]["derivedRowsScanned"] = valuesSource["rowsScanned"]
      end
      else do
        derived = self~buildDerivedAggregateSource(rightText)
        if derived == .nil then return self~sqlFailure("Invalid LEFT JOIN derived table reference")
        drel = derived["relation"]
        names = drel~names
        alias = drel~alias
        definition = .SQLVirtualDefinition~new(alias, names)
        rawRows = .array~new
        do drow over derived["rows"]
          vals = .table~new
          do n over names
            vals[n] = drow[alias || "." || n]
          end
          rawRows~append(.DatabaseRow~new(vals))
        end
        spec["entry"]["table"] = .nil
        spec["entry"]["definition"] = definition
        spec["entry"]["alias"] = alias
        spec["entry"]["rows"] = rawRows
        spec["entry"]["derivedRowsScanned"] = derived["rowsScanned"]
      end
    end
    else do
      rightRef = self~parseTableRef(rightText)
      if rightRef == .nil then return self~sqlFailure("Invalid LEFT JOIN table reference")
      rightObj = self~engine~table(rightRef["table"])
      if rightObj == .nil then return self~sqlFailure("Table not found: " || rightRef["table"])
      spec["entry"]["table"] = rightObj
      spec["entry"]["definition"] = rightObj~definition
      spec["entry"]["alias"] = rightRef["alias"]
    end
    entries~append(spec["entry"])
    joinSpecs~append(spec)
    if nextRel = 0 then leave
    cursor = segmentStart - 1 + nextRel
  end

  relation = .SQLAliasRelationDefinition~new(entries)
  rows = .array~new
  if baseEntry["rows"] \== .nil then do
    baseRows = baseEntry["rows"]
    scanned = baseEntry["derivedRowsScanned"]
    if scanned == .nil then scanned = baseRows~items
  end
  else do
    baseRows = baseObj~readRows
    scanned = baseRows~items
  end
  do rawRow over baseRows
    rows~append(self~qualifiedAliasRow(baseEntry, rawRow))
  end

  joinedAliases = .table~new
  joinedAliases[baseEntry["alias"]~translate] = .true
  do spec over joinSpecs
    entry = spec["entry"]
    onPredicate = .SQLPredicateParser~new~parse(spec["onText"])
    connector = self~findAliasJoinConnector(onPredicate, relation, entry["alias"], joinedAliases)
    if connector == .nil then return self~sqlUnsupported("LEFT JOIN ON requires an equality connector to the joined relation")
    if entry["rows"] \== .nil then do
      rightRows = entry["rows"]
      extraScanned = entry["derivedRowsScanned"]
      if extraScanned == .nil then extraScanned = rightRows~items
      scanned += extraScanned
    end
    else do
      rightRows = entry["table"]~readRows
      scanned += rightRows~items
    end
    rows = self~extendByLeftPredicateJoin(rows, entry, rightRows, connector, onPredicate, relation)
    joinedAliases[entry["alias"]~translate] = .true
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = rows
  rs~affectedRows = rows~items
  rs~rowsScanned = scanned
  rs~accessPath = "LEFT_HASH_CHAIN"

  if predicate \== .nil then do
    filtered = .array~new
    do row over rs~rows
      if predicate~evaluate(row, relation) then filtered~append(row)
    end
    rs~rows = filtered
    rs~affectedRows = filtered~items
  end
  preOrder = self~resolvedOrderBy(orderBy, relation)
  if preOrder \== .nil then do
    rs = self~applyOrderBy(rs, preOrder)
    if rs~status \= .Error~SUCCESS then return rs
    orderBy = ""
  end
  rs = self~applyProjection(rs, projection, relation)
  if rs~status \= .Error~SUCCESS then return rs
  if distinct then rs = self~applyDistinct(rs)
  return self~applyOrderBy(rs, orderBy)

::method qualifiedAliasRow private
  use arg entry, rawRow
  values = .table~new
  alias = entry["alias"]
  do col over entry["definition"]~columns
    values[alias || "." || col~name] = rawRow[col~name]
  end
  return .DatabaseRow~new(values)

::method extendByLeftPredicateJoin private
  use arg currentRows, entry, newRows, connector, onPredicate, relation
  leftResolved = relation~resolve(connector~leftReference)
  rightResolved = relation~resolve(connector~rightReference)
  if leftResolved == .nil then return currentRows
  if rightResolved == .nil then return currentRows
  alias = entry["alias"]
  newResolved = .nil
  existingResolved = .nil
  if leftResolved["alias"]~caselessEquals(alias) then do
    newResolved = leftResolved
    existingResolved = rightResolved
  end
  else if rightResolved["alias"]~caselessEquals(alias) then do
    newResolved = rightResolved
    existingResolved = leftResolved
  end
  else return currentRows

  buckets = .table~new
  do rawRow over newRows
    value = rawRow[newResolved["sourceColumn"]]
    if value == .nil then iterate
    key = value~string
    arr = buckets[key]
    if arr == .nil then arr = .array~new
    arr~append(rawRow)
    buckets[key] = arr
  end

  out = .array~new
  do current over currentRows
    value = current[existingResolved["physicalName"]]
    matches = .nil
    if value \== .nil then matches = buckets[value~string]
    matched = .false
    if matches \== .nil then do rawRow over matches
      values = current~values~copy
      do col over entry["definition"]~columns
        values[alias || "." || col~name] = rawRow[col~name]
      end
      combined = .DatabaseRow~new(values)
      if onPredicate~evaluate(combined, relation) then do
        out~append(combined)
        matched = .true
      end
    end
    if \matched then do
      values = current~values~copy
      do col over entry["definition"]~columns
        values[alias || "." || col~name] = .nil
      end
      out~append(.DatabaseRow~new(values))
    end
  end
  return out

::method findAliasJoinConnectorFromText private
  use arg predicateText, relation, newAlias, joinedAliases
  remaining = predicateText~strip
  do while remaining \= ""
    andPos = self~findTopLevelKeyword(" " || remaining || " ", " AND ")
    if andPos > 0 then do
      padded = " " || remaining || " "
      clause = padded~left(andPos - 1)~strip
      remaining = padded~substr(andPos + 5)~strip
    end
    else do
      clause = remaining
      remaining = ""
    end
    if self~findScalarSubqueryOpen(clause) > 0 then iterate
    pred = .SQLPredicateParser~new~parse(clause)
    if pred == .nil then iterate
    connector = self~findAliasJoinConnector(pred, relation, newAlias, joinedAliases)
    if connector \== .nil then return connector
  end
  return .nil

::method findAliasJoinConnector private
  use arg predicate, relation, newAlias, joinedAliases
  predicates = self~flattenAndPredicates(predicate)
  do pred over predicates
    if \pred~isA(.SQLColumnComparisonPredicate) then iterate
    if pred~operator \= "=" then iterate
    leftResolved = relation~resolve(pred~leftReference)
    rightResolved = relation~resolve(pred~rightReference)
    if leftResolved == .nil then iterate
    if rightResolved == .nil then iterate
    leftIsNew = leftResolved["alias"]~caselessEquals(newAlias)
    rightIsNew = rightResolved["alias"]~caselessEquals(newAlias)
    if leftIsNew then do
      if joinedAliases[rightResolved["alias"]~translate] \== .nil then return pred
    end
    if rightIsNew then do
      if joinedAliases[leftResolved["alias"]~translate] \== .nil then return pred
    end
  end
  return .nil

::method executeCrossJoinSelect private
  use arg projection, rest, orderBy, distinct = .false
  restUpper = rest~translate
  wherePos = restUpper~pos(" WHERE ")
  if wherePos = 0 then do
    refsText = rest
    predicate = .nil
  end
  else do
    refsText = rest~left(wherePos - 1)~strip
    predicateText = rest~substr(wherePos + 7)~strip
    if predicateText = "" then return self~sqlParseFailure("WHERE requires a predicate")
    if self~findScalarSubqueryOpen(predicateText) > 0 then predicate = .nil
    else predicate = .SQLPredicateParser~new~parse(predicateText)
  end
  refTexts = self~splitList(refsText)
  if refTexts~items < 2 then return self~sqlFailure("Cross join requires at least two tables")

  entries = .array~new
  do refText over refTexts
    ref = self~parseTableRef(refText)
    if ref == .nil then return self~sqlFailure("Invalid cross-join table reference")
    obj = self~engine~table(ref["table"])
    if obj == .nil then return self~sqlFailure("Table not found: " || ref["table"])
    entry = .table~new
    entry["table"] = obj
    entry["definition"] = obj~definition
    entry["alias"] = ref["alias"]
    entries~append(entry)
  end
  relation = .SQLMultiRelationDefinition~new(entries)

  -- Retain the optimized two-table path introduced in v0.7 when possible.
  if entries~items = 2 then do
    prefilter = .nil
    if predicate \== .nil then prefilter = self~simpleMultiPrefilter(predicate, relation, entries)
    if prefilter \== .nil then do
      queryResult = self~engine~selectCrossJoinWithSidePredicate(entries[1]["table"]~definition~name, entries[2]["table"]~definition~name, prefilter["side"], prefilter["predicate"])
      if queryResult~status = .Error~SUCCESS then queryResult~accessPath = "CROSS_PREFILTER_" || prefilter["side"] || "_" || queryResult~accessPath~substr(queryResult~accessPath~lastPos("_") + 1)
    end
    else queryResult = self~engine~selectCrossJoin(entries[1]["table"]~definition~name, entries[2]["table"]~definition~name)
  end
  else queryResult = self~executeMultiCommaJoin(entries, relation, predicate)
  if queryResult~status \= .Error~SUCCESS then return queryResult

  if wherePos > 0 then do
    filteredRows = .array~new
    do row over queryResult~rows
      rowPredicate = predicate
      if self~findScalarSubqueryOpen(predicateText) > 0 then do
        bound = self~bindScalarSubqueries(predicateText, row, relation)
        if bound == .nil then return self~sqlUnsupported("Scalar subquery in cross-join WHERE could not be evaluated")
        rowPredicate = .SQLPredicateParser~new~parse(bound)
        if rowPredicate == .nil then return self~sqlParseFailure("Invalid cross-join WHERE predicate")
      end
      if rowPredicate~evaluate(row, relation) then filteredRows~append(row)
    end
    queryResult~rows = filteredRows
    queryResult~affectedRows = filteredRows~items
  end
  queryResult = self~applyProjection(queryResult, projection, relation)
  if queryResult~status \= .Error~SUCCESS then return queryResult
  if distinct then queryResult = self~applyDistinct(queryResult)
  return self~applyOrderBy(queryResult, orderBy)

::method executeMultiCommaJoin private
  use arg entries, relation, predicate
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  predicates = self~flattenAndPredicates(predicate)
  first = entries[1]
  rows = .array~new
  firstRows = first["table"]~readRows
  do rawRow over firstRows
    rows~append(self~qualifiedSingleRow(first["table"], rawRow))
  end
  scanned = firstRows~items
  joinedNames = .table~new
  joinedNames[first["table"]~definition~name] = .true

  do i = 2 to entries~items
    entry = entries[i]
    tableObj = entry["table"]
    newRows = tableObj~readRows
    scanned += newRows~items
    connector = self~findConnectorPredicate(predicates, relation, tableObj~definition~name, joinedNames)
    if connector == .nil then rows = self~extendByCrossProduct(rows, tableObj, newRows)
    else rows = self~extendByEqualityJoin(rows, tableObj, newRows, connector, relation)
    joinedNames[tableObj~definition~name] = .true
  end
  rs~rows = rows
  rs~affectedRows = rows~items
  rs~accessPath = "MULTI_COMMA_EQUIJOIN"
  rs~rowsScanned = scanned
  return rs

::method qualifiedSingleRow private
  use arg tableObj, rawRow
  values = .table~new
  tableName = tableObj~definition~name
  do col over tableObj~definition~columns
    values[tableName || "." || col~name] = rawRow[col~name]
  end
  return .DatabaseRow~new(values)

::method extendByCrossProduct private
  use arg currentRows, tableObj, newRows
  out = .array~new
  tableName = tableObj~definition~name
  do current over currentRows
    do newRow over newRows
      values = current~values~copy
      do col over tableObj~definition~columns
        values[tableName || "." || col~name] = newRow[col~name]
      end
      out~append(.DatabaseRow~new(values))
    end
  end
  return out

::method extendByEqualityJoin private
  use arg currentRows, tableObj, newRows, connector, relation
  leftResolved = relation~resolve(connector~leftReference)
  rightResolved = relation~resolve(connector~rightReference)
  newName = tableObj~definition~name
  if leftResolved["tableName"] = newName then do
    newResolved = leftResolved
    existingResolved = rightResolved
  end
  else do
    newResolved = rightResolved
    existingResolved = leftResolved
  end
  buckets = .table~new
  do rawRow over newRows
    value = rawRow[newResolved["sourceColumn"]]
    if value == .nil then iterate
    key = value~string
    arr = buckets[key]
    if arr == .nil then arr = .array~new
    arr~append(rawRow)
    buckets[key] = arr
  end
  out = .array~new
  do current over currentRows
    value = current[existingResolved["physicalName"]]
    if value == .nil then iterate
    matches = buckets[value~string]
    if matches == .nil then iterate
    do rawRow over matches
      values = current~values~copy
      do col over tableObj~definition~columns
        values[newName || "." || col~name] = rawRow[col~name]
      end
      out~append(.DatabaseRow~new(values))
    end
  end
  return out

::method findConnectorPredicate private
  use arg predicates, relation, newTableName, joinedNames
  do pred over predicates
    if \pred~isA(.SQLColumnComparisonPredicate) then iterate
    if pred~operator \= "=" then iterate
    leftResolved = relation~resolve(pred~leftReference)
    rightResolved = relation~resolve(pred~rightReference)
    if leftResolved == .nil then iterate
    if rightResolved == .nil then iterate
    if leftResolved["tableName"] = newTableName then do
      if joinedNames[rightResolved["tableName"]] \== .nil then return pred
    end
    if rightResolved["tableName"] = newTableName then do
      if joinedNames[leftResolved["tableName"]] \== .nil then return pred
    end
  end
  return .nil

::method flattenAndPredicates private
  use arg predicate
  out = .array~new
  if predicate == .nil then return out
  if predicate~isA(.SQLLogicalPredicate) then do
    if predicate~operator = "AND" then do
      left = self~flattenAndPredicates(predicate~left)
      right = self~flattenAndPredicates(predicate~right)
      do item over left
        out~append(item)
      end
      do item over right
        out~append(item)
      end
      return out
    end
  end
  out~append(predicate)
  return out

::method simpleMultiPrefilter private
  use arg predicate, relation, entries
  if \predicate~isA(.SQLComparisonPredicate) then return .nil
  if predicate~operator \= "=" then return .nil
  resolved = relation~resolve(predicate~column)
  if resolved == .nil then return .nil
  sidePredicate = .SQLComparisonPredicate~new(resolved["sourceColumn"], predicate~operator, predicate~value)
  out = .table~new
  if resolved["tableName"] = entries[1]["table"]~definition~name then out["side"] = "LEFT"
  else if resolved["tableName"] = entries[2]["table"]~definition~name then out["side"] = "RIGHT"
  else return .nil
  out["predicate"] = sidePredicate
  return out

::method applyDistinct private
  use arg queryResult
  seen = .table~new
  out = .array~new
  do row over queryResult~rows
    sig = self~rowSignature(row)
    if seen[sig] \== .nil then iterate
    seen[sig] = .true
    out~append(row)
  end
  queryResult~rows = out
  queryResult~affectedRows = out~items
  return queryResult

::method rowSignature private
  use arg row
  keys = .array~new
  do key over row~values
    keys~append(key~string)
  end
  if keys~items > 1 then keys~sort
  sig = ""
  do key over keys
    value = row[key]
    if value == .nil then valueText = "<NULL>"
    else valueText = value~string
    sig ||= key~length || ":" || key || "=" || valueText~length || ":" || valueText || "1E"x
  end
  return sig

::method resolvedOrderBy private
  use arg orderBy, relation
  if orderBy = "" then return .nil
  specs = self~splitList(orderBy)
  translated = .array~new
  do specText over specs
    words = specText~strip~space~makeArray(" ")
    if words~items < 1 then return .nil
    if words~items > 4 then return .nil
    resolved = relation~resolve(words[1])
    if resolved == .nil then return .nil
    item = resolved["physicalName"]
    i = 2
    if i <= words~items then do
      dir = words[i]~translate
      if dir = "ASC" | dir = "DESC" then do
        item ||= " " || dir
        i += 1
      end
    end
    if i <= words~items then do
      if words[i]~translate \= "NULLS" then return .nil
      if i + 1 > words~items then return .nil
      nullDir = words[i + 1]~translate
      if nullDir \= "FIRST" & nullDir \= "LAST" then return .nil
      item ||= " NULLS " || nullDir
      i += 2
    end
    if i <= words~items then return .nil
    translated~append(item)
  end
  return self~joinArray(translated, ", ")

::method joinArray private
  use arg items, separator
  out = ""
  first = .true
  do item over items
    if first then first = .false
    else out ||= separator
    out ||= item
  end
  return out

::method parseOrderExpressionSpec private
  use arg specText
  text = specText~strip
  upper = text~translate
  direction = "ASC"
  if upper~endsWith(" DESC") then do
    direction = "DESC"
    text = text~left(text~length - 5)~strip
  end
  else if upper~endsWith(" ASC") then do
    text = text~left(text~length - 4)~strip
  end
  if text = "" then return .nil
  out = .table~new
  out["expression"] = text
  out["direction"] = direction
  return out

::method expandOrderByProjectionAliases private
  use arg orderBy, projection
  if orderBy = "" then return orderBy
  aliases = .table~new
  do item over self~splitList(projection)
    spec = self~parseProjectionSpec(item)
    if spec == .nil then iterate
    alias = spec["alias"]
    if alias \= "" then aliases[alias~translate] = "(" || spec["expression"] || ")"
  end
  if aliases~items = 0 then return orderBy
  out = ""; quote = ""; i = 1
  do while i <= orderBy~length
    ch = orderBy~substr(i,1)
    if quote \= "" then do
      out ||= ch
      if ch = quote then do
        if i < orderBy~length then do
          if orderBy~substr(i+1,1) = quote then do; out ||= quote; i += 1; end
          else quote = ""
        end
        else quote = ""
      end
      i += 1; iterate
    end
    if ch = "'" | ch = '"' then do; quote = ch; out ||= ch; i += 1; iterate; end
    if datatype(ch, "A") | ch = "_" then do
      start = i
      do while i <= orderBy~length
        c = orderBy~substr(i,1)
        if \datatype(c, "A") & \datatype(c, "N") & c \= "_" then leave
        i += 1
      end
      token = orderBy~substr(start, i-start)
      prev = ""; next = ""
      if start > 1 then prev = orderBy~substr(start-1,1)
      if i <= orderBy~length then next = orderBy~substr(i,1)
      repl = aliases[token~translate]
      if repl \== .nil & prev \= "." & next \= "." then out ||= repl
      else out ||= token
      iterate
    end
    out ||= ch; i += 1
  end
  return out

::method applyExpressionOrderBy private
  use arg queryResult, orderBy, relation
  if orderBy = "" then return queryResult
  specs = .array~new
  do specText over self~splitList(orderBy)
    spec = self~parseOrderExpressionSpec(specText)
    if spec == .nil then return self~sqlParseFailure("Invalid ORDER BY")
    if queryResult~rows~items > 0 then do
      probe = self~evaluateProjectionExpression(spec["expression"], queryResult~rows[1], relation)
      if \probe["ok"] then return self~sqlUnsupported("ORDER BY expression is not implemented: " || spec["expression"])
    end
    specs~append(spec)
  end
  rows = queryResult~rows
  if rows~items < 2 then return queryResult
  i = 2
  do while i <= rows~items
    current = rows[i]
    j = i - 1
    do while j >= 1
      if self~compareExpressionOrderRows(rows[j], current, specs, relation) <= 0 then leave
      rows[j + 1] = rows[j]
      j -= 1
    end
    rows[j + 1] = current
    i += 1
  end
  queryResult~rows = rows
  return queryResult

::method compareExpressionOrderRows private
  use arg leftRow, rightRow, specs, relation
  do spec over specs
    leftValue = self~evaluateProjectionExpression(spec["expression"], leftRow, relation)
    rightValue = self~evaluateProjectionExpression(spec["expression"], rightRow, relation)
    if \leftValue["ok"] | \rightValue["ok"] then return 0
    lv = leftValue["value"]
    rv = rightValue["value"]
    cmp = self~compareScalarValues(lv, rv)
    if spec["direction"] = "DESC" then cmp = 0 - cmp
    if cmp \= 0 then return cmp
  end
  return 0

::method compareScalarValues private
  use arg lv, rv
  if lv == .nil then do
    if rv == .nil then return 0
    return -1
  end
  if rv == .nil then return 1
  if .NoSQLUnicodeSupport~isUnicodeValue(lv) then return .NoSQLUnicodeSupport~compareValues(lv, rv)
  if .NoSQLUnicodeSupport~isUnicodeValue(rv) then return .NoSQLUnicodeSupport~compareValues(lv, rv)
  ls = lv~string
  rs = rv~string
  if datatype(ls, "N") then do
    if datatype(rs, "N") then do
      if ls < rs then return -1
      if ls > rs then return 1
      return 0
    end
  end
  if ls < rs then return -1
  if ls > rs then return 1
  return 0

::method applyOrderBy private
  use arg queryResult, orderBy, sortBound = .nil
  if orderBy = "" then return queryResult
  rows = queryResult~rows
  compiled = self~compileOrderSpecs(orderBy, rows)
  if compiled["error"] \== .nil then return compiled["error"]
  specs = compiled["specs"]
  if rows~items < 2 then return queryResult

  if sortBound \== .nil then do
    if sortBound <= 0 then do
      queryResult~rows = .array~new
      return queryResult
    end
    if sortBound < rows~items then rows = self~boundedTopRows(rows, specs, sortBound)
    else rows = self~mergeSortRows(rows, specs)
  end
  else rows = self~mergeSortRows(rows, specs)

  queryResult~rows = rows
  return queryResult

::method compileOrderSpecs private
  use arg orderBy, rows
  out = .table~new
  out["error"] = .nil
  specs = .array~new
  requestedSpecs = self~splitList(orderBy)

  do specText over requestedSpecs
    words = specText~strip~space~makeArray(" ")
    if words~items < 1 then do
      out["error"] = self~sqlFailure("Invalid ORDER BY")
      return out
    end
    if words~items > 4 then do
      out["error"] = self~sqlUnsupported("ORDER BY expressions are not implemented")
      return out
    end

    direction = "ASC"
    nullOrdering = ""
    wi = 2
    if wi <= words~items then do
      maybeDirection = words[wi]~translate
      if maybeDirection = "ASC" | maybeDirection = "DESC" then do
        direction = maybeDirection
        wi += 1
      end
    end
    if wi <= words~items then do
      if words[wi]~translate \= "NULLS" then do
        out["error"] = self~sqlFailure("Invalid ORDER BY modifier")
        return out
      end
      if wi + 1 > words~items then do
        out["error"] = self~sqlFailure("NULLS requires FIRST or LAST")
        return out
      end
      nullOrdering = words[wi + 1]~translate
      if nullOrdering \= "FIRST" & nullOrdering \= "LAST" then do
        out["error"] = self~sqlFailure("NULLS requires FIRST or LAST")
        return out
      end
      wi += 2
    end
    if wi <= words~items then do
      out["error"] = self~sqlUnsupported("ORDER BY expressions are not implemented")
      return out
    end

    resolvedName = words[1]
    if rows~items > 0 then do
      if \rows[1]~values~hasIndex(resolvedName) then do
        found = ""
        do key over rows[1]~values~allIndexes
          candidate = key~string
          dot = candidate~lastPos(".")
          if dot > 0 then suffix = candidate~substr(dot + 1)
          else suffix = candidate
          if suffix~caselessEquals(resolvedName) then do
            if found \= "" then do
              out["error"] = self~sqlUnsupported("ORDER BY column is ambiguous: " || resolvedName)
              return out
            end
            found = candidate
          end
        end
        if found = "" then do
          out["error"] = self~sqlUnsupported("ORDER BY currently requires a projected column: " || resolvedName)
          return out
        end
        resolvedName = found
      end
    end

    spec = .table~new
    spec["column"] = resolvedName
    spec["direction"] = direction
    spec["nullOrdering"] = nullOrdering
    specs~append(spec)
  end
  out["specs"] = specs
  return out

::method compareOrderRows private
  use arg leftRow, rightRow, specs
  -- Compatibility: callers such as FETCH WITH TIES may still pass the textual
  -- ORDER BY clause. Compile it once for this comparison boundary.
  if \specs~isA(.array) then do
    rows = .array~new
    rows~append(leftRow)
    rows~append(rightRow)
    compiled = self~compileOrderSpecs(specs, rows)
    if compiled["error"] \== .nil then return 0
    specs = compiled["specs"]
  end
  return self~compareCompiledOrderRows(leftRow, rightRow, specs)

::method compareCompiledOrderRows private
  use arg leftRow, rightRow, specs
  do spec over specs
    column = spec["column"]
    direction = spec["direction"]
    nullOrdering = spec["nullOrdering"]

    lv = leftRow[column]
    rv = rightRow[column]
    cmp = 0
    explicitNullComparison = .false

    if lv == .nil then do
      if rv \== .nil then do
        if nullOrdering = "LAST" then cmp = 1
        else cmp = -1
        explicitNullComparison = nullOrdering \= ""
      end
    end
    else if rv == .nil then do
      if nullOrdering = "LAST" then cmp = -1
      else cmp = 1
      explicitNullComparison = nullOrdering \= ""
    end
    else do
      if .NoSQLUnicodeSupport~isUnicodeValue(lv) then cmp = .NoSQLUnicodeSupport~compareValues(lv, rv)
      else if .NoSQLUnicodeSupport~isUnicodeValue(rv) then cmp = .NoSQLUnicodeSupport~compareValues(lv, rv)
      else do
      ls = lv~string
      rs = rv~string
      if datatype(ls, "N") & datatype(rs, "N") then do
        if ls < rs then cmp = -1
        else if ls > rs then cmp = 1
      end
      else do
        if ls < rs then cmp = -1
        else if ls > rs then cmp = 1
      end
      end
    end

    if direction = "DESC" & \explicitNullComparison then cmp = 0 - cmp
    if cmp \= 0 then return cmp
  end
  return 0

::method mergeSortRows private
  use arg rows, specs
  if rows~items < 2 then return rows
  width = 1
  source = rows
  do while width < source~items
    target = .array~new
    startAt = 1
    do while startAt <= source~items
      left = startAt
      leftEnd = left + width - 1
      if leftEnd > source~items then leftEnd = source~items
      right = leftEnd + 1
      rightEnd = right + width - 1
      if rightEnd > source~items then rightEnd = source~items
      li = left
      ri = right
      do while li <= leftEnd | ri <= rightEnd
        if li > leftEnd then do
          target~append(source[ri])
          ri += 1
        end
        else if ri > rightEnd then do
          target~append(source[li])
          li += 1
        end
        else if self~compareCompiledOrderRows(source[li], source[ri], specs) <= 0 then do
          target~append(source[li])
          li += 1
        end
        else do
          target~append(source[ri])
          ri += 1
        end
      end
      startAt += width * 2
    end
    source = target
    width *= 2
  end
  return source

::method boundedTopRows private
  use arg rows, specs, bound
  if bound <= 0 then return .array~new
  heap = .array~new
  sequence = 0

  do row over rows
    sequence += 1
    entry = .table~new
    entry["row"] = row
    entry["sequence"] = sequence

    if heap~items < bound then do
      heap~append(entry)
      self~heapSiftUpWorst(heap, heap~items, specs)
    end
    else if self~compareOrderEntries(entry, heap[1], specs) < 0 then do
      heap[1] = entry
      self~heapSiftDownWorst(heap, 1, specs)
    end
  end

  entries = self~mergeSortEntries(heap, specs)
  out = .array~new
  do entry over entries
    out~append(entry["row"])
  end
  return out

::method compareOrderEntries private
  use arg leftEntry, rightEntry, specs
  cmp = self~compareCompiledOrderRows(leftEntry["row"], rightEntry["row"], specs)
  if cmp \= 0 then return cmp
  if leftEntry["sequence"] < rightEntry["sequence"] then return -1
  if leftEntry["sequence"] > rightEntry["sequence"] then return 1
  return 0

::method heapSiftUpWorst private
  use arg heap, pos, specs
  do while pos > 1
    parent = trunc(pos / 2)
    if self~compareOrderEntries(heap[pos], heap[parent], specs) <= 0 then leave
    tmp = heap[parent]
    heap[parent] = heap[pos]
    heap[pos] = tmp
    pos = parent
  end

::method heapSiftDownWorst private
  use arg heap, pos, specs
  count = heap~items
  do forever
    left = pos * 2
    if left > count then leave
    right = left + 1
    worst = left
    if right <= count then do
      if self~compareOrderEntries(heap[right], heap[left], specs) > 0 then worst = right
    end
    if self~compareOrderEntries(heap[worst], heap[pos], specs) <= 0 then leave
    tmp = heap[pos]
    heap[pos] = heap[worst]
    heap[worst] = tmp
    pos = worst
  end

::method mergeSortEntries private
  use arg entries, specs
  if entries~items < 2 then return entries
  width = 1
  source = entries
  do while width < source~items
    target = .array~new
    startAt = 1
    do while startAt <= source~items
      left = startAt
      leftEnd = left + width - 1
      if leftEnd > source~items then leftEnd = source~items
      right = leftEnd + 1
      rightEnd = right + width - 1
      if rightEnd > source~items then rightEnd = source~items
      li = left
      ri = right
      do while li <= leftEnd | ri <= rightEnd
        if li > leftEnd then do
          target~append(source[ri]); ri += 1
        end
        else if ri > rightEnd then do
          target~append(source[li]); li += 1
        end
        else if self~compareOrderEntries(source[li], source[ri], specs) <= 0 then do
          target~append(source[li]); li += 1
        end
        else do
          target~append(source[ri]); ri += 1
        end
      end
      startAt += width * 2
    end
    source = target
    width *= 2
  end
  return source

::method parseTableRef private
  use arg text
  words = text~space~makeArray(" ")
  if words~items = 1 then do
    out = .table~new
    out["table"] = words[1]
    out["alias"] = words[1]
    return out
  end
  if words~items = 2 then do
    out = .table~new
    out["table"] = words[1]
    out["alias"] = words[2]
    return out
  end
  if words~items = 3 then do
    if words[2]~translate \= "AS" then return .nil
    out = .table~new
    out["table"] = words[1]
    out["alias"] = words[3]
    return out
  end
  return .nil

::method normalizeSinglePredicate private
  use arg predicate, relation
  if predicate~isA(.SQLComparisonPredicate) then do
    resolved = relation~resolve(predicate~column)
    if resolved == .nil then return .false
    predicate~column = resolved["sourceColumn"]
    return .true
  end
  if predicate~isA(.SQLNullPredicate) then do
    resolved = relation~resolve(predicate~column)
    if resolved == .nil then return .false
    predicate~column = resolved["sourceColumn"]
    return .true
  end
  if predicate~isA(.SQLExpressionComparisonPredicate) then do
    if \self~normalizeValueExpression(predicate~leftExpression, relation) then return .false
    return self~normalizeValueExpression(predicate~rightExpression, relation)
  end
  if predicate~isA(.SQLLikePredicate) then do
    if \self~normalizeValueExpression(predicate~valueExpression, relation) then return .false
    return self~normalizeValueExpression(predicate~patternExpression, relation)
  end
  if predicate~isA(.SQLBetweenPredicate) then do
    if \self~normalizeValueExpression(predicate~valueExpression, relation) then return .false
    if \self~normalizeValueExpression(predicate~lowExpression, relation) then return .false
    return self~normalizeValueExpression(predicate~highExpression, relation)
  end
  if predicate~isA(.SQLLogicalPredicate) then do
    if \self~normalizeSinglePredicate(predicate~left, relation) then return .false
    return self~normalizeSinglePredicate(predicate~right, relation)
  end
  if predicate~isA(.SQLNotPredicate) then return self~normalizeSinglePredicate(predicate~child, relation)
  return .false

::method normalizeValueExpression private
  use arg expression, relation
  if expression~isA(.SQLLiteralValueExpression) then return .true
  if expression~isA(.SQLColumnValueExpression) then do
    resolved = relation~resolve(expression~reference)
    if resolved == .nil then return .false
    expression~reference = resolved["sourceColumn"]
    return .true
  end
  if expression~isA(.SQLFunctionValueExpression) then do
    do child over expression~arguments
      if \self~normalizeValueExpression(child, relation) then return .false
    end
    return .true
  end
  if expression~isA(.SQLCastValueExpression) then return self~normalizeValueExpression(expression~child, relation)
  if expression~isA(.SQLConcatValueExpression) then do
    if \self~normalizeValueExpression(expression~left, relation) then return .false
    return self~normalizeValueExpression(expression~right, relation)
  end
  return .false

::method simpleJoinPrefilter private
  use arg predicate, relation
  if \predicate~isA(.SQLComparisonPredicate) then return .nil
  if predicate~operator \= "=" then return .nil
  resolved = relation~resolve(predicate~column)
  if resolved == .nil then return .nil
  sidePredicate = .SQLComparisonPredicate~new(resolved["sourceColumn"], predicate~operator, predicate~value)
  out = .table~new
  out["side"] = resolved["side"]
  out["predicate"] = sidePredicate
  return out

::method projectionHasTopLevelAggregate private
  use arg projection
  do itemText over self~splitList(projection)
    parsed = self~parseProjectionSpec(itemText)
    if parsed == .nil then iterate
    expression = parsed["expression"]~strip
    upper = expression~translate
    if upper~startsWith("(SELECT ") then iterate
    do fn over "COUNT SUM AVG MIN MAX"~makeArray(" ")
      if upper~startsWith(fn || "(") then return .true
    end
    if upper~startsWith("COALESCE(") then do
      open = expression~pos("(")
      if open > 0 then do
        if self~matchingParen(expression, open) = expression~length then do
          args = self~splitList(expression~substr(open + 1, expression~length - open - 1))
          if args~items >= 2 then do
            firstArg = args[1]~strip~translate
            do fn over "COUNT SUM AVG MIN MAX"~makeArray(" ")
              if firstArg~startsWith(fn || "(") then return .true
            end
          end
        end
      end
    end
  end
  return .false

::method executeDerivedSelect private
  use arg projection, rest, orderBy = "", distinct = .false
  text = rest~strip
  closePos = self~matchingParen(text, 1)
  if closePos = 0 then return .nil
  tail = text~substr(closePos + 1)~strip
  whereText = ""
  wherePos = tail~translate~pos(" WHERE ")
  if wherePos > 0 then do
    whereText = tail~substr(wherePos + 7)~strip
    aliasText = tail~left(wherePos - 1)~strip
  end
  else aliasText = tail
  sourceText = text~left(closePos) || " " || aliasText
  source = self~buildDerivedAggregateSource(sourceText)
  if source == .nil then return .nil
  relation = source["relation"]
  rows = source["rows"]
  if whereText \= "" then do
    expressionComparison = self~splitTopLevelComparison(whereText)
    usedExpressionComparison = .false
    if expressionComparison \== .nil then do
      -- Derived relations may legitimately filter on arithmetic over projected
      -- window values, e.g. rn = (n + 1) / 2.  Evaluate both operands through
      -- the established scalar-expression engine before falling back to the
      -- token predicate parser.
      canEvaluate = .true
      if rows~items > 0 then do
        leftProbe = self~evaluateProjectionExpression(expressionComparison["left"], rows[1], relation)
        rightProbe = self~evaluateProjectionExpression(expressionComparison["right"], rows[1], relation)
        if \leftProbe["ok"] | \rightProbe["ok"] then canEvaluate = .false
      end
      if canEvaluate then do
        filtered = .array~new
        do row over rows
          leftValue = self~evaluateProjectionExpression(expressionComparison["left"], row, relation)
          rightValue = self~evaluateProjectionExpression(expressionComparison["right"], row, relation)
          if \leftValue["ok"] | \rightValue["ok"] then do
            canEvaluate = .false
            leave
          end
          lv = leftValue["value"]; rv = rightValue["value"]
          match = .false
          if lv \== .nil & rv \== .nil then do
            cmp = self~compareScalarValues(lv, rv)
            select
              when expressionComparison["operator"] = "=" then match = cmp = 0
              when expressionComparison["operator"] = "<>" | expressionComparison["operator"] = "!=" then match = cmp \= 0
              when expressionComparison["operator"] = ">" then match = cmp > 0
              when expressionComparison["operator"] = ">=" then match = cmp >= 0
              when expressionComparison["operator"] = "<" then match = cmp < 0
              when expressionComparison["operator"] = "<=" then match = cmp <= 0
              otherwise canEvaluate = .false
            end
          end
          if \canEvaluate then leave
          if match then filtered~append(row)
        end
        if canEvaluate then do
          rows = filtered
          usedExpressionComparison = .true
        end
      end
    end

    if \usedExpressionComparison then do
      predicate = .SQLPredicateParser~new~parse(whereText)
      if predicate == .nil then return self~sqlParseFailure("Invalid derived WHERE predicate")
      if \self~normalizeSinglePredicate(predicate, relation) then return self~sqlParseFailure("Unknown or ambiguous derived WHERE column")
      filtered = .array~new
      do row over rows
        if predicate~evaluate(row, relation) then filtered~append(row)
      end
      rows = filtered
    end
  end
  resultSet = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  resultSet~rows = rows
  resultSet~affectedRows = rows~items
  resultSet~rowsScanned = source["rowsScanned"]
  resultSet~accessPath = "DERIVED_" || source["accessPath"]
  if orderBy \= "" then do
    ordered = self~applyExpressionOrderBy(resultSet, orderBy, relation)
    if ordered~status \= .Error~SUCCESS then return ordered
    resultSet = ordered
  end
  resultSet = self~applyProjection(resultSet, projection, relation)
  if resultSet~status \= .Error~SUCCESS then return resultSet
  if distinct then resultSet = self~applyDistinct(resultSet)
  return resultSet

::method makeOlapGroupDescriptor private
  use arg item, relation
  groupItem = item~strip
  resolved = relation~resolve(groupItem)
  if resolved == .nil then return .nil
  grp = .table~new
  grp["kind"] = "COLUMN"
  grp["resolved"] = resolved
  grp["expression"] = groupItem
  return grp

::method parseOlapGroupingSets private
  use arg groupText, relation
  text = groupText~strip
  upper = text~translate
  sets = .array~new

  if upper~startsWith("GROUPING SETS") then do
    tail = text~substr(14)~strip
    if tail~left(1) \= "(" then return .nil
    close = self~matchingParen(tail, 1)
    if close \= tail~length then return .nil
    body = tail~substr(2, close - 2)
    do member over self~splitList(body)
      member = member~strip
      if member~left(1) \= "(" then return .nil
      mclose = self~matchingParen(member, 1)
      if mclose \= member~length then return .nil
      inside = member~substr(2, mclose - 2)~strip
      one = .array~new
      if inside \= "" then do
        do item over self~splitList(inside)
          grp = self~makeOlapGroupDescriptor(item, relation)
          if grp == .nil then return .nil
          one~append(grp)
        end
      end
      sets~append(one)
    end
    return sets
  end

  if upper~startsWith("ROLLUP") | upper~startsWith("CUBE") then do
    isCube = upper~startsWith("CUBE")
    if isCube then tail = text~substr(5)~strip
    else tail = text~substr(7)~strip
    if tail~left(1) \= "(" then return .nil
    close = self~matchingParen(tail, 1)
    if close \= tail~length then return .nil
    inside = tail~substr(2, close - 2)~strip
    dimensions = .array~new
    if inside \= "" then do
      do item over self~splitList(inside)
        grp = self~makeOlapGroupDescriptor(item, relation)
        if grp == .nil then return .nil
        dimensions~append(grp)
      end
    end

    if isCube then do
      count = dimensions~items
      combinations = 2 ** count
      do mask = combinations - 1 to 0 by -1
        one = .array~new
        do i = 1 to count
          bit = 2 ** (count - i)
          if mask // (bit * 2) >= bit then one~append(dimensions[i])
        end
        sets~append(one)
      end
    end
    else do
      do keep = dimensions~items to 0 by -1
        one = .array~new
        do i = 1 to keep
          one~append(dimensions[i])
        end
        sets~append(one)
      end
    end
    return sets
  end

  return .nil

::method olapSetContains private
  use arg groupingSet, spec
  do grp over groupingSet
    if spec["kind"] = "COLUMN" then do
      if grp["resolved"]["physicalName"]~caselessEquals(spec["resolved"]["physicalName"]) then return .true
    end
    else if grp["expression"]~space~caselessEquals(spec["expression"]~space) then return .true
  end
  return .false

::method executeOlapGroupingSelect private
  use arg specs, groupingSets, filteredRows, relation, havingText, orderBy, scanned, sourceAccessPath, distinct = .false

  -- Validate that every non-aggregate projection is one of the OLAP dimensions.
  do spec over specs
    if spec["kind"] = "COLUMN" | spec["kind"] = "EXPRESSION" then do
      known = .false
      do groupingSet over groupingSets
        if self~olapSetContains(groupingSet, spec) then do
          known = .true
          leave
        end
      end
      if \known then return self~sqlParseFailure("Projected expression is not in GROUPING SETS/ROLLUP/CUBE: " || spec["expression"])
    end
  end

  outRows = .array~new

  do groupingSet over groupingSets
    groups = .table~new
    groupOrder = .array~new

    if groupingSet~items = 0 then do
      groups["__ALL__"] = filteredRows
      groupOrder~append("__ALL__")
    end
    else do
      do row over filteredRows
        key = self~aggregateGroupKey(row, groupingSet)
        bucket = groups[key]
        if bucket == .nil then do
          bucket = .array~new
          groups[key] = bucket
          groupOrder~append(key)
        end
        bucket~append(row)
      end
    end

    do key over groupOrder
      bucket = groups[key]
      if havingText \= "" then do
        havingOk = self~evaluateHavingPredicate(havingText, bucket, relation)
        if havingOk == .nil then return self~sqlUnsupported("HAVING expression is outside the supported OLAP aggregate surface")
        if \havingOk then iterate
      end

      values = .table~new
      do spec over specs
        outputName = spec["alias"]
        if outputName = "" then outputName = spec["display"]

        if spec["kind"] = "COLUMN" then do
          if \self~olapSetContains(groupingSet, spec) then values[outputName] = .nil
          else if bucket~items = 0 then values[outputName] = .nil
          else values[outputName] = bucket[1][spec["resolved"]["physicalName"]]
        end
        else if spec["kind"] = "EXPRESSION" then do
          if \self~olapSetContains(groupingSet, spec) then values[outputName] = .nil
          else if bucket~items = 0 then values[outputName] = .nil
          else do
            evaluated = self~evaluateProjectionExpression(spec["expression"], bucket[1], spec["relation"])
            if \evaluated["ok"] then return self~sqlUnsupported("Grouped projection expression is not implemented: " || spec["expression"])
            values[outputName] = evaluated["value"]
          end
        end
        else if spec["kind"] = "LITERAL" then values[outputName] = spec["value"]
        else if spec["kind"] = "AGG_EXPRESSION" then do
          evaluated = self~evaluateAggregateExpression(spec["expression"], bucket, spec["relation"])
          if evaluated == .nil | \evaluated["ok"] then return self~sqlUnsupported("Aggregate expression is not implemented: " || spec["expression"])
          values[outputName] = evaluated["value"]
        end
        else do
          aggregateOutput = self~aggregateValue(spec, bucket)
          if aggregateOutput == .nil then do
            if spec["coalesce"] == .true then aggregateOutput = spec["coalesceFallback"]
          end
          values[outputName] = aggregateOutput
        end
      end
      outRows~append(.DatabaseRow~new(values))
    end
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = outRows
  rs~affectedRows = outRows~items
  rs~rowsScanned = scanned
  rs~accessPath = "OLAP_GROUPING_" || sourceAccessPath
  if distinct then rs = self~applyDistinct(rs)
  return self~applyOrderBy(rs, orderBy)

::method executeAggregateSelect private
  use arg projection, rest, distinct = .false
  hasAggregate = self~projectionHasTopLevelAggregate(projection)
  restUpper = rest~translate
  groupPos = self~findTopLevelKeyword(rest, " GROUP BY ")
  if \hasAggregate then do
    if groupPos = 0 then return .nil
    -- SQL permits grouped queries whose projection contains grouped columns
    -- or literals without an aggregate.  This is especially useful inside
    -- EXISTS where only row existence matters.
  end

  orderBy = ""
  orderPos = self~findTopLevelKeyword(rest, " ORDER BY ")
  if orderPos > 0 then do
    orderBy = rest~substr(orderPos + 10)~strip
    rest = rest~left(orderPos - 1)~strip
  end

  havingText = ""
  havingPos = self~findTopLevelKeyword(rest, " HAVING ")
  if havingPos > 0 then do
    havingText = rest~substr(havingPos + 8)~strip
    rest = rest~left(havingPos - 1)~strip
  end

  groupText = ""
  groupPos = self~findTopLevelKeyword(rest, " GROUP BY ")
  if groupPos > 0 then do
    groupText = rest~substr(groupPos + 10)~strip
    rest = rest~left(groupPos - 1)~strip
  end

  whereText = ""
  wherePos = self~findTopLevelKeyword(rest, " WHERE ")
  if wherePos > 0 then do
    whereText = rest~substr(wherePos + 7)~strip
    rest = rest~left(wherePos - 1)~strip
  end

  source = self~buildAggregateSource(rest)
  if source == .nil then return self~sqlUnsupported("Aggregate FROM source is not implemented")
  relation = source["relation"]
  baseRows = source["rows"]
  scanned = source["rowsScanned"]

  specs = self~parseAggregateProjection(projection, relation)
  if specs == .nil then return self~sqlUnsupported("Aggregate projection is outside the supported aggregate surface")

  groupColumns = .array~new
  if groupText \= "" then do
    do item over self~splitList(groupText)
      groupItem = item~strip
      resolved = relation~resolve(groupItem)
      grp = .table~new
      if resolved \== .nil then do
        grp["kind"] = "COLUMN"
        grp["resolved"] = resolved
        grp["expression"] = groupItem
      end
      else do
        -- GROUP BY expressions use the same scalar evaluator as projection.
        -- Syntax is validated against an actual source row below where possible.
        grp["kind"] = "EXPRESSION"
        grp["resolved"] = .nil
        grp["expression"] = groupItem
        grp["relation"] = relation
      end
      groupColumns~append(grp)
    end
  end

  isOlapGrouping = .false
  groupUpper = groupText~strip~translate
  if groupUpper~startsWith("GROUPING SETS") | groupUpper~startsWith("ROLLUP") | groupUpper~startsWith("CUBE") then isOlapGrouping = .true

  if \isOlapGrouping then do
    do spec over specs
      if spec["kind"] = "COLUMN" | spec["kind"] = "EXPRESSION" then do
        if groupColumns~items = 0 then return self~sqlParseFailure("Non-aggregate projection requires GROUP BY")
        matched = .false
        do grp over groupColumns
          if spec["kind"] = "COLUMN" & grp["kind"] = "COLUMN" then do
            if grp["resolved"]["physicalName"]~caselessEquals(spec["resolved"]["physicalName"]) then matched = .true
          end
          else if grp["expression"]~space~caselessEquals(spec["expression"]~space) then matched = .true
        end
        if \matched & spec["kind"] = "EXPRESSION" then matched = self~expressionUsesOnlyGroupColumns(spec["expression"], groupColumns, relation)
        if \matched then return self~sqlParseFailure("Projected expression is not in GROUP BY: " || spec["expression"])
      end
    end
  end

  filteredRows = baseRows
  if whereText \= "" then do
    filteredRows = .array~new
    if self~findScalarSubqueryOpen(whereText) > 0 then do
      do row over baseRows
        expanded = self~bindScalarSubqueries(whereText, row, relation)
        if expanded == .nil then return self~sqlUnsupported("Correlated scalar subquery in WHERE could not be evaluated")
        predicate = .SQLPredicateParser~new~parse(expanded)
        if predicate == .nil then return self~sqlParseFailure("Invalid aggregate WHERE predicate")
        if predicate~evaluate(row, relation) then filteredRows~append(row)
      end
    end
    else do
      predicate = .SQLPredicateParser~new~parse(whereText)
      if predicate == .nil then return self~sqlParseFailure("Invalid aggregate WHERE predicate")
      do row over baseRows
        if predicate~evaluate(row, relation) then filteredRows~append(row)
      end
    end
  end

  olapGroupingSets = .nil
  groupUpper = groupText~strip~translate
  if groupUpper~startsWith("GROUPING SETS") | groupUpper~startsWith("ROLLUP") | groupUpper~startsWith("CUBE") then do
    olapGroupingSets = self~parseOlapGroupingSets(groupText, relation)
    if olapGroupingSets == .nil then return self~sqlParseFailure("Invalid GROUPING SETS/ROLLUP/CUBE clause")
    return self~executeOlapGroupingSelect(specs, olapGroupingSets, filteredRows, relation, havingText, orderBy, scanned, source["accessPath"], distinct)
  end

  groups = .table~new
  order = .array~new
  if groupColumns~items = 0 then do
    groups["__ALL__"] = filteredRows
    order~append("__ALL__")
  end
  else do
    do row over filteredRows
      key = self~aggregateGroupKey(row, groupColumns)
      bucket = groups[key]
      if bucket == .nil then do
        bucket = .array~new
        groups[key] = bucket
        order~append(key)
      end
      bucket~append(row)
    end
  end

  outRows = .array~new
  if groupColumns~items = 0 then do
    if groups["__ALL__"] == .nil then groups["__ALL__"] = .array~new
  end
  do key over order
    bucket = groups[key]
    if havingText \= "" then do
      havingOk = self~evaluateHavingPredicate(havingText, bucket, relation)
      if havingOk == .nil then return self~sqlUnsupported("HAVING expression is outside the supported aggregate surface")
      if \havingOk then iterate
    end
    values = .table~new
    do spec over specs
      outputName = spec["alias"]
      if outputName = "" then outputName = spec["display"]
      if spec["kind"] = "COLUMN" then do
        if bucket~items = 0 then values[outputName] = .nil
        else values[outputName] = bucket[1][spec["resolved"]["physicalName"]]
      end
      else if spec["kind"] = "EXPRESSION" then do
        if bucket~items = 0 then values[outputName] = .nil
        else do
          evaluated = self~evaluateProjectionExpression(spec["expression"], bucket[1], spec["relation"])
          if \evaluated["ok"] then return self~sqlUnsupported("Grouped projection expression is not implemented: " || spec["expression"])
          values[outputName] = evaluated["value"]
        end
      end
      else if spec["kind"] = "LITERAL" then values[outputName] = spec["value"]
      else if spec["kind"] = "AGG_EXPRESSION" then do
        evaluated = self~evaluateAggregateExpression(spec["expression"], bucket, spec["relation"])
        if evaluated == .nil | \evaluated["ok"] then return self~sqlUnsupported("Aggregate expression is not implemented: " || spec["expression"])
        values[outputName] = evaluated["value"]
      end
      else do
        aggregateOutput = self~aggregateValue(spec, bucket)
        if aggregateOutput == .nil then do
          if spec["coalesce"] == .true then aggregateOutput = spec["coalesceFallback"]
        end
        values[outputName] = aggregateOutput
      end
    end
    outRows~append(.DatabaseRow~new(values))
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = outRows
  rs~affectedRows = outRows~items
  rs~rowsScanned = scanned
  rs~accessPath = "AGGREGATE_" || source["accessPath"]
  if distinct then rs = self~applyDistinct(rs)
  return self~applyOrderBy(rs, orderBy)

::method buildAggregateSource private
  use arg sourceText
  text = sourceText~strip
  if text~left(1) = "(" then return self~buildDerivedAggregateSource(text)
  upper = " " || text~translate || " "
  if upper~pos(" LEFT JOIN ") > 0 then return self~buildLeftJoinAggregateSource(text)
  if upper~pos(" JOIN ") > 0 then return self~buildInnerJoinAggregateSource(text)
  ref = self~parseTableRef(text)
  if ref == .nil then return .nil
  obj = self~engine~table(ref["table"])
  if obj == .nil then return .nil
  relation = .SQLRelationDefinition~new(obj~definition, ref["alias"])
  rows = obj~readRows
  out = .table~new
  out["relation"] = relation
  out["rows"] = rows
  out["rowsScanned"] = rows~items
  out["accessPath"] = "TABLE_SCAN"
  return out

::method buildLeftJoinAggregateSource private
  use arg joinText
  firstPos = joinText~translate~pos(" LEFT JOIN ")
  if firstPos = 0 then return .nil
  baseRef = self~parseTableRef(joinText~left(firstPos - 1)~strip)
  if baseRef == .nil then return .nil
  baseObj = self~engine~table(baseRef["table"])
  if baseObj == .nil then return .nil
  entries = .array~new
  baseEntry = .table~new
  baseEntry["table"] = baseObj; baseEntry["definition"] = baseObj~definition; baseEntry["alias"] = baseRef["alias"]
  entries~append(baseEntry)
  joinSpecs = .array~new
  cursor = firstPos
  do while cursor > 0
    segmentStart = cursor + 11
    remaining = joinText~substr(segmentStart)~strip
    nextRel = remaining~translate~pos(" LEFT JOIN ")
    if nextRel > 0 then segment = remaining~left(nextRel - 1)~strip
    else segment = remaining
    onPos = segment~translate~pos(" ON ")
    if onPos = 0 then return .nil
    rightRef = self~parseTableRef(segment~left(onPos - 1)~strip)
    if rightRef == .nil then return .nil
    rightObj = self~engine~table(rightRef["table"])
    if rightObj == .nil then return .nil
    spec = .table~new
    spec["onText"] = segment~substr(onPos + 4)~strip
    spec["entry"] = .table~new
    spec["entry"]["table"] = rightObj; spec["entry"]["definition"] = rightObj~definition; spec["entry"]["alias"] = rightRef["alias"]
    entries~append(spec["entry"]); joinSpecs~append(spec)
    if nextRel = 0 then leave
    cursor = segmentStart - 1 + nextRel
  end
  relation = .SQLAliasRelationDefinition~new(entries)
  rows = .array~new
  baseRows = baseObj~readRows
  do rawRow over baseRows; rows~append(self~qualifiedAliasRow(baseEntry, rawRow)); end
  scanned = baseRows~items
  joinedAliases = .table~new; joinedAliases[baseEntry["alias"]~translate] = .true
  do spec over joinSpecs
    entry = spec["entry"]
    onPredicate = .SQLPredicateParser~new~parse(spec["onText"])
    connector = self~findAliasJoinConnector(onPredicate, relation, entry["alias"], joinedAliases)
    if connector == .nil then return .nil
    rightRows = entry["table"]~readRows; scanned += rightRows~items
    rows = self~extendByLeftPredicateJoin(rows, entry, rightRows, connector, onPredicate, relation)
    joinedAliases[entry["alias"]~translate] = .true
  end
  out = .table~new
  out["relation"] = relation; out["rows"] = rows; out["rowsScanned"] = scanned; out["accessPath"] = "LEFT_HASH_CHAIN"
  return out

::method buildInnerJoinAggregateSource private
  use arg joinText
  firstPos = joinText~translate~pos(" JOIN ")
  if firstPos = 0 then return .nil
  baseRef = self~parseTableRef(joinText~left(firstPos - 1)~strip)
  if baseRef == .nil then return .nil
  baseObj = self~engine~table(baseRef["table"])
  if baseObj == .nil then return .nil
  entries = .array~new
  baseEntry = .table~new
  baseEntry["table"] = baseObj
  baseEntry["definition"] = baseObj~definition
  baseEntry["alias"] = baseRef["alias"]
  entries~append(baseEntry)
  joinSpecs = .array~new
  cursor = firstPos
  do while cursor > 0
    segmentStart = cursor + 6
    remaining = joinText~substr(segmentStart)~strip
    nextRel = remaining~translate~pos(" JOIN ")
    if nextRel > 0 then segment = remaining~left(nextRel - 1)~strip
    else segment = remaining
    onPos = segment~translate~pos(" ON ")
    if onPos = 0 then return .nil
    rightRef = self~parseTableRef(segment~left(onPos - 1)~strip)
    if rightRef == .nil then return .nil
    rightObj = self~engine~table(rightRef["table"])
    if rightObj == .nil then return .nil
    spec = .table~new
    spec["onText"] = segment~substr(onPos + 4)~strip
    spec["entry"] = .table~new
    spec["entry"]["table"] = rightObj
    spec["entry"]["definition"] = rightObj~definition
    spec["entry"]["alias"] = rightRef["alias"]
    entries~append(spec["entry"])
    joinSpecs~append(spec)
    if nextRel = 0 then leave
    cursor = segmentStart - 1 + nextRel
  end
  relation = .SQLAliasRelationDefinition~new(entries)
  rows = .array~new
  baseRows = baseObj~readRows
  do rawRow over baseRows
    rows~append(self~qualifiedAliasRow(baseEntry, rawRow))
  end
  scanned = baseRows~items
  joinedAliases = .table~new
  joinedAliases[baseEntry["alias"]~translate] = .true
  do spec over joinSpecs
    entry = spec["entry"]
    onPredicate = .SQLPredicateParser~new~parse(spec["onText"])
    connector = self~findAliasJoinConnector(onPredicate, relation, entry["alias"], joinedAliases)
    if connector == .nil then return .nil
    rightRows = entry["table"]~readRows
    scanned += rightRows~items
    rows = self~extendByInnerPredicateJoin(rows, entry, rightRows, connector, onPredicate, relation)
    joinedAliases[entry["alias"]~translate] = .true
  end
  out = .table~new
  out["relation"] = relation
  out["rows"] = rows
  out["rowsScanned"] = scanned
  out["accessPath"] = "INNER_HASH_CHAIN"
  return out

::method buildDerivedAggregateSource private
  use arg text
  closePos = self~matchingParen(text, 1)
  if closePos = 0 then return .nil
  inner = text~substr(2, closePos - 2)~strip
  alias = text~substr(closePos + 1)~strip
  if alias = "" then return .nil
  if alias~words > 1 then return .nil
  if self~hasTopLevelUnion(inner) then subRs = self~executeUnionSelect(inner)
  else subRs = self~executeSelect(inner)
  if subRs~status \= .Error~SUCCESS then return .nil
  names = .array~new
  sourceNames = .array~new

  -- Derived-table column names are the SELECT output names, not the internal
  -- qualified source keys.  `SELECT e.full_name` therefore exposes
  -- `full_name` to the outer query unless an explicit alias says otherwise.
  fromPos = self~findTopLevelKeyword(inner, " FROM ")
  if fromPos > 0 then do
    proj = inner~substr(8, fromPos - 8)~strip
    if proj \= "*" then do
      do item over self~splitList(proj)
        spec = self~parseProjectionSpec(item)
        if spec == .nil then return .nil
        sourceName = spec["alias"]
        if sourceName = "" then sourceName = spec["expression"]
        outputName = spec["alias"]
        if outputName = "" then do
          outputName = spec["expression"]~strip
          dot = outputName~lastPos(".")
          if dot > 0 & outputName~pos("(") = 0 & outputName~pos(" ") = 0 then outputName = outputName~substr(dot + 1)
        end
        sourceNames~append(sourceName)
        names~append(outputName)
      end
    end
  end

  if names~items = 0 then do
    if subRs~rows~items = 0 then return .nil
    do name over subRs~rows[1]~values~allIndexes
      names~append(name)
      sourceNames~append(name)
    end
  end

  relation = .SQLDerivedRelationDefinition~new(alias, names)
  rows = .array~new
  do raw over subRs~rows
    vals = .table~new
    do i = 1 to names~items
      vals[alias || "." || names[i]] = raw[sourceNames[i]]
    end
    rows~append(.DatabaseRow~new(vals))
  end
  out = .table~new
  out["relation"] = relation
  out["rows"] = rows
  out["rowsScanned"] = subRs~rowsScanned
  out["accessPath"] = "DERIVED"
  return out

::method evaluateHavingPredicate private
  use arg text, bucket, relation
  andPos = self~findTopLevelKeyword(" " || text || " ", " AND ")
  if andPos > 0 then do
    padded = " " || text || " "
    leftText = padded~left(andPos - 1)~strip
    rightText = padded~substr(andPos + 5)~strip
    leftOk = self~evaluateHavingPredicate(leftText, bucket, relation)
    if leftOk == .nil then return .nil
    if \leftOk then return .false
    return self~evaluateHavingPredicate(rightText, bucket, relation)
  end
  parsed = self~splitTopLevelComparison(text)
  if parsed == .nil then return .nil
  left = self~evaluateAggregateOperand(parsed["left"], bucket, relation)
  if left == .nil then return .nil
  right = self~evaluateAggregateOperand(parsed["right"], bucket, relation)
  if right == .nil then return .nil
  lv = left["value"]
  rv = right["value"]
  if lv == .nil | rv == .nil then return .false
  op = parsed["operator"]
  if datatype(lv~string, "N") & datatype(rv~string, "N") then do
    select
      when op = ">" then return lv > rv
      when op = ">=" then return lv >= rv
      when op = "<" then return lv < rv
      when op = "<=" then return lv <= rv
      when op = "=" then return lv = rv
      when op = "<>" | op = "!=" then return lv \= rv
      otherwise return .nil
    end
  end
  select
    when op = "=" then return lv~string == rv~string
    when op = "<>" | op = "!=" then return lv~string \== rv~string
    otherwise return .nil
  end

::method evaluateAggregateOperand private
  use arg operand, bucket, relation
  text = operand~strip
  if text~left(1) = "(" then do
    close = self~matchingParen(text, 1)
    if close = text~length then do
      inner = text~substr(2, text~length - 2)~strip
      if inner~translate~startsWith("SELECT ") then do
        boundInner = inner
        if bucket~items > 0 then boundInner = self~bindOuterReferences(inner, bucket[1], relation)
        rs = self~executeSelect(boundInner)
        if rs~status \= .Error~SUCCESS then return .nil
        if rs~rows~items = 0 then value = .nil
        else do
          indexes = rs~rows[1]~values~allIndexes
          if indexes~items = 0 then value = .nil
          else value = rs~rows[1][indexes[1]]
        end
        out = .table~new; out["value"] = value; return out
      end
    end
  end
  -- HAVING operands are expressions, not projection specifications.  Add a
  -- synthetic alias so parseProjectionSpec cannot mistake the final token of
  -- FILTER (WHERE ...) for an implicit output alias.
  specs = self~parseAggregateProjection(text || " AS __having_operand", relation)
  if specs \== .nil then do
    if specs~items = 1 then do
      spec = specs[1]
      if spec["kind"] = "AGGREGATE" then do
        out = .table~new; out["value"] = self~aggregateValue(spec, bucket); return out
      end
    end
  end
  lit = self~literal(text)
  out = .table~new; out["value"] = lit; return out

::method evaluateAggregateExpression private
  use arg expression, bucket, relation
  text = expression~strip
  do forever
    upper = text~translate
    best = 0
    bestFn = ""
    do fn over "COUNT SUM AVG MIN MAX"~makeArray(" ")
      probe = fn || "("
      p = upper~pos(probe)
      if p > 0 then if best = 0 | p < best then do; best = p; bestFn = fn; end
    end
    if best = 0 then leave
    openPos = best + bestFn~length
    closePos = self~matchingParen(text, openPos)
    if closePos = 0 then return .nil
    callText = text~substr(best, closePos - best + 1)
    specs = self~parseAggregateProjection(callText, relation)
    if specs == .nil | specs~items \= 1 then return .nil
    spec = specs[1]
    if spec["kind"] \= "AGGREGATE" then return .nil
    value = self~aggregateValue(spec, bucket)
    literal = self~sqlLiteralForDynamicValue(value)
    text = text~left(best - 1) || literal || text~substr(closePos + 1)
  end
  row = .DatabaseRow~new(.table~new)
  return self~evaluateProjectionExpression(text, row, relation)

::method splitTopLevelComparison private
  use arg text
  ops = ">= <= <> != > < ="
  depth = 0
  quote = ""
  i = 1
  do while i <= text~length
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then quote = ""
      i += 1; iterate
    end
    if ch = "'" | ch = '"' then do; quote = ch; i += 1; iterate; end
    if ch = "(" then do; depth += 1; i += 1; iterate; end
    if ch = ")" then do; depth -= 1; i += 1; iterate; end
    if depth = 0 then do
      do op over ops~makeArray(" ")
        if text~substr(i, op~length) = op then do
          out = .table~new
          out["left"] = text~left(i - 1)~strip
          out["operator"] = op
          out["right"] = text~substr(i + op~length)~strip
          return out
        end
      end
    end
    i += 1
  end
  return .nil

::method parseAggregateProjection private
  use arg projection, relation
  specs = .array~new
  do itemText over self~splitList(projection)
    parsed = self~parseProjectionSpec(itemText)
    if parsed == .nil then return .nil
    expression = parsed["expression"]~strip
    upper = expression~translate
    spec = .table~new
    spec["alias"] = parsed["alias"]
    spec["expression"] = expression
    spec["display"] = expression
    spec["filterPredicate"] = .nil

    -- SQL aggregate FILTER is part of the aggregate invocation semantics:
    --   COUNT(*) FILTER (WHERE predicate)
    -- Parse and normalize the predicate once, then let aggregateValue apply it
    -- row-by-row before COUNT/SUM/AVG/MIN/MAX sees the bucket.
    filterPos = self~findTopLevelKeyword(expression, " FILTER ")
    if filterPos > 0 then do
      filterBase = expression~left(filterPos - 1)~strip
      filterTail = expression~substr(filterPos + 8)~strip
      if filterTail~left(1) \= "(" then return .nil
      if self~matchingParen(filterTail, 1) \= filterTail~length then return .nil
      filterBody = filterTail~substr(2, filterTail~length - 2)~strip
      if \filterBody~translate~startsWith("WHERE ") then return .nil
      filterWhere = filterBody~substr(7)~strip
      if filterWhere = "" then return .nil
      filterPredicate = .SQLPredicateParser~new~parse(filterWhere)
      if filterPredicate == .nil then return .nil
      if \self~normalizeSinglePredicate(filterPredicate, relation) then return .nil
      spec["filterPredicate"] = filterPredicate
      expression = filterBase
      upper = expression~translate
    end

    if upper~startsWith("COALESCE(") then do
      outerOpen = expression~pos("(")
      if outerOpen = 0 then return .nil
      if self~matchingParen(expression, outerOpen) \= expression~length then return .nil
      coalesceArgs = self~splitList(expression~substr(outerOpen + 1, expression~length - outerOpen - 1))
      if coalesceArgs~items \= 2 then return .nil
      innerSpecs = self~parseAggregateProjection(coalesceArgs[1], relation)
      if innerSpecs == .nil then return .nil
      if innerSpecs~items \= 1 then return .nil
      innerSpec = innerSpecs[1]
      if innerSpec["kind"] \= "AGGREGATE" then return .nil
      fallbackText = coalesceArgs[2]~strip
      fallbackValue = self~literal(fallbackText)
      if fallbackValue == .nil then do
        if fallbackText~translate \= "NULL" then return .nil
      end
      innerSpec["alias"] = parsed["alias"]
      innerSpec["expression"] = expression
      innerSpec["display"] = expression
      innerSpec["coalesce"] = .true
      innerSpec["coalesceFallback"] = fallbackValue
      specs~append(innerSpec)
      iterate
    end
    -- v0.31 aggregate arithmetic/function composition.
    aggArithmetic = self~findTopLevelArithmetic(expression, "/") > 0 | self~findTopLevelArithmetic(expression, "-") > 0 | ,
                    self~findTopLevelArithmetic(expression, "+") > 0 | self~findTopLevelArithmetic(expression, "*") > 0
    startsAggregate = .false
    do aggregateFn over "COUNT SUM AVG MIN MAX"~makeArray(" ")
      if upper~startsWith(aggregateFn || "(") then startsAggregate = .true
    end
    if startsAggregate & aggArithmetic | upper~startsWith("NULLIF(") then do
      spec["kind"] = "AGG_EXPRESSION"
      spec["relation"] = relation
      specs~append(spec)
      iterate
    end
    open = expression~pos("(")
    if open = 0 then do
      resolved = relation~resolve(expression)
      if resolved \== .nil then do
        spec["kind"] = "COLUMN"
        spec["resolved"] = resolved
        specs~append(spec)
        iterate
      end
      literalValue = self~literal(expression)
      literalUpper = expression~translate
      if literalValue \== .nil | literalUpper = "NULL" | literalUpper = "TRUE" | literalUpper = "FALSE" | datatype(expression, "N") then do
        spec["kind"] = "LITERAL"
        spec["value"] = literalValue
        specs~append(spec)
        iterate
      end
      if expression~length >= 2 then do
        if expression~left(1) = "'" & expression~right(1) = "'" then do
          spec["kind"] = "LITERAL"
          spec["value"] = literalValue
          specs~append(spec)
          iterate
        end
      end
      return .nil
    end
    if expression~right(1) \= ")" then return .nil
    fn = expression~left(open - 1)~strip~translate
    if wordpos(fn, "COUNT SUM AVG MIN MAX") = 0 then do
      if wordpos(fn, "UPPER LOWER SUBSTR") > 0 then do
        spec["kind"] = "EXPRESSION"
        spec["relation"] = relation
        specs~append(spec)
        iterate
      end
      return .nil
    end
    argText = expression~substr(open + 1, expression~length - open - 1)~strip
    spec["kind"] = "AGGREGATE"
    spec["function"] = fn
    if fn = "COUNT" then do
      spec["distinct"] = .false
      if argText~translate~startsWith("DISTINCT ") then do
        argText = argText~substr(10)~strip
        if argText = "" | argText = "*" then return .nil
        spec["distinct"] = .true
      end
      if argText = "*" then do
        spec["star"] = .true
        spec["resolved"] = .nil
      end
      else do
        resolved = relation~resolve(argText)
        if resolved == .nil then return .nil
        spec["star"] = .false
        spec["resolved"] = resolved
      end
    end
    else do
      if argText = "*" then return .nil
      resolved = relation~resolve(argText)
      if resolved == .nil then do
        -- v0.18: aggregate expressions are evaluated row-by-row.  This is
        -- deliberately expression-based rather than SQL-text interpolation.
        if fn \= "SUM" then do
          if fn \= "AVG" then return .nil
        end
        spec["resolved"] = .nil
        spec["expressionArg"] = argText
        spec["relation"] = relation
      end
      else do
        spec["resolved"] = resolved
        col = resolved["column"]
        if fn = "SUM" | fn = "AVG" then do
          if col~type \= "INTEGER" then do
            if col~type \= "DECIMAL" then do
              if col~type \= "UNKNOWN" then return .nil
            end
          end
        end
      end
      spec["star"] = .false
    end
    spec["relation"] = relation
    specs~append(spec)
  end
  return specs

::method expressionUsesOnlyGroupColumns private
  use arg expression, groupColumns, relation
  allowed = .table~new
  do grp over groupColumns
    if grp["kind"] = "COLUMN" then allowed[grp["resolved"]["physicalName"]~translate] = .true
  end
  text = expression
  do ch over "( ) , + - * / | = < >"~makeArray(" ")
    text = text~changeStr(ch, " ")
  end
  do token over text~space~makeArray(" ")
    candidate = token~strip
    if candidate = "" then iterate
    if candidate~left(1) = "'" | candidate~left(1) = '"' then iterate
    resolved = relation~resolve(candidate)
    if resolved == .nil then iterate
    if allowed[resolved["physicalName"]~translate] == .nil then return .false
  end
  return .true

::method aggregateGroupKey private
  use arg row, groupColumns
  key = ""
  first = .true
  do grp over groupColumns
    if grp["kind"] = "COLUMN" then value = row[grp["resolved"]["physicalName"]]
    else do
      evaluated = self~evaluateProjectionExpression(grp["expression"], row, grp["relation"])
      if \evaluated["ok"] then value = .nil
      else value = evaluated["value"]
    end
    if value == .nil then token = "N:"
    else token = "V:" || value~string~length || ":" || value~string
    if first then first = .false
    else key ||= "|"
    key ||= token
  end
  return key

::method aggregateValue private
  use arg spec, bucket
  fn = spec["function"]
  filterPredicate = spec["filterPredicate"]
  relation = spec["relation"]

  if fn = "COUNT" then do
    if spec["star"] then do
      if filterPredicate == .nil then return bucket~items
      count = 0
      do row over bucket
        if filterPredicate~evaluate(row, relation) then count += 1
      end
      return count
    end
    count = 0
    resolved = spec["resolved"]
    distinct = spec["distinct"]
    if distinct == .nil then distinct = .false
    seen = .table~new
    do row over bucket
      if filterPredicate \== .nil then if \filterPredicate~evaluate(row, relation) then iterate
      value = row[resolved["physicalName"]]
      if value == .nil then iterate
      if distinct then do
        token = value~string
        if seen[token] \== .nil then iterate
        seen[token] = .true
      end
      count += 1
    end
    return count
  end

  resolved = spec["resolved"]
  expressionArg = spec["expressionArg"]
  relation = spec["relation"]
  have = .false
  total = 0
  count = 0
  minimum = .nil
  maximum = .nil
  if resolved == .nil then col = .nil
  else col = resolved["column"]
  do row over bucket
    if filterPredicate \== .nil then if \filterPredicate~evaluate(row, relation) then iterate
    if resolved == .nil then do
      evaluated = self~evaluateProjectionExpression(expressionArg, row, relation)
      if \evaluated["ok"] then return .nil
      value = evaluated["value"]
      if value \== .nil then do
        if \datatype(value~string, "N") then return .nil
      end
    end
    else value = row[resolved["physicalName"]]
    if value == .nil then iterate
    count += 1
    if fn = "SUM" | fn = "AVG" then total += value
    if \have then do
      minimum = value
      maximum = value
      have = .true
    end
    else do
      if col \== .nil then do
        if col~compare(value, "<", minimum) then minimum = value
        if col~compare(value, ">", maximum) then maximum = value
      end
    end
  end
  if \have then return .nil
  select
    when fn = "SUM" then return total
    when fn = "AVG" then return total / count
    when fn = "MIN" then return minimum
    when fn = "MAX" then return maximum
    otherwise return .nil
  end

::method applyProjection private
  use arg queryResult, projection, relation
  if projection = "*" then return queryResult
  specs = self~splitList(projection)
  outRows = .array~new
  do sourceRow over queryResult~rows
    values = .table~new
    do specText over specs
      spec = self~parseProjectionSpec(specText)
      if spec == .nil then return self~sqlFailure("Invalid projection: " || specText)
      expression = spec["expression"]
      evaluated = self~evaluateProjectionExpression(expression, sourceRow, relation)
      if \evaluated["ok"] then do
        if evaluated["error"] \== .nil then do
          failure = .DatabaseResult~new(.DatabaseOperationType~SELECT)
          return failure~fail(evaluated["error"], evaluated["message"])
        end
        if expression~translate~pos("SELECT ") > 0 then return self~sqlUnsupported("Scalar subquery expression is not implemented: " || expression)
        if self~findTopLevelArithmetic(expression, "*") = 0 then return self~sqlFailure("Unknown or ambiguous projection column: " || expression)
        return self~sqlUnsupported("Projection expression is not implemented: " || expression)
      end
      outputName = spec["alias"]
      if outputName = "" then do
        resolved = relation~resolve(expression)
        if resolved == .nil then outputName = expression
        else if expression~pos(".") > 0 then outputName = expression
        else outputName = resolved["sourceColumn"]
      end
      values[outputName] = evaluated["value"]
    end
    outRows~append(.DatabaseRow~new(values))
  end
  queryResult~rows = outRows
  queryResult~affectedRows = outRows~items
  return queryResult

::method evaluateProjectionExpression private
  use arg expression, sourceRow, relation
  expr = expression~strip
  do while expr~length >= 2
    if expr~left(1) \= "(" then leave
    if self~matchingParen(expr, 1) \= expr~length then leave
    expr = expr~substr(2, expr~length - 2)~strip
  end
  out = .table~new
  out["ok"] = .false
  upperExpr = expr~translate
  if upperExpr~startsWith("SELECT ") then return self~evaluateCorrelatedScalarSubquery(expr, sourceRow, relation)
  if upperExpr~startsWith("COALESCE(") then do
    open = expr~pos("(")
    if open = 0 then return out
    if self~matchingParen(expr, open) \= expr~length then return out
    args = self~splitList(expr~substr(open + 1, expr~length - open - 1))
    if args~items < 2 then return out
    do arg over args
      child = self~evaluateProjectionExpression(arg, sourceRow, relation)
      if \child["ok"] then return child
      if child["value"] \== .nil then do
        out["ok"] = .true
        out["value"] = child["value"]
        return out
      end
    end
    out["ok"] = .true
    out["value"] = .nil
    return out
  end
  if upperExpr~startsWith("NULLIF(") then do
    open = expr~pos("(")
    if open = 0 | self~matchingParen(expr, open) \= expr~length then return out
    args = self~splitList(expr~substr(open + 1, expr~length - open - 1))
    if args~items \= 2 then return out
    leftArg = self~evaluateProjectionExpression(args[1], sourceRow, relation)
    rightArg = self~evaluateProjectionExpression(args[2], sourceRow, relation)
    if \leftArg["ok"] | \rightArg["ok"] then return out
    out["ok"] = .true
    if leftArg["value"] == .nil then out["value"] = .nil
    else if rightArg["value"] \== .nil then do
      if self~compareScalarValues(leftArg["value"], rightArg["value"]) = 0 then out["value"] = .nil
      else out["value"] = leftArg["value"]
    end
    else out["value"] = leftArg["value"]
    return out
  end
  if upperExpr~startsWith("CASE ") then return self~evaluateCaseExpression(expr, sourceRow, relation)
  if upperExpr~startsWith("CAST(") then do
    open = expr~pos("(")
    if open = 0 | self~matchingParen(expr, open) \= expr~length then return out
    body = expr~substr(open + 1, expr~length - open - 1)~strip
    asPos = self~findTopLevelKeyword(" " || body, " AS ")
    if asPos = 0 then return out
    asPos -= 1
    childText = body~left(asPos - 1)~strip
    targetType = body~substr(asPos + 4)~strip~translate
    child = self~evaluateProjectionExpression(childText, sourceRow, relation)
    if \child["ok"] then return child
    out["ok"] = .true
    if child["value"] == .nil then out["value"] = .nil
    else if targetType = "VARCHAR" then do
      if .NoSQLUnicodeSupport~isUnicodeValue(child["value"]) then out["value"] = child["value"]
      else out["value"] = child["value"]~string
    end
    else do
      out["ok"] = .false
      return out
    end
    return out
  end
  do fn over "UPPER LOWER SUBSTR CHAR_LENGTH CHARACTER_LENGTH OCTET_LENGTH ST_SRID ST_GEOMETRYTYPE ST_X ST_Y ST_WITHIN ST_INTERSECTS"~makeArray(" ")
    prefix = fn || "("
    if upperExpr~startsWith(prefix) then do
      if self~matchingParen(expr, prefix~length) \= expr~length then leave
      argText = expr~substr(prefix~length + 1, expr~length - prefix~length - 1)
      args = self~splitList(argText)
      if fn = "UPPER" | fn = "LOWER" then do
        if args~items \= 1 then return out
        child = self~evaluateProjectionExpression(args[1], sourceRow, relation)
        if \child["ok"] then return out
        out["ok"] = .true
        if child["value"] == .nil then out["value"] = .nil
        else if .NoSQLUnicodeSupport~isUnicodeValue(child["value"]) then do
          if fn = "UPPER" then out["value"] = child["value"]~upper
          else out["value"] = child["value"]~lower
        end
        else if fn = "UPPER" then out["value"] = child["value"]~string~translate
        else out["value"] = translate(child["value"]~string, "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return out
      end
      if fn = "CHAR_LENGTH" | fn = "CHARACTER_LENGTH" | fn = "OCTET_LENGTH" then do
        if args~items \= 1 then return out
        child = self~evaluateProjectionExpression(args[1], sourceRow, relation)
        if \child["ok"] then return out
        out["ok"] = .true
        if fn = "OCTET_LENGTH" then out["value"] = .NoSQLUnicodeSupport~octetLength(child["value"])
        else out["value"] = .NoSQLUnicodeSupport~characterLength(child["value"])
        return out
      end
      if fn = "ST_SRID" | fn = "ST_GEOMETRYTYPE" | fn = "ST_X" | fn = "ST_Y" then do
        if args~items \= 1 then return out
        child = self~evaluateProjectionExpression(args[1], sourceRow, relation)
        if \child["ok"] then return child
        out["ok"] = .true
        if child["value"] == .nil then out["value"] = .nil
        else select
          when fn = "ST_SRID" then out["value"] = .NoSQLSpatialSupport~srid(child["value"])
          when fn = "ST_GEOMETRYTYPE" then out["value"] = .NoSQLSpatialSupport~geometryType(child["value"])
          when fn = "ST_X" then out["value"] = .NoSQLSpatialSupport~x(child["value"])
          when fn = "ST_Y" then out["value"] = .NoSQLSpatialSupport~y(child["value"])
          otherwise nop
        end
        return out
      end
      if fn = "ST_WITHIN" | fn = "ST_INTERSECTS" then do
        if args~items \= 2 then return out
        leftArg = self~evaluateProjectionExpression(args[1], sourceRow, relation)
        rightArg = self~evaluateProjectionExpression(args[2], sourceRow, relation)
        if \leftArg["ok"] | \rightArg["ok"] then return out
        out["ok"] = .true
        if leftArg["value"] == .nil | rightArg["value"] == .nil then out["value"] = .nil
        else if fn = "ST_WITHIN" then do
          if .NoSQLSpatialSupport~within(leftArg["value"], rightArg["value"]) then out["value"] = "TRUE"
          else out["value"] = "FALSE"
        end
        else do
          if .NoSQLSpatialSupport~intersects(leftArg["value"], rightArg["value"]) then out["value"] = "TRUE"
          else out["value"] = "FALSE"
        end
        return out
      end
      if fn = "SUBSTR" then do
        if args~items < 2 | args~items > 3 then return out
        valueArg = self~evaluateProjectionExpression(args[1], sourceRow, relation)
        startArg = self~evaluateProjectionExpression(args[2], sourceRow, relation)
        if \valueArg["ok"] | \startArg["ok"] then return out
        out["ok"] = .true
        if valueArg["value"] == .nil then do; out["value"] = .nil; return out; end
        if \datatype(startArg["value"]~string, "W") then do; out["ok"] = .false; return out; end
        if args~items = 2 then do
          if .NoSQLUnicodeSupport~isUnicodeValue(valueArg["value"]) then out["value"] = valueArg["value"]~substr(startArg["value"])
          else out["value"] = valueArg["value"]~string~substr(startArg["value"])
        end
        else do
          lenArg = self~evaluateProjectionExpression(args[3], sourceRow, relation)
          if \lenArg["ok"] then do; out["ok"] = .false; return out; end
          if \datatype(lenArg["value"]~string, "W") then do; out["ok"] = .false; return out; end
          if .NoSQLUnicodeSupport~isUnicodeValue(valueArg["value"]) then out["value"] = valueArg["value"]~substr(startArg["value"], lenArg["value"])
          else out["value"] = valueArg["value"]~string~substr(startArg["value"], lenArg["value"])
        end
        return out
      end
    end
  end
  concatPos = self~findTopLevelOperator(expr, "||")
  if concatPos > 0 then do
    left = self~evaluateProjectionExpression(expr~left(concatPos - 1), sourceRow, relation)
    right = self~evaluateProjectionExpression(expr~substr(concatPos + 2), sourceRow, relation)
    if \left["ok"] | \right["ok"] then do
      out["ok"] = .false
      return out
    end
    out["ok"] = .true
    if left["value"] == .nil | right["value"] == .nil then out["value"] = .nil
    else if .NoSQLUnicodeSupport~isUnicodeValue(left["value"]) then ,
      out["value"] = .NoSQLUnicodeSupport~text(.NoSQLUnicodeSupport~raw(left["value"]) || .NoSQLUnicodeSupport~raw(right["value"]))
    else if .NoSQLUnicodeSupport~isUnicodeValue(right["value"]) then ,
      out["value"] = .NoSQLUnicodeSupport~text(.NoSQLUnicodeSupport~raw(left["value"]) || .NoSQLUnicodeSupport~raw(right["value"]))
    else out["value"] = left["value"]~string || right["value"]~string
    return out
  end
  if expr~length >= 2 then do
    first = expr~left(1)
    last = expr~right(1)
    if first = "'" & last = "'" then do
      out["ok"] = .true
      out["value"] = self~unquote(expr)
      return out
    end
  end
  if datatype(expr, "N") then do
    out["ok"] = .true
    out["value"] = expr
    return out
  end
  if upperExpr = "NULL" then do
    out["ok"] = .true
    out["value"] = .nil
    return out
  end
  if upperExpr = "TRUE" | upperExpr = "FALSE" then do
    out["ok"] = .true
    out["value"] = upperExpr
    return out
  end
  resolved = relation~resolve(expr)
  if resolved \== .nil then do
    out["ok"] = .true
    out["value"] = sourceRow[resolved["physicalName"]]
    return out
  end
  op = self~findTopLevelArithmetic(expr, "*")
  if op > 0 then do
    left = self~evaluateProjectionExpression(expr~left(op - 1), sourceRow, relation)
    right = self~evaluateProjectionExpression(expr~substr(op + 1), sourceRow, relation)
    if \left["ok"] | \right["ok"] then do
      out["ok"] = .false
      return out
    end
    if left["value"] == .nil | right["value"] == .nil then value = .nil
    else do
      if \datatype(left["value"]~string, "N") | \datatype(right["value"]~string, "N") then do
        out["ok"] = .false
        return out
      end
      value = left["value"] * right["value"]
    end
    out["ok"] = .true
    out["value"] = value
    return out
  end
  op = self~findTopLevelArithmetic(expr, "/")
  if op > 0 then do
    left = self~evaluateProjectionExpression(expr~left(op - 1), sourceRow, relation)
    right = self~evaluateProjectionExpression(expr~substr(op + 1), sourceRow, relation)
    if \left["ok"] | \right["ok"] then do; out["ok"] = .false; return out; end
    if left["value"] == .nil | right["value"] == .nil then value = .nil
    else do
      if \datatype(left["value"]~string, "N") | \datatype(right["value"]~string, "N") then do; out["ok"] = .false; return out; end
      if right["value"] = 0 then do; out["ok"] = .false; return out; end
      value = left["value"] / right["value"]
    end
    out["ok"] = .true; out["value"] = value; return out
  end
  op = self~findTopLevelArithmetic(expr, "-")
  if op > 0 then do
    left = self~evaluateProjectionExpression(expr~left(op - 1), sourceRow, relation)
    right = self~evaluateProjectionExpression(expr~substr(op + 1), sourceRow, relation)
    if \left["ok"] | \right["ok"] then do; out["ok"] = .false; return out; end
    if left["value"] == .nil | right["value"] == .nil then value = .nil
    else do
      if \datatype(left["value"]~string, "N") | \datatype(right["value"]~string, "N") then do; out["ok"] = .false; return out; end
      value = left["value"] - right["value"]
    end
    out["ok"] = .true; out["value"] = value; return out
  end
  op = self~findTopLevelArithmetic(expr, "+")
  if op > 0 then do
    left = self~evaluateProjectionExpression(expr~left(op - 1), sourceRow, relation)
    right = self~evaluateProjectionExpression(expr~substr(op + 1), sourceRow, relation)
    if \left["ok"] | \right["ok"] then do; out["ok"] = .false; return out; end
    if left["value"] == .nil | right["value"] == .nil then value = .nil
    else do
      if \datatype(left["value"]~string, "N") | \datatype(right["value"]~string, "N") then do; out["ok"] = .false; return out; end
      value = left["value"] + right["value"]
    end
    out["ok"] = .true; out["value"] = value; return out
  end
  out["ok"] = .false
  return out

::method evaluateCaseExpression private
  use arg expression, sourceRow, relation
  out = .table~new
  out["ok"] = .false
  text = expression~strip
  upper = text~translate
  if \upper~startsWith("CASE ") then return out
  if \upper~endsWith(" END") then return out
  if text~length <= 9 then return out
  body = text~substr(6, text~length - 9)~strip
  -- v0.19 searched CASE: CASE WHEN predicate THEN value ... ELSE value END
  if body~translate~startsWith("WHEN ") then do
    tail = body~substr(6)~strip
    do forever
      thenPos = self~findTopLevelKeyword(tail, " THEN ")
      if thenPos = 0 then return out
      conditionText = tail~left(thenPos - 1)~strip
      afterThen = tail~substr(thenPos + 6)~strip
      nextWhen = self~findTopLevelKeyword(afterThen, " WHEN ")
      elsePos = self~findTopLevelKeyword(afterThen, " ELSE ")
      boundary = 0; boundaryKind = ""
      if nextWhen > 0 then do; boundary = nextWhen; boundaryKind = "WHEN"; end
      if elsePos > 0 then if boundary = 0 | elsePos < boundary then do; boundary = elsePos; boundaryKind = "ELSE"; end
      if boundary = 0 then resultText = afterThen~strip
      else resultText = afterThen~left(boundary - 1)~strip
      if self~findScalarSubqueryOpen(conditionText) > 0 then do
        boundCondition = self~bindScalarSubqueries(conditionText, sourceRow, relation)
        if boundCondition == .nil then return out
        conditionText = boundCondition
      end
      predicate = .SQLPredicateParser~new~parse(conditionText)
      if predicate == .nil then return out
      if \self~normalizeSinglePredicate(predicate, relation) then return out
      if predicate~evaluate(sourceRow, relation) then return self~evaluateProjectionExpression(resultText, sourceRow, relation)
      if boundary = 0 then do; out["ok"] = .true; out["value"] = .nil; return out; end
      if boundaryKind = "ELSE" then return self~evaluateProjectionExpression(afterThen~substr(boundary + 6)~strip, sourceRow, relation)
      tail = afterThen~substr(boundary + 6)~strip
    end
  end
  firstWhen = self~findTopLevelKeyword(body, " WHEN ")
  if firstWhen = 0 then return out
  operandText = body~left(firstWhen - 1)~strip
  operand = self~evaluateProjectionExpression(operandText, sourceRow, relation)
  if \operand["ok"] then return out
  tail = body~substr(firstWhen + 6)~strip
  do forever
    thenPos = self~findTopLevelKeyword(tail, " THEN ")
    if thenPos = 0 then return out
    whenText = tail~left(thenPos - 1)~strip
    whenValue = self~evaluateProjectionExpression(whenText, sourceRow, relation)
    if \whenValue["ok"] then return out
    afterThen = tail~substr(thenPos + 6)~strip
    nextWhen = self~findTopLevelKeyword(afterThen, " WHEN ")
    elsePos = self~findTopLevelKeyword(afterThen, " ELSE ")
    boundary = 0
    boundaryKind = ""
    if nextWhen > 0 then do
      boundary = nextWhen
      boundaryKind = "WHEN"
    end
    if elsePos > 0 then do
      if boundary = 0 | elsePos < boundary then do
        boundary = elsePos
        boundaryKind = "ELSE"
      end
    end
    if boundary = 0 then resultText = afterThen~strip
    else resultText = afterThen~left(boundary - 1)~strip
    if self~compareScalarValues(operand["value"], whenValue["value"]) = 0 then do
      resultValue = self~evaluateProjectionExpression(resultText, sourceRow, relation)
      return resultValue
    end
    if boundary = 0 then do
      out["ok"] = .true
      out["value"] = .nil
      return out
    end
    if boundaryKind = "ELSE" then do
      elseText = afterThen~substr(boundary + 6)~strip
      elseValue = self~evaluateProjectionExpression(elseText, sourceRow, relation)
      return elseValue
    end
    tail = afterThen~substr(boundary + 6)~strip
  end

::method findTopLevelOperator private
  use arg text, wanted
  depth = 0
  quote = ""
  i = 1
  do while i <= text~length - wanted~length + 1
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then do
        if i < text~length then do
          if text~substr(i + 1,1) = quote then i += 1
          else quote = ""
        end
        else quote = ""
      end
    end
    else if ch = "'" | ch = '"' then quote = ch
    else if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if depth = 0 then do
      if text~substr(i, wanted~length) = wanted then return i
    end
    i += 1
  end
  return 0

::method findTopLevelArithmetic private
  use arg text, wanted
  depth = 0
  quote = ""
  i = 1
  do while i <= text~length
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then do
        if i < text~length then do
          if text~substr(i + 1,1) = quote then i += 1
          else quote = ""
        end
        else quote = ""
      end
    end
    else if ch = "'" | ch = '"' then quote = ch
    else if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if depth = 0 then do
      if ch = wanted then return i
    end
    i += 1
  end
  return 0

::method findScalarSubqueryOpen private
  use arg text
  upper = text~translate
  start = 1
  do forever
    pos = upper~pos("(", start)
    if pos = 0 then return 0
    i = pos + 1
    do while i <= upper~length & upper~substr(i,1) = " "
      i += 1
    end
    if upper~substr(i,7) = "SELECT " | upper~substr(i,6) = "SELECT" then return pos
    start = pos + 1
  end

::method bindScalarSubqueries private
  use arg text, outerRow, outerRelation
  work = text
  do forever
    pos = self~findScalarSubqueryOpen(work)
    if pos = 0 then leave
    close = self~matchingParen(work, pos)
    if close = 0 then return .nil
    inner = work~substr(pos + 1, close - pos - 1)~strip
    scalar = self~evaluateCorrelatedScalarSubquery(inner, outerRow, outerRelation)
    if \scalar["ok"] then return .nil
    literal = self~sqlLiteralForDynamicValue(scalar["value"])
    work = work~left(pos - 1) || literal || work~substr(close + 1)
  end
  return work

::method sqlLiteralForDynamicValue private
  use arg value
  if value == .nil then return "NULL"
  text = value~string
  if datatype(text, "N") then return text
  upper = text~translate
  if upper = "TRUE" | upper = "FALSE" then return upper
  return "'" || text~changeStr("'", "''") || "'"

::method evaluateCorrelatedScalarSubquery private
  use arg subqueryText, outerRow, outerRelation
  out = .table~new
  boundText = self~bindOuterReferences(subqueryText, outerRow, outerRelation)
  subRs = self~executeSelect(boundText)
  if subRs~status \= .Error~SUCCESS then do
    out["ok"] = .false
    out["error"] = subRs~error
    out["message"] = subRs~message
    return out
  end
  if subRs~rows~items = 0 then do
    out["ok"] = .true
    out["value"] = .nil
    return out
  end
  if subRs~rows~items > 1 then do
    out["ok"] = .false
    out["error"] = .Error~DATABASEERROR
    out["message"] = "Scalar subquery returned more than one row"
    return out
  end
  row = subRs~rows[1]
  keys = .array~new
  do key over row~values
    keys~append(key)
  end
  if keys~items \= 1 then do
    out["ok"] = .false
    out["error"] = .Error~DATABASEERROR
    out["message"] = "Scalar subquery must return exactly one column"
    return out
  end
  out["ok"] = .true
  out["value"] = row[keys[1]]
  return out

::method bindOuterReferences private
  use arg text, outerRow, outerRelation
  out = ""
  quote = ""
  i = 1
  do while i <= text~length
    ch = text~substr(i,1)
    if quote \= "" then do
      out ||= ch
      if ch = quote then do
        if i < text~length then do
          if text~substr(i + 1,1) = quote then do
            out ||= quote
            i += 2
            iterate
          end
        end
        quote = ""
      end
      i += 1
      iterate
    end
    if ch = "'" | ch = '"' then do
      quote = ch
      out ||= ch
      i += 1
      iterate
    end
    if self~isIdentifierChar(ch) then do
      start = i
      do while i <= text~length
        if \self~isIdentifierChar(text~substr(i,1)) then leave
        i += 1
      end
      token = text~substr(start, i - start)
      if token~pos(".") > 0 then do
        resolved = outerRelation~resolve(token)
        if resolved \== .nil then do
          value = outerRow[resolved["physicalName"]]
          out ||= self~sqlLiteralForBoundValue(value, resolved["column"])
          iterate
        end
      end
      out ||= token
      iterate
    end
    out ||= ch
    i += 1
  end
  return out

::method isIdentifierChar private
  use arg ch
  if ch = "" then return .false
  if datatype(ch, "A") then return .true
  if datatype(ch, "N") then return .true
  if ch = "_" | ch = "." then return .true
  return .false

::method sqlLiteralForBoundValue private
  use arg value, column
  if value == .nil then return "NULL"
  typeName = "UNKNOWN"
  if column \== .nil then typeName = column~type
  if typeName = "INTEGER" | typeName = "DECIMAL" then return value~string
  if typeName = "BOOLEAN" then do
    upper = value~string~translate
    if upper = "TRUE" | upper = "1" then return "TRUE"
    return "FALSE"
  end
  return "'" || value~string~changeStr("'", "''") || "'"

::method parseProjectionSpec private
  use arg text
  item = text~strip
  out = .table~new
  upper = item~translate
  asPos = upper~lastPos(" AS ")
  if asPos > 0 then do
    expression = item~left(asPos - 1)~strip
    alias = item~substr(asPos + 4)~strip
    if expression = "" | alias = "" then return .nil
    if alias~space~words \= 1 then return .nil
    out["expression"] = expression
    out["alias"] = alias
    return out
  end
  if item~space~words \= 1 then do
    itemUpper = item~translate
    if itemUpper~startsWith("CASE ") then do
      if \itemUpper~endsWith(" END") then return .nil
    end
    else do
      expressionForm = .false
      do fn over "COUNT SUM AVG MIN MAX UPPER LOWER SUBSTR COALESCE"~makeArray(" ")
        if itemUpper~startsWith(fn || "(") then expressionForm = .true
      end
      if item~left(1) = "(" then do
        if self~matchingParen(item, 1) = item~length then do
          innerProjection = item~substr(2, item~length - 2)~strip~translate
          if innerProjection~startsWith("SELECT ") then expressionForm = .true
        end
      end
      if \expressionForm then return .nil
      open = item~pos("(")
      if open = 0 then return .nil
      if self~matchingParen(item, open) \= item~length then return .nil
    end
  end
  out["expression"] = item
  out["alias"] = ""
  return out

::method executeInsert private
  use arg text
  tableStart = wordindex(text, 3)
  if tableStart = 0 then return self~sqlFailure("INSERT requires table name")
  rest = text~substr(tableStart)~strip

  -- Both standard INSERT forms are native grammar:
  --   INSERT INTO table (a,b) VALUES (...)
  --   INSERT INTO table VALUES (...)
  -- Only grammar whitespace is skipped; quoted value contents are untouched.
  tableEnd = 1
  do while tableEnd <= rest~length
    ch = rest~substr(tableEnd, 1)
    if self~isSQLWhitespace(ch) | ch = "(" then leave
    tableEnd += 1
  end
  tableName = rest~left(tableEnd - 1)~strip
  if tableName = "" then return self~sqlFailure("INSERT requires table name")

  t = self~engine~table(tableName)
  if t == .nil then return self~sqlFailure("Table not found: " || tableName)

  pos = self~skipSQLWhitespace(rest, tableEnd)
  cols = .array~new

  if pos <= rest~length then do
    if rest~substr(pos, 1) = "(" then do
      closeCols = self~matchingParen(rest, pos)
      if closeCols = 0 then return self~sqlFailure("INSERT has unmatched column list")
      columnsText = rest~substr(pos + 1, closeCols - pos - 1)
      cols = self~trimmedList(columnsText)
      if cols~items = 0 then return self~sqlFailure("INSERT requires at least one column")
      pos = self~skipSQLWhitespace(rest, closeCols + 1)
    end
    else do
      do columnName over t~definition~columnNames
        cols~append(columnName)
      end
    end
  end

  if pos > rest~length then return self~sqlFailure("INSERT requires VALUES")
  if pos + 5 > rest~length then return self~sqlFailure("INSERT requires VALUES")
  if \rest~substr(pos, 6)~caselessEquals("VALUES") then return self~sqlFailure("INSERT requires VALUES")
  afterValues = pos + 6
  if afterValues <= rest~length then do
    nextCh = rest~substr(afterValues, 1)
    if \self~isSQLWhitespace(nextCh) & nextCh \= "(" then return self~sqlFailure("INSERT requires VALUES")
  end

  pos = self~skipSQLWhitespace(rest, afterValues)
  if pos > rest~length then return self~sqlFailure("INSERT requires at least one VALUES tuple")

  rows = .array~new
  do while pos <= rest~length
    if rest~substr(pos, 1) \= "(" then return self~sqlFailure("VALUES requires parenthesized tuple")
    closeValues = self~matchingParen(rest, pos)
    if closeValues = 0 then return self~sqlFailure("VALUES has unmatched '('")
    valuesText = rest~substr(pos + 1, closeValues - pos - 1)
    vals = self~splitList(valuesText)
    if cols~items \= vals~items then return self~sqlFailure("INSERT column/value count mismatch")

    row = .table~new
    do i = 1 to cols~items
      row[cols[i]] = self~literal(vals[i]~strip)
    end
    rows~append(row)

    pos = self~skipSQLWhitespace(rest, closeValues + 1)
    if pos <= rest~length then do
      if rest~substr(pos, 1) \= "," then return self~sqlFailure("Unexpected INSERT trailing input")
      pos = self~skipSQLWhitespace(rest, pos + 1)
      if pos > rest~length then return self~sqlFailure("INSERT requires VALUES tuple after ','")
    end
  end

  if rows~items = 0 then return self~sqlFailure("INSERT requires at least one VALUES tuple")
  if rows~items = 1 then return self~engine~insert(tableName, rows[1])
  return self~engine~insertMany(tableName, rows)

::method executeUpdateFrom private
  use arg targetText, setText, fromText, whereText

  targetRef = self~parseTableRef(targetText)
  if targetRef == .nil then return self~sqlParseFailure("Invalid UPDATE target table reference")
  sourceRef = self~parseTableRef(fromText)
  if sourceRef == .nil then return self~sqlParseFailure("Invalid UPDATE FROM table reference")

  targetObj = self~engine~table(targetRef["table"])
  if targetObj == .nil then return self~sqlFailure("Table not found: " || targetRef["table"])
  sourceObj = self~engine~table(sourceRef["table"])
  if sourceObj == .nil then return self~sqlFailure("Table not found: " || sourceRef["table"])

  entries = .array~new
  targetEntry = .table~new
  targetEntry["table"] = targetObj
  targetEntry["definition"] = targetObj~definition
  targetEntry["alias"] = targetRef["alias"]
  sourceEntry = .table~new
  sourceEntry["table"] = sourceObj
  sourceEntry["definition"] = sourceObj~definition
  sourceEntry["alias"] = sourceRef["alias"]
  entries~append(targetEntry)
  entries~append(sourceEntry)
  relation = .SQLAliasRelationDefinition~new(entries)

  assignments = .array~new
  do item over self~splitList(setText)
    p = self~parseEquals(item)
    if p == .nil then return self~sqlFailure("Invalid SET assignment")
    targetColumn = targetObj~definition~canonicalColumn(p[1])
    if targetColumn == .nil then do
      resolvedTarget = relation~resolve(p[1])
      if resolvedTarget == .nil then return self~sqlParseFailure("Unknown UPDATE target column: " || p[1])
      if \resolvedTarget["alias"]~caselessEquals(targetRef["alias"]) then return self~sqlParseFailure("UPDATE SET may assign only target-table columns")
      targetColumn = resolvedTarget["sourceColumn"]
    end
    spec = .table~new
    spec["column"] = targetColumn
    spec["expression"] = p[2]
    assignments~append(spec)
  end

  predicate = .nil
  if whereText \= "" then do
    predicate = .SQLPredicateParser~new~parse(whereText)
    if predicate == .nil then return self~sqlParseFailure("Invalid UPDATE FROM WHERE predicate")
  end

  targetRows = targetObj~readRows
  sourceRows = sourceObj~readRows
  affected = 0

  do targetRaw over targetRows
    targetQualified = self~qualifiedAliasRow(targetEntry, targetRaw)
    matchedCombined = .nil
    matchCount = 0

    do sourceRaw over sourceRows
      values = targetQualified~values~copy
      do col over sourceObj~definition~columns
        values[sourceRef["alias"] || "." || col~name] = sourceRaw[col~name]
      end
      combined = .DatabaseRow~new(values)

      matched = .true
      if predicate \== .nil then matched = predicate~evaluate(combined, relation)
      if matched then do
        matchCount += 1
        if matchCount > 1 then return self~sqlUnsupported("UPDATE FROM produced multiple source matches for one target row")
        matchedCombined = combined
      end
    end

    if matchCount = 0 then iterate

    newValues = .table~new
    do spec over assignments
      evaluated = self~evaluateProjectionExpression(spec["expression"], matchedCombined, relation)
      if \evaluated["ok"] then return self~sqlUnsupported("UPDATE FROM assignment expression is not implemented: " || spec["expression"])
      newValues[spec["column"]] = evaluated["value"]
    end

    pkPredicate = .nil
    do pkName over targetObj~definition~primaryKey
      piece = .SQLComparisonPredicate~new(pkName, "=", targetRaw[pkName])
      if pkPredicate == .nil then pkPredicate = piece
      else pkPredicate = .SQLLogicalPredicate~new("AND", pkPredicate, piece)
    end
    if pkPredicate == .nil then return self~sqlUnsupported("UPDATE FROM requires a primary key on the target table")

    one = self~engine~updateWhere(targetRef["table"], pkPredicate, newValues)
    if one~status \= .Error~SUCCESS then return one
    affected += one~affectedRows
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~UPDATE)
  rs~affectedRows = affected
  rs~accessPath = "UPDATE_FROM_NESTED_LOOP"
  return rs

::method executeUpdate private
  use arg text
  rest = text~substr(8)~strip
  setPos = self~findTopLevelKeyword(" " || rest, " SET ")
  if setPos = 0 then return self~sqlFailure("UPDATE requires SET")
  setPos -= 1
  targetText = rest~left(setPos - 1)~strip
  afterSet = rest~substr(setPos + 5)~strip

  wherePos = self~findTopLevelKeyword(" " || afterSet, " WHERE ")
  if wherePos > 0 then do
    wherePos -= 1
    beforeWhere = afterSet~left(wherePos - 1)~strip
    whereText = afterSet~substr(wherePos + 7)~strip
    if whereText = "" then return self~sqlParseFailure("WHERE requires a predicate")
  end
  else do
    beforeWhere = afterSet
    whereText = ""
  end

  fromPos = self~findTopLevelKeyword(" " || beforeWhere, " FROM ")
  if fromPos > 0 then do
    fromPos -= 1
    setText = beforeWhere~left(fromPos - 1)~strip
    fromText = beforeWhere~substr(fromPos + 6)~strip
    if setText = "" then return self~sqlParseFailure("UPDATE requires SET assignments")
    if fromText = "" then return self~sqlParseFailure("UPDATE FROM requires a source table")
    return self~executeUpdateFrom(targetText, setText, fromText, whereText)
  end

  tableName = targetText
  setText = beforeWhere

  -- Preserve the established literal fast path where possible.
  expressionAssignments = .array~new
  literalAssignments = .table~new
  hasExpression = .false
  do item over self~splitList(setText)
    p = self~parseEquals(item)
    if p == .nil then return self~sqlFailure("Invalid SET assignment")
    spec = .table~new
    spec["column"] = p[1]
    spec["expression"] = p[2]
    expressionAssignments~append(spec)
    lit = self~literal(p[2])
    -- Bare identifiers/arithmetic/subqueries are expressions, not string literals.
    exprUpper = p[2]~strip~translate
    if self~findTopLevelArithmetic(p[2], "*") > 0 | self~findTopLevelArithmetic(p[2], "+") > 0 | ,
       self~findTopLevelArithmetic(p[2], "-") > 0 | self~findTopLevelArithmetic(p[2], "/") > 0 | ,
       self~findScalarSubqueryOpen(p[2]) > 0 then hasExpression = .true
    else literalAssignments[p[1]] = lit
  end
  if \hasExpression & self~findScalarSubqueryOpen(whereText) = 0 then do
    predicate = .nil
    if whereText \= "" then predicate = .SQLPredicateParser~new~parse(whereText)
    return self~engine~updateWhere(tableName, predicate, literalAssignments)
  end

  t = self~engine~table(tableName)
  if t == .nil then return self~sqlFailure("Table not found: " || tableName)
  relation = .SQLRelationDefinition~new(t~definition, tableName)
  affected = 0
  rows = t~readRows
  do row over rows
    matched = .true
    if whereText \= "" then do
      boundWhere = whereText
      if self~findScalarSubqueryOpen(boundWhere) > 0 then do
        boundWhere = self~bindScalarSubqueries(boundWhere, row, relation)
        if boundWhere == .nil then return self~sqlUnsupported("Correlated scalar subquery in UPDATE WHERE could not be evaluated")
      end
      expanded = self~expandSetSubqueryPredicates(boundWhere)
      if expanded["error"] \== .nil then return expanded["error"]
      predicate = .SQLPredicateParser~new~parse(expanded["text"])
      if predicate == .nil then return self~sqlParseFailure("Invalid UPDATE WHERE predicate")
      if \self~normalizeSinglePredicate(predicate, relation) then return self~sqlParseFailure("Unknown UPDATE WHERE column")
      matched = predicate~evaluate(row, relation)
    end
    if \matched then iterate
    values = .table~new
    do spec over expressionAssignments
      evaluated = self~evaluateProjectionExpression(spec["expression"], row, relation)
      if \evaluated["ok"] then return self~sqlUnsupported("UPDATE assignment expression is not implemented: " || spec["expression"])
      values[spec["column"]] = evaluated["value"]
    end
    pkPredicate = .nil
    do pkName over t~definition~primaryKey
      piece = .SQLComparisonPredicate~new(pkName, "=", row[pkName])
      if pkPredicate == .nil then pkPredicate = piece
      else pkPredicate = .SQLLogicalPredicate~new(pkPredicate, "AND", piece)
    end
    if pkPredicate == .nil then return self~sqlUnsupported("Expression UPDATE requires a primary key")
    one = self~engine~updateWhere(tableName, pkPredicate, values)
    if one~status \= .Error~SUCCESS then return one
    affected += one~affectedRows
  end
  rs = .DatabaseResult~new(.DatabaseOperationType~UPDATE)
  rs~affectedRows = affected
  return rs

::method executeDeleteUsing private
  use arg targetText, usingText, whereText

  targetRef = self~parseTableRef(targetText)
  if targetRef == .nil then return self~sqlParseFailure("Invalid DELETE target table reference")
  sourceRef = self~parseTableRef(usingText)
  if sourceRef == .nil then return self~sqlParseFailure("Invalid DELETE USING table reference")

  targetObj = self~engine~table(targetRef["table"])
  if targetObj == .nil then return self~sqlFailure("Table not found: " || targetRef["table"])
  sourceObj = self~engine~table(sourceRef["table"])
  if sourceObj == .nil then return self~sqlFailure("Table not found: " || sourceRef["table"])

  entries = .array~new
  targetEntry = .table~new
  targetEntry["table"] = targetObj
  targetEntry["definition"] = targetObj~definition
  targetEntry["alias"] = targetRef["alias"]
  sourceEntry = .table~new
  sourceEntry["table"] = sourceObj
  sourceEntry["definition"] = sourceObj~definition
  sourceEntry["alias"] = sourceRef["alias"]
  entries~append(targetEntry)
  entries~append(sourceEntry)
  relation = .SQLAliasRelationDefinition~new(entries)

  predicate = .nil
  if whereText \= "" then do
    predicate = .SQLPredicateParser~new~parse(whereText)
    if predicate == .nil then return self~sqlParseFailure("Invalid DELETE USING WHERE predicate")
  end

  if targetObj~definition~primaryKey~items = 0 then return self~sqlUnsupported("DELETE USING requires a primary key on the target table")

  targetRows = targetObj~readRows
  sourceRows = sourceObj~readRows
  deleteKeys = .table~new

  do targetRaw over targetRows
    targetQualified = self~qualifiedAliasRow(targetEntry, targetRaw)
    matchedTarget = .false

    do sourceRaw over sourceRows
      values = targetQualified~values~copy
      do col over sourceObj~definition~columns
        values[sourceRef["alias"] || "." || col~name] = sourceRaw[col~name]
      end
      combined = .DatabaseRow~new(values)

      matched = .true
      if predicate \== .nil then matched = predicate~evaluate(combined, relation)
      if matched then do
        matchedTarget = .true
        leave
      end
    end

    if matchedTarget then do
      sig = ""
      first = .true
      do pkName over targetObj~definition~primaryKey
        if \first then sig ||= "1F"x
        v = targetRaw[pkName]
        if v == .nil then v = ""
        sig ||= v~string
        first = .false
      end
      deleteKeys[sig] = targetRaw
    end
  end

  affected = 0
  do sig over deleteKeys~allIndexes
    targetRaw = deleteKeys[sig]
    pkPredicate = .nil
    do pkName over targetObj~definition~primaryKey
      piece = .SQLComparisonPredicate~new(pkName, "=", targetRaw[pkName])
      if pkPredicate == .nil then pkPredicate = piece
      else pkPredicate = .SQLLogicalPredicate~new("AND", pkPredicate, piece)
    end
    one = self~engine~deleteWhere(targetRef["table"], pkPredicate)
    if one~status \= .Error~SUCCESS then return one
    affected += one~affectedRows
  end

  rs = .DatabaseResult~new(.DatabaseOperationType~DELETE)
  rs~affectedRows = affected
  rs~accessPath = "DELETE_USING_NESTED_LOOP"
  return rs

::method executeDelete private
  use arg text
  rest = text~substr(13)~strip

  wherePos = self~findTopLevelKeyword(" " || rest, " WHERE ")
  if wherePos > 0 then do
    wherePos -= 1
    beforeWhere = rest~left(wherePos - 1)~strip
    predicateText = rest~substr(wherePos + 7)~strip
    if predicateText = "" then return self~sqlParseFailure("WHERE requires a predicate")
  end
  else do
    beforeWhere = rest
    predicateText = ""
  end

  usingPos = self~findTopLevelKeyword(" " || beforeWhere, " USING ")
  if usingPos > 0 then do
    usingPos -= 1
    targetText = beforeWhere~left(usingPos - 1)~strip
    usingText = beforeWhere~substr(usingPos + 7)~strip
    if targetText = "" then return self~sqlParseFailure("DELETE FROM requires a target table")
    if usingText = "" then return self~sqlParseFailure("DELETE USING requires a source table")
    return self~executeDeleteUsing(targetText, usingText, predicateText)
  end

  tableName = beforeWhere
  if predicateText = "" then return self~engine~deleteWhere(tableName, .nil)

  -- Resolve IN/NOT IN/quantified set subqueries first.  A scalar correlated
  -- subquery may remain afterward and is then evaluated once per source row.
  expanded = self~expandSetSubqueryPredicates(predicateText)
  if expanded["error"] \== .nil then return expanded["error"]
  predicateText = expanded["text"]

  if self~findScalarSubqueryOpen(predicateText) > 0 then do
    t = self~engine~table(tableName)
    if t == .nil then return self~sqlFailure("Table not found: " || tableName)
    relation = .SQLRelationDefinition~new(t~definition, tableName)
    rows = t~readRows
    affected = 0
    do row over rows
      bound = self~bindScalarSubqueries(predicateText, row, relation)
      if bound == .nil then return self~sqlUnsupported("Correlated scalar subquery in DELETE could not be evaluated")
      pred = .SQLPredicateParser~new~parse(bound)
      if pred == .nil then return self~sqlParseFailure("Invalid DELETE predicate")
      if \self~normalizeSinglePredicate(pred, relation) then return self~sqlParseFailure("Unknown DELETE WHERE column")
      if \pred~evaluate(row, relation) then iterate
      pkPredicate = .nil
      do pkName over t~definition~primaryKey
        piece = .SQLComparisonPredicate~new(pkName, "=", row[pkName])
        if pkPredicate == .nil then pkPredicate = piece
        else pkPredicate = .SQLLogicalPredicate~new("AND", pkPredicate, piece)
      end
      if pkPredicate == .nil then return self~sqlUnsupported("Correlated DELETE requires a primary key")
      one = self~engine~deleteWhere(tableName, pkPredicate)
      if one~status \= .Error~SUCCESS then return one
      affected += one~affectedRows
    end
    rs = .DatabaseResult~new(.DatabaseOperationType~DELETE)
    rs~affectedRows = affected
    return rs
  end

  predicate = .SQLPredicateParser~new~parse(predicateText)
  if predicate == .nil then return self~sqlParseFailure("Invalid DELETE predicate")
  return self~engine~deleteWhere(tableName, predicate)

::method parseEquals private
  use arg text
  eq = text~pos("=")
  if eq = 0 then return .nil
  left = text~left(eq - 1)~strip
  right = text~substr(eq + 1)~strip
  if left = "" then return .nil
  if right = "" then return .nil
  out = .array~new
  out[1] = left
  out[2] = self~unquote(right)
  return out

::method splitList private
  use arg text
  out = .array~new
  current = ""
  quote = ""
  depth = 0
  i = 1
  do while i <= text~length
    ch = text~substr(i, 1)
    if quote \= "" then do
      current ||= ch
      if ch = quote then do
        doubled = .false
        if i < text~length then do
          if text~substr(i + 1, 1) = quote then doubled = .true
        end
        if doubled then do
          current ||= quote
          i += 1
        end
        else quote = ""
      end
    end
    else if ch = "'" then do
      quote = ch
      current ||= ch
    end
    else if ch = '"' then do
      quote = ch
      current ||= ch
    end
    else if ch = "(" then do
      depth += 1
      current ||= ch
    end
    else if ch = ")" then do
      depth -= 1
      current ||= ch
    end
    else if ch = "," then do
      if depth = 0 then do
        out~append(current~strip)
        current = ""
      end
      else current ||= ch
    end
    else current ||= ch
    i += 1
  end
  if current~strip \= "" then out~append(current~strip)
  return out

::method isSQLWhitespace private
  use arg ch
  if ch = " " then return .true
  if ch = x2c("09") then return .true
  if ch = x2c("0A") then return .true
  if ch = x2c("0D") then return .true
  return .false

::method skipSQLWhitespace private
  use arg text, pos
  do while pos <= text~length
    if \self~isSQLWhitespace(text~substr(pos, 1)) then leave
    pos += 1
  end
  return pos

::method trimmedList private
  use arg text
  out = .array~new
  do item over self~splitList(text)
    out~append(item~strip)
  end
  return out

::method matchingParen private
  use arg text, openPos
  depth = 0
  quote = ""
  i = openPos
  do while i <= text~length
    ch = text~substr(i, 1)
    if quote \= "" then do
      if ch = quote then do
        doubled = .false
        if i < text~length then do
          if text~substr(i + 1, 1) = quote then doubled = .true
        end
        if doubled then i += 1
        else quote = ""
      end
    end
    else if ch = "'" then quote = ch
    else if ch = '"' then quote = ch
    else if ch = "(" then depth += 1
    else if ch = ")" then do
      depth -= 1
      if depth = 0 then return i
    end
    i += 1
  end
  return 0

::method literal private
  use arg value
  value = value~strip
  if value~translate = "NULL" then return .nil
  return self~unquote(value)

::method unquote private
  use arg value
  value = value~strip
  if value~length >= 2 then do
    first = value~left(1)
    last = value~right(1)
    quoted = .false
    if first = "'" then do
      if last = "'" then quoted = .true
    end
    if first = '"' then do
      if last = '"' then quoted = .true
    end
    if quoted then do
      inner = value~substr(2, value~length - 2)
      return inner~changeStr(first || first, first)
    end
  end
  return value

::method unsupportedSelectReason private
  use arg text
  u = " " || text~translate || " "
  topFrom = self~findTopLevelKeyword(text, " FROM ")
  fromPos = u~pos(" FROM ")
  if fromPos > 0 then do
    tail = u~substr(fromPos + 6)
    stop = tail~length + 1
    p = tail~pos(" WHERE ")
    if p > 0 then stop = p
    p = tail~pos(" JOIN ")
    if p > 0 then do
      if p < stop then stop = p
    end
    fromRef = tail~left(stop - 1)
  end
  return ""

::method sqlFailure private
  use arg message
  return self~sqlParseFailure(message)

::method sqlParseFailure private
  use arg message
  rs = .DatabaseResult~new
  return rs~fail(.Error~SQLPARSEERROR, message)

::method sqlUnsupported private
  use arg message
  rs = .DatabaseResult~new
  return rs~fail(.Error~SQLUNSUPPORTED, message)


/* -------------------------------------------------------------------------
   Shared database abstraction interoperability surfaces (v0.14)
   ------------------------------------------------------------------------- */

::class DatabaseType public
::constant NULL      "NULL"
::constant BOOLEAN   "BOOLEAN"
::constant INTEGER   "INTEGER"
::constant DECIMAL   "DECIMAL"
::constant VARCHAR   "VARCHAR"
::constant DATE      "DATE"
::constant DATETIME  "DATETIME"
::constant BLOB      "BLOB"
::constant GEOMETRY  "GEOMETRY"
::constant UNKNOWN   "UNKNOWN"

::class DatabaseSpatialEncoding public
::constant OPAQUE       "OPAQUE"
::constant WKT          "WKT"
::constant WKBHEX       "WKBHEX"
::constant EWKBHEX      "EWKBHEX"
::constant GPKGBLOBHEX  "GPKGBLOBHEX"

::class DatabaseGeometryValue public subclass DatabaseValue
::attribute geometryType
::attribute srid
::attribute encoding

::method init
  use arg raw = "", geometryType = "", srid = 0, encoding = .nil, value = .nil
  if encoding == .nil then encoding = .DatabaseSpatialEncoding~OPAQUE
  if value == .nil then value = raw
  self~init:super(raw, value, .DatabaseType~GEOMETRY)
  self~geometryType = geometryType
  self~srid = srid
  self~encoding = encoding

::method string
  type = self~geometryType
  if type = "" then type = .DatabaseType~GEOMETRY
  return type || "(SRID=" || self~srid || "," || self~encoding || "=" || self~rawValue~string~left(24) || "...)"

::class DatabaseValue public
::attribute rawValue
::attribute value
::attribute typeName
::attribute null

::method init
  use arg rawValue = .nil, value = .nil, typeName = "UNKNOWN"
  self~rawValue = rawValue
  self~value = value
  self~typeName = typeName~string~translate
  self~null = (value == .nil)

::method nullValue class
  return self~new(.nil, .nil, .DatabaseType~NULL)

::method boolean class
  use arg value
  if value == .nil then return self~nullValue
  u = value~string~strip~translate
  if u = "TRUE" | u = "1" then return self~new(value, "TRUE", .DatabaseType~BOOLEAN)
  if u = "FALSE" | u = "0" then return self~new(value, "FALSE", .DatabaseType~BOOLEAN)
  return self~invalid(value, .DatabaseType~BOOLEAN)

::method integer class
  use arg value
  if value == .nil then return self~nullValue
  if \datatype(value~string, "W") then return self~invalid(value, .DatabaseType~INTEGER)
  return self~new(value, value~string, .DatabaseType~INTEGER)

::method decimal class
  use arg value
  if value == .nil then return self~nullValue
  if \datatype(value~string, "N") then return self~invalid(value, .DatabaseType~DECIMAL)
  return self~new(value, value~string, .DatabaseType~DECIMAL)

::method varchar class
  use arg value
  if value == .nil then return self~nullValue
  return self~new(value, value~string, .DatabaseType~VARCHAR)

::method date class
  use arg value
  if value == .nil then return self~nullValue
  return self~new(value, value~string, .DatabaseType~DATE)

::method datetime class
  use arg value
  if value == .nil then return self~nullValue
  return self~new(value, value~string, .DatabaseType~DATETIME)

::method blob class
  use arg value
  if value == .nil then return self~nullValue
  return self~new(value, value~string, .DatabaseType~BLOB)

::method geometry class
  use arg value, geometryType = "", srid = 0, encoding = .nil
  if value == .nil then return self~nullValue
  raw = value
  if value~hasMethod("hex") then raw = value~hex
  return .DatabaseGeometryValue~new(raw, geometryType, srid, encoding, value)

::method unknown class
  use arg value
  if value == .nil then return self~nullValue
  return self~new(value, value, .DatabaseType~UNKNOWN)

::method invalid class private
  use arg raw, typeName
  v = self~new(raw, raw, typeName)
  v~typeName = "INVALID:" || typeName
  return v

::class DatabaseColumnMetadata public
::attribute name
::attribute nativeType
::attribute commonType
::attribute nullable
::attribute ordinalPosition
::attribute geometryType
::attribute srid
::attribute textMode

::method init
  use arg name, nativeType, commonType, nullable, ordinalPosition, geometryType = "", srid = 0, textMode = "CLASSIC"
  self~name = name
  self~nativeType = nativeType
  self~commonType = commonType
  self~nullable = nullable
  self~ordinalPosition = ordinalPosition
  self~geometryType = geometryType
  self~srid = srid
  self~textMode = textMode

::class DatabaseTableMetadata public
::attribute name
::attribute columns

::method init
  use arg definition, geometryColumn = "", geometryType = "", srid = 0
  self~name = definition~name
  cols = .array~new
  ordinal = 1
  do col over definition~columns
    columnGeometryType = ""
    columnSrid = 0
    if geometryColumn \= "" then do
      if col~name~caselessEquals(geometryColumn) then do
        columnGeometryType = geometryType
        columnSrid = srid
      end
    end
    cols~append(.DatabaseColumnMetadata~new(col~name, col~type, self~commonType(col~type), col~nullable, ordinal, columnGeometryType, columnSrid, col~textMode))
    ordinal += 1
  end
  self~columns = cols

::method commonType private
  use arg nativeType
  t = nativeType~string~translate
  select
    when t = "BOOLEAN" then return .DatabaseType~BOOLEAN
    when t = "INTEGER" then return .DatabaseType~INTEGER
    when t = "DECIMAL" then return .DatabaseType~DECIMAL
    when t = "VARCHAR" then return .DatabaseType~VARCHAR
    when t = "TEXT" then return .DatabaseType~VARCHAR
    when t = "DATE" then return .DatabaseType~DATE
    when t = "DATETIME" then return .DatabaseType~DATETIME
    when t = "BLOB" then return .DatabaseType~BLOB
    when t = "GEOMETRY" then return .DatabaseType~GEOMETRY
    otherwise return .DatabaseType~UNKNOWN
  end

::class DatabaseDeferredQueryResult subclass DatabaseResult public
::attribute complete

::method init
  self~init:super(.DatabaseOperationType~QUERY)
  self~status = .Error~NOTEXECUTED
  self~error = .Error~SUCCESS
  self~message = "DEFERRED"
  self~complete = .false

::method completeFrom
  use arg source
  self~status = source~status
  self~error = source~error
  self~message = source~message
  self~operationType = source~operationType
  self~rows = source~rows
  self~affectedRows = source~affectedRows
  self~accessPath = source~accessPath
  self~rowsScanned = source~rowsScanned
  self~snapshotGeneration = source~snapshotGeneration
  self~indexedThrough = source~indexedThrough
  self~leftIndexedThrough = source~leftIndexedThrough
  self~rightIndexedThrough = source~rightIndexedThrough
  self~metadata = source~metadata
  self~complete = .true
  return self

::method rollbackFailure
  use arg errorCode = .nil, message = "Transaction did not commit"
  if errorCode == .nil then errorCode = .Error~TRANSACTIONFAILED
  self~status = .Error~ROLLEDBACK
  self~error = errorCode
  self~message = message
  self~rows = .array~new
  self~affectedRows = 0
  self~complete = .true
  return self

::method discard
  use arg errorCode = .nil, message = "Transaction discarded before commit"
  if errorCode == .nil then errorCode = .Error~SUCCESS
  self~status = .Error~NOTEXECUTED
  self~error = errorCode
  self~message = message
  self~rows = .array~new
  self~affectedRows = 0
  self~complete = .true
  return self

::class DatabaseSavepoint public
::attribute name
::attribute operationCount
::attribute transactionToken

::method init
  use arg name, operationCount, transactionToken
  self~name = name
  self~operationCount = operationCount
  self~transactionToken = transactionToken

::class DatabasePreparedStatement public
::attribute name
::attribute sql
::attribute parameterCount
::attribute transactionToken
::attribute status
::attribute error

::method init
  use arg name, sql, parameterCount, transactionToken, status = .nil, error = .nil
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~name = name
  self~sql = sql
  self~parameterCount = parameterCount
  self~transactionToken = transactionToken
  self~status = status
  self~error = error

::class DatabasePreparedBatch public
::attribute statement
::attribute parameterSets
::attribute transactionToken

::method init
  use arg statement, transactionToken
  self~statement = statement
  self~transactionToken = transactionToken
  self~parameterSets = .array~new

::method add
  use arg parameters
  self~parameterSets~append(parameters)
  return self

::class DatabaseMutationGraph public
::attribute engine
::attribute stageEngine
::attribute stageRoot
::attribute baseSignature
::attribute token
::attribute state
::attribute message
::attribute activeKeys
::attribute operationCount

::method init
  use arg engine
  self~engine = engine
  self~token = .DateTime~new~string || "-graph-" || random(100000,999999)
  self~state = "OPEN"
  self~message = ""
  self~activeKeys = .table~new
  self~operationCount = 0
  clone = .DatabaseFileSystem~stableClone(engine~root, self~token)
  if clone == .nil then do
    self~state = "FAILED"
    self~message = "Unable to create staged mutation graph"
    self~stageRoot = ""
    self~baseSignature = ""
    self~stageEngine = .nil
    return
  end
  self~stageRoot = clone["path"]
  self~baseSignature = clone["signature"]
  self~stageEngine = .FileDatabaseEngine~new(self~stageRoot, self)

::method eventRegistry
  return self~engine~events

::method execute
  use arg sqlText
  if self~state \= "OPEN" then return self~failure(.DatabaseOperationType~OPERATION, self~message)
  rs = .NoSQLServerSQL~new(self~stageEngine)~execute(sqlText)
  self~operationCount += 1
  if rs~status \= .Error~SUCCESS then do
    self~state = "FAILED"
    self~message = rs~message
  end
  return rs

::method stageDeleteWhereEquals
  use arg tableName, column, wanted
  key = "DELETE|" || tableName~translate || "|" || column~translate || "|" || self~keyValue(wanted)
  if \self~enter(key) then return self~failure(.DatabaseOperationType~DELETE, self~message)
  rs = self~stageEngine~deleteWhereEquals(tableName, column, wanted)
  self~operationCount += 1
  self~leave(key)
  if rs~status \= .Error~SUCCESS then do
    self~state = "FAILED"
    self~message = rs~message
  end
  return rs

::method stageSetNullWhereEquals
  use arg tableName, column, wanted
  key = "SETNULL|" || tableName~translate || "|" || column~translate || "|" || self~keyValue(wanted)
  if \self~enter(key) then return self~failure(.DatabaseOperationType~UPDATE, self~message)
  assignments = .table~new
  assignments[column] = .nil
  rs = self~stageEngine~updateWhereEquals(tableName, column, wanted, assignments)
  self~operationCount += 1
  self~leave(key)
  if rs~status \= .Error~SUCCESS then do
    self~state = "FAILED"
    self~message = rs~message
  end
  return rs

::method stageUpdateWhereEquals
  use arg tableName, whereColumn, wanted, setColumn, newValue
  key = "UPDATE|" || tableName~translate || "|" || whereColumn~translate || "|" || self~keyValue(wanted) || "|" || setColumn~translate || "|" || self~keyValue(newValue)
  if \self~enter(key) then return self~failure(.DatabaseOperationType~UPDATE, self~message)
  assignments = .table~new
  assignments[setColumn] = newValue
  rs = self~stageEngine~updateWhereEquals(tableName, whereColumn, wanted, assignments)
  self~operationCount += 1
  self~leave(key)
  if rs~status \= .Error~SUCCESS then do
    self~state = "FAILED"
    self~message = rs~message
  end
  return rs

::method deleteWhereAndCommit
  use arg tableName, predicate
  if self~state \= "OPEN" then return self~failure(.DatabaseOperationType~DELETE, self~message)
  rs = self~stageEngine~deleteWhere(tableName, predicate)
  self~operationCount += 1
  if rs~status \= .Error~SUCCESS then do
    self~state = "FAILED"
    self~message = rs~message
    self~rollback
    return rs
  end
  affected = rs~affectedRows
  commitResult = self~commit
  if commitResult~status \= .Error~COMMITTED then return rs~fail(commitResult~error, commitResult~message)
  rs~affectedRows = affected
  return rs

::method updateWhereAndCommit
  use arg tableName, predicate, assignments
  if self~state \= "OPEN" then return self~failure(.DatabaseOperationType~UPDATE, self~message)
  rs = self~stageEngine~updateWhere(tableName, predicate, assignments)
  self~operationCount += 1
  if rs~status \= .Error~SUCCESS then do
    self~state = "FAILED"
    self~message = rs~message
    self~rollback
    return rs
  end
  affected = rs~affectedRows
  commitResult = self~commit
  if commitResult~status \= .Error~COMMITTED then return rs~fail(commitResult~error, commitResult~message)
  rs~affectedRows = affected
  return rs

::method commit
  if self~state \= "OPEN" then return self~failure(.DatabaseOperationType~COMMIT, "Mutation graph is not open")
  if .DatabaseFileSystem~signature(self~engine~root) \= self~baseSignature then do
    self~message = "Database changed while mutation graph was staged"
    self~state = "FAILED"
    self~discardStage
    return self~failure(.DatabaseOperationType~COMMIT, self~message, .Error~TRANSACTIONFAILED)
  end

  before = .DatabaseEvent~new(.DatabaseEventType~BEFORE_COMMIT, "*", "MUTATION_GRAPH", .array~new, self~stageEngine, .true)
  self~eventRegistry~dispatch(before)
  if before~vetoed then do
    self~message = before~vetoMessage
    self~state = "FAILED"
    self~discardStage
    return self~failure(.DatabaseOperationType~COMMIT, self~message, .Error~CONSTRAINT)
  end

  if \self~engine~runtime~beginTransactionPublish(self~engine~root, self~token) then do
    self~message = "Another transaction or mutation graph is publishing"
    self~state = "FAILED"
    self~discardStage
    return self~failure(.DatabaseOperationType~COMMIT, self~message, .Error~TIMEOUT)
  end

  publishResult = .DatabaseFileSystem~publishClone(self~engine~root, self~stageRoot, self~baseSignature)
  self~engine~runtime~endTransactionPublish(self~engine~root, self~token)
  if publishResult \= 0 then do
    self~message = "Unable to publish staged mutation graph"
    self~state = "FAILED"
    return self~failure(.DatabaseOperationType~COMMIT, self~message, .Error~TRANSACTIONFAILED)
  end

  self~stageRoot = ""
  self~state = "COMMITTED"
  afterEngine = .FileDatabaseEngine~new(self~engine~root)
  after = .DatabaseEvent~new(.DatabaseEventType~AFTER_COMMIT, "*", "MUTATION_GRAPH", .array~new, afterEngine, .false)
  signal on syntax name afterCommitIgnored
  self~eventRegistry~dispatch(after)
  signal off syntax
  rs = .DatabaseResult~new(.DatabaseOperationType~COMMIT)
  rs~status = .Error~COMMITTED
  rs~error = .Error~SUCCESS
  rs~message = "COMMITTED"
  return rs
afterCommitIgnored:
  signal off syntax
  rs = .DatabaseResult~new(.DatabaseOperationType~COMMIT)
  rs~status = .Error~COMMITTED
  rs~error = .Error~SUCCESS
  rs~message = "COMMITTED"
  return rs

::method rollback
  if self~stageRoot \= "" then self~discardStage
  if self~state \= "COMMITTED" then self~state = "ROLLED_BACK"
  rs = .DatabaseResult~new(.DatabaseOperationType~ROLLBACK)
  rs~status = .Error~NOTEXECUTED
  rs~error = .Error~SUCCESS
  rs~message = "DISCARDED"
  return rs

::method enter private
  use arg key
  if self~activeKeys[key] \== .nil then do
    self~state = "FAILED"
    self~message = "Mutation graph cycle detected: " || key
    return .false
  end
  self~activeKeys[key] = .true
  return .true

::method leave private
  use arg key
  self~activeKeys~remove(key)
  return .true

::method keyValue private
  use arg value
  if value == .nil then return "<NULL>"
  return value~string

::method discardStage private
  if self~stageRoot \= "" then do
    .DatabaseFileSystem~removeTree(self~stageRoot)
    self~stageRoot = ""
  end

::method failure private
  use arg operationType, message, errorCode
  if arg(3, "O") then errorCode = .Error~TRANSACTIONFAILED
  rs = .DatabaseResult~new(operationType)
  return rs~fail(errorCode, message)

::class DatabaseTransaction subclass NoSQLAlchemyObject public
::attribute engine
::attribute state
::attribute token
::attribute operations
::attribute prepared
::attribute savepoints
::attribute stageRoot
::attribute baseSignature
::attribute initError
::attribute lastMutationResults

::method init
  use arg engine, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("TRANSACTION", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("EXECUTE", "queue SQL in a staged transaction", "MUTATE")
  self~registerNoSQLMethod("COMMIT", "commit the staged mutation graph", "MUTATE")
  self~registerNoSQLMethod("ROLLBACK", "discard staged transaction state", "MUTATE")
  self~engine = engine
  self~state = "OPEN"
  self~token = .DateTime~new~string || "-" || random(100000,999999)
  self~operations = .array~new
  self~prepared = .table~new
  self~savepoints = .table~new
  self~lastMutationResults = .array~new
  self~initError = .nil
  stage = .DatabaseFileSystem~stableClone(engine~root, self~token)
  if stage == .nil then do
    self~state = "FAILED"
    self~initError = .Error~TRANSACTIONFAILED
    self~stageRoot = ""
    self~baseSignature = ""
  end
  else do
    self~stageRoot = stage["path"]
    self~baseSignature = stage["signature"]
  end

::method execute
  use arg sqlText
  if self~state \= "OPEN" then return self~invalidState("Transaction is not open")
  op = .table~new
  op["kind"] = "EXECUTE"
  op["sql"] = sqlText
  self~operations~append(op)
  rs = .DatabaseResult~new(.DatabaseOperationType~EXECUTE)
  rs~status = .Error~NOTEXECUTED
  rs~error = .Error~SUCCESS
  rs~message = "QUEUED"
  return rs

::method query
  use arg sqlText
  if self~state \= "OPEN" then do
    ref = .DatabaseDeferredQueryResult~new
    ref~status = .Error~NOTEXECUTED
    ref~error = .Error~INVALIDSTATE
    ref~message = "Transaction is not open"
    return ref
  end
  ref = .DatabaseDeferredQueryResult~new
  op = .table~new
  op["kind"] = "QUERY"
  op["sql"] = sqlText
  op["deferred"] = ref
  self~operations~append(op)
  return ref

::method savepoint
  use arg name
  if self~state \= "OPEN" then return self~invalidState("Transaction is not open")
  key = name~string~translate
  if self~savepoints[key] \== .nil then do
    rs = .DatabaseResult~new(.DatabaseOperationType~SAVEPOINT)
    return rs~fail(.Error~INVALIDSAVEPOINT, "Duplicate savepoint: " || name)
  end
  sp = .DatabaseSavepoint~new(name~string, self~operations~items, self~token)
  self~savepoints[key] = sp
  return sp

::method rollbackTo
  use arg savepoint
  if self~state \= "OPEN" then return self~invalidState("Transaction is not open")
  if savepoint == .nil then return self~invalidSavepoint("Missing savepoint")
  if \savepoint~isA(.DatabaseSavepoint) then return self~invalidSavepoint("Invalid savepoint object")
  if savepoint~transactionToken \= self~token then return self~invalidSavepoint("Savepoint belongs to another transaction")
  stored = self~savepoints[savepoint~name~translate]
  if stored == .nil then return self~invalidSavepoint("Unknown savepoint: " || savepoint~name)
  keep = .array~new
  do i = 1 to savepoint~operationCount
    keep~append(self~operations[i])
  end
  do i = savepoint~operationCount + 1 to self~operations~items
    op = self~operations[i]
    ref = op["deferred"]
    if ref \== .nil then ref~discard(.Error~INVALIDSAVEPOINT, "Deferred query removed by rollback to savepoint")
  end
  self~operations = keep
  -- Savepoints created after the target are no longer valid.
  keys = self~savepoints~allIndexes
  do key over keys
    candidate = self~savepoints[key]
    if candidate~operationCount > savepoint~operationCount then self~savepoints~remove(key)
  end
  rs = .DatabaseResult~new(.DatabaseOperationType~ROLLBACKTOSAVEPOINT)
  rs~status = .Error~NOTEXECUTED
  rs~error = .Error~SUCCESS
  rs~message = "STAGED STATE REWOUND"
  return rs

::method prepareStatement
  use arg name, sqlText
  if self~state \= "OPEN" then return .DatabasePreparedStatement~new(name, sqlText, 0, self~token, .Error~NOTEXECUTED, .Error~INVALIDSTATE)
  key = name~string~translate
  if self~prepared[key] \== .nil then return .DatabasePreparedStatement~new(name, sqlText, 0, self~token, .Error~NOTEXECUTED, .Error~DUPLICATEPREPARED)
  count = .DatabaseParameterBinder~countPlaceholders(sqlText)
  ps = .DatabasePreparedStatement~new(name~string, sqlText~string, count, self~token)
  self~prepared[key] = ps
  return ps

::method executePrepared
  use arg statement, parameters
  if self~state \= "OPEN" then return self~invalidState("Transaction is not open")
  validation = self~validatePrepared(statement, parameters)
  if validation \== .nil then return validation
  op = .table~new
  op["kind"] = "PREPARED"
  op["statement"] = statement
  op["parameters"] = parameters
  self~operations~append(op)
  rs = .DatabaseResult~new(.DatabaseOperationType~PREPAREDEXECUTION)
  rs~status = .Error~NOTEXECUTED
  rs~error = .Error~SUCCESS
  rs~message = "QUEUED"
  return rs

::method prepareBatch
  use arg statement
  return .DatabasePreparedBatch~new(statement, self~token)

::method executePreparedBatch
  use arg batch
  if self~state \= "OPEN" then return self~invalidState("Transaction is not open")
  if batch == .nil then return self~prepareFailure(.Error~PREPAREFAILED, "Missing prepared batch")
  if \batch~isA(.DatabasePreparedBatch) then return self~prepareFailure(.Error~PREPAREFAILED, "Invalid prepared batch")
  if batch~transactionToken \= self~token then return self~prepareFailure(.Error~PREPAREFAILED, "Prepared batch belongs to another transaction")
  do parameters over batch~parameterSets
    validation = self~validatePrepared(batch~statement, parameters)
    if validation \== .nil then return validation
  end
  op = .table~new
  op["kind"] = "PREPARED_BATCH"
  op["batch"] = batch
  self~operations~append(op)
  rs = .DatabaseResult~new(.DatabaseOperationType~PREPAREDBATCH)
  rs~status = .Error~NOTEXECUTED
  rs~error = .Error~SUCCESS
  rs~message = "QUEUED"
  return rs

::method validatePrepared private
  use arg statement, parameters
  if statement == .nil then return self~prepareFailure(.Error~PREPAREFAILED, "Missing prepared statement")
  if \statement~isA(.DatabasePreparedStatement) then return self~prepareFailure(.Error~PREPAREFAILED, "Invalid prepared statement")
  if statement~transactionToken \= self~token then return self~prepareFailure(.Error~PREPAREFAILED, "Prepared statement belongs to another transaction")
  declared = self~prepared[statement~name~translate]
  if declared == .nil then return self~prepareFailure(.Error~PREPAREFAILED, "Prepared statement has not been declared")
  if statement~error \= .Error~SUCCESS then return self~prepareFailure(statement~error, "Prepared statement declaration failed")
  if parameters == .nil then count = 0
  else count = parameters~items
  if count \= statement~parameterCount then return self~prepareFailure(.Error~PARAMETERCOUNT, "Prepared parameter count mismatch")
  if parameters \== .nil then do parameter over parameters
    if parameter~isA(.DatabaseValue) then do
      if parameter~typeName~startsWith("INVALID:") then return self~prepareFailure(.Error~INVALIDPARAMETER, "Invalid prepared parameter")
    end
  end
  return .nil

::method commit
  self~lastMutationResults = .array~new
  if self~state \= "OPEN" then return self~invalidState("Transaction cannot be committed in state " || self~state)
  if self~initError \== .nil then do
    self~state = "FAILED"
    return self~prepareFailure(.Error~TRANSACTIONFAILED, "Unable to create transaction snapshot")
  end
  if .DatabaseFileSystem~signature(self~engine~root) \= self~baseSignature then do
    self~discardStage
    self~state = "FAILED"
    return self~prepareFailure(.Error~TRANSACTIONFAILED, "Database changed after transaction began")
  end

  stageEngine = .FileDatabaseEngine~new(self~stageRoot)
  stageSql = .NoSQLServerSQL~new(stageEngine)
  completedQueries = .array~new
  do op over self~operations
    kind = op["kind"]
    select
      when kind = "EXECUTE" then opResult = stageSql~execute(op["sql"])
      when kind = "QUERY" then opResult = stageSql~execute(op["sql"])
      when kind = "PREPARED" then do
        bound = .DatabaseParameterBinder~bind(op["statement"], op["parameters"])
        if bound~isA(.DatabaseResult) then opResult = bound
        else opResult = stageSql~execute(bound)
      end
      when kind = "PREPARED_BATCH" then do
        opResult = .DatabaseResult~new(.DatabaseOperationType~PREPAREDBATCH)
        do parameters over op["batch"]~parameterSets
          bound = .DatabaseParameterBinder~bind(op["batch"]~statement, parameters)
          if bound~isA(.DatabaseResult) then do
            opResult = bound
            leave
          end
          oneResult = stageSql~execute(bound)
          if oneResult~status \= .Error~SUCCESS then do
            opResult = oneResult
            leave
          end
          if self~isMutationOperation(oneResult~operationType) then self~lastMutationResults~append(oneResult)
          opResult~affectedRows += oneResult~affectedRows
        end
      end
      otherwise opResult = self~prepareFailure(.Error~INVALIDOPERATION, "Unknown transaction operation")
    end
    if opResult~status \= .Error~SUCCESS then do
      self~rollbackDeferred(.Error~TRANSACTIONFAILED, "Transaction operation failed: " || opResult~error)
      self~discardStage
      self~state = "FAILED"
      rs = .DatabaseResult~new(.DatabaseOperationType~COMMIT)
      rs~status = .Error~ROLLEDBACK
      rs~error = .Error~TRANSACTIONFAILED
      rs~message = opResult~message
      return rs
    end
    if kind \= "PREPARED_BATCH" then do
      if self~isMutationOperation(opResult~operationType) then self~lastMutationResults~append(opResult)
    end
    if kind = "QUERY" then do
      pair = .table~new
      pair["ref"] = op["deferred"]
      pair["result"] = opResult
      completedQueries~append(pair)
    end
  end

  if .DatabaseFileSystem~signature(self~engine~root) \= self~baseSignature then do
    self~rollbackDeferred(.Error~TRANSACTIONFAILED, "Database changed during transaction commit")
    self~discardStage
    self~state = "FAILED"
    rs = .DatabaseResult~new(.DatabaseOperationType~COMMIT)
    rs~status = .Error~ROLLEDBACK
    rs~error = .Error~TRANSACTIONFAILED
    rs~message = "Database changed during transaction commit"
    return rs
  end

  if \self~engine~runtime~beginTransactionPublish(self~engine~root, self~token) then do
    self~rollbackDeferred(.Error~TIMEOUT, "Another transaction is publishing")
    self~discardStage
    self~state = "FAILED"
    return self~prepareFailure(.Error~TIMEOUT, "Another transaction is publishing")
  end

  publishResult = .DatabaseFileSystem~publishClone(self~engine~root, self~stageRoot, self~baseSignature)
  self~engine~runtime~endTransactionPublish(self~engine~root, self~token)
  if publishResult \= 0 then do
    if publishResult = 10 then publishMessage = "Database changed during transaction publication"
    else publishMessage = "Unable to publish transaction"
    self~rollbackDeferred(.Error~TRANSACTIONFAILED, publishMessage)
    self~state = "FAILED"
    rs = .DatabaseResult~new(.DatabaseOperationType~COMMIT)
    rs~status = .Error~ROLLEDBACK
    rs~error = .Error~TRANSACTIONFAILED
    rs~message = publishMessage
    return rs
  end
  self~stageRoot = ""
  do pair over completedQueries
    pair["ref"]~completeFrom(pair["result"])
  end
  self~state = "COMMITTED"
  rs = .DatabaseResult~new(.DatabaseOperationType~COMMIT)
  rs~status = .Error~COMMITTED
  rs~error = .Error~SUCCESS
  rs~message = "COMMITTED"
  return rs

::method rollback
  if self~state \= "OPEN" then return self~invalidState("Transaction cannot be rolled back in state " || self~state)
  do op over self~operations
    ref = op["deferred"]
    if ref \== .nil then ref~discard(.Error~SUCCESS, "Transaction discarded before commit")
  end
  self~discardStage
  self~state = "ROLLED_BACK"
  rs = .DatabaseResult~new(.DatabaseOperationType~ROLLBACK)
  rs~status = .Error~NOTEXECUTED
  rs~error = .Error~SUCCESS
  rs~message = "DISCARDED"
  return rs

::method isMutationOperation private
  use arg operationType
  if operationType == .nil then return .false
  if operationType = .DatabaseOperationType~INSERT then return .true
  if operationType = .DatabaseOperationType~UPDATE then return .true
  if operationType = .DatabaseOperationType~DELETE then return .true
  return .false

::method rollbackDeferred private
  use arg errorCode, message
  do op over self~operations
    ref = op["deferred"]
    if ref \== .nil then ref~rollbackFailure(errorCode, message)
  end

::method discardStage private
  if self~stageRoot \= "" then do
    .DatabaseFileSystem~removeTree(self~stageRoot)
    self~stageRoot = ""
  end

::method invalidState private
  use arg message
  rs = .DatabaseResult~new(.DatabaseOperationType~OPERATION)
  return rs~fail(.Error~INVALIDSTATE, message)

::method invalidSavepoint private
  use arg message
  rs = .DatabaseResult~new(.DatabaseOperationType~ROLLBACKTOSAVEPOINT)
  return rs~fail(.Error~INVALIDSAVEPOINT, message)

::method prepareFailure private
  use arg code, message
  rs = .DatabaseResult~new(.DatabaseOperationType~PREPAREDSTATEMENT)
  return rs~fail(code, message)

::class DatabaseParameterBinder public
::method countPlaceholders class
  use arg sqlText
  count = 0
  quote = ""
  i = 1
  do while i <= sqlText~length
    ch = sqlText~substr(i,1)
    if quote \= "" then do
      if ch = quote then do
        if i < sqlText~length then do
          if sqlText~substr(i+1,1) = quote then do
            i += 2
            iterate
          end
        end
        quote = ""
      end
      i += 1
      iterate
    end
    if ch = "'" | ch = '"' then quote = ch
    else if ch = "?" then count += 1
    i += 1
  end
  return count

::method bind class
  use arg statement, parameters
  if parameters == .nil then parameters = .array~new
  if parameters~items \= statement~parameterCount then do
    rs = .DatabaseResult~new(.DatabaseOperationType~PREPAREDEXECUTION)
    return rs~fail(.Error~PARAMETERCOUNT, "Prepared parameter count mismatch")
  end
  out = ""
  quote = ""
  p = 1
  i = 1
  sqlText = statement~sql
  do while i <= sqlText~length
    ch = sqlText~substr(i,1)
    if quote \= "" then do
      out ||= ch
      if ch = quote then do
        if i < sqlText~length then do
          if sqlText~substr(i+1,1) = quote then do
            out ||= quote
            i += 2
            iterate
          end
        end
        quote = ""
      end
      i += 1
      iterate
    end
    if ch = "'" | ch = '"' then do
      quote = ch
      out ||= ch
    end
    else if ch = "?" then do
      rendered = self~render(parameters[p])
      if rendered~isA(.DatabaseResult) then return rendered
      out ||= rendered
      p += 1
    end
    else out ||= ch
    i += 1
  end
  return out

::method render class private
  use arg parameter
  if parameter == .nil then return "NULL"
  if parameter~isA(.DatabaseValue) then value = parameter
  else value = .DatabaseValue~unknown(parameter)
  if value~typeName~startsWith("INVALID:") then do
    rs = .DatabaseResult~new(.DatabaseOperationType~PREPAREDEXECUTION)
    return rs~fail(.Error~INVALIDPARAMETER, "Invalid prepared parameter")
  end
  if value~null then return "NULL"
  typeName = value~typeName~translate
  select
    when typeName = .DatabaseType~INTEGER then do
      if \datatype(value~value~string, "W") then return self~invalidParameter("Invalid INTEGER parameter")
      return value~value~string
    end
    when typeName = .DatabaseType~DECIMAL then do
      if \datatype(value~value~string, "N") then return self~invalidParameter("Invalid DECIMAL parameter")
      return value~value~string
    end
    when typeName = .DatabaseType~BOOLEAN then do
      u = value~value~string~translate
      if u = "TRUE" | u = "FALSE" then return u
      return self~invalidParameter("Invalid BOOLEAN parameter")
    end
    when typeName = .DatabaseType~VARCHAR then return self~quoteText(value~value)
    when typeName = .DatabaseType~DATE then return self~quoteText(value~value)
    when typeName = .DatabaseType~DATETIME then return self~quoteText(value~value)
    when typeName = .DatabaseType~BLOB then return self~quoteText(value~value)
    when typeName = .DatabaseType~UNKNOWN then return self~quoteText(value~value)
    otherwise return self~invalidParameter("Unsupported parameter type")
  end

::method quoteText class private
  use arg value
  return "'" || value~string~changeStr("'", "''") || "'"

::method invalidParameter class private
  use arg message
  rs = .DatabaseResult~new(.DatabaseOperationType~PREPAREDEXECUTION)
  return rs~fail(.Error~INVALIDPARAMETER, message)

::class DatabaseFileSystem public
::method canonicalRoot class
  use arg source
  source = source~string~strip
  do while source~right(1) = "/"
    source = source~left(source~length - 1)
  end
  call SysFileTree source || "/database.yaml", "anchor.", "FO"
  if anchor.0 \= 1 then return source
  marker = "/database.yaml"
  markerPos = anchor.1~lastpos(marker)
  if markerPos = 0 then return source
  return anchor.1~left(markerPos - 1)

::method signature class
  use arg source
  root = self~canonicalRoot(source)
  catalogPath = root || "/database.yaml"
  if stream(catalogPath, "c", "query exists") = "" then return "MISSING"
  raw = .Yaml~new~parseFile(catalogPath)
  sig = "format=" || raw["formatVersion"] || ";"
  names = raw["tables"]
  if names == .nil then return sig
  do name over names
    tablePath = root || "/tables/" || name || "/table.yaml"
    if stream(tablePath, "c", "query exists") = "" then do
      sig ||= name || ":MISSING;"
      iterate
    end
    t = .Yaml~new~parseFile(tablePath)
    generation = t["generation"]
    if generation == .nil then generation = 0
    rowCount = t["rowCount"]
    if rowCount == .nil then rowCount = "?"
    sig ||= name || ":" || generation || ":" || rowCount || ";"
  end
  return sig

::method stableClone class
  use arg source, token = "tx"
  root = self~canonicalRoot(source)
  do attempt = 1 to 8
    before = self~signature(root)
    target = SysTempFileName(root || ".txn-??????")
    if SysMkDir(target) \= 0 then return .nil
    if self~copyTree(root, target) \= 0 then do
      self~removeTree(target)
      return .nil
    end
    after = self~signature(root)
    cloneSig = self~signature(target)
    if before = after then do
      if cloneSig = before then do
        answer = .table~new
        answer["path"] = target
        answer["signature"] = before
        return answer
      end
    end
    self~removeTree(target)
  end
  return .nil

::method copyTree class
  use arg source, target
  call SysFileTree source || "/*", "dirs.", "DOS"
  do i = 1 to dirs.0
    relative = dirs.i~substr(source~length + 1)
    rc = SysMkDir(target || relative)
    if rc \= 0 then do
      if stream(target || relative, "c", "query exists") = "" then return rc
    end
  end
  call SysFileTree source || "/*", "files.", "FOS"
  do i = 1 to files.0
    relative = files.i~substr(source~length + 1)
    rc = SysFileCopy(files.i, target || relative)
    if rc \= 0 then return rc
  end
  return 0

::method removeTree class
  use arg target
  if target == .nil then return 0
  if target = "" then return 0
  call SysFileTree target || "/*", "files.", "FOS"
  do i = 1 to files.0
    call SysFileDelete files.i
  end
  call SysFileTree target || "/*", "dirs.", "DOS"
  do i = dirs.0 to 1 by -1
    call SysRmDir dirs.i
  end
  call SysRmDir target
  return 0

::method publicationJournalPath class
  use arg liveRoot
  root = self~canonicalRoot(liveRoot)
  return root || ".txpublish.yaml"

::method writePublicationIntent class private
  use arg liveRoot, stageRoot, backupRoot, expectedSignature
  journalPath = self~publicationJournalPath(liveRoot)
  tmp = SysTempFileName(journalPath || ".new-??????")
  raw = .table~new
  raw["formatVersion"] = 1
  raw["liveRoot"] = liveRoot
  raw["stageRoot"] = stageRoot
  raw["backupRoot"] = backupRoot
  raw["expectedSignature"] = expectedSignature
  raw["created"] = .DateTime~new~string
  .Yaml~toYamlFile(raw, tmp)
  moveRc = SysFileMove(tmp, journalPath)
  if moveRc \= 0 then do
    call SysFileDelete tmp
    return moveRc
  end
  return 0

::method recoverPublication class
  use arg source
  liveRoot = self~canonicalRoot(source)
  journalPath = liveRoot || ".txpublish.yaml"
  if stream(journalPath, "c", "query exists") = "" then return 0

  signal on syntax name recoveryBroken
  raw = .Yaml~new~parseFile(journalPath)
  stageRoot = raw["stageRoot"]
  backupRoot = raw["backupRoot"]
  expectedSignature = raw["expectedSignature"]
  if stageRoot == .nil | backupRoot == .nil | expectedSignature == .nil then signal recoveryBroken

  liveExists = (stream(liveRoot || "/database.yaml", "c", "query exists") \= "")
  stageExists = (stream(stageRoot || "/database.yaml", "c", "query exists") \= "")
  backupExists = (stream(backupRoot || "/database.yaml", "c", "query exists") \= "")

  -- Intent exists but live was never renamed.  Commit only if the live
  -- database still matches the transaction's original snapshot.
  if liveExists & stageExists & \backupExists then do
    if self~signature(liveRoot) \= expectedSignature then do
      self~removeTree(stageRoot)
      call SysFileDelete journalPath
      return 20
    end
    moveLive = SysFileMove(liveRoot, backupRoot)
    if moveLive \= 0 then return 21
    backupExists = .true
    liveExists = .false
  end

  -- The authoritative tree has been renamed away.  The backup must still
  -- be the exact snapshot we intended to replace before the stage may win.
  if \liveExists & backupExists & stageExists then do
    if self~signature(backupRoot) \= expectedSignature then do
      call SysFileMove backupRoot, liveRoot
      self~removeTree(stageRoot)
      call SysFileDelete journalPath
      return 22
    end
    moveStage = SysFileMove(stageRoot, liveRoot)
    if moveStage \= 0 then do
      call SysFileMove backupRoot, liveRoot
      return 23
    end
    liveExists = .true
    stageExists = .false
  end

  -- Stage already became live: publication is committed; only cleanup was
  -- interrupted.  A missing stage with only a backup means publication could
  -- not complete, so restore the old authoritative tree instead.
  if liveExists & backupExists & \stageExists then do
    self~removeTree(backupRoot)
    call SysFileDelete journalPath
    return 1
  end
  if \liveExists & backupExists & \stageExists then do
    restoreRc = SysFileMove(backupRoot, liveRoot)
    if restoreRc = 0 then call SysFileDelete journalPath
    return 2
  end

  -- A fully recovered/rolled-back state can leave only the journal behind.
  if liveExists & \backupExists & \stageExists then do
    call SysFileDelete journalPath
    return 3
  end

  -- If both live and stage exist after a failed publication rollback and the
  -- live signature is still the base snapshot, discard the unpublished stage.
  if liveExists & stageExists & \backupExists then do
    if self~signature(liveRoot) = expectedSignature then do
      self~removeTree(stageRoot)
      call SysFileDelete journalPath
      return 4
    end
  end
  return 24

recoveryBroken:
  return 25

::method publishClone class
  use arg liveRoot, stageRoot, expectedSignature
  liveRoot = self~canonicalRoot(liveRoot)
  recoveryRc = self~recoverPublication(liveRoot)
  journalPath = self~publicationJournalPath(liveRoot)
  if stream(journalPath, "c", "query exists") \= "" then return 13
  if self~signature(liveRoot) \= expectedSignature then return 10
  backup = SysTempFileName(liveRoot || ".backup-??????")
  -- SysTempFileName reserves a pathname.  Publication needs that pathname to
  -- be available for the directory rename.
  if stream(backup, "c", "query exists") \= "" then call SysFileDelete backup
  intentRc = self~writePublicationIntent(liveRoot, stageRoot, backup, expectedSignature)
  if intentRc \= 0 then return 14

  moveLive = SysFileMove(liveRoot, backup)
  if moveLive \= 0 then do
    call SysFileDelete journalPath
    return 11
  end
  if self~signature(backup) \= expectedSignature then do
    call SysFileMove backup, liveRoot
    call SysFileDelete journalPath
    return 15
  end

  moveStage = SysFileMove(stageRoot, liveRoot)
  if moveStage \= 0 then do
    call SysFileMove backup, liveRoot
    return 12
  end
  self~removeTree(backup)
  call SysFileDelete journalPath
  return 0

::class SQLDatabase subclass NoSQLServerSQL public


/* -------------------------------------------------------------------------
   database_core compatibility facade (v0.22 baseline, v0.34 extensions)

   These classes are deliberately namespaced.  Do not ::requires database_core
   alongside NoSQLServer.cls: both packages publish several same-named classes
   with different method semantics.  The facade maps observable contracts while
   retaining FileDatabaseEngine / DatabaseRow / DatabaseResult native behavior.
   v0.69 extends this facade with the v0.34 relational-source shape and spatial
   metadata/value fields without claiming binary class identity with DB Core.
   ------------------------------------------------------------------------- */

::class NoSQLDatabaseCoreIsolation public
::constant DEFAULT          "DEFAULT"
::constant READUNCOMMITTED  "READUNCOMMITTED"
::constant READCOMMITTED    "READCOMMITTED"
::constant REPEATABLEREAD   "REPEATABLEREAD"
::constant SERIALIZABLE     "SERIALIZABLE"

::class NoSQLDatabaseCoreAccessMode public
::constant DEFAULT    "DEFAULT"
::constant READONLY   "READONLY"
::constant READWRITE  "READWRITE"

::class NoSQLDatabaseCoreSpatialEncoding public
::constant OPAQUE       "OPAQUE"
::constant WKT          "WKT"
::constant WKBHEX       "WKBHEX"
::constant EWKBHEX      "EWKBHEX"
::constant GPKGBLOBHEX  "GPKGBLOBHEX"

::class NoSQLDatabaseCoreValue public
::attribute nativeValue
::attribute raw
::attribute rawValue
::attribute value
::attribute typeName
::attribute isNull
::attribute null
::attribute geometryType
::attribute srid
::attribute encoding

::method init
  use arg nativeValue
  self~nativeValue = nativeValue
  self~geometryType = ""
  self~srid = 0
  self~encoding = .NoSQLDatabaseCoreSpatialEncoding~OPAQUE
  if nativeValue == .nil then do
    self~raw = .nil
    self~rawValue = .nil
    self~value = .nil
    self~typeName = .DatabaseType~NULL
    self~isNull = .true
    self~null = .true
    return
  end
  self~raw = nativeValue~rawValue
  self~rawValue = nativeValue~rawValue
  self~value = nativeValue~value
  self~typeName = nativeValue~typeName
  if self~typeName = .DatabaseType~BOOLEAN then do
    u = nativeValue~value~string~translate
    if u = "TRUE" | u = "1" then self~value = .true
    else if u = "FALSE" | u = "0" then self~value = .false
  end
  if self~typeName = .DatabaseType~GEOMETRY then do
    if nativeValue~hasMethod("geometryType") then self~geometryType = nativeValue~geometryType
    if nativeValue~hasMethod("srid") then self~srid = nativeValue~srid
    if nativeValue~hasMethod("encoding") then self~encoding = nativeValue~encoding
    geometryObject = nativeValue~value
    if geometryObject \== .nil then do
      if geometryObject~hasMethod("geometryType") then self~geometryType = geometryObject~geometryType
      if geometryObject~hasMethod("srid") then self~srid = geometryObject~srid
      if geometryObject~hasMethod("hex") then do
        self~raw = geometryObject~hex
        self~rawValue = geometryObject~hex
        self~encoding = .NoSQLDatabaseCoreSpatialEncoding~GPKGBLOBHEX
      end
    end
  end
  self~isNull = nativeValue~null
  self~null = nativeValue~null

::method string
  if self~isNull then return "NULL"
  if self~typeName = .DatabaseType~GEOMETRY then do
    type = self~geometryType
    if type = "" then type = .DatabaseType~GEOMETRY
    return type || "(SRID=" || self~srid || "," || self~encoding || "=" || self~raw~string~left(24) || "...)"
  end
  if self~raw == .nil then return ""
  return self~raw~string

::class NoSQLDatabaseCoreGeometryValue public subclass NoSQLDatabaseCoreValue
::method init
  use arg nativeValue
  self~init:super(nativeValue)

::class NoSQLDatabaseCoreRow public
::attribute nativeRow
::attribute columnNames

::method init
  use arg nativeRow, columnNames = .nil
  self~nativeRow = nativeRow
  if columnNames == .nil then columnNames = .array~new
  self~columnNames = columnNames

::method at
  use arg name
  if self~nativeRow == .nil then return .nil
  nativeValue = self~nativeRow~valueAt(name)
  if nativeValue == .nil then return .nil
  if nativeValue~typeName = .DatabaseType~GEOMETRY then return .NoSQLDatabaseCoreGeometryValue~new(nativeValue)
  return .NoSQLDatabaseCoreValue~new(nativeValue)

::method rawAt
  use arg name
  if self~nativeRow == .nil then return .nil
  return self~nativeRow~rawAt(name)

::method valueAt
  use arg name
  item = self~at(name)
  if item == .nil then return .nil
  return item~value

::class NoSQLDatabaseCoreColumnMetadata public
::attribute nativeMetadata
::attribute name
::attribute engineType
::attribute databaseType
::attribute nullable
::attribute ordinal
::attribute geometryType
::attribute srid

::method init
  use arg nativeMetadata = .nil, name = "", engineType = "", databaseType = .nil, nullable = .true, ordinal = 0, geometryType = "", srid = 0
  self~nativeMetadata = nativeMetadata
  if nativeMetadata \== .nil then do
    self~name = nativeMetadata~name
    self~engineType = nativeMetadata~nativeType
    self~databaseType = nativeMetadata~commonType
    self~nullable = nativeMetadata~nullable
    self~ordinal = nativeMetadata~ordinalPosition
    self~geometryType = ""
    self~srid = 0
    if nativeMetadata~hasMethod("geometryType") then self~geometryType = nativeMetadata~geometryType
    if nativeMetadata~hasMethod("srid") then self~srid = nativeMetadata~srid
  end
  else do
    self~name = name
    self~engineType = engineType
    if databaseType == .nil then databaseType = .DatabaseType~UNKNOWN
    self~databaseType = databaseType
    self~nullable = nullable
    self~ordinal = ordinal
    self~geometryType = geometryType
    self~srid = srid
  end

::class NoSQLDatabaseCoreResultMetadata public
::attribute columns

::method init
  use arg columns = .nil
  if columns == .nil then columns = .array~new
  self~columns = columns

::method add
  use arg column
  self~columns~append(column)
  return column

::method types
  out = .array~new
  do column over self~columns
    out~append(column~databaseType)
  end
  return out

::class NoSQLDatabaseCoreResultSchema public
::attribute columns

::method init
  self~columns = .array~new

::method add
  use arg name, databaseType = .nil
  if databaseType == .nil then databaseType = .DatabaseType~UNKNOWN
  self~columns~append(.NoSQLDatabaseCoreColumnMetadata~new(.nil, name, "", databaseType, .true, self~columns~items + 1))
  return self

::method types
  out = .array~new
  do column over self~columns
    out~append(column~databaseType)
  end
  return out

::class NoSQLDatabaseCoreResult public
::attribute status
::attribute error
::attribute success
::attribute warnings
::attribute message
::attribute nativeResult

::method init
  use arg status = .nil, error = .nil, nativeResult = .nil, message = ""
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~status = status
  self~error = error
  self~success = (status = .Error~SUCCESS)
  self~warnings = .array~new
  self~nativeResult = nativeResult
  self~message = message

::class NoSQLDatabaseCoreQueryResult subclass NoSQLDatabaseCoreResult public
::attribute columns
::attribute columnTypes
::attribute rows
::attribute rowCount
::attribute metadata
::attribute accessPath
::attribute rowsScanned

::method init
  use arg status = .nil, error = .nil, columns = .nil, rows = .nil, columnTypes = .nil, metadata = .nil, nativeResult = .nil, message = ""
  self~init:super(status, error, nativeResult, message)
  if columns == .nil then columns = .array~new
  if rows == .nil then rows = .array~new
  if columnTypes == .nil then columnTypes = .array~new
  if metadata == .nil then metadata = .NoSQLDatabaseCoreResultMetadata~new
  self~columns = columns
  self~columnTypes = columnTypes
  self~rows = rows
  self~rowCount = rows~items
  self~metadata = metadata
  if nativeResult == .nil then do
    self~accessPath = ""
    self~rowsScanned = 0
  end
  else do
    self~accessPath = nativeResult~accessPath
    self~rowsScanned = nativeResult~rowsScanned
  end

::class NoSQLDatabaseCoreMutationResult subclass NoSQLDatabaseCoreResult public
::attribute affectedRows
::attribute generatedKey

::method init
  use arg status = .nil, error = .nil, affectedRows = 0, generatedKey = .nil, nativeResult = .nil, message = ""
  self~init:super(status, error, nativeResult, message)
  self~affectedRows = affectedRows
  self~generatedKey = generatedKey

::class NoSQLDatabaseCoreTransactionResult subclass NoSQLDatabaseCoreResult public
::attribute outcome
::attribute operationCount
::attribute attemptCount
::attribute mutationResults

::method init
  use arg outcome = .nil, error = .nil, operationCount = 0, attemptCount = 1, mutationResults = .nil, nativeResult = .nil, message = ""
  if outcome == .nil then outcome = .Error~UNKNOWN
  if error == .nil then error = .Error~SUCCESS
  if outcome = .Error~COMMITTED then status = .Error~SUCCESS
  else status = outcome
  if mutationResults == .nil then mutationResults = .array~new
  self~init:super(status, error, nativeResult, message)
  self~outcome = outcome
  self~operationCount = operationCount
  self~attemptCount = attemptCount
  self~mutationResults = mutationResults

::method committed
  return self~outcome = .Error~COMMITTED

::method rolledBack
  return self~outcome = .Error~ROLLEDBACK

::method retried
  return self~attemptCount > 1

::class NoSQLDatabaseCoreDeferredResult public
::attribute result
::attribute resolved
::attribute resultSchema

::method init
  use arg resultSchema = .nil
  self~result = .nil
  self~resolved = .false
  self~resultSchema = resultSchema

::method resolve
  use arg value
  self~result = value
  self~resolved = .true
  return value

::class NoSQLDatabaseCorePreparedStatement public
::attribute name
::attribute sql
::attribute scope
::attribute parameterCount
::attribute status
::attribute error

::method init
  use arg name, sql, scope = "transaction", status = .nil, error = .nil
  if status == .nil then status = .Error~SUCCESS
  if error == .nil then error = .Error~SUCCESS
  self~name = name~string
  self~sql = sql~string
  self~scope = scope~string
  self~parameterCount = .DatabaseParameterBinder~countPlaceholders(sql)
  self~status = status
  self~error = error

::class NoSQLDatabaseCorePreparedBatch public
::attribute statement
::attribute parameterSets

::method init
  use arg statement
  self~statement = statement
  self~parameterSets = .array~new

::method add
  use arg parameters
  self~parameterSets~append(parameters)
  return parameters

::method count
  return self~parameterSets~items

::class NoSQLDatabaseCoreSavepoint public
::attribute name
::attribute operationCount
::attribute transactionToken

::method init
  use arg name, operationCount, transactionToken
  self~name = name
  self~operationCount = operationCount
  self~transactionToken = transactionToken

::class NoSQLDatabaseCoreTransaction public
::attribute adapter
::attribute engine
::attribute operations
::attribute deferredResults
::attribute prepared
::attribute savepoints
::attribute state
::attribute retryAttempts
::attribute isolationLevel
::attribute accessMode
::attribute token
::attribute firstNativeTransaction
::attribute logicalOperationCount

::method init
  use arg adapter
  self~adapter = adapter
  self~engine = adapter~engine
  self~operations = .array~new
  self~deferredResults = .array~new
  self~prepared = .table~new
  self~savepoints = .table~new
  self~state = "building"
  self~retryAttempts = 1
  self~isolationLevel = .NoSQLDatabaseCoreIsolation~DEFAULT
  self~accessMode = .NoSQLDatabaseCoreAccessMode~DEFAULT
  self~token = .DateTime~new~string || "-" || random(100000,999999)
  self~firstNativeTransaction = self~engine~transaction
  self~logicalOperationCount = 0

::method isolation
  use arg level
  if self~state \= "building" then return .Error~INVALIDSTATE
  if level = .NoSQLDatabaseCoreIsolation~DEFAULT | level = .NoSQLDatabaseCoreIsolation~SERIALIZABLE then do
    self~isolationLevel = level
    return .Error~SUCCESS
  end
  return .Error~UNSUPPORTED

::method readOnly
  if self~state \= "building" then return .Error~INVALIDSTATE
  self~accessMode = .NoSQLDatabaseCoreAccessMode~READONLY
  return .Error~SUCCESS

::method readWrite
  if self~state \= "building" then return .Error~INVALIDSTATE
  self~accessMode = .NoSQLDatabaseCoreAccessMode~READWRITE
  return .Error~SUCCESS

::method setTimeout
  use arg seconds
  if self~state \= "building" then return .Error~INVALIDSTATE
  return .Error~UNSUPPORTED

::method setRetryAttempts
  use arg attempts
  if self~state \= "building" then return .Error~INVALIDSTATE
  if \datatype(attempts~string, "W") then return .Error~INVALIDARGUMENT
  if attempts < 1 then return .Error~INVALIDARGUMENT
  self~retryAttempts = attempts
  return .Error~SUCCESS

::method execute
  use arg sqlText
  if self~state \= "building" then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE)
  if self~accessMode = .NoSQLDatabaseCoreAccessMode~READONLY then do
    if self~adapter~isMutationSQL(sqlText) then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDOPERATION, .nil, "Read-only transaction rejects mutation")
  end
  op = .table~new
  op["kind"] = "EXECUTE"
  op["sql"] = sqlText
  self~operations~append(op)
  self~logicalOperationCount += 1
  return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~SUCCESS, .nil, "QUEUED")

::method query
  use arg sqlText
  return self~queryWithSchema(sqlText, .nil)

::method queryWithSchema
  use arg sqlText, resultSchema
  if self~state \= "building" then return .NoSQLDatabaseCoreDeferredResult~new(resultSchema)
  ref = .NoSQLDatabaseCoreDeferredResult~new(resultSchema)
  op = .table~new
  op["kind"] = "QUERY"
  op["sql"] = sqlText
  op["deferred"] = ref
  op["schema"] = resultSchema
  self~operations~append(op)
  self~deferredResults~append(ref)
  self~logicalOperationCount += 1
  return ref

::method prepareStatement
  use arg name, sqlText, scope = "transaction"
  if self~state \= "building" then return .NoSQLDatabaseCorePreparedStatement~new(name, sqlText, scope, .Error~NOTEXECUTED, .Error~INVALIDSTATE)
  key = name~string~translate
  if self~prepared[key] \== .nil then return .NoSQLDatabaseCorePreparedStatement~new(name, sqlText, scope, .Error~NOTEXECUTED, .Error~DUPLICATEPREPARED)
  ps = .NoSQLDatabaseCorePreparedStatement~new(name, sqlText, scope)
  self~prepared[key] = ps
  self~logicalOperationCount += 1
  return ps

::method executePrepared
  use arg statement, parameters = .nil
  if self~state \= "building" then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE)
  validation = self~validatePrepared(statement, parameters)
  if validation \== .nil then return validation
  if self~accessMode = .NoSQLDatabaseCoreAccessMode~READONLY then do
    if self~adapter~isMutationSQL(statement~sql) then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDOPERATION, .nil, "Read-only transaction rejects prepared mutation")
  end
  op = .table~new
  op["kind"] = "PREPARED"
  op["statement"] = statement
  op["parameters"] = self~normalizeParameters(parameters)
  self~operations~append(op)
  self~logicalOperationCount += 1
  return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~SUCCESS, .nil, "QUEUED")

::method queryPrepared
  use arg statement, parameters = .nil
  if self~state \= "building" then return .NoSQLDatabaseCoreDeferredResult~new
  validation = self~validatePrepared(statement, parameters)
  if validation \== .nil then return .NoSQLDatabaseCoreDeferredResult~new
  ref = .NoSQLDatabaseCoreDeferredResult~new
  op = .table~new
  op["kind"] = "QUERY_PREPARED"
  op["statement"] = statement
  op["parameters"] = self~normalizeParameters(parameters)
  op["deferred"] = ref
  op["schema"] = .nil
  self~operations~append(op)
  self~deferredResults~append(ref)
  self~logicalOperationCount += 1
  return ref

::method prepareBatch
  use arg statement
  return .NoSQLDatabaseCorePreparedBatch~new(statement)

::method executePreparedBatch
  use arg batch
  if self~state \= "building" then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE)
  if batch == .nil then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~PREPAREFAILED)
  do params over batch~parameterSets
    validation = self~validatePrepared(batch~statement, params)
    if validation \== .nil then return validation
  end
  if self~accessMode = .NoSQLDatabaseCoreAccessMode~READONLY then do
    if self~adapter~isMutationSQL(batch~statement~sql) then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDOPERATION)
  end
  op = .table~new
  op["kind"] = "PREPARED_BATCH"
  op["batch"] = batch
  self~operations~append(op)
  self~logicalOperationCount += 1
  return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~SUCCESS, .nil, "QUEUED")

::method savepoint
  use arg name = ""
  if self~state \= "building" then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE)
  if name = "" then name = "sp_" || (self~savepoints~items + 1)
  key = name~string~translate
  if self~savepoints[key] \== .nil then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSAVEPOINT)
  sp = .NoSQLDatabaseCoreSavepoint~new(name, self~operations~items, self~token)
  self~savepoints[key] = sp
  self~logicalOperationCount += 1
  return sp

::method rollbackTo
  use arg savepoint
  if self~state \= "building" then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE)
  if savepoint == .nil then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSAVEPOINT)
  if \savepoint~isA(.NoSQLDatabaseCoreSavepoint) then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSAVEPOINT)
  if savepoint~transactionToken \= self~token then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSAVEPOINT)
  target = self~savepoints[savepoint~name~translate]
  if target == .nil then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDSAVEPOINT)
  keep = .array~new
  do i = 1 to savepoint~operationCount
    keep~append(self~operations[i])
  end
  self~operations = keep
  self~logicalOperationCount += 1
  keys = self~savepoints~allIndexes
  do key over keys
    if self~savepoints[key]~operationCount > savepoint~operationCount then self~savepoints~remove(key)
  end
  return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~SUCCESS, .nil, "STAGED STATE REWOUND")

::method rollback
  if self~state \= "building" then return .NoSQLDatabaseCoreTransactionResult~new(.Error~UNKNOWN, .Error~INVALIDSTATE, self~logicalOperationCount, 0)
  self~state = "rolled-back"
  self~firstNativeTransaction~rollback
  return .NoSQLDatabaseCoreTransactionResult~new(.Error~NOTEXECUTED, .Error~SUCCESS, self~logicalOperationCount, 0)

::method commit
  if self~state \= "building" then return .NoSQLDatabaseCoreTransactionResult~new(.Error~NOTEXECUTED, .Error~INVALIDSTATE, self~logicalOperationCount, 0)
  self~state = "executing"
  lastNative = .nil
  do attempt = 1 to self~retryAttempts
    if attempt = 1 then nativeTx = self~firstNativeTransaction
    else nativeTx = self~engine~transaction
    nativePrepared = .table~new
    nativeDeferred = .array~new

    -- Declarations are recreated for each whole-transaction attempt.
    keys = self~prepared~allIndexes
    do key over keys
      ps = self~prepared[key]
      nativePs = nativeTx~prepareStatement(ps~name, ps~sql)
      if nativePs~error \= .Error~SUCCESS then do
        self~state = "failed"
        return .NoSQLDatabaseCoreTransactionResult~new(.Error~NOTEXECUTED, nativePs~error, self~logicalOperationCount, attempt)
      end
      nativePrepared[key] = nativePs
    end

    replayError = .nil
    do op over self~operations
      kind = op["kind"]
      select
        when kind = "EXECUTE" then queued = nativeTx~execute(op["sql"])
        when kind = "QUERY" then do
          nref = nativeTx~query(op["sql"])
          pair = .table~new; pair["native"] = nref; pair["compat"] = op["deferred"]; pair["schema"] = op["schema"]; pair["sql"] = op["sql"]
          nativeDeferred~append(pair)
          queued = .nil
        end
        when kind = "PREPARED" then queued = nativeTx~executePrepared(nativePrepared[op["statement"]~name~translate], op["parameters"])
        when kind = "QUERY_PREPARED" then do
          nativePs = nativePrepared[op["statement"]~name~translate]
          bound = .DatabaseParameterBinder~bind(nativePs, op["parameters"])
          if bound~isA(.DatabaseResult) then queued = bound
          else do
            nref = nativeTx~query(bound)
            pair = .table~new; pair["native"] = nref; pair["compat"] = op["deferred"]; pair["schema"] = op["schema"]; pair["sql"] = bound
            nativeDeferred~append(pair)
            queued = .nil
          end
        end
        when kind = "PREPARED_BATCH" then do
          nativePs = nativePrepared[op["batch"]~statement~name~translate]
          nb = nativeTx~prepareBatch(nativePs)
          do params over op["batch"]~parameterSets
            nb~add(params)
          end
          queued = nativeTx~executePreparedBatch(nb)
        end
        otherwise queued = .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDOPERATION)
      end
      if queued \== .nil then do
        if queued~error \= .Error~SUCCESS then do
          replayError = queued~error
          leave
        end
      end
    end
    if replayError \== .nil then do
      nativeTx~rollback
      self~state = "failed"
      return .NoSQLDatabaseCoreTransactionResult~new(.Error~NOTEXECUTED, replayError, self~logicalOperationCount, attempt)
    end

    nativeResult = nativeTx~commit
    lastNative = nativeResult
    mappedError = self~adapter~mapNativeError(nativeResult)
    if nativeResult~status = .Error~COMMITTED then do
      mutationResults = self~adapter~adaptMutationResults(nativeTx~lastMutationResults)
      do pair over nativeDeferred
        qr = self~adapter~adaptQueryResult(pair["native"], pair["schema"], pair["sql"])
        pair["compat"]~resolve(qr)
      end
      self~state = "committed"
      return .NoSQLDatabaseCoreTransactionResult~new(.Error~COMMITTED, .Error~SUCCESS, self~logicalOperationCount, attempt, mutationResults, nativeResult, nativeResult~message)
    end

    retryable = (mappedError = .Error~SERIALIZATIONFAILURE | mappedError = .Error~DEADLOCK | mappedError = .Error~LOCKTIMEOUT)
    if \retryable | attempt >= self~retryAttempts then do
      if nativeResult~status = .Error~NOTEXECUTED then outcome = .Error~NOTEXECUTED
      else outcome = .Error~ROLLEDBACK
      self~state = "failed"
      return .NoSQLDatabaseCoreTransactionResult~new(outcome, mappedError, self~logicalOperationCount, attempt, .array~new, nativeResult, nativeResult~message)
    end
  end
  self~state = "failed"
  return .NoSQLDatabaseCoreTransactionResult~new(.Error~ROLLEDBACK, .Error~TRANSACTIONFAILED, self~logicalOperationCount, self~retryAttempts, .array~new, lastNative)

::method validatePrepared private
  use arg statement, parameters
  if statement == .nil then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~PREPAREFAILED)
  if \statement~isA(.NoSQLDatabaseCorePreparedStatement) then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~PREPAREFAILED)
  if statement~error \= .Error~SUCCESS then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, statement~error)
  declared = self~prepared[statement~name~translate]
  if declared == .nil then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~PREPAREFAILED)
  params = self~normalizeParameters(parameters)
  if params~items \= statement~parameterCount then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~PARAMETERCOUNT)
  do parameter over params
    if parameter~isA(.DatabaseValue) then do
      if parameter~typeName~startsWith("INVALID:") then return .NoSQLDatabaseCoreResult~new(.Error~NOTEXECUTED, .Error~INVALIDPARAMETER)
    end
  end
  return .nil

::method normalizeParameters private
  use arg parameters
  if parameters == .nil then return .array~new
  if parameters~isA(.Array) then return parameters
  out = .array~new
  out~append(parameters)
  return out

::class NoSQLDatabaseCoreSourceKind public
::constant DATABASE "DATABASE"
::constant TABLE    "TABLE"

::class NoSQLDatabaseCoreCapability public
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

::class NoSQLDatabaseCoreCapabilities public
::attribute values
::method init
  self~values = .set~new
::method add
  use arg capability
  self~values~put(capability)
  return self
::method supports
  use arg capability
  return self~values~hasIndex(capability)
::method all
  return self~values~makeArray

::class NoSQLDatabaseCoreEndpointIdentity public
::attribute protocol
::attribute product
::attribute version
::attribute rawVersion
::method init
  use arg protocol = "", product = "", version = "", rawVersion = ""
  self~protocol = protocol
  self~product = product
  self~version = version
  self~rawVersion = rawVersion
::method string
  return self~protocol || ":" || self~product || ":" || self~version

::class NoSQLDatabaseCoreSourceIdentity public
::attribute sourceKind
::attribute engineName
::attribute name
::attribute endpointIdentity
::method init
  use arg sourceKind = .nil, engineName = "", name = "", endpointIdentity = .nil
  if sourceKind == .nil then sourceKind = .NoSQLDatabaseCoreSourceKind~DATABASE
  self~sourceKind = sourceKind
  self~engineName = engineName
  self~name = name
  self~endpointIdentity = endpointIdentity
::method protocol
  if self~endpointIdentity == .nil then return self~engineName
  return self~endpointIdentity~protocol
::method product
  if self~endpointIdentity == .nil then return self~engineName
  return self~endpointIdentity~product
::method version
  if self~endpointIdentity == .nil then return ""
  return self~endpointIdentity~version
::method string
  base = self~sourceKind || ":" || self~engineName || ":" || self~name
  if self~endpointIdentity == .nil then return base
  return base || ":" || self~endpointIdentity~product

::class NoSQLDatabaseCoreRelationDescriptor public
::attribute schemaName
::attribute name
::attribute relationType
::method init
  use arg schemaName = "", name = "", relationType = ""
  self~schemaName = schemaName
  self~name = name
  self~relationType = relationType
::method qualifiedName
  if self~schemaName = "" then return self~name
  return self~schemaName || "." || self~name
::method string
  return self~qualifiedName

::class NoSQLDatabaseRelationalSource public
::attribute database
::method init
  use arg database
  self~database = database
::method endpointIdentity
  return self~database~endpointIdentity
::method identity
  endpoint = self~endpointIdentity
  return .NoSQLDatabaseCoreSourceIdentity~new(.NoSQLDatabaseCoreSourceKind~DATABASE, self~database~engineName, self~database~databaseName, endpoint)
::method capabilities
  return self~database~capabilities
::method supports
  use arg capability
  return self~database~supports(capability)
::method tables
  return self~database~tables
::method table
  use arg tableName
  return .NoSQLDatabaseTableSource~new(self~database, tableName, self)

::class NoSQLDatabaseTableSource public
::attribute database
::attribute tableName
::attribute parentSource
::method init
  use arg database, tableName, parentSource = .nil
  self~database = database
  self~tableName = tableName
  if parentSource == .nil then parentSource = .NoSQLDatabaseRelationalSource~new(database)
  self~parentSource = parentSource
::method endpointIdentity
  return self~parentSource~endpointIdentity
::method identity
  endpoint = self~endpointIdentity
  return .NoSQLDatabaseCoreSourceIdentity~new(.NoSQLDatabaseCoreSourceKind~TABLE, self~database~engineName, self~tableName, endpoint)
::method capabilities
  return self~database~capabilities
::method supports
  use arg capability
  return self~database~supports(capability)
::method metadata
  return self~database~tableMetadata(self~tableName)
::method rows
  return self~database~queryTable(self~tableName)
::method query
  use arg sqlText
  return self~database~query(sqlText)
::method describe
  description = .directory~new
  sourceIdentity = self~identity
  sourceCapabilities = self~capabilities
  description["name"] = self~tableName
  description["engine"] = sourceIdentity~engineName
  description["protocol"] = sourceIdentity~protocol
  description["product"] = sourceIdentity~product
  description["version"] = sourceIdentity~version
  description["capabilities"] = sourceCapabilities~all
  description["metadata"] = self~metadata
  return description

::class NoSQLDatabaseCoreAdapter subclass NoSQLAlchemyObject public
::attribute engine

::method init
  use arg engine, alchemySealer = .nil, alchemyAuthority = .nil
  self~initNoSQLAlchemy("DATABASE_CORE_ADAPTER", alchemySealer, alchemyAuthority)
  self~registerNoSQLMethod("QUERYTABLE", "query one relational source through Database Core", "READ")
  self~registerNoSQLMethod("EXECUTE", "execute through the Database Core adapter", "UNKNOWN")
  self~registerNoSQLMethod("TRANSACTION", "begin a Database Core transaction", "MUTATE")
  self~engine = engine

::method version
  return self~engine~version

::method engineName
  v = self~version
  if v~engine == .nil then return "nosqlserver"
  return v~engine~string~lower

::method databaseName
  if self~engine~hasMethod("readCatalog") then do
    catalog = self~engine~readCatalog
    if catalog \== .nil then do
      if catalog~hasIndex("name") then do
        name = catalog["name"]
        if name \== .nil then return name~string
      end
    end
  end
  return self~version~product

::method endpointIdentity
  v = self~version
  protocol = self~engineName
  return .NoSQLDatabaseCoreEndpointIdentity~new(protocol, v~product, v~release, v~string)

::method capabilities
  caps = .NoSQLDatabaseCoreCapabilities~new
  caps~add(.NoSQLDatabaseCoreCapability~TYPEDRESULTS)
  caps~add(.NoSQLDatabaseCoreCapability~RESULTMETADATA)
  caps~add(.NoSQLDatabaseCoreCapability~RESULTSCHEMA)
  caps~add(.NoSQLDatabaseCoreCapability~TABLEDISCOVERY)
  if self~version~supports("MUTATION_RESULTS") then caps~add(.NoSQLDatabaseCoreCapability~MUTATIONRESULTS)
  if self~version~supports("PREPARED_MUTATION_RESULTS") then caps~add(.NoSQLDatabaseCoreCapability~PREPAREDMUTATIONRESULTS)
  if self~version~supports("PREPARED_STATEMENTS") then caps~add(.NoSQLDatabaseCoreCapability~PREPAREDSTATEMENTS)
  if self~version~supports("PREPARED_BATCH") then caps~add(.NoSQLDatabaseCoreCapability~PREPAREDBATCH)
  if self~version~supports("TRANSACTIONS") then caps~add(.NoSQLDatabaseCoreCapability~TRANSACTIONS)
  if self~version~supports("SAVEPOINTS") then caps~add(.NoSQLDatabaseCoreCapability~SAVEPOINTS)
  if self~version~supports("TRANSACTION_RETRY") then caps~add(.NoSQLDatabaseCoreCapability~TRANSACTIONRETRY)
  if self~version~supports("TRANSACTION_READ_ONLY") then caps~add(.NoSQLDatabaseCoreCapability~TRANSACTIONREADONLY)
  if self~version~supports("TRANSACTION_ISOLATION") then caps~add(.NoSQLDatabaseCoreCapability~TRANSACTIONISOLATION)
  if self~version~supports("GEOMETRY_TYPED_VALUE") then caps~add(.NoSQLDatabaseCoreCapability~SPATIALTYPES)
  return caps

::method supports
  use arg capability
  return self~capabilities~supports(capability)

::method tables
  out = .array~new
  if \self~engine~hasMethod("readCatalog") then return out
  catalog = self~engine~readCatalog
  if catalog == .nil then return out
  names = catalog["tables"]
  if names == .nil then return out
  do name over names
    out~append(.NoSQLDatabaseCoreRelationDescriptor~new("", name~string, "BASE TABLE"))
  end
  return out

::method relationalSource
  return .NoSQLDatabaseRelationalSource~new(self)

::method tableSource
  use arg tableName
  return self~relationalSource~table(tableName)

::method transaction
  return .NoSQLDatabaseCoreTransaction~new(self)

::method resultSchema
  return .NoSQLDatabaseCoreResultSchema~new

::method execute
  use arg sqlText
  tx = self~transaction
  queued = tx~execute(sqlText)
  if queued~error \= .Error~SUCCESS then return queued
  return tx~commit

::method query
  use arg sqlText
  nativeResult = self~engine~query(sqlText)
  return self~adaptQueryResult(nativeResult, .nil, sqlText)

::method queryWithSchema
  use arg sqlText, resultSchema
  nativeResult = self~engine~query(sqlText)
  return self~adaptQueryResult(nativeResult, resultSchema, sqlText)

::method tableMetadata
  use arg tableName
  nativeMetadata = self~engine~tableMetadata(tableName)
  if nativeMetadata == .nil then return .NoSQLDatabaseCoreResultMetadata~new
  cols = .array~new
  do column over nativeMetadata~columns
    cols~append(.NoSQLDatabaseCoreColumnMetadata~new(column))
  end
  return .NoSQLDatabaseCoreResultMetadata~new(cols)

::method queryTable
  use arg tableName
  metadata = self~tableMetadata(tableName)
  schema = .NoSQLDatabaseCoreResultSchema~new
  do column over metadata~columns
    schema~add(column~name, column~databaseType)
  end
  return self~queryWithSchema("SELECT * FROM " || tableName, schema)

::method isMutationSQL
  use arg sqlText
  upper = sqlText~string~strip~translate
  if upper~startsWith("INSERT ") then return .true
  if upper~startsWith("UPDATE ") then return .true
  if upper~startsWith("DELETE ") then return .true
  if upper~startsWith("CREATE ") then return .true
  if upper~startsWith("DROP ") then return .true
  return .false

::method mapNativeError
  use arg nativeResult
  if nativeResult == .nil then return .Error~UNKNOWN
  message = nativeResult~message~string~translate
  if message~pos("DATABASE CHANGED AFTER TRANSACTION BEGAN") > 0 then return .Error~SERIALIZATIONFAILURE
  if message~pos("DATABASE CHANGED DURING TRANSACTION COMMIT") > 0 then return .Error~SERIALIZATIONFAILURE
  if message~pos("DATABASE CHANGED DURING TRANSACTION PUBLICATION") > 0 then return .Error~SERIALIZATIONFAILURE
  return nativeResult~error

::method adaptMutationResults
  use arg nativeResults
  out = .array~new
  if nativeResults == .nil then return out
  do nativeResult over nativeResults
    out~append(.NoSQLDatabaseCoreMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, nativeResult~affectedRows, .nil, nativeResult, nativeResult~message))
  end
  return out

::method adaptQueryResult
  use arg nativeResult, resultSchema = .nil, sqlText = ""
  if nativeResult == .nil then return .NoSQLDatabaseCoreQueryResult~new(.Error~FAILED, .Error~DATABASEERROR)
  if nativeResult~status \= .Error~SUCCESS then return .NoSQLDatabaseCoreQueryResult~new(nativeResult~status, self~mapNativeError(nativeResult), .nil, .nil, .nil, .nil, nativeResult, nativeResult~message)

  names = self~projectionNames(sqlText, nativeResult, resultSchema)
  metadata = self~adaptMetadata(nativeResult~metadata, names, sqlText)
  nativeTypes = metadata~types
  requestedTypes = .array~new
  if resultSchema \== .nil then requestedTypes = resultSchema~types
  rows = .array~new
  outputTypes = .array~new

  do i = 1 to names~items
    requested = .DatabaseType~UNKNOWN
    if i <= requestedTypes~items then requested = requestedTypes[i]
    nativeType = .DatabaseType~UNKNOWN
    if i <= nativeTypes~items then nativeType = nativeTypes[i]
    if requested \= .DatabaseType~UNKNOWN & nativeType \= .DatabaseType~UNKNOWN & requested \= nativeType then do
      return .NoSQLDatabaseCoreQueryResult~new(.Error~FAILED, .Error~INVALIDPARAMETER, names, .array~new, requestedTypes, metadata, nativeResult, "Explicit result schema contradicts native metadata at ordinal " || i)
    end
    if requested = .DatabaseType~UNKNOWN then outputTypes~append(nativeType)
    else outputTypes~append(requested)
  end

  do nativeRow over nativeResult~rows
    adaptedNative = self~coerceRow(nativeRow, names, outputTypes)
    if adaptedNative == .nil then return .NoSQLDatabaseCoreQueryResult~new(.Error~FAILED, .Error~INVALIDPARAMETER, names, .array~new, outputTypes, metadata, nativeResult, "Typed result conversion failed")
    rows~append(.NoSQLDatabaseCoreRow~new(adaptedNative, names))
  end
  return .NoSQLDatabaseCoreQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, names, rows, outputTypes, metadata, nativeResult, nativeResult~message)

::method adaptMetadata private
  use arg nativeMetadata, names, sqlText = ""
  cols = .array~new
  if nativeMetadata \== .nil then do
    do column over nativeMetadata~columns
      cols~append(.NoSQLDatabaseCoreColumnMetadata~new(column))
    end
    return .NoSQLDatabaseCoreResultMetadata~new(cols)
  end

  inferred = self~inferSimpleTableMetadata(sqlText, names)
  if inferred \== .nil then return inferred

  do i = 1 to names~items
    cols~append(.NoSQLDatabaseCoreColumnMetadata~new(.nil, names[i], "", .DatabaseType~UNKNOWN, .true, i))
  end
  return .NoSQLDatabaseCoreResultMetadata~new(cols)

::method inferSimpleTableMetadata private
  use arg sqlText, names
  text = sqlText~string~strip
  if \text~translate~startsWith("SELECT ") then return .nil
  fromPos = self~topLevelKeywordPos(text, " FROM ", 8)
  if fromPos = 0 then return .nil
  rest = text~substr(fromPos + 6)~strip
  upperRest = rest~translate
  cut = rest~length + 1
  do keyword over " WHERE | GROUP BY | HAVING | ORDER BY | LIMIT | OFFSET | JOIN | LEFT JOIN | RIGHT JOIN | FULL JOIN "~makeArray("|")
    k = keyword~strip
    pos = self~topLevelKeywordPos(" " || rest, " " || k || " ", 1)
    if pos > 0 then do
      adjusted = pos
      if adjusted < cut then cut = adjusted
    end
  end
  fromPart = rest~left(cut - 1)~strip
  if fromPart~pos(",") > 0 | fromPart~left(1) = "(" then return .nil
  tableName = fromPart~word(1)
  if tableName = "" then return .nil
  nativeTableMeta = self~engine~tableMetadata(tableName)
  if nativeTableMeta == .nil then return .nil
  byName = .table~new
  do column over nativeTableMeta~columns
    byName[column~name~translate] = column
  end
  out = .array~new
  do i = 1 to names~items
    outputName = names[i]
    sourceName = outputName
    dot = sourceName~lastPos(".")
    if dot > 0 then sourceName = sourceName~substr(dot + 1)
    nativeCol = byName[sourceName~translate]
    if nativeCol == .nil then out~append(.NoSQLDatabaseCoreColumnMetadata~new(.nil, outputName, "", .DatabaseType~UNKNOWN, .true, i))
    else do
      geometryType = ""
      srid = 0
      if nativeCol~hasMethod("geometryType") then geometryType = nativeCol~geometryType
      if nativeCol~hasMethod("srid") then srid = nativeCol~srid
      out~append(.NoSQLDatabaseCoreColumnMetadata~new(.nil, outputName, nativeCol~nativeType, nativeCol~commonType, nativeCol~nullable, i, geometryType, srid))
    end
  end
  return .NoSQLDatabaseCoreResultMetadata~new(out)

::method coerceRow private
  use arg nativeRow, names, types
  values = .table~new
  raws = .table~new
  typeNames = .table~new
  do i = 1 to names~items
    name = names[i]
    raw = nativeRow~rawAt(name)
    if raw == .nil then raw = nativeRow~at(name)
    requested = types[i]
    typed = self~coerceValue(raw, requested)
    if typed == .nil then return .nil
    values[name] = typed~value
    raws[name] = typed~rawValue
    typeNames[name] = typed~typeName
  end
  return .DatabaseRow~new(values, raws, typeNames)

::method coerceValue private
  use arg raw, requested
  if raw == .nil then return .DatabaseValue~nullValue
  select
    when requested = .DatabaseType~INTEGER then out = .DatabaseValue~integer(raw)
    when requested = .DatabaseType~DECIMAL then out = .DatabaseValue~decimal(raw)
    when requested = .DatabaseType~BOOLEAN then out = .DatabaseValue~boolean(raw)
    when requested = .DatabaseType~VARCHAR then out = .DatabaseValue~varchar(raw)
    when requested = .DatabaseType~DATE then out = .DatabaseValue~date(raw)
    when requested = .DatabaseType~DATETIME then out = .DatabaseValue~datetime(raw)
    when requested = .DatabaseType~BLOB then out = .DatabaseValue~blob(raw)
    when requested = .DatabaseType~GEOMETRY then do
      if raw~isA(.GeoPackageGeometry) then out = .DatabaseGeometryValue~new(raw~hex, raw~geometryType, raw~srid, .DatabaseSpatialEncoding~GPKGBLOBHEX, raw)
      else if raw~isA(.DatabaseGeometryValue) then out = raw
      else out = .DatabaseGeometryValue~new(raw~string)
    end
    otherwise out = .DatabaseValue~unknown(raw)
  end
  if out~typeName~startsWith("INVALID:") then return .nil
  return out

::method projectionNames private
  use arg sqlText, nativeResult, resultSchema
  if resultSchema \== .nil then do
    schemaNames = .array~new
    do column over resultSchema~columns
      schemaNames~append(column~name)
    end
    if schemaNames~items > 0 then do
      parsed = self~parseProjectionNames(sqlText)
      if parsed~items = schemaNames~items then return parsed
      upperSql = sqlText~string~strip~translate
      if upperSql~startsWith("SELECT * FROM ") then return schemaNames
    end
  end
  parsed = self~parseProjectionNames(sqlText)
  if parsed~items > 0 then return parsed
  if nativeResult~metadata \== .nil then do
    names = .array~new
    do column over nativeResult~metadata~columns
      names~append(column~name)
    end
    return names
  end
  return .array~new

::method parseProjectionNames private
  use arg sqlText
  out = .array~new
  text = sqlText~string~strip
  upper = text~translate
  if \upper~startsWith("SELECT ") then return out
  fromPos = self~topLevelKeywordPos(text, " FROM ", 8)
  if fromPos = 0 then return out
  projection = text~substr(8, fromPos - 8)~strip
  if projection~translate~startsWith("DISTINCT ") then projection = projection~substr(10)~strip
  items = self~splitTopLevelComma(projection)
  do item over items
    spec = item~strip
    up = spec~translate
    asPos = self~topLevelLastAs(spec)
    if asPos > 0 then name = spec~substr(asPos + 4)~strip
    else do
      if spec = "*" then return .array~new
      name = spec
    end
    out~append(name)
  end
  return out

::method topLevelLastAs private
  use arg text
  upper = text~translate
  depth = 0; quote = ""; last = 0; i = 1
  do while i <= text~length - 3
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then quote = ""
      i += 1; iterate
    end
    if ch = "'" | ch = '"' then do; quote = ch; i += 1; iterate; end
    if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if depth = 0 then do
      if upper~substr(i,4) = " AS " then last = i
    end
    i += 1
  end
  return last

::method topLevelKeywordPos private
  use arg text, keyword, start = 1
  upper = text~translate; key = keyword~translate
  depth = 0; quote = ""; i = start
  do while i <= text~length - key~length + 1
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then quote = ""
      i += 1; iterate
    end
    if ch = "'" | ch = '"' then do; quote = ch; i += 1; iterate; end
    if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if depth = 0 then do
      if upper~substr(i,key~length) = key then return i
    end
    i += 1
  end
  return 0

::method splitTopLevelComma private
  use arg text
  out = .array~new; depth = 0; quote = ""; start = 1; i = 1
  do while i <= text~length
    ch = text~substr(i,1)
    if quote \= "" then do
      if ch = quote then quote = ""
      i += 1; iterate
    end
    if ch = "'" | ch = '"' then do; quote = ch; i += 1; iterate; end
    if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if ch = "," & depth = 0 then do
      out~append(text~substr(start, i - start)~strip)
      start = i + 1
    end
    i += 1
  end
  out~append(text~substr(start)~strip)
  return out


/* ============================================================
 * v0.74 native SQLite 3 binary storage reader
 * ============================================================ */

/* SQLiteNativeReader - read-only SQLite 3 file-format reader for ooRexx.
 *
 * This is deliberately a storage reader, not a second SQL implementation.
 * It decodes SQLite database pages into schema records and ordinary rowid
 * table records. Callers (such as NoSQLServer) own relational projection,
 * predicates, joins, and governance above this layer.
 */

::class SQLiteNativeBlob public
::attribute bytes

::method init
  use strict arg bytes
  self~bytes = bytes

::method hex
  return c2x(self~bytes)

::method string
  return self~hex


::class SQLiteNativeColumn public
::attribute name
::attribute declaredType
::attribute notNull
::attribute primaryKey
::attribute rowidAlias

::method init
  use strict arg name, declaredType = "", notNull = .false, primaryKey = .false, rowidAlias = .false
  self~name = name
  self~declaredType = declaredType
  self~notNull = notNull
  self~primaryKey = primaryKey
  self~rowidAlias = rowidAlias


::class SQLiteNativeTable public
::attribute name
::attribute rootPage
::attribute sql
::attribute columns
::attribute withoutRowid

::method init
  use strict arg name, rootPage, sql, columns, withoutRowid = .false
  self~name = name
  self~rootPage = rootPage
  self~sql = sql
  self~columns = columns
  self~withoutRowid = withoutRowid

::method columnNames
  out = .array~new
  do column over self~columns
    out~append(column~name)
  end
  return out


::class SQLiteNativeDatabase public
::attribute path
::attribute pageSize
::attribute reservedBytes
::attribute usableSize
::attribute textEncoding
::attribute pageCount

::method init
  expose fileSize schemaCache
  use strict arg path
  self~path = path~string
  size = stream(self~path, "c", "query size")
  if size == "" | \datatype(size, "W") | size < 100 then
    raise syntax 93.900 additional("Not a readable SQLite database file:" self~path)
  fileSize = size
  header = charin(self~path, 1, 100)
  if header~length \= 100 then
    raise syntax 93.900 additional("Short read while loading SQLite database header:" self~path)
  if header~substr(1, 16) \= "SQLite format 3" || "00"x then
    raise syntax 93.900 additional("SQLite 3 file header not found:" self~path)

  ps = c2d(header~substr(17, 2))
  if ps = 1 then ps = 65536
  if ps < 512 | ps > 65536 then
    raise syntax 93.900 additional("Invalid SQLite page size:" ps)
  -- Power-of-two validation without relying on bit operators.
  p = ps
  do while p > 1 & p // 2 = 0
    p = p % 2
  end
  if p \= 1 then raise syntax 93.900 additional("SQLite page size is not a power of two:" ps)
  if size // ps \= 0 then
    raise syntax 93.900 additional("SQLite file size is not an integral number of pages")

  self~pageSize = ps
  self~reservedBytes = c2d(header~substr(21, 1))
  self~usableSize = ps - self~reservedBytes
  if self~usableSize < 480 then raise syntax 93.900 additional("SQLite usable page size is too small")
  self~textEncoding = c2d(header~substr(57, 4))
  if self~textEncoding = 0 then self~textEncoding = 1
  if self~textEncoding < 1 | self~textEncoding > 3 then
    raise syntax 93.900 additional("Invalid SQLite text encoding:" self~textEncoding)
  self~pageCount = size % ps
  schemaCache = .nil

::method rawPage
  use strict arg pageNo
  if \datatype(pageNo, "W") | pageNo < 1 | pageNo > self~pageCount then
    raise syntax 93.900 additional("SQLite page number out of range:" pageNo)
  offset = (pageNo - 1) * self~pageSize + 1
  page = charin(self~path, offset, self~pageSize)
  if page~length \= self~pageSize then
    raise syntax 93.900 additional("Short read while loading SQLite page" pageNo)
  return page

::method schema
  expose schemaCache
  if schemaCache \== .nil then return schemaCache
  records = self~tableRecords(1)
  out = .array~new
  do record over records
    values = record["values"]
    if values~items < 5 then iterate
    type = values[1]
    name = values[2]
    tableName = values[3]
    rootPage = values[4]
    sql = values[5]
    if type == .nil | name == .nil then iterate
    if \type~string~caselessEquals("table") then iterate
    if name~string~startsWith("sqlite_") then iterate
    if sql == .nil then iterate
    parsed = self~parseCreateTable(name~string, rootPage, sql~string)
    out~append(parsed)
  end
  schemaCache = out
  return schemaCache

::method table
  use strict arg name
  do t over self~schema
    if t~name~caselessEquals(name) then return t
  end
  return .nil

::method rows
  use strict arg tableName
  t = self~table(tableName)
  if t == .nil then raise syntax 93.900 additional("SQLite table not found:" tableName)
  if t~withoutRowid then raise syntax 93.900 additional("WITHOUT ROWID tables are not supported by the native reader:" t~name)
  rawRows = self~tableRecords(t~rootPage)
  out = .array~new
  do raw over rawRows
    decoded = raw["values"]
    rowid = raw["rowid"]
    row = .table~new
    do i = 1 to t~columns~items
      column = t~columns[i]
      if i <= decoded~items then value = decoded[i]
      else value = .nil
      if column~rowidAlias & value == .nil then value = rowid
      row[column~name] = value
    end
    out~append(row)
  end
  return out

::method rowCount
  use strict arg tableName
  return self~rows(tableName)~items

::method tableRecords
  use strict arg rootPage
  out = .array~new
  self~walkTableBtree(rootPage, out)
  return out

::method walkTableBtree private
  use strict arg pageNo, out
  page = self~rawPage(pageNo)
  header = 1
  if pageNo = 1 then header = 101
  pageType = c2d(page~substr(header, 1))
  if pageType \= 5 & pageType \= 13 then
    raise syntax 93.900 additional("Expected SQLite table b-tree page at" pageNo "but found type" pageType)
  cellCount = c2d(page~substr(header + 3, 2))
  if pageType = 13 then do
    ptrBase = header + 8
    do i = 0 to cellCount - 1
      cellOffset = c2d(page~substr(ptrBase + i * 2, 2)) + 1
      out~append(self~decodeTableLeafCell(page, cellOffset))
    end
    return
  end

  ptrBase = header + 12
  do i = 0 to cellCount - 1
    cellOffset = c2d(page~substr(ptrBase + i * 2, 2)) + 1
    child = c2d(page~substr(cellOffset, 4))
    self~walkTableBtree(child, out)
  end
  rightMost = c2d(page~substr(header + 8, 4))
  self~walkTableBtree(rightMost, out)

::method decodeTableLeafCell private
  use strict arg page, cellOffset
  payloadVar = self~readVarint(page, cellOffset)
  payloadSize = payloadVar[1]
  p = cellOffset + payloadVar[2]
  rowidVar = self~readVarint(page, p)
  rowid = self~signed64(rowidVar[1])
  p += rowidVar[2]

  local = self~tableLeafLocalPayload(payloadSize)
  payload = page~substr(p, local)
  if payloadSize > local then do
    overflowPage = c2d(page~substr(p + local, 4))
    remaining = payloadSize - local
    do while remaining > 0
      if overflowPage = 0 then raise syntax 93.900 additional("Broken SQLite overflow chain")
      over = self~rawPage(overflowPage)
      nextPage = c2d(over~substr(1, 4))
      take = self~usableSize - 4
      if take > remaining then take = remaining
      payload ||= over~substr(5, take)
      remaining -= take
      overflowPage = nextPage
    end
  end
  if payload~length \= payloadSize then raise syntax 93.900 additional("SQLite cell payload length mismatch")

  cell = .table~new
  cell["rowid"] = rowid
  cell["values"] = self~decodeRecord(payload)
  return cell

::method tableLeafLocalPayload private
  use strict arg payloadSize
  u = self~usableSize
  x = u - 35
  if payloadSize <= x then return payloadSize
  m = ((u - 12) * 32 % 255) - 23
  k = m + ((payloadSize - m) // (u - 4))
  if k <= x then return k
  return m

::method decodeRecord
  use strict arg payload
  if payload~length = 0 then return .array~new
  headerVar = self~readVarint(payload, 1)
  headerSize = headerVar[1]
  if headerSize < headerVar[2] | headerSize > payload~length then
    raise syntax 93.900 additional("Invalid SQLite record header size")
  headerPos = 1 + headerVar[2]
  bodyPos = headerSize + 1
  serials = .array~new
  do while headerPos <= headerSize
    serialVar = self~readVarint(payload, headerPos)
    serials~append(serialVar[1])
    headerPos += serialVar[2]
  end
  out = .array~new
  do serial over serials
    decoded = self~decodeSerial(payload, bodyPos, serial)
    out~append(decoded[1])
    bodyPos += decoded[2]
  end
  if bodyPos - 1 > payload~length then raise syntax 93.900 additional("SQLite record body overruns payload")
  return out

::method decodeSerial private
  numeric digits 50
  use strict arg payload, bodyPos, serial
  pair = .array~new(2)
  select
    when serial = 0 then do; pair[1] = .nil; pair[2] = 0; end
    when serial = 1 then do; pair[1] = c2d(payload~substr(bodyPos, 1), 1); pair[2] = 1; end
    when serial = 2 then do; pair[1] = c2d(payload~substr(bodyPos, 2), 2); pair[2] = 2; end
    when serial = 3 then do; pair[1] = c2d(payload~substr(bodyPos, 3), 3); pair[2] = 3; end
    when serial = 4 then do; pair[1] = c2d(payload~substr(bodyPos, 4), 4); pair[2] = 4; end
    when serial = 5 then do; pair[1] = c2d(payload~substr(bodyPos, 6), 6); pair[2] = 6; end
    when serial = 6 then do; pair[1] = c2d(payload~substr(bodyPos, 8), 8); pair[2] = 8; end
    when serial = 7 then do; pair[1] = self~decodeFloat64(payload~substr(bodyPos, 8)); pair[2] = 8; end
    when serial = 8 then do; pair[1] = 0; pair[2] = 0; end
    when serial = 9 then do; pair[1] = 1; pair[2] = 0; end
    when serial = 10 | serial = 11 then raise syntax 93.900 additional("Reserved SQLite serial type encountered:" serial)
    otherwise do
      if serial < 12 then raise syntax 93.900 additional("Invalid SQLite serial type:" serial)
      if serial // 2 = 0 then do
        n = (serial - 12) % 2
        pair[1] = .SQLiteNativeBlob~new(payload~substr(bodyPos, n))
        pair[2] = n
      end
      else do
        n = (serial - 13) % 2
        pair[1] = self~decodeText(payload~substr(bodyPos, n))
        pair[2] = n
      end
    end
  end
  return pair

::method decodeText private
  use strict arg bytes
  select
    when self~textEncoding = 1 then return bytes
    when self~textEncoding = 2 then raise syntax 93.900 additional("SQLite UTF-16le text encoding is not yet supported by the native reader")
    when self~textEncoding = 3 then raise syntax 93.900 additional("SQLite UTF-16be text encoding is not yet supported by the native reader")
    otherwise raise syntax 93.900 additional("Unknown SQLite text encoding")
  end

::method decodeFloat64 private
  numeric digits 40
  use strict arg bytes
  if bytes~length \= 8 then raise syntax 93.900 additional("SQLite REAL requires 8 bytes")
  bits = c2d(bytes)
  sign = 1
  if bits >= 2 ** 63 then do
    sign = -1
    bits -= 2 ** 63
  end
  exponent = bits % (2 ** 52)
  fraction = bits // (2 ** 52)
  if exponent = 2047 then raise syntax 93.900 additional("SQLite REAL NaN/Infinity is not supported")
  if exponent = 0 then do
    if fraction = 0 then return 0 * sign
    value = (fraction / (2 ** 52)) * (2 ** -1022)
  end
  else value = (1 + fraction / (2 ** 52)) * (2 ** (exponent - 1023))
  return sign * value

::method readVarint private
  numeric digits 50
  use strict arg bytes, offset
  value = 0
  do i = 0 to 7
    if offset + i > bytes~length then raise syntax 93.900 additional("Truncated SQLite varint")
    b = c2d(bytes~substr(offset + i, 1))
    value = value * 128 + (b // 128)
    if b < 128 then return .array~of(value, i + 1)
  end
  if offset + 8 > bytes~length then raise syntax 93.900 additional("Truncated 9-byte SQLite varint")
  b = c2d(bytes~substr(offset + 8, 1))
  value = value * 256 + b
  return .array~of(value, 9)

::method signed64 private
  numeric digits 50
  use strict arg value
  if value >= 2 ** 63 then return value - 2 ** 64
  return value

::method parseCreateTable private
  use strict arg name, rootPage, sql
  upper = sql~translate
  withoutRowid = upper~pos("WITHOUT ROWID") > 0
  openPos = sql~pos("(")
  if openPos = 0 then raise syntax 93.900 additional("Cannot parse SQLite CREATE TABLE for" name)
  closePos = self~matchingCloseParen(sql, openPos)
  if closePos = 0 then raise syntax 93.900 additional("Unbalanced SQLite CREATE TABLE for" name)
  body = sql~substr(openPos + 1, closePos - openPos - 1)
  parts = self~splitTopLevelComma(body)
  columns = .array~new
  tablePk = .table~new

  -- First collect table-level PRIMARY KEY declarations.
  do part over parts
    item = self~sqlTrim(part)
    itemUpper = item~translate
    if itemUpper~startsWith("CONSTRAINT ") then do
      rest = self~afterConstraintName(item)
      if rest \= "" then itemUpper = rest~translate
      else iterate
      item = rest
    end
    if itemUpper~startsWith("PRIMARY KEY") then do
      p1 = item~pos("(")
      if p1 > 0 then do
        p2 = self~matchingCloseParen(item, p1)
        if p2 > p1 then do
          keys = self~splitTopLevelComma(item~substr(p1 + 1, p2 - p1 - 1))
          do key over keys
            keyName = self~identifierOnly(key~strip)
            if keyName \= "" then tablePk[keyName~translate] = .true
          end
        end
      end
    end
  end

  do part over parts
    item = self~sqlTrim(part)
    if item = "" then iterate
    itemUpper = item~translate
    if itemUpper~startsWith("CONSTRAINT ") | itemUpper~startsWith("PRIMARY KEY") |,
       itemUpper~startsWith("UNIQUE") | itemUpper~startsWith("CHECK") | itemUpper~startsWith("FOREIGN KEY") then iterate

    ident = self~consumeIdentifier(item)
    columnName = ident[1]
    rest = ident[2]~strip
    if columnName = "" then iterate
    declaredType = self~consumeDeclaredType(rest)
    constraints = rest~substr(declaredType[2])~strip
    typeName = declaredType[1]
    cUpper = constraints~translate
    isPk = cUpper~pos("PRIMARY KEY") > 0 | tablePk~hasIndex(columnName~translate)
    notNull = cUpper~pos("NOT NULL") > 0
    rowidAlias = isPk & typeName~strip~translate = "INTEGER" & \withoutRowid
    columns~append(.SQLiteNativeColumn~new(columnName, typeName, notNull, isPk, rowidAlias))
  end
  return .SQLiteNativeTable~new(name, rootPage, sql, columns, withoutRowid)

::method matchingCloseParen private
  use strict arg text, openPos
  depth = 0
  quote = ""
  bracket = .false
  i = openPos
  do while i <= text~length
    ch = text~substr(i, 1)
    if bracket then do
      if ch = "]" then bracket = .false
      i += 1
      iterate
    end
    if quote \= "" then do
      if ch = quote then do
        if i < text~length & text~substr(i + 1, 1) = quote then i += 2
        else do; quote = ""; i += 1; end
      end
      else i += 1
      iterate
    end
    if ch = "[" then do; bracket = .true; i += 1; iterate; end
    if ch = '"' | ch = "'" | ch = "`" then do; quote = ch; i += 1; iterate; end
    if ch = "(" then depth += 1
    else if ch = ")" then do
      depth -= 1
      if depth = 0 then return i
    end
    i += 1
  end
  return 0

::method splitTopLevelComma private
  use strict arg text
  out = .array~new
  depth = 0
  quote = ""
  bracket = .false
  start = 1
  i = 1
  do while i <= text~length
    ch = text~substr(i, 1)
    if bracket then do
      if ch = "]" then bracket = .false
      i += 1
      iterate
    end
    if quote \= "" then do
      if ch = quote then do
        if i < text~length & text~substr(i + 1, 1) = quote then i += 2
        else do; quote = ""; i += 1; end
      end
      else i += 1
      iterate
    end
    if ch = "[" then do; bracket = .true; i += 1; iterate; end
    if ch = '"' | ch = "'" | ch = "`" then do; quote = ch; i += 1; iterate; end
    if ch = "(" then depth += 1
    else if ch = ")" then depth -= 1
    else if ch = "," & depth = 0 then do
      out~append(text~substr(start, i - start)~strip)
      start = i + 1
    end
    i += 1
  end
  out~append(text~substr(start)~strip)
  return out

::method sqlTrim private
  use strict arg text
  ws = " " || "09"x || "0a"x || "0d"x
  do while text~length > 0 & ws~pos(text~left(1)) > 0
    text = text~substr(2)
  end
  do while text~length > 0 & ws~pos(text~right(1)) > 0
    text = text~left(text~length - 1)
  end
  return text

::method consumeIdentifier private
  use strict arg text
  text = self~sqlTrim(text)
  if text = "" then return .array~of("", "")
  first = text~left(1)
  if first = '"' | first = "`" then do
    i = 2
    value = ""
    do while i <= text~length
      ch = text~substr(i, 1)
      if ch = first then do
        if i < text~length & text~substr(i + 1, 1) = first then do
          value ||= first
          i += 2
          iterate
        end
        return .array~of(value, text~substr(i + 1))
      end
      value ||= ch
      i += 1
    end
    raise syntax 93.900 additional("Unterminated quoted SQLite identifier")
  end
  if first = "[" then do
    close = text~pos("]", 2)
    if close = 0 then raise syntax 93.900 additional("Unterminated bracketed SQLite identifier")
    return .array~of(text~substr(2, close - 2), text~substr(close + 1))
  end
  p = text~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$", "N")
  if p = 0 then return .array~of(text, "")
  if p = 1 then return .array~of("", text)
  return .array~of(text~left(p - 1), text~substr(p))

::method identifierOnly private
  use strict arg text
  parsed = self~consumeIdentifier(text)
  return parsed[1]

::method consumeDeclaredType private
  use strict arg rest
  if rest = "" then return .array~of("", 1)
  upper = rest~translate
  keywords = .array~of(" CONSTRAINT ", " PRIMARY ", " NOT ", " UNIQUE ", " CHECK ", " DEFAULT ", " COLLATE ", " REFERENCES ", " GENERATED ", " AS ")
  best = 0
  do key over keywords
    p = upper~pos(key)
    if p > 0 & (best = 0 | p < best) then best = p
  end
  -- Constraints may begin immediately, with no declared type.
  starts = .array~of("CONSTRAINT ", "PRIMARY ", "NOT ", "UNIQUE", "CHECK", "DEFAULT ", "COLLATE ", "REFERENCES ", "GENERATED ", "AS ")
  do key over starts
    if upper~startsWith(key) then return .array~of("", 1)
  end
  if best = 0 then return .array~of(rest~strip, rest~length + 1)
  return .array~of(rest~left(best - 1)~strip, best)

::method afterConstraintName private
  use strict arg item
  rest = self~sqlTrim(item~substr(12))
  parsed = self~consumeIdentifier(rest)
  if parsed[1] = "" then return ""
  return self~sqlTrim(parsed[2])

