now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(7200)

profile = .InstitutionalPolicyAuthorityProfile~new('ROLLBACK-GATE-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-DEP','PLATFORM_RELEASE','DEPLOY','OPS-ROLLBACK-GATED',start,.nil,'POLICY_BOARD','AUTH:G-DEP')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,deployEval)

v1 = .InstitutionalPolicyRelease~new('OPS-ROLLBACK-GATED','1.0',start,.nil,'POLICY_AUTHOR','POLICY_APPROVER','',.nil,'OPS-RB-V1')~seal
call assertTrue catalog~publish(v1)~ok,'v1 published'
v2 = .InstitutionalPolicyRelease~new('OPS-ROLLBACK-GATED','2.0',rolloutStart,.nil,'POLICY_AUTHOR','POLICY_APPROVER','1.0',.nil,'OPS-RB-V2')~seal

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('PILOT','COMMERCE','GB','WEB','*','PILOT')~seal

promotionGate = .InstitutionalPolicyRolloutGate~new('OPS-PROMOTE','1.0',pilotScope,300,300)
call assertTrue promotionGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('P-ACTIONS','EVALUATED_ACTIONS','GE',1000,1000)~seal),'promotion sample criterion added'
call assertTrue promotionGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('P-ERROR','POLICY_ERROR_RATE','LE',0.01,1000)~seal),'promotion error criterion added'
ignored = promotionGate~seal

rollbackGate = .InstitutionalPolicyRollbackGate~new('OPS-POST-CUTOVER','1.0',globalScope,300,300,'ANY')
call assertTrue rollbackGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('R-ERROR','POLICY_ERROR_RATE','GT',0.02,1000)~seal),'rollback error trigger added'
call assertTrue rollbackGate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('R-SEVERE','SEVERE_INCIDENTS','GT',0,1000)~seal),'rollback severe trigger added'
ignored = rollbackGate~seal

rolloutReq = .InstitutionalPolicyProgressiveRequest~new('ROLLOUT-RB-001',v1,v2,'PLATFORM_RELEASE',rolloutEnd,'bounded rollout with deterministic promotion and rollback gates','CHG-RB-001',now,promotionGate,rollbackGate)
call assertTrue catalog~publish(v2,.nil,rolloutReq)~ok,'v2 published with promotion and rollback gates'
rollout = catalog~progressiveBinding(v2~policyId,v2~version)~value
call assertEqual rollbackGate~semanticIdentity,rollout~rollbackGate~semanticIdentity,'exact rollback gate retained'

call deploy catalog,v2,'DEP-V2-STAGE',globalScope,'STAGED',rolloutStart,'stage v2','CHG-RB-002',now,.nil
call deploy catalog,v2,'DEP-V2-CANARY',pilotScope,'CANARY',rolloutStart,'canary v2','CHG-RB-003',now,.nil

promoteObservedAt = rolloutStart + .InstitutionalPolicyTime~seconds(600)
goodPromotion = makePromotionEvidence(rollout,pilotScope,rolloutStart,promoteObservedAt,5000,0.003,5000,'PROMOTE')
promoteAt = promoteObservedAt + .InstitutionalPolicyTime~seconds(20)
call deploy catalog,v2,'DEP-V2-ACTIVE',globalScope,'ACTIVE',promoteAt,'promote v2 after passing gate','CHG-RB-004',promoteObservedAt,goodPromotion

/* Post-promotion evidence is evaluated independently from customer evidence. */
monitor1 = promoteAt + .InstitutionalPolicyTime~seconds(600)
insufficient = makeRollbackEvidence(rollout,globalScope,promoteAt,monitor1,100,0.04,0,100,'INSUFF')
a1 = catalog~assessRollback(v2~policyId,v2~version,globalScope,insufficient,monitor1,'RB-ASSESS-INSUFF')
call assertTrue a1~ok,'insufficient rollback evidence is recorded'
call assertEqual 'ROLLBACK_INSUFFICIENT_EVIDENCE',a1~value~outcome,'insufficient post-cutover sample cannot trigger automatic rollback'

monitor2 = monitor1 + .InstitutionalPolicyTime~seconds(600)
healthy = makeRollbackEvidence(rollout,globalScope,monitor2 - .InstitutionalPolicyTime~seconds(600),monitor2,5000,0.006,0,5000,'HEALTHY')
a2 = catalog~assessRollback(v2~policyId,v2~version,globalScope,healthy,monitor2,'RB-ASSESS-HEALTHY')
call assertTrue a2~ok,'healthy post-cutover evidence is recorded'
call assertEqual 'ROLLBACK_NOT_REQUIRED',a2~value~outcome,'healthy successor does not trigger rollback'

/* Old observations cannot be made fresh merely by evaluating them later. */
staleAt = monitor2 + .InstitutionalPolicyTime~seconds(400)
stale = catalog~assessRollback(v2~policyId,v2~version,globalScope,healthy,staleAt,'RB-ASSESS-STALE')
call assertTrue \stale~ok,'stale post-cutover evidence cannot be reused'
call assertEqual 'ROLLBACK_OBSERVATION_STALE',stale~code,'stale rollback evidence rejected explicitly'

monitor3 = monitor2 + .InstitutionalPolicyTime~seconds(600)
bad = makeRollbackEvidence(rollout,globalScope,monitor3 - .InstitutionalPolicyTime~seconds(600),monitor3,8000,0.031,0,8000,'BAD')
a3 = catalog~assessRollback(v2~policyId,v2~version,globalScope,bad,monitor3,'RB-ASSESS-BAD')
call assertTrue a3~ok,'bad post-cutover evidence assessed'
call assertEqual 'ROLLBACK_ELIGIBLE',a3~value~outcome,'fixed degradation threshold makes rollback eligible'
call assertEqual rollbackGate~semanticIdentity,a3~value~gateIdentity,'assessment retains exact rollback gate identity'

/* The automated path re-evaluates evidence internally; callers cannot hand it a forged assessment. */
autoAt = monitor3 + .InstitutionalPolicyTime~seconds(20)
autoReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V1-AUTO-ROLLBACK',v1,'PLATFORM_RELEASE',globalScope,'ACTIVE',autoAt,.nil,'automatic rollback after fixed post-cutover gate','INC-RB-005',monitor3,bad)
auto = catalog~applyAutomatedRollback(v1~policyId,v1~version,autoReq)
call assertTrue auto~ok,'eligible evidence permits automatic rollback to exact prior reviewed policy'
call assertTrue auto~value~rollbackAssessment <> .nil,'rollback deployment retains exact assessment evidence'
call assertEqual 'ROLLBACK_ELIGIBLE',auto~value~rollbackAssessment~outcome,'rollback binding proves gate eligibility'
call assertEqual v1~semanticIdentity,auto~value~policyIdentity,'automatic rollback selects exact prior policy identity'

assessments = catalog~rollbackAssessments(v2~policyId,v2~version)
call assertEqual 4,assessments~items,'post-promotion rollback assessments retained immutably'

/* Manual authorised rollback remains independent of the automatic gate. */
manualAt = autoAt + .InstitutionalPolicyTime~seconds(60)
manualReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V1-MANUAL-ROLLBACK',v1,'PLATFORM_RELEASE',globalScope,'ACTIVE',manualAt,.nil,'manual incident rollback remains available','INC-RB-006',monitor3)
manual = catalog~applyDeployment(v1~policyId,v1~version,manualReq)
call assertTrue manual~ok,'manual authorised rollback does not require automatic metric trigger'
call assertTrue manual~value~rollbackAssessment == .nil,'manual rollback is not misrepresented as gate-triggered'

say 'PASS test_post_promotion_rollback_gate'
exit 0

deploy: procedure
  use arg catalog,policy,id,scope,mode,effectiveFrom,reason,evidence,requestedAt,observations
  req = .InstitutionalPolicyDeploymentRequest~new(id,policy,'PLATFORM_RELEASE',scope,mode,effectiveFrom,.nil,reason,evidence,requestedAt,observations)
  result = catalog~applyDeployment(policy~policyId,policy~version,req)
  if result~ok = .false then do
    say 'FAIL: deployment' id 'code='result~code 'detail='result~detail
    exit 1
  end
  return

makePromotionEvidence: procedure
  use arg rollout,scope,windowFrom,recordedAt,actions,errorRate,sampleSize,prefix
  out = .array~new
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-A',rollout,'EVALUATED_ACTIONS',actions,sampleSize,windowFrom,recordedAt,'ROLLOUT-METRICS','METRIC:' || prefix || ':A',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-E',rollout,'POLICY_ERROR_RATE',errorRate,sampleSize,windowFrom,recordedAt,'ROLLOUT-METRICS','METRIC:' || prefix || ':E',scope,recordedAt)~seal)
  return out

makeRollbackEvidence: procedure
  use arg rollout,scope,windowFrom,recordedAt,actions,errorRate,severe,sampleSize,prefix
  out = .array~new
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-E',rollout,'POLICY_ERROR_RATE',errorRate,sampleSize,windowFrom,recordedAt,'POST-PROMOTION-METRICS','METRIC:' || prefix || ':E',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-S',rollout,'SEVERE_INCIDENTS',severe,sampleSize,windowFrom,recordedAt,'POST-PROMOTION-METRICS','METRIC:' || prefix || ':S',scope,recordedAt)~seal)
  return out

assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
