now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(7200)

profile = .InstitutionalPolicyAuthorityProfile~new('SEC-GATED-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-DEPLOY','PLATFORM_RELEASE','DEPLOY','SECURITY-POLICY-GATED',start,.nil,'SECURITY_BOARD','AUTH:SEC-DEPLOY')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .SecurityPolicyCatalog~new(.nil,.nil,.nil,.nil,deployEval)

v1 = makePolicy('1.0',start,'HOLD','')
call assertTrue catalog~publish(v1)~ok,'v1 published'
v2 = makePolicy('2.0',rolloutStart,'REVIEW_REQUIRED','1.0')

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('GB-WEB-PILOT','COMMERCE','GB','WEB','*','PILOT')~seal
normalPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
pilotPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','PILOT')

gate = .InstitutionalPolicyRolloutGate~new('SECURITY-CANARY-GATE','1.0',pilotScope,300,300)
call assertTrue gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('C-ACTIONS','EVALUATED_ACTIONS','GE',1000,1000)~seal),'actions criterion added'
call assertTrue gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('C-FALSE-POS','FALSE_POSITIVE_RATE','LE',0.01,1000)~seal),'false-positive criterion added'
call assertTrue gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('C-SEVERE','SEVERE_SECURITY_INCIDENTS','EQ',0,1000)~seal),'severe incident criterion added'
ignored = gate~seal

rolloutRequest = .InstitutionalPolicyProgressiveRequest~new('SEC-GATED-ROLLOUT',v1,v2,'PLATFORM_RELEASE',rolloutEnd,'canary v2 under fixed measurable acceptance criteria','SEC-CHG-900',now,gate)
call assertTrue catalog~publish(v2,.nil,rolloutRequest)~ok,'v2 published with fixed rollout gate'
rollout = catalog~progressiveBinding(v2~policyId,v2~version)~value

call deploy catalog,v2,'SEC-GATED-STAGE',globalScope,'STAGED',rolloutStart,'stage v2','SEC-CHG-901',now,.nil
call deploy catalog,v2,'SEC-GATED-CANARY',pilotScope,'CANARY',rolloutStart,'canary v2','SEC-CHG-902',now,.nil

subject = 'CUSTOMER-GATED'
store = .SecurityEvidenceStore~new
finding = .SecurityFinding~new('F-GATED-GEO','GEO_CONTINUITY_ANOMALY','CONCERN',subject,95,start,rolloutEnd,'recent impossible travel evidence','SECURITY_EFFECT')~seal
call assertTrue store~recordFinding(finding)~ok,'customer security evidence recorded'
replayer = .SecurityPolicyReplayEngine~new

during = rolloutStart + .InstitutionalPolicyTime~seconds(60)
normalAction = makeGold('A-GATED-NORMAL',subject,during)
normalSnap = store~snapshotFor(subject,during)
normal = replayer~replayPublished(normalAction,normalSnap,catalog,v1~policyId,normalPoint)
call assertTrue normal~ok,'ordinary traffic remains on v1 during canary'
call assertEqual 'HOLD',normal~value~disposition,'ordinary v1 HOLD result'
pilotAction = makeGold('A-GATED-PILOT',subject,during)
pilotSnap = store~snapshotFor(subject,during)
pilot = replayer~replayPublished(pilotAction,pilotSnap,catalog,v1~policyId,pilotPoint)
call assertTrue pilot~ok,'pilot routes to v2 during canary'
call assertEqual 'REVIEW_REQUIRED',pilot~value~disposition,'pilot receives v2 semantics'

assess1 = rolloutStart + .InstitutionalPolicyTime~seconds(600)
insufficient = makeMetrics(rollout,pilotScope,rolloutStart,assess1,100,0.0,0,100,'INSUFF')
req1 = .InstitutionalPolicyDeploymentRequest~new('SEC-GATED-PROMOTE-INSUFF',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',assess1 + .InstitutionalPolicyTime~seconds(10),.nil,'promotion requires sufficient evidence','SEC-CHG-903',assess1,insufficient)
r1 = catalog~applyDeployment(v2~policyId,v2~version,req1)
call assertTrue \r1~ok,'small canary sample blocks security policy promotion'
call assertEqual 'INSUFFICIENT_EVIDENCE',r1~value~outcome,'security rollout records statistical insufficiency'

assess2 = assess1 + .InstitutionalPolicyTime~seconds(600)
bad = makeMetrics(rollout,pilotScope,assess2 - .InstitutionalPolicyTime~seconds(600),assess2,2500,0.025,0,2500,'BAD')
req2 = .InstitutionalPolicyDeploymentRequest~new('SEC-GATED-PROMOTE-BAD',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',assess2 + .InstitutionalPolicyTime~seconds(10),.nil,'promotion blocked by false-positive threshold','SEC-CHG-904',assess2,bad)
r2 = catalog~applyDeployment(v2~policyId,v2~version,req2)
call assertTrue \r2~ok,'measurably bad Bouncer canary blocks promotion'
call assertEqual 'PROMOTION_BLOCKED',r2~value~outcome,'threshold breach is explicit, not runtime model opinion'

/* Blocking promotion does not mutate the customer's security evidence or route. */
postBadAction = makeGold('A-GATED-POSTBAD',subject,assess2 + .InstitutionalPolicyTime~seconds(20))
postBadSnap = store~snapshotFor(subject,postBadAction~intendedAt)
call assertEqual 1,postBadSnap~findings~items,'rollout metrics never become customer security findings'
postBad = replayer~replayPublished(postBadAction,postBadSnap,catalog,v1~policyId,normalPoint)
call assertTrue postBad~ok,'ordinary route remains usable after blocked promotion'
call assertEqual '1.0',postBad~value~policy~version,'blocked promotion leaves v1 operative'
call assertEqual 'HOLD',postBad~value~disposition,'v1 result remains intact'

assess3 = assess2 + .InstitutionalPolicyTime~seconds(600)
good = makeMetrics(rollout,pilotScope,assess3 - .InstitutionalPolicyTime~seconds(600),assess3,6000,0.003,0,6000,'GOOD')
promoteAt = assess3 + .InstitutionalPolicyTime~seconds(20)
req3 = .InstitutionalPolicyDeploymentRequest~new('SEC-GATED-PROMOTE-GOOD',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',promoteAt,.nil,'promote v2 after fixed gate passes','SEC-CHG-905',assess3,good)
r3 = catalog~applyDeployment(v2~policyId,v2~version,req3)
call assertTrue r3~ok,'good Bouncer canary evidence permits promotion'
call assertTrue r3~value~rolloutAssessment <> .nil,'deployment evidence retains gate assessment'
call assertEqual 'PROMOTION_ELIGIBLE',r3~value~rolloutAssessment~outcome,'promotion assessment passed'
call assertEqual gate~semanticIdentity,r3~value~rolloutAssessment~gateIdentity,'exact reviewed gate retained'

cutAction = makeGold('A-GATED-CUTOVER',subject,promoteAt + .InstitutionalPolicyTime~seconds(1))
cutSnap = store~snapshotFor(subject,cutAction~intendedAt)
cut = replayer~replayPublished(cutAction,cutSnap,catalog,v1~policyId,normalPoint)
call assertTrue cut~ok,'ordinary traffic routes to v2 after evidence-backed cutover'
call assertEqual '2.0',cut~value~policy~version,'v2 operative after promotion'
call assertEqual 'REVIEW_REQUIRED',cut~value~disposition,'v2 Bouncer behaviour operative after promotion'

rollbackAt = promoteAt + .InstitutionalPolicyTime~seconds(60)
call deploy catalog,v1,'SEC-GATED-ROLLBACK',globalScope,'ACTIVE',rollbackAt,'rollback exact reviewed v1','SEC-INC-906',assess3,.nil
rollbackAction = makeGold('A-GATED-ROLLBACK',subject,rollbackAt + .InstitutionalPolicyTime~seconds(1))
rollbackSnap = store~snapshotFor(subject,rollbackAction~intendedAt)
rollback = replayer~replayPublished(rollbackAction,rollbackSnap,catalog,v1~policyId,normalPoint)
call assertTrue rollback~ok,'rollback remains available without successor health proof'
call assertEqual '1.0',rollback~value~policy~version,'rollback selects exact reviewed v1'
call assertEqual 'HOLD',rollback~value~disposition,'v1 HOLD semantics restored'

say 'PASS test_policy_rollout_gate_integration'
exit 0

makePolicy: procedure
  use arg version,effectiveFrom,disposition,supersedes
  p = .SecurityPolicyFramework~new('SECURITY-POLICY-GATED',version,effectiveFrom,.nil,'SECURITY_TEAM','RISK_COMMITTEE',supersedes)
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

makeMetrics: procedure
  use arg rollout,scope,windowFrom,recordedAt,actions,falsePositiveRate,severe,sampleSize,prefix
  out = .array~new
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-A',rollout,'EVALUATED_ACTIONS',actions,sampleSize,windowFrom,recordedAt,'BOUNCER-ROLLOUT-METRICS','METRIC:' || prefix || ':A',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-F',rollout,'FALSE_POSITIVE_RATE',falsePositiveRate,sampleSize,windowFrom,recordedAt,'BOUNCER-ROLLOUT-METRICS','METRIC:' || prefix || ':F',scope,recordedAt)~seal)
  out~append(.InstitutionalPolicyRolloutObservation~new(prefix || '-S',rollout,'SEVERE_SECURITY_INCIDENTS',severe,sampleSize,windowFrom,recordedAt,'BOUNCER-ROLLOUT-METRICS','METRIC:' || prefix || ':S',scope,recordedAt)~seal)
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
