say 'TABLE FEED DECISION PROVIDER START'

inputSchema = .AlgorithmSchema~new('TABLE_FEED_SOURCE')
inputSchema~add('ROW_ID', 'TEXT', .false)
inputSchema~add('LABEL', 'TEXT', .false)
inputSchema~add('PREFERENCE_SCORE', 'NUMBER', .false)
inputSchema~addEnum('UPSTREAM_DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))

builder = .AlgorithmInputRelationBuilder~new(inputSchema)
call addInput builder, 'BIG_UPSELL', 'big', 1000000, 'PROHIBITED'
call addInput builder, 'WARNING', 'warn', -1000000, 'REQUIRED'
call addInput builder, 'SELL_PRODUCT', 'sell', 10, 'SUPPRESSED'
call addInput builder, 'ANSWER_QUERY', 'answer', 10, 'PERMITTED'
snapshot = builder~freeze('TABLE-SNAPSHOT-1', 'TEST', 'UNIT')
call assert snapshot \== .nil, 'input snapshot'

provider = .TableFeedDecisionProvider~new('..')
engine = .AlgorithmRelationEngine~new
call assert engine~addProvider(provider), 'register table feed provider'
ctx = .AlgorithmExecutionContext~new('TABLE-FEED-INV-1', snapshot~sourceOid, snapshot~sourceOid)
algorithmResult = engine~execute('TABLE_FEED_DECIDER', snapshot, ctx)
call assert algorithmResult \== .nil, 'algorithm result'
call assert algorithmResult~validate~items = 0, 'algorithm result validates'
call assert provider~invocationCount = 1, 'provider invoked once'

decisions = algorithmResult~relation('TABLE_FEED_DECISIONS')
call assert decisions~rows~items = 4, 'four decision rows'
call assert find(decisions, 'BIG_UPSELL')~value('PROVISIONAL_SELECTED') = .true, 'big upsell provisionally selected'
call assert find(decisions, 'BIG_UPSELL')~value('DISPOSITION') = 'PROHIBITED', 'big upsell prohibited'
call assert find(decisions, 'BIG_UPSELL')~value('FINAL_SELECTED') = .false, '+1m cannot defeat prohibition'
call assert find(decisions, 'WARNING')~value('PROVISIONAL_SELECTED') = .false, 'warning provisionally rejected'
call assert find(decisions, 'WARNING')~value('DISPOSITION') = 'REQUIRED', 'warning required'
call assert find(decisions, 'WARNING')~value('FINAL_SELECTED') = .true, '-1m cannot defeat requirement'
call assert find(decisions, 'SELL_PRODUCT')~value('DISPOSITION') = 'SUPPRESSED', 'sell remains suppressed'
call assert find(decisions, 'ANSWER_QUERY')~value('FINAL_SELECTED') = .true, 'permitted positive score elected'

ctx2 = .AlgorithmExecutionContext~new('TABLE-FEED-INV-2', snapshot~sourceOid, snapshot~sourceOid)
replay = engine~execute('TABLE_FEED_DECIDER', snapshot, ctx2)
call assert provider~invocationCount = 1, 'audit replay does not rerun provider'
call assert replay~providerExecutionId == algorithmResult~providerExecutionId, 'replay preserves provider execution id'

say 'materialization:' algorithmResult~materializationId
say 'TABLE FEED DECISION PROVIDER: OK'
exit 0

addInput: procedure
  use arg builder, rowId, label, score, disposition
  values = .directory~new
  values['ROW_ID'] = rowId
  values['LABEL'] = label
  values['PREFERENCE_SCORE'] = score
  values['UPSTREAM_DISPOSITION'] = disposition
  added = builder~addValues(values)
  if \added then do
    say 'ASSERT FAILED: add input' rowId
    exit 1
  end
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
  say 'ASSERT FAILED:' message
  exit 1

::requires '../algorithm/TableFeedDecisionProvider.cls'
