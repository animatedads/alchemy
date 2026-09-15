now = .DateTime~new
start = now - .TimeSpan~new(0,0,1,0,0)
finish = now + .TimeSpan~new(0,4,0,0,0)

profile = .InstitutionalPolicyAuthorityProfile~new('POLICY-GOVERNANCE','1.0',start,.nil)
call addGrant profile,'G-AUTH','POLICY_AUTHOR','AUTHOR','OPS-POLICY',start
call addGrant profile,'G-APP','POLICY_APPROVER','APPROVER','OPS-POLICY',start
call addGrant profile,'G-PUB','POLICY_RELEASE','PUBLISHER','OPS-POLICY',start
call addGrant profile,'G-SUSP','DUTY_MANAGER','SUSPEND','OPS-POLICY',start
call addGrant profile,'G-RESUME','DUTY_MANAGER','RESUME','OPS-POLICY',start
call addGrant profile,'G-WITHDRAW','RISK_OWNER','WITHDRAW','OPS-POLICY',start
call addGrant profile,'G-RATIFY','RISK_OWNER','RATIFY','OPS-POLICY',start
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('OPS-RULE','OPS-POLICY',.true,'OPTIONAL')~seal)
ignored = profile~seal

policy = .InstitutionalPolicyRelease~new('OPS-POLICY','1.0',start,finish,'POLICY_AUTHOR','POLICY_APPROVER','',.nil,'OPS-PAYLOAD-1')~seal
pubEval = .InstitutionalPolicyAuthorityEvaluator~new(profile)
lifeEval = .InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,pubEval,lifeEval)
request = .InstitutionalPolicyPublicationRequest~new(policy,'POLICY_RELEASE',now)
call assertTrue catalog~publish(policy,request)~ok,'policy published'
recordBefore = catalog~publicationRecord(policy~policyId,policy~version)~value~canonicalText
call assertTrue catalog~resolve(policy~policyId,now)~ok,'policy active before lifecycle event'

suspendAt = now + .InstitutionalPolicyTime~seconds(600)
sreq = .InstitutionalPolicyLifecycleRequest~new('LC-001','SUSPEND',policy,'DUTY_MANAGER',suspendAt,'incident containment','INC-77')
sres = catalog~applyLifecycle(policy~policyId,policy~version,sreq)
call assertTrue sres~ok,'authorized suspension recorded'
call assertEqual profile~semanticIdentity,sres~value~authorityDecision~authorityProfileIdentity,'suspension snapshots exact governance profile'
blocked = catalog~resolve(policy~policyId,suspendAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue \blocked~ok,'suspended policy does not resolve operative'
call assertEqual 'POLICY_SUSPENDED',blocked~code,'suspension has explicit resolution code'

resumeAt = now + .InstitutionalPolicyTime~seconds(1200)
rreq = .InstitutionalPolicyLifecycleRequest~new('LC-002','RESUME',policy,'DUTY_MANAGER',resumeAt,'incident cleared','INC-77-CLEAR')
call assertTrue catalog~applyLifecycle(policy~policyId,policy~version,rreq)~ok,'authorized resume recorded'
call assertTrue catalog~resolve(policy~policyId,resumeAt + .InstitutionalPolicyTime~seconds(1))~ok,'resumed policy resolves again'

withdrawAt = now + .InstitutionalPolicyTime~seconds(1800)
wreq = .InstitutionalPolicyLifecycleRequest~new('LC-003','WITHDRAW',policy,'RISK_OWNER',withdrawAt,'policy defect confirmed','RISK-91')
call assertTrue catalog~applyLifecycle(policy~policyId,policy~version,wreq)~ok,'authorized withdrawal recorded'
withdrawn = catalog~resolve(policy~policyId,withdrawAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue \withdrawn~ok,'withdrawn policy does not resolve'
call assertEqual 'POLICY_WITHDRAWN',withdrawn~code,'withdrawal is terminal deployment state'

lateResume = .InstitutionalPolicyLifecycleRequest~new('LC-004','RESUME',policy,'DUTY_MANAGER',withdrawAt + .InstitutionalPolicyTime~seconds(60),'attempted restart','INC-77')
late = catalog~applyLifecycle(policy~policyId,policy~version,lateResume)
call assertTrue \late~ok,'withdrawn policy cannot be resumed'
call assertEqual 'POLICY_ALREADY_WITHDRAWN',late~code,'withdrawal cannot be silently erased'

recordAfter = catalog~publicationRecord(policy~policyId,policy~version)~value~canonicalText
call assertEqual recordBefore,recordAfter,'deployment lifecycle never rewrites original publication evidence'
state = catalog~deploymentState(policy~policyId,policy~version,withdrawAt + .InstitutionalPolicyTime~seconds(2))~value
call assertEqual 'WITHDRAWN',state~state,'deployment state replays immutable lifecycle events'
call assertEqual 3,state~events~items,'three accepted lifecycle events retained'

unauthorized = .InstitutionalPolicyLifecycleRequest~new('LC-005','RATIFY',policy,'RANDOM_USER',now + .InstitutionalPolicyTime~seconds(100),'not entitled','NONE')
denied = catalog~applyLifecycle(policy~policyId,policy~version,unauthorized)
call assertTrue \denied~ok,'unauthorized lifecycle mutation rejected'
call assertEqual 'LIFECYCLE_AUTHORITY_DENIED',denied~code,'authority denial explicit'
retro = .InstitutionalPolicyLifecycleRequest~new('LC-006','RATIFY',policy,'RISK_OWNER',now - .InstitutionalPolicyTime~seconds(5),'attempted historical rewrite','NONE',now)
retroResult = catalog~applyLifecycle(policy~policyId,policy~version,retro)
call assertTrue \retroResult~ok,'retroactive lifecycle evidence rejected'
call assertEqual 'LIFECYCLE_RETROACTIVE_NOT_ALLOWED',retroResult~code,'historical deployment state cannot be rewritten through ordinary lifecycle API'

say 'PASS test_policy_deployment_lifecycle'
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
