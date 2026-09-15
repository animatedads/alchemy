/* Federation regulated intermediary Wire UI access/permission authority v0.7. */
::class RIDWireSecurityBuild public
::constant VERSION "0.7"
::constant API_VERSION "regulated.intermediary.wire-security/0.1"
::constant DOMAIN_ID "FEDERATION_RID_INTERMEDIARY"

/* Access Control is the coarse domain-entry gate.  Permission is evaluated
 * separately for every semantic action against its exact RID object. */
::class RIDWireSecurityContext public
::attribute principalId get
::attribute roleName get
::attribute accessEnvelope get
::attribute lastPermissionEnvelope get
::method init
  expose principalId roleName accessAuthority accessPolicy permissionAuthority permissionPreviewAuthority permissionPolicy securityFramework securitySnapshot accessEnvelope lastPermissionEnvelope requestSequence
  use arg principalIdArg,roleNameArg,accessAuthorityArg,accessPolicyArg,permissionAuthorityArg,permissionPolicyArg,securityFrameworkArg,securitySnapshotArg
  principalId=.RIDCanonical~required("principalId",principalIdArg)~upper
  roleName=.RIDCanonical~required("roleName",roleNameArg)~upper
  accessAuthority=accessAuthorityArg; accessPolicy=accessPolicyArg; permissionAuthority=permissionAuthorityArg; permissionPreviewAuthority=.PermissionAuthority~new; permissionPolicy=permissionPolicyArg; securityFramework=securityFrameworkArg; securitySnapshot=securitySnapshotArg
  accessEnvelope=.nil; lastPermissionEnvelope=.nil; requestSequence=0

::method enter
  expose principalId accessAuthority accessPolicy accessEnvelope requestSequence
  use arg entryPoint="WEB",atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  requestSequence+=1
  req=.AccessControlRequest~new("RID-ACCESS-"||requestSequence,principalId,.RIDWireSecurityBuild~DOMAIN_ID,entryPoint,atTime)~seal
  r=accessAuthority~decide(req,accessPolicy)
  if \r~ok then return .RIDResult~failure(r~code,r~detail)
  env=r~value
  if \env~decision~allowed then return .RIDResult~failure("RID_ACCESS_CONTROL_DENIED",env~decision~code,env)
  accessEnvelope=env
  return .RIDResult~success(env,"RID_ACCESS_CONTROL_ALLOWED")

::method permit
  expose principalId permissionAuthority permissionPolicy securityFramework securitySnapshot accessEnvelope lastPermissionEnvelope requestSequence
  use arg objectId,objectClass,methodName,atTime=.nil
  if accessEnvelope==.nil then return .RIDResult~failure("RID_ACCESS_CONTROL_REQUIRED")
  if atTime==.nil then atTime=.DateTime~new
  objectId=.RIDCanonical~required("objectId",objectId)~upper
  objectClass=.RIDCanonical~required("objectClass",objectClass)~upper
  methodName=.RIDCanonical~required("methodName",methodName)~upper
  requestSequence+=1
  action=.SecurityActionSurface~new("RID-SECURITY-ACTION-"||requestSequence,principalId,"METHOD_INVOCATION",atTime,"NORMAL",methodName)
  action~putAttribute("OBJECT_ID",objectId)
  action~putAttribute("METHOD",methodName)
  assessment=.SecurityEffectEngine~new~evaluate(action~seal,securitySnapshot,securityFramework)
  if \assessment~ok then return .RIDResult~failure("RID_SECURITY_EFFECT_FAILED",assessment~code)
  preq=.PermissionRequest~new("RID-PERMISSION-"||requestSequence,principalId,objectId,objectClass,methodName,atTime)
  if \preq~bindSecurityAssessment(assessment~value) then return .RIDResult~failure("RID_PERMISSION_SECURITY_BIND_FAILED")
  preq~seal
  r=permissionAuthority~decide(preq,permissionPolicy)
  if \r~ok then return .RIDResult~failure(r~code,r~detail)
  env=r~value; lastPermissionEnvelope=env
  if \env~decision~allowed then return .RIDResult~failure("RID_PERMISSION_DENIED",env~decision~code,env)
  return .RIDResult~success(env,"RID_PERMISSION_ALLOWED")

::method preview
  expose principalId permissionPreviewAuthority permissionPolicy securityFramework securitySnapshot accessEnvelope requestSequence
  use arg objectId,objectClass,methodName,atTime=.nil
  if accessEnvelope==.nil then return .RIDResult~failure("RID_ACCESS_CONTROL_REQUIRED")
  if atTime==.nil then atTime=.DateTime~new
  objectId=.RIDCanonical~required("objectId",objectId)~upper; objectClass=.RIDCanonical~required("objectClass",objectClass)~upper; methodName=.RIDCanonical~required("methodName",methodName)~upper
  requestSequence+=1
  action=.SecurityActionSurface~new("RID-SECURITY-PREVIEW-"||requestSequence,principalId,"METHOD_INVOCATION",atTime,"NORMAL",methodName)
  action~putAttribute("OBJECT_ID",objectId); action~putAttribute("METHOD",methodName)
  assessment=.SecurityEffectEngine~new~evaluate(action~seal,securitySnapshot,securityFramework); if \assessment~ok then return .RIDResult~failure("RID_SECURITY_EFFECT_FAILED",assessment~code)
  preq=.PermissionRequest~new("RID-PREVIEW-"||requestSequence,principalId,objectId,objectClass,methodName,atTime); if \preq~bindSecurityAssessment(assessment~value) then return .RIDResult~failure("RID_PERMISSION_SECURITY_BIND_FAILED"); preq~seal
  r=permissionPreviewAuthority~decide(preq,permissionPolicy); if \r~ok then return .RIDResult~failure(r~code,r~detail); env=r~value
  if \env~decision~allowed then return .RIDResult~failure("RID_PERMISSION_DENIED",env~decision~code,env)
  return .RIDResult~success(env,"RID_PERMISSION_ALLOWED")

::method accessDecisionRef
  expose accessEnvelope
  if accessEnvelope==.nil then return ""
  if accessEnvelope~proved then return accessEnvelope~proof~algorithm||":"||accessEnvelope~proof~keyId||":"||accessEnvelope~proof~tag
  return accessEnvelope~decision~code

::method permissionDecisionRef
  expose lastPermissionEnvelope
  if lastPermissionEnvelope==.nil then return ""
  if lastPermissionEnvelope~proved then return lastPermissionEnvelope~proof~algorithm||":"||lastPermissionEnvelope~proof~keyId||":"||lastPermissionEnvelope~proof~tag
  return lastPermissionEnvelope~decision~code

::requires "RegulatedIntermediaryDistribution.cls"
::requires "AccessPermissions.cls"
::requires "SecurityEffect.cls"
::requires "Crypto.cls"
