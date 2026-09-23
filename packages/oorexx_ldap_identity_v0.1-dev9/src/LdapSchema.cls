/* LdapSchema.cls
 * Read-only subschema projection for the native ooRexx LDAP personality.
 *
 * This is discovery metadata, not a second semantic authority.  Native
 * mutation APIs already constrain the fields they can change; dev9 does not
 * claim a general LDAP schema/matching-rule enforcement engine.
 */

::class LdapSchemaBuild public
::constant API_VERSION "ldap.schema/0.1"
::constant SUBSCHEMA_DN "cn=subschema"

::class LdapSchemaRegistry public
::method entry
  use strict arg requestedAttributes = .nil
  a = .LdapAttributeSet~new
  a~add("objectClass", "top")
  a~add("objectClass", "subschema")
  a~put("cn", "subschema")
  do value over self~attributeTypes; a~add("attributeTypes", value); end
  do value over self~objectClasses; a~add("objectClasses", value); end
  do value over self~matchingRules; a~add("matchingRules", value); end
  do value over self~ldapSyntaxes; a~add("ldapSyntaxes", value); end
  full = .LdapEntry~new(.LdapSchemaBuild~SUBSCHEMA_DN, a, "ldap-subschema")
  if requestedAttributes == .nil then return full
  if requestedAttributes~items = 0 then return full
  do name over requestedAttributes; if name = "*" | name = "+" then return full; end
  selected = .LdapAttributeSet~new
  do name over requestedAttributes
    if name = "1.1" then iterate
    do value over a~get(name); selected~add(name, value); end
  end
  return .LdapEntry~new(.LdapSchemaBuild~SUBSCHEMA_DN, selected, "ldap-subschema")
::method attributeTypes
  out = .array~new
  out~append("( 2.5.4.0 NAME 'objectClass' EQUALITY objectIdentifierMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.38 )")
  out~append("( 2.5.4.3 NAME 'cn' EQUALITY caseIgnoreMatch SUBSTR caseIgnoreSubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )")
  out~append("( 0.9.2342.19200300.100.1.1 NAME 'uid' EQUALITY caseIgnoreMatch SUBSTR caseIgnoreSubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 SINGLE-VALUE )")
  out~append("( 2.5.4.31 NAME 'member' EQUALITY distinguishedNameMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 )")
  out~append("( 1.3.6.1.1.16.4 NAME 'entryUUID' EQUALITY uuidMatch ORDERING uuidOrderingMatch SYNTAX 1.3.6.1.1.16.1 SINGLE-VALUE NO-USER-MODIFICATION USAGE directoryOperation )")
  out~append(self~privateAttribute("1", "oorexxEntityId", .true))
  out~append(self~privateAttribute("2", "oorexxEntryKind", .true))
  out~append(self~privateAttribute("3", "oorexxEntryState", .true))
  out~append(self~privateAttribute("4", "oorexxRevision", .true))
  out~append(self~privateAttribute("5", "oorexxCreatedAt", .true))
  out~append(self~privateAttribute("6", "oorexxUpdatedAt", .true))
  out~append(self~privateAttribute("7", "oorexxPrincipalType", .true))
  out~append(self~privateAttribute("8", "oorexxResourceType", .true))
  out~append(self~privateAttribute("9", "oorexxResourceRef", .true))
  out~append(self~privateAttribute("10", "oorexxOwnerId", .true))
  out~append(self~privateAttribute("11", "oorexxCredentialType", .true))
  out~append(self~privateAttribute("12", "oorexxSecretRef", .true))
  out~append(self~privateAttribute("13", "oorexxNotBefore", .true))
  out~append(self~privateAttribute("14", "oorexxNotAfter", .true))
  out~append(self~privateAttribute("15", "oorexxKeyUsage", .true))
  out~append(self~privateAttribute("16", "oorexxActiveKeyGeneration", .true))
  out~append(self~privateAttribute("17", "oorexxKeySetId", .true))
  out~append(self~privateAttribute("18", "oorexxKeyGeneration", .true))
  out~append(self~privateAttribute("19", "oorexxKeyAlgorithm", .true))
  out~append(self~privateAttribute("20", "oorexxPublicKey", .true))
  out~append(self~privateAttribute("21", "oorexxRotateAt", .true))
  out~append(self~privateAttribute("22", "oorexxRevocationReason", .true))
  out~append(self~privateAttribute("23", "oorexxAclSubject", .true))
  out~append(self~privateAttribute("24", "oorexxAclResource", .true))
  out~append(self~privateAttribute("25", "oorexxAclAction", .true))
  out~append(self~privateAttribute("26", "oorexxAclEffect", .true))
  return out
::method privateAttribute private
  use strict arg suffix, name, single = .false
  text = "( 1.3.6.1.4.1.32473.999.1." || suffix || " NAME '" || name || "' EQUALITY caseIgnoreMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15"
  if single then text ||= " SINGLE-VALUE"
  return text || " )"
::method objectClasses
  out = .array~new
  out~append("( 2.5.6.0 NAME 'top' ABSTRACT MUST objectClass )")
  out~append("( 2.5.20.1 NAME 'subschema' AUXILIARY MAY ( cn $ attributeTypes $ objectClasses $ matchingRules $ ldapSyntaxes ) )")
  out~append("( 2.5.6.9 NAME 'groupOfNames' SUP top STRUCTURAL MUST ( cn $ member ) )")
  out~append("( 1.3.6.1.4.1.32473.999.2.1 NAME 'oorexxPrincipal' SUP top STRUCTURAL MUST ( oorexxEntityId $ oorexxEntryKind ) MAY ( cn $ uid $ oorexxPrincipalType $ oorexxEntryState ) )")
  out~append("( 1.3.6.1.4.1.32473.999.2.2 NAME 'oorexxResource' SUP top STRUCTURAL MUST ( oorexxEntityId $ oorexxEntryKind ) MAY ( cn $ oorexxResourceType $ oorexxResourceRef $ oorexxEntryState ) )")
  out~append("( 1.3.6.1.4.1.32473.999.2.3 NAME 'oorexxCredential' SUP top STRUCTURAL MUST ( oorexxEntityId $ oorexxOwnerId $ oorexxCredentialType $ oorexxSecretRef ) MAY ( oorexxNotBefore $ oorexxNotAfter $ oorexxEntryState ) )")
  out~append("( 1.3.6.1.4.1.32473.999.2.4 NAME 'oorexxKeySet' SUP top STRUCTURAL MUST ( oorexxEntityId $ oorexxOwnerId ) MAY ( oorexxKeyUsage $ oorexxActiveKeyGeneration ) )")
  out~append("( 1.3.6.1.4.1.32473.999.2.5 NAME 'oorexxKeyGeneration' SUP top STRUCTURAL MUST ( oorexxEntityId $ oorexxKeySetId $ oorexxKeyGeneration $ oorexxKeyAlgorithm ) MAY ( oorexxPublicKey $ oorexxSecretRef $ oorexxNotBefore $ oorexxNotAfter $ oorexxRotateAt $ oorexxRevocationReason $ oorexxEntryState ) )")
  out~append("( 1.3.6.1.4.1.32473.999.2.6 NAME 'oorexxAclGrant' SUP top STRUCTURAL MUST ( oorexxEntityId $ oorexxAclSubject $ oorexxAclResource $ oorexxAclAction $ oorexxAclEffect ) )")
  return out
::method matchingRules
  return .array~of("( 2.5.13.2 NAME 'caseIgnoreMatch' SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )", "( 2.5.13.1 NAME 'distinguishedNameMatch' SYNTAX 1.3.6.1.4.1.1466.115.121.1.12 )")
::method ldapSyntaxes
  return .array~of("( 1.3.6.1.4.1.1466.115.121.1.15 DESC 'Directory String' )", "( 1.3.6.1.4.1.1466.115.121.1.12 DESC 'DN' )", "( 1.3.6.1.1.16.1 DESC 'UUID' )")

::requires "src/LdapDirectoryPersonality.cls"
