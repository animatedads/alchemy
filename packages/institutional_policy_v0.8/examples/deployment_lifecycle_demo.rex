now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
profile=.InstitutionalPolicyAuthorityProfile~new('DEMO-GOV','1.0',start,.nil)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('A','AUTHOR','AUTHOR','DEMO-POLICY',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('P','APPROVER','APPROVER','DEMO-POLICY',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('R','RELEASE','PUBLISHER','DEMO-POLICY',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('S','DUTY','SUSPEND','DEMO-POLICY',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('U','DUTY','RESUME','DEMO-POLICY',start,.nil)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('W','OWNER','WITHDRAW','DEMO-POLICY',start,.nil)~seal)
ignored=profile~addRule(.InstitutionalPolicyAuthorityRule~new('RULE','DEMO-POLICY',.true,'OPTIONAL')~seal)
ignored=profile~seal
policy=.InstitutionalPolicyRelease~new('DEMO-POLICY','1.0',start,.nil,'AUTHOR','APPROVER','',.nil,'DEMO-PAYLOAD')~seal
catalog=.InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.InstitutionalPolicyAuthorityEvaluator~new(profile),.InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile))
pubRequest=.InstitutionalPolicyPublicationRequest~new(policy,'RELEASE',now)
ignored=catalog~publish(policy,pubRequest)
s1=now+.InstitutionalPolicyTime~seconds(10)
req1=.InstitutionalPolicyLifecycleRequest~new('D1','SUSPEND',policy,'DUTY',s1,'incident review','INC-1')
ignored=catalog~applyLifecycle(policy~policyId,policy~version,req1)
say 'after suspend:' catalog~deploymentState(policy~policyId,policy~version,s1)~value~state
s2=now+.InstitutionalPolicyTime~seconds(20)
req2=.InstitutionalPolicyLifecycleRequest~new('D2','RESUME',policy,'DUTY',s2,'review cleared','INC-1')
ignored=catalog~applyLifecycle(policy~policyId,policy~version,req2)
say 'after resume:' catalog~deploymentState(policy~policyId,policy~version,s2)~value~state
s3=now+.InstitutionalPolicyTime~seconds(30)
req3=.InstitutionalPolicyLifecycleRequest~new('D3','WITHDRAW',policy,'OWNER',s3,'policy retired','CHANGE-9')
ignored=catalog~applyLifecycle(policy~policyId,policy~version,req3)
say 'after withdraw:' catalog~deploymentState(policy~policyId,policy~version,s3)~value~state
say 'publication still:' catalog~publicationRecord(policy~policyId,policy~version)~value~policyIdentity
::requires 'InstitutionalPolicy.cls'
