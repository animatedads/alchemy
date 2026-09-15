now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
expiry = now + .InstitutionalPolicyTime~seconds(1800)
profile = .InstitutionalPolicyAuthorityProfile~new('EMERGENCY-GOVERNANCE','1.0',start,.nil)
call addGrant profile,'E-AUTH','SECURITY_AUTHOR','AUTHOR','EMERGENCY-POLICY',start,'GENERAL'
call addGrant profile,'E-APP','SECURITY_APPROVER','APPROVER','EMERGENCY-POLICY',start,'GENERAL'
call addGrant profile,'E-BREAK','ON_CALL_DIRECTOR','EMERGENCY_PUBLISHER','EMERGENCY-POLICY',start,'EMERGENCY'
call addGrant profile,'E-RATIFY','RISK_CHAIR','RATIFY','EMERGENCY-POLICY',start,'GENERAL'
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('E-RULE','EMERGENCY-POLICY',.true,'OPTIONAL',.true,3600)~seal)
ignored = profile~seal
policy = .InstitutionalPolicyRelease~new('EMERGENCY-POLICY','1.0',now,expiry,'SECURITY_AUTHOR','SECURITY_APPROVER','',.nil,'EMERGENCY-PAYLOAD')~seal
pubEval = .InstitutionalPolicyAuthorityEvaluator~new(profile)
lifeEval = .InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,pubEval,lifeEval)
request = .InstitutionalPolicyPublicationRequest~new(policy,'ON_CALL_DIRECTOR',now,.true,'active exploit containment',expiry)
call assertTrue catalog~publish(policy,request)~ok,'bounded emergency policy published'
record = catalog~publicationRecord(policy~policyId,policy~version)~value
call assertTrue record~emergency,'publication record says emergency path used'
call assertEqual 'active exploit containment',record~emergencyReason,'emergency reason preserved as publication evidence'
call assertEqual expiry,record~emergencyExpiresAt,'emergency expiry preserved as publication evidence'
state0 = catalog~deploymentState(policy~policyId,policy~version,now)~value
call assertTrue \state0~ratified,'emergency publication begins unratified'
ratifyAt = now + .InstitutionalPolicyTime~seconds(300)
ratify = .InstitutionalPolicyLifecycleRequest~new('ER-001','RATIFY',policy,'RISK_CHAIR',ratifyAt,'normal authority reviewed emergency action','CAB-EM-44')
r = catalog~applyLifecycle(policy~policyId,policy~version,ratify)
call assertTrue r~ok,'normal authority ratifies emergency publication'
state1 = catalog~deploymentState(policy~policyId,policy~version,ratifyAt)~value
call assertTrue state1~ratified,'ratification becomes durable deployment evidence'
call assertEqual 'E-RATIFY',r~value~authorityDecision~grantId,'ratification records exact authority grant'
call assertTrue catalog~resolve(policy~policyId,ratifyAt)~ok,'ratified emergency policy still operative inside fixed window'
after = catalog~resolve(policy~policyId,expiry + .InstitutionalPolicyTime~seconds(1))
call assertTrue \after~ok,'ratification does not extend semantic policy lifetime'
call assertEqual 'POLICY_NOT_EFFECTIVE',after~code,'continuation requires a new normally governed policy release'
say 'PASS test_emergency_ratification_lifecycle'
exit 0
addGrant: procedure
  use arg profile,id,principal,action,policyId,start,class
  ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(id,principal,action,policyId,start,.nil,'POLICY_BOARD','AUTH:' || id,class)~seal)
  return
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
