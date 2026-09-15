now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
endAt=now+.InstitutionalPolicyTime~seconds(1800)
profile=.InstitutionalPolicyAuthorityProfile~new('SEC-EM-RATIFY','1.0',start,.nil)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('EA','INCIDENT-TEAM','AUTHOR','SECURITY-INCIDENT-R',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('ER','DUTY-RISK','APPROVER','SECURITY-INCIDENT-R',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('EP','INCIDENT-COMMANDER','EMERGENCY_PUBLISHER','SECURITY-INCIDENT-R',start,.nil,'BOARD','BREAKGLASS','EMERGENCY')~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('RR','RISK-CHAIR','RATIFY','SECURITY-INCIDENT-R',start,.nil,'BOARD','RATIFY')~seal)
ignored=profile~addRule(.InstitutionalPolicyAuthorityRule~new('BREAKGLASS-R','SECURITY-INCIDENT-R',.true,'OPTIONAL',.true,3600)~seal)
ignored=profile~seal
framework=.SecurityPolicyFramework~new('SECURITY-INCIDENT-R','E1',now,endAt,'INCIDENT-TEAM','DUTY-RISK','')
ignored=framework~addRule(.SecurityPolicyRule~new('TEMP-HOLD',1,'PRIVILEGED_MUTATION','HOLD','temporary exploit containment')~seal)
ignored=framework~seal
pubEval=.InstitutionalPolicyAuthorityEvaluator~new(profile)
lifeEval=.InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile)
catalog=.SecurityPolicyCatalog~new(.nil,.nil,pubEval,lifeEval)
request=.InstitutionalPolicyPublicationRequest~new(framework,'INCIDENT-COMMANDER',now,.true,'active exploit containment',endAt)
call assertTrue catalog~publish(framework,request)~ok,'emergency security policy published'
record=catalog~publicationRecord(framework~policyId,framework~version)~value
call assertTrue record~emergency,'security publication record retains emergency status'
call assertEqual 'active exploit containment',record~emergencyReason,'security publication retains break-glass reason'
ratifyAt=now+.InstitutionalPolicyTime~seconds(300)
ratify=.InstitutionalPolicyLifecycleRequest~new('SEC-RAT-1','RATIFY',framework,'RISK-CHAIR',ratifyAt,'normal risk authority reviewed incident policy','CAB-SEC-EM-1')
r=catalog~applyLifecycle(framework~policyId,framework~version,ratify)
call assertTrue r~ok,'emergency security policy can be ratified through ordinary authority evidence'
call assertEqual 'RR',r~value~authorityDecision~grantId,'exact ratifier grant retained'
state=catalog~deploymentState(framework~policyId,framework~version,ratifyAt)~value
call assertTrue state~ratified,'ratification visible in deployment state'
after=catalog~resolve(framework~policyId,endAt+.InstitutionalPolicyTime~seconds(1))
call assertTrue \after~ok,'ratification does not turn bounded emergency policy into permanent policy'
call assertEqual 'POLICY_NOT_EFFECTIVE',after~code,'new normal release required after emergency expiry'
say 'PASS test_policy_emergency_ratification_integration'
exit 0
assertTrue: procedure
 use arg v,l
 if v=.false then do; say 'FAIL:' l; exit 1; end
 return
assertEqual: procedure
 use arg e,a,l
 if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
 return
::requires 'SecurityEffect.cls'
