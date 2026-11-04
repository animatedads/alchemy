/* LDAP Identity-gated wrapper for the read-only RexxOS Grid service.
 *
 * RpcServiceCore context must contain principal_id that was attributed by an
 * approved authentication layer.  This wrapper asks Identity Directory ACL
 * authority for the exact service action before invoking the underlying Grid
 * endpoint.  It never performs Bind, transport selection or serialization.
 */
::class RexxOSGridAuthorizedServiceEndpoint public

::method init
  expose endpoint authorizer serviceName
  use strict arg endpointArg, authorizerArg
  endpoint = endpointArg
  authorizer = authorizerArg
  serviceName = endpoint~serviceName

::attribute serviceName get

::method registerWith
  expose serviceName
  use strict arg registry
  mapping = .Directory~new
  mapping["estate.capabilities"] = "rpcCapabilities"
  mapping["estate.snapshot"] = "rpcEstateSnapshot"
  mapping["estate.members"] = "rpcEstateMembers"
  mapping["estate.member"] = "rpcEstateMember"
  mapping["mu.list"] = "rpcManagementUnits"
  mapping["mu.describe"] = "rpcManagementUnit"
  mapping["management.capabilities"] = "rpcManagementCapabilities"
  registry~registerObject(serviceName, self, mapping)
  return self

::method rpcCapabilities
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.ESTATE.READ")
  if gate <> .nil then return gate
  return endpoint~rpcCapabilities(arguments, context)

::method rpcEstateSnapshot
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.ESTATE.READ")
  if gate <> .nil then return gate
  return endpoint~rpcEstateSnapshot(arguments, context)

::method rpcEstateMembers
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.ESTATE.READ")
  if gate <> .nil then return gate
  return endpoint~rpcEstateMembers(arguments, context)

::method rpcEstateMember
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.ESTATE.READ")
  if gate <> .nil then return gate
  return endpoint~rpcEstateMember(arguments, context)

::method rpcManagementUnits
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.ESTATE.READ")
  if gate <> .nil then return gate
  return endpoint~rpcManagementUnits(arguments, context)

::method rpcManagementUnit
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.ESTATE.READ")
  if gate <> .nil then return gate
  return endpoint~rpcManagementUnit(arguments, context)

::method rpcManagementCapabilities
  expose endpoint
  use strict arg arguments, context
  gate = self~gate(context, "GRID.MANAGEMENT.READ")
  if gate <> .nil then return gate
  return endpoint~rpcManagementCapabilities(arguments, context)

::method gate
  expose authorizer serviceName
  use strict arg context, action
  if context = .nil then return .RpcServiceFault~new("UNAUTHENTICATED", "attributed principal required")
  if \context~hasIndex("principal_id") then return .RpcServiceFault~new("UNAUTHENTICATED", "attributed principal required")
  principalId = context["principal_id"]
  if principalId = .nil | principalId~string~strip = "" then return .RpcServiceFault~new("UNAUTHENTICATED", "attributed principal required")
  evidence = authorizer~authorizeService(principalId, action, serviceName)
  if evidence~allowed then return .nil
  return .RpcServiceFault~new("PERMISSION_DENIED", evidence~code)

::requires "RexxOSGridServiceEndpoint.cls"
::requires "RexxOSGridIdentityAuthorization.cls"
::requires "RpcServiceCore.cls"
