now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
profile=.InstitutionalPolicyAuthorityProfile~new('SEC-DEMO-GOV','1.0',start,.nil)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('A','SECURITY_TEAM','AUTHOR','SECURITY-POLICY-CORE',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('P','RISK_COMMITTEE','APPROVER','SECURITY-POLICY-CORE',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('R','SECURITY_RELEASE','PUBLISHER','SECURITY-POLICY-CORE',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('S','SECURITY_DUTY','SUSPEND','SECURITY-POLICY-CORE',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('U','SECURITY_DUTY','RESUME','SECURITY-POLICY-CORE',start,.nil)~seal)
ignored=profile~addRule(.InstitutionalPolicyAuthorityRule~new('RULE','SECURITY-POLICY-CORE',.true,'OPTIONAL')~seal)
ignored=profile~seal
catalog=.SecurityPolicyCatalog~new(.nil,.nil,.InstitutionalPolicyAuthorityEvaluator~new(profile),.InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile))
policy=.SecurityTestSupport~basePolicy(now)
pubRequest=.InstitutionalPolicyPublicationRequest~new(policy,'SECURITY_RELEASE',now)
ignored=catalog~publish(policy,pubRequest)
subject='DEMO-CUSTOMER'
store=.SecurityEvidenceStore~new
finding=.SecurityTestSupport~geoFinding(subject,now)
ignored=store~recordFinding(finding)
engine=.SecurityEffectEngine~new
a=.SecurityActionSurface~new('D-A1',subject,'PURCHASE',now,'HIGH','PAYMENT')
a~putAttribute('PAYMENT_INSTRUMENT','STORED'); a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET'); a~putAttribute('AMOUNT',22000); a~seal
say 'before suspension:' engine~evaluate(a,store~snapshotFor(subject,now),catalog~resolve(policy~policyId,now)~value)~value~disposition
s=now+.InstitutionalPolicyTime~seconds(10)
req1=.InstitutionalPolicyLifecycleRequest~new('SD1','SUSPEND',policy,'SECURITY_DUTY',s,'policy review','INC-9')
ignored=catalog~applyLifecycle(policy~policyId,policy~version,req1)
say 'during suspension:' catalog~resolve(policy~policyId,s)~code
u=now+.InstitutionalPolicyTime~seconds(20)
req2=.InstitutionalPolicyLifecycleRequest~new('SD2','RESUME',policy,'SECURITY_DUTY',u,'review cleared','INC-9')
ignored=catalog~applyLifecycle(policy~policyId,policy~version,req2)
say 'after resume:' catalog~resolve(policy~policyId,u)~code
::requires 'TestSupport.cls'
