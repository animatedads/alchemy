/* MySQLNativeBackend.cls - Foreign Runtime/libmariadb bulk backend v0.3.1 */

::class MySQLNativeBackend public subclass NativeDatabaseBackend
::method init
  expose bridgePath library
  use strict arg bridgePath=""
  self~init:super("MYSQL","libmariadb-foreign-runtime","0.3.1",.NativeDatabaseImplementationKind~FOREIGN_RUNTIME,10)
  if bridgePath="" then bridgePath="mariadb_bulk.bridge.json"
  library=.nil
  self~addRequirement("OOREXX_FOREIGN_RUNTIME",.true,"ooRexx Foreign Runtime v0.22.2-compatible package")
  self~addRequirement("LIBMARIADB",.true,"libmariadb/libmysqlclient shared library and packaged bulk shim")
  self~addCapability("TRANSACTIONS","SUPPORTED","DECLARED","Database Core transaction stream can remain on one MariaDB connection")
  self~addCapability("TYPED_RESULTS","SUPPORTED","TESTED","Native field metadata is normalized before bulk materialisation","tests/test_mysql_bulk_materialisation.rex")
  self~addCapability("RESULT_METADATA","SUPPORTED","TESTED","Column names and normalized common types are retained","tests/test_mysql_bulk_materialisation.rex")
  self~addCapability("BULK_RESULT_MATERIALISATION","SUPPORTED","TESTED","MYSQL_RES rows materialise directly into one ooRexx Array in one producer-owned pass","tests/test_mysql_bulk_materialisation.rex")
  self~addCapability("BULK_JSON_RESULT","SUPPORTED","TESTED","Materialised Array serialises through json.cls in one call with no tabular text round-trip","tests/test_mysql_bulk_materialisation.rex")
  self~addCapability("SESSION_REUSE","SUPPORTED","DECLARED","Low-level native session is reusable until close")
  self~addLimitation("NO_TEXT_ROUND_TRIP","Native querySet() never renders TSV/CSV merely to reparse it into rows")
  self~addLimitation("BINARY_JSON_REPRESENTATION","Binary fields use an exact lowercase hexadecimal string prefixed with \\x at the JSON/object boundary")
  self~addLimitation("NO_MID_TRANSACTION_FALLBACK","Once a native session is acquired, failures are returned and are not replayed through another backend")
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
  return l~client_version > 0
unavailable:
  return .false
::method availabilityEvidence
  d=self~availabilityEvidence:super
  if d["available"] then do
    d["client_version_number"]=self~library~client_version
    d["foreign_runtime_version"]=.foreign~runtimeInfo~runtimeVersion
    d["provider_path"]=self~library~providerPath
  end
  return d
::method acquire
  use strict arg connection
  if \self~available then return .nil
  s=.MySQLNativeSession~new(self,self~library,connection)
  if \s~connected then do; s~close; return .nil; end
  return s
::method querySet
  use strict arg connection, sql
  session=self~acquire(connection)
  if session==.nil then return .MySQLNativeBulkResult~failure("Unable to acquire MySQL/MariaDB native session","08006")
  rs=session~querySet(sql)
  ignore=session~close
  return rs

::class MySQLNativeSession public
::method init
  expose backend library connection handle connected lastError
  use strict arg backend, library, connection
  handle=.nil; connected=.false; lastError=""
  host=self~nullable(connection~host)
  port=connection~port
  db=self~nullable(connection~databaseName)
  user=self~nullable(connection~userName)
  password=.nil
  credential=connection~credential
  if credential\==.nil then do
    if credential~kind="password" then password=credential~value
    else if credential~kind<>"none" & credential~kind<>"environment" then do
      lastError="Unsupported credential kind for native MySQL/MariaDB: " || credential~kind
      return
    end
  end
  handle=library~connect(host,user,password,db,port)
  if handle==.nil then do; lastError="libmariadb returned no MYSQL handle"; return; end
  connected=.true
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
  if \connected then return ""
  return library~server_version(handle)
::method querySet
  expose connected library handle lastError
  use strict arg sql
  if \connected then return .MySQLNativeBulkResult~failure(lastError,"08006")
  nativeResult=library~query_set(handle,sql)
  if nativeResult==.nil then do
    lastError=library~connection_error(handle)
    state=library~connection_sqlstate(handle)
    return .MySQLNativeBulkResult~failure(lastError,state)
  end
  return .MySQLNativeBulkResult~new(library,nativeResult)
::method close
  expose handle connected
  if handle\==.nil then do; handle~close; handle=.nil; end
  connected=.false
  return self
::method uninit
  expose handle
  if symbol("HANDLE")="VAR" then if handle\==.nil then handle~close

::class MySQLNativeColumn public
::method init
  expose name nativeType commonType ordinal flags
  use strict arg name, nativeType, commonType, ordinal, flags=0
::attribute name get
::attribute nativeType get
::attribute commonType get
::attribute ordinal get
::attribute flags get

::class MySQLNativeBulkResult public subclass NativeDatabaseBulkResult
::method init
  expose library handle ok errorText sqlState columns rowCount fieldCount rows materialised closed
  use strict arg library=.nil, handle=.nil, ok=.true, errorText="", sqlState=""
  columns=.array~new; rows=.nil; materialised=.false; closed=.false
  rowCount=0; fieldCount=0
  if ok & handle\==.nil then do
    fieldCount=library~result_field_count(handle)
    rowCount=library~result_row_count(handle)
    do c=0 to fieldCount-1
      name=library~result_field_name(handle,c); if name==.nil then name=""
      nativeType=library~result_field_native_type(handle,c)
      commonType=library~result_field_common_type(handle,c)
      flags=library~result_field_flags(handle,c)
      columns~append(.MySQLNativeColumn~new(name,nativeType,commonType,c+1,flags))
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
  ignore=library~result_rewind(handle)
  do r=1 to rowCount
    if library~result_next(handle)<>1 then leave
    row=.directory~new
    do c=0 to fieldCount-1
      col=columns[c+1]
      if library~result_current_is_null(handle,c)=1 then value=.nil
      else do
        value=library~result_current_value(handle,c)
        if value==.nil then value=""
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

::requires "NativeDatabaseBackend.cls"
::requires "json.cls"
