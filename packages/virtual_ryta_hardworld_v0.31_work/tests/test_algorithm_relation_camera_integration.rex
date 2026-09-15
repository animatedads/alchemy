/*
 * External CameraCore v0.20 integration test.
 * Run through tests/run_camera_integration.sh with CAMERA_CORE_DIR set.
 */

say 'ALGORITHM RELATION CAMERA V0.4 START'

camera = .CameraModel~new('ALGREL-CAMERA', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))

x1 = camera~transitionModel~learn('M1', 'M2')
x2 = camera~transitionModel~learn('M2', 'M3')
call assertEqual 'x1 id', 'X1', x1~id
call assertEqual 'x2 id', 'X2', x2~id

do sampleIndex = 1 to 24
  observedWeight = camera~behaviour~observeTransition(15 * 60, 'X1')
end
do sampleIndex = 1 to 2
  observedWeight = camera~behaviour~observeTransition(15 * 60, 'X2')
end

conditionModel = .CameraCurrentConditionModel~new(300, 4, 1.0)
do occurrenceIndex = 1 to 6
  occurrence = .CameraMotifTransitionOccurrence~new('X2', 'M2', 'M3', (15 * 60) + occurrenceIndex * 20)
  observedCount = conditionModel~observeOccurrence(occurrence)
end
condition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, (15 * 60) + 130, 3)
call assertEqual 'source camera algorithm shifted', .CameraConstant~CONDITION_SHIFTED, condition~state

/* Add a public CameraConditionMetricSignal so the second relation is exercised. */
signal = .CameraConditionMetricSignal~new('INTERACTION_RATE')
signal~sampleCount = 3
signal~averageZ = 3.25
signal~maximumAbsoluteZ = 4.1
signal~elevated = .true
signal~baselineContext = 'ALL'
condition~addMetricSignal(signal)
condition~usableMetricCount = condition~usableMetricCount + 1
condition~elevatedMetricCount = condition~elevatedMetricCount + 1

provider = .CameraCurrentConditionAlgorithmProvider~new('0.20', '..', '..')
engine = .AlgorithmRelationEngine~new
call assertTrue 'camera provider registration', engine~addProvider(provider)
catalog = engine~catalog
call assertEqual 'camera catalog has two declared relations', 2, catalog~rows~items
call assertEqual 'metadata discovery does not invoke camera adapter', 0, provider~invocationCount
call assertEqual 'camera source manifest is file hashed', 'FILE_HASHED', provider~sourceManifestMode
call assertTrue 'camera source manifest hash populated', provider~sourceManifestHash~length == 64
schemaCatalog = engine~schemaCatalog
call assertTrue 'camera schema catalog populated', schemaCatalog~rows~items > 10
call assertEqual 'camera schema discovery does not invoke camera adapter', 0, provider~invocationCount
context = .AlgorithmExecutionContext~new('CAMERA-INV-1', 'CAMERA-CONDITION-OID-1')
algorithmResult = engine~execute('CAMERA_CURRENT_CONDITION', condition, context)
call assertTrue 'camera algorithm result exists', algorithmResult \== .nil
call assertEqual 'camera provider invoked once', 1, provider~invocationCount
call assertEqual 'camera relation validation', 0, algorithmResult~validationErrors~items

conditionRelation = algorithmResult~relation('CAMERA_CURRENT_CONDITION')
call assertTrue 'condition relation exists', conditionRelation \== .nil
call assertEqual 'one condition row', 1, conditionRelation~rows~items
conditionRow = conditionRelation~rows[1]
call assertEqual 'condition state text', 'SHIFTED', conditionRow~value('CONDITION_STATE')
call assertEqual 'condition state code', .CameraConstant~CONDITION_SHIFTED, conditionRow~value('CONDITION_STATE_CODE')
call assertEqual 'transition count retained', 6, conditionRow~value('TRANSITION_COUNT')
call assertTrue 'excess surprise retained', conditionRow~value('EXCESS_SURPRISE_BITS') > 0

signalRelation = algorithmResult~relation('CAMERA_METRIC_SIGNALS')
call assertTrue 'metric relation exists', signalRelation \== .nil
call assertEqual 'one metric signal row', 1, signalRelation~rows~items
signalRow = signalRelation~rows[1]
call assertEqual 'metric name retained', 'INTERACTION_RATE', signalRow~value('METRIC_NAME')
call assertEqual 'metric elevated retained', .true, signalRow~value('ELEVATED')

sameResult = engine~execute('CAMERA_CURRENT_CONDITION', condition, context)
call assertTrue 'camera rescan is same materialization', sameResult == algorithmResult
call assertEqual 'camera provider not rerun on rescan', 1, provider~invocationCount

newInvocation = .AlgorithmExecutionContext~new('CAMERA-INV-2', 'CALLER-OID-CHANGED')
replayResult = engine~execute('CAMERA_CURRENT_CONDITION', condition, newInvocation)
call assertEqual 'same camera content reuses materialization across audit ids', 1, provider~invocationCount
call assertEqual 'camera content key reused', algorithmResult~materializationKey, replayResult~materializationKey
call assertEqual 'camera replay invocation rebound', 'CAMERA-INV-2', replayResult~relation('CAMERA_CURRENT_CONDITION')~rows[1]~value('INVOCATION_ID')

condition~strongestMetricZ = condition~strongestMetricZ + 0.25
changedResult = engine~execute('CAMERA_CURRENT_CONDITION', condition, context)
call assertEqual 'changed camera content reruns provider despite same caller oid', 2, provider~invocationCount
call assertTrue 'changed camera input hash differs', changedResult~canonicalInputHash \== algorithmResult~canonicalInputHash

say 'ALGORITHM RELATION CAMERA V0.4: OK'
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

::requires '../CameraCore.cls'
::requires '../integration/CameraCurrentConditionAlgorithmProvider.cls'
::requires '../algorithm/AlgorithmRelation.cls'
