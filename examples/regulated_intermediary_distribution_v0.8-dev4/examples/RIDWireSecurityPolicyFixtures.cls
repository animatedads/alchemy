/* Example policy set for RID Wire UI.  Roles shape policy, but are not authority. */
::class RIDWireSecurityPolicyFixtures public
::method context class
  use arg roleArg="ADVISER",principalArg="RID:ADVISER:REP-1",provePermissions=.false,allowEntry=.true
  role=roleArg~string~upper; principal=principalArg~string~upper; now=.DateTime~new
  ring=.CryptoMacKeyRing~new
  ring~addKey("rid-wire-decisions-1","00112233445566778899aabbccddeeff")
  signer=.AccessPermissionsSigner~new(ring,"rid-wire-decisions-1")
  accessAuthority=.AccessControlAuthority~new(signer)
  if provePermissions then permissionAuthority=.PermissionAuthority~new(signer)
  else permissionAuthority=.PermissionAuthority~new

  access=.AccessControlPolicy~new("RID-WIRE-ACCESS","1","DENY",now-.TimeSpan~new(0,0,0,0,1),.nil,"RID_SECURITY","RID_RISK")
  if allowEntry then access~addRule(.AccessControlRule~new("RID-ENTER-"||role,100,"ALLOW",principal,.RIDWireSecurityBuild~DOMAIN_ID,"*")~seal)
  access~seal

  permissions=.PermissionPolicy~new("RID-WIRE-PERMISSIONS-"||role,"1","DENY",now-.TimeSpan~new(0,0,0,0,1),.nil,"RID_SECURITY","RID_RISK")
  do method over .array~of("DASHBOARD.REFRESH","CASES.FILTER","CASES.SORT","CASES.SELECT")
    permissions~addRule(.PermissionRule~new("RID-"||role||"-"||method,100,"ALLOW",principal,"RID.WORKSPACE:*","RIDINTERMEDIARYWORKSPACE",method,"ALLOW","*")~seal)
  end
  permissions~addRule(.PermissionRule~new("RID-"||role||"-CASE.OPEN",100,"ALLOW",principal,"RID.CASE:*","RIDDISTRIBUTIONCASE","CASE.OPEN","ALLOW","*")~seal)
  if role="ADVISER" | role="COMPLIANCE" | role="ADMIN" then permissions~addRule(.PermissionRule~new("RID-"||role||"-WORK.ACK",100,"ALLOW",principal,"RID.WORK:*","RIDINTERMEDIARYWORK","WORK.ACK","ALLOW","*")~seal)
  if role="ADVISER" then do
    permissions~addRule(.PermissionRule~new("RID-ADVISER-SIGNATURE.PREPARE",100,"ALLOW",principal,"RID.WORK:*","RIDSIGNINGCEREMONY","SIGNATURE.PREPARE","ALLOW","*")~seal)
    permissions~addRule(.PermissionRule~new("RID-ADVISER-SIGNATURE.SUBMIT",100,"ALLOW",principal,"RID.WORK:*","RIDSIGNINGCEREMONY","SIGNATURE.SUBMIT","ALLOW","*")~seal)
  end
  permissions~seal

  framework=.SecurityPolicyFramework~new("RID-WIRE-SECURITY","1",now-.TimeSpan~new(0,0,0,0,1),.nil,"RID_SECURITY","RID_RISK")~seal
  snapshot=.SecuritySnapshot~new("RID-WIRE-SNAPSHOT:"||principal,principal,now)~seal
  return .RIDWireSecurityContext~new(principal,role,accessAuthority,access,permissionAuthority,permissions,framework,snapshot)

::requires "RIDWireAuthority.cls"
