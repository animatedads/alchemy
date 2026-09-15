now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(3600)
profile = .InstitutionalPolicyAuthorityProfile~new('DEMO-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('DEPLOY-GRANT','RELEASE','DEPLOY','DEMO-POLICY',start,.nil,'BOARD','AUTH:DEPLOY')~seal)
ignored = profile~seal
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile))
v1 = .InstitutionalPolicyRelease~new('DEMO-POLICY','1.0',start,.nil,'AUTHOR','APPROVER','',.nil,'DEMO-V1')~seal
v2 = .InstitutionalPolicyRelease~new('DEMO-POLICY','2.0',rolloutStart,.nil,'AUTHOR','APPROVER','1.0',.nil,'DEMO-V2')~seal
ignored = catalog~publish(v1)
rollout = .InstitutionalPolicyProgressiveRequest~new('ROLLOUT-DEMO',v1,v2,'RELEASE',rolloutEnd,'bounded canary and cutover','CHG-DEMO',now)
ignored = catalog~publish(v2,.nil,rollout)
globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('PILOT','COMMERCE','GB','WEB','*','PILOT')~seal
ignored = catalog~applyDeployment(v2~policyId,v2~version,.InstitutionalPolicyDeploymentRequest~new('V2-STAGE',v2,'RELEASE',globalScope,'STAGED',rolloutStart,.nil,'stage successor','CHG-1',now))
ignored = catalog~applyDeployment(v2~policyId,v2~version,.InstitutionalPolicyDeploymentRequest~new('V2-CANARY',v2,'RELEASE',pilotScope,'CANARY',rolloutStart,.nil,'pilot successor','CHG-2',now))
ordinary = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
pilot = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','PILOT')
at = rolloutStart + .InstitutionalPolicyTime~seconds(5)
say 'ordinary version:' catalog~resolveForContext('DEMO-POLICY',ordinary,at)~value~version
say 'pilot version:' catalog~resolveForContext('DEMO-POLICY',pilot,at)~value~version
cut = rolloutStart + .InstitutionalPolicyTime~seconds(20)
ignored = catalog~applyDeployment(v2~policyId,v2~version,.InstitutionalPolicyDeploymentRequest~new('V2-ACTIVE',v2,'RELEASE',globalScope,'ACTIVE',cut,.nil,'cut over','CHG-3',now))
say 'after cutover:' catalog~resolveForContext('DEMO-POLICY',ordinary,cut + .InstitutionalPolicyTime~seconds(1))~value~version
rollback = cut + .InstitutionalPolicyTime~seconds(20)
ignored = catalog~applyDeployment(v1~policyId,v1~version,.InstitutionalPolicyDeploymentRequest~new('V1-ROLLBACK',v1,'RELEASE',globalScope,'ACTIVE',rollback,.nil,'rollback','INC-4',now))
say 'after rollback:' catalog~resolveForContext('DEMO-POLICY',ordinary,rollback + .InstitutionalPolicyTime~seconds(1))~value~version
::requires 'InstitutionalPolicy.cls'
