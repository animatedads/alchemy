now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(7200)

profile = .InstitutionalPolicyAuthorityProfile~new('ROLLOUT-GATE-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-DEP','PLATFORM_RELEASE','DEPLOY','OPS-GATED',start,.nil,'POLICY_BOARD','AUTH:G-DEP')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,deployEval)

v1 = .InstitutionalPolicyRelease~new('OPS-GATED','1.0',start,.nil,'POLICY_AUTHOR','POLICY_APPROVER','',.nil,'OPS-GATED-V1')~seal
call assertTrue catalog~publish(v1)~ok,'v1 published'
v2 = .InstitutionalPolicyRelease~new('OPS-GATED','2.0',rolloutStart,.nil,'POLICY_AUTHOR','POLICY_APPROVER','1.0',.nil,'OPS-GATED-V2')~seal

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('PILOT','COMMERCE','GB','WEB','*','PILOT')~seal

gate = .InstitutionalPolicyRolloutGate~new('OPS-GATE','1.0',pilotScope,300,300)
call assertTrue gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('C-SAMPLE','EVALUATED_ACTIONS','GE',1000,1000)~seal),'sample criterion added'
call assertTrue gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('C-ERROR','POLICY_ERROR_RATE','LE',0.01,1000)~seal),'error criterion added'
call assertTrue gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('C-SEVERE','SEVERE_INCIDENTS','EQ',0,1000)~seal),'severe incident criterion added'
ignored = gate~seal

rolloutReq = .InstitutionalPolicyProgressiveRequest~new('ROLLOUT-GATED-001',v1,v2,'PLATFORM_RELEASE',rolloutEnd,'bounded rollout with fixed evidence gate','CHG-GATE-001',now,gate)
call assertTrue catalog~publish(v2,.nil,rolloutReq)~ok,'v2 published with fixed rollout gate'
rolloutResult = catalog~progressiveBinding('OPS-GATED','2.0')
call assertTrue rolloutResult~ok,'progressive binding retained'
rollout = rolloutResult~value
call assertEqual gate~semanticIdentity,rollout~gate~semanticIdentity,'exact gate identity retained in rollout authorization'

stageReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-STAGE',v2,'PLATFORM_RELEASE',globalScope,'STAGED',rolloutStart,.nil,'stage v2','CHG-GATE-002',now)
call assertTrue catalog~applyDeployment(v2~policyId,v2~version,stageReq)~ok,'v2 staged without promotion gate evaluation'
canaryReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-CANARY',v2,'PLATFORM_RELEASE',pilotScope,'CANARY',rolloutStart,.nil,'canary v2','CHG-GATE-003',now)
call assertTrue catalog~applyDeployment(v2~policyId,v2~version,canaryReq)~ok,'v2 canary starts without promotion gate evaluation'

assess1 = rolloutStart + .InstitutionalPolicyTime~seconds(600)
insufficient = makeEvidence(rollout,pilotScope,rolloutStart,assess1,100,0.0,0,100,'INSUFF')
req1 = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-PROMOTE-INSUFF',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',assess1 + .InstitutionalPolicyTime~seconds(10),.nil,'attempt promotion with too little evidence','CHG-GATE-004',assess1,insufficient)
r1 = catalog~applyDeployment(v2~policyId,v2~version,req1)
call assertTrue \r1~ok,'insufficient sample blocks promotion'
call assertEqual 'ROLLOUT_PROMOTION_NOT_ELIGIBLE',r1~code,'insufficient sample failure code'
call assertEqual 'INSUFFICIENT_EVIDENCE',r1~value~outcome,'insufficient evidence outcome retained'

assess2 = assess1 + .InstitutionalPolicyTime~seconds(600)
bad = makeEvidence(rollout,pilotScope,assess2 - .InstitutionalPolicyTime~seconds(600),assess2,2000,0.02,0,2000,'BAD')
req2 = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-PROMOTE-BAD',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',assess2 + .InstitutionalPolicyTime~seconds(10),.nil,'attempt promotion with excessive error rate','CHG-GATE-005',assess2,bad)
r2 = catalog~applyDeployment(v2~policyId,v2~version,req2)
call assertTrue \r2~ok,'bad canary evidence blocks promotion'
call assertEqual 'PROMOTION_BLOCKED',r2~value~outcome,'breached fixed criterion is promotion blocked'

assess3 = assess2 + .InstitutionalPolicyTime~seconds(600)
good = makeEvidence(rollout,pilotScope,assess3 - .InstitutionalPolicyTime~seconds(600),assess3,5000,0.002,0,5000,'GOOD')
lateEval = .InstitutionalPolicyRolloutEvaluator~new~evaluate('ASSESS-STALE-OBS',rollout,globalScope,good,assess3 + .InstitutionalPolicyTime~seconds(400))
call assertTrue \lateEval~ok,'old rollout observations cannot be made fresh by evaluating them later'
call assertEqual 'ROLLOUT_OBSERVATION_STALE',lateEval~code,'actual observation age is enforced'
reqStale = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-PROMOTE-STALE',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',assess3 + .InstitutionalPolicyTime~seconds(400),.nil,'attempt promotion after evidence freshness expires','CHG-GATE-006',assess3,good)
rStale = catalog~applyDeployment(v2~policyId,v2~version,reqStale)
call assertTrue \rStale~ok,'stale otherwise-good evidence cannot be reused'
call assertEqual 'ROLLOUT_PROMOTION_ASSESSMENT_MISMATCH',rStale~code,'freshness mismatch explicit'

promoteAt = assess3 + .InstitutionalPolicyTime~seconds(30)
req3 = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-PROMOTE-GOOD',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',promoteAt,.nil,'promote after fixed gate passes','CHG-GATE-007',assess3,good)
r3 = catalog~applyDeployment(v2~policyId,v2~version,req3)
call assertTrue r3~ok,'good fresh canary evidence permits promotion'
call assertTrue r3~value~rolloutAssessment <> .nil,'successful deployment retains rollout assessment'
call assertEqual 'PROMOTION_ELIGIBLE',r3~value~rolloutAssessment~outcome,'binding retains promotion outcome'
call assertEqual gate~semanticIdentity,r3~value~rolloutAssessment~gateIdentity,'binding retains exact gate identity'

assessments = catalog~rolloutAssessments('OPS-GATED','2.0')
call assertEqual 4,assessments~items,'authorized promotion attempts retained as immutable assessment history'

/* Same inputs and same assessment id produce the same deterministic evidence result. */
evaluator = .InstitutionalPolicyRolloutEvaluator~new
a = evaluator~evaluate('ASSESS-DETERMINISTIC',rollout,globalScope,good,assess3)
b = evaluator~evaluate('ASSESS-DETERMINISTIC',rollout,globalScope,good,assess3)
call assertTrue a~ok & b~ok,'direct deterministic evaluations succeed'
call assertEqual a~value~semanticIdentity,b~value~semanticIdentity,'same evidence and gate produce identical assessment identity'

rollbackAt = promoteAt + .InstitutionalPolicyTime~seconds(60)
rollbackReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V1-ROLLBACK',v1,'PLATFORM_RELEASE',globalScope,'ACTIVE',rollbackAt,.nil,'rollback to exact reviewed v1 after v2 problem','INC-GATE-008',assess3)
call assertTrue catalog~applyDeployment(v1~policyId,v1~version,rollbackReq)~ok,'rollback to prior reviewed policy does not require successor promotion evidence'

say 'PASS test_rollout_evidence_gate'
exit 0

makeEvidence: procedure
  use arg rollout,scope,windowFrom,recordedAt,actions,errorRate,severe,sampleSize,prefix
  out = .array~new
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-A',rollout,'EVALUATED_ACTIONS',actions,sampleSize,windowFrom,recordedAt,'ROLLOUT-METRICS','METRICS:' || prefix || ':A',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-E',rollout,'POLICY_ERROR_RATE',errorRate,sampleSize,windowFrom,recordedAt,'ROLLOUT-METRICS','METRICS:' || prefix || ':E',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-S',rollout,'SEVERE_INCIDENTS',severe,sampleSize,windowFrom,recordedAt,'ROLLOUT-METRICS','METRICS:' || prefix || ':S',scope,recordedAt)~seal)
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
