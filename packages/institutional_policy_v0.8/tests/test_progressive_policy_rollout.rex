now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(3600)

profile = .InstitutionalPolicyAuthorityProfile~new('ROLLOUT-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-DEP','PLATFORM_RELEASE','DEPLOY','OPS-POLICY',start,.nil,'POLICY_BOARD','AUTH:G-DEP')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,deployEval)

v1 = .InstitutionalPolicyRelease~new('OPS-POLICY','1.0',start,.nil,'POLICY_AUTHOR','POLICY_APPROVER','',.nil,'OPS-PAYLOAD-V1')~seal
call assertTrue catalog~publish(v1)~ok,'v1 published'

v2 = .InstitutionalPolicyRelease~new('OPS-POLICY','2.0',rolloutStart,.nil,'POLICY_AUTHOR','POLICY_APPROVER','1.0',.nil,'OPS-PAYLOAD-V2')~seal
plainOverlap = catalog~publish(v2)
call assertTrue \plainOverlap~ok,'overlap still forbidden without explicit progressive authorization'
call assertEqual 'POLICY_EFFECTIVE_RANGE_OVERLAP',plainOverlap~code,'ordinary publish remains strict'

badRollout = .InstitutionalPolicyProgressiveRequest~new('ROLLOUT-BAD',v1,v2,'RANDOM_USER',rolloutEnd,'unauthorized overlap','CHG-BAD',now)
badPublish = catalog~publish(v2,.nil,badRollout)
call assertTrue \badPublish~ok,'unauthorized progressive overlap rejected'
call assertEqual 'DEPLOYMENT_AUTHORITY_DENIED',badPublish~code,'progressive overlap requires deploy authority'

rollout = .InstitutionalPolicyProgressiveRequest~new('ROLLOUT-001',v1,v2,'PLATFORM_RELEASE',rolloutEnd,'bounded v1 to v2 production rollout','CHG-200',now)
call assertTrue catalog~publish(v2,.nil,rollout)~ok,'authorized bounded progressive overlap published'
rolloutRecord = catalog~progressiveBinding('OPS-POLICY','2.0')
call assertTrue rolloutRecord~ok,'progressive authorization evidence retained'
call assertEqual 'G-DEP',rolloutRecord~value~authorityDecision~grantId,'exact deploy grant retained on rollout evidence'
call assertEqual v1~semanticIdentity,rolloutRecord~value~priorIdentity,'prior exact semantic identity retained'
call assertEqual v2~semanticIdentity,rolloutRecord~value~nextIdentity,'next exact semantic identity retained'

normalPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL')
pilotPoint = .InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','PILOT')
globalScope = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new('PILOT','COMMERCE','GB','WEB','*','PILOT')~seal

before = catalog~resolveForContext('OPS-POLICY',normalPoint,now + .InstitutionalPolicyTime~seconds(5))
call assertTrue before~ok,'before successor effective time v1 remains operative'
call assertEqual '1.0',before~value~version,'pre-rollout version is v1'

stageReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-STAGE',v2,'PLATFORM_RELEASE',globalScope,'STAGED',rolloutStart,.nil,'stage v2 globally','CHG-201',now)
call assertTrue catalog~applyDeployment('OPS-POLICY','2.0',stageReq)~ok,'v2 staged globally'
canaryReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-PILOT',v2,'PLATFORM_RELEASE',pilotScope,'CANARY',rolloutStart,.nil,'v2 pilot canary','CHG-202',now)
call assertTrue catalog~applyDeployment('OPS-POLICY','2.0',canaryReq)~ok,'v2 pilot canary recorded'

during = rolloutStart + .InstitutionalPolicyTime~seconds(5)
normalDuring = catalog~resolveForContext('OPS-POLICY',normalPoint,during)
call assertTrue normalDuring~ok,'staged successor does not displace v1 for ordinary cohort'
call assertEqual '1.0',normalDuring~value~version,'ordinary cohort remains on v1'
pilotDuring = catalog~resolveForContext('OPS-POLICY',pilotPoint,during)
call assertTrue pilotDuring~ok,'pilot cohort routes to canary successor'
call assertEqual '2.0',pilotDuring~value~version,'pilot receives v2'

missingPoint = catalog~resolve('OPS-POLICY',during)
call assertTrue \missingPoint~ok,'overlapping versions cannot resolve without deployment context'
call assertEqual 'DEPLOYMENT_POINT_REQUIRED',missingPoint~code,'progressive overlap requires deployment point'

cutoverAt = rolloutStart + .InstitutionalPolicyTime~seconds(20)
cutoverReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V2-ACTIVE',v2,'PLATFORM_RELEASE',globalScope,'ACTIVE',cutoverAt,.nil,'promote v2 globally','CHG-203',now)
call assertTrue catalog~applyDeployment('OPS-POLICY','2.0',cutoverReq)~ok,'global v2 cutover binding recorded'
afterCutover = catalog~resolveForContext('OPS-POLICY',normalPoint,cutoverAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue afterCutover~ok,'global cutover selects v2'
call assertEqual '2.0',afterCutover~value~version,'ordinary cohort now on v2'

rollbackAt = cutoverAt + .InstitutionalPolicyTime~seconds(20)
rollbackReq = .InstitutionalPolicyDeploymentRequest~new('DEP-V1-ROLLBACK',v1,'PLATFORM_RELEASE',globalScope,'ACTIVE',rollbackAt,.nil,'rollback to reviewed v1','INC-ROLLBACK',now)
call assertTrue catalog~applyDeployment('OPS-POLICY','1.0',rollbackReq)~ok,'rollback binding to old reviewed version recorded'
afterRollback = catalog~resolveForContext('OPS-POLICY',normalPoint,rollbackAt + .InstitutionalPolicyTime~seconds(1))
call assertTrue afterRollback~ok,'later equally-specific old-version binding performs rollback'
call assertEqual '1.0',afterRollback~value~version,'rollback selects v1'

historicalDuring = catalog~resolveForContext('OPS-POLICY',normalPoint,during)
call assertTrue historicalDuring~ok,'future rollback binding does not rewrite earlier topology history'
call assertEqual '1.0',historicalDuring~value~version,'historical pre-cutover route remains v1'

expired = catalog~resolveForContext('OPS-POLICY',normalPoint,rolloutEnd + .InstitutionalPolicyTime~seconds(1))
call assertTrue \expired~ok,'dual-version operation cannot continue beyond bounded authorization without cleanup'
call assertEqual 'PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED',expired~code,'expired overlap authorization explicit'

say 'PASS test_progressive_policy_rollout'
exit 0

assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
