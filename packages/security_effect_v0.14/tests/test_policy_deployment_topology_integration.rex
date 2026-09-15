now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)

profile = .InstitutionalPolicyAuthorityProfile~new('SEC-TOPOLOGY-GOV','1.0',start,.nil)
call addGrant profile,'S-AUTH','SECURITY_TEAM','AUTHOR','SECURITY-POLICY-CORE',start
call addGrant profile,'S-APP','RISK_COMMITTEE','APPROVER','SECURITY-POLICY-CORE',start
call addGrant profile,'S-PUB','SECURITY_RELEASE','PUBLISHER','SECURITY-POLICY-CORE',start
call addGrant profile,'S-DEP','PLATFORM_RELEASE','DEPLOY','SECURITY-POLICY-CORE',start
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('SEC-TOPOLOGY-RULE','SECURITY-POLICY-CORE',.true,'OPTIONAL')~seal)
ignored = profile~seal

pubEval = .InstitutionalPolicyAuthorityEvaluator~new(profile)
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .SecurityPolicyCatalog~new(.nil,.nil,pubEval,.nil,deployEval)
policy = .SecurityTestSupport~basePolicy(now)
policyIdentityBefore = policy~semanticIdentity
pubReq = .InstitutionalPolicyPublicationRequest~new(policy,'SECURITY_RELEASE',now)
call assertTrue catalog~publish(policy,pubReq)~ok,'security policy published before topology assignment'

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
kzWebScope = .InstitutionalPolicyDeploymentScope~new('KZ-WEB','COMMERCE','KZ','WEB')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('KZ-WEB-PILOT','COMMERCE','KZ','WEB','*','PILOT')~seal

call deploy catalog,policy,'SEC-DEP-1',globalScope,'ACTIVE',now,'ordinary production surfaces','REL-700'
call deploy catalog,policy,'SEC-DEP-2',kzWebScope,'STAGED',now,'new security deployment staged on Kazakhstan web','REL-701'
call deploy catalog,policy,'SEC-DEP-3',pilotScope,'CANARY',now,'pilot cohort receives canary','REL-702'

call assertEqual policyIdentityBefore,policy~semanticIdentity,'deployment topology does not mutate security policy semantic identity'

subject = 'CUSTOMER-TOPOLOGY'
module = .SecurityEffectRuntimeModule~new(catalog,.nil,'SECURITY-POLICY-CORE')
call assertTrue module~runtimeStart~ok,'runtime starts with topology-aware catalogue'
call assertTrue module~evidenceStore~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'security evidence stored independently of deployment topology'

londonWeb = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
kzWeb = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','GENERAL')
kzPilot = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','PILOT')
kzShannon = .InstitutionalPolicyDeploymentPoint~new('OURLADYAIR','KZ','SHANNON','RETAIL','GENERAL')

london = module~assess(makeGold('A-TOP-1',subject,now),londonWeb)
call assertTrue london~ok,'global active security deployment evaluates London web'
call assertEqual 'HOLD',london~value~disposition,'same gold policy still holds high-consequence action'

staged = module~assess(makeGold('A-TOP-2',subject,now),kzWeb)
call assertTrue \staged~ok,'staged regional security deployment does not execute'
call assertEqual 'POLICY_STAGED',staged~code,'runtime exposes staged topology state rather than inventing security result'

pilot = module~assess(makeGold('A-TOP-3',subject,now),kzPilot)
call assertTrue pilot~ok,'more-specific canary policy executes for pilot cohort'
call assertEqual 'HOLD',pilot~value~disposition,'canary uses exact same deterministic security policy'
pilotState = catalog~topologyState(policy~policyId,policy~version,kzPilot,now)~value
call assertEqual 'CANARY',pilotState~mode,'runtime deployment evidence remains explicitly canary'
call assertEqual 'SEC-DEP-3',pilotState~binding~deploymentId,'pilot chooses exact more-specific canary binding'

shannon = module~assess(makeRead('A-TOP-4',subject,now),kzShannon)
call assertTrue shannon~ok,'Shannon surface remains available under broad active binding'
call assertEqual 'ALLOW',shannon~value~disposition,'unrelated low-risk customer-service action remains allowed'

missingContext = module~assess(makeGold('A-TOP-5',subject,now))
call assertTrue \missingContext~ok,'topology-configured runtime cannot be bypassed by omitting deployment point'
call assertEqual 'DEPLOYMENT_POINT_REQUIRED',missingContext~code,'missing deployment context fails closed once topology exists'

snap = module~evidenceStore~snapshotFor(subject,now)
replayer = .SecurityPolicyReplayEngine~new
stagedReplay = replayer~replayPublished(makeGold('A-TOP-R1',subject,now),snap,catalog,policy~policyId,kzWeb)
call assertTrue \stagedReplay~ok,'historical replay honours scoped staged deployment'
call assertEqual 'POLICY_STAGED',stagedReplay~code,'replay cannot bypass topology evidence'
pilotReplay = replayer~replayPublished(makeGold('A-TOP-R2',subject,now),snap,catalog,policy~policyId,kzPilot)
call assertTrue pilotReplay~ok,'historical replay can execute exact canary deployment'
call assertEqual 'HOLD',pilotReplay~value~disposition,'canary replay deterministic'

call assertTrue module~runtimeStop~ok,'runtime stops'
say 'PASS test_policy_deployment_topology_integration'
exit 0

deploy: procedure
  use arg catalog,policy,id,scope,mode,when,reason,evidence
  req = .InstitutionalPolicyDeploymentRequest~new(id,policy,'PLATFORM_RELEASE',scope,mode,when,.nil,reason,evidence,when)
  result = catalog~applyDeployment(policy~policyId,policy~version,req)
  if result~ok = .false then do
    say 'FAIL: deployment' id 'code='result~code 'detail='result~detail
    exit 1
  end
  return
makeGold: procedure
  use arg id,subject,when
  a = .SecurityActionSurface~new(id,subject,'PURCHASE',when,'HIGH','PAYMENT')
  a~putAttribute('PAYMENT_INSTRUMENT','STORED')
  a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
  a~putAttribute('AMOUNT',22000)
  return a~seal
makeRead: procedure
  use arg id,subject,when
  return .SecurityActionSurface~new(id,subject,'VIEW_BOOKING',when,'LOW','CUSTOMER_SERVICE')~seal
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
