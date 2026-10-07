/* LdapAccessPermissionsAdapter.cls
 * Optional Access Permissions integration for Identity Directory / LDAP.
 *
 * Bind attribution remains separate.  This adapter asks the platform
 * AccessControlAuthority whether the attributed principal may cross the LDAP
 * directory domain through the exact LDAP operation entry point.  It does not
 * treat an Access Control decision as method Permission; protected ooRexx
 * method surfaces still require their own PermissionAuthority enforcement.
 */

::class AccessPermissionsLdapAuthority subclass LdapOperationAuthority public
::attribute domainId get
::method init
  expose accessAuthority policy domainId requestSequence
  use strict arg accessAuthorityArg, policyArg, domainIdArg = "LDAP:DIRECTORY"
  if accessAuthorityArg == .nil then raise syntax 88.900 array("Access Permissions authority required")
  if policyArg == .nil then raise syntax 88.900 array("Access Permissions policy required")
  accessAuthority = accessAuthorityArg
  policy = policyArg
  domainId = domainIdArg~string~upper
  requestSequence = 0
::method authorize
  expose accessAuthority policy domainId requestSequence
  use strict arg session, action, resourceId, targetDn = ""
  if session == .nil then return .DirectoryResult~failure("LDAP_AUTHENTICATION_REQUIRED")
  if \session~authenticated then return .DirectoryResult~failure("LDAP_AUTHENTICATION_REQUIRED")
  requestSequence += 1
  intendedAt = .DateTime~new
  requestId = "ldap-access:" || session~sessionId || ":" || requestSequence
  request = .AccessControlRequest~new(requestId, session~principalId, domainId, action~string~upper, intendedAt)
  ignore = request~putAttribute("RESOURCE_ID", resourceId~string)
  if targetDn~string <> "" then ignore = request~putAttribute("TARGET_DN", targetDn~string)
  ignore = request~putAttribute("LDAP_SESSION_ID", session~sessionId)
  request~seal

  result = accessAuthority~decide(request, policy)
  if \result~ok then return .DirectoryResult~failure("ACCESS_PERMISSIONS_FAILURE", result~code)
  envelope = result~value
  if envelope == .nil then return .DirectoryResult~failure("ACCESS_PERMISSIONS_FAILURE", "missing envelope")
  if envelope~decision == .nil then return .DirectoryResult~failure("ACCESS_PERMISSIONS_FAILURE", "missing decision")
  decision = envelope~decision
  if \decision~allowed then return .DirectoryResult~failure("LDAP_AUTHORIZATION_DENIED", decision~code)
  return .DirectoryResult~success(envelope, decision~code)

::requires "src/LdapConversation.cls"
::requires "AccessPermissions.cls"
