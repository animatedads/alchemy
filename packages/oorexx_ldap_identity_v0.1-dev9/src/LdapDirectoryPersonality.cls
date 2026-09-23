/* LdapDirectoryPersonality.cls
 * Native LDAP semantic projection plus personality/filter seam.
 * This layer stays above BER/socket framing and operates on parsed LDAP operations.
 */

::class LdapIdentityBuild public
::constant API_VERSION "ldap.personality/0.1"
::constant NATIVE_PERSONALITY "oorexx-native-ldap/0.1"

::class LdapAttributeSet public
::method init
  expose values
  values = .directory~new
::method put
  expose values
  use strict arg name, value
  key = name~string~lower
  a = .array~new
  a~append(value~string)
  values[key] = a
  return self
::method add
  expose values
  use strict arg name, value
  key = name~string~lower
  if \values~hasIndex(key) then values[key] = .array~new
  values[key]~append(value~string)
  return self
::method get
  expose values
  use strict arg name
  key = name~string~lower
  if values~hasIndex(key) then return .DirectoryCanonical~copyArray(values[key])
  return .array~new
::method first
  vals = self~get(arg(1))
  if vals~items = 0 then return ""
  return vals[1]
::method names
  expose values
  out = .array~new
  do k over values~allIndexes
    out~append(k)
  end
  return .DirectoryCanonical~sortedStrings(out)
::method has
  expose values
  use strict arg name
  return values~hasIndex(name~string~lower)
::method copy
  c = .LdapAttributeSet~new
  do name over self~names
    do value over self~get(name)
      c~add(name, value)
    end
  end
  return c

::class LdapEntry public
::attribute dn get
::attribute attributes get
::attribute semanticEntityId get
::method init
  expose dn attributes semanticEntityId
  use strict arg dnArg, attributesArg, semanticEntityIdArg = ""
  dn = dnArg~string
  attributes = attributesArg
  semanticEntityId = semanticEntityIdArg~string

::class LdapModification public
::attribute operation get
::attribute attributeName get
::attribute values get
::method init
  expose operation attributeName values
  use strict arg operationArg, attributeNameArg, valuesArg = .nil
  operation = operationArg~string~upper
  if operation <> "ADD" & operation <> "DELETE" & operation <> "REPLACE" then raise syntax 88.900 array("LDAP modification operation must be ADD, DELETE or REPLACE")
  attributeName = attributeNameArg~string
  values = .DirectoryCanonical~copyArray(valuesArg)

::class DirectoryPersonality public
::attribute name get
::method init
  expose name
  use strict arg nameArg
  name = nameArg~string
::method project
  raise syntax 88.900 array("personality must implement project")
::method importAdd
  raise syntax 88.900 array("personality must implement importAdd")
::method importModify
  raise syntax 88.900 array("personality must implement importModify")
::method capabilities
  out = .directory~new
  out["personality"] = self~name
  out["semanticAuthority"] = "identity.directory/0.1"
  return out

::class NativeLdapPersonality subclass DirectoryPersonality public
::method init
  self~init:super("oorexx-native-ldap/0.1")
::method project
  use strict arg entity, directory
  a = .LdapAttributeSet~new
  a~add("objectClass", "top")
  uuid = directory~entryUuidFor(entity~entityId)
  if uuid = "" then uuid = entity~entryUuid
  a~put("entryUUID", uuid)
  a~put("oorexxEntityId", entity~entityId)
  a~put("oorexxEntryKind", entity~kind)
  a~put("oorexxEntryState", entity~state)
  a~put("oorexxRevision", entity~revision)
  a~put("oorexxCreatedAt", .DirectoryCanonical~dateTimeText(entity~createdAt))
  a~put("oorexxUpdatedAt", .DirectoryCanonical~dateTimeText(entity~updatedAt))
  select
    when entity~kind = "PRINCIPAL" then do
      a~add("objectClass", "oorexxPrincipal")
      if entity~loginName <> "" then a~put("uid", entity~loginName)
      if entity~displayName <> "" then a~put("cn", entity~displayName)
      else a~put("cn", entity~entityId)
      a~put("oorexxPrincipalType", entity~principalType)
    end
    when entity~kind = "GROUP" then do
      a~add("objectClass", "groupOfNames")
      if entity~displayName <> "" then a~put("cn", entity~displayName)
      else a~put("cn", entity~entityId)
      do memberId over entity~memberIds
        member = directory~entryById(memberId)
        if member <> .nil then a~add("member", member~dn)
      end
    end
    when entity~kind = "RESOURCE" then do
      a~add("objectClass", "oorexxResource")
      if entity~displayName <> "" then a~put("cn", entity~displayName)
      else a~put("cn", entity~entityId)
      a~put("oorexxResourceType", entity~resourceType)
      a~put("oorexxResourceRef", entity~resourceRef)
    end
    when entity~kind = "CREDENTIAL" then do
      a~add("objectClass", "oorexxCredential")
      a~put("oorexxOwnerId", entity~ownerId)
      a~put("oorexxCredentialType", entity~credentialType)
      a~put("oorexxSecretRef", entity~secretRef)
      if entity~notBefore <> .nil then a~put("oorexxNotBefore", .DirectoryCanonical~dateTimeText(entity~notBefore))
      if entity~notAfter <> .nil then a~put("oorexxNotAfter", .DirectoryCanonical~dateTimeText(entity~notAfter))
    end
    when entity~kind = "KEYSET" then do
      a~add("objectClass", "oorexxKeySet")
      a~put("oorexxOwnerId", entity~ownerId)
      a~put("oorexxKeyUsage", entity~usage)
      if entity~activeGenerationId <> "" then a~put("oorexxActiveKeyGeneration", entity~activeGenerationId)
    end
    when entity~kind = "KEYGEN" then do
      a~add("objectClass", "oorexxKeyGeneration")
      a~put("oorexxKeySetId", entity~keySetId)
      a~put("oorexxKeyGeneration", entity~generation)
      a~put("oorexxKeyAlgorithm", entity~algorithm)
      if entity~publicMaterial <> "" then a~put("oorexxPublicKey", entity~publicMaterial)
      a~put("oorexxSecretRef", entity~secretRef)
      if entity~notBefore <> .nil then a~put("oorexxNotBefore", .DirectoryCanonical~dateTimeText(entity~notBefore))
      if entity~notAfter <> .nil then a~put("oorexxNotAfter", .DirectoryCanonical~dateTimeText(entity~notAfter))
      if entity~rotateAt <> .nil then a~put("oorexxRotateAt", .DirectoryCanonical~dateTimeText(entity~rotateAt))
      if entity~revokedReason <> "" then a~put("oorexxRevocationReason", entity~revokedReason)
    end
    when entity~kind = "ACL" then do
      a~add("objectClass", "oorexxAclGrant")
      a~put("oorexxAclSubject", entity~subjectId)
      a~put("oorexxAclResource", entity~resourceId)
      a~put("oorexxAclAction", entity~action)
      a~put("oorexxAclEffect", entity~effect)
    end
    otherwise a~add("objectClass", "extensibleObject")
  end
  return .LdapEntry~new(entity~dn, a, entity~entityId)
::method importAdd
  use strict arg ldapEntry, directory
  a = ldapEntry~attributes
  kind = a~first("oorexxEntryKind")~upper
  id = a~first("oorexxEntityId")
  /* dev1-dev4 incorrectly overloaded entryUUID as platform identity.  Keep a
   * narrow import fallback for package compatibility, but all dev9 projection
   * emits a distinct server-assigned entryUUID plus oorexxEntityId. */
  if id = "" then id = a~first("entryUUID")
  if id = "" then return .DirectoryResult~failure("LDAP_ENTITY_ID_REQUIRED")
  select
    when kind = "PRINCIPAL" then return directory~createPrincipal(id, ldapEntry~dn, a~first("oorexxPrincipalType"), a~first("cn"), a~first("uid"))
    when kind = "GROUP" then return directory~createGroup(id, ldapEntry~dn, a~first("cn"))
    when kind = "RESOURCE" then return directory~createResource(id, ldapEntry~dn, a~first("oorexxResourceType"), a~first("oorexxResourceRef"), a~first("cn"))
    when kind = "CREDENTIAL" then do
      nb = self~parseOptionalDateTime(a~first("oorexxNotBefore"), "oorexxNotBefore")
      if \nb~ok then return nb
      na = self~parseOptionalDateTime(a~first("oorexxNotAfter"), "oorexxNotAfter")
      if \na~ok then return na
      entryState = a~first("oorexxEntryState")
      if entryState = "" then entryState = "STAGED"
      return directory~createCredential(id, ldapEntry~dn, a~first("oorexxOwnerId"), a~first("oorexxCredentialType"), a~first("oorexxSecretRef"), nb~value, na~value, entryState)
    end
    when kind = "ACL" then return directory~createAclGrant(id, ldapEntry~dn, a~first("oorexxAclSubject"), a~first("oorexxAclResource"), a~first("oorexxAclAction"), a~first("oorexxAclEffect"))
    otherwise return .DirectoryResult~failure("LDAP_ADD_KIND_UNSUPPORTED", kind)
  end
::method parseOptionalDateTime private
  use strict arg text, attributeName
  text = text~string~strip
  if text = "" then return .DirectoryResult~success(.nil)
  signal on syntax name invalidDateTime
  dt = .DateTime~fromUtcIsoDate(text)
  signal off syntax
  return .DirectoryResult~success(dt)
invalidDateTime:
  signal off syntax
  return .DirectoryResult~failure("LDAP_INVALID_DATETIME", attributeName || "=" || text)
::method importModify
  use strict arg dn, modifications, directory
  entity = .LdapDn~findEntity(directory, dn)
  if entity == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_OBJECT", dn)
  select
    when entity~kind = "PRINCIPAL" then return self~modifyPrincipal(entity, modifications, directory)
    when entity~kind = "GROUP" then return self~modifyGroup(entity, modifications, directory)
    when entity~kind = "RESOURCE" then return self~modifyResource(entity, modifications, directory)
    otherwise return .DirectoryResult~failure("LDAP_MODIFY_KIND_UNSUPPORTED", entity~kind)
  end
::method singleValueAfter private
  use strict arg currentValue, modification, allowEmpty = .true
  op = modification~operation
  vals = modification~values
  if op = "REPLACE" then do
    if vals~items > 1 then return .DirectoryResult~failure("LDAP_SINGLE_VALUE_ATTRIBUTE")
    if vals~items = 0 then do
      if allowEmpty then return .DirectoryResult~success("")
      return .DirectoryResult~failure("LDAP_ATTRIBUTE_REQUIRED")
    end
    return .DirectoryResult~success(vals[1]~string)
  end
  if op = "ADD" then do
    if vals~items <> 1 then return .DirectoryResult~failure("LDAP_SINGLE_VALUE_ATTRIBUTE")
    if currentValue <> "" then return .DirectoryResult~failure("LDAP_ATTRIBUTE_OR_VALUE_EXISTS")
    return .DirectoryResult~success(vals[1]~string)
  end
  if op = "DELETE" then do
    if \allowEmpty then return .DirectoryResult~failure("LDAP_ATTRIBUTE_REQUIRED")
    if vals~items = 0 then return .DirectoryResult~success("")
    do v over vals
      if currentValue~caselessEquals(v~string) then return .DirectoryResult~success("")
    end
    return .DirectoryResult~failure("LDAP_NO_SUCH_ATTRIBUTE")
  end
  return .DirectoryResult~failure("LDAP_MODIFICATION_OPERATION_INVALID")
::method modifyPrincipal private
  use strict arg entity, modifications, directory
  displayName = entity~displayName
  loginName = entity~loginName
  state = entity~state
  displayChanged = .false; loginChanged = .false; stateChanged = .false
  do m over modifications
    name = m~attributeName~lower
    select
      when name = "cn" then do
        r = self~singleValueAfter(displayName, m, .true); if \r~ok then return r
        displayName = r~value; displayChanged = .true
      end
      when name = "uid" then do
        r = self~singleValueAfter(loginName, m, .true); if \r~ok then return r
        loginName = r~value; loginChanged = .true
      end
      when name = "oorexxentrystate" then do
        r = self~singleValueAfter(state, m, .false); if \r~ok then return r
        state = r~value~upper; stateChanged = .true
      end
      otherwise return .DirectoryResult~failure("LDAP_ATTRIBUTE_IMMUTABLE", m~attributeName)
    end
  end
  if \displayChanged then displayName = .nil
  if \loginChanged then loginName = .nil
  if \stateChanged then state = .nil
  return directory~updatePrincipal(entity~entityId, displayName, loginName, state)
::method modifyGroup private
  use strict arg entity, modifications, directory
  displayName = entity~displayName
  members = entity~memberIds
  state = entity~state
  displayChanged = .false; membersChanged = .false; stateChanged = .false
  do m over modifications
    name = m~attributeName~lower
    select
      when name = "cn" then do
        r = self~singleValueAfter(displayName, m, .true); if \r~ok then return r
        displayName = r~value; displayChanged = .true
      end
      when name = "member" then do
        current = .directory~new
        do id over members; current[id] = .true; end
        if m~operation = "REPLACE" then current = .directory~new
        do memberDn over m~values
          member = .LdapDn~findEntity(directory, memberDn)
          if member == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_MEMBER", memberDn)
          id = member~entityId
          if m~operation = "DELETE" then do
            if current~hasIndex(id) then current~remove(id)
            else return .DirectoryResult~failure("LDAP_NO_SUCH_ATTRIBUTE", memberDn)
          end
          else do
            if m~operation = "ADD" & current~hasIndex(id) then return .DirectoryResult~failure("LDAP_ATTRIBUTE_OR_VALUE_EXISTS", memberDn)
            current[id] = .true
          end
        end
        if m~operation = "DELETE" & m~values~items = 0 then current = .directory~new
        members = .array~new
        do id over current~allIndexes; members~append(id); end
        membersChanged = .true
      end
      when name = "oorexxentrystate" then do
        r = self~singleValueAfter(state, m, .false); if \r~ok then return r
        state = r~value~upper; stateChanged = .true
      end
      otherwise return .DirectoryResult~failure("LDAP_ATTRIBUTE_IMMUTABLE", m~attributeName)
    end
  end
  if \displayChanged then displayName = .nil
  if \membersChanged then members = .nil
  if \stateChanged then state = .nil
  return directory~updateGroup(entity~entityId, displayName, members, state)
::method modifyResource private
  use strict arg entity, modifications, directory
  displayName = entity~displayName
  resourceRef = entity~resourceRef
  state = entity~state
  displayChanged = .false; refChanged = .false; stateChanged = .false
  do m over modifications
    name = m~attributeName~lower
    select
      when name = "cn" then do
        r = self~singleValueAfter(displayName, m, .true); if \r~ok then return r
        displayName = r~value; displayChanged = .true
      end
      when name = "oorexxresourceref" then do
        r = self~singleValueAfter(resourceRef, m, .false); if \r~ok then return r
        resourceRef = r~value; refChanged = .true
      end
      when name = "oorexxentrystate" then do
        r = self~singleValueAfter(state, m, .false); if \r~ok then return r
        state = r~value~upper; stateChanged = .true
      end
      otherwise return .DirectoryResult~failure("LDAP_ATTRIBUTE_IMMUTABLE", m~attributeName)
    end
  end
  if \displayChanged then displayName = .nil
  if \refChanged then resourceRef = .nil
  if \stateChanged then state = .nil
  return directory~updateResource(entity~entityId, displayName, resourceRef, state)
::method capabilities
  out = self~capabilities:super
  out["ldapNativeProjection"] = .true
  out["rawSecretMaterialExposed"] = .false
  out["vendorPolicyInCore"] = .false
  out["modify"] = .true
  out["dateTimeObjectsInCore"] = .true
  return out

/* Generic edge conversation filter. It can alias vendor-facing attribute names
 * without changing the semantic core. It is deliberately not an AD policy model. */
/* Composes an authoritative directory personality with a pure conversation
 * filter.  The wrapped personality remains the semantic/projection owner;
 * the filter changes only the externally visible vocabulary. */
::class FilteredDirectoryPersonality subclass DirectoryPersonality public
::method init
  expose inner filter
  use strict arg nameArg, innerArg, filterArg
  self~init:super(nameArg)
  inner = innerArg
  filter = filterArg
::method project
  expose inner filter
  use strict arg entity, directory
  return filter~fromNative(inner~project(entity, directory))
::method importAdd
  expose inner filter
  use strict arg ldapEntry, directory
  return inner~importAdd(filter~toNative(ldapEntry), directory)
::method importModify
  expose inner filter
  use strict arg dn, modifications, directory
  native = .array~new
  do m over modifications
    native~append(.LdapModification~new(m~operation, filter~toNativeName(m~attributeName), m~values))
  end
  return inner~importModify(dn, native, directory)
::method capabilities
  expose inner filter
  out = inner~capabilities
  out["personality"] = self~name
  out["conversationFilter"] = filter~name
  out["semanticAuthority"] = "identity.directory/0.1"
  out["vendorPolicyInCore"] = .false
  return out

::class AttributeAliasConversationFilter public
::attribute name get
::method init
  expose name inbound outbound
  use strict arg nameArg
  name = nameArg~string
  inbound = .directory~new
  outbound = .directory~new
::method addAlias
  expose inbound outbound
  use strict arg externalName, nativeName
  e = externalName~string~lower
  n = nativeName~string~lower
  inbound[e] = n
  outbound[n] = e
  return self
::method toNativeName
  expose inbound
  use strict arg name
  key = name~string~lower
  if inbound~hasIndex(key) then return inbound[key]
  return key
::method fromNativeName
  expose outbound
  use strict arg name
  key = name~string~lower
  if outbound~hasIndex(key) then return outbound[key]
  return key
::method toNative
  expose inbound
  use strict arg entry
  a = .LdapAttributeSet~new
  do name over entry~attributes~names
    native = name
    if inbound~hasIndex(name) then native = inbound[name]
    do value over entry~attributes~get(name)
      a~add(native, value)
    end
  end
  return .LdapEntry~new(entry~dn, a, entry~semanticEntityId)
::method fromNative
  expose outbound
  use strict arg entry
  a = .LdapAttributeSet~new
  do name over entry~attributes~names
    external = name
    if outbound~hasIndex(name) then external = outbound[name]
    do value over entry~attributes~get(name)
      a~add(external, value)
    end
  end
  return .LdapEntry~new(entry~dn, a, entry~semanticEntityId)

::requires "src/LdapFilter.cls"
::requires "src/LdapDn.cls"

