/* ooRexx r13196: fail-closed LDAP Identity authorization over explicit RpcServiceCore registry */
d = .IdentityDirectory~new("TEST-DIRECTORY")
r = d~createPrincipal("operator-1","uid=operator-1,ou=people,dc=example","PERSON","Operator One","operator1")
call assert r~ok, "principal"
r = d~createResource("grid-service","cn=grid-service,ou=resources,dc=example","REXXOS_GRID","rexxos://GRID-TEST/service/rexxos.grid/0.1","Grid read")
call assert r~ok, "resource"
r = d~createAclGrant("grid-read","cn=grid-read,ou=acl,dc=example","operator-1","grid-service","GRID.ESTATE.READ","ALLOW")
call assert r~ok, "grant"
e = .MockGridReadEndpoint~new
outer = .RexxOSGridAuthorizedServiceEndpoint~new(e,.RexxOSGridIdentityAuthorization~new(d,"GRID-TEST"))
registry = .RpcServiceRegistry~new
outer~registerWith(registry)
registry~freeze
dispatcher = .RpcServiceDispatcher~new(registry)
arg = .Directory~new
ctx = .Directory~new
ctx["principal_id"]="operator-1"
call expectPass dispatcher~invoke("rexxos.grid/0.1","estate.snapshot",arg,ctx), "estate read"
call expectFault dispatcher~invoke("rexxos.grid/0.1","management.capabilities",arg,ctx), "PERMISSION_DENIED", "management"
call expectFault dispatcher~invoke("rexxos.grid/0.1","estate.snapshot",arg,.nil), "UNAUTHENTICATED", "nil context"
call expectFault dispatcher~invoke("rexxos.grid/0.1","estate.snapshot",arg,.Directory~new), "UNAUTHENTICATED", "no principal"
call expectFault dispatcher~invoke("rexxos.grid/0.1","estate.snapshot",arg,"malformed"), "UNAUTHENTICATED", "wrong context type"
call expectFault dispatcher~invoke("rexxos.grid/0.1","mutate",arg,ctx), "NOT_FOUND", "unpublished method"
r = d~updatePrincipal("operator-1",.nil,.nil,"DISABLED")
call assert r~ok, "disable principal"
call expectFault dispatcher~invoke("rexxos.grid/0.1","estate.snapshot",arg,ctx), "PERMISSION_DENIED", "disabled"
call assert e~calls = 1, "only authorised invocation reached endpoint"
say "PASS Grid LDAP identity-gated RPC method dispatch and malformed-context rejection"
exit 0

assert:
  use arg condition, label
  if \condition then do; say "FAIL" label; exit 1; end
  return
expectPass:
  use arg reply, label
  call assert reply~ok, label
  call assert reply~value = "MOCK-ESTATE-READ", label || " payload"
  return
expectFault:
  use arg reply, code, label
  call assert \reply~ok, label || " denied"
  call assert reply~fault~code = code, label || " code"
  return

::class MockGridReadEndpoint
::attribute calls get
::method init
  expose calls
  calls = 0
::method serviceName
  return "rexxos.grid/0.1"
::method rpcCapabilities
  use strict arg args, context
  return self~allowed
::method rpcEstateSnapshot
  use strict arg args, context
  return self~allowed
::method rpcEstateMembers
  use strict arg args, context
  return self~allowed
::method rpcEstateMember
  use strict arg args, context
  return self~allowed
::method rpcManagementUnits
  use strict arg args, context
  return self~allowed
::method rpcManagementUnit
  use strict arg args, context
  return self~allowed
::method rpcManagementCapabilities
  use strict arg args, context
  return self~allowed
::method allowed
  expose calls
  calls = calls + 1
  return "MOCK-ESTATE-READ"

::requires "RexxOSGridAuthorizedServiceEndpoint.cls"
::requires "IdentityDirectory.cls"
::requires "RpcServiceCore.cls"
