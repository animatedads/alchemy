now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
finish = now + .InstitutionalPolicyTime~seconds(7200)

profile = .InstitutionalPolicyAuthorityProfile~new('POLICY-DEPLOY-GOV','1.0',start,.nil)
call addGrant profile,'G-AUTH','POLICY_AUTHOR','AUTHOR','OPS-POLICY',start
call addGrant profile,'G-APP','POLICY_APPROVER','APPROVER','OPS-POLICY',start
call addGrant profile,'G-PUB','POLICY_RELEASE','PUBLISHER','OPS-POLICY',start
call addGrant profile,'G-DEP','PLATFORM_RELEASE','DEPLOY','OPS-POLICY',start
call addGrant profile,'G-SUSP','DUTY_MANAGER','SUSPEND','OPS-POLICY',start
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('OPS-RULE','OPS-POLICY',.true,'OPTIONAL')~seal)
ignored = profile~seal

policy = .InstitutionalPolicyRelease~new('OPS-POLICY','1.0',start,finish,'POLICY_AUTHOR','POLICY_APPROVER','',.nil,'OPS-PAYLOAD-TOPOLOGY')~seal
pubEval = .InstitutionalPolicyAuthorityEvaluator~new(profile)
lifeEval = .InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile)
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,pubEval,lifeEval,deployEval)
pubReq = .InstitutionalPolicyPublicationRequest~new(policy,'POLICY_RELEASE',now)
call assertTrue catalog~publish(policy,pubReq)~ok,'policy published independently of topology'

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
kzWebScope = .InstitutionalPolicyDeploymentScope~new('KZ-WEB','COMMERCE','KZ','WEB')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('KZ-WEB-PILOT','COMMERCE','KZ','WEB','*','PILOT')~seal

globalReq = .InstitutionalPolicyDeploymentRequest~new('DEP-001',policy,'PLATFORM_RELEASE',globalScope,'ACTIVE',now,.nil,'global production deployment','CHG-100',now)
call assertTrue catalog~applyDeployment(policy~policyId,policy~version,globalReq)~ok,'global active binding recorded'

stageReq = .InstitutionalPolicyDeploymentRequest~new('DEP-002',policy,'PLATFORM_RELEASE',kzWebScope,'STAGED',now,.nil,'stage Kazakhstan web surface','CHG-101',now)
call assertTrue catalog~applyDeployment(policy~policyId,policy~version,stageReq)~ok,'specific staged binding recorded'

canaryReq = .InstitutionalPolicyDeploymentRequest~new('DEP-003',policy,'PLATFORM_RELEASE',pilotScope,'CANARY',now,.nil,'pilot cohort canary','CHG-102',now)
canaryResult = catalog~applyDeployment(policy~policyId,policy~version,canaryReq)
call assertTrue canaryResult~ok,'more-specific canary binding recorded'
call assertEqual profile~semanticIdentity,canaryResult~value~authorityDecision~authorityProfileIdentity,'deployment snapshots exact governance profile'
call assertEqual 'G-DEP',canaryResult~value~authorityDecision~grantId,'deployment snapshots exact deploy authority grant'

londonWeb = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
kzWeb = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','GENERAL')
kzPilot = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','PILOT')
kzShannon = .InstitutionalPolicyDeploymentPoint~new('OURLADYAIR','KZ','SHANNON','RETAIL','GENERAL')

call assertTrue catalog~resolveForContext(policy~policyId,londonWeb,now)~ok,'broad active deployment serves London web'
staged = catalog~resolveForContext(policy~policyId,kzWeb,now)
call assertTrue \staged~ok,'specific staged deployment is not operative'
call assertEqual 'POLICY_STAGED',staged~code,'staged state explicit'

pilot = catalog~resolveForContext(policy~policyId,kzPilot,now)
call assertTrue pilot~ok,'more-specific canary is operative inside staged region'
pilotState = catalog~topologyState(policy~policyId,policy~version,kzPilot,now)~value
call assertEqual 'CANARY',pilotState~mode,'canary mode preserved as deployment evidence'
call assertEqual 'DEP-003',pilotState~binding~deploymentId,'most-specific deployment binding selected'

call assertTrue catalog~resolveForContext(policy~policyId,kzShannon,now)~ok,'unrelated Shannon surface remains on broad active deployment'
shannonState = catalog~topologyState(policy~policyId,policy~version,kzShannon,now)~value
call assertEqual 'ACTIVE',shannonState~mode,'unrelated surface active'
call assertEqual 'DEP-001',shannonState~binding~deploymentId,'global binding supplies unrelated surface'

missingPoint = catalog~resolveForContext(policy~policyId,.nil,now)
call assertTrue \missingPoint~ok,'topology-aware resolution requires explicit deployment point'
call assertEqual 'DEPLOYMENT_POINT_REQUIRED',missingPoint~code,'missing topology context cannot silently become global'

retro = .InstitutionalPolicyDeploymentRequest~new('DEP-RETRO',policy,'PLATFORM_RELEASE',kzWebScope,'ACTIVE',now - .InstitutionalPolicyTime~seconds(1),.nil,'attempt historical rewrite','BAD',now)
retroResult = catalog~applyDeployment(policy~policyId,policy~version,retro)
call assertTrue \retroResult~ok,'retroactive deployment binding rejected'
call assertEqual 'DEPLOYMENT_RETROACTIVE_NOT_ALLOWED',retroResult~code,'deployment history cannot be backdated'

badCanary = .InstitutionalPolicyDeploymentRequest~new('DEP-BAD-CANARY',policy,'PLATFORM_RELEASE',globalScope,'CANARY',now + .InstitutionalPolicyTime~seconds(10),.nil,'not actually a canary','BAD',now)
badCanaryResult = catalog~applyDeployment(policy~policyId,policy~version,badCanary)
call assertTrue \badCanaryResult~ok,'global canary declaration rejected'
call assertEqual 'CANARY_SCOPE_REQUIRED',badCanaryResult~code,'canary requires a bounded scope'

unauthorized = .InstitutionalPolicyDeploymentRequest~new('DEP-UNAUTH',policy,'RANDOM_USER',kzWebScope,'ACTIVE',now + .InstitutionalPolicyTime~seconds(20),.nil,'not entitled','BAD',now)
unauthResult = catalog~applyDeployment(policy~policyId,policy~version,unauthorized)
call assertTrue \unauthResult~ok,'unauthorized deployment rejected'
call assertEqual 'DEPLOYMENT_AUTHORITY_DENIED',unauthResult~code,'deployment authority denial explicit'

suspendAt = now + .InstitutionalPolicyTime~seconds(30)
suspendReq = .InstitutionalPolicyLifecycleRequest~new('LC-TOPOLOGY-SUSPEND','SUSPEND',policy,'DUTY_MANAGER',suspendAt,'global incident containment','INC-TOPOLOGY',now)
call assertTrue catalog~applyLifecycle(policy~policyId,policy~version,suspendReq)~ok,'global lifecycle suspension recorded'
pilotBlocked = catalog~resolveForContext(policy~policyId,kzPilot,suspendAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue \pilotBlocked~ok,'global lifecycle suspension vetoes even canary deployment'
call assertEqual 'POLICY_SUSPENDED',pilotBlocked~code,'global lifecycle remains stronger than topology'

call assertEqual 3,catalog~deploymentBindings(policy~policyId,policy~version)~items,'all accepted topology bindings retained immutably'

say 'PASS test_policy_deployment_topology'
exit 0

addGrant: procedure
  use arg profile,id,principal,action,policyId,start
  ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(id,principal,action,policyId,start,.nil,'POLICY_BOARD','AUTH:' || id)~seal)
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
