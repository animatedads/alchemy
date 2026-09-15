now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
profile = .InstitutionalPolicyAuthorityProfile~new('SEC-OPS-GOV','1.0',start,.nil)
call addGrant profile,'S-AUTH','SECURITY_TEAM','AUTHOR','SECURITY-POLICY-CORE',start
call addGrant profile,'S-APP','RISK_COMMITTEE','APPROVER','SECURITY-POLICY-CORE',start
call addGrant profile,'S-PUB','SECURITY_RELEASE','PUBLISHER','SECURITY-POLICY-CORE',start
call addGrant profile,'S-SUSP','SECURITY_DUTY','SUSPEND','SECURITY-POLICY-CORE',start
call addGrant profile,'S-RESUME','SECURITY_DUTY','RESUME','SECURITY-POLICY-CORE',start
call addGrant profile,'S-WITHDRAW','SECURITY_OWNER','WITHDRAW','SECURITY-POLICY-CORE',start
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('SEC-LC-RULE','SECURITY-POLICY-CORE',.true,'OPTIONAL')~seal)
ignored = profile~seal

pubEval = .InstitutionalPolicyAuthorityEvaluator~new(profile)
lifeEval = .InstitutionalPolicyLifecycleAuthorityEvaluator~new(profile)
catalog = .SecurityPolicyCatalog~new(.nil,.nil,pubEval,lifeEval)
policy = .SecurityTestSupport~basePolicy(now)
request = .InstitutionalPolicyPublicationRequest~new(policy,'SECURITY_RELEASE',now)
call assertTrue catalog~publish(policy,request)~ok,'security policy published with lifecycle governance'

subject = 'CUSTOMER-LIFECYCLE'
module = .SecurityEffectRuntimeModule~new(catalog,.nil,'SECURITY-POLICY-CORE')
call assertTrue module~runtimeStart~ok,'runtime starts'
call assertTrue module~evidenceStore~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'evidence stored independently of deployment state'
first = module~assess(makeGold('A-LC-1',subject,now))
call assertTrue first~ok,'operative policy evaluates before suspension'
call assertEqual 'HOLD',first~value~disposition,'gold hold still works'

suspendAt = now + .InstitutionalPolicyTime~seconds(10)
suspend = .InstitutionalPolicyLifecycleRequest~new('SEC-LC-1','SUSPEND',policy,'SECURITY_DUTY',suspendAt,'suspected policy defect','INC-SEC-14')
call assertTrue catalog~applyLifecycle(policy~policyId,policy~version,suspend)~ok,'security policy suspension recorded'
blocked = module~assess(makeGold('A-LC-2',subject,suspendAt + .InstitutionalPolicyTime~seconds(1)))
call assertTrue \blocked~ok,'runtime refuses suspended policy rather than evaluating stale authority'
call assertEqual 'POLICY_SUSPENDED',blocked~code,'runtime surfaces deployment suspension explicitly'
replayer = .SecurityPolicyReplayEngine~new
replayBlocked = replayer~replayPublished(makeGold('A-LC-R1',subject,suspendAt + .InstitutionalPolicyTime~seconds(1)), module~evidenceStore~snapshotFor(subject,suspendAt + .InstitutionalPolicyTime~seconds(1)), catalog, policy~policyId)
call assertTrue \replayBlocked~ok,'published historical replay obeys deployment suspension'
call assertEqual 'POLICY_SUSPENDED',replayBlocked~code,'replay does not bypass catalogue lifecycle evidence'

resumeAt = now + .InstitutionalPolicyTime~seconds(20)
resume = .InstitutionalPolicyLifecycleRequest~new('SEC-LC-2','RESUME',policy,'SECURITY_DUTY',resumeAt,'policy defect disproved','INC-SEC-14-CLEAR')
call assertTrue catalog~applyLifecycle(policy~policyId,policy~version,resume)~ok,'security policy resume recorded'
resumed = module~assess(makeGold('A-LC-3',subject,resumeAt + .InstitutionalPolicyTime~seconds(1)))
call assertTrue resumed~ok,'runtime resumes exact same immutable policy artefact'
call assertEqual 'HOLD',resumed~value~disposition,'customer-security reasoning unchanged by deployment lifecycle'

withdrawAt = now + .InstitutionalPolicyTime~seconds(30)
withdraw = .InstitutionalPolicyLifecycleRequest~new('SEC-LC-3','WITHDRAW',policy,'SECURITY_OWNER',withdrawAt,'policy withdrawn from service','RISK-SEC-21')
call assertTrue catalog~applyLifecycle(policy~policyId,policy~version,withdraw)~ok,'security policy withdrawal recorded'
ended = module~assess(makeGold('A-LC-4',subject,withdrawAt + .InstitutionalPolicyTime~seconds(1)))
call assertTrue \ended~ok,'withdrawn security policy cannot silently continue operating'
call assertEqual 'POLICY_WITHDRAWN',ended~code,'withdrawal explicit to runtime'
call assertTrue module~runtimeStop~ok,'runtime stops'

say 'PASS test_policy_deployment_lifecycle_integration'
exit 0
makeGold: procedure
  use arg id,subject,when
  a = .SecurityActionSurface~new(id,subject,'PURCHASE',when,'HIGH','PAYMENT')
  a~putAttribute('PAYMENT_INSTRUMENT','STORED')
  a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
  a~putAttribute('AMOUNT',22000)
  return a~seal
addGrant: procedure
  use arg profile,id,principal,action,policyId,start
  ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(id,principal,action,policyId,start,.nil,'SECURITY_BOARD','AUTH:' || id)~seal)
  return
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'SecurityEffectRuntimeModule.cls'
::requires 'TestSupport.cls'
