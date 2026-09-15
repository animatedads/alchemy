say 'TABLE FEED CONSISTENCY GATE START'

inputSchema = .AlgorithmSchema~new('TABLE_FEED_SOURCE')
inputSchema~add('ROW_ID', 'TEXT', .false)
inputSchema~add('LABEL', 'TEXT', .false)
inputSchema~add('PREFERENCE_SCORE', 'NUMBER', .false)
inputSchema~addEnum('UPSTREAM_DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))

frozenGrade = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION, 0, '', '', .array~of('FEDERATED_OBSERVATION'))
sourceGrade = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT, 1, '', 'SOURCE-GEN-7', .array~of('ONE_SOURCE_AT_GENERATION_7'))

frozenSnapshot = makeSnapshot(inputSchema, frozenGrade)
sourceSnapshot = makeSnapshot(inputSchema, sourceGrade)
call assert frozenSnapshot~contentHash == sourceSnapshot~contentHash, 'same rows across grades'

/* Strict consumer: frozen observation is insufficient, so no authority is emitted. */
strictProvider = .TableFeedDecisionProvider~new('..', .AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT)
strictEngine = .AlgorithmRelationEngine~new
call assert strictEngine~addProvider(strictProvider), 'register strict provider'
catalog = strictEngine~catalog
call assert strictProvider~invocationCount = 0, 'catalog remains observational'
call assert pos('MIN_CONSISTENCY=SOURCE_SNAPSHOT', catalog~rows[1]~value('INPUT_CONTRACT')) > 0, 'minimum consistency visible in provider metadata'
ctx1 = .AlgorithmExecutionContext~new('STRICT-FROZEN', frozenSnapshot~sourceOid, frozenSnapshot~sourceOid)
r1 = strictEngine~execute('TABLE_FEED_DECIDER', frozenSnapshot, ctx1)
call assert r1 \== .nil, 'strict frozen result'
d1 = r1~relation('TABLE_FEED_DECISIONS')
call assert find(d1, 'BIG_UPSELL')~value('DISPOSITION') = 'UNRESOLVED', 'prohibition not asserted from insufficient temporal evidence'
call assert find(d1, 'WARNING')~value('DISPOSITION') = 'UNRESOLVED', 'requirement not asserted from insufficient temporal evidence'
call assert find(d1, 'BIG_UPSELL')~value('FINAL_SELECTED') = .false, 'insufficient grade selects nothing'
call assert find(d1, 'WARNING')~value('FINAL_SELECTED') = .false, 'insufficient grade cannot force action'
call assert find(d1, 'WARNING')~value('REASON') = 'INPUT_CONSISTENCY_INSUFFICIENT', 'explicit insufficiency reason'
call assert find(d1, 'WARNING')~value('INPUT_CONSISTENCY_GRADE') = 'FROZEN_OBSERVATION', 'actual grade visible'
call assert find(d1, 'WARNING')~value('REQUIRED_CONSISTENCY_GRADE') = 'SOURCE_SNAPSHOT', 'required grade visible'

/* Same typed rows, stronger evidence: normal score-vs-authority semantics resume. */
ctx2 = .AlgorithmExecutionContext~new('STRICT-SOURCE', sourceSnapshot~sourceOid, sourceSnapshot~sourceOid)
r2 = strictEngine~execute('TABLE_FEED_DECIDER', sourceSnapshot, ctx2)
call assert r2 \== .nil, 'strict source result'
d2 = r2~relation('TABLE_FEED_DECISIONS')
call assert find(d2, 'BIG_UPSELL')~value('DISPOSITION') = 'PROHIBITED', 'source snapshot permits hard prohibition evaluation'
call assert find(d2, 'BIG_UPSELL')~value('FINAL_SELECTED') = .false, '+1m still loses to prohibition'
call assert find(d2, 'WARNING')~value('DISPOSITION') = 'REQUIRED', 'source snapshot permits requirement evaluation'
call assert find(d2, 'WARNING')~value('FINAL_SELECTED') = .true, '-1m still loses to requirement'
call assert r1~materializationId \== r2~materializationId, 'same rows different consistency produce different algorithm materialization identity'
call assert strictProvider~invocationCount = 2, 'two consistency identities execute separately'

say 'frozen materialization:' r1~materializationId
say 'source materialization:' r2~materializationId
say 'TABLE FEED CONSISTENCY GATE: OK'
exit 0

makeSnapshot: procedure
  use arg schema, consistency
  builder = .AlgorithmInputRelationBuilder~new(schema)
  call addInput builder, 'BIG_UPSELL', 'big', 1000000, 'PROHIBITED'
  call addInput builder, 'WARNING', 'warn', -1000000, 'REQUIRED'
  return builder~freeze('', 'SAME QUERY', 'CONSISTENCY_TEST', consistency)

addInput: procedure
  use arg builder, rowId, label, score, disposition
  values = .directory~new
  values['ROW_ID'] = rowId
  values['LABEL'] = label
  values['PREFERENCE_SCORE'] = score
  values['UPSTREAM_DISPOSITION'] = disposition
  if \builder~addValues(values) then raise syntax 93.900 additional('Unable to add input row:' rowId)
  return .true

find: procedure
  use arg relation, wanted
  do decisionRow over relation~rows
    if decisionRow~value('ROW_ID') == wanted then return decisionRow
  end
  return .nil

assert: procedure
  use arg condition, message
  if condition then return .true
  raise syntax 93.900 additional('ASSERT FAILED:' message)

::requires '../algorithm/TableFeedDecisionProvider.cls'
