now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(7200)

profile = .InstitutionalPolicyAuthorityProfile~new('SEC-RB-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-RB-DEP','PLATFORM_RELEASE','DEPLOY','SECURITY-POLICY-RB',start,.nil,'SECURITY_BOARD','AUTH:SEC-RB-DEP')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .SecurityPolicyCatalog~new(.nil,.nil,.nil,.nil,deployEval)

v1 = makePolicy('1.0',start,'HOLD','')
call assertTrue catalog~publish(v1)~ok,'v1 published'
v2 = makePolicy('2.0',rolloutStart,'REVIEW_REQUIRED','1.0')

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('GB-WEB-PILOT','COMMERCE','GB','WEB','*','PILOT')~seal
normalPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')

promotionGate = .InstitutionalPolicyRolloutGate~new('SEC-PROMOTE','1.0',pilotScope,300,300)
call assertTrue promotionGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('P-ACTIONS','EVALUATED_ACTIONS','GE',1000,1000)~seal),'promotion sample criterion added'
call assertTrue promotionGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('P-FALSE-POS','FALSE_POSITIVE_RATE','LE',0.01,1000)~seal),'promotion false-positive criterion added'
ignored = promotionGate~seal

rollbackGate = .InstitutionalPolicyRollbackGate~new('SEC-POST-CUTOVER','1.0',globalScope,300,300,'ANY')
call assertTrue rollbackGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('R-FALSE-POS','FALSE_POSITIVE_RATE','GT',0.02,1000)~seal),'rollback false-positive trigger added'
call assertTrue rollbackGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('R-SEVERE','SEVERE_SECURITY_INCIDENTS','GT',0,1000)~seal),'rollback severe-incident trigger added'
ignored = rollbackGate~seal

rolloutRequest = .InstitutionalPolicyProgressiveRequest~new('SEC-RB-ROLLOUT',v1,v2,'PLATFORM_RELEASE',rolloutEnd,'v2 rollout with fixed post-cutover rollback criteria','SEC-CHG-1000',now,promotionGate,rollbackGate)
call assertTrue catalog~publish(v2,.nil,rolloutRequest)~ok,'v2 published with promotion and rollback gates'
rollout = catalog~progressiveBinding(v2~policyId,v2~version)~value

call deploy catalog,v2,'SEC-RB-STAGE',globalScope,'STAGED',rolloutStart,'stage v2','SEC-CHG-1001',now,.nil
call deploy catalog,v2,'SEC-RB-CANARY',pilotScope,'CANARY',rolloutStart,'canary v2','SEC-CHG-1002',now,.nil

subject = 'CUSTOMER-RB'
store = .SecurityEvidenceStore~new
finding = .SecurityFinding~new('F-RB-GEO','GEO_CONTINUITY_ANOMALY','CONCERN',subject,95,start,rolloutEnd,'recent impossible travel evidence','SECURITY_EFFECT')~seal
call assertTrue store~recordFinding(finding)~ok,'customer security evidence recorded'
replayer = .SecurityPolicyReplayEngine~new

promoteObservedAt = rolloutStart + .InstitutionalPolicyTime~seconds(600)
goodPromotion = makePromotionMetrics(rollout,pilotScope,rolloutStart,promoteObservedAt,6000,0.003,6000,'PROMOTE')
promoteAt = promoteObservedAt + .InstitutionalPolicyTime~seconds(20)
call deploy catalog,v2,'SEC-RB-PROMOTE',globalScope,'ACTIVE',promoteAt,'promote v2 after fixed canary gate','SEC-CHG-1003',promoteObservedAt,goodPromotion

cutAction = makeGold('A-RB-CUTOVER',subject,promoteAt + .InstitutionalPolicyTime~seconds(1))
cutSnap = store~snapshotFor(subject,cutAction~intendedAt)
cut = replayer~replayPublished(cutAction,cutSnap,catalog,v1~policyId,normalPoint)
call assertTrue cut~ok,'traffic routes through v2 after promotion'
call assertEqual '2.0',cut~value~policy~version,'v2 is operative after evidence-backed cutover'
call assertEqual 'REVIEW_REQUIRED',cut~value~disposition,'v2 behaviour is active'

healthyAt = promoteAt + .InstitutionalPolicyTime~seconds(600)
healthy = makeRollbackMetrics(rollout,globalScope,promoteAt,healthyAt,7000,0.006,0,7000,'HEALTHY')
healthyReq = .InstitutionalPolicyDeploymentRequest~new('SEC-RB-AUTO-HEALTHY',v1,'PLATFORM_RELEASE',globalScope,'ACTIVE',healthyAt + .InstitutionalPolicyTime~seconds(20),.nil,'automatic rollback should not fire while healthy','SEC-OBS-1004',healthyAt,healthy)
healthyRollback = catalog~applyAutomatedRollback(v1~policyId,v1~version,healthyReq)
call assertTrue \healthyRollback~ok,'healthy successor blocks automatic rollback'
call assertEqual 'ROLLBACK_NOT_ELIGIBLE',healthyRollback~code,'healthy automatic rollback failure is explicit'
call assertEqual 'ROLLBACK_NOT_REQUIRED',healthyRollback~value~outcome,'fixed gate says rollback not required'

/* Rollout health evidence remains governance evidence and never appears in the customer snapshot. */
postHealthyAction = makeGold('A-RB-HEALTHY',subject,healthyAt + .InstitutionalPolicyTime~seconds(30))
postHealthySnap = store~snapshotFor(subject,postHealthyAction~intendedAt)
call assertEqual 1,postHealthySnap~findings~items,'post-promotion metrics never become customer security findings'
postHealthy = replayer~replayPublished(postHealthyAction,postHealthySnap,catalog,v1~policyId,normalPoint)
call assertTrue postHealthy~ok,'v2 remains operative after healthy evidence'
call assertEqual '2.0',postHealthy~value~policy~version,'healthy evidence does not alter deployment routing'

badAt = healthyAt + .InstitutionalPolicyTime~seconds(600)
bad = makeRollbackMetrics(rollout,globalScope,badAt - .InstitutionalPolicyTime~seconds(600),badAt,9000,0.031,0,9000,'BAD')
autoAt = badAt + .InstitutionalPolicyTime~seconds(20)
badReq = .InstitutionalPolicyDeploymentRequest~new('SEC-RB-AUTO-BAD',v1,'PLATFORM_RELEASE',globalScope,'ACTIVE',autoAt,.nil,'automatic rollback after fixed degradation threshold','SEC-INC-1005',badAt,bad)
badRollback = catalog~applyAutomatedRollback(v1~policyId,v1~version,badReq)
call assertTrue badRollback~ok,'bad production evidence permits automatic rollback'
call assertTrue badRollback~value~rollbackAssessment <> .nil,'rollback binding retains fixed-gate assessment'
call assertEqual 'ROLLBACK_ELIGIBLE',badRollback~value~rollbackAssessment~outcome,'automatic rollback is evidence-backed'
call assertEqual rollbackGate~semanticIdentity,badRollback~value~rollbackAssessment~gateIdentity,'exact reviewed rollback gate retained'
call assertEqual v1~semanticIdentity,badRollback~value~policyIdentity,'rollback selects exact reviewed v1 artefact'

rollbackAction = makeGold('A-RB-ROLLED-BACK',subject,autoAt + .InstitutionalPolicyTime~seconds(1))
rollbackSnap = store~snapshotFor(subject,rollbackAction~intendedAt)
rollback = replayer~replayPublished(rollbackAction,rollbackSnap,catalog,v1~policyId,normalPoint)
call assertTrue rollback~ok,'Bouncer remains operational after automatic rollback'
call assertEqual '1.0',rollback~value~policy~version,'routing returns to exact v1'
call assertEqual 'HOLD',rollback~value~disposition,'v1 HOLD semantics restored after degradation'
call assertEqual 1,rollbackSnap~findings~items,'rollback changes policy selection, not customer evidence'

assessments = catalog~rollbackAssessments(v2~policyId,v2~version)
call assertEqual 2,assessments~items,'healthy and bad post-promotion assessments retained'

say 'PASS test_policy_post_promotion_rollback_integration'
exit 0

makePolicy: procedure
  use arg version,effectiveFrom,disposition,supersedes
  p = .SecurityPolicyFramework~new('SECURITY-POLICY-RB',version,effectiveFrom,.nil,'SECURITY_TEAM','RISK_COMMITTEE',supersedes)
  r = .SecurityPolicyRule~new('PAY-031',100,'PURCHASE',disposition,'high-value stored payment under identity-continuity concern')
  r~requireFinding('GEO_CONTINUITY_ANOMALY')
  r~addCriterion('PAYMENT_INSTRUMENT','EQ','STORED')
  r~addCriterion('ASSET_CLASS','EQ','HIGH_VALUE_LIQUID_ASSET')
  r~addCriterion('AMOUNT','GE',20000)
  r~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED','TRANSACTION')
  ignored = p~addRule(r~seal)
  return p~seal

deploy: procedure
  use arg catalog,policy,id,scope,mode,effectiveFrom,reason,evidence,requestedAt,observations
  req = .InstitutionalPolicyDeploymentRequest~new(id,policy,'PLATFORM_RELEASE',scope,mode,effectiveFrom,.nil,reason,evidence,requestedAt,observations)
  result = catalog~applyDeployment(policy~policyId,policy~version,req)
  if result~ok = .false then do
    say 'FAIL: deployment' id 'code='result~code 'detail='result~detail
    exit 1
  end
  return

makePromotionMetrics: procedure
  use arg rollout,scope,windowFrom,recordedAt,actions,falsePositiveRate,sampleSize,prefix
  out = .array~new
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-A',rollout,'EVALUATED_ACTIONS',actions,sampleSize,windowFrom,recordedAt,'BOUNCER-ROLLOUT-METRICS','METRIC:' || prefix || ':A',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-F',rollout,'FALSE_POSITIVE_RATE',falsePositiveRate,sampleSize,windowFrom,recordedAt,'BOUNCER-ROLLOUT-METRICS','METRIC:' || prefix || ':F',scope,recordedAt)~seal)
  return out

makeRollbackMetrics: procedure
  use arg rollout,scope,windowFrom,recordedAt,actions,falsePositiveRate,severe,sampleSize,prefix
  out = .array~new
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-F',rollout,'FALSE_POSITIVE_RATE',falsePositiveRate,sampleSize,windowFrom,recordedAt,'BOUNCER-POST-PROMOTION-METRICS','METRIC:' || prefix || ':F',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-S',rollout,'SEVERE_SECURITY_INCIDENTS',severe,sampleSize,windowFrom,recordedAt,'BOUNCER-POST-PROMOTION-METRICS','METRIC:' || prefix || ':S',scope,recordedAt)~seal)
  return out

makeGold: procedure
  use arg id,subject,when
  a = .SecurityActionSurface~new(id,subject,'PURCHASE',when,'HIGH','PAYMENT')
  a~putAttribute('PAYMENT_INSTRUMENT','STORED')
  a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
  a~putAttribute('AMOUNT',22000)
  return a~seal

assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'SecurityEffect.cls'
