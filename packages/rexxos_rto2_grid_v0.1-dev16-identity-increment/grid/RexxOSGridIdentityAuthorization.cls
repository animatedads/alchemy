/* RexxOS Grid / Identity Directory authorization seam.
 *
 * The caller must already have an attributed principal from an approved
 * authentication path (for example LDAP Bind over the owned LDAP service).
 * Authentication is deliberately not performed here.  Identity Directory
 * remains identity/ACL authority; Grid remains estate authority.
 */
::class RexxOSGridAuthorizationEvidence public

::method init
  expose allowed code principalId principalRevision resourceId resourceRevision resourceRef directoryRevision action
  use strict arg allowedArg, codeArg, principalIdArg, principalRevisionArg, resourceIdArg, resourceRevisionArg, resourceRefArg, directoryRevisionArg, actionArg
  allowed = allowedArg
  code = codeArg~string~upper
  principalId = principalIdArg~string
  principalRevision = principalRevisionArg
  resourceId = resourceIdArg~string
  resourceRevision = resourceRevisionArg
  resourceRef = resourceRefArg~string
  directoryRevision = directoryRevisionArg
  action = actionArg~string~upper

::attribute allowed get
::attribute code get
::attribute principalId get
::attribute principalRevision get
::attribute resourceId get
::attribute resourceRevision get
::attribute resourceRef get
::attribute directoryRevision get
::attribute action get

::method asRecord
  expose allowed code principalId principalRevision resourceId resourceRevision resourceRef directoryRevision action
  r = .Directory~new
  r["schema"] = "rexxos.grid.identity-authorization/0.1"
  r["allowed"] = allowed
  r["code"] = code
  r["principal_id"] = principalId
  r["principal_revision"] = principalRevision
  r["resource_id"] = resourceId
  r["resource_revision"] = resourceRevision
  r["resource_ref"] = resourceRef
  r["directory_revision"] = directoryRevision
  r["action"] = action
  r["authentication_authority"] = "EXTERNAL_ATTRIBUTION_REQUIRED"
  r["authorization_authority"] = "IDENTITY_DIRECTORY_ACL"
  r["grid_authority_effect"] = "ACCESS_GATE_ONLY"
  return r

::class RexxOSGridIdentityAuthorization public

::method init
  expose directory gridId resourceType
  use strict arg directoryArg, gridIdArg, resourceTypeArg = "REXXOS_GRID"
  directory = directoryArg
  gridId = gridIdArg~string
  resourceType = resourceTypeArg~string~upper
  if gridId = "" then raise syntax 93.900 array("grid identity required")
  if \directory~hasMethod("ENTRYBYID") | \directory~hasMethod("ENTRIESOFKIND") | \directory~hasMethod("ACLDECISION") then raise syntax 93.900 array("identity directory provider required")

::attribute gridId get

::method serviceResourceRef
  expose gridId
  use strict arg serviceName = "rexxos.grid/0.1"
  return "rexxos://" || gridId || "/service/" || serviceName~string

::method authorizeService
  use strict arg principalId, action, serviceName = "rexxos.grid/0.1"
  return self~authorizeResource(principalId, self~serviceResourceRef(serviceName), action)

::method authorizeResource
  expose directory resourceType
  use strict arg principalIdArg, resourceRefArg, actionArg
  principalId = principalIdArg~string~strip
  resourceRef = resourceRefArg~string
  action = actionArg~string~strip~upper
  if principalId = "" then return self~denied("PRINCIPAL_REQUIRED", principalId, 0, "", 0, resourceRef, action)
  if resourceRef = "" then return self~denied("RESOURCE_REQUIRED", principalId, 0, "", 0, resourceRef, action)
  if action = "" then return self~denied("ACTION_REQUIRED", principalId, 0, "", 0, resourceRef, action)

  principal = directory~entryById(principalId)
  if principal = .nil then return self~denied("NO_SUCH_PRINCIPAL", principalId, 0, "", 0, resourceRef, action)
  if principal~kind <> "PRINCIPAL" then return self~denied("NO_SUCH_PRINCIPAL", principalId, principal~revision, "", 0, resourceRef, action)
  if principal~state <> "ACTIVE" then return self~denied("PRINCIPAL_NOT_ACTIVE", principalId, principal~revision, "", 0, resourceRef, action)

  resource = self~resourceByRef(resourceRef)
  if resource = .nil then return self~denied("NO_SUCH_RESOURCE", principalId, principal~revision, "", 0, resourceRef, action)
  if resource~state <> "ACTIVE" then return self~denied("RESOURCE_NOT_ACTIVE", principalId, principal~revision, resource~entityId, resource~revision, resourceRef, action)

  decision = directory~aclDecision(principalId, resource~entityId, action)
  if \decision~ok then return self~denied(decision~code, principalId, principal~revision, resource~entityId, resource~revision, resourceRef, action)
  return .RexxOSGridAuthorizationEvidence~new(.true, "ACL_ALLOW", principalId, principal~revision, resource~entityId, resource~revision, resourceRef, directory~revision, action)

::method resourceByRef
  expose directory resourceType
  use strict arg resourceRef
  do resource over directory~entriesOfKind("RESOURCE")
    if resource~resourceType <> resourceType then iterate
    if resource~resourceRef = resourceRef then return resource
  end
  return .nil

::method denied
  expose directory
  use strict arg code, principalId, principalRevision, resourceId, resourceRevision, resourceRef, action
  return .RexxOSGridAuthorizationEvidence~new(.false, code, principalId, principalRevision, resourceId, resourceRevision, resourceRef, directory~revision, action)
