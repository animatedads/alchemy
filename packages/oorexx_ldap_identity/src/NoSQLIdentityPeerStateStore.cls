/* NoSQLIdentityPeerStateStore.cls - durable peer delivery state. */
::class NoSQLIdentityPeerStateStoreBuild public
::constant API_VERSION "identity.peer.outbox.nosql/0.1"
::constant REQUEST_TABLE "identity_peer_outbox"
::constant ACK_TABLE "identity_peer_ack"
::constant META_TABLE "identity_peer_outbox_meta"
::constant SCHEMA_VERSION "1"

::class NoSQLIdentityPeerStateStore subclass IdentityPeerOutbox public
::method init
  expose root engine
  use strict arg rootArg
  root=rootArg~string
  if root="" then raise syntax 88.900 array("NoSQL identity peer outbox root required")
  engine=.FileDatabaseEngine~new(root)
  ready=self~ensureSchema
  if \ready~ok then raise syntax 88.900 array("NoSQL identity peer outbox schema failure:" ready~code ready~detail)
::attribute root get
::method resultOk private
  use strict arg dbResult
  return dbResult~status=.Error~SUCCESS
::method ensureSchema private
  expose engine
  meta=.NoSQLIdentityPeerStateStoreBuild~META_TABLE
  if engine~table(meta)==.nil then do
    cols=.array~new
    cols~append(.DatabaseColumn~new("meta_key","VARCHAR",.false,.true,.true))
    cols~append(.DatabaseColumn~new("meta_value","TEXT",.false))
    rs=engine~createTable(meta,cols,.array~of("meta_key"))
    if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_SCHEMA_FAILED",rs~message)
  end
  req=.NoSQLIdentityPeerStateStoreBuild~REQUEST_TABLE
  if engine~table(req)==.nil then do
    cols=.array~new
    cols~append(.DatabaseColumn~new("request_id","VARCHAR",.false,.true,.true))
    cols~append(.DatabaseColumn~new("request_identity","VARCHAR",.false))
    cols~append(.DatabaseColumn~new("origin_peer_id","VARCHAR",.false))
    cols~append(.DatabaseColumn~new("origin_epoch","INTEGER",.false))
    cols~append(.DatabaseColumn~new("origin_sequence","INTEGER",.false))
    cols~append(.DatabaseColumn~new("commit_policy","VARCHAR",.false))
    cols~append(.DatabaseColumn~new("created_at","DATETIME",.false))
    cols~append(.DatabaseColumn~new("payload","TEXT",.false))
    rs=engine~createTable(req,cols,.array~of("request_id"))
    if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_SCHEMA_FAILED",rs~message)
  end
  ack=.NoSQLIdentityPeerStateStoreBuild~ACK_TABLE
  if engine~table(ack)==.nil then do
    cols=.array~new
    cols~append(.DatabaseColumn~new("ack_key","VARCHAR",.false,.true,.true))
    cols~append(.DatabaseColumn~new("request_id","VARCHAR",.false))
    cols~append(.DatabaseColumn~new("peer_id","VARCHAR",.false))
    cols~append(.DatabaseColumn~new("status","VARCHAR",.false))
    cols~append(.DatabaseColumn~new("detail","TEXT",.false))
    cols~append(.DatabaseColumn~new("durable_revision","INTEGER",.false))
    cols~append(.DatabaseColumn~new("acked_at","DATETIME",.false))
    rs=engine~createTable(ack,cols,.array~of("ack_key"))
    if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_SCHEMA_FAILED",rs~message)
  end
  version=self~metaValue("schema_version")
  if version==.nil then return self~putMeta("schema_version",.NoSQLIdentityPeerStateStoreBuild~SCHEMA_VERSION)
  if version<>.NoSQLIdentityPeerStateStoreBuild~SCHEMA_VERSION then return .DirectoryResult~failure("PEER_OUTBOX_SCHEMA_VERSION_UNSUPPORTED",version)
  return .DirectoryResult~success(.true,"SCHEMA_READY")
::method metaValue private
  expose engine
  use strict arg key
  rs=engine~selectWhereEquals(.NoSQLIdentityPeerStateStoreBuild~META_TABLE,"meta_key",key)
  if \self~resultOk(rs) | rs~rows~items=0 then return .nil
  return rs~rows[1]["meta_value"]~string
::method putMeta private
  expose engine
  use strict arg key,value
  values=.table~new; values["meta_key"]=key~string; values["meta_value"]=value~string
  rs=engine~insert(.NoSQLIdentityPeerStateStoreBuild~META_TABLE,values)
  if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_META_WRITE_FAILED",rs~message)
  return .DirectoryResult~success(.true,"META_STORED")
::method recordRequest
  expose engine
  use strict arg request
  table=.NoSQLIdentityPeerStateStoreBuild~REQUEST_TABLE
  existing=engine~selectWhereEquals(table,"request_id",request~requestId)
  if \self~resultOk(existing) then return .DirectoryResult~failure("PEER_OUTBOX_READ_FAILED",existing~message)
  if existing~rows~items>0 then do
    row=existing~rows[1]
    if row["request_identity"]~string=request~semanticIdentity then return .DirectoryResult~success(.false,"REQUEST_ALREADY_STORED")
    return .DirectoryResult~failure("PEER_REQUEST_DIVERGED",request~requestId)
  end
  values=.table~new
  values["request_id"]=request~requestId; values["request_identity"]=request~semanticIdentity
  values["origin_peer_id"]=request~originPeerId; values["origin_epoch"]=request~originEpoch
  values["origin_sequence"]=request~change~originSequence; values["commit_policy"]=request~commitPolicy
  values["created_at"]=.DirectoryCanonical~dateTimeText(request~createdAt); values["payload"]=.IdentityPeerUpdateCodec~toJson(request)
  rs=engine~insert(table,values)
  if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_APPEND_FAILED",rs~message)
  return .DirectoryResult~success(.true,"REQUEST_STORED")
::method recordAck
  expose engine
  use strict arg ack
  table=.NoSQLIdentityPeerStateStoreBuild~ACK_TABLE; key=ack~requestId||"|"||ack~peerId
  existing=engine~selectWhereEquals(table,"ack_key",key)
  if \self~resultOk(existing) then return .DirectoryResult~failure("PEER_OUTBOX_READ_FAILED",existing~message)
  values=.table~new
  values["request_id"]=ack~requestId; values["peer_id"]=ack~peerId; values["status"]=ack~status
  values["detail"]=ack~detail; values["durable_revision"]=ack~durableRevision; values["acked_at"]=.DirectoryCanonical~dateTimeText(ack~ackedAt)
  if existing~rows~items=0 then do; values["ack_key"]=key; rs=engine~insert(table,values); end
  else rs=engine~updateWhereEquals(table,"ack_key",key,values)
  if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_ACK_WRITE_FAILED",rs~message)
  return .DirectoryResult~success(.true,"ACK_STORED")
::method loadRequests
  expose engine
  rs=engine~selectAll(.NoSQLIdentityPeerStateStoreBuild~REQUEST_TABLE)
  if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_READ_FAILED",rs~message)
  out=.array~new
  do row over rs~rows
    signal on syntax name corruptRequest
    request=.IdentityPeerUpdateCodec~fromJson(row["payload"]~string)
    signal off syntax
    if request~requestId<>row["request_id"]~string then return .DirectoryResult~failure("PEER_OUTBOX_CORRUPT_REQUEST_ID",row["request_id"])
    if request~semanticIdentity<>row["request_identity"]~string then return .DirectoryResult~failure("PEER_OUTBOX_CORRUPT_IDENTITY",row["request_id"])
    if request~originPeerId<>row["origin_peer_id"]~string then return .DirectoryResult~failure("PEER_OUTBOX_CORRUPT_ORIGIN",row["request_id"])
    if request~originEpoch<>row["origin_epoch"] then return .DirectoryResult~failure("PEER_OUTBOX_CORRUPT_EPOCH",row["request_id"])
    if request~change~originSequence<>row["origin_sequence"] then return .DirectoryResult~failure("PEER_OUTBOX_CORRUPT_SEQUENCE",row["request_id"])
    out~append(request)
  end
  return .DirectoryResult~success(out,"REQUESTS_LOADED")
corruptRequest:
  signal off syntax
  return .DirectoryResult~failure("PEER_OUTBOX_CORRUPT_PAYLOAD")
::method loadAcks
  expose engine
  use strict arg requestId
  rs=engine~selectWhereEquals(.NoSQLIdentityPeerStateStoreBuild~ACK_TABLE,"request_id",requestId~string)
  if \self~resultOk(rs) then return .DirectoryResult~failure("PEER_OUTBOX_READ_FAILED",rs~message)
  out=.array~new
  do row over rs~rows
    dt=.DirectoryEntityCodec~requiredDateTimeFromText("ack.ackedAt",row["acked_at"])
    out~append(.IdentityPeerAck~new(row["request_id"]~string,row["peer_id"]~string,row["status"]~string,row["detail"]~string,row["durable_revision"],dt))
  end
  return .DirectoryResult~success(out,"ACKS_LOADED")
::method capabilities
  d=self~capabilities:super; d["durable"]=.true; d["provider"]="NOSQLSERVER_FILE"; d["semanticCommitSeparateFromDeliveryState"]=.true; return d
::requires "src/IdentityPeerFabric.cls"
::requires "NoSQLServer.cls"
