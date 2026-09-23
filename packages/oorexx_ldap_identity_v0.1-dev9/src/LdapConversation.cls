/* LdapConversation.cls
 * Parsed-operation LDAP conversation service. Authentication attribution and
 * operation authority are deliberately separate.
 */

::class LdapConversationBuild public
::constant API_VERSION "ldap.conversation/0.1"
::constant STATUS "PARSED_OPERATION_ENGINE_WITH_SEPARATE_BER_SOCKET_ADAPTER"

::class LdapBindResult public
::attribute ok get
::attribute code get
::attribute principalId get
::method init
  expose ok code principalId
  use strict arg okArg, codeArg, principalIdArg = ""
  ok = okArg
  code = codeArg~string~upper
  principalId = principalIdArg~string

::class LdapSession public
::attribute sessionId get
::attribute principalId get
::attribute authenticated get
::method init
  expose sessionId principalId authenticated
  use strict arg sessionIdArg, principalIdArg = "", authenticatedArg = .false
  sessionId = sessionIdArg~string
  principalId = principalIdArg~string
  authenticated = authenticatedArg

::class LdapAuthenticator public
::method bind
  use strict arg bindName, credential
  return .LdapBindResult~new(.false, "AUTHENTICATOR_NOT_CONFIGURED")

::class LdapSaslBuild public
::constant API_VERSION "ldap.sasl/0.1"

::class LdapSaslProvider public
::method mechanisms
  return .array~new
::method authenticate
  use strict arg mechanism, credentials = .nil, tlsActive = .false
  return .LdapBindResult~new(.false, "SASL_MECHANISM_UNAVAILABLE")

/* Reference one-step SASL PLAIN mechanism.  PLAIN carries credentials and is
 * therefore refused unless a TLS layer is already active.  The authcid is
 * passed to the configured LDAP authenticator; authorization-id delegation is
 * deliberately not inferred in this first mechanism provider. */
::class PlainLdapSaslProvider subclass LdapSaslProvider public
::method init
  expose authenticator
  use strict arg authenticatorArg
  authenticator = authenticatorArg
::method mechanisms
  return .array~of("PLAIN")
::method authenticate
  expose authenticator
  use strict arg mechanism, credentials = .nil, tlsActive = .false
  if \mechanism~string~caselessEquals("PLAIN") then return .LdapBindResult~new(.false, "SASL_MECHANISM_UNAVAILABLE")
  if \tlsActive then return .LdapBindResult~new(.false, "SASL_CONFIDENTIALITY_REQUIRED")
  if credentials == .nil then return .LdapBindResult~new(.false, "SASL_CREDENTIALS_REQUIRED")
  bytes = credentials~string
  first = bytes~pos('00'x)
  if first = 0 then return .LdapBindResult~new(.false, "SASL_PLAIN_INVALID")
  rest = bytes~substr(first + 1)
  second = rest~pos('00'x)
  if second = 0 then return .LdapBindResult~new(.false, "SASL_PLAIN_INVALID")
  authzid = bytes~left(first - 1)
  authcid = rest~left(second - 1)
  password = rest~substr(second + 1)
  if authcid = "" then return .LdapBindResult~new(.false, "SASL_PLAIN_INVALID")
  if authzid <> "" & \authzid~caselessEquals(authcid) then return .LdapBindResult~new(.false, "SASL_AUTHZID_UNSUPPORTED")
  return authenticator~bind(authcid, password)

::class LdapOperationAuthority public
::method authorize
  use strict arg session, action, resourceId, targetDn = ""
  return .DirectoryResult~failure("AUTHORITY_NOT_CONFIGURED")

::class DirectoryAclLdapAuthority subclass LdapOperationAuthority public
::method init
  expose directory
  use strict arg directoryArg
  directory = directoryArg
::method authorize
  expose directory
  use strict arg session, action, resourceId, targetDn = ""
  if session == .nil then return .DirectoryResult~failure("LDAP_AUTHENTICATION_REQUIRED")
  if \session~authenticated then return .DirectoryResult~failure("LDAP_AUTHENTICATION_REQUIRED")
  return directory~aclDecision(session~principalId, resourceId, action)

::class LdapConversationService public
::attribute directory get
::attribute personality get
::attribute directoryResourceId get
::method init
  expose directory personality authenticator authority directoryResourceId sessionSequence saslProvider
  use strict arg directoryArg, personalityArg, authenticatorArg, authorityArg, directoryResourceIdArg, saslProviderArg = .nil
  directory = directoryArg
  personality = personalityArg
  authenticator = authenticatorArg
  authority = authorityArg
  directoryResourceId = directoryResourceIdArg~string
  saslProvider = saslProviderArg
  sessionSequence = 0
::method bind
  expose authenticator sessionSequence
  use strict arg bindName, credential
  result = authenticator~bind(bindName, credential)
  sessionSequence += 1
  if \result~ok then return .DirectoryResult~failure(result~code)
  session = .LdapSession~new("ldap-session-" || sessionSequence, result~principalId, .true)
  return .DirectoryResult~success(session, "BIND_ATTRIBUTION_ONLY")
::method bindSasl
  expose saslProvider sessionSequence
  use strict arg mechanism, credentials = .nil, tlsActive = .false
  if saslProvider == .nil then return .DirectoryResult~failure("SASL_NOT_CONFIGURED")
  result = saslProvider~authenticate(mechanism, credentials, tlsActive)
  sessionSequence += 1
  if \result~ok then return .DirectoryResult~failure(result~code)
  session = .LdapSession~new("ldap-session-" || sessionSequence, result~principalId, .true)
  return .DirectoryResult~success(session, "SASL_BIND_ATTRIBUTION_ONLY")
::method saslMechanisms
  expose saslProvider
  if saslProvider == .nil then return .array~new
  return saslProvider~mechanisms
::method authorizeOperation
  expose authority directoryResourceId
  use strict arg session, action, targetDn = ""
  return authority~authorize(session, action, directoryResourceId, targetDn)
::method authorize private
  use strict arg session, action, targetDn = ""
  return self~authorizeOperation(session, action, targetDn)
::method inScope private
  use strict arg entryDn, baseDn, scope
  ep = .LdapDn~parse(entryDn)
  bp = .LdapDn~parse(baseDn)
  if \ep~ok | \bp~ok then return .false
  e = ep~value; b = bp~value
  s = scope~string~upper
  if s = "BASE" then return e~canonicalKey = b~canonicalKey
  if s = "SUB" then return e~isDescendantOf(b~canonicalText, .true)
  if s = "ONE" then return e~relativeDepth(b~canonicalText) = 1
  return .false
::method resolveEntity private
  expose directory
  use strict arg dn
  return .LdapDn~findEntity(directory, dn)
::method search
  expose directory personality
  use strict arg session, baseDn, scope = "SUB", filterText = "(objectClass=*)", requestedAttributes = .nil
  auth = self~authorize(session, "LDAP_SEARCH", baseDn)
  if \auth~ok then return auth
  baseParsed = .LdapDn~parse(baseDn)
  if \baseParsed~ok then return .DirectoryResult~failure("LDAP_INVALID_DN", baseDn)
  parsedFilter = .LdapFilter~parse(filterText)
  if \parsedFilter~ok then return .DirectoryResult~failure("LDAP_INVALID_FILTER", filterText)
  out = .array~new
  do entity over directory~allEntries
    if \self~inScope(entity~dn, baseDn, scope) then iterate
    entry = personality~project(entity, directory)
    if .LdapFilter~matchesNode(parsedFilter~value, entry~attributes) then out~append(self~selectAttributes(entry, requestedAttributes))
  end
  return .DirectoryResult~success(out)
::method selectAttributes private
  use strict arg entry, requestedAttributes
  if requestedAttributes == .nil then return entry
  selected = .LdapAttributeSet~new
  do name over requestedAttributes
    do value over entry~attributes~get(name)
      selected~add(name, value)
    end
  end
  return .LdapEntry~new(entry~dn, selected, entry~semanticEntityId)
::method compare
  expose directory personality
  use strict arg session, dn, attributeName, assertionValue
  auth = self~authorize(session, "LDAP_COMPARE", dn)
  if \auth~ok then return auth
  entity = self~resolveEntity(dn)
  if entity == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_OBJECT", dn)
  entry = personality~project(entity, directory)
  do value over entry~attributes~get(attributeName)
    if value~caselessEquals(assertionValue~string) then return .DirectoryResult~success(.true)
  end
  return .DirectoryResult~success(.false)
::method add
  expose personality directory
  use strict arg session, ldapEntry
  auth = self~authorize(session, "LDAP_ADD", ldapEntry~dn)
  if \auth~ok then return auth
  parsed = .LdapDn~parse(ldapEntry~dn)
  if \parsed~ok then return .DirectoryResult~failure("LDAP_INVALID_DN", ldapEntry~dn)
  canonicalEntry = .LdapEntry~new(parsed~value~canonicalText, ldapEntry~attributes, ldapEntry~semanticEntityId)
  if self~resolveEntity(canonicalEntry~dn) <> .nil then return .DirectoryResult~failure("LDAP_ALREADY_EXISTS", canonicalEntry~dn)
  return personality~importAdd(canonicalEntry, directory)
::method modify
  expose personality directory
  use strict arg session, dn, modifications
  auth = self~authorize(session, "LDAP_MODIFY", dn)
  if \auth~ok then return auth
  return personality~importModify(dn, modifications, directory)
::method delete
  expose directory
  use strict arg session, dn
  auth = self~authorize(session, "LDAP_DELETE", dn)
  if \auth~ok then return auth
  entity = self~resolveEntity(dn)
  if entity == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_OBJECT", dn)
  return directory~deleteEntity(entity~entityId)
::method modifyDn
  expose directory
  use strict arg session, dn, newDn
  auth = self~authorize(session, "LDAP_MODIFY_DN", dn)
  if \auth~ok then return auth
  entity = self~resolveEntity(dn)
  if entity == .nil then return .DirectoryResult~failure("LDAP_NO_SUCH_OBJECT", dn)
  parsed = .LdapDn~parse(newDn)
  if \parsed~ok then return .DirectoryResult~failure("LDAP_INVALID_DN", newDn)
  canonicalDn = parsed~value~canonicalText
  existing = self~resolveEntity(canonicalDn)
  if existing <> .nil then do
    if existing~entityId <> entity~entityId then return .DirectoryResult~failure("LDAP_ALREADY_EXISTS", canonicalDn)
  end
  return directory~renameEntity(entity~entityId, canonicalDn)
::method capabilities
  expose personality
  caps = personality~capabilities
  caps["bindAttributionSeparateFromAuthority"] = .true
  caps["search"] = .true
  caps["compare"] = .true
  caps["add"] = .true
  caps["delete"] = .true
  caps["modifyDn"] = .true
  caps["modify"] = .true
  caps["berSocketServer"] = .false
  caps["rfc4533Sync"] = .true
  caps["rfc4514DnSyntax"] = .true
  caps["dnComparisonProfile"] = .LdapDnBuild~COMPARISON_PROFILE
  caps["rfc4515FilterSyntax"] = .true
  caps["filterExtensibleMatch"] = .false
  caps["saslMechanisms"] = self~saslMechanisms
  return caps

::requires "src/LdapDirectoryPersonality.cls"
