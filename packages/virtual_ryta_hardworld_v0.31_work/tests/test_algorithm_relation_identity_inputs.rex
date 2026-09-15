/* Exact frozen-input identity: plugin set/config, approvals and policies are identity-bearing. */

say 'ALGORITHM RELATION IDENTITY INPUTS V0.4 START'

actor = .VirtualRYTA~new
provider = .RYTAAlgorithmProvider~new(actor, '..')
engine = .AlgorithmRelationEngine~new
call assertTrue 'register provider', engine~addProvider(provider)

world = .RYTAWorldState~new('WORLD-IDENTITY-1')
world~putKnown('ESSENTIAL_MEDICATION', .false)
world~putKnown('IMMEDIATE_ACCESS', .false)
world~putKnown('GUARANTEED_CUSTODY', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('BIG_UPSELL_REVIEW_REQUIRED', .true)

context1 = .AlgorithmExecutionContext~new('IDENTITY-1', 'CALLER-OID-1', world~snapshotOid)
baseResult = engine~execute('VIRTUAL_RYTA', world, context1)
call assertEqual 'base execution', 1, provider~invocationCount
baseInputHash = baseResult~canonicalInputHash
baseManifestHash = baseResult~sourceManifestHash

actor~addScorePlugin(.RYTATestExtremeScoringPlugin~new('BIG_UPSELL', 1234))
context2 = .AlgorithmExecutionContext~new('IDENTITY-2', 'CALLER-OID-1', world~snapshotOid)
pluginResult = engine~execute('VIRTUAL_RYTA', world, context2)
call assertEqual 'plugin set/config changes identity and executes provider', 2, provider~invocationCount
call assertTrue 'plugin config changes canonical input hash', pluginResult~canonicalInputHash \== baseInputHash
call assertTrue 'plugin code set changes source manifest hash', pluginResult~sourceManifestHash \== baseManifestHash

approval = .RYTAApproval~new('APP-ID-1', 'SALES_MANAGER', 'BIG_UPSELL', actor~stateRules~modelId, actor~stateRules~modelVersion, world~snapshotOid, 'DEFAULT')
actor~approvals~add(approval)
context3 = .AlgorithmExecutionContext~new('IDENTITY-3', 'CALLER-OID-1', world~snapshotOid)
approvalResult = engine~execute('VIRTUAL_RYTA', world, context3)
call assertEqual 'approval set changes identity and executes provider', 3, provider~invocationCount
call assertTrue 'approval changes canonical input hash', approvalResult~canonicalInputHash \== pluginResult~canonicalInputHash

approval~revoked = .true
context4 = .AlgorithmExecutionContext~new('IDENTITY-4', 'CALLER-OID-1', world~snapshotOid)
revokedResult = engine~execute('VIRTUAL_RYTA', world, context4)
call assertEqual 'approval revocation changes identity', 4, provider~invocationCount
call assertTrue 'revocation changes canonical input hash', revokedResult~canonicalInputHash \== approvalResult~canonicalInputHash

policy = actor~approvalPolicies~policy(.RYTAConstant~APPROVAL_POLICY_BIG_UPSELL)
policy~quorum = 2
context5 = .AlgorithmExecutionContext~new('IDENTITY-5', 'CALLER-OID-1', world~snapshotOid)
policyResult = engine~execute('VIRTUAL_RYTA', world, context5)
call assertEqual 'approval policy change changes identity', 5, provider~invocationCount
call assertTrue 'policy change changes canonical input hash', policyResult~canonicalInputHash \== revokedResult~canonicalInputHash

/* An external plugin without a source manifest fingerprint invalidates strict read-path eligibility. */
actor2 = .VirtualRYTA~new
actor2~addScorePlugin(.UnfingerprintedExternalPlugin~new)
provider2 = .RYTAAlgorithmProvider~new(actor2, '..')
call assertEqual 'unfingerprinted external plugin makes manifest incomplete', 'INCOMPLETE', provider2~sourceManifestMode
engine2 = .AlgorithmRelationEngine~new
ok = engine2~addProvider(provider2)
readOperator = .AlgorithmRelationReadOperator~new(engine2)
plan = .AlgorithmRelationReadPlan~new('VIRTUAL_RYTA', 'RYTA_ACTION_DECISIONS')
call assertTrue 'planner read path rejects incomplete source identity', readOperator~describe(plan) == .nil
call assertTrue 'rejection reason names unverified source', readOperator~lastError~pos('UNVERIFIED_SOURCE_MANIFEST') > 0
call assertEqual 'rejected metadata bind does not invoke provider', 0, provider2~invocationCount

say 'ALGORITHM RELATION IDENTITY INPUTS V0.4: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  actual:' actual
  exit 1

::class UnfingerprintedExternalPlugin public
::method pluginId
  return 'EXTERNAL_NO_FINGERPRINT'
::method pluginVersion
  return '1'
::method pluginKind
  return 'SCORE'
::method canonicalConfiguration
  return 'EXTERNAL_NO_FINGERPRINT|version=1'
::method score
  use arg world, actionCode
  return 0

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmReadOperator.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../plugins/RYTATestExtremeScoring.cls'
::requires '../HardWorld.cls'
