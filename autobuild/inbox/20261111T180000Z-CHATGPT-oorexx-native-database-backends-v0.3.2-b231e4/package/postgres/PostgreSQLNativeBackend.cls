/* PostgreSQLNativeBackend.cls - Foreign Runtime/libpq backend v0.2 */

::class PostgreSQLNativeBackend public subclass NativeDatabaseBackend
::method init
  expose bridgePath library
  use strict arg bridgePath=""
  self~init:super("POSTGRESQL","libpq-foreign-runtime","0.2",.NativeDatabaseImplementationKind~FOREIGN_RUNTIME,10)
  if bridgePath="" then bridgePath="libpq.bridge.json"
  library=.nil
  self~addRequirement("OOREXX_FOREIGN_RUNTIME",.true,"ooRexx Foreign Runtime v0.22.2-compatible package")
  self~addRequirement("LIBPQ",.true,"libpq shared library visible to the native loader")
  self~addCapability("TRANSACTIONS","SUPPORTED","TESTED","Database Core transaction stream over one libpq connection","tests/test_postgres_native_offline.rex")
  self~addCapability("PREPARED_STATEMENTS","SUPPORTED","DECLARED","Database Core compiles PostgreSQL PREPARE/EXECUTE into the transaction stream")
  self~addCapability("TYPED_RESULTS","SUPPORTED","DECLARED","Result text is returned through the existing Database Core PostgreSQL parser")
  self~addCapability("RESULT_METADATA","SUPPORTED","DECLARED","libpq field names and OIDs are preserved in native bulk results")
  self~addCapability("BULK_RESULT_MATERIALISATION","SUPPORTED","TESTED","PGresult tuples materialise directly to one ooRexx Array in one producer-owned pass","tests/test_postgres_bulk_materialisation.rex")
  self~addCapability("BULK_JSON_RESULT","SUPPORTED","TESTED","A materialised bulk Array serialises through json.cls in one call without TSV round-trip","tests/test_postgres_bulk_materialisation.rex")
  self~addCapability("TABLE_DISCOVERY","SUPPORTED","DECLARED","Uses existing PostgreSQL information_schema discovery SQL")
  self~addCapability("CANCELLATION","UNSUPPORTED","DECLARED","PQcancel/PQcancelCreate is not wired in v0.1")
  self~addCapability("ASYNC_QUERY","UNSUPPORTED","DECLARED","v0.1 drains PQgetResult synchronously after PQsendQuery")
  self~addCapability("PIPELINE_MODE","UNSUPPORTED","DECLARED","libpq pipeline mode is intentionally not exposed in v0.1")
  self~addCapability("COPY_STREAMING","UNSUPPORTED","DECLARED","COPY IN/OUT is detected but not consumed in v0.1")
  self~addCapability("SESSION_REUSE","SUPPORTED","DECLARED","Low-level PostgreSQLNativeSession is reusable; Database Core executor opens one session per transaction")
  self~addLimitation("NO_MID_TRANSACTION_FALLBACK","Once a native session is acquired, failure is returned; execution is never replayed through a fallback")
  self~addLimitation("LEGACY_TEXT_RESULT_ADAPTER","Database Core command-executor compatibility can still synthesize tabular text; native querySet()/bulk results bypass it")
  self~addLimitation("NO_COPY","COPY statuses are rejected until explicit streaming ownership semantics are implemented")
::method bridgePath
  expose bridgePath
  return bridgePath
::method library
  expose bridgePath library
  if library==.nil then library=.foreign~load(bridgePath)
  return library
::method available
  signal on syntax name unavailable
  l=self~library
  v=l~lib_version
  return v>0
unavailable:
  return .false
::method availabilityEvidence
  d=self~availabilityEvidence:super
  if d["available"] then do
    d["libpq_version_number"]=self~library~lib_version
    d["foreign_runtime_version"]=.foreign~runtimeInfo~runtimeVersion
    d["provider_path"]=self~library~providerPath
  end
  return d
::method acquire
  use strict arg connection
  if \self~available then return .nil
  s=.PostgreSQLNativeSession~new(self,self~library,connection)
  if \s~connected then do; s~close; return .nil; end
  return s
::method commandExecutor
  use strict arg connection
  return .PostgreSQLNativeCommandExecutor~new(self,connection)
::method querySet
  use strict arg connection, sql
  session=self~acquire(connection)
  if session==.nil then return .PostgreSQLNativeBulkResult~failure("Unable to acquire PostgreSQL native session","08006")
  rs=session~querySet(sql)
  ignore=session~close
  return rs
::method database
  use strict arg connection
  return .Database~new(connection,.PostgreSQLEngine~new,self~commandExecutor(connection))

::class PostgreSQLNativeSession public
::method init
  expose backend library connection handle connected lastError
  use strict arg backend, library, connection
  handle=.nil; connected=.false; lastError=""
  host=self~nullable(connection~host)
  port=.nil; if connection~port>0 then port=connection~port~string
  db=self~nullable(connection~databaseName)
  user=self~nullable(connection~userName)
  password=.nil
  credential=connection~credential
  if credential\==.nil then do
    if credential~kind="password" then password=credential~value
    else if credential~kind<>"none" & credential~kind<>"environment" then do
      lastError="Unsupported credential kind for native PostgreSQL: " || credential~kind
      return
    end
  end
  handle=library~connect(host,port,.nil,.nil,db,user,password)
  if handle==.nil then do; lastError="libpq returned no PGconn"; return; end
  if library~connection_status(handle)=0 then connected=.true
  else lastError=library~connection_error(handle)
::method nullable private
  use strict arg value
  if value==.nil then return .nil
  if value~string="" then return .nil
  return value~string
::attribute backend get
::attribute connection get
::attribute connected get
::attribute lastError get
::method serverVersion
  expose connected library handle
  if \connected then return 0
  return library~server_version(handle)
::method protocolVersion
  expose connected library handle
  if \connected then return 0
  return library~protocol_version(handle)
::method querySet
  expose connected library handle lastError
  use strict arg sql
  if \connected then return .PostgreSQLNativeBulkResult~failure(lastError,"08006")
  if library~send_query(handle,sql)<>1 then do
    lastError=library~connection_error(handle)
    return .PostgreSQLNativeBulkResult~failure(lastError,"08006")
  end
  tupleResult=.nil; errorText=""; sqlState=""; ok=.true
  do forever
    pg=library~get_result(handle)
    if pg==.nil then leave
    status=library~result_status(pg)
    select
      when status=2 | status=9 | status=12 then do
        if tupleResult\==.nil then do
          ok=.false
          errorText="querySet requires exactly one tuple result"
          sqlState="21000"
          pg~close
        end
        else tupleResult=pg
      end
      when status=0 | status=1 then pg~close
      otherwise do
        ok=.false
        msg=library~result_error(pg); if msg="" then msg=library~connection_error(handle)
        errorText ||= msg
        sf=library~result_error_field(pg,67); if sf\==.nil then sqlState=sf
        pg~close
      end
    end
  end
  if \ok then do
    if tupleResult\==.nil then tupleResult~close
    lastError=errorText
    return .PostgreSQLNativeBulkResult~failure(errorText,sqlState)
  end
  if tupleResult==.nil then return .PostgreSQLNativeBulkResult~failure("querySet returned no tuple result","02000")
  return .PostgreSQLNativeBulkResult~new(library,tupleResult)

::method executeStream
  expose connected library handle lastError
  use strict arg sql
  if \connected then return .PostgreSQLNativeStreamResult~failure(lastError,"08006")
  if library~send_query(handle,sql)<>1 then do
    lastError=library~connection_error(handle)
    return .PostgreSQLNativeStreamResult~failure(lastError,"08006")
  end
  output=""; errorText=""; sqlState=""; ok=.true
  do forever
    r=library~get_result(handle)
    if r==.nil then leave
    status=library~result_status(r)
    select
      when status=1 then do
        tag=library~command_status(r)
        if tag<>"" then output ||= tag || .endOfLine
      end
      when status=2 | status=9 | status=12 then output ||= self~renderTuples(r)
      when status=0 then nop
      when status=3 | status=4 | status=8 then do
        ok=.false
        errorText="COPY result requires explicit streaming support"
        sqlState="0A000"
      end
      when status=6 then do
        msg=library~result_error(r); if msg<>"" then errorText ||= msg
      end
      otherwise do
        ok=.false
        msg=library~result_error(r); if msg="" then msg=library~connection_error(handle)
        errorText ||= msg
        sf=library~result_error_field(r,67)
        if sf\==.nil then sqlState=sf
      end
    end
    r~close
  end
  if ok then return .PostgreSQLNativeStreamResult~success(output)
  lastError=errorText
  return .PostgreSQLNativeStreamResult~failure(errorText,sqlState,output)
::method renderTuples private
  expose library
  use strict arg r
  fields=library~field_count(r); tuples=library~tuple_count(r); text=""
  do c=0 to fields-1
    if c>0 then text ||= "09"x
    name=library~field_name(r,c); if name==.nil then name=""
    text ||= name
  end
  text ||= .endOfLine
  do row=0 to tuples-1
    do c=0 to fields-1
      if c>0 then text ||= "09"x
      if library~field_is_null(r,row,c)=1 then value=""
      else do; value=library~field_value(r,row,c); if value==.nil then value=""; end
      text ||= value
    end
    text ||= .endOfLine
  end
  return text
::method close
  expose handle connected
  if handle\==.nil then do; handle~close; handle=.nil; end
  connected=.false
  return self
::method uninit
  expose handle
  if symbol("HANDLE")="VAR" then if handle\==.nil then handle~close

::class PostgreSQLNativeColumn public
::method init
  expose name oid commonType ordinal
  use strict arg name, oid, commonType, ordinal
::attribute name get
::attribute oid get
::attribute commonType get
::attribute ordinal get

::class PostgreSQLNativeBulkResult public subclass NativeDatabaseBulkResult
::method init
  expose library handle ok errorText sqlState columns rowCount fieldCount rows materialised closed
  use strict arg library=.nil, handle=.nil, ok=.true, errorText="", sqlState=""
  columns=.array~new; rows=.nil; materialised=.false; closed=.false
  rowCount=0; fieldCount=0
  if ok & handle\==.nil then do
    fieldCount=library~field_count(handle)
    rowCount=library~tuple_count(handle)
    do c=0 to fieldCount-1
      name=library~field_name(handle,c); if name==.nil then name=""
      oid=library~field_type(handle,c)
      columns~append(.PostgreSQLNativeColumn~new(name,oid,self~commonTypeForOid(oid),c+1))
    end
  end
::attribute ok get
::attribute errorText get
::attribute sqlState get
::attribute columns get
::attribute rowCount get
::attribute fieldCount get
::attribute materialised get

::method failure class
  use strict arg errorText, sqlState=""
  return self~new(.nil,.nil,.false,errorText,sqlState)

::method asArray
  expose library handle ok columns rowCount fieldCount rows materialised closed
  if \ok then return .array~new
  if materialised then return rows
  rows=.array~new(rowCount)
  do r=0 to rowCount-1
    row=.directory~new
    do c=0 to fieldCount-1
      col=columns[c+1]
      if library~field_is_null(handle,r,c)=1 then value=.nil
      else do
        value=library~field_value(handle,r,c); if value==.nil then value=""
        value=self~typedValue(value,col~commonType)
      end
      row[col~name]=value
    end
    rows~append(row)
  end
  materialised=.true
  self~releaseNative
  return rows

::method asDirectories
  return self~asArray

::method asJson
  return .json~toJSON(self~asArray)

::method releaseNative private
  expose handle closed
  if \closed then do
    if handle\==.nil then handle~close
    handle=.nil
    closed=.true
  end

::method close
  expose materialised rows
  self~releaseNative
  if \materialised then rows=.array~new
  return self

::method uninit
  expose closed
  if symbol("CLOSED")="VAR" then if \closed then self~releaseNative

::method typedValue private
  use strict arg value, commonType
  select
    when commonType="BOOLEAN" then do
      u=value~string~strip~translate
      if u="T" | u="TRUE" | u="1" then return .json~true
      if u="F" | u="FALSE" | u="0" then return .json~false
      return .JsonString~new(value~string)
    end
    when commonType="INTEGER" then return value~string
    when commonType="DECIMAL" then return value~string
    when commonType="NULL" then return .nil
    when commonType="JSON" then return .json~fromJSON(value~string)
    otherwise return .JsonString~new(value~string)
  end

::method commonTypeForOid private
  use strict arg oid
  select
    when oid=16 then return "BOOLEAN"       /* bool */
    when oid=20 | oid=21 | oid=23 | oid=26 then return "INTEGER" /* int8/int2/int4/oid */
    when oid=700 | oid=701 | oid=1700 then return "DECIMAL"       /* float4/float8/numeric */
    when oid=1082 then return "DATE"
    when oid=1083 | oid=1114 | oid=1184 | oid=1266 then return "DATETIME"
    when oid=17 then return "BLOB"
    when oid=114 | oid=3802 then return "JSON"
    otherwise return "VARCHAR"
  end

::class PostgreSQLNativeStreamResult public
::method init
  expose ok stdout stderr sqlState
  use strict arg ok, stdout="", stderr="", sqlState=""
::attribute ok get
::attribute stdout get
::attribute stderr get
::attribute sqlState get
::method success class
  use strict arg stdout=""
  return self~new(.true,stdout,"","")
::method failure class
  use strict arg stderr, sqlState="", stdout=""
  return self~new(.false,stdout,stderr,sqlState)

::class PostgreSQLNativeCommandExecutor public subclass DatabaseCommandExecutor
::method init
  expose backend connection
  use strict arg backend, connection
::method execute
  expose backend connection
  use strict arg command
  if command~status=.Error~NOTEXECUTED then return .DatabaseCommandResult~notExecuted(command,command~error)
  session=.PostgreSQLNativeSession~new(backend,backend~library,connection)
  if \session~connected then do
    commandResult=.DatabaseCommandResult~new(1,"",session~lastError,command,"FOREIGN_RUNTIME_LIBPQ")
    ignore=session~close
    return commandResult
  end
  stream=session~executeStream(command~stdinText)
  ignore=session~close
  if stream~ok then return .DatabaseCommandResult~new(0,stream~stdout,"",command,"FOREIGN_RUNTIME_LIBPQ")
  return .DatabaseCommandResult~new(1,stream~stdout,stream~stderr,command,"FOREIGN_RUNTIME_LIBPQ")

::requires "NativeDatabaseBackend.cls"
::requires "database_core.cls"
::requires "foreign.cls"
::requires "json.cls"
