/* msqlshim v0.21.2 - reconciled process-list surface + Alchemy Objects v0.8 + NoSQLServer v0.79 */

::requires "socket.cls"
::requires "src/MySQLDeflate.cls"
::requires "NoSQLServer.cls"
::requires "AlchemyObject.cls"

::class MySQLShimAlchemyObject subclass AlchemyObject public
::method init public
  expose mysqlAlchemySealer mysqlAlchemyAuthority
  use strict arg role = "MYSQLSHIM_OBJECT", purpose = "msqlshim service object", sealer = .nil, authority = .nil
  mysqlAlchemySealer = sealer
  mysqlAlchemyAuthority = authority
  meta = .directory~new
  meta["PURPOSE"] = purpose
  meta["PACKAGE"] = "msqlshim"
  meta["PACKAGE_VERSION"] = "0.21.2"
  meta["COMPONENT"] = "msqlshim"
  meta["ROLE"] = role
  meta["AUTHORSHIP"] = .array~of("msqlshim project")
  meta["STANDARDS"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.8", "MYSQL-CLASSIC-PROTOCOL-SERVICE-0.21")
  meta["DESIGN_LIMITATIONS"] = .array~of("Wire compatibility is not authentication authority", "SQL/storage semantics remain owned by NoSQLServer", "packet/row/value objects remain deliberately lightweight")
  /* Preferred Alchemy v0.8 construction chain. */
  forward class (super) array (meta, sealer, authority) continue
  self~registerExternalRequirement("database", "NoSQLServer", "0.79", .true, "", "PUBLIC")
  self~registerExternalRequirement("library", "Alchemy Objects", "0.8", .true, "", "PUBLIC")
  self~registerEnvironmentRequirement("ooRexx", "5.3.0 r13196 behavior profile validated", .true)
  return self

::method initMySQLAlchemy protected
  use strict arg role, purpose, sealer = .nil, authority = .nil
  return self~sendWith(.array~of("INIT", .MySQLShimAlchemyObject), .array~of(role, purpose, sealer, authority))

::method mysqlAlchemySealer protected
  expose mysqlAlchemySealer
  return mysqlAlchemySealer

::method mysqlAlchemyAuthority protected
  expose mysqlAlchemyAuthority
  return mysqlAlchemyAuthority

::class MySQLWireServer subclass MySQLShimAlchemyObject public
::attribute engine
::attribute host
::attribute port
::attribute serverSocket
::attribute running
::attribute backendGate
::attribute sessionRegistry

::constant CLIENT_LONG_PASSWORD      1
::constant CLIENT_LONG_FLAG          4
::constant CLIENT_COMPRESS           32
::constant CLIENT_CONNECT_WITH_DB    8
::constant CLIENT_PROTOCOL_41        512
::constant CLIENT_TRANSACTIONS       8192
::constant CLIENT_SECURE_CONNECTION  32768
::constant CLIENT_MULTI_RESULTS      131072
::constant CLIENT_PLUGIN_AUTH        524288
::constant CLIENT_CONNECT_ATTRS       1048576
::constant CLIENT_DEPRECATE_EOF       16777216
::constant CLIENT_OPTIONAL_RESULTSET_METADATA 33554432
::constant CLIENT_QUERY_ATTRIBUTES     134217728

::constant SERVER_STATUS_AUTOCOMMIT  2
::constant SERVER_STATUS_CURSOR_EXISTS 64
::constant SERVER_STATUS_LAST_ROW_SENT 128

::constant COM_QUIT                  1
::constant COM_INIT_DB               2
::constant COM_QUERY                 3
::constant COM_FIELD_LIST            4
::constant COM_STATISTICS            9
::constant COM_PROCESS_INFO          10
::constant COM_DEBUG                 13
::constant COM_PING                  14
::constant COM_SET_OPTION            27
::constant COM_STMT_PREPARE          22
::constant COM_STMT_EXECUTE          23
::constant COM_STMT_SEND_LONG_DATA   24
::constant COM_STMT_CLOSE            25
::constant COM_STMT_RESET            26
::constant COM_STMT_FETCH            28
::constant COM_RESET_CONNECTION      31

::method init
  expose engine host port serverSocket running
  use arg databaseRoot, host = "127.0.0.1", port = 3333, alchemySealer = .nil, alchemyAuthority = .nil
  self~init:super("WIRE_SERVER", "MySQL/MariaDB classic-protocol service facade for NoSQLServer", alchemySealer, alchemyAuthority)
  self~registerStateVariable("host", "PUBLIC", "listener host")
  self~registerStateVariable("port", "PUBLIC", "listener port")
  self~registerStateVariable("running", "CUSTOMER", "listener lifecycle state")
  self~registerMethodContract("SERVE", "serve MySQL wire clients", .array~new, "ANY", .false, "FALSE", "PUBLIC", "NORMAL", "EXTERNAL", "NONE")
  self~registerMethodContract("STOP", "stop listener", .array~new, "ANY", .false, "FALSE", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("COMPATIBILITYSNAPSHOT", "bounded declared protocol capability surface", .array~new, "DIRECTORY", .false, "FALSE", "PUBLIC", "NORMAL", "READ", "NONE")
  engine = .FileDatabaseEngine~new(databaseRoot)
  self~engine = engine
  self~host = host
  self~port = port
  serverSocket = .nil
  running = .false
  self~backendGate = .MySQLBackendGate~new(self~mysqlAlchemySealer, self~mysqlAlchemyAuthority)
  self~sessionRegistry = .MySQLSessionRegistry~new(self~mysqlAlchemySealer, self~mysqlAlchemyAuthority)
  self~recordRelationship("USES", engine, "native SQL/storage backend", "CUSTOMER")
  self~recordRelationship("USES", self~backendGate, "fair serialized backend scheduler", "INTERNAL")
  self~recordRelationship("USES", self~sessionRegistry, "active MySQL session catalogue", "INTERNAL")

::method compatibilitySnapshot public unguarded
  self~alchemyTouch("COMPATIBILITY_SNAPSHOT")
  d = .directory~new
  d["schema"] = "msqlshim.protocol-capabilities/0.1"
  d["msqlshim_version"] = "0.21.2"
  d["mysql_identity"] = "5.7.44-NoSQLServer-ooRexx"
  d["backend_release"] = .NoSQLServerBuild~RELEASE
  d["alchemy_base_version"] = .AlchemyObject~VERSION
  d["client_compress"] = .true
  d["client_deprecate_eof"] = .true
  d["client_optional_resultset_metadata"] = .true
  d["client_query_attributes"] = .true
  d["client_connect_attrs"] = .true
  d["handshake_database_selection"] = .true
  d["processlist"] = .true
  d["com_process_info"] = .true
  d["alchemy_standard_adoption"] = .true
  d["prepared_statements"] = .true
  d["prepared_read_only_cursors"] = .true
  d["tls"] = .false
  d["authentication"] = .false
  d["zstd_compression"] = .false
  return d

::method serve unguarded
  expose host port serverSocket running
  self~alchemyTouch("SERVE")
  listener = .Socket~new
  listener~setOption("SO_REUSEADDR", 1)
  address = .InetAddress~new(host, port)
  if listener~bind(address) < 0 then raise syntax 93.900 additional("MySQL wire bind failed errno=" || listener~errno)
  if listener~listen(64) < 0 then raise syntax 93.900 additional("MySQL wire listen failed errno=" || listener~errno)
  serverSocket = listener
  running = .true
  say "msqlshim MySQL wire listener on" host || ":" || port
  do while running
    client = listener~accept
    if client == .nil then leave
    -- stop() can wake a blocking accept by closing the listener.  Some socket
    -- implementations return a non-nil but unusable accepted socket in that
    -- race, so do not launch a new client activity after running was cleared.
    if \running then do
      client~close
      leave
    end
    self~start("serveClient", client)
  end
  if listener \== .nil then listener~close

::method stop unguarded
  expose running serverSocket
  self~alchemyTouch("STOP")
  running = .false
  if serverSocket \== .nil then serverSocket~close

::method serveClient unguarded
  expose engine running
  use arg rawSocket
  self~alchemyTouch("CLIENT_ACCEPTED")
  connection = .MySQLWireConnection~new(rawSocket, self~mysqlAlchemySealer, self~mysqlAlchemyAuthority)
  connection~recordRelationship("SERVED_BY", self, "wire listener identity", "INTERNAL")
  currentDatabase = "nosqlserver"
  connectionId = self~sessionRegistry~allocateId
  connection~connectionId = connectionId

  signal on syntax name clientFailure

  capabilities = self~serverCapabilities
  scramble = "12345678abcdefgh1234"
  handshake = d2c(10) || "5.7.44-NoSQLServer-ooRexx" || "00"x ||,
      self~le32(connectionId) || scramble~substr(1, 8) || "00"x ||,
      self~le16(capabilities // 65536) || d2c(45) || self~le16(self~SERVER_STATUS_AUTOCOMMIT) ||,
      self~le16(capabilities % 65536) || d2c(21) || copies("00"x, 10) ||,
      scramble~substr(9, 12) || "00"x || "mysql_native_password" || "00"x
  self~sendPacket(connection, 0, handshake)

  response = self~readPacket(connection)
  if response == .nil then signal clientDone
  responsePayload = response["payload"]
  if responsePayload~length < 4 then do
    self~sendError(connection, 2, 1043, "08S01", "Malformed handshake response")
    signal clientDone
  end
  clientCapabilities = self~readLE32(responsePayload, 1)
  connection~clientCapabilities = clientCapabilities

  handshakeInfo = self~decodeHandshakeResponse(connection, responsePayload)
  if handshakeInfo["error"] \= "" then do
    self~sendError(connection, response["sequence"] + 1, 1043, "08S01", handshakeInfo["error"])
    signal clientDone
  end
  if handshakeInfo["database"] \= "" then currentDatabase = handshakeInfo["database"]
  self~sessionRegistry~register(connectionId, connection~clientUser, currentDatabase)

  -- NoSQLServer itself currently has no account/authentication layer.  This
  -- listener deliberately accepts the protocol handshake without validating
  -- the auth-response bytes.  Bind to loopback unless the caller chooses otherwise.
  self~sendOK(connection, response["sequence"] + 1, 0, 0)

  -- CLIENT_COMPRESS becomes active only after the connection-phase OK packet.
  if self~hasCapability(clientCapabilities, self~CLIENT_COMPRESS) then connection~compressionEnabled = .true

  do forever
    packet = self~readPacket(connection)
    if packet == .nil then leave
    payload = packet["payload"]
    if payload~length = 0 then leave
    command = c2d(payload~substr(1, 1))
    commandData = payload~substr(2)

    select
      when command = self~COM_QUIT then leave
      when command = self~COM_PING then self~sendOK(connection, 1, 0, 0)
      when command = self~COM_INIT_DB then do
        currentDatabase = commandData
        self~sessionRegistry~updateDatabase(connectionId, currentDatabase)
        self~sendOK(connection, 1, 0, 0)
      end
      when command = self~COM_QUERY then do
        self~sessionRegistry~updateState(connectionId, "Query", "executing")
        queryData = self~decodeQueryCommand(connection, commandData)
        if queryData["error"] \= "" then self~sendError(connection, 1, 1210, "HY000", queryData["error"])
        else do
          queryResult = self~handleQuery(connection, queryData["sql"], currentDatabase)
          if queryResult \== .nil then do
            currentDatabase = queryResult
            self~sessionRegistry~updateDatabase(connectionId, currentDatabase)
          end
        end
        self~sessionRegistry~updateState(connectionId, "Sleep", "")
      end
      when command = self~COM_FIELD_LIST then self~handleFieldList(connection, commandData, currentDatabase)
      when command = self~COM_STATISTICS then self~sendPacket(connection, 1, self~statisticsText)
      when command = self~COM_PROCESS_INFO then self~sendProcessList(connection, currentDatabase)
      when command = self~COM_DEBUG then do
        say "msqlshim COM_DEBUG connection database=" currentDatabase "compression=" connection~compressionEnabled
        self~sendOK(connection, 1, 0, 0)
      end
      when command = self~COM_SET_OPTION then self~handleSetOption(connection, commandData)
      when command = self~COM_STMT_PREPARE then self~handleStmtPrepare(connection, commandData, currentDatabase)
      when command = self~COM_STMT_EXECUTE then self~handleStmtExecute(connection, commandData, currentDatabase)
      when command = self~COM_STMT_SEND_LONG_DATA then self~handleStmtLongData(connection, commandData)
      when command = self~COM_STMT_CLOSE then self~handleStmtClose(connection, commandData)
      when command = self~COM_STMT_RESET then self~handleStmtReset(connection, commandData)
      when command = self~COM_STMT_FETCH then self~handleStmtFetch(connection, commandData)
      when command = self~COM_RESET_CONNECTION then do
        currentDatabase = "nosqlserver"
        connection~resetSession
        self~sendOK(connection, 1, 0, 0)
      end
      otherwise self~sendError(connection, 1, 1047, "08S01", "Unsupported MySQL command " || command)
    end
  end

clientDone:
  self~sessionRegistry~remove(connectionId)
  connection~socket~close
  return

clientFailure:
  info = condition("O")
  -- A stop() closes the listener to wake accept; suppress the harmless socket
  -- failure from a client activity created in that shutdown race.
  if running then do
    say "MySQL wire client failure:" info["MESSAGE"] info["ADDITIONAL"]
    do key over info~allIndexes
      say "  condition" key "=" info[key]
    end
  end
  self~sessionRegistry~remove(connectionId)
  connection~socket~close
  return


::method decodeHandshakeResponse private unguarded
  use arg connection, payload
  out = .directory~new
  out["error"] = ""
  out["database"] = ""
  if payload~length < 32 then do
    out["error"] = "Malformed handshake response"
    return out
  end

  capabilities = connection~clientCapabilities
  connection~clientMaxPacket = self~readLE32(payload, 5)
  connection~clientCharacterSet = c2d(payload~substr(9, 1))
  offset = 33

  userInfo = self~readNulStringAt(payload, offset)
  if userInfo["error"] \= "" then do; out["error"] = userInfo["error"]; return out; end
  connection~clientUser = userInfo["text"]
  offset = userInfo["next"]

  -- We advertise CLIENT_SECURE_CONNECTION but not
  -- CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA, therefore the normal authentication
  -- response is a one-byte length followed by opaque bytes.  Authentication is
  -- still deliberately not validated; parsing it is required to locate the
  -- following database/plugin/attribute fields correctly.
  if self~hasCapability(capabilities, self~CLIENT_SECURE_CONNECTION) then do
    if offset > payload~length then do; out["error"] = "Truncated authentication response"; return out; end
    authLength = c2d(payload~substr(offset, 1))
    offset += 1
    if offset + authLength - 1 > payload~length then do; out["error"] = "Truncated authentication response"; return out; end
    offset += authLength
  end
  else do
    authInfo = self~readNulStringAt(payload, offset)
    if authInfo["error"] \= "" then do; out["error"] = authInfo["error"]; return out; end
    offset = authInfo["next"]
  end

  if self~hasCapability(capabilities, self~CLIENT_CONNECT_WITH_DB) then do
    dbInfo = self~readNulStringAt(payload, offset)
    if dbInfo["error"] \= "" then do; out["error"] = dbInfo["error"]; return out; end
    out["database"] = dbInfo["text"]
    connection~requestedDatabase = dbInfo["text"]
    offset = dbInfo["next"]
  end

  if self~hasCapability(capabilities, self~CLIENT_PLUGIN_AUTH) then do
    pluginInfo = self~readNulStringAt(payload, offset)
    if pluginInfo["error"] \= "" then do; out["error"] = pluginInfo["error"]; return out; end
    connection~authPlugin = pluginInfo["text"]
    offset = pluginInfo["next"]
  end

  attrs = .directory~new
  if self~hasCapability(capabilities, self~CLIENT_CONNECT_ATTRS) then do
    totalInfo = self~readLenEncIntAt(payload, offset)
    if totalInfo["error"] \= "" then do; out["error"] = "Malformed connection attributes: " || totalInfo["error"]; return out; end
    offset = totalInfo["next"]
    attrsEnd = offset + totalInfo["value"]
    if attrsEnd - 1 > payload~length then do; out["error"] = "Truncated connection attributes"; return out; end
    do while offset < attrsEnd
      keyInfo = self~readLenEncStringAt(payload, offset)
      if keyInfo["error"] \= "" then do; out["error"] = "Malformed connection attribute key"; return out; end
      valueInfo = self~readLenEncStringAt(payload, keyInfo["next"])
      if valueInfo["error"] \= "" then do; out["error"] = "Malformed connection attribute value"; return out; end
      if valueInfo["next"] > attrsEnd then do; out["error"] = "Connection attribute exceeds declared block"; return out; end
      -- Keep only the final value for duplicate keys, matching directory semantics.
      -- Values remain connection-local and are not copied into Alchemy telemetry.
      attrs[keyInfo["text"]] = valueInfo["text"]
      offset = valueInfo["next"]
    end
    if offset \= attrsEnd then do; out["error"] = "Malformed connection attribute block"; return out; end
  end
  connection~connectionAttributes = attrs
  connection~alchemyTouch("HANDSHAKE_PARSED")
  return out

::method readNulStringAt private unguarded
  use arg data, offset
  out = .directory~new
  out["error"] = ""
  if offset > data~length then do; out["error"] = "Truncated NUL-terminated handshake field"; return out; end
  tail = data~substr(offset)
  zero = tail~pos("00"x)
  if zero = 0 then do; out["error"] = "Unterminated handshake field"; return out; end
  out["text"] = tail~substr(1, zero - 1)
  out["next"] = offset + zero
  return out

::method decodeQueryCommand private unguarded
  use arg connection, commandData
  out = .table~new
  out["error"] = ""
  out["sql"] = commandData
  out["attributes"] = .array~new
  if \self~hasCapability(connection~clientCapabilities, self~CLIENT_QUERY_ATTRIBUTES) then return out

  countInfo = self~readLenEncIntAt(commandData, 1)
  if countInfo["error"] \= "" then return self~queryDecodeFailure(countInfo["error"])
  parameterCount = countInfo["value"]
  setInfo = self~readLenEncIntAt(commandData, countInfo["next"])
  if setInfo["error"] \= "" then return self~queryDecodeFailure(setInfo["error"])
  if setInfo["value"] \= 1 then return self~queryDecodeFailure("COM_QUERY parameter_set_count must be 1")
  offset = setInfo["next"]
  if parameterCount = 0 then do
    out["sql"] = commandData~substr(offset)
    return out
  end

  decoded = self~decodeNamedParameters(commandData, offset, parameterCount)
  if decoded["error"] \= "" then return self~queryDecodeFailure(decoded["error"])
  out["attributes"] = decoded["attributes"]
  sqlText = commandData~substr(decoded["next"])

  -- COM_QUERY query attributes can also carry positional query parameters.
  -- The first values satisfy ordinary ? placeholders; any remaining values
  -- are retained only as per-command attributes and never become authority.
  placeholderCount = .DatabaseParameterBinder~countPlaceholders(sqlText)
  if placeholderCount > parameterCount then return self~queryDecodeFailure("COM_QUERY has fewer parameters than SQL placeholders")
  if placeholderCount > 0 then do
    parameters = .array~new
    values = decoded["values"]
    do i = 1 to placeholderCount
      parameters~append(values[i])
    end
    ps = .NoSQLDatabaseCorePreparedStatement~new("mysql_query_attributes", sqlText)
    boundSql = .DatabaseParameterBinder~bind(ps, parameters)
    if boundSql~isA(.DatabaseResult) then return self~queryDecodeFailure(boundSql~message)
    sqlText = boundSql
  end
  out["sql"] = sqlText
  return out

::method queryDecodeFailure private unguarded
  use arg message
  out = .table~new
  out["error"] = message
  out["sql"] = ""
  out["attributes"] = .array~new
  return out

::method decodeNamedParameters private unguarded
  use arg data, offset, count
  out = .table~new
  out["error"] = ""
  out["attributes"] = .array~new
  out["values"] = .array~new
  bitmapLength = (count + 7) % 8
  if offset + bitmapLength - 1 > data~length then return self~namedParameterFailure("Truncated query-attribute NULL bitmap")
  nullBitmap = data~substr(offset, bitmapLength)
  offset += bitmapLength
  if offset > data~length then return self~namedParameterFailure("Missing query-attribute bind flag")
  newTypes = c2d(data~substr(offset,1)); offset += 1
  if newTypes \= 1 then return self~namedParameterFailure("Query attributes require new_params_bind_flag=1")

  types = .array~new
  names = .array~new
  do i = 1 to count
    if offset + 1 > data~length then return self~namedParameterFailure("Truncated query-attribute type vector")
    typeInfo = .table~new
    typeInfo["type"] = c2d(data~substr(offset,1))
    typeInfo["unsigned"] = (c2d(data~substr(offset+1,1)) >= 128)
    offset += 2
    nameInfo = self~readLenEncStringAt(data, offset)
    if nameInfo["error"] \= "" then return self~namedParameterFailure(nameInfo["error"])
    offset = nameInfo["next"]
    types~append(typeInfo); names~append(nameInfo["text"])
  end

  do i = 1 to count
    bitmapByte = ((i - 1) % 8) + 1
    bitmapBit = (i - 1) // 8
    byteValue = c2d(nullBitmap~substr(bitmapByte,1))
    isNull = ((byteValue % (2 ** bitmapBit)) // 2) = 1
    if isNull then value = .DatabaseValue~nullValue
    else do
      typeInfo = types[i]
      valueResult = self~decodeBinaryParameter(typeInfo["type"], typeInfo["unsigned"], data, offset)
      if valueResult["error"] \= "" then return self~namedParameterFailure(valueResult["error"])
      offset = valueResult["next"]
      value = valueResult["value"]
    end
    out["values"]~append(value)
    attr = .table~new; attr["name"] = names[i]; attr["value"] = value
    out["attributes"]~append(attr)
  end
  out["next"] = offset
  return out

::method namedParameterFailure private unguarded
  use arg message
  out = .table~new
  out["error"] = message
  out["attributes"] = .array~new
  out["values"] = .array~new
  out["next"] = 0
  return out

::method handleQuery private unguarded
  expose engine
  use arg socket, sqlText, currentDatabase
  stripped = sqlText~strip
  upper = stripped~translate

  -- Session bootstrap statements commonly emitted by MySQL client libraries.
  if upper~startsWith("SET ") then do
    self~sendOK(socket, 1, 0, 0)
    return currentDatabase
  end
  if upper~startsWith("USE ") then do
    dbName = stripped~substr(5)~strip
    if dbName~left(1) = "`" & dbName~right(1) = "`" then dbName = dbName~substr(2, dbName~length - 2)
    self~sendOK(socket, 1, 0, 0)
    return dbName
  end

  if upper = "SHOW PROCESSLIST" | upper = "SHOW PROCESSLIST;" | upper = "SHOW FULL PROCESSLIST" | upper = "SHOW FULL PROCESSLIST;" then do
    self~sendProcessList(socket, currentDatabase)
    return currentDatabase
  end

  -- MySQL metadata commands are shim concerns: do not push them into the
  -- backend SQL parser.  One FileDatabaseEngine instance represents one
  -- database/catalog and exposes its registered tables through database.yaml.
  if upper = "SHOW DATABASES" | upper = "SHOW DATABASES;" then do
    names = .array~of("Database")
    types = .array~of(.DatabaseType~VARCHAR)
    rows = .array~new
    rows~append(.array~of(currentDatabase))
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end
  -- DESCRIBE / DESC / SHOW COLUMNS are MySQL metadata syntax.  Resolve
  -- them through the existing databaseCore metadata surface rather than
  -- teaching the NoSQLServer SQL parser MySQL-specific commands.
  metadataKind = self~metadataCommandKind(stripped)
  if metadataKind \= "" then do
    tableName = self~metadataCommandTable(stripped, metadataKind)
    if tableName = "" then do
      self~sendError(socket, 1, 1064, "42000", "Malformed metadata command")
      return currentDatabase
    end
    if \self~catalogHasTable(engine, tableName) then do
      self~sendError(socket, 1, 1146, "42S02", "Table '" || currentDatabase || "." || tableName || "' doesn't exist")
      return currentDatabase
    end
    core = engine~databaseCore
    metadata = core~tableMetadata(tableName)
    rows = .array~new
    do column over metadata~columns
      nullText = "YES"
      if column~nullable = .false then nullText = "NO"
      rows~append(.array~of(column~name, self~mysqlTypeName(column~engineType), nullText, "", .nil, ""))
    end
    names = .array~of("Field", "Type", "Null", "Key", "Default", "Extra")
    types = .array~of(.DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR)
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end

  if upper = "SHOW TABLES" | upper = "SHOW TABLES;" | upper = "SHOW FULL TABLES" | upper = "SHOW FULL TABLES;" then do
    catalog = engine~readCatalog
    tableNames = catalog["tables"]
    if tableNames == .nil then tableNames = .array~new
    rows = .array~new
    if upper~startsWith("SHOW FULL TABLES") then do
      names = .array~of("Tables_in_" || currentDatabase, "Table_type")
      types = .array~of(.DatabaseType~VARCHAR, .DatabaseType~VARCHAR)
      do tableName over tableNames
        rows~append(.array~of(tableName, "BASE TABLE"))
      end
    end
    else do
      names = .array~of("Tables_in_" || currentDatabase)
      types = .array~of(.DatabaseType~VARCHAR)
      do tableName over tableNames
        rows~append(.array~of(tableName))
      end
    end
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end

  -- Connector bootstrap/session personality.  These are MySQL protocol-ecology
  -- queries, not NoSQLServer SQL semantics, so answer them in the shim.
  -- The values describe the compatibility session exposed by msqlshim; they
  -- are not fabricated backend storage metadata.
  variableName = self~systemVariableSelectName(stripped)
  if variableName \= "" then do
    variableValue = self~systemVariableValue(variableName)
    if variableValue == .nil then do
      self~sendError(socket, 1, 1193, "HY000", "Unknown system variable '" || variableName || "'")
      return currentDatabase
    end
    names = .array~of("@@" || variableName)
    types = .array~of(.DatabaseType~VARCHAR)
    rows = .array~of(.array~of(variableValue))
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end

  showKind = self~showBootstrapKind(stripped)
  if showKind = "VARIABLES" then do
    pattern = self~showLikePattern(stripped)
    names = .array~of("Variable_name", "Value")
    types = .array~of(.DatabaseType~VARCHAR, .DatabaseType~VARCHAR)
    rows = self~systemVariableRows(pattern)
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end
  if showKind = "STATUS" then do
    pattern = self~showLikePattern(stripped)
    names = .array~of("Variable_name", "Value")
    types = .array~of(.DatabaseType~VARCHAR, .DatabaseType~VARCHAR)
    rows = self~statusRows(pattern, socket)
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end

  -- A few harmless identity probes make ordinary connectors and test tools
  -- feel at home without pushing MySQL-specific SQL into the NoSQLServer parser.
  if upper = "SELECT VERSION()" | upper = "SELECT VERSION();" then do
    names = .array~of("VERSION()")
    types = .array~of(.DatabaseType~VARCHAR)
    row = .array~of("5.7.44-NoSQLServer-ooRexx")
    rows = .array~of(row)
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end
  if upper = "SELECT DATABASE()" | upper = "SELECT DATABASE();" then do
    names = .array~of("DATABASE()")
    types = .array~of(.DatabaseType~VARCHAR)
    row = .array~of(currentDatabase)
    rows = .array~of(row)
    self~sendSyntheticResult(socket, currentDatabase, names, types, rows)
    return currentDatabase
  end

  isQuery = upper~startsWith("SELECT ") | upper~startsWith("WITH ")
  if isQuery then do
    coreResult = self~backendQuery(stripped)
    if coreResult~success = .false then do
      self~sendDatabaseError(socket, coreResult~error, coreResult~message)
      return currentDatabase
    end
    -- The fair backend ticket is released before result encoding/socket writes.
    -- A slow or blocked client must not retain the database execution slot.
    self~sendCoreResult(socket, currentDatabase, coreResult)
    return currentDatabase
  end

  nativeResult = self~backendExecute(stripped)
  if nativeResult~status \= .Error~SUCCESS then do
    self~sendDatabaseError(socket, nativeResult~error, nativeResult~message)
    return currentDatabase
  end
  self~sendOK(socket, 1, nativeResult~affectedRows, 0)
  return currentDatabase


::method backendQuery private unguarded
  expose engine backendGate
  use arg sqlText
  ticket = backendGate~enter
  signal on syntax name backendQueryFailure
  core = engine~databaseCore
  resultSchema = self~wildcardResultSchema(core, sqlText)
  if resultSchema == .nil then coreResult = core~query(sqlText)
  else coreResult = core~queryWithSchema(sqlText, resultSchema)
  backendGate~leave(ticket)
  signal off syntax
  return coreResult
backendQueryFailure:
  backendGate~leave(ticket)
  signal off syntax
  raise propagate

::method backendExecute private unguarded
  expose engine backendGate
  use arg sqlText
  ticket = backendGate~enter
  signal on syntax name backendExecuteFailure
  nativeResult = engine~execute(sqlText)
  backendGate~leave(ticket)
  signal off syntax
  return nativeResult
backendExecuteFailure:
  backendGate~leave(ticket)
  signal off syntax
  raise propagate

::method systemVariableSelectName private unguarded
  use arg sqlText
  text = sqlText~strip
  if text~right(1) = ";" then text = text~left(text~length - 1)~strip
  upper = text~translate
  if \upper~startsWith("SELECT @@") then return ""

  expression = text~substr(10)~strip
  if expression = "" then return ""
  -- This compatibility surface intentionally handles the common one-variable
  -- bootstrap form.  A comma means this is a general SELECT and belongs to the
  -- SQL engine until/unless a wider MySQL expression shim is deliberately added.
  if expression~pos(",") > 0 then return ""
  variableName = expression~word(1)
  variableName = variableName~translate
  if variableName~startsWith("SESSION.") then variableName = variableName~substr(9)
  if variableName~startsWith("GLOBAL.") then variableName = variableName~substr(8)
  return variableName~lower

::method systemVariableValue private unguarded
  use arg variableName
  name = variableName~string~translate
  select
    when name = "VERSION" then return "5.7.44-NoSQLServer-ooRexx"
    when name = "VERSION_COMMENT" then return "NoSQLServer ooRexx MySQL wire compatibility shim"
    when name = "SQL_MODE" then return ""
    when name = "CHARACTER_SET_CLIENT" then return "utf8mb4"
    when name = "CHARACTER_SET_CONNECTION" then return "utf8mb4"
    when name = "CHARACTER_SET_RESULTS" then return "utf8mb4"
    when name = "CHARACTER_SET_SERVER" then return "utf8mb4"
    when name = "COLLATION_CONNECTION" then return "utf8mb4_general_ci"
    when name = "COLLATION_SERVER" then return "utf8mb4_general_ci"
    when name = "AUTOCOMMIT" then return "1"
    when name = "MAX_ALLOWED_PACKET" then return "16777216"
    when name = "PROTOCOL_COMPRESSION_ALGORITHMS" then return "zlib,uncompressed"
    when name = "MSQLSHIM_VERSION" then return "0.21.2"
    when name = "NOSQLSERVER_RELEASE" then return .NoSQLServerBuild~RELEASE
    when name = "NOSQLSERVER_SQL_LEVEL" then return .NoSQLServerBuild~SQLLEVEL
    when name = "ALCHEMY_OBJECT_VERSION" then return self~VERSION
    otherwise return .nil
  end

::method systemVariableRows private unguarded
  use arg pattern = ""
  variableNames = .array~of("alchemy_object_version", "autocommit", "character_set_client", "character_set_connection",,
      "character_set_results", "character_set_server", "collation_connection",,
      "collation_server", "max_allowed_packet", "msqlshim_version", "nosqlserver_release", "nosqlserver_sql_level",,
      "protocol_compression_algorithms", "sql_mode", "version", "version_comment")
  rows = .array~new
  do variableName over variableNames
    if self~sqlLikeMatches(variableName, pattern) then do
      rows~append(.array~of(variableName, self~systemVariableValue(variableName)))
    end
  end
  return rows

::method statusRows private unguarded
  use arg pattern = "", connection = .nil
  -- Compatibility/session status only.  These are deliberately modest shim
  -- values, not claims about NoSQLServer operational telemetry.
  statusNames = .array~of("Compression", "Compression_algorithm", "Compression_level", "Connections", "Questions", "Ssl_cipher", "Threads_connected", "Uptime")
  rows = .array~new
  do statusName over statusNames
    if self~sqlLikeMatches(statusName, pattern) then do
      select
        when statusName = "Compression" then do
          if connection == .nil then statusValue = "OFF"
          else if connection~compressionEnabled then statusValue = "ON"
          else statusValue = "OFF"
        end
        when statusName = "Compression_algorithm" then do
          if connection == .nil then statusValue = "uncompressed"
          else if connection~compressionEnabled then statusValue = "zlib"
          else statusValue = "uncompressed"
        end
        when statusName = "Compression_level" then statusValue = "0"
        when statusName = "Connections" then statusValue = self~sessionRegistry~totalConnections
        when statusName = "Questions" then statusValue = "0"
        when statusName = "Ssl_cipher" then statusValue = ""
        when statusName = "Threads_connected" then statusValue = self~sessionRegistry~count
        when statusName = "Uptime" then statusValue = "0"
        otherwise statusValue = ""
      end
      rows~append(.array~of(statusName, statusValue))
    end
  end
  return rows

::method showBootstrapKind private unguarded
  use arg sqlText
  text = sqlText~strip
  if text~right(1) = ";" then text = text~left(text~length - 1)~strip
  upper = text~translate
  if upper = "SHOW VARIABLES" then return "VARIABLES"
  if upper~startsWith("SHOW VARIABLES LIKE ") then return "VARIABLES"
  if upper = "SHOW SESSION VARIABLES" then return "VARIABLES"
  if upper~startsWith("SHOW SESSION VARIABLES LIKE ") then return "VARIABLES"
  if upper = "SHOW GLOBAL VARIABLES" then return "VARIABLES"
  if upper~startsWith("SHOW GLOBAL VARIABLES LIKE ") then return "VARIABLES"
  if upper = "SHOW STATUS" then return "STATUS"
  if upper~startsWith("SHOW STATUS LIKE ") then return "STATUS"
  if upper = "SHOW SESSION STATUS" then return "STATUS"
  if upper~startsWith("SHOW SESSION STATUS LIKE ") then return "STATUS"
  if upper = "SHOW GLOBAL STATUS" then return "STATUS"
  if upper~startsWith("SHOW GLOBAL STATUS LIKE ") then return "STATUS"
  return ""

::method showLikePattern private unguarded
  use arg sqlText
  text = sqlText~strip
  if text~right(1) = ";" then text = text~left(text~length - 1)~strip
  upper = text~translate
  likePos = upper~pos(" LIKE ")
  if likePos = 0 then return ""
  pattern = text~substr(likePos + 6)~strip
  if pattern~length >= 2 then do
    first = pattern~left(1)
    last = pattern~right(1)
    if first = "'" then do
      if last = "'" then pattern = pattern~substr(2, pattern~length - 2)
    end
    else if first = '"' then do
      if last = '"' then pattern = pattern~substr(2, pattern~length - 2)
    end
  end
  return pattern

::method sqlLikeMatches private unguarded
  use arg text, pattern
  if pattern = "" then return .true
  return self~sqlLikeMatchAt(text~string, pattern~string)

::method sqlLikeMatchAt private unguarded
  use arg text, pattern
  if pattern = "" then return text = ""

  token = pattern~substr(1, 1)
  remainder = pattern~substr(2)
  if token = "%" then do
    if self~sqlLikeMatchAt(text, remainder) then return .true
    do i = 1 to text~length
      if self~sqlLikeMatchAt(text~substr(i + 1), remainder) then return .true
    end
    return .false
  end

  if text = "" then return .false
  if token = "_" then return self~sqlLikeMatchAt(text~substr(2), remainder)
  if text~substr(1, 1)~caselessEquals(token) then return self~sqlLikeMatchAt(text~substr(2), remainder)
  return .false

::method metadataCommandKind private unguarded
  use arg sqlText
  text = sqlText~strip
  if text~right(1) = ";" then text = text~left(text~length - 1)~strip
  upper = text~translate
  if upper~startsWith("DESCRIBE ") then return "DESCRIBE"
  if upper~startsWith("DESC ") then return "DESC"
  if upper~startsWith("SHOW COLUMNS FROM ") then return "SHOW COLUMNS"
  if upper~startsWith("SHOW FULL COLUMNS FROM ") then return "SHOW FULL COLUMNS"
  return ""

::method metadataCommandTable private unguarded
  use arg sqlText, metadataKind
  text = sqlText~strip
  if text~right(1) = ";" then text = text~left(text~length - 1)~strip
  select
    when metadataKind = "DESCRIBE" then rest = text~substr(10)~strip
    when metadataKind = "DESC" then rest = text~substr(6)~strip
    when metadataKind = "SHOW COLUMNS" then rest = text~substr(19)~strip
    when metadataKind = "SHOW FULL COLUMNS" then rest = text~substr(24)~strip
    otherwise return ""
  end
  if rest = "" then return ""
  tableName = rest~word(1)
  if tableName~left(1) = "`" then do
    if tableName~right(1) = "`" then tableName = tableName~substr(2, tableName~length - 2)
  end
  return tableName

::method catalogHasTable private unguarded
  use arg engine, tableName
  catalog = engine~readCatalog
  tableNames = catalog["tables"]
  if tableNames == .nil then return .false
  wanted = tableName~translate
  do item over tableNames
    if item~string~translate = wanted then return .true
  end
  return .false

::method mysqlTypeName private unguarded
  use arg engineType
  typeName = engineType~string~translate
  select
    when typeName = "BOOLEAN" then return "tinyint(1)"
    when typeName = "INTEGER" then return "int"
    when typeName = "DECIMAL" then return "decimal"
    when typeName = "VARCHAR" then return "varchar(1024)"
    when typeName = "TEXT" then return "text"
    when typeName = "DATE" then return "date"
    when typeName = "DATETIME" then return "datetime"
    when typeName = "BLOB" then return "blob"
    otherwise return typeName~lower
  end

::method sendProcessList private unguarded
  use arg connection, currentDatabase
  rows = self~sessionRegistry~rows
  names = .array~of("Id", "User", "Host", "db", "Command", "Time", "State", "Info")
  types = .array~of(.DatabaseType~INTEGER, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR, .DatabaseType~INTEGER, .DatabaseType~VARCHAR, .DatabaseType~VARCHAR)
  self~sendSyntheticResult(connection, currentDatabase, names, types, rows)
  return

::method handleFieldList private unguarded
  expose engine
  use arg connection, commandData, currentDatabase
  nul = commandData~pos("00"x)
  if nul = 0 then tableName = commandData
  else tableName = commandData~left(nul - 1)
  wildcard = ""
  if nul > 0 then wildcard = commandData~substr(nul + 1)
  if \self~catalogHasTable(engine, tableName) then do
    self~sendError(connection, 1, 1146, "42S02", "Table '" || currentDatabase || "." || tableName || "' doesn't exist")
    return
  end
  metadata = engine~databaseCore~tableMetadata(tableName)
  sequence = 1
  do column over metadata~columns
    if wildcard = "" then matched = .true
    else matched = self~sqlLikeMatches(column~name, wildcard)
    if matched then do
      self~sendPacket(connection, sequence, self~columnDefinition(currentDatabase, column~name, column~databaseType))
      sequence += 1
    end
  end
  self~sendEOF(connection, sequence)

::method handleSetOption private unguarded
  use arg connection, commandData
  if commandData~length < 2 then do
    self~sendError(connection, 1, 1043, "08S01", "Malformed COM_SET_OPTION")
    return
  end
  option = c2d(commandData~substr(1,1)) + c2d(commandData~substr(2,1)) * 256
  if option = 0 then do
    connection~multiStatements = .true
    self~sendOK(connection, 1, 0, 0)
    return
  end
  if option = 1 then do
    connection~multiStatements = .false
    self~sendOK(connection, 1, 0, 0)
    return
  end
  self~sendError(connection, 1, 1231, "42000", "Unsupported COM_SET_OPTION value " || option)

::method handleStmtPrepare private unguarded
  expose engine backendGate
  use arg connection, sqlText, currentDatabase
  statementId = connection~allocateStatementId
  parameterCount = .DatabaseParameterBinder~countPlaceholders(sqlText)
  metadata = self~preparedResultMetadata(sqlText)
  columnCount = metadata["names"]~items

  entry = .table~new
  entry["id"] = statementId
  entry["sql"] = sqlText
  entry["parameterCount"] = parameterCount
  entry["metadata"] = metadata
  entry["parameterTypes"] = .array~new
  entry["longData"] = .table~new
  entry["cursorResult"] = .nil
  entry["cursorPosition"] = 1
  connection~preparedStatements[statementId] = entry

  payload = "00"x || self~le32(statementId) || self~le16(columnCount) ||,
      self~le16(parameterCount) || "00"x || self~le16(0)
  self~sendPacket(connection, 1, payload)
  sequence = 2

  -- Parameter metadata is deliberately generic VARCHAR.  COM_STMT_EXECUTE
  -- carries the actual bound types, which are retained per statement when the
  -- client uses new_params_bind_flag=0 on later executions.
  if parameterCount > 0 then do
    do i = 1 to parameterCount
      self~sendPacket(connection, sequence, self~columnDefinition(currentDatabase, "?", .DatabaseType~VARCHAR))
      sequence += 1
    end
    if \self~hasCapability(connection~clientCapabilities, self~CLIENT_DEPRECATE_EOF) then do
      self~sendEOF(connection, sequence)
      sequence += 1
    end
  end

  if columnCount > 0 then do
    names = metadata["names"]
    types = metadata["types"]
    do i = 1 to columnCount
      self~sendPacket(connection, sequence, self~columnDefinition(currentDatabase, names[i], types[i]))
      sequence += 1
    end
    if \self~hasCapability(connection~clientCapabilities, self~CLIENT_DEPRECATE_EOF) then self~sendEOF(connection, sequence)
  end

::method handleStmtExecute private unguarded
  use arg connection, commandData, currentDatabase
  if commandData~length < 9 then do
    self~sendError(connection, 1, 1043, "08S01", "Malformed COM_STMT_EXECUTE")
    return
  end
  statementId = self~readLE32(commandData, 1)
  entry = connection~preparedStatements[statementId]
  if entry == .nil then do
    self~sendError(connection, 1, 1243, "HY000", "Unknown prepared statement handler (" || statementId || ")")
    return
  end
  rawFlags = c2d(commandData~substr(5,1))
  cursorFlags = rawFlags // 8
  parameterCountAvailable = (rawFlags // 16) >= 8
  if cursorFlags \= 0 then do
    if cursorFlags \= 1 then do
      self~sendError(connection, 1, 1235, "42000", "Only CURSOR_TYPE_READ_ONLY prepared cursors are supported")
      return
    end
  end
  iterationCount = self~readLE32(commandData, 6)
  if iterationCount \= 1 then do
    self~sendError(connection, 1, 1235, "42000", "COM_STMT_EXECUTE iteration count must be 1")
    return
  end

  -- Re-execution closes any cursor previously opened for this statement.
  entry["cursorResult"] = .nil
  entry["cursorPosition"] = 1

  parameterOffset = 10
  suppliedCount = entry["parameterCount"]
  if self~hasCapability(connection~clientCapabilities, self~CLIENT_QUERY_ATTRIBUTES) & parameterCountAvailable then do
    countInfo = self~readLenEncIntAt(commandData, parameterOffset)
    if countInfo["error"] \= "" then do
      self~sendError(connection, 1, 1210, "HY000", countInfo["error"])
      return
    end
    suppliedCount = countInfo["value"]
    parameterOffset = countInfo["next"]
  end
  if suppliedCount < entry["parameterCount"] then do
    self~sendError(connection, 1, 1210, "HY000", "COM_STMT_EXECUTE supplied fewer parameters than prepared placeholders")
    return
  end

  decoded = self~decodeStmtParameters(entry, commandData, parameterOffset, suppliedCount, self~hasCapability(connection~clientCapabilities, self~CLIENT_QUERY_ATTRIBUTES))
  if decoded["error"] \= "" then do
    self~sendError(connection, 1, 1210, "HY000", decoded["error"])
    return
  end
  parameters = decoded["parameters"]
  sqlUpper = entry["sql"]~strip~translate
  isQuery = sqlUpper~startsWith("SELECT ") | sqlUpper~startsWith("WITH ")

  if isQuery then do
    preparedResult = self~backendPreparedQuery(entry, parameters)
    if preparedResult["error"] \= .Error~SUCCESS then do
      self~sendDatabaseError(connection, preparedResult["error"], preparedResult["message"])
      return
    end
    if cursorFlags = 1 then do
      entry["cursorResult"] = preparedResult["result"]
      entry["cursorPosition"] = 1
      self~sendBinaryCursorMetadata(connection, currentDatabase, preparedResult["result"])
    end
    else self~sendBinaryCoreResult(connection, currentDatabase, preparedResult["result"])
  end
  else do
    preparedResult = self~backendPreparedExecute(entry, parameters)
    if preparedResult["error"] \= .Error~SUCCESS then do
      self~sendDatabaseError(connection, preparedResult["error"], preparedResult["message"])
      return
    end
    self~sendOK(connection, 1, preparedResult["affectedRows"], 0)
  end
  entry["longData"] = .table~new

::method handleStmtLongData private unguarded
  use arg connection, commandData
  if commandData~length < 6 then return
  statementId = self~readLE32(commandData, 1)
  parameterIndex = self~readLE16(commandData, 5)
  entry = connection~preparedStatements[statementId]
  if entry == .nil then return
  if parameterIndex >= entry["parameterCount"] then return
  key = parameterIndex + 1
  existing = entry["longData"][key]
  if existing == .nil then existing = ""
  entry["longData"][key] = existing || commandData~substr(7)
  -- COM_STMT_SEND_LONG_DATA intentionally has no response packet.

::method handleStmtClose private unguarded
  use arg connection, commandData
  if commandData~length < 4 then return
  statementId = self~readLE32(commandData, 1)
  connection~preparedStatements~remove(statementId)
  -- COM_STMT_CLOSE intentionally has no response packet.

::method handleStmtReset private unguarded
  use arg connection, commandData
  if commandData~length < 4 then do
    self~sendError(connection, 1, 1043, "08S01", "Malformed COM_STMT_RESET")
    return
  end
  statementId = self~readLE32(commandData, 1)
  entry = connection~preparedStatements[statementId]
  if entry == .nil then do
    self~sendError(connection, 1, 1243, "HY000", "Unknown prepared statement handler (" || statementId || ")")
    return
  end
  entry["longData"] = .table~new
  entry["cursorResult"] = .nil
  entry["cursorPosition"] = 1
  self~sendOK(connection, 1, 0, 0)

::method handleStmtFetch private unguarded
  use arg connection, commandData
  if commandData~length < 8 then do
    self~sendError(connection, 1, 1043, "08S01", "Malformed COM_STMT_FETCH")
    return
  end
  statementId = self~readLE32(commandData, 1)
  requestedRows = self~readLE32(commandData, 5)
  entry = connection~preparedStatements[statementId]
  if entry == .nil then do
    self~sendError(connection, 1, 1243, "HY000", "Unknown prepared statement handler (" || statementId || ")")
    return
  end
  coreResult = entry["cursorResult"]
  if coreResult == .nil then do
    self~sendError(connection, 1, 1325, "24000", "Cursor is not open")
    return
  end

  rows = coreResult~rows
  position = entry["cursorPosition"]
  sequence = 1
  sent = 0
  do while sent < requestedRows
    if position > rows~items then leave
    self~sendPacket(connection, sequence, self~binaryCoreRow(coreResult, rows[position]))
    sequence += 1
    position += 1
    sent += 1
  end
  entry["cursorPosition"] = position

  if position > rows~items then do
    entry["cursorResult"] = .nil
    entry["cursorPosition"] = 1
    status = self~SERVER_STATUS_AUTOCOMMIT + self~SERVER_STATUS_LAST_ROW_SENT
  end
  else status = self~SERVER_STATUS_AUTOCOMMIT + self~SERVER_STATUS_CURSOR_EXISTS
  self~sendEOF(connection, sequence, status)

::method preparedResultMetadata private unguarded
  expose engine
  use arg sqlText
  metadataResult = .table~new
  metadataResult["names"] = .array~new
  metadataResult["types"] = .array~new
  text = sqlText~strip
  upper = text~translate
  if \upper~startsWith("SELECT ") then return metadataResult
  fromPos = upper~pos(" FROM ")
  if fromPos = 0 then return metadataResult
  projection = text~substr(8, fromPos - 8)~strip
  rest = text~substr(fromPos + 6)~strip
  if rest = "" then return metadataResult
  tableName = rest~word(1)
  if tableName~right(1) = ";" then tableName = tableName~left(tableName~length - 1)
  if tableName~left(1) = "`" then do
    if tableName~right(1) = "`" then tableName = tableName~substr(2, tableName~length - 2)
  end
  if \self~catalogHasTable(engine, tableName) then return metadataResult
  tableMetadata = engine~databaseCore~tableMetadata(tableName)

  if projection = "*" then do
    do column over tableMetadata~columns
      metadataResult["names"]~append(column~name)
      metadataResult["types"]~append(column~databaseType)
    end
    return metadataResult
  end

  -- Cover the common direct-column projection used by native prepared clients.
  -- Expressions/aggregates still execute correctly; they simply advertise no
  -- prepare-time result metadata until a wider SQL projection parser is added.
  remaining = projection
  do while remaining \= ""
    comma = remaining~pos(",")
    if comma = 0 then do
      token = remaining~strip
      remaining = ""
    end
    else do
      token = remaining~left(comma - 1)~strip
      remaining = remaining~substr(comma + 1)~strip
    end
    if token~pos(" ") > 0 then return .table~of("names", .array~new, "types", .array~new)
    if token~pos("(") > 0 then return .table~of("names", .array~new, "types", .array~new)
    if token~pos(".") > 0 then token = token~substr(token~lastPos(".") + 1)
    if token~left(1) = "`" then do
      if token~right(1) = "`" then token = token~substr(2, token~length - 2)
    end
    matched = .false
    do column over tableMetadata~columns
      if column~name~translate = token~translate then do
        metadataResult["names"]~append(column~name)
        metadataResult["types"]~append(column~databaseType)
        matched = .true
        leave
      end
    end
    if \matched then return .table~of("names", .array~new, "types", .array~new)
  end
  return metadataResult

::method decodeStmtParameters private unguarded
  use arg entry, commandData, offset, suppliedCount, namesPresent
  decoded = .table~new
  decoded["error"] = ""
  parameters = .array~new
  decoded["parameters"] = parameters
  count = entry["parameterCount"]
  if suppliedCount = 0 then return decoded

  bitmapLength = (suppliedCount + 7) % 8
  if commandData~length < offset + bitmapLength then do
    decoded["error"] = "Malformed prepared parameter NULL bitmap"
    return decoded
  end
  nullBitmap = commandData~substr(offset, bitmapLength)
  offset += bitmapLength
  if offset > commandData~length then do
    decoded["error"] = "Missing prepared parameter bind flag"
    return decoded
  end
  newTypes = c2d(commandData~substr(offset,1))
  offset += 1
  types = entry["parameterTypes"]
  if newTypes \= 0 then do
    types = .array~new
    do i = 1 to suppliedCount
      if offset + 1 > commandData~length then do
        decoded["error"] = "Truncated prepared parameter type vector"
        return decoded
      end
      typeInfo = .table~new
      typeInfo["type"] = c2d(commandData~substr(offset,1))
      typeInfo["unsigned"] = (c2d(commandData~substr(offset + 1,1)) >= 128)
      types~append(typeInfo)
      offset += 2
      if namesPresent then do
        nameInfo = self~readLenEncStringAt(commandData, offset)
        if nameInfo["error"] \= "" then do
          decoded["error"] = nameInfo["error"]
          return decoded
        end
        offset = nameInfo["next"]
      end
    end
    entry["parameterTypes"] = types
  end
  else if types~items \= suppliedCount then do
    decoded["error"] = "Prepared parameter types have not been bound"
    return decoded
  end

  do i = 1 to suppliedCount
    bitmapByte = ((i - 1) % 8) + 1
    bitmapBit = (i - 1) // 8
    byteValue = c2d(nullBitmap~substr(bitmapByte,1))
    isNull = ((byteValue % (2 ** bitmapBit)) // 2) = 1
    if isNull then do
      if i <= count then parameters~append(.DatabaseValue~nullValue)
      iterate
    end

    longValue = entry["longData"][i]
    if longValue \== .nil then do
      if i <= count then parameters~append(.DatabaseValue~blob(longValue))
      iterate
    end

    typeInfo = types[i]
    valueResult = self~decodeBinaryParameter(typeInfo["type"], typeInfo["unsigned"], commandData, offset)
    if valueResult["error"] \= "" then do
      decoded["error"] = valueResult["error"]
      return decoded
    end
    offset = valueResult["next"]
    if i <= count then parameters~append(valueResult["value"])
  end
  return decoded

::method decodeBinaryParameter private unguarded
  use arg typeCode, unsigned, data, offset
  out = .table~new
  out["error"] = ""
  select
    when typeCode = 6 then do
      out["value"] = .DatabaseValue~nullValue
      out["next"] = offset
    end
    when typeCode = 1 then do
      if offset > data~length then return self~parameterDecodeFailure("Truncated TINY parameter")
      n = c2d(data~substr(offset,1))
      if \unsigned then if n >= 128 then n -= 256
      out["value"] = .DatabaseValue~integer(n)
      out["next"] = offset + 1
    end
    when typeCode = 2 then do
      if offset + 1 > data~length then return self~parameterDecodeFailure("Truncated SHORT parameter")
      n = self~readLE16(data, offset)
      if \unsigned then if n >= 32768 then n -= 65536
      out["value"] = .DatabaseValue~integer(n)
      out["next"] = offset + 2
    end
    when typeCode = 3 | typeCode = 9 then do
      if offset + 3 > data~length then return self~parameterDecodeFailure("Truncated LONG parameter")
      n = self~readLE32(data, offset)
      if \unsigned then if n >= 2147483648 then n -= 4294967296
      out["value"] = .DatabaseValue~integer(n)
      out["next"] = offset + 4
    end
    when typeCode = 4 then do
      if offset + 3 > data~length then return self~parameterDecodeFailure("Truncated FLOAT parameter")
      number = self~decodeIEEE754Float(data~substr(offset, 4))
      if number["error"] \= "" then return self~parameterDecodeFailure(number["error"])
      out["value"] = .DatabaseValue~decimal(number["text"])
      out["next"] = offset + 4
    end
    when typeCode = 5 then do
      if offset + 7 > data~length then return self~parameterDecodeFailure("Truncated DOUBLE parameter")
      number = self~decodeIEEE754Double(data~substr(offset, 8))
      if number["error"] \= "" then return self~parameterDecodeFailure(number["error"])
      out["value"] = .DatabaseValue~decimal(number["text"])
      out["next"] = offset + 8
    end
    when typeCode = 8 then do
      if offset + 7 > data~length then return self~parameterDecodeFailure("Truncated LONGLONG parameter")
      n = self~readLE64(data, offset)
      if \unsigned then if n >= 9223372036854775808 then n -= 18446744073709551616
      out["value"] = .DatabaseValue~integer(n)
      out["next"] = offset + 8
    end
    when typeCode = 10 | typeCode = 7 | typeCode = 12 | typeCode = 11 then do
      temporal = self~decodeBinaryTemporal(typeCode, data, offset)
      if temporal["error"] \= "" then return self~parameterDecodeFailure(temporal["error"])
      select
        when typeCode = 10 then out["value"] = .DatabaseValue~date(temporal["text"])
        when typeCode = 7 | typeCode = 12 then out["value"] = .DatabaseValue~datetime(temporal["text"])
        otherwise out["value"] = .DatabaseValue~varchar(temporal["text"])
      end
      out["next"] = temporal["next"]
    end
    when typeCode = 13 then do
      if offset + 1 > data~length then return self~parameterDecodeFailure("Truncated YEAR parameter")
      out["value"] = .DatabaseValue~integer(self~readLE16(data, offset))
      out["next"] = offset + 2
    end
    when typeCode = 15 | typeCode = 246 | typeCode = 249 | typeCode = 250 | typeCode = 251 | typeCode = 252 | typeCode = 253 | typeCode = 254 then do
      stringResult = self~readLenEncStringAt(data, offset)
      if stringResult["error"] \= "" then return stringResult
      if typeCode = 246 then out["value"] = .DatabaseValue~decimal(stringResult["text"])
      else if typeCode >= 249 then do
        if typeCode <= 252 then out["value"] = .DatabaseValue~blob(stringResult["text"])
        else out["value"] = .DatabaseValue~varchar(stringResult["text"])
      end
      else out["value"] = .DatabaseValue~varchar(stringResult["text"])
      out["next"] = stringResult["next"]
    end
    otherwise return self~parameterDecodeFailure("Unsupported prepared parameter type " || typeCode)
  end
  return out

::method decodeIEEE754Float private unguarded
  use arg bytes
  out = .table~new
  out["error"] = ""
  b0 = c2d(bytes~substr(1,1)); b1 = c2d(bytes~substr(2,1)); b2 = c2d(bytes~substr(3,1)); b3 = c2d(bytes~substr(4,1))
  sign = 1
  if b3 >= 128 then sign = -1
  exponent = ((b3 // 128) * 2) + (b2 % 128)
  fraction = (b2 // 128) / 128 + b1 / 32768 + b0 / 8388608
  if exponent = 255 then do
    out["error"] = "NaN/Infinity FLOAT parameters are not supported"
    return out
  end
  if exponent = 0 then number = sign * fraction * (2 ** -126)
  else number = sign * (1 + fraction) * (2 ** (exponent - 127))
  out["text"] = self~canonicalNumericText(number)
  return out

::method decodeIEEE754Double private unguarded
  use arg bytes
  out = .table~new
  out["error"] = ""
  b0 = c2d(bytes~substr(1,1)); b1 = c2d(bytes~substr(2,1)); b2 = c2d(bytes~substr(3,1)); b3 = c2d(bytes~substr(4,1))
  b4 = c2d(bytes~substr(5,1)); b5 = c2d(bytes~substr(6,1)); b6 = c2d(bytes~substr(7,1)); b7 = c2d(bytes~substr(8,1))
  sign = 1
  if b7 >= 128 then sign = -1
  exponent = ((b7 // 128) * 16) + (b6 % 16)
  fraction = (b6 // 16) / 16 + b5 / 4096 + b4 / 1048576 + b3 / 268435456 +,
      b2 / 68719476736 + b1 / 17592186044416 + b0 / 4503599627370496
  if exponent = 2047 then do
    out["error"] = "NaN/Infinity DOUBLE parameters are not supported"
    return out
  end
  if exponent = 0 then number = sign * fraction * (2 ** -1022)
  else number = sign * (1 + fraction) * (2 ** (exponent - 1023))
  out["text"] = self~canonicalNumericText(number)
  return out

::method canonicalNumericText private unguarded
  use arg number
  -- Let ooRexx own decimal rendering, then remove insignificant blanks only.
  -- DatabaseValue~decimal validates the resulting numeric text before binding.
  return number~string~strip

::method decodeBinaryTemporal private unguarded
  use arg typeCode, data, offset
  out = .table~new
  out["error"] = ""
  if offset > data~length then return self~temporalDecodeFailure("Truncated temporal parameter")
  length = c2d(data~substr(offset,1))
  offset += 1
  if offset + length - 1 > data~length then return self~temporalDecodeFailure("Truncated temporal parameter value")

  if typeCode = 10 then do
    if length = 0 then out["text"] = "0000-00-00"
    else if length = 4 then do
      year = self~readLE16(data, offset); month = c2d(data~substr(offset+2,1)); day = c2d(data~substr(offset+3,1))
      out["text"] = self~fourDigits(year) || "-" || self~twoDigits(month) || "-" || self~twoDigits(day)
    end
    else return self~temporalDecodeFailure("Invalid DATE parameter length " || length)
  end
  else if typeCode = 7 | typeCode = 12 then do
    if length = 0 then out["text"] = "0000-00-00 00:00:00"
    else if length = 4 | length = 7 | length = 11 then do
      year = self~readLE16(data, offset); month = c2d(data~substr(offset+2,1)); day = c2d(data~substr(offset+3,1))
      text = self~fourDigits(year) || "-" || self~twoDigits(month) || "-" || self~twoDigits(day)
      if length >= 7 then do
        hour = c2d(data~substr(offset+4,1)); minute = c2d(data~substr(offset+5,1)); second = c2d(data~substr(offset+6,1))
        text ||= " " || self~twoDigits(hour) || ":" || self~twoDigits(minute) || ":" || self~twoDigits(second)
      end
      else text ||= " 00:00:00"
      if length = 11 then text ||= "." || self~sixDigits(self~readLE32(data, offset+7))
      out["text"] = text
    end
    else return self~temporalDecodeFailure("Invalid DATETIME/TIMESTAMP parameter length " || length)
  end
  else if typeCode = 11 then do
    if length = 0 then out["text"] = "00:00:00"
    else if length = 8 | length = 12 then do
      negative = c2d(data~substr(offset,1))
      days = self~readLE32(data, offset+1)
      hour = c2d(data~substr(offset+5,1)); minute = c2d(data~substr(offset+6,1)); second = c2d(data~substr(offset+7,1))
      totalHour = days * 24 + hour
      text = ""
      if negative \= 0 then text = "-"
      if totalHour < 10 then text ||= "0"
      text ||= totalHour || ":" || self~twoDigits(minute) || ":" || self~twoDigits(second)
      if length = 12 then text ||= "." || self~sixDigits(self~readLE32(data, offset+8))
      out["text"] = text
    end
    else return self~temporalDecodeFailure("Invalid TIME parameter length " || length)
  end
  out["next"] = offset + length
  return out

::method temporalDecodeFailure private unguarded
  use arg message
  out = .table~new
  out["error"] = message
  out["next"] = 0
  return out

::method twoDigits private unguarded
  use arg n
  text = n~string
  if text~length < 2 then text = "0" || text
  return text

::method fourDigits private unguarded
  use arg n
  text = n~string
  do while text~length < 4; text = "0" || text; end
  return text

::method sixDigits private unguarded
  use arg n
  text = n~string
  do while text~length < 6; text = "0" || text; end
  return text

::method parameterDecodeFailure private unguarded
  use arg message
  out = .table~new
  out["error"] = message
  out["next"] = 0
  return out

::method readLenEncIntAt private unguarded
  use arg data, offset
  out = .table~new
  out["error"] = ""
  if offset > data~length then return self~parameterDecodeFailure("Truncated length-encoded integer")
  first = c2d(data~substr(offset,1))
  if first < 251 then do; out["value"] = first; out["next"] = offset + 1; return out; end
  if first = 252 then do
    if offset + 2 > data~length then return self~parameterDecodeFailure("Truncated length-encoded integer")
    out["value"] = self~readLE16(data, offset + 1); out["next"] = offset + 3; return out
  end
  if first = 253 then do
    if offset + 3 > data~length then return self~parameterDecodeFailure("Truncated length-encoded integer")
    out["value"] = self~readLE24(data, offset + 1); out["next"] = offset + 4; return out
  end
  if first = 254 then do
    if offset + 8 > data~length then return self~parameterDecodeFailure("Truncated length-encoded integer")
    out["value"] = self~readLE64(data, offset + 1); out["next"] = offset + 9; return out
  end
  return self~parameterDecodeFailure("Invalid length-encoded integer")

::method readLenEncStringAt private unguarded
  use arg data, offset
  out = .table~new
  out["error"] = ""
  if offset > data~length then return self~parameterDecodeFailure("Truncated length-encoded parameter")
  first = c2d(data~substr(offset,1))
  if first < 251 then do; length = first; offset += 1; end
  else if first = 252 then do; if offset + 2 > data~length then return self~parameterDecodeFailure("Truncated length-encoded parameter"); length = self~readLE16(data, offset + 1); offset += 3; end
  else if first = 253 then do; if offset + 3 > data~length then return self~parameterDecodeFailure("Truncated length-encoded parameter"); length = self~readLE24(data, offset + 1); offset += 4; end
  else if first = 254 then do; if offset + 8 > data~length then return self~parameterDecodeFailure("Truncated length-encoded parameter"); length = self~readLE64(data, offset + 1); offset += 9; end
  else return self~parameterDecodeFailure("Invalid length-encoded parameter")
  if offset + length - 1 > data~length then return self~parameterDecodeFailure("Truncated length-encoded parameter value")
  out["text"] = data~substr(offset, length)
  out["next"] = offset + length
  return out

::method backendPreparedQuery private unguarded
  expose engine backendGate
  use arg entry, parameters
  response = .table~new
  response["error"] = .Error~SUCCESS
  response["message"] = ""
  ticket = backendGate~enter
  signal on syntax name backendPreparedQueryFailure
  core = engine~databaseCore

  -- Use NoSQLServer's native parameter binder, then the ordinary query adapter.
  -- For SELECT * and simple direct-column projections, carry the prepare-time
  -- metadata into queryWithSchema so the adapter does not lose wildcard column
  -- names on an empty or parameter-filtered result.
  ps = .NoSQLDatabaseCorePreparedStatement~new("mysql_stmt_" || entry["id"], entry["sql"])
  boundSql = .DatabaseParameterBinder~bind(ps, parameters)
  if boundSql~isA(.DatabaseResult) then do
    response["error"] = boundSql~error
    response["message"] = boundSql~message
  end
  else do
    metadata = entry["metadata"]
    if metadata["names"]~items > 0 then do
      schema = core~resultSchema
      do i = 1 to metadata["names"]~items
        schema~add(metadata["names"][i], metadata["types"][i])
      end
      response["result"] = core~queryWithSchema(boundSql, schema)
    end
    else response["result"] = core~query(boundSql)
    if response["result"]~success = .false then do
      response["error"] = response["result"]~error
      response["message"] = response["result"]~message
    end
  end
  backendGate~leave(ticket)
  signal off syntax
  return response
backendPreparedQueryFailure:
  backendGate~leave(ticket)
  signal off syntax
  raise propagate

::method backendPreparedExecute private unguarded
  expose engine backendGate
  use arg entry, parameters
  response = .table~new
  response["error"] = .Error~SUCCESS
  response["message"] = ""
  response["affectedRows"] = 0
  ticket = backendGate~enter
  signal on syntax name backendPreparedExecuteFailure
  core = engine~databaseCore
  tx = core~transaction
  ps = tx~prepareStatement("mysql_stmt_" || entry["id"], entry["sql"])
  queued = tx~executePrepared(ps, parameters)
  if queued~error \= .Error~SUCCESS then do
    response["error"] = queued~error
    response["message"] = queued~message
  end
  else do
    commitResult = tx~commit
    if commitResult~error \= .Error~SUCCESS then do
      response["error"] = commitResult~error
      response["message"] = commitResult~message
    end
    else do
      do mutationResult over commitResult~mutationResults
        response["affectedRows"] += mutationResult~affectedRows
      end
    end
  end
  backendGate~leave(ticket)
  signal off syntax
  return response
backendPreparedExecuteFailure:
  backendGate~leave(ticket)
  signal off syntax
  raise propagate

::method sendBinaryCoreResult private unguarded
  use arg connection, currentDatabase, coreResult
  sequence = self~sendBinaryCoreMetadata(connection, currentDatabase, coreResult, self~SERVER_STATUS_AUTOCOMMIT)
  if sequence = 0 then return
  do dbRow over coreResult~rows
    self~sendPacket(connection, sequence, self~binaryCoreRow(coreResult, dbRow))
    sequence += 1
  end
  self~sendEOF(connection, sequence, self~SERVER_STATUS_AUTOCOMMIT)

::method sendBinaryCursorMetadata private unguarded
  use arg connection, currentDatabase, coreResult
  cursorStatus = self~SERVER_STATUS_AUTOCOMMIT + self~SERVER_STATUS_CURSOR_EXISTS
  callResult = self~sendBinaryCoreMetadata(connection, currentDatabase, coreResult, cursorStatus)

::method sendBinaryCoreMetadata private unguarded
  use arg connection, currentDatabase, coreResult, status
  names = coreResult~columns
  types = coreResult~columnTypes
  if names~items = 0 then do
    self~sendError(connection, 1, 1105, "HY000", "msqlshim cannot encode a prepared SELECT result with zero columns")
    return 0
  end
  self~sendPacket(connection, 1, self~resultsetHeader(connection, names~items))
  sequence = 2
  do i = 1 to names~items
    columnType = .DatabaseType~UNKNOWN
    if i <= types~items then columnType = types[i]
    self~sendPacket(connection, sequence, self~columnDefinition(currentDatabase, names[i], columnType))
    sequence += 1
  end
  if \self~hasCapability(connection~clientCapabilities, self~CLIENT_DEPRECATE_EOF) then do
    self~sendEOF(connection, sequence, status)
    sequence += 1
  end
  return sequence

::method binaryCoreRow private unguarded
  use arg coreResult, dbRow
  names = coreResult~columns
  types = coreResult~columnTypes
  nullBytes = copies("00"x, (names~items + 9) % 8)
  values = ""
  do i = 1 to names~items
    value = dbRow~valueAt(names[i])
    if value == .nil then nullBytes = self~setNullBitmapBit(nullBytes, i - 1, 2)
    else do
      columnType = .DatabaseType~UNKNOWN
      if i <= types~items then columnType = types[i]
      values ||= self~binaryResultValue(value, columnType)
    end
  end
  return "00"x || nullBytes || values

::method setNullBitmapBit private unguarded
  use arg bitmap, fieldIndex, bitOffset
  bitIndex = fieldIndex + bitOffset
  byteIndex = (bitIndex % 8) + 1
  bitPos = bitIndex // 8
  old = c2d(bitmap~substr(byteIndex,1))
  new = old + (2 ** bitPos)
  return bitmap~left(byteIndex - 1) || d2c(new) || bitmap~substr(byteIndex + 1)

::method binaryResultValue private unguarded
  use arg value, databaseType
  typeName = databaseType~string~translate
  select
    when typeName = .DatabaseType~BOOLEAN then return d2c(value~string = "TRUE")
    when typeName = .DatabaseType~INTEGER then do
      n = value
      if n < 0 then n += 4294967296
      return self~le32(n)
    end
    when typeName = .DatabaseType~DATE then return self~binaryDate(value, .false)
    when typeName = .DatabaseType~DATETIME then return self~binaryDate(value, .true)
    otherwise return self~lenEncString(value~string)
  end

::method binaryDate private unguarded
  use arg value, withTime
  text = value~string~strip
  if text = "" then return "00"x
  datePart = text~word(1)
  parse var datePart year "-" month "-" day
  if \datatype(year, "W") | \datatype(month, "W") | \datatype(day, "W") then return "00"x
  if \withTime | text~words < 2 then return "04"x || self~le16(year) || d2c(month) || d2c(day)
  timePart = text~word(2)
  parse var timePart hour ":" minute ":" second
  if \datatype(hour, "W") | \datatype(minute, "W") | \datatype(second, "W") then return "04"x || self~le16(year) || d2c(month) || d2c(day)
  return "07"x || self~le16(year) || d2c(month) || d2c(day) || d2c(hour) || d2c(minute) || d2c(second)

::method statisticsText private unguarded
  return "Uptime: 0  Threads: 1  Questions: 0  Slow queries: 0  Opens: 0  Flush tables: 0  Open tables: 0  Queries per second avg: 0.000"

::method wildcardResultSchema private unguarded
  use arg core, sqlText
  text = sqlText~string~strip
  upper = text~translate
  if \upper~startsWith("SELECT * FROM ") then return .nil

  rest = text~substr(15)~strip
  if rest = "" then return .nil
  tableName = rest~word(1)
  if tableName~right(1) = ";" then tableName = tableName~left(tableName~length - 1)
  if tableName~left(1) = "`" & tableName~right(1) = "`" then do
    tableName = tableName~substr(2, tableName~length - 2)
  end
  if tableName = "" then return .nil

  metadata = core~tableMetadata(tableName)
  if metadata == .nil then return .nil
  if metadata~columns~items = 0 then return .nil
  schema = core~resultSchema
  do column over metadata~columns
    schema~add(column~name, column~databaseType)
  end
  return schema

::method sendCoreResult private unguarded
  use arg socket, currentDatabase, coreResult
  names = coreResult~columns
  types = coreResult~columnTypes
  -- 0x00 is an OK-packet marker in protocol 4.1.  Sending a zero-column
  -- result header therefore becomes a one-byte malformed OK packet to real
  -- clients.  Fail explicitly instead of emitting an invalid resultset.
  if names~items = 0 then do
    self~sendError(socket, 1, 1105, "HY000", "msqlshim cannot encode a SELECT result with zero columns")
    return
  end
  self~sendPacket(socket, 1, self~resultsetHeader(socket, names~items))
  sequence = 2
  do i = 1 to names~items
    columnType = .DatabaseType~UNKNOWN
    if i <= types~items then columnType = types[i]
    self~sendPacket(socket, sequence, self~columnDefinition(currentDatabase, names[i], columnType))
    sequence += 1
  end
  if \self~hasCapability(socket~clientCapabilities, self~CLIENT_DEPRECATE_EOF) then do
    self~sendEOF(socket, sequence)
    sequence += 1
  end
  do dbRow over coreResult~rows
    payload = ""
    do i = 1 to names~items
      value = dbRow~valueAt(names[i])
      payload ||= self~textField(value)
    end
    self~sendPacket(socket, sequence, payload)
    sequence += 1
  end
  self~sendEOF(socket, sequence)

::method sendSyntheticResult private unguarded
  use arg socket, currentDatabase, names, types, rows
  self~sendPacket(socket, 1, self~resultsetHeader(socket, names~items))
  sequence = 2
  do i = 1 to names~items
    self~sendPacket(socket, sequence, self~columnDefinition(currentDatabase, names[i], types[i]))
    sequence += 1
  end
  if \self~hasCapability(socket~clientCapabilities, self~CLIENT_DEPRECATE_EOF) then do
    self~sendEOF(socket, sequence)
    sequence += 1
  end
  do row over rows
    payload = ""
    do value over row
      payload ||= self~textField(value)
    end
    self~sendPacket(socket, sequence, payload)
    sequence += 1
  end
  self~sendEOF(socket, sequence)

::method columnDefinition private unguarded
  use arg currentDatabase, name, databaseType
  catalog = self~lenEncString("def")
  schema = self~lenEncString(currentDatabase)
  tableName = self~lenEncString("")
  originalTable = self~lenEncString("")
  columnName = self~lenEncString(name)
  originalName = self~lenEncString("")
  fixedLength = "0C"x
  charset = self~le16(45)
  columnLength = self~le32(1024)
  mysqlType = self~mysqlColumnType(databaseType)
  flags = self~le16(0)
  decimals = d2c(0)
  filler = "0000"x
  return catalog || schema || tableName || originalTable || columnName || originalName ||,
      fixedLength || charset || columnLength || d2c(mysqlType) || flags || decimals || filler

::method mysqlColumnType private unguarded
  use arg databaseType
  typeName = databaseType~string~translate
  select
    when typeName = .DatabaseType~BOOLEAN then return 1       -- MYSQL_TYPE_TINY
    when typeName = .DatabaseType~INTEGER then return 3       -- MYSQL_TYPE_LONG
    when typeName = .DatabaseType~DECIMAL then return 246     -- MYSQL_TYPE_NEWDECIMAL
    when typeName = .DatabaseType~DATE then return 10         -- MYSQL_TYPE_DATE
    when typeName = .DatabaseType~DATETIME then return 12     -- MYSQL_TYPE_DATETIME
    when typeName = .DatabaseType~BLOB then return 252        -- MYSQL_TYPE_BLOB
    otherwise return 253                                      -- MYSQL_TYPE_VAR_STRING
  end

::method textField private unguarded
  use arg value
  if value == .nil then return "FB"x
  return self~lenEncString(value~string)

::method sendOK private unguarded
  use arg socket, sequence, affectedRows = 0, lastInsertId = 0
  payload = "00"x || self~lenEncInt(affectedRows) || self~lenEncInt(lastInsertId) ||,
      self~le16(self~SERVER_STATUS_AUTOCOMMIT) || self~le16(0)
  self~sendPacket(socket, sequence, payload)

::method sendEOF private unguarded
  use arg socket, sequence, status = (self~SERVER_STATUS_AUTOCOMMIT)
  if self~hasCapability(socket~clientCapabilities, self~CLIENT_DEPRECATE_EOF) then do
    -- EOF-deprecated clients expect an OK packet with 0xFE header as the
    -- resultset terminator.  affected_rows=0, last_insert_id=0.
    payload = "FE"x || self~lenEncInt(0) || self~lenEncInt(0) || self~le16(status) || self~le16(0)
  end
  else payload = "FE"x || self~le16(0) || self~le16(status)
  self~sendPacket(socket, sequence, payload)

::method sendDatabaseError private unguarded
  use arg socket, databaseError, message
  code = 1105
  state = "HY000"
  errorName = databaseError~string~translate
  if errorName = .Error~SQLPARSEERROR then do
    code = 1064
    state = "42000"
  end
  if errorName = .Error~SQLUNSUPPORTED then do
    code = 1235
    state = "42000"
  end
  if message == "" then message = "NoSQLServer database error: " || databaseError
  self~sendError(socket, 1, code, state, message)

::method sendError private unguarded
  use arg socket, sequence, errorCode, sqlState, message
  payload = "FF"x || self~le16(errorCode) || "#" || sqlState~left(5) || message~string
  self~sendPacket(socket, sequence, payload)

::method sendPacket private unguarded
  use arg connection, sequence, payload
  maxPayload = 16777215
  seq = sequence // 256
  payloadLength = payload~length
  offset = 1

  if payloadLength = 0 then do
    self~sendBasicPacket(connection, seq, "")
    return
  end

  do while offset <= payloadLength
    chunkLength = payloadLength - offset + 1
    if chunkLength > maxPayload then chunkLength = maxPayload
    chunk = payload~substr(offset, chunkLength)
    self~sendBasicPacket(connection, seq, chunk)
    seq = (seq + 1) // 256
    offset += chunkLength
  end

  -- A payload which is an exact multiple of 0xFFFFFF is terminated by an
  -- additional zero-length MySQL packet.
  if payloadLength >= maxPayload then do
    if payloadLength // maxPayload = 0 then self~sendBasicPacket(connection, seq, "")
  end

::method sendBasicPacket private unguarded
  use arg connection, sequence, payload
  packetBytes = self~le24(payload~length) || d2c(sequence // 256) || payload
  if connection~compressionEnabled then do
    if sequence = 1 then connection~compressedWriteSequence = 1
    self~sendCompressedBytes(connection, packetBytes)
  end
  else self~sendSocketBytes(connection~socket, packetBytes)

::method sendCompressedBytes private unguarded
  use arg connection, rawBytes
  maxFrame = 16777215
  offset = 1
  do while offset <= rawBytes~length
    chunkLength = rawBytes~length - offset + 1
    if chunkLength > maxFrame then chunkLength = maxFrame
    plainChunk = rawBytes~substr(offset, chunkLength)
    compressed = .MySQLDeflate~compressZlib(plainChunk)
    if plainChunk~length >= 50 then do
      if compressed~length < plainChunk~length then do
        framePayload = compressed
        uncompressedLength = plainChunk~length
      end
      else do
        framePayload = plainChunk
        uncompressedLength = 0
      end
    end
    else do
      framePayload = plainChunk
      uncompressedLength = 0
    end
    frame = self~le24(framePayload~length) || d2c(connection~compressedWriteSequence // 256) ||,
        self~le24(uncompressedLength) || framePayload
    self~sendSocketBytes(connection~socket, frame)
    connection~compressedWriteSequence = (connection~compressedWriteSequence + 1) // 256
    offset += chunkLength
  end

::method sendSocketBytes private unguarded
  use arg socket, bytes
  offset = 1
  do while offset <= bytes~length
    sent = socket~send(bytes~substr(offset))
    if sent == .nil then raise syntax 93.900 additional("Socket send failed")
    if sent <= 0 then raise syntax 93.900 additional("Socket send failed")
    offset += sent
  end

::method readPacket private unguarded
  use arg connection
  if connection~compressionEnabled then return self~readCompressedPacket(connection)
  return self~readBasicPacket(connection)

::method readBasicPacket private unguarded
  use arg connection
  header = self~recvExact(connection~socket, 4)
  if header == .nil then return .nil
  payloadLength = self~readLE24(header, 1)
  sequence = c2d(header~substr(4, 1))
  payload = self~recvExact(connection~socket, payloadLength)
  if payload == .nil then return .nil
  packet = .table~new
  packet["sequence"] = sequence
  packet["payload"] = payload
  return packet

::method readCompressedPacket private unguarded
  use arg connection
  do forever
    buffered = connection~compressedReadBuffer
    if buffered~length >= 4 then do
      payloadLength = self~readLE24(buffered, 1)
      if buffered~length >= payloadLength + 4 then do
        header = buffered~substr(1,4)
        sequence = c2d(header~substr(4,1))
        payload = buffered~substr(5, payloadLength)
        connection~compressedReadBuffer = buffered~substr(payloadLength + 5)
        packet = .table~new
        packet["sequence"] = sequence
        packet["payload"] = payload
        return packet
      end
    end

    compressedHeader = self~recvExact(connection~socket, 7)
    if compressedHeader == .nil then return .nil
    compressedLength = self~readLE24(compressedHeader, 1)
    uncompressedLength = self~readLE24(compressedHeader, 5)
    framePayload = self~recvExact(connection~socket, compressedLength)
    if framePayload == .nil then return .nil
    if uncompressedLength = 0 then plainBytes = framePayload
    else do
      plainBytes = .MySQLDeflate~decompressZlib(framePayload)
      if plainBytes~length \= uncompressedLength then raise syntax 93.900 additional("Compressed MySQL frame length mismatch")
    end
    connection~compressedReadBuffer ||= plainBytes
  end

::method recvExact private unguarded
  use arg socket, wanted
  if wanted = 0 then return ""
  data = ""
  do while data~length < wanted
    part = socket~recv(wanted - data~length)
    if part == .nil then return .nil
    if part == "" then return .nil
    data ||= part
  end
  return data

::method hasCapability private unguarded
  use arg capabilities, mask
  return (capabilities // (mask * 2)) >= mask

::method serverCapabilities private unguarded
  return self~CLIENT_LONG_PASSWORD + self~CLIENT_LONG_FLAG + self~CLIENT_COMPRESS + self~CLIENT_CONNECT_WITH_DB +,
      self~CLIENT_PROTOCOL_41 + self~CLIENT_TRANSACTIONS + self~CLIENT_SECURE_CONNECTION +,
      self~CLIENT_MULTI_RESULTS + self~CLIENT_PLUGIN_AUTH + self~CLIENT_CONNECT_ATTRS + self~CLIENT_DEPRECATE_EOF +,
      self~CLIENT_OPTIONAL_RESULTSET_METADATA + self~CLIENT_QUERY_ATTRIBUTES

::method resultsetHeader private unguarded
  use arg connection, columnCount
  if self~hasCapability(connection~clientCapabilities, self~CLIENT_OPTIONAL_RESULTSET_METADATA) then do
    -- RESULTSET_METADATA_FULL = 1.  v0.14 advertises optional-metadata
    -- capability but deliberately continues to send full metadata.
    return "01"x || self~lenEncInt(columnCount)
  end
  return self~lenEncInt(columnCount)

::method lenEncString private unguarded
  use arg text
  stringValue = text~string
  return self~lenEncInt(stringValue~length) || stringValue

::method lenEncInt private unguarded
  use arg number
  if number < 251 then return d2c(number)
  if number < 65536 then return "FC"x || self~le16(number)
  if number < 16777216 then return "FD"x || self~le24(number)
  return "FE"x || self~le64(number)

::method le16 private unguarded
  use arg number
  return d2c(number // 256) || d2c((number % 256) // 256)

::method le24 private unguarded
  use arg number
  b0 = number // 256
  q = number % 256
  b1 = q // 256
  b2 = (q % 256) // 256
  return d2c(b0) || d2c(b1) || d2c(b2)

::method le32 private unguarded
  use arg number
  out = ""
  work = number
  do 4
    out ||= d2c(work // 256)
    work = work % 256
  end
  return out

::method le64 private unguarded
  use arg number
  out = ""
  work = number
  do 8
    out ||= d2c(work // 256)
    work = work % 256
  end
  return out

::method readLE16 private unguarded
  use arg data, offset
  return c2d(data~substr(offset,1)) + c2d(data~substr(offset + 1,1)) * 256

::method readLE64 private unguarded
  use arg data, offset
  value = 0
  factor = 1
  do i = 0 to 7
    value += c2d(data~substr(offset + i,1)) * factor
    factor *= 256
  end
  return value

::method readLE24 private unguarded
  use arg data, offset
  b0 = c2d(data~substr(offset, 1))
  b1 = c2d(data~substr(offset + 1, 1))
  b2 = c2d(data~substr(offset + 2, 1))
  return b0 + b1 * 256 + b2 * 65536

::method readLE32 private unguarded
  use arg data, offset
  b0 = c2d(data~substr(offset, 1))
  b1 = c2d(data~substr(offset + 1, 1))
  b2 = c2d(data~substr(offset + 2, 1))
  b3 = c2d(data~substr(offset + 3, 1))
  return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216


::class MySQLSessionRegistry subclass MySQLShimAlchemyObject public

::method init
  expose sessions nextId totalConnections
  use arg alchemySealer = .nil, alchemyAuthority = .nil
  self~init:super("SESSION_REGISTRY", "bounded active MySQL connection catalogue", alchemySealer, alchemyAuthority)
  self~registerMethodContract("ALLOCATEID", "allocate server connection id", .array~new, "NUMERIC", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("ROWS", "snapshot active process-list rows", .array~new, "ARRAY", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "NONE")
  sessions = .table~new
  nextId = 1000
  totalConnections = 0

::method allocateId
  expose nextId
  self~alchemyTouch("ALLOCATE_ID")
  id = nextId
  nextId += 1
  return id

::method register
  expose sessions totalConnections
  use strict arg id, user, database
  self~alchemyTouch("REGISTER_SESSION")
  d = .directory~new
  d["id"] = id
  d["user"] = user
  d["host"] = "client"
  d["db"] = database
  d["command"] = "Sleep"
  d["state"] = ""
  d["started"] = time("S")
  sessions[id] = d
  totalConnections += 1
  return .true

::method updateDatabase
  expose sessions
  use strict arg id, database
  if sessions~hasIndex(id) then sessions[id]["db"] = database
  return .true

::method updateState
  expose sessions
  use strict arg id, command, state
  if sessions~hasIndex(id) then do
    sessions[id]["command"] = command
    sessions[id]["state"] = state
    sessions[id]["started"] = time("S")
  end
  return .true

::method remove
  expose sessions
  use strict arg id
  if sessions~hasIndex(id) then sessions~remove(id)
  return .true

::method count
  expose sessions
  return sessions~items

::method totalConnections
  expose totalConnections
  return totalConnections

::method rows
  expose sessions
  self~alchemyTouch("ROWS")
  rows = .array~new
  now = time("S")
  do id over sessions~allIndexes
    d = sessions[id]
    elapsed = now - d["started"]
    if elapsed < 0 then elapsed += 86400
    rows~append(.array~of(d["id"], d["user"], d["host"], d["db"], d["command"], elapsed, d["state"], ""))
  end
  return rows

::class MySQLBackendGate subclass MySQLShimAlchemyObject public

::method init
  expose nextTicket serving
  use arg alchemySealer = .nil, alchemyAuthority = .nil
  self~init:super("BACKEND_GATE", "FIFO scheduler for serialized NoSQLServer execution", alchemySealer, alchemyAuthority)
  self~registerMethodContract("ENTER", "acquire next FIFO backend ticket", .array~new, "NUMERIC", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("LEAVE", "release current FIFO backend ticket", .array~of("TICKET"), "BOOLEAN", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  nextTicket = 1
  serving = 1

::method enter
  expose nextTicket serving
  self~alchemyTouch("ENTER")
  ticket = nextTicket
  nextTicket += 1
  -- Do not retain the gate while waiting for an earlier backend operation.
  guard off
  guard on when serving = ticket
  guard off
  return ticket

::method leave
  expose serving
  use arg ticket
  self~alchemyTouch("LEAVE")
  if ticket = serving then serving += 1
  return .true

::class MySQLWireConnection subclass MySQLShimAlchemyObject public
::attribute socket
::attribute clientCapabilities
::attribute compressionEnabled
::attribute compressedReadBuffer
::attribute compressedWriteSequence
::attribute multiStatements
::attribute clientUser
::attribute requestedDatabase
::attribute authPlugin
::attribute connectionAttributes
::attribute clientMaxPacket
::attribute clientCharacterSet
::attribute connectionId

::method init
  use arg socket, alchemySealer = .nil, alchemyAuthority = .nil
  self~init:super("WIRE_CONNECTION", "connection-local MySQL protocol/session state", alchemySealer, alchemyAuthority)
  self~registerMethodContract("ALLOCATESTATEMENTID", "allocate connection-local prepared statement id", .array~new, "NUMERIC", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("RESETSESSION", "clear connection-local prepared/session state", .array~new, "ANY", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~socket = socket
  if socket \== .nil then self~recordRelationship("OWNS_SESSION_SOCKET", socket, "connection transport endpoint", "SECRET")
  self~clientCapabilities = 0
  self~compressionEnabled = .false
  self~compressedReadBuffer = ""
  self~compressedWriteSequence = 0
  self~multiStatements = .false
  self~clientUser = ""
  self~requestedDatabase = ""
  self~authPlugin = ""
  self~connectionAttributes = .directory~new
  self~clientMaxPacket = 0
  self~clientCharacterSet = 0
  self~connectionId = 0
  self~preparedStatements = .table~new
  self~nextStatementId = 1

::attribute preparedStatements
::attribute nextStatementId

::method allocateStatementId
  self~alchemyTouch("ALLOCATE_STATEMENT_ID")
  id = self~nextStatementId
  self~nextStatementId = id + 1
  return id

::method resetSession
  self~alchemyTouch("RESET_SESSION")
  self~compressedReadBuffer = ""
  self~multiStatements = .false
  self~clientUser = ""
  self~requestedDatabase = ""
  self~authPlugin = ""
  self~connectionAttributes = .directory~new
  self~clientMaxPacket = 0
  self~clientCharacterSet = 0
  self~connectionId = 0
  self~preparedStatements = .table~new
  self~nextStatementId = 1
