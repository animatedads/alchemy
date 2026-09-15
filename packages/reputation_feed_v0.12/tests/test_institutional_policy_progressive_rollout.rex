now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(120)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(3600)
policyId = 'REPUTATION-FEED-GLOBAL'
actor = 'FEED_PLATFORM_RELEASE'

profile = .InstitutionalPolicyAuthorityProfile~new('RF-ROLLOUT-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('RF-ROLLOUT-GRANT',actor,'DEPLOY',policyId,start,.nil,'REPUTATION_BOARD','AUTH:RF-ROLLOUT-GRANT')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,deployEval)
bridge = .ReputationFeedInstitutionalPolicyBridge~new(policyId)

v1Set = makePolicySet('NORMAL',2,70)~seal
v2Set = makePolicySet('HEIGHTENED',3,85)~seal
v1 = bridge~newRelease('1.0',v1Set,start,.nil,'FEED_AUTHOR','REPUTATION_BOARD','')
v2 = bridge~newRelease('2.0',v2Set,rolloutStart,.nil,'FEED_AUTHOR','REPUTATION_BOARD','1.0')
call assertTrue catalog~publish(v1)~ok,'publish v1'
rolloutReq = .InstitutionalPolicyProgressiveRequest~new('RF-ROLLOUT-001',v1,v2,actor,rolloutEnd,'bounded canary of reviewed Feed policy','RF-CHG-200',now)
call assertTrue catalog~publish(v2,.nil,rolloutReq)~ok,'publish v2 with authorized overlap'
rolloutRecord = catalog~progressiveBinding(policyId,'2.0')
call assertTrue rolloutRecord~ok,'rollout authorization retained'
call assertEqual 'RF-ROLLOUT-GRANT',rolloutRecord~value~authorityDecision~grantId,'exact deploy authority retained'

scopeGlobal = .InstitutionalPolicyDeploymentScope~new('RF-GLOBAL')~seal
scopePilot = .InstitutionalPolicyDeploymentScope~new('RF-GB-WEB-PILOT','REPUTATION_FEED','GB','WEB','*','PILOT')~seal
call deploy catalog,v1,'RF-V1-ACTIVE',scopeGlobal,'ACTIVE',start,'prior reviewed policy active','RF-CHG-201',actor,start
call deploy catalog,v2,'RF-V2-STAGED',scopeGlobal,'STAGED',rolloutStart,'successor staged globally','RF-CHG-202',actor,now
call deploy catalog,v2,'RF-V2-PILOT',scopePilot,'CANARY',rolloutStart,'successor canary pilot','RF-CHG-203',actor,now

normalPoint = .InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','GB','WEB','PUBLIC','GENERAL')
pilotPoint = .InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','GB','WEB','PUBLIC','PILOT')
h = makeHypothesis()
during = rolloutStart + .InstitutionalPolicyTime~seconds(5)

normal = bridge~operativeForContext(catalog,normalPoint,during)
call assertTrue normal~ok,'ordinary cohort stays on prior policy during canary'
normalOut = normal~value~corroborate(h)
call assertEqual '1.0',normalOut~policyVersion,'normal cohort v1'
call assertEqual 'CORROBORATED',normalOut~domainResult~status,'v1 lenient result'
call assertEqual 'RF-ROLLOUT-001',normalOut~progressiveRolloutId,'prior route retains active overlap authorization'
call assertEqual 'RF-V1-ACTIVE',normalOut~deploymentBindingId,'prior active binding exact'

pilot = bridge~operativeForContext(catalog,pilotPoint,during)
call assertTrue pilot~ok,'pilot cohort receives successor policy'
pilotOut = pilot~value~corroborate(h)
call assertEqual '2.0',pilotOut~policyVersion,'pilot cohort v2'
call assertEqual 'CORROBORATING',pilotOut~domainResult~status,'same evidence under stricter v2 is not corroborated'
call assertEqual 'CANARY',pilotOut~deploymentMode,'pilot route explicitly canary'
call assertEqual 'RF-V2-PILOT',pilotOut~deploymentBindingId,'pilot exact deployment binding retained'
call assertEqual 'RF-ROLLOUT-001',pilotOut~progressiveRolloutId,'pilot retains exact rollout authorization'
call assertTrue pilotOut~progressiveRolloutIdentity <> '','rollout semantic identity retained'

cutoverAt = rolloutStart + .InstitutionalPolicyTime~seconds(20)
call deploy catalog,v2,'RF-V2-ACTIVE',scopeGlobal,'ACTIVE',cutoverAt,'promote successor after canary review','RF-CHG-204',actor,now
cut = bridge~operativeForContext(catalog,normalPoint,cutoverAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue cut~ok,'cutover selects successor for ordinary cohort'
cutOut = cut~value~corroborate(h)
call assertEqual '2.0',cutOut~policyVersion,'cutover v2'
call assertEqual 'RF-V2-ACTIVE',cutOut~deploymentBindingId,'cutover binding retained'
call assertEqual 'CORROBORATING',cutOut~domainResult~status,'v2 semantics visible after cutover'

rollbackAt = cutoverAt + .InstitutionalPolicyTime~seconds(20)
call deploy catalog,v1,'RF-V1-ROLLBACK',scopeGlobal,'ACTIVE',rollbackAt,'rollback exact prior reviewed policy','RF-INC-205',actor,now
rollback = bridge~operativeForContext(catalog,normalPoint,rollbackAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue rollback~ok,'rollback selects exact prior policy'
rollbackOut = rollback~value~corroborate(h)
call assertEqual '1.0',rollbackOut~policyVersion,'rollback v1'
call assertEqual 'RF-V1-ROLLBACK',rollbackOut~deploymentBindingId,'rollback binding retained'
call assertEqual 'CORROBORATED',rollbackOut~domainResult~status,'prior Feed semantics restored without regeneration'

historical = bridge~operativeForContext(catalog,normalPoint,during)
call assertTrue historical~ok,'later cutover/rollback do not rewrite historical route'
historicalOut = historical~value~corroborate(h)
call assertEqual normalOut~canonicalText,historicalOut~canonicalText,'historical progressive replay deterministic'

expired = bridge~operativeForContext(catalog,normalPoint,rolloutEnd + .InstitutionalPolicyTime~seconds(1))
call assertFalse expired~ok,'dual effective versions cannot outlive rollout authorization'
call assertEqual 'PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED',expired~code,'expired overlap fails closed'

say 'PASS test_institutional_policy_progressive_rollout normal='normalOut~policyVersion 'pilot='pilotOut~policyVersion 'cut='cutOut~policyVersion 'rollback='rollbackOut~policyVersion
exit 0

makePolicySet: procedure
  use arg id,minFamilies,minConfidence
  return .ReputationFeedPolicySet~new(id, -
    .ReputationLineagePolicy~new(78,2), -
    .ReputationCorroborationPolicy~new(minFamilies,minConfidence,1,180,.true), -
    .ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false), -
    .ReputationGeographicSaliencePolicy~new(2,5,3,10))
makeHypothesis: procedure
  h=.ReputationEventHypothesis~new('H-ROLLOUT','AIRCRAFT_SAFETY_INCIDENT')
  h~addClaim(makeClaim('A','ASSERTION:A',92)); h~addClaim(makeClaim('B','ASSERTION:B',84))
  return h~seal
makeClaim: procedure
  use arg id,root,confidence
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Progressive rollout claim',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-ROLLOUT'); c~addSubject('MANUFACTURER','BOEING'); c~addConcept('CABIN_OPENING')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'progressive rollout root')
  c~setSourceAuthentication('VERIFIED','AUTH-'id,.false,'HIST-'id)
  return c~seal
deploy: procedure
  use arg catalog,policy,id,scope,mode,effectiveFrom,reason,evidence,actor,requestedAt
  req=.InstitutionalPolicyDeploymentRequest~new(id,policy,actor,scope,mode,effectiveFrom,.nil,reason,evidence,requestedAt)
  applied=catalog~applyDeployment(policy~policyId,policy~version,req)
  if applied~ok=.false then do; say 'FAIL: deployment' id applied~code applied~detail; exit 1; end
  return
assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value == .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'
