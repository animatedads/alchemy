now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(3600)
profile = .InstitutionalPolicyAuthorityProfile~new('SEC-DEMO-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-DEPLOY','RELEASE','DEPLOY','SECURITY-POLICY-CORE',start,.nil,'BOARD','AUTH:DEPLOY')~seal)
ignored = profile~seal
catalog = .SecurityPolicyCatalog~new(.nil,.nil,.nil,.nil,.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile))
v1 = makePolicy('1.0',start,'HOLD','')
v2 = makePolicy('2.0',rolloutStart,'REVIEW_REQUIRED','1.0')
ignored = catalog~publish(v1)
ignored = catalog~publish(v2,.nil,.InstitutionalPolicyProgressiveRequest~new('SEC-ROLLOUT',v1,v2,'RELEASE',rolloutEnd,'canary successor','CHG-1',now))
globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('PILOT','COMMERCE','GB','WEB','*','PILOT')~seal
ignored = catalog~applyDeployment(v2~policyId,v2~version,.InstitutionalPolicyDeploymentRequest~new('V2-STAGE',v2,'RELEASE',globalScope,'STAGED',rolloutStart,.nil,'stage successor','CHG-2',now))
ignored = catalog~applyDeployment(v2~policyId,v2~version,.InstitutionalPolicyDeploymentRequest~new('V2-CANARY',v2,'RELEASE',pilotScope,'CANARY',rolloutStart,.nil,'pilot successor','CHG-3',now))
ordinary = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
pilot = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','PILOT')
at = rolloutStart + .InstitutionalPolicyTime~seconds(5)
say 'ordinary policy:' catalog~resolveForContext('SECURITY-POLICY-CORE',ordinary,at)~value~version
say 'pilot policy:' catalog~resolveForContext('SECURITY-POLICY-CORE',pilot,at)~value~version
exit 0
makePolicy: procedure
  use arg version,effectiveFrom,disposition,supersedes
  p=.SecurityPolicyFramework~new('SECURITY-POLICY-CORE',version,effectiveFrom,.nil,'SECURITY_TEAM','RISK_COMMITTEE',supersedes)
  r=.SecurityPolicyRule~new('PAY-031',100,'PURCHASE',disposition,'demo')
  r~requireFinding('GEO_CONTINUITY_ANOMALY')
  ignored=p~addRule(r~seal)
  return p~seal
::requires 'SecurityEffect.cls'
