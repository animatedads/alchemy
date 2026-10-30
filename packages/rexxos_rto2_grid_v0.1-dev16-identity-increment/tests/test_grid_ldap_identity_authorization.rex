/* Contract test for the RexxOS Grid / Identity Directory seam.
 * Requires dev15 Grid classes, LDAP Identity dev22 and RpcServiceCore on REXX_PATH.
 */
call addRequire "RexxOSGridIdentityAuthorization.cls"
call addRequire "IdentityDirectory.cls"

directory = .IdentityDirectory~new("TEST-DIRECTORY")
op = directory~createPrincipal("operator-1", "uid=operator-1,ou=people,dc=example", "PERSON", "Operator One", "operator1")
call assert op~ok, "principal creation"
resourceRef = "rexxos://REXXOS-GRID-1/service/rexxos.grid/0.1"
op = directory~createResource("grid-service", "cn=grid-service,ou=resources,dc=example", "REXXOS_GRID", resourceRef, "RexxOS Grid service")
call assert op~ok, "resource creation"
op = directory~createAclGrant("grid-read", "cn=grid-read,ou=acl,dc=example", "operator-1", "grid-service", "GRID.ESTATE.READ", "ALLOW")
call assert op~ok, "ACL creation"

authorizer = .RexxOSGridIdentityAuthorization~new(directory, "REXXOS-GRID-1")
allowed = authorizer~authorizeService("operator-1", "GRID.ESTATE.READ")
call assert allowed~allowed, "allowed principal"
call assert allowed~resourceRef = resourceRef, "resource identity preserved"
call assert allowed~directoryRevision = directory~revision, "directory revision fenced"

denied = authorizer~authorizeService("operator-1", "GRID.MANAGEMENT.READ")
call assert \denied~allowed, "ungranted action denied"
call assert denied~code = "ACL_DEFAULT_DENY", "default deny preserved"

op = directory~updatePrincipal("operator-1", .nil, .nil, "DISABLED")
call assert op~ok, "principal disabled"
disabled = authorizer~authorizeService("operator-1", "GRID.ESTATE.READ")
call assert \disabled~allowed, "disabled principal denied"
call assert disabled~code = "PRINCIPAL_NOT_ACTIVE", "disabled state preserved"

say "PASS RexxOS Grid consumes Identity Directory principal and ACL authority without conflating authentication or Grid authority"
exit 0

addRequire:
  use arg file
  interpret '::requires "' || file || '"'
  return

assert:
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return
