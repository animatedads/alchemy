/* DirectoryStore.cls
 * ooRexx Identity Directory v0.1-dev9
 *
 * Provider-neutral durable change-log boundary for the Identity Directory.
 * The directory owns identity semantics. Stores persist accepted semantic
 * changes; they do not reinterpret LDAP, ACL, credential, or key policy.
 *
 * JSON serialization uses the ooRexx-supplied json.cls. No local JSON parser
 * or encoder is implemented here.
 */

::class DirectoryStoreBuild public
::constant API_VERSION "identity.directory.store/0.1"
::constant CODEC_VERSION "identity.directory.change-json/0.1"

::class DirectoryEntityCodec public
::method stringValue class
  use strict arg value = ""
  if value == .nil then value = ""
  return .JsonString~new(value~string)

::method optionalDateTimeText class
  use strict arg value = .nil
  if value == .nil then return self~stringValue("")
  return self~stringValue(.DirectoryCanonical~dateTimeText(value))

::method stringArray class
  use strict arg values = .nil
  out = .array~new
  if values == .nil then return out
  do value over values
    out~append(self~stringValue(value))
  end
  return out

::method toRecord class
  use strict arg entity
  if entity == .nil then return .nil
  r = .directory~new
  r["entityId"] = self~stringValue(entity~entityId)
  r["dn"] = self~stringValue(entity~dn)
  r["kind"] = self~stringValue(entity~kind)
  r["state"] = self~stringValue(entity~state)
  r["revision"] = entity~revision
  r["createdAt"] = self~stringValue(.DirectoryCanonical~dateTimeText(entity~createdAt))
  r["updatedAt"] = self~stringValue(.DirectoryCanonical~dateTimeText(entity~updatedAt))

  select
    when entity~kind = "PRINCIPAL" then do
      r["principalType"] = self~stringValue(entity~principalType)
      r["displayName"] = self~stringValue(entity~displayName)
      r["loginName"] = self~stringValue(entity~loginName)
    end
    when entity~kind = "GROUP" then do
      r["displayName"] = self~stringValue(entity~displayName)
      r["members"] = self~stringArray(entity~memberIds)
    end
    when entity~kind = "RESOURCE" then do
      r["resourceType"] = self~stringValue(entity~resourceType)
      r["resourceRef"] = self~stringValue(entity~resourceRef)
      r["displayName"] = self~stringValue(entity~displayName)
    end
    when entity~kind = "CREDENTIAL" then do
      r["ownerId"] = self~stringValue(entity~ownerId)
      r["credentialType"] = self~stringValue(entity~credentialType)
      r["secretRef"] = self~stringValue(entity~secretRef)
      r["notBefore"] = self~optionalDateTimeText(entity~notBefore)
      r["notAfter"] = self~optionalDateTimeText(entity~notAfter)
    end
    when entity~kind = "KEYSET" then do
      r["ownerId"] = self~stringValue(entity~ownerId)
      r["usage"] = self~stringValue(entity~usage)
      r["activeGenerationId"] = self~stringValue(entity~activeGenerationId)
    end
    when entity~kind = "KEYGEN" then do
      r["keySetId"] = self~stringValue(entity~keySetId)
      r["generation"] = entity~generation
      r["algorithm"] = self~stringValue(entity~algorithm)
      r["publicMaterial"] = self~stringValue(entity~publicMaterial)
      r["secretRef"] = self~stringValue(entity~secretRef)
      r["notBefore"] = self~optionalDateTimeText(entity~notBefore)
      r["notAfter"] = self~optionalDateTimeText(entity~notAfter)
      r["rotateAt"] = self~optionalDateTimeText(entity~rotateAt)
      r["revokedReason"] = self~stringValue(entity~revokedReason)
    end
    when entity~kind = "ACL" then do
      r["subjectId"] = self~stringValue(entity~subjectId)
      r["resourceId"] = self~stringValue(entity~resourceId)
      r["action"] = self~stringValue(entity~action)
      r["effect"] = self~stringValue(entity~effect)
    end
    otherwise raise syntax 88.900 array("unsupported directory entity kind for persistence:" entity~kind)
  end
  return r

::method dateTimeFromText class
  use strict arg value = ""
  if value == .nil then return .nil
  text = value~string
  if text = "" then return .nil
  return .DateTime~fromUtcIsoDate(text)

::method requiredDateTimeFromText class
  use strict arg name, value
  dt = self~dateTimeFromText(value)
  if dt == .nil then raise syntax 88.900 array(name || " required in persisted directory record")
  return dt

::method fromRecord class
  use strict arg r
  if r == .nil then return .nil
  kind = r["kind"]~string~upper
  id = r["entityId"]~string
  dn = r["dn"]~string
  state = r["state"]~string~upper

  select
    when kind = "PRINCIPAL" then entity = .IdentityPrincipal~new(id, dn, r["principalType"]~string, r["displayName"]~string, r["loginName"]~string)
    when kind = "GROUP" then do
      entity = .IdentityGroup~new(id, dn, r["displayName"]~string)
      members = r["members"]
      if members <> .nil then do member over members
        entity~addMember(member~string)
      end
    end
    when kind = "RESOURCE" then entity = .DirectoryResource~new(id, dn, r["resourceType"]~string, r["resourceRef"]~string, r["displayName"]~string)
    when kind = "CREDENTIAL" then entity = .DirectoryCredential~new(id, dn, r["ownerId"]~string, r["credentialType"]~string, r["secretRef"]~string, self~dateTimeFromText(r["notBefore"]), self~dateTimeFromText(r["notAfter"]), state)
    when kind = "KEYSET" then do
      entity = .DirectoryKeySet~new(id, dn, r["ownerId"]~string, r["usage"]~string)
      entity~setActiveGeneration(r["activeGenerationId"]~string)
    end
    when kind = "KEYGEN" then do
      entity = .DirectoryKeyGeneration~new(id, dn, r["keySetId"]~string, r["generation"], r["algorithm"]~string, r["publicMaterial"]~string, r["secretRef"]~string, self~dateTimeFromText(r["notBefore"]), self~dateTimeFromText(r["notAfter"]), self~dateTimeFromText(r["rotateAt"]), state)
      if state = "REVOKED" then entity~revoke(r["revokedReason"]~string)
    end
    when kind = "ACL" then entity = .DirectoryAclGrant~new(id, dn, r["subjectId"]~string, r["resourceId"]~string, r["action"]~string, r["effect"]~string)
    otherwise raise syntax 88.900 array("unsupported persisted directory entity kind:" kind)
  end

  createdAt = self~requiredDateTimeFromText("createdAt", r["createdAt"])
  updatedAt = self~requiredDateTimeFromText("updatedAt", r["updatedAt"])
  entity~restoreMetadata(state, r["revision"], createdAt, updatedAt)
  return entity

::class DirectoryChangeCodec public
::method stringValue class
  use strict arg value = ""
  if value == .nil then value = ""
  return .JsonString~new(value~string)

::method toRecord class
  use strict arg change
  r = .directory~new
  r["codec"] = self~stringValue(.DirectoryStoreBuild~CODEC_VERSION)
  r["changeId"] = self~stringValue(change~changeId)
  r["originPeerId"] = self~stringValue(change~originPeerId)
  r["originSequence"] = change~originSequence
  r["localRevision"] = change~localRevision
  r["operation"] = self~stringValue(change~operation)
  r["entityId"] = self~stringValue(change~entityId)
  r["beforeIdentity"] = self~stringValue(change~beforeIdentity)
  r["afterIdentity"] = self~stringValue(change~afterIdentity)
  r["createdAt"] = self~stringValue(.DirectoryCanonical~dateTimeText(change~createdAt))
  r["beforeEntity"] = .DirectoryEntityCodec~toRecord(change~beforeEntity)
  r["afterEntity"] = .DirectoryEntityCodec~toRecord(change~afterEntity)
  return r

::method toJson class
  use strict arg change
  return .json~toJSON(self~toRecord(change))

::method fromRecord class
  use strict arg r
  if r["codec"] == .nil then raise syntax 88.900 array("persisted directory change codec missing")
  if r["codec"]~string <> .DirectoryStoreBuild~CODEC_VERSION then raise syntax 88.900 array("unsupported persisted directory change codec:" r["codec"]~string)
  before = .DirectoryEntityCodec~fromRecord(r["beforeEntity"])
  after = .DirectoryEntityCodec~fromRecord(r["afterEntity"])
  createdAt = .DirectoryEntityCodec~requiredDateTimeFromText("change.createdAt", r["createdAt"])
  change = .DirectoryChange~new(r["changeId"]~string, r["originPeerId"]~string, r["originSequence"], r["localRevision"], r["operation"]~string, r["entityId"]~string, before, after, createdAt)
  if change~beforeIdentity <> r["beforeIdentity"]~string then raise syntax 88.900 array("persisted directory change before identity mismatch:" change~changeId)
  if change~afterIdentity <> r["afterIdentity"]~string then raise syntax 88.900 array("persisted directory change after identity mismatch:" change~changeId)
  return change

::method fromJson class
  use strict arg jsonText
  return self~fromRecord(.json~fromJSON(jsonText~string))

::class DirectoryStore public
::method apiVersion
  return .DirectoryStoreBuild~API_VERSION
::method bindDirectory
  use strict arg peerId
  return .DirectoryResult~success(.true, "UNBOUND_PROVIDER")
::method appendChange
  use strict arg change
  raise syntax 88.900 array("DirectoryStore appendChange must be implemented")
::method loadChanges
  raise syntax 88.900 array("DirectoryStore loadChanges must be implemented")
::method capabilities
  c = .directory~new
  c["appendOnlyChangeLog"] = .true
  c["durable"] = .false
  c["atomicSingleChangeAppend"] = .false
  c["peerBinding"] = .false
  return c

::class MemoryDirectoryStore subclass DirectoryStore public
::method init
  expose boundPeer changes byId
  boundPeer = ""
  changes = .array~new
  byId = .directory~new
::method bindDirectory
  expose boundPeer
  use strict arg peerId
  peerId = peerId~string
  if boundPeer = "" then do
    boundPeer = peerId
    return .DirectoryResult~success(.true, "BOUND")
  end
  if boundPeer <> peerId then return .DirectoryResult~failure("STORE_PEER_MISMATCH", boundPeer || "/" || peerId)
  return .DirectoryResult~success(.false, "ALREADY_BOUND")
::method appendChange
  expose changes byId
  use strict arg change
  if byId~hasIndex(change~changeId) then do
    existing = byId[change~changeId]
    if existing~semanticIdentity = change~semanticIdentity then return .DirectoryResult~success(.false, "ALREADY_STORED")
    return .DirectoryResult~failure("STORE_CHANGE_DIVERGED", change~changeId)
  end
  copy = .DirectoryChangeCodec~fromJson(.DirectoryChangeCodec~toJson(change))
  changes~append(copy)
  byId[copy~changeId] = copy
  return .DirectoryResult~success(.true, "STORED")
::method loadChanges
  expose changes
  out = .array~new
  remaining = .array~new
  do change over changes
    remaining~append(.DirectoryChangeCodec~fromJson(.DirectoryChangeCodec~toJson(change)))
  end
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
::method capabilities
  c = self~capabilities:super
  c["atomicSingleChangeAppend"] = .true
  c["peerBinding"] = .true
  return c

::requires "src/IdentityDirectory.cls"
::requires "json.cls"
