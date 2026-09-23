/* IdentityDirectory.cls
 * ooRexx Identity Directory v0.1-dev9
 *
 * Neutral semantic identity/resource/ACL/credential/key-lifecycle core.
 * LDAP and vendor dialects are conversations over this model; they are not
 * allowed to become the semantic authority.
 */

::class IdentityDirectoryBuild public
::constant RELEASE "0.1-dev9"
::constant STORE_API "identity.directory.store/0.1"
::constant API_VERSION "identity.directory/0.1"
::constant CREDENTIAL_API "identity.credentials/0.1"
::constant KEY_API "identity.keys/0.1"
::constant ACL_API "identity.acl/0.1"
::constant REPLICATION_API "identity.replication/0.1"

::class DirectoryResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string~upper
  detail = detailArg~string
  value = valueArg
::method success class
  use strict arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use strict arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class DirectoryCanonical public
::method field class
  use strict arg name, value = ""
  if value == .nil then value = ""
  value = value~string
  return name~string~upper || ":" || value~length || ":" || value || '0a'x
::method hash class
  use strict arg text
  return .SHA256~new(text~string)~digest
::method normalizedId class
  use strict arg value
  return value~string~strip
::method normalizedAction class
  use strict arg value
  return value~string~strip~upper
::method normalizedDn class
  use strict arg value
  /* Development canonical index only. Full RFC 4514 parsing belongs to the LDAP conversation layer. */
  return value~string~strip~lower
::method boolText class
  use strict arg value
  if value then return "TRUE"
  return "FALSE"
::method requireDateTime class
  use strict arg name, value
  .Validate~classType(name, value, .DateTime)
  return value
::method optionalDateTime class
  use strict arg name, value = .nil
  if value == .nil then return .nil
  .Validate~classType(name, value, .DateTime)
  return value
::method dateTimeText class
  use strict arg value = .nil
  if value == .nil then return ""
  .Validate~classType("value", value, .DateTime)
  /* Canonicalize absolute instants in UTC so equivalent timezone offsets
   * produce identical semantic text and replication identities. */
  return value~toUtcTime~utcIsoDate
::method entryUuidHex class
  use strict arg entityId, createdAt
  .Validate~classType("createdAt", createdAt, .DateTime)
  /* LDAP entryUUID is distinct from the platform semantic entityId.  The
   * directory derives a stable RFC-4122-variant UUID from immutable creation
   * identity.  SHA-256 provides the pseudorandom bits; version/variant bits
   * are then set explicitly.  Re-creating a deleted entityId at a later
   * instant therefore receives a different entryUUID. */
  seed = "OOREXX-IDENTITY-ENTRY-UUID/1" || '0a'x
  seed ||= self~field("ENTITY_ID", self~normalizedId(entityId))
  seed ||= self~field("CREATED_AT", self~dateTimeText(createdAt))
  h = self~hash(seed)~lower~left(32)
  h = h~overlay("4", 13)
  variant = x2d(h~substr(17,1)) // 4 + 8
  h = h~overlay(d2x(variant,1)~lower, 17)
  return h
::method entryUuidText class
  use strict arg entityId, createdAt
  h = self~entryUuidHex(entityId, createdAt)
  return h~substr(1,8) || "-" || h~substr(9,4) || "-" || h~substr(13,4) || "-" || h~substr(17,4) || "-" || h~substr(21,12)
::method entryUuidBytes class
  use strict arg entityId, createdAt
  return x2c(self~entryUuidHex(entityId, createdAt))
::method validateWindow class
  use strict arg notBefore = .nil, notAfter = .nil, rotateAt = .nil
  if notBefore <> .nil then .Validate~classType("notBefore", notBefore, .DateTime)
  if notAfter <> .nil then .Validate~classType("notAfter", notAfter, .DateTime)
  if rotateAt <> .nil then .Validate~classType("rotateAt", rotateAt, .DateTime)
  if notBefore <> .nil & notAfter <> .nil then if notBefore > notAfter then raise syntax 88.900 array("notBefore must not be later than notAfter")
  if rotateAt <> .nil then do
    if notBefore <> .nil then if rotateAt < notBefore then raise syntax 88.900 array("rotateAt must not be earlier than notBefore")
    if notAfter <> .nil then if rotateAt > notAfter then raise syntax 88.900 array("rotateAt must not be later than notAfter")
  end
  return .true
::method copyArray class
  use strict arg source = .nil
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out
::method sortedStrings class
  use strict arg source
  remaining = self~copyArray(source)
  out = .array~new
  do while remaining~items > 0
    bestIndex = 1
    best = remaining[1]~string
    i = 2
    do while i <= remaining~items
      candidate = remaining[i]~string
      if candidate < best then do
        best = candidate
        bestIndex = i
      end
      i += 1
    end
    out~append(best)
    next = .array~new
    i = 1
    do while i <= remaining~items
      if i <> bestIndex then next~append(remaining[i])
      i += 1
    end
    remaining = next
  end
  return out

::class DirectoryEntity public
::attribute entityId get
::attribute dn get
::attribute kind get
::attribute state get
::attribute revision get
::attribute createdAt get
::attribute updatedAt get
::method init
  expose entityId dn kind state revision createdAt updatedAt entryUuidHexCache
  use strict arg entityIdArg, dnArg, kindArg, stateArg = "ACTIVE"
  entityId = .DirectoryCanonical~normalizedId(entityIdArg)
  dn = dnArg~string~strip
  kind = kindArg~string~upper
  state = stateArg~string~upper
  revision = 0
  createdAt = .DateTime~new
  updatedAt = createdAt
  entryUuidHexCache = ""
  if entityId = "" | dn = "" | kind = "" then raise syntax 88.900 array("directory entity identity fields required")
::method setState
  expose state updatedAt
  use strict arg stateArg
  state = stateArg~string~upper
  updatedAt = .DateTime~new
  return self
::method rename
  expose dn updatedAt
  use strict arg dnArg
  if dnArg~string~strip = "" then raise syntax 88.900 array("directory DN required")
  dn = dnArg~string~strip
  updatedAt = .DateTime~new
  return self
::method stampRevision
  expose revision updatedAt
  use strict arg revisionArg
  revision = revisionArg
  updatedAt = .DateTime~new
  return self
::method restoreMetadata
  expose state revision createdAt updatedAt entryUuidHexCache
  use strict arg stateArg, revisionArg, createdAtArg, updatedAtArg, entryUuidHexArg = .nil
  .DirectoryCanonical~requireDateTime("createdAt", createdAtArg)
  .DirectoryCanonical~requireDateTime("updatedAt", updatedAtArg)
  state = stateArg~string~upper
  revision = revisionArg
  createdAt = createdAtArg
  updatedAt = updatedAtArg
  if entryUuidHexArg == .nil then entryUuidHexCache = ""
  else entryUuidHexCache = entryUuidHexArg~string~lower
  return self
::method baseCanonicalText
  expose entityId dn kind state
  text = "IDENTITY-DIRECTORY-ENTITY/1" || '0a'x
  text ||= .DirectoryCanonical~field("ENTITY_ID", entityId)
  text ||= .DirectoryCanonical~field("DN", dn)
  text ||= .DirectoryCanonical~field("KIND", kind)
  text ||= .DirectoryCanonical~field("STATE", state)
  return text
::method canonicalText
  return self~baseCanonicalText
::method semanticIdentity
  return .DirectoryCanonical~hash(self~canonicalText)
::method cachedEntryUuidHex
  expose entryUuidHexCache
  return entryUuidHexCache
::method entryUuidHex
  expose entryUuidHexCache
  if entryUuidHexCache = "" then entryUuidHexCache = .DirectoryCanonical~entryUuidHex(self~entityId, self~createdAt)
  return entryUuidHexCache
::method entryUuid
  h = self~entryUuidHex
  return h~substr(1,8) || "-" || h~substr(9,4) || "-" || h~substr(13,4) || "-" || h~substr(17,4) || "-" || h~substr(21,12)
::method entryUuidBytes
  return x2c(self~entryUuidHex)
::method copy
  raise syntax 88.900 array("copy must be implemented by concrete directory entity")

::class IdentityPrincipal subclass DirectoryEntity public
::attribute principalType get
::attribute displayName get
::attribute loginName get
::method init
  expose principalType displayName loginName
  use strict arg principalId, dn, principalTypeArg = "PERSON", displayNameArg = "", loginNameArg = ""
  self~init:super(principalId, dn, "PRINCIPAL", "ACTIVE")
  principalType = principalTypeArg~string~upper
  displayName = displayNameArg~string
  loginName = loginNameArg~string
::method setDisplayName
  expose displayName
  use strict arg value
  displayName = value~string
  return self
::method setLoginName
  expose loginName
  use strict arg value
  loginName = value~string
  return self
::method canonicalText
  expose principalType displayName loginName
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("PRINCIPAL_TYPE", principalType)
  text ||= .DirectoryCanonical~field("DISPLAY_NAME", displayName)
  text ||= .DirectoryCanonical~field("LOGIN_NAME", loginName)
  return text
::method copy
  expose principalType displayName loginName
  c = .IdentityPrincipal~new(self~entityId, self~dn, principalType, displayName, loginName)
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class IdentityGroup subclass DirectoryEntity public
::attribute displayName get
::method init
  expose displayName members
  use strict arg groupId, dn, displayNameArg = ""
  self~init:super(groupId, dn, "GROUP", "ACTIVE")
  displayName = displayNameArg~string
  members = .directory~new
::method setDisplayName
  expose displayName
  use strict arg value
  displayName = value~string
  return self
::method addMember
  expose members
  use strict arg entityId
  id = .DirectoryCanonical~normalizedId(entityId)
  if id = "" then return .false
  members[id] = .true
  return .true
::method removeMember
  expose members
  use strict arg entityId
  id = .DirectoryCanonical~normalizedId(entityId)
  if members~hasIndex(id) then members~remove(id)
  return .true
::method hasMember
  expose members
  use strict arg entityId
  return members~hasIndex(.DirectoryCanonical~normalizedId(entityId))
::method memberIds
  expose members
  ids = .array~new
  do id over members~allIndexes
    ids~append(id)
  end
  return .DirectoryCanonical~sortedStrings(ids)
::method canonicalText
  expose displayName
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("DISPLAY_NAME", displayName)
  do id over self~memberIds
    text ||= .DirectoryCanonical~field("MEMBER", id)
  end
  return text
::method copy
  expose displayName
  c = .IdentityGroup~new(self~entityId, self~dn, displayName)
  do id over self~memberIds
    c~addMember(id)
  end
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class DirectoryResource subclass DirectoryEntity public
::attribute resourceType get
::attribute resourceRef get
::attribute displayName get
::method init
  expose resourceType resourceRef displayName
  use strict arg resourceId, dn, resourceTypeArg, resourceRefArg, displayNameArg = ""
  self~init:super(resourceId, dn, "RESOURCE", "ACTIVE")
  resourceType = resourceTypeArg~string~upper
  resourceRef = resourceRefArg~string
  displayName = displayNameArg~string
::method setDisplayName
  expose displayName
  use strict arg value
  displayName = value~string
  return self
::method setResourceRef
  expose resourceRef
  use strict arg value
  resourceRef = value~string
  if resourceRef = "" then raise syntax 88.900 array("resource reference required")
  return self
::method canonicalText
  expose resourceType resourceRef displayName
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("RESOURCE_TYPE", resourceType)
  text ||= .DirectoryCanonical~field("RESOURCE_REF", resourceRef)
  text ||= .DirectoryCanonical~field("DISPLAY_NAME", displayName)
  return text
::method copy
  expose resourceType resourceRef displayName
  c = .DirectoryResource~new(self~entityId, self~dn, resourceType, resourceRef, displayName)
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class DirectoryCredential subclass DirectoryEntity public
::attribute ownerId get
::attribute credentialType get
::attribute secretRef get
::attribute notBefore get
::attribute notAfter get
::method init
  expose ownerId credentialType secretRef notBefore notAfter
  use strict arg credentialId, dn, ownerIdArg, credentialTypeArg, secretRefArg, notBeforeArg = .nil, notAfterArg = .nil, stateArg = "STAGED"
  self~init:super(credentialId, dn, "CREDENTIAL", stateArg)
  ownerId = ownerIdArg~string
  credentialType = credentialTypeArg~string~upper
  secretRef = secretRefArg~string
  notBefore = .DirectoryCanonical~optionalDateTime("notBefore", notBeforeArg)
  notAfter = .DirectoryCanonical~optionalDateTime("notAfter", notAfterArg)
  .DirectoryCanonical~validateWindow(notBefore, notAfter)
  if ownerId = "" | credentialType = "" | secretRef = "" then raise syntax 88.900 array("credential owner/type/secret reference required")
::method validAt
  expose notBefore notAfter
  use strict arg instant = (.DateTime~new)
  .DirectoryCanonical~requireDateTime("instant", instant)
  if notBefore <> .nil then if instant < notBefore then return .false
  if notAfter <> .nil then if instant > notAfter then return .false
  return .true
::method canonicalText
  expose ownerId credentialType secretRef notBefore notAfter
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("OWNER_ID", ownerId)
  text ||= .DirectoryCanonical~field("CREDENTIAL_TYPE", credentialType)
  text ||= .DirectoryCanonical~field("SECRET_REF", secretRef)
  text ||= .DirectoryCanonical~field("NOT_BEFORE", .DirectoryCanonical~dateTimeText(notBefore))
  text ||= .DirectoryCanonical~field("NOT_AFTER", .DirectoryCanonical~dateTimeText(notAfter))
  return text
::method copy
  expose ownerId credentialType secretRef notBefore notAfter
  c = .DirectoryCredential~new(self~entityId, self~dn, ownerId, credentialType, secretRef, notBefore, notAfter, self~state)
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class DirectoryKeySet subclass DirectoryEntity public
::attribute ownerId get
::attribute usage get
::attribute activeGenerationId get
::method init
  expose ownerId usage activeGenerationId
  use strict arg keySetId, dn, ownerIdArg, usageArg
  self~init:super(keySetId, dn, "KEYSET", "ACTIVE")
  ownerId = ownerIdArg~string
  usage = usageArg~string~upper
  activeGenerationId = ""
  if ownerId = "" | usage = "" then raise syntax 88.900 array("key-set owner/usage required")
::method setActiveGeneration
  expose activeGenerationId
  use strict arg keyGenerationId
  activeGenerationId = keyGenerationId~string
  return self
::method canonicalText
  expose ownerId usage activeGenerationId
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("OWNER_ID", ownerId)
  text ||= .DirectoryCanonical~field("USAGE", usage)
  text ||= .DirectoryCanonical~field("ACTIVE_GENERATION_ID", activeGenerationId)
  return text
::method copy
  expose ownerId usage activeGenerationId
  c = .DirectoryKeySet~new(self~entityId, self~dn, ownerId, usage)
  c~setActiveGeneration(activeGenerationId)
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class DirectoryKeyGeneration subclass DirectoryEntity public
::attribute keySetId get
::attribute generation get
::attribute algorithm get
::attribute publicMaterial get
::attribute secretRef get
::attribute notBefore get
::attribute notAfter get
::attribute rotateAt get
::attribute revokedReason get
::method init
  expose keySetId generation algorithm publicMaterial secretRef notBefore notAfter rotateAt revokedReason
  use strict arg keyGenerationId, dn, keySetIdArg, generationArg, algorithmArg, publicMaterialArg, secretRefArg, notBeforeArg = .nil, notAfterArg = .nil, rotateAtArg = .nil, stateArg = "STAGED"
  self~init:super(keyGenerationId, dn, "KEYGEN", stateArg)
  keySetId = keySetIdArg~string
  generation = generationArg
  algorithm = algorithmArg~string~upper
  publicMaterial = publicMaterialArg~string
  secretRef = secretRefArg~string
  notBefore = .DirectoryCanonical~optionalDateTime("notBefore", notBeforeArg)
  notAfter = .DirectoryCanonical~optionalDateTime("notAfter", notAfterArg)
  rotateAt = .DirectoryCanonical~optionalDateTime("rotateAt", rotateAtArg)
  .DirectoryCanonical~validateWindow(notBefore, notAfter, rotateAt)
  revokedReason = ""
  if keySetId = "" | algorithm = "" | secretRef = "" then raise syntax 88.900 array("key generation set/algorithm/secret reference required")
::method validAt
  expose notBefore notAfter
  use strict arg instant = (.DateTime~new)
  .DirectoryCanonical~requireDateTime("instant", instant)
  if notBefore <> .nil then if instant < notBefore then return .false
  if notAfter <> .nil then if instant > notAfter then return .false
  return .true
::method rotationDue
  expose rotateAt
  use strict arg instant = (.DateTime~new)
  .DirectoryCanonical~requireDateTime("instant", instant)
  if rotateAt == .nil then return .false
  return instant >= rotateAt
::method revoke
  expose revokedReason
  use strict arg reason = ""
  revokedReason = reason~string
  self~setState("REVOKED")
  return self
::method canonicalText
  expose keySetId generation algorithm publicMaterial secretRef notBefore notAfter rotateAt revokedReason
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("KEYSET_ID", keySetId)
  text ||= .DirectoryCanonical~field("GENERATION", generation)
  text ||= .DirectoryCanonical~field("ALGORITHM", algorithm)
  text ||= .DirectoryCanonical~field("PUBLIC_MATERIAL", publicMaterial)
  text ||= .DirectoryCanonical~field("SECRET_REF", secretRef)
  text ||= .DirectoryCanonical~field("NOT_BEFORE", .DirectoryCanonical~dateTimeText(notBefore))
  text ||= .DirectoryCanonical~field("NOT_AFTER", .DirectoryCanonical~dateTimeText(notAfter))
  text ||= .DirectoryCanonical~field("ROTATE_AT", .DirectoryCanonical~dateTimeText(rotateAt))
  text ||= .DirectoryCanonical~field("REVOKED_REASON", revokedReason)
  return text
::method copy
  expose keySetId generation algorithm publicMaterial secretRef notBefore notAfter rotateAt revokedReason
  c = .DirectoryKeyGeneration~new(self~entityId, self~dn, keySetId, generation, algorithm, publicMaterial, secretRef, notBefore, notAfter, rotateAt, self~state)
  if self~state = "REVOKED" then c~revoke(revokedReason)
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class DirectoryAclGrant subclass DirectoryEntity public
::attribute subjectId get
::attribute resourceId get
::attribute action get
::attribute effect get
::method init
  expose subjectId resourceId action effect
  use strict arg aclId, dn, subjectIdArg, resourceIdArg, actionArg, effectArg = "ALLOW"
  self~init:super(aclId, dn, "ACL", "ACTIVE")
  subjectId = subjectIdArg~string
  resourceId = resourceIdArg~string
  action = .DirectoryCanonical~normalizedAction(actionArg)
  effect = effectArg~string~upper
  if subjectId = "" | resourceId = "" | action = "" then raise syntax 88.900 array("ACL subject/resource/action required")
  if effect <> "ALLOW" & effect <> "DENY" then raise syntax 88.900 array("ACL effect must be ALLOW or DENY")
::method canonicalText
  expose subjectId resourceId action effect
  text = self~baseCanonicalText
  text ||= .DirectoryCanonical~field("SUBJECT_ID", subjectId)
  text ||= .DirectoryCanonical~field("RESOURCE_ID", resourceId)
  text ||= .DirectoryCanonical~field("ACTION", action)
  text ||= .DirectoryCanonical~field("EFFECT", effect)
  return text
::method copy
  expose subjectId resourceId action effect
  c = .DirectoryAclGrant~new(self~entityId, self~dn, subjectId, resourceId, action, effect)
  c~restoreMetadata(self~state, self~revision, self~createdAt, self~updatedAt, self~cachedEntryUuidHex)
  return c

::class DirectoryChange public
::attribute changeId get
::attribute originPeerId get
::attribute originSequence get
::attribute localRevision get
::attribute operation get
::attribute entityId get
::attribute beforeIdentity get
::attribute afterIdentity get
::attribute beforeEntity get
::attribute afterEntity get
::attribute createdAt get
::method init
  expose changeId originPeerId originSequence localRevision operation entityId beforeIdentity afterIdentity beforeEntity afterEntity createdAt
  use strict arg changeIdArg, originPeerIdArg, originSequenceArg, localRevisionArg, operationArg, entityIdArg, beforeEntityArg = .nil, afterEntityArg = .nil, createdAtArg = (.DateTime~new)
  changeId = changeIdArg~string
  originPeerId = originPeerIdArg~string
  originSequence = originSequenceArg
  localRevision = localRevisionArg
  operation = operationArg~string~upper
  entityId = entityIdArg~string
  beforeEntity = beforeEntityArg
  afterEntity = afterEntityArg
  if beforeEntity == .nil then beforeIdentity = ""
  else beforeIdentity = beforeEntity~semanticIdentity
  if afterEntity == .nil then afterIdentity = ""
  else afterIdentity = afterEntity~semanticIdentity
  createdAt = .DirectoryCanonical~requireDateTime("createdAt", createdAtArg)
::method canonicalText
  expose changeId originPeerId originSequence operation entityId beforeIdentity afterIdentity
  text = "IDENTITY-DIRECTORY-CHANGE/1" || '0a'x
  text ||= .DirectoryCanonical~field("CHANGE_ID", changeId)
  text ||= .DirectoryCanonical~field("ORIGIN_PEER_ID", originPeerId)
  text ||= .DirectoryCanonical~field("ORIGIN_SEQUENCE", originSequence)
  text ||= .DirectoryCanonical~field("OPERATION", operation)
  text ||= .DirectoryCanonical~field("ENTITY_ID", entityId)
  text ||= .DirectoryCanonical~field("BEFORE_IDENTITY", beforeIdentity)
  text ||= .DirectoryCanonical~field("AFTER_IDENTITY", afterIdentity)
  return text
::method semanticIdentity
  return .DirectoryCanonical~hash(self~canonicalText)

::class IdentityDirectory public
::attribute peerId get
::attribute revision get
::attribute store get
::method init
  expose peerId revision originSequence entriesById idByDn changes seenChanges store
  use strict arg peerIdArg = "local", storeArg = .nil, recover = .true
  peerId = peerIdArg~string
  if peerId = "" then raise syntax 88.900 array("directory peer id required")
  revision = 0
  originSequence = 0
  entriesById = .directory~new
  idByDn = .directory~new
  changes = .array~new
  seenChanges = .directory~new
  store = .nil
  if storeArg <> .nil then do
    r = self~attachStore(storeArg, recover)
    if \r~ok then raise syntax 88.900 array("directory store attach failed:" r~code r~detail)
  end
::method attachStore
  expose store revision entriesById
  use strict arg storeArg, recover = .true
  if storeArg == .nil then return .DirectoryResult~failure("STORE_REQUIRED")
  if store <> .nil then return .DirectoryResult~failure("STORE_ALREADY_ATTACHED")
  if revision <> 0 | entriesById~items <> 0 then return .DirectoryResult~failure("STORE_ATTACH_REQUIRES_PRISTINE_DIRECTORY")
  if \storeArg~hasMethod("APPENDCHANGE") | \storeArg~hasMethod("LOADCHANGES") | \storeArg~hasMethod("BINDDIRECTORY") then return .DirectoryResult~failure("INVALID_STORE_PROVIDER")
  bind = storeArg~bindDirectory(self~peerId)
  if \bind~ok then return bind
  store = storeArg
  if recover then do
    r = self~recoverFromStore
    if \r~ok then do
      store = .nil
      return r
    end
    return r
  end
  return .DirectoryResult~success(.true, "STORE_ATTACHED")
::method recoverFromStore
  expose store peerId revision originSequence entriesById idByDn changes seenChanges
  if store == .nil then return .DirectoryResult~success(.false, "NO_STORE")
  if revision <> 0 | entriesById~items <> 0 | changes~items <> 0 then return .DirectoryResult~failure("STORE_RECOVERY_REQUIRES_PRISTINE_DIRECTORY")
  loaded = store~loadChanges
  if \loaded~ok then return loaded
  expectedRevision = 1
  do change over loaded~value
    if change~localRevision <> expectedRevision then return .DirectoryResult~failure("STORE_REVISION_GAP", expectedRevision || "/" || change~localRevision)
    current = self~entryById(change~entityId)
    op = change~operation
    select
      when op = "ADD" then do
        if current <> .nil then return .DirectoryResult~failure("STORE_REPLAY_ADD_EXISTS", change~entityId)
        if change~afterEntity == .nil then return .DirectoryResult~failure("STORE_REPLAY_AFTER_REQUIRED", change~changeId)
        if change~afterEntity~revision <> change~localRevision then return .DirectoryResult~failure("STORE_REPLAY_ENTITY_REVISION", change~changeId)
        before = .nil
        after = change~afterEntity~copy
      end
      when op = "REPLACE" then do
        if current == .nil then return .DirectoryResult~failure("STORE_REPLAY_MISSING_ENTITY", change~entityId)
        if current~semanticIdentity <> change~beforeIdentity then return .DirectoryResult~failure("STORE_REPLAY_DIVERGED", change~changeId)
        if change~afterEntity == .nil then return .DirectoryResult~failure("STORE_REPLAY_AFTER_REQUIRED", change~changeId)
        if change~afterEntity~revision <> change~localRevision then return .DirectoryResult~failure("STORE_REPLAY_ENTITY_REVISION", change~changeId)
        before = current~copy
        after = change~afterEntity~copy
      end
      when op = "DELETE" then do
        if current == .nil then return .DirectoryResult~failure("STORE_REPLAY_MISSING_ENTITY", change~entityId)
        if current~semanticIdentity <> change~beforeIdentity then return .DirectoryResult~failure("STORE_REPLAY_DIVERGED", change~changeId)
        before = current~copy
        after = .nil
      end
      otherwise return .DirectoryResult~failure("STORE_REPLAY_OPERATION_UNSUPPORTED", op)
    end
    self~applyMutation(op, before, after)
    changes~append(change)
    seenChanges[change~changeId] = .true
    revision = change~localRevision
    if change~originPeerId = peerId then if change~originSequence > originSequence then originSequence = change~originSequence
    expectedRevision += 1
  end
  return .DirectoryResult~success(revision, "STORE_RECOVERED")
::method persistChange private
  expose store
  use strict arg change
  if store == .nil then return .DirectoryResult~success(.false, "VOLATILE")
  return store~appendChange(change)
::method entryById
  expose entriesById
  use strict arg entityId
  id = .DirectoryCanonical~normalizedId(entityId)
  if entriesById~hasIndex(id) then return entriesById[id]~copy
  return .nil
::method entryByDn
  expose entriesById idByDn
  use strict arg dn
  key = .DirectoryCanonical~normalizedDn(dn)
  if \idByDn~hasIndex(key) then return .nil
  return entriesById[idByDn[key]]~copy
::method entryUuidFor
  expose entriesById
  use strict arg entityId
  id = .DirectoryCanonical~normalizedId(entityId)
  if \entriesById~hasIndex(id) then return ""
  return entriesById[id]~entryUuid
::method entryUuidBytesFor
  expose entriesById
  use strict arg entityId
  id = .DirectoryCanonical~normalizedId(entityId)
  if \entriesById~hasIndex(id) then return ""
  return entriesById[id]~entryUuidBytes
::method allEntries
  expose entriesById
  out = .array~new
  ids = .array~new
  do id over entriesById~allIndexes
    ids~append(id)
  end
  do id over .DirectoryCanonical~sortedStrings(ids)
    out~append(entriesById[id]~copy)
  end
  return out
::method entriesOfKind
  use strict arg kind
  kind = kind~string~upper
  out = .array~new
  do entry over self~allEntries
    if entry~kind = kind then out~append(entry)
  end
  return out
::method commitAdd private
  expose entriesById idByDn
  use strict arg entity
  id = entity~entityId
  dnKey = .DirectoryCanonical~normalizedDn(entity~dn)
  if entriesById~hasIndex(id) then return .DirectoryResult~failure("ENTITY_EXISTS", id)
  if idByDn~hasIndex(dnKey) then return .DirectoryResult~failure("DN_EXISTS", entity~dn)
  return self~commitLocal("ADD", .nil, entity)
::method commitReplace private
  expose entriesById idByDn
  use strict arg entity
  id = entity~entityId
  if \entriesById~hasIndex(id) then return .DirectoryResult~failure("NO_SUCH_ENTITY", id)
  before = entriesById[id]~copy
  newDnKey = .DirectoryCanonical~normalizedDn(entity~dn)
  oldDnKey = .DirectoryCanonical~normalizedDn(before~dn)
  if newDnKey <> oldDnKey then do
    if idByDn~hasIndex(newDnKey) then return .DirectoryResult~failure("DN_EXISTS", entity~dn)
  end
  return self~commitLocal("REPLACE", before, entity)
::method commitDelete private
  expose entriesById
  use strict arg entityId
  id = .DirectoryCanonical~normalizedId(entityId)
  if \entriesById~hasIndex(id) then return .DirectoryResult~failure("NO_SUCH_ENTITY", id)
  return self~commitLocal("DELETE", entriesById[id]~copy, .nil)
::method commitLocal private
  expose peerId revision originSequence entriesById idByDn changes seenChanges
  use strict arg operation, beforeEntity = .nil, afterEntity = .nil
  nextRevision = revision + 1
  nextOriginSequence = originSequence + 1
  if afterEntity == .nil then entityId = beforeEntity~entityId
  else entityId = afterEntity~entityId
  if afterEntity <> .nil then afterEntity~stampRevision(nextRevision)
  changeId = peerId || ":" || nextOriginSequence
  change = .DirectoryChange~new(changeId, peerId, nextOriginSequence, nextRevision, operation, entityId, beforeEntity, afterEntity)
  persisted = self~persistChange(change)
  if \persisted~ok then return persisted
  revision = nextRevision
  originSequence = nextOriginSequence
  self~applyMutation(operation, beforeEntity, afterEntity)
  changes~append(change)
  seenChanges[changeId] = .true
  if afterEntity == .nil then value = .nil
  else value = afterEntity~copy
  return .DirectoryResult~success(value, changeId)
::method applyMutation private
  expose entriesById idByDn
  use strict arg operation, beforeEntity = .nil, afterEntity = .nil
  if beforeEntity <> .nil then do
    oldDnKey = .DirectoryCanonical~normalizedDn(beforeEntity~dn)
    if idByDn~hasIndex(oldDnKey) then idByDn~remove(oldDnKey)
    if operation = "DELETE" then do
      if entriesById~hasIndex(beforeEntity~entityId) then entriesById~remove(beforeEntity~entityId)
    end
  end
  if afterEntity <> .nil then do
    entriesById[afterEntity~entityId] = afterEntity~copy
    idByDn[.DirectoryCanonical~normalizedDn(afterEntity~dn)] = afterEntity~entityId
  end
  return .true
::method createPrincipal
  use strict arg principalId, dn, principalType = "PERSON", displayName = "", loginName = ""
  return self~commitAdd(.IdentityPrincipal~new(principalId, dn, principalType, displayName, loginName))
::method createGroup
  use strict arg groupId, dn, displayName = ""
  return self~commitAdd(.IdentityGroup~new(groupId, dn, displayName))
::method createResource
  use strict arg resourceId, dn, resourceType, resourceRef, displayName = ""
  return self~commitAdd(.DirectoryResource~new(resourceId, dn, resourceType, resourceRef, displayName))
::method createCredential
  use strict arg credentialId, dn, ownerId, credentialType, secretRef, notBefore = .nil, notAfter = .nil, state = "STAGED"
  if self~entryById(ownerId) == .nil then return .DirectoryResult~failure("NO_SUCH_OWNER", ownerId)
  return self~commitAdd(.DirectoryCredential~new(credentialId, dn, ownerId, credentialType, secretRef, notBefore, notAfter, state))
::method createKeySet
  use strict arg keySetId, dn, ownerId, usage
  if self~entryById(ownerId) == .nil then return .DirectoryResult~failure("NO_SUCH_OWNER", ownerId)
  return self~commitAdd(.DirectoryKeySet~new(keySetId, dn, ownerId, usage))
::method stageKeyGeneration
  use strict arg keyGenerationId, dn, keySetId, generation, algorithm, publicMaterial, secretRef, notBefore = .nil, notAfter = .nil, rotateAt = .nil
  ks = self~entryById(keySetId)
  if ks == .nil then return .DirectoryResult~failure("NO_SUCH_KEYSET", keySetId)
  if ks~kind <> "KEYSET" then return .DirectoryResult~failure("NO_SUCH_KEYSET", keySetId)
  do kg over self~entriesOfKind("KEYGEN")
    if kg~keySetId = keySetId & kg~generation = generation then return .DirectoryResult~failure("KEY_GENERATION_EXISTS", generation)
  end
  return self~commitAdd(.DirectoryKeyGeneration~new(keyGenerationId, dn, keySetId, generation, algorithm, publicMaterial, secretRef, notBefore, notAfter, rotateAt, "STAGED"))
::method activateKeyGeneration
  use strict arg keySetId, keyGenerationId, effectiveAt = (.DateTime~new)
  .DirectoryCanonical~requireDateTime("effectiveAt", effectiveAt)
  ks = self~entryById(keySetId)
  kg = self~entryById(keyGenerationId)
  if ks == .nil then return .DirectoryResult~failure("NO_SUCH_KEYSET", keySetId)
  if ks~kind <> "KEYSET" then return .DirectoryResult~failure("NO_SUCH_KEYSET", keySetId)
  if kg == .nil then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  if kg~kind <> "KEYGEN" then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  if kg~keySetId <> keySetId then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  if kg~state = "REVOKED" | kg~state = "DESTROYED" then return .DirectoryResult~failure("KEY_GENERATION_NOT_ACTIVATABLE", kg~state)
  if \kg~validAt(effectiveAt) then return .DirectoryResult~failure("KEY_GENERATION_NOT_EFFECTIVE", .DirectoryCanonical~dateTimeText(effectiveAt))
  oldActive = ks~activeGenerationId
  if oldActive <> "" & oldActive <> keyGenerationId then do
    previous = self~entryById(oldActive)
    if previous <> .nil then do
      previous~setState("RETIRING")
      ignore = self~commitReplace(previous)
    end
  end
  kg~setState("ACTIVE")
  r1 = self~commitReplace(kg)
  if \r1~ok then return r1
  ks = self~entryById(keySetId)
  ks~setActiveGeneration(keyGenerationId)
  return self~commitReplace(ks)
::method retireKeyGeneration
  use strict arg keyGenerationId
  kg = self~entryById(keyGenerationId)
  if kg == .nil then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  if kg~kind <> "KEYGEN" then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  if kg~state = "ACTIVE" then return .DirectoryResult~failure("ACTIVE_KEY_MUST_BE_REPLACED_FIRST", keyGenerationId)
  if kg~state = "REVOKED" | kg~state = "DESTROYED" then return .DirectoryResult~failure("KEY_GENERATION_NOT_RETIRABLE", kg~state)
  kg~setState("RETIRED")
  return self~commitReplace(kg)
::method revokeKeyGeneration
  use strict arg keyGenerationId, reason = ""
  kg = self~entryById(keyGenerationId)
  if kg == .nil then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  if kg~kind <> "KEYGEN" then return .DirectoryResult~failure("NO_SUCH_KEY_GENERATION", keyGenerationId)
  kg~revoke(reason)
  r = self~commitReplace(kg)
  if \r~ok then return r
  ks = self~entryById(kg~keySetId)
  if ks <> .nil then if ks~activeGenerationId = keyGenerationId then do
    ks~setActiveGeneration("")
    ignore = self~commitReplace(ks)
  end
  return r
::method addGroupMember
  use strict arg groupId, entityId
  group = self~entryById(groupId)
  member = self~entryById(entityId)
  if group == .nil then return .DirectoryResult~failure("NO_SUCH_GROUP", groupId)
  if group~kind <> "GROUP" then return .DirectoryResult~failure("NO_SUCH_GROUP", groupId)
  if member == .nil then return .DirectoryResult~failure("NO_SUCH_MEMBER", entityId)
  group~addMember(entityId)
  return self~commitReplace(group)
::method removeGroupMember
  use strict arg groupId, entityId
  group = self~entryById(groupId)
  if group == .nil then return .DirectoryResult~failure("NO_SUCH_GROUP", groupId)
  if group~kind <> "GROUP" then return .DirectoryResult~failure("NO_SUCH_GROUP", groupId)
  group~removeMember(entityId)
  return self~commitReplace(group)
::method updatePrincipal
  use strict arg principalId, displayName = .nil, loginName = .nil, state = .nil
  principal = self~entryById(principalId)
  if principal == .nil then return .DirectoryResult~failure("NO_SUCH_PRINCIPAL", principalId)
  if principal~kind <> "PRINCIPAL" then return .DirectoryResult~failure("NO_SUCH_PRINCIPAL", principalId)
  if displayName <> .nil then principal~setDisplayName(displayName)
  if loginName <> .nil then principal~setLoginName(loginName)
  if state <> .nil then principal~setState(state)
  return self~commitReplace(principal)
::method updateGroup
  use strict arg groupId, displayName = .nil, memberIds = .nil, state = .nil
  group = self~entryById(groupId)
  if group == .nil then return .DirectoryResult~failure("NO_SUCH_GROUP", groupId)
  if group~kind <> "GROUP" then return .DirectoryResult~failure("NO_SUCH_GROUP", groupId)
  if displayName <> .nil then group~setDisplayName(displayName)
  if memberIds <> .nil then do
    existing = group~memberIds
    do id over existing
      group~removeMember(id)
    end
    do id over memberIds
      member = self~entryById(id)
      if member == .nil then return .DirectoryResult~failure("NO_SUCH_MEMBER", id)
      group~addMember(id)
    end
  end
  if state <> .nil then group~setState(state)
  return self~commitReplace(group)
::method updateResource
  use strict arg resourceId, displayName = .nil, resourceRef = .nil, state = .nil
  resource = self~entryById(resourceId)
  if resource == .nil then return .DirectoryResult~failure("NO_SUCH_RESOURCE", resourceId)
  if resource~kind <> "RESOURCE" then return .DirectoryResult~failure("NO_SUCH_RESOURCE", resourceId)
  if displayName <> .nil then resource~setDisplayName(displayName)
  if resourceRef <> .nil then resource~setResourceRef(resourceRef)
  if state <> .nil then resource~setState(state)
  return self~commitReplace(resource)
::method createAclGrant
  use strict arg aclId, dn, subjectId, resourceId, action, effect = "ALLOW"
  if self~entryById(subjectId) == .nil then return .DirectoryResult~failure("NO_SUCH_SUBJECT", subjectId)
  resource = self~entryById(resourceId)
  if resource == .nil then return .DirectoryResult~failure("NO_SUCH_RESOURCE", resourceId)
  if resource~kind <> "RESOURCE" then return .DirectoryResult~failure("NO_SUCH_RESOURCE", resourceId)
  return self~commitAdd(.DirectoryAclGrant~new(aclId, dn, subjectId, resourceId, action, effect))
::method subjectMatches private
  use strict arg principalId, subjectId
  if principalId = subjectId then return .true
  group = self~entryById(subjectId)
  if group == .nil then return .false
  if group~kind <> "GROUP" then return .false
  return group~hasMember(principalId)
::method aclDecision
  use strict arg principalId, resourceId, action
  action = .DirectoryCanonical~normalizedAction(action)
  foundAllow = .false
  do acl over self~entriesOfKind("ACL")
    if acl~state <> "ACTIVE" then iterate
    if acl~resourceId <> resourceId then iterate
    if acl~action <> action & acl~action <> "*" then iterate
    if \self~subjectMatches(principalId, acl~subjectId) then iterate
    if acl~effect = "DENY" then return .DirectoryResult~failure("ACL_DENY", acl~entityId)
    if acl~effect = "ALLOW" then foundAllow = .true
  end
  if foundAllow then return .DirectoryResult~success(.true, "ACL_ALLOW")
  return .DirectoryResult~failure("ACL_DEFAULT_DENY", principalId || "/" || resourceId || "/" || action)
::method renameEntity
  use strict arg entityId, newDn
  entity = self~entryById(entityId)
  if entity == .nil then return .DirectoryResult~failure("NO_SUCH_ENTITY", entityId)
  entity~rename(newDn)
  return self~commitReplace(entity)
::method setEntityState
  use strict arg entityId, state
  entity = self~entryById(entityId)
  if entity == .nil then return .DirectoryResult~failure("NO_SUCH_ENTITY", entityId)
  entity~setState(state)
  return self~commitReplace(entity)
::method deleteEntity
  use strict arg entityId
  /* Fail closed on obvious owned children. */
  do entry over self~allEntries
    select
      when entry~kind = "CREDENTIAL" then if entry~ownerId = entityId then return .DirectoryResult~failure("ENTITY_HAS_DEPENDENTS", entry~entityId)
      when entry~kind = "KEYSET" then if entry~ownerId = entityId then return .DirectoryResult~failure("ENTITY_HAS_DEPENDENTS", entry~entityId)
      when entry~kind = "KEYGEN" then if entry~keySetId = entityId then return .DirectoryResult~failure("ENTITY_HAS_DEPENDENTS", entry~entityId)
      when entry~kind = "ACL" then if entry~subjectId = entityId | entry~resourceId = entityId then return .DirectoryResult~failure("ENTITY_HAS_DEPENDENTS", entry~entityId)
      otherwise nop
    end
  end
  return self~commitDelete(entityId)
::method changesSince
  expose changes
  use strict arg localRevision = 0
  out = .array~new
  do ch over changes
    if ch~localRevision > localRevision then out~append(ch)
  end
  return out
::method applyReplicatedChange
  expose revision entriesById seenChanges changes
  use strict arg change
  if change == .nil then return .DirectoryResult~failure("CHANGE_REQUIRED")
  if seenChanges~hasIndex(change~changeId) then return .DirectoryResult~success(.false, "ALREADY_APPLIED")
  current = self~entryById(change~entityId)
  op = change~operation
  select
    when op = "ADD" then do
      if current <> .nil then do
        if current~semanticIdentity = change~afterIdentity then do
          seenChanges[change~changeId] = .true
          return .DirectoryResult~success(.false, "SEMANTICALLY_PRESENT")
        end
        return .DirectoryResult~failure("REPLICATION_CONFLICT_ADD", change~entityId)
      end
    end
    when op = "REPLACE" then do
      if current == .nil then return .DirectoryResult~failure("REPLICATION_CONFLICT_MISSING", change~entityId)
      if current~semanticIdentity <> change~beforeIdentity then return .DirectoryResult~failure("REPLICATION_CONFLICT_DIVERGED", change~entityId)
    end
    when op = "DELETE" then do
      if current == .nil then do
        seenChanges[change~changeId] = .true
        return .DirectoryResult~success(.false, "ALREADY_ABSENT")
      end
      if current~semanticIdentity <> change~beforeIdentity then return .DirectoryResult~failure("REPLICATION_CONFLICT_DIVERGED", change~entityId)
    end
    otherwise return .DirectoryResult~failure("REPLICATION_OPERATION_UNSUPPORTED", op)
  end
  nextRevision = revision + 1
  before = .nil
  after = .nil
  if op = "ADD" then after = change~afterEntity~copy
  else if op = "REPLACE" then do
    before = current~copy
    after = change~afterEntity~copy
  end
  else if op = "DELETE" then before = current~copy
  if after <> .nil then after~stampRevision(nextRevision)
  local = .DirectoryChange~new(change~changeId, change~originPeerId, change~originSequence, nextRevision, op, change~entityId, before, after, change~createdAt)
  persisted = self~persistChange(local)
  if \persisted~ok then return persisted
  revision = nextRevision
  self~applyMutation(op, before, after)
  changes~append(local)
  seenChanges[change~changeId] = .true
  return .DirectoryResult~success(.true, "APPLIED")

::requires "crypto.cls"
