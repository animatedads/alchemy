/* Camera v0.20 through the generic NoSQLServer v0.68 Algorithm Relation external engine. */
parse arg root
if root == '' then do
  say 'database root required'
  exit 2
end

say 'CAMERA V0.20 NOSQLSERVER V0.68 EXTERNAL ENGINE START'

camera = .CameraModel~new('ALGREL-CAMERA-SQL', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
x1 = camera~transitionModel~learn('M1', 'M2')
x2 = camera~transitionModel~learn('M2', 'M3')
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
call assert condition~state = .CameraConstant~CONDITION_SHIFTED, 'source Camera condition shifted'

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
algorithmEngine = .AlgorithmRelationEngine~new
call assert algorithmEngine~addProvider(provider), 'camera provider registration'
ctx = .AlgorithmExecutionContext~new('CAMERA-SQL-INV-1', 'CAMERA-CONDITION-OID-SQL-1', 'CAMERA-CONDITION-OID-SQL-1')

nosqlClasses = .directory~new
nosqlClasses['TABLE_DEFINITION'] = .TableDefinition
nosqlClasses['DATABASE_ROW'] = .DatabaseRow
nosqlClasses['DATABASE_RESULT'] = .DatabaseResult
nosqlClasses['TABLE_METADATA'] = .DatabaseTableMetadata
bindings = .directory~new
bindings['CAMERA_CURRENT_CONDITION'] = 'camera_condition'
bindings['CAMERA_METRIC_SIGNALS'] = 'camera_signals'
external = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'CAMERA_CURRENT_CONDITION', condition, ctx, nosqlClasses, bindings)
call assert external~isReady, 'camera external engine ready' external~lastError
call assert provider~invocationCount = 0, 'camera registration does not invoke provider'

fed = .FederatedDatabaseEngine~new(root)
ignore = fed~addEngine(external)
sql = .NoSQLServerSQL~new(fed)

catalog = fed~readCatalog
call assert catalogHas(catalog, 'camera_condition'), 'camera condition catalogued'
call assert catalogHas(catalog, 'camera_signals'), 'camera signals catalogued'
call assert provider~invocationCount = 0, 'camera catalog discovery no execution'
meta = fed~tableMetadata('camera_condition')
call assert meta~columns~items = 21, 'camera condition schema has 21 columns'
call assert provider~invocationCount = 0, 'camera metadata no execution'

rs = sql~execute("SELECT condition_state, transition_count, excess_surprise_bits FROM camera_condition")
call ok rs
call assert rs~rows~items = 1, 'one camera condition row'
call assert rs~rows[1]['condition_state'] = 'SHIFTED', 'camera state through SQL'
call assert rs~rows[1]['transition_count'] = 6, 'camera transition count through SQL'
call assert rs~rows[1]['excess_surprise_bits'] > 0, 'camera surprise through SQL'
call assert provider~invocationCount = 1, 'camera first SQL read exactly once'

signals = sql~execute("SELECT metric_name, elevated, maximum_absolute_z FROM camera_signals")
call ok signals
call assert signals~rows~items = 1, 'one camera signal row'
call assert signals~rows[1]['metric_name'] = 'INTERACTION_RATE', 'camera metric name through SQL'
call assert signals~rows[1]['elevated'] = .true, 'camera boolean through SQL'
call assert provider~invocationCount = 1, 'second camera relation shares materialization'

call ok sql~execute("CREATE TABLE metric_labels (metric_name VARCHAR PRIMARY KEY, label VARCHAR)")
call ok sql~execute("INSERT INTO metric_labels VALUES ('INTERACTION_RATE','Interaction rate')")
joined = sql~execute("SELECT s.metric_name,l.label FROM camera_signals s JOIN metric_labels l ON s.metric_name=l.metric_name")
call ok joined
call assert joined~rows~items = 1, 'camera/persisted join row'
call assert joined~rows[1]['l.label'] = 'Interaction rate', 'camera/persisted join value'
call assert provider~invocationCount = 1, 'camera join does not rerun provider'

/* Lazy identity guard is generic: changing Camera input before first read fails closed. */
provider2 = .CameraCurrentConditionAlgorithmProvider~new('0.20', '..', '..')
algorithmEngine2 = .AlgorithmRelationEngine~new
call assert algorithmEngine2~addProvider(provider2), 'second camera provider registration'
ctx2 = .AlgorithmExecutionContext~new('CAMERA-SQL-INV-2', 'CAMERA-CONDITION-OID-SQL-2', 'CAMERA-CONDITION-OID-SQL-2')
bindings2 = .directory~new
bindings2['CAMERA_CURRENT_CONDITION'] = 'camera_mutated'
external2 = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine2, 'CAMERA_CURRENT_CONDITION', condition, ctx2, nosqlClasses, bindings2)
call assert external2~isReady, 'second camera external ready' external2~lastError
ignore = fed~addEngine(external2)
condition~strongestMetricZ = condition~strongestMetricZ + 0.25
changed = sql~execute('SELECT condition_state FROM camera_mutated')
call assert changed~error = .Error~SQLERROR, 'changed camera input rejected before execution'
call assert external2~lastError = 'INPUT_CHANGED_BEFORE_MATERIALIZATION', 'camera changed-input diagnostic'
call assert provider2~invocationCount = 0, 'changed camera input never invokes provider'

say 'camera provider invocations:' provider~invocationCount
say 'CAMERA V0.20 NOSQLSERVER V0.68 EXTERNAL ENGINE: OK'
exit 0

catalogHas: procedure
  use arg catalog, wanted
  do actual over catalog['tables']
    if actual~caselessEquals(wanted) then return .true
  end
  return .false

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say 'FAILED:' rs~status rs~error rs~message
    exit 1
  end
  return .true

assert: procedure
  use arg condition, message, detail = ''
  if condition then return .true
  say 'ASSERT FAILED:' message detail
  exit 1

::requires '../NoSQLServer.cls'
::requires '../CameraCore.cls'
::requires '../integration/CameraCurrentConditionAlgorithmProvider.cls'
::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
::requires '../algorithm/AlgorithmRelation.cls'
