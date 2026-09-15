say 'TABLE FEED AUTHORITY MATRIX START'

schema = .AlgorithmSchema~new('TABLE_FEED_SOURCE')
schema~add('ROW_ID', 'TEXT', .false)
schema~add('LABEL', 'TEXT', .false)
schema~add('PREFERENCE_SCORE', 'NUMBER', .false)
schema~addEnum('UPSTREAM_DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))

builder = .AlgorithmInputRelationBuilder~new(schema)
dispositions = .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL')
scores = .array~of(-1000000, 0, 1000000)
expectedRows = 0

do disposition over dispositions
  do score over scores
    expectedRows = expectedRows + 1
    values = .directory~new
    values['ROW_ID'] = disposition || '_' || score
    values['LABEL'] = 'matrix'
    values['PREFERENCE_SCORE'] = score
    values['UPSTREAM_DISPOSITION'] = disposition
    call assert builder~addValues(values), 'matrix input add'
  end
end
snapshot = builder~freeze('', '', 'AUTHORITY_MATRIX')
call assert snapshot~rowCount = 18, '18 input vectors'

provider = .TableFeedDecisionProvider~new('..')
engine = .AlgorithmRelationEngine~new
call assert engine~addProvider(provider), 'provider registration'
ctx = .AlgorithmExecutionContext~new('AUTHORITY-MATRIX-1', snapshot~sourceOid, snapshot~sourceOid)
algorithmResult = engine~execute('TABLE_FEED_DECIDER', snapshot, ctx)
call assert algorithmResult~validate~items = 0, 'matrix output validates'
decisions = algorithmResult~relation('TABLE_FEED_DECISIONS')
call assert decisions~rows~items = 18, '18 output vectors'

checked = 0
do decisionRow over decisions~rows
  checked = checked + 1
  upstream = decisionRow~value('UPSTREAM_DISPOSITION')
  score = decisionRow~value('PREFERENCE_SCORE')
  finalSelected = decisionRow~value('FINAL_SELECTED')
  disposition = decisionRow~value('DISPOSITION')

  select
    when upstream == 'PROHIBITED' then do
      call assert disposition == 'PROHIBITED', 'prohibition preserved'
      call assert finalSelected = .false, 'prohibition never score-selected'
    end
    when upstream == 'REQUIRED' then do
      call assert disposition == 'REQUIRED', 'requirement preserved'
      call assert finalSelected = .true, 'requirement always selected'
    end
    when upstream == 'SUPPRESSED' then do
      call assert disposition == 'SUPPRESSED', 'suppression preserved'
      call assert finalSelected = .false, 'suppression never elected'
    end
    when upstream == 'REQUIRES_APPROVAL' then do
      call assert disposition == 'REQUIRES_APPROVAL', 'approval gate preserved'
      call assert finalSelected = .false, 'approval-gated action not elected without approval'
    end
    when upstream == 'PERMITTED' then do
      call assert disposition == 'PERMITTED', 'permission preserved'
      expected = score > 0
      call assert finalSelected = expected, 'permission follows score election'
    end
    otherwise do
      call assert upstream == 'UNRESOLVED', 'only unresolved remains'
      call assert disposition == 'UNRESOLVED', 'unresolved preserved'
      call assert finalSelected = .false, 'unresolved fails closed'
    end
  end
end
call assert checked = 18, 'all vectors checked'
call assert provider~invocationCount = 1, 'matrix evaluated in one provider invocation'

say 'vectors:' checked
say 'holes: 0'
say 'TABLE FEED AUTHORITY MATRIX: OK'
exit 0

assert: procedure
  use arg condition, message
  if condition then return .true
  say 'ASSERT FAILED:' message
  exit 1

::requires '../algorithm/TableFeedDecisionProvider.cls'
