now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(3600)

profile = .InstitutionalPolicyAuthorityProfile~new('SEC-ROLLOUT-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('S-DEP','PLATFORM_RELEASE','DEPLOY','SECURITY-POLICY-CORE',start,.nil,'SECURITY_BOARD','AUTH:S-DEP')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .SecurityPolicyCatalog~new(.nil,.nil,.nil,.nil,deployEval)

v1 = makePolicy('1.0',start,'HOLD','')
call assertTrue catalog~publish(v1)~ok,'v1 security policy published'
v2 = makePolicy('2.0',rolloutStart,'REVIEW_REQUIRED','1.0')

rollout = .InstitutionalPolicyProgressiveRequest~new('SEC-ROLLOUT-001',v1,v2,'PLATFORM_RELEASE',rolloutEnd,'canary new reviewed security policy before cutover','SEC-CHG-800',now)
call assertTrue catalog~publish(v2,.nil,rollout)~ok,'v2 published under bounded progressive overlap authorization'
record = catalog~progressiveBinding(v2~policyId,v2~version)
call assertTrue record~ok,'security rollout authority evidence retained'
call assertEqual 'S-DEP',record~value~authorityDecision~grantId,'security rollout records exact deploy grant'

globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('GB-WEB-PILOT','COMMERCE','GB','WEB','*','PILOT')~seal
call deploy catalog,v2,'SEC-V2-STAGED',globalScope,'STAGED',rolloutStart,'stage reviewed v2 globally','SEC-CHG-801',now
call deploy catalog,v2,'SEC-V2-PILOT',pilotScope,'CANARY',rolloutStart,'canary reviewed v2 to pilot cohort','SEC-CHG-802',now

subject = 'CUSTOMER-PROGRESSIVE'
store = .SecurityEvidenceStore~new
finding = .SecurityFinding~new('F-GEO-PROG','GEO_CONTINUITY_ANOMALY','CONCERN',subject,95,start,rolloutEnd,'recent impossible travel evidence','SECURITY_EFFECT')~seal
call assertTrue store~recordFinding(finding)~ok,'customer evidence recorded independently of rollout topology'
replayer = .SecurityPolicyReplayEngine~new
normalPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
pilotPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','PILOT')

during = rolloutStart + .InstitutionalPolicyTime~seconds(5)
normalAction = makeGold('A-PROG-NORMAL',subject,during)
normalSnap = store~snapshotFor(subject,during)
normalResult = replayer~replayPublished(normalAction,normalSnap,catalog,'SECURITY-POLICY-CORE',normalPoint)
call assertTrue normalResult~ok,'ordinary cohort still executes prior reviewed policy during canary'
call assertEqual 'HOLD',normalResult~value~disposition,'ordinary cohort remains on v1 HOLD semantics'
call assertEqual '1.0',normalResult~value~policy~version,'trace identifies v1 as operative policy'

pilotAction = makeGold('A-PROG-PILOT',subject,during)
pilotSnap = store~snapshotFor(subject,during)
pilotResult = replayer~replayPublished(pilotAction,pilotSnap,catalog,'SECURITY-POLICY-CORE',pilotPoint)
call assertTrue pilotResult~ok,'pilot cohort executes successor reviewed policy'
call assertEqual 'REVIEW_REQUIRED',pilotResult~value~disposition,'pilot receives v2 review semantics'
call assertEqual '2.0',pilotResult~value~policy~version,'trace identifies v2 canary policy'

cutoverAt = rolloutStart + .InstitutionalPolicyTime~seconds(20)
call deploy catalog,v2,'SEC-V2-ACTIVE',globalScope,'ACTIVE',cutoverAt,'promote v2 after canary evidence','SEC-CHG-803',now
cutAction = makeGold('A-PROG-CUT',subject,cutoverAt + .InstitutionalPolicyTime~seconds(1))
cutSnap = store~snapshotFor(subject,cutAction~intendedAt)
cutResult = replayer~replayPublished(cutAction,cutSnap,catalog,'SECURITY-POLICY-CORE',normalPoint)
call assertTrue cutResult~ok,'broad cutover selects successor policy'
call assertEqual '2.0',cutResult~value~policy~version,'cutover selects v2'
call assertEqual 'REVIEW_REQUIRED',cutResult~value~disposition,'v2 business effect visible after cutover'

rollbackAt = cutoverAt + .InstitutionalPolicyTime~seconds(20)
call deploy catalog,v1,'SEC-V1-ROLLBACK',globalScope,'ACTIVE',rollbackAt,'rollback exact prior reviewed policy','SEC-INC-804',now
rollbackAction = makeGold('A-PROG-ROLLBACK',subject,rollbackAt + .InstitutionalPolicyTime~seconds(1))
rollbackSnap = store~snapshotFor(subject,rollbackAction~intendedAt)
rollbackResult = replayer~replayPublished(rollbackAction,rollbackSnap,catalog,'SECURITY-POLICY-CORE',normalPoint)
call assertTrue rollbackResult~ok,'rollback routes to exact prior reviewed policy'
call assertEqual '1.0',rollbackResult~value~policy~version,'rollback policy identity is v1'
call assertEqual 'HOLD',rollbackResult~value~disposition,'prior HOLD semantics restored without regenerating policy'

historical = replayer~replayPublished(normalAction,normalSnap,catalog,'SECURITY-POLICY-CORE',normalPoint)
call assertTrue historical~ok,'later rollback binding does not rewrite historical canary period'
call assertEqual '1.0',historical~value~policy~version,'historical ordinary cohort remains on v1'

expiredAction = makeGold('A-PROG-EXPIRED',subject,rolloutEnd + .InstitutionalPolicyTime~seconds(1))
expiredSnap = store~snapshotFor(subject,expiredAction~intendedAt)
expiredResult = replayer~replayPublished(expiredAction,expiredSnap,catalog,'SECURITY-POLICY-CORE',normalPoint)
call assertTrue \expiredResult~ok,'unretired dual versions cannot outlive rollout authorization'
call assertEqual 'PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED',expiredResult~code,'expired progressive authorization is explicit'

say 'PASS test_policy_progressive_rollout_integration'
exit 0

makePolicy: procedure
  use arg version,effectiveFrom,disposition,supersedes
  p = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE',version,effectiveFrom,.nil,'SECURITY_TEAM','RISK_COMMITTEE',supersedes)
  r = .SecurityPolicyRule~new('PAY-031',100,'PURCHASE',disposition,'high-value stored payment under identity-continuity concern')
  r~requireFinding('GEO_CONTINUITY_ANOMALY')
  r~addCriterion('PAYMENT_INSTRUMENT','EQ','STORED')
  r~addCriterion('ASSET_CLASS','EQ','HIGH_VALUE_LIQUID_ASSET')
  r~addCriterion('AMOUNT','GE',20000)
  r~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED','TRANSACTION')
  ignored = p~addRule(r~seal)
  return p~seal

deploy: procedure
  use arg catalog,policy,id,scope,mode,effectiveFrom,reason,evidence,requestedAt
  req = .InstitutionalPolicyDeploymentRequest~new(id,policy,'PLATFORM_RELEASE',scope,mode,effectiveFrom,.nil,reason,evidence,requestedAt)
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
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'SecurityEffect.cls'
