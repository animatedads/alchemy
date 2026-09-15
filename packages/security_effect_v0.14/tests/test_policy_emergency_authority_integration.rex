now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
profile=.InstitutionalPolicyAuthorityProfile~new('SEC-EMERGENCY','1.0',start,.nil)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('EA','INCIDENT-TEAM','AUTHOR','SECURITY-INCIDENT',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('ER','DUTY-RISK','APPROVER','SECURITY-INCIDENT',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('EP','INCIDENT-COMMANDER','EMERGENCY_PUBLISHER','SECURITY-INCIDENT',start,.nil,'BOARD','BREAKGLASS','EMERGENCY')~seal)
authRule=.InstitutionalPolicyAuthorityRule~new('BREAKGLASS','SECURITY-INCIDENT',.true,'OPTIONAL',.true,7200)
ignored=profile~addRule(authRule~seal)
ignored=profile~seal
endAt=now+.InstitutionalPolicyTime~seconds(3600)
framework=.SecurityPolicyFramework~new('SECURITY-INCIDENT','E1',now,endAt,'INCIDENT-TEAM','DUTY-RISK','')
rule=.SecurityPolicyRule~new('ACTIVE-PROBE-HOLD',1,'PRIVILEGED_MUTATION','HOLD','temporary response to active exploit campaign')
ignored=rule~requireFinding('ACTIVE_EXPLOIT_PROBE')
ignored=framework~addRule(rule~seal)
ignored=framework~seal
request=.InstitutionalPolicyPublicationRequest~new(framework,'INCIDENT-COMMANDER',now,.true,'active exploit campaign',endAt)
evaluator=.InstitutionalPolicyAuthorityEvaluator~new(profile)
catalog=.SecurityPolicyCatalog~new(.nil,.nil,evaluator)
published=catalog~publish(framework,request)
call assertTrue published~ok,'bounded emergency security policy can be published by explicit break-glass authority'
record=catalog~publicationRecord(framework~policyId,framework~version)~value
call assertTrue record~authorityDecision~emergency,'publication evidence labels emergency path'
call assertEqual 'EP',record~authorityDecision~emergencyGrantId,'exact break-glass grant retained'
call assertEqual endAt,framework~effectiveUntil,'emergency policy is inherently time-bounded'

say 'PASS test_policy_emergency_authority_integration'
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
