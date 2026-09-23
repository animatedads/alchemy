/* NoSQLDirectoryStore.cls
 * ooRexx Identity Directory v0.1-dev9
 *
 * Durable DirectoryStore provider backed by NoSQLServer's native FILE engine.
 * NoSQLServer owns physical persistence, journaling and CsvStream-backed table
 * storage. The Identity Directory owns identity semantics.
 */

::class NoSQLDirectoryStoreBuild public
::constant API_VERSION "identity.directory.store.nosql/0.1"
::constant CHANGE_TABLE "identity_change_log"
::constant META_TABLE "identity_directory_meta"
::constant SCHEMA_VERSION "1"

::class NoSQLDirectoryStore subclass DirectoryStore public
::attribute root get
::method init
  expose root engine ready
  use strict arg rootArg
  root = rootArg~string
  if root = "" then raise syntax 88.900 array("NoSQL directory store root required")
  engine = .FileDatabaseEngine~new(root)
  ready = self~ensureSchema
  if \ready~ok then raise syntax 88.900 array("NoSQL directory store schema failure:" ready~code ready~detail)

::method resultOk private
  use strict arg dbResult
  return dbResult~status = .Error~SUCCESS

::method ensureSchema private
  expose engine
  metaName = .NoSQLDirectoryStoreBuild~META_TABLE
  if engine~table(metaName) == .nil then do
    cols = .array~new
    cols~append(.DatabaseColumn~new("meta_key", "VARCHAR", .false, .true, .true))
    cols~append(.DatabaseColumn~new("meta_value", "TEXT", .false))
    pk = .array~of("meta_key")
    rs = engine~createTable(metaName, cols, pk)
    if \self~resultOk(rs) then return .DirectoryResult~failure("STORE_SCHEMA_CREATE_FAILED", rs~message)
  end

  changeName = .NoSQLDirectoryStoreBuild~CHANGE_TABLE
  if engine~table(changeName) == .nil then do
    cols = .array~new
    cols~append(.DatabaseColumn~new("change_id", "VARCHAR", .false, .true, .true))
    cols~append(.DatabaseColumn~new("local_revision", "INTEGER", .false, .true))
    cols~append(.DatabaseColumn~new("origin_peer_id", "VARCHAR", .false))
    cols~append(.DatabaseColumn~new("origin_sequence", "INTEGER", .false))
    cols~append(.DatabaseColumn~new("operation", "VARCHAR", .false))
    cols~append(.DatabaseColumn~new("entity_id", "VARCHAR", .false))
    cols~append(.DatabaseColumn~new("created_at", "DATETIME", .false))
    cols~append(.DatabaseColumn~new("change_identity", "VARCHAR", .false))
    cols~append(.DatabaseColumn~new("payload", "TEXT", .false))
    pk = .array~of("change_id")
    unique = .array~new
    unique~append(.array~of("local_revision"))
    rs = engine~createTable(changeName, cols, pk, unique)
    if \self~resultOk(rs) then return .DirectoryResult~failure("STORE_SCHEMA_CREATE_FAILED", rs~message)
  end

  schema = self~metaValue("schema_version")
  if schema == .nil then do
    rs = self~putMeta("schema_version", .NoSQLDirectoryStoreBuild~SCHEMA_VERSION)
    if \rs~ok then return rs
  end
  else if schema <> .NoSQLDirectoryStoreBuild~SCHEMA_VERSION then return .DirectoryResult~failure("STORE_SCHEMA_VERSION_UNSUPPORTED", schema)
  return .DirectoryResult~success(.true, "SCHEMA_READY")

::method metaValue private
  expose engine
  use strict arg key
  rs = engine~selectWhereEquals(.NoSQLDirectoryStoreBuild~META_TABLE, "meta_key", key)
  if \self~resultOk(rs) then return .nil
  if rs~rows~items = 0 then return .nil
  return rs~rows[1]["meta_value"]~string

::method putMeta private
  expose engine
  use strict arg key, value
  existing = self~metaValue(key)
  if existing <> .nil then do
    if existing = value~string then return .DirectoryResult~success(.false, "META_PRESENT")
    return .DirectoryResult~failure("STORE_META_CONFLICT", key)
  end
  values = .table~new
  values["meta_key"] = key~string
  values["meta_value"] = value~string
  rs = engine~insert(.NoSQLDirectoryStoreBuild~META_TABLE, values)
  if \self~resultOk(rs) then return .DirectoryResult~failure("STORE_META_WRITE_FAILED", rs~message)
  return .DirectoryResult~success(.true, "META_STORED")

::method bindDirectory
  use strict arg peerId
  existing = self~metaValue("peer_id")
  if existing == .nil then return self~putMeta("peer_id", peerId)
  if existing <> peerId~string then return .DirectoryResult~failure("STORE_PEER_MISMATCH", existing || "/" || peerId~string)
  return .DirectoryResult~success(.false, "ALREADY_BOUND")

::method appendChange
  expose engine
  use strict arg change
  tableName = .NoSQLDirectoryStoreBuild~CHANGE_TABLE
  existing = engine~selectWhereEquals(tableName, "change_id", change~changeId)
  if \self~resultOk(existing) then return .DirectoryResult~failure("STORE_READ_FAILED", existing~message)
  if existing~rows~items > 0 then do
    row = existing~rows[1]
    if row["change_identity"]~string = change~semanticIdentity then return .DirectoryResult~success(.false, "ALREADY_STORED")
    return .DirectoryResult~failure("STORE_CHANGE_DIVERGED", change~changeId)
  end

  revisionRows = engine~selectWhereEquals(tableName, "local_revision", change~localRevision)
  if \self~resultOk(revisionRows) then return .DirectoryResult~failure("STORE_READ_FAILED", revisionRows~message)
  if revisionRows~rows~items > 0 then return .DirectoryResult~failure("STORE_REVISION_COLLISION", change~localRevision)

  values = .table~new
  values["change_id"] = change~changeId
  values["local_revision"] = change~localRevision
  values["origin_peer_id"] = change~originPeerId
  values["origin_sequence"] = change~originSequence
  values["operation"] = change~operation
  values["entity_id"] = change~entityId
  values["created_at"] = .DirectoryCanonical~dateTimeText(change~createdAt)
  values["change_identity"] = change~semanticIdentity
  values["payload"] = .DirectoryChangeCodec~toJson(change)
  rs = engine~insert(tableName, values)
  if \self~resultOk(rs) then return .DirectoryResult~failure("STORE_APPEND_FAILED", rs~message)
  return .DirectoryResult~success(.true, "STORED")

::method loadChanges
  expose engine
  rs = engine~selectAll(.NoSQLDirectoryStoreBuild~CHANGE_TABLE)
  if \self~resultOk(rs) then return .DirectoryResult~failure("STORE_READ_FAILED", rs~message)
  remaining = .array~new
  do row over rs~rows
    signal on syntax name corruptRow
    change = .DirectoryChangeCodec~fromJson(row["payload"]~string)
    signal off syntax
    if change~changeId <> row["change_id"]~string then return .DirectoryResult~failure("STORE_CORRUPT_CHANGE_ID", row["change_id"])
    if change~localRevision <> row["local_revision"] then return .DirectoryResult~failure("STORE_CORRUPT_REVISION", row["change_id"])
    if change~originPeerId <> row["origin_peer_id"]~string then return .DirectoryResult~failure("STORE_CORRUPT_ORIGIN", row["change_id"])
    if change~originSequence <> row["origin_sequence"] then return .DirectoryResult~failure("STORE_CORRUPT_ORIGIN_SEQUENCE", row["change_id"])
    if change~operation <> row["operation"]~string then return .DirectoryResult~failure("STORE_CORRUPT_OPERATION", row["change_id"])
    if change~entityId <> row["entity_id"]~string then return .DirectoryResult~failure("STORE_CORRUPT_ENTITY_ID", row["change_id"])
    if change~semanticIdentity <> row["change_identity"]~string then return .DirectoryResult~failure("STORE_CORRUPT_IDENTITY", row["change_id"])
    if .DirectoryCanonical~dateTimeText(change~createdAt) <> row["created_at"]~string then return .DirectoryResult~failure("STORE_CORRUPT_TIMESTAMP", row["change_id"])
    remaining~append(change)
  end

  out = .array~new
  do while remaining~items > 0
    bestIndex = 1
    bestRevision = remaining[1]~localRevision
    i = 2
    do while i <= remaining~items
      if remaining[i]~localRevision < bestRevision then do
        bestIndex = i
        bestRevision = remaining[i]~localRevision
      end
      i += 1
    end
    out~append(remaining[bestIndex])
    next = .array~new
    i = 1
    do while i <= remaining~items
      if i <> bestIndex then next~append(remaining[i])
      i += 1
    end
    remaining = next
  end
  return .DirectoryResult~success(out, "LOADED")
corruptRow:
  conditionObject = condition("O")
  signal off syntax
  detail = conditionObject["MESSAGE"]
  if detail == .nil then detail = conditionObject["ADDITIONAL"]
  else if detail = "" then detail = conditionObject["ADDITIONAL"]
  if detail == .nil then detail = "invalid persisted change payload"
  return .DirectoryResult~failure("STORE_CORRUPT_PAYLOAD", detail~string)

::method capabilities
  c = self~capabilities:super
  c["durable"] = .true
  c["atomicSingleChangeAppend"] = .true
  c["peerBinding"] = .true
  c["provider"] = "NOSQLSERVER_FILE"
  c["nosqlServerOwnsPhysicalPersistence"] = .true
  return c

::requires "src/DirectoryStore.cls"
::requires "NoSQLServer.cls"
