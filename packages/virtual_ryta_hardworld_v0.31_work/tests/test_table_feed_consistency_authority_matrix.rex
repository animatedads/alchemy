say 'TABLE FEED CONSISTENCY / AUTHORITY MATRIX START'

grades = .array~of('FROZEN_OBSERVATION','SOURCE_SNAPSHOT','COORDINATED_SNAPSHOT')
dispositions = .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL')
scores = .array~of(-1000000, 0, 1000000)

vectors = 0
holes = 0

do requiredGrade over grades
  provider = .TableFeedDecisionProvider~new('..', requiredGrade)
  engine = .AlgorithmRelationEngine~new
  call assert engine~addProvider(provider), 'provider registration ' || requiredGrade

  do actualGrade over grades
    do upstream over dispositions
      do score over scores
        vectors = vectors + 1
        consistency = makeConsistency(actualGrade, vectors)
        snapshot = makeSnapshot(upstream, score, consistency)
        ctx = .AlgorithmExecutionContext~new('MATRIX-' || vectors, snapshot~sourceOid, snapshot~sourceOid)
        algorithmResult = engine~execute('TABLE_FEED_DECIDER', snapshot, ctx)
        if algorithmResult == .nil then do
          holes = holes + 1
          iterate
        end
        decisions = algorithmResult~relation('TABLE_FEED_DECISIONS')
        if decisions == .nil then do
          holes = holes + 1
          iterate
        end
        if decisions~rows~items \= 1 then do
          holes = holes + 1
          iterate
        end
        row = decisions~rows[1]
        sufficient = gradeRank(actualGrade) >= gradeRank(requiredGrade)
        expectedDisposition = expectedDisposition(upstream, sufficient)
        expectedFinal = expectedFinal(upstream, score, sufficient)
        if row~value('DISPOSITION') \= expectedDisposition then holes = holes + 1
        if row~value('FINAL_SELECTED') \= expectedFinal then holes = holes + 1
        if row~value('INPUT_CONSISTENCY_GRADE') \= actualGrade then holes = holes + 1
        if row~value('REQUIRED_CONSISTENCY_GRADE') \= requiredGrade then holes = holes + 1
      end
    end
  end
end

say 'vectors:' vectors
say 'holes:' holes
call assert vectors = 162, 'matrix vector count'
call assert holes = 0, 'matrix has no holes'
say 'TABLE FEED CONSISTENCY / AUTHORITY MATRIX: OK'
exit 0

makeConsistency: procedure
  use arg grade, serial
  select
    when grade = 'FROZEN_OBSERVATION' then return .AlgorithmInputConsistencyDescriptor~new(grade, 0, '', '', .array~of('MATRIX=FROZEN-' || serial))
    when grade = 'SOURCE_SNAPSHOT' then return .AlgorithmInputConsistencyDescriptor~new(grade, 1, '', 'SOURCE-' || serial, .array~of('MATRIX=SOURCE-' || serial))
    when grade = 'COORDINATED_SNAPSHOT' then return .AlgorithmInputConsistencyDescriptor~new(grade, 2, 'MATRIX_COORD', 'COORD-' || serial, .array~of('MATRIX=COORD-' || serial))
    otherwise raise syntax 93.900 additional('Unknown grade:' grade)
  end

makeSnapshot: procedure
  use arg upstream, score, consistency
  schema = .AlgorithmSchema~new('TABLE_FEED_SOURCE')
  schema~add('ROW_ID', 'TEXT', .false)
  schema~add('LABEL', 'TEXT', .false)
  schema~add('PREFERENCE_SCORE', 'NUMBER', .false)
  schema~addEnum('UPSTREAM_DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))
  builder = .AlgorithmInputRelationBuilder~new(schema)
  values = .directory~new
  values['ROW_ID'] = 'ROW'
  values['LABEL'] = 'row'
  values['PREFERENCE_SCORE'] = score
  values['UPSTREAM_DISPOSITION'] = upstream
  if \builder~addValues(values) then raise syntax 93.900 additional('Unable to add matrix input')
  return builder~freeze('', 'MATRIX', 'MATRIX', consistency)

gradeRank: procedure
  use arg grade
  if grade = 'FROZEN_OBSERVATION' then return 10
  if grade = 'SOURCE_SNAPSHOT' then return 20
  if grade = 'COORDINATED_SNAPSHOT' then return 30
  return 0

expectedDisposition: procedure
  use arg upstream, sufficient
  if \sufficient then return 'UNRESOLVED'
  if upstream = 'UNRESOLVED' then return 'UNRESOLVED'
  return upstream

expectedFinal: procedure
  use arg upstream, score, sufficient
  if \sufficient then return .false
  select
    when upstream = 'REQUIRED' then return .true
    when upstream = 'PROHIBITED' then return .false
    when upstream = 'SUPPRESSED' then return .false
    when upstream = 'REQUIRES_APPROVAL' then return .false
    when upstream = 'PERMITTED' then return score > 0
    otherwise return .false
  end

assert: procedure
  use arg condition, message
  if condition then return .true
  raise syntax 93.900 additional('ASSERT FAILED:' message)

::requires '../algorithm/TableFeedDecisionProvider.cls'
