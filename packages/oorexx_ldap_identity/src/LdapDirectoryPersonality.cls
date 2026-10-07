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

::class NativeLdapSchemaPolicy public
::constant API_VERSION "ldap.schema.enforcement/0.1"
::method init
  expose matching
  use strict arg matchingArg = .nil
  if matchingArg == .nil then matching = .LdapMatchingRuleRegistry~new
  else matching = matchingArg
::method attributeDefinition
  expose matching
  use strict arg attributeName
  name = matching~canonicalAttributeName(attributeName)
  d = .directory~new
  d["known"] = .true
  d["name"] = name
  d["single"] = .true
  d["noUserModification"] = .false
  d["syntax"] = "DIRECTORY_STRING"
  select
    when name = "objectclass" then do; d["single"] = .false; d["syntax"] = "OBJECT_IDENTIFIER"; end
    when name = "cn" then d["single"] = .false
    when name = "uid" then nop
    when name = "member" then do; d["single"] = .false; d["syntax"] = "DN"; end
    when name = "entryuuid" then do; d["syntax"] = "UUID"; d["noUserModification"] = .true; end
    when name = "oorexxrevision" | name = "oorexxkeygeneration" then d["syntax"] = "INTEGER"
    when name = "oorexxcreatedat" | name = "oorexxupdatedat" then do; d["syntax"] = "DATETIME"; d["noUserModification"] = .true; end
    when name = "oorexxnotbefore" | name = "oorexxnotafter" | name = "oorexxrotateat" then d["syntax"] = "DATETIME"
    when name = "oorexxentityid" | name = "oorexxentrykind" | name = "oorexxentrystate" | name = "oorexxprincipaltype" | name = "oorexxresourcetype" | name = "oorexxresourceref" | name = "oorexxownerid" | name = "oorexxcredentialtype" | name = "oorexxsecretref" | name = "oorexxkeyusage" | name = "oorexxactivekeygeneration" | name = "oorexxkeysetid" | name = "oorexxkeyalgorithm" | name = "oorexxpublickey" | name = "oorexxrevocationreason" | name = "oorexxaclsubject" | name = "oorexxaclresource" | name = "oorexxaclaction" | name = "oorexxacleffect" then nop
    otherwise do
      d["known"] = .false
      d["single"] = .false
      d["syntax"] = ""
    end
  end
  if name = "oorexxrevision" | name = "oorexxactivekeygeneration" | name = "oorexxrevocationreason" then d["noUserModification"] = .true
  return d
::method normalizeAdd
  expose matching
  use strict arg ldapEntry
  attrsResult = self~normalizeAttributes(ldapEntry~attributes, .true)
  if \attrsResult~ok then return attrsResult
  attrs = attrsResult~value
  classResult = self~normalizeObjectClasses(attrs)
  if \classResult~ok then return classResult
  info = classResult~value
  kind = info["kind"]
  actualKind = attrs~first("oorexxEntryKind")~upper
  if actualKind = "" then attrs~put("oorexxEntryKind", kind)
  else if actualKind <> kind then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "oorexxEntryKind=" || actualKind || " expected=" || kind)
  valid = self~validateAttributes(attrs, info)
  if \valid~ok then return valid
  return .DirectoryResult~success(.LdapEntry~new(ldapEntry~dn, attrs, ldapEntry~semanticEntityId))
::method validateProjected
  use strict arg ldapEntry
  normalized = self~normalizeAttributes(ldapEntry~attributes, .false)
  if \normalized~ok then return normalized
  info = self~classInfo(normalized~value)
  if \info~ok then return info
  return self~validateAttributes(normalized~value, info~value)
::method normalizeModify
  expose matching
  use strict arg currentEntry, modifications
  normalized = .array~new
  do m over modifications
    def = self~attributeDefinition(m~attributeName)
    if \def["known"] then return .DirectoryResult~failure("LDAP_UNDEFINED_ATTRIBUTE_TYPE", m~attributeName)
    name = def["name"]
    if name = "objectclass" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_MODS_PROHIBITED", m~attributeName)
    if def["noUserModification"] then return .DirectoryResult~failure("LDAP_ATTRIBUTE_IMMUTABLE", m~attributeName || " is server-maintained")
    if name = "oorexxentityid" | name = "oorexxentrykind" then return .DirectoryResult~failure("LDAP_ATTRIBUTE_IMMUTABLE", m~attributeName || " is immutable")
    vals = m~values
    if def["single"] then do
      if m~operation = "ADD" & vals~items <> 1 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is single-valued")
      if m~operation = "REPLACE" & vals~items > 1 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is single-valued")
      if m~operation = "DELETE" & vals~items > 1 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is single-valued")
    end
    do value over vals
      syntaxResult = self~validateValue(name, value)
      if \syntaxResult~ok then return syntaxResult
    end
    normalized~append(.LdapModification~new(m~operation, name, vals))
  end
  applied = self~applyModifications(currentEntry~attributes, normalized)
  if \applied~ok then return applied
  classResult = self~classInfo(applied~value)
  if \classResult~ok then return classResult
  valid = self~validateAttributes(applied~value, classResult~value)
  if \valid~ok then return valid
  return .DirectoryResult~success(normalized)
::method normalizeAttributes private
  expose matching
  use strict arg attributes, rejectNoUserModification = .false
  out = .LdapAttributeSet~new
  do externalName over attributes~names
    def = self~attributeDefinition(externalName)
    if \def["known"] then return .DirectoryResult~failure("LDAP_UNDEFINED_ATTRIBUTE_TYPE", externalName)
    name = def["name"]
    do value over attributes~get(externalName)
      normalizedValue = value~string
      if name = "objectclass" then do
        normalizedValue = matching~canonicalObjectClass(value)
        if normalizedValue = "" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "unknown objectClass " || value)
      end
      out~add(name, normalizedValue)
    end
  end
  do name over out~names
    def = self~attributeDefinition(name)
    vals = out~get(name)
    if def["single"] & vals~items > 1 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is single-valued")
    if rejectNoUserModification & def["noUserModification"] & vals~items > 0 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is server-maintained")
    do value over vals
      syntaxResult = self~validateValue(name, value)
      if \syntaxResult~ok then return syntaxResult
    end
  end
  return .DirectoryResult~success(out)
::method normalizeObjectClasses private
  expose matching
  use strict arg attrs
  values = attrs~get("objectclass")
  if values~items = 0 then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "objectClass is required")
  semanticClass = ""; hasGroupOfNames = .false
  normalizedClasses = .array~new
  do value over values
    canonical = matching~canonicalObjectClass(value)
    if canonical = "" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "unknown objectClass " || value)
    self~appendUnique(normalizedClasses, canonical)
    key = canonical~lower
    if key = "groupofnames" then do
      hasGroupOfNames = .true
      if semanticClass = "" then semanticClass = "oorexxGroup"
      else if semanticClass <> "oorexxGroup" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "multiple structural classes")
    end
    else if key = "oorexxprincipal" | key = "oorexxgroup" | key = "oorexxresource" | key = "oorexxcredential" | key = "oorexxkeyset" | key = "oorexxkeygeneration" | key = "oorexxaclgrant" then do
      if semanticClass = "" then semanticClass = canonical
      else if semanticClass~lower <> key then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "multiple structural classes")
    end
    else if key <> "top" & key <> "oorexxentity" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "unsupported structural class " || canonical)
  end
  if semanticClass = "" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "native structural objectClass is required")
  self~appendUnique(normalizedClasses, "top")
  self~appendUnique(normalizedClasses, "oorexxEntity")
  if semanticClass = "oorexxGroup" then do
    if hasGroupOfNames & attrs~get("member")~items = 0 then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "groupOfNames requires member")
    /* groupOfNames is a legacy/interoperability input alias only.  Native
     * entries have exactly one structural class: oorexxGroup. */
    cleanClasses = .array~new
    do oc over normalizedClasses
      if \oc~caselessEquals("groupOfNames") then self~appendUnique(cleanClasses, oc)
    end
    normalizedClasses = cleanClasses
    self~appendUnique(normalizedClasses, "oorexxGroup")
  end
  attrs~put("objectclass", normalizedClasses[1])
  do i = 2 to normalizedClasses~items; attrs~add("objectclass", normalizedClasses[i]); end
  return self~classInfo(attrs)
::method classInfo private
  expose matching
  use strict arg attrs
  values = attrs~get("objectclass")
  semanticClass = ""
  do value over values
    canonical = matching~canonicalObjectClass(value)
    if canonical = "" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "unknown objectClass " || value)
    key = canonical~lower
    if key = "groupofnames" then do
      if semanticClass = "" then semanticClass = "oorexxGroup"
      else if semanticClass <> "oorexxGroup" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "multiple structural classes")
    end
    else if key = "oorexxprincipal" | key = "oorexxgroup" | key = "oorexxresource" | key = "oorexxcredential" | key = "oorexxkeyset" | key = "oorexxkeygeneration" | key = "oorexxaclgrant" then do
      if semanticClass = "" then semanticClass = canonical
      else if semanticClass~lower <> key then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "multiple structural classes")
    end
  end
  if semanticClass = "" then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", "native structural objectClass is required")
  info = .directory~new
  info["class"] = semanticClass
  select
    when semanticClass = "oorexxPrincipal" then info["kind"] = "PRINCIPAL"
    when semanticClass = "oorexxGroup" then info["kind"] = "GROUP"
    when semanticClass = "oorexxResource" then info["kind"] = "RESOURCE"
    when semanticClass = "oorexxCredential" then info["kind"] = "CREDENTIAL"
    when semanticClass = "oorexxKeySet" then info["kind"] = "KEYSET"
    when semanticClass = "oorexxKeyGeneration" then info["kind"] = "KEYGEN"
    when semanticClass = "oorexxAclGrant" then info["kind"] = "ACL"
    otherwise return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", semanticClass)
  end
  return .DirectoryResult~success(info)
::method validateAttributes private
  use strict arg attrs, info
  required = .array~of("objectclass", "oorexxentityid", "oorexxentrykind")
  allowed = .array~of("objectclass", "entryuuid", "oorexxentityid", "oorexxentrykind", "oorexxentrystate", "oorexxrevision", "oorexxcreatedat", "oorexxupdatedat")
  className = info["class"]
  select
    when className = "oorexxPrincipal" then do
      allowed = self~appendAll(allowed, .array~of("cn", "uid", "oorexxprincipaltype"))
    end
    when className = "oorexxGroup" then do
      required~append("cn")
      allowed = self~appendAll(allowed, .array~of("cn", "member"))
    end
    when className = "oorexxResource" then do
      required~append("oorexxresourcetype"); required~append("oorexxresourceref")
      allowed = self~appendAll(allowed, .array~of("cn", "oorexxresourcetype", "oorexxresourceref"))
    end
    when className = "oorexxCredential" then do
      required~append("oorexxownerid"); required~append("oorexxcredentialtype"); required~append("oorexxsecretref")
      allowed = self~appendAll(allowed, .array~of("oorexxownerid", "oorexxcredentialtype", "oorexxsecretref", "oorexxnotbefore", "oorexxnotafter"))
    end
    when className = "oorexxKeySet" then do
      required~append("oorexxownerid"); required~append("oorexxkeyusage")
      allowed = self~appendAll(allowed, .array~of("oorexxownerid", "oorexxkeyusage", "oorexxactivekeygeneration"))
    end
    when className = "oorexxKeyGeneration" then do
      required~append("oorexxkeysetid"); required~append("oorexxkeygeneration"); required~append("oorexxkeyalgorithm"); required~append("oorexxsecretref")
      allowed = self~appendAll(allowed, .array~of("oorexxkeysetid", "oorexxkeygeneration", "oorexxkeyalgorithm", "oorexxpublickey", "oorexxsecretref", "oorexxnotbefore", "oorexxnotafter", "oorexxrotateat", "oorexxrevocationreason"))
    end
    when className = "oorexxAclGrant" then do
      required = self~appendAll(required, .array~of("oorexxaclsubject", "oorexxaclresource", "oorexxaclaction", "oorexxacleffect"))
      allowed = self~appendAll(allowed, .array~of("oorexxaclsubject", "oorexxaclresource", "oorexxaclaction", "oorexxacleffect"))
    end
    otherwise return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", className)
  end
  do name over required
    if attrs~get(name)~items = 0 then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", className || " requires " || name)
  end
  do name over attrs~names
    if \self~arrayContains(allowed, name) then return .DirectoryResult~failure("LDAP_OBJECT_CLASS_VIOLATION", className || " does not allow " || name)
    def = self~attributeDefinition(name)
    if def["single"] & attrs~get(name)~items > 1 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is single-valued")
    if name = "cn" | name = "uid" then if attrs~get(name)~items > 1 then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", name || " is single-valued in native object model")
  end
  return .DirectoryResult~success(.true)
::method validateValue private
  expose matching
  use strict arg name, value
  def = self~attributeDefinition(name)
  select
    when def["syntax"] = "DN" then do
      parsed = .LdapDn~parse(value)
      if \parsed~ok then return .DirectoryResult~failure("LDAP_INVALID_ATTRIBUTE_SYNTAX", name || "=" || value)
    end
    when def["syntax"] = "UUID" then do
      if \matching~equality("uuidMatch", value, value) then return .DirectoryResult~failure("LDAP_INVALID_ATTRIBUTE_SYNTAX", name || "=" || value)
    end
    when def["syntax"] = "INTEGER" then do
      if \matching~equality("integerMatch", value, value) then return .DirectoryResult~failure("LDAP_INVALID_ATTRIBUTE_SYNTAX", name || "=" || value)
    end
    when def["syntax"] = "DATETIME" then do
      signal on syntax name badDateTime
      ignore = .DateTime~fromUtcIsoDate(value~string)
      signal off syntax
    end
    otherwise nop
  end
  return .DirectoryResult~success(.true)
badDateTime:
  signal off syntax
  return .DirectoryResult~failure("LDAP_INVALID_ATTRIBUTE_SYNTAX", name || "=" || value)
::method applyModifications private
  use strict arg attributes, modifications
  state = .directory~new
  do name over attributes~names; state[name] = attributes~get(name); end
  do m over modifications
    name = m~attributeName~lower
    if state~hasIndex(name) then current = state[name]
    else current = .array~new
    if m~operation = "REPLACE" then state[name] = .DirectoryCanonical~copyArray(m~values)
    else if m~operation = "ADD" then do
      do value over m~values
        if self~containsValue(name, current, value) then return .DirectoryResult~failure("LDAP_ATTRIBUTE_OR_VALUE_EXISTS", name || "=" || value)
        current~append(value~string)
      end
      state[name] = current
    end
    else if m~operation = "DELETE" then do
      if m~values~items = 0 then state~remove(name)
      else do
        do value over m~values
          next = .array~new; found = .false
          do existing over current
            if \found & self~valuesEqual(name, existing, value) then found = .true
            else next~append(existing)
          end
          if \found then return .DirectoryResult~failure("LDAP_NO_SUCH_ATTRIBUTE", name || "=" || value)
          current = next
        end
        if current~items = 0 then state~remove(name)
        else state[name] = current
      end
    end
  end
  attrs = .LdapAttributeSet~new
  do name over state~allIndexes
    do value over state[name]; attrs~add(name, value); end
  end
  return .DirectoryResult~success(attrs)
::method containsValue private
  use strict arg name, values, target
  do value over values; if self~valuesEqual(name, value, target) then return .true; end
  return .false
::method valuesEqual private
  expose matching
  use strict arg name, left, right
  rule = matching~equalityRuleFor(name)
  if rule = "" then return left~string = right~string
  return matching~equality(rule, left, right)
::method appendUnique private
  use strict arg values, value
  do existing over values; if existing~caselessEquals(value) then return values; end
  values~append(value)
  return values
::method appendAll private
  use strict arg target, source
  do value over source; self~appendUnique(target, value); end
  return target
::method arrayContains private
  use strict arg values, value
  do existing over values; if existing~caselessEquals(value) then return .true; end
  return .false

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
  use strict arg dn, modifications, directory, matchingRegistry = .nil
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
  a~add("objectClass", "oorexxEntity")
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
      a~add("objectClass", "oorexxGroup")
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
  schema = .NativeLdapSchemaPolicy~new
  normalized = schema~normalizeAdd(ldapEntry)
  if \normalized~ok then return normalized
  ldapEntry = normalized~value
  a = ldapEntry~attributes
  kind = a~first("oorexxEntryKind")~upper
  id = a~first("oorexxEntityId")
  if id = "" then return .DirectoryResult~failure("LDAP_ENTITY_ID_REQUIRED")
  select
    when kind = "PRINCIPAL" then return directory~createPrincipal(id, ldapEntry~dn, a~first("oorexxPrincipalType"), a~first("cn"), a~first("uid"))
    when kind = "GROUP" then do
      memberIds = .array~new
      matching = .LdapMatchingRuleRegistry~new
      do memberDn over a~get("member")
        member = matching~findEntity(directory, memberDn)
        if member == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_MEMBER", memberDn)
        memberIds~append(member~entityId)
      end
      return directory~createGroup(id, ldapEntry~dn, a~first("cn"), memberIds)
    end
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
    when kind = "KEYSET" then return directory~createKeySet(id, ldapEntry~dn, a~first("oorexxOwnerId"), a~first("oorexxKeyUsage"))
    when kind = "KEYGEN" then do
      entryState = a~first("oorexxEntryState")~upper
      if entryState <> "" & entryState <> "STAGED" then return .DirectoryResult~failure("LDAP_CONSTRAINT_VIOLATION", "new key generation must be STAGED")
      nb = self~parseOptionalDateTime(a~first("oorexxNotBefore"), "oorexxNotBefore"); if \nb~ok then return nb
      na = self~parseOptionalDateTime(a~first("oorexxNotAfter"), "oorexxNotAfter"); if \na~ok then return na
      ra = self~parseOptionalDateTime(a~first("oorexxRotateAt"), "oorexxRotateAt"); if \ra~ok then return ra
      return directory~stageKeyGeneration(id, ldapEntry~dn, a~first("oorexxKeySetId"), a~first("oorexxKeyGeneration") + 0, a~first("oorexxKeyAlgorithm"), a~first("oorexxPublicKey"), a~first("oorexxSecretRef"), nb~value, na~value, ra~value)
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
  use strict arg dn, modifications, directory, matchingRegistry = .nil
  if matchingRegistry == .nil then matchingRegistry = .LdapMatchingRuleRegistry~new
  entity = matchingRegistry~findEntity(directory, dn)
  if entity == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_OBJECT", dn)
  schema = .NativeLdapSchemaPolicy~new(matchingRegistry)
  normalized = schema~normalizeModify(self~project(entity, directory), modifications)
  if \normalized~ok then return normalized
  modifications = normalized~value
  select
    when entity~kind = "PRINCIPAL" then return self~modifyPrincipal(entity, modifications, directory)
    when entity~kind = "GROUP" then return self~modifyGroup(entity, modifications, directory, matchingRegistry)
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
  use strict arg entity, modifications, directory, matchingRegistry
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
          member = matchingRegistry~findEntity(directory, memberDn)
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
  out["schemaEnforcement"] = .true
  out["schemaEnforcementApi"] = .NativeLdapSchemaPolicy~API_VERSION
  out["schemaEnforcementScope"] = "NATIVE_PUBLISHED_SCHEMA"
  out["dynamicSchemaMutation"] = .false
  out["rdnAttributeEnforcement"] = .false
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
  use strict arg dn, modifications, directory, matchingRegistry = .nil
  native = .array~new
  do m over modifications
    native~append(.LdapModification~new(m~operation, filter~toNativeName(m~attributeName), m~values))
  end
  return inner~importModify(dn, native, directory, matchingRegistry)
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
  expose name inbound outbound classInbound classOutbound
  use strict arg nameArg
  name = nameArg~string
  inbound = .directory~new
  outbound = .directory~new
  classInbound = .directory~new
  classOutbound = .directory~new
::method addAlias
  expose inbound outbound
  use strict arg externalName, nativeName
  e = externalName~string~lower
  n = nativeName~string~lower
  inbound[e] = n
  outbound[n] = e
  return self
::method addObjectClassAlias
  expose classInbound classOutbound
  use strict arg externalClass, nativeClass
  e = externalClass~string~lower
  n = nativeClass~string
  classInbound[e] = n
  classOutbound[n~lower] = externalClass~string
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
  expose inbound classInbound
  use strict arg entry
  a = .LdapAttributeSet~new
  do name over entry~attributes~names
    native = name
    if inbound~hasIndex(name) then native = inbound[name]
    do value over entry~attributes~get(name)
      projected = value
      if native~caselessEquals("objectClass") then do
        key = value~string~lower
        if classInbound~hasIndex(key) then projected = classInbound[key]
      end
      a~add(native, projected)
    end
  end
  return .LdapEntry~new(entry~dn, a, entry~semanticEntityId)
::method fromNative
  expose outbound classOutbound
  use strict arg entry
  a = .LdapAttributeSet~new
  do name over entry~attributes~names
    external = name
    if outbound~hasIndex(name) then external = outbound[name]
    do value over entry~attributes~get(name)
      projected = value
      if name~caselessEquals("objectClass") then do
        key = value~string~lower
        if classOutbound~hasIndex(key) then projected = classOutbound[key]
      end
      a~add(external, projected)
    end
  end
  return .LdapEntry~new(entry~dn, a, entry~semanticEntityId)

::requires "src/LdapFilter.cls"
::requires "src/LdapMatchingRules.cls"
::requires "src/LdapDn.cls"

