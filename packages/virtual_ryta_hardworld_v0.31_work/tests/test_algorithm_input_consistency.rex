say 'ALGORITHM INPUT CONSISTENCY START'

schema = .AlgorithmSchema~new('CONSISTENCY_ROWS')
schema~add('ROW_ID', 'TEXT', .false)
schema~add('VALUE', 'INTEGER', .false)
values = .directory~new
values['ROW_ID'] = 'A'
values['VALUE'] = 1

frozenEvidence = .array~of('CAPTURE=FEDERATED_QUERY','ATOMICITY=NOT_CLAIMED')
frozenGrade = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION, 0, '', '', frozenEvidence)
sourceEvidence = .array~of('SOURCE=FILE_ENGINE','SNAPSHOT_GENERATION=42')
sourceGrade = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT, 1, '', 'GENERATION:42', sourceEvidence)
coordinatedEvidence = .array~of('SOURCE_A=GEN42','SOURCE_B=TOKEN7')
coordinatedGrade = .AlgorithmInputConsistencyDescriptor~new(.AlgorithmInputConsistencyConstant~COORDINATED_SNAPSHOT, 2, 'TEST_COORDINATOR', 'COORD:ABC', coordinatedEvidence)

call assert frozenGrade~rank = 10, 'frozen rank'
call assert sourceGrade~rank = 20, 'source rank'
call assert coordinatedGrade~rank = 30, 'coordinated rank'
call assert \frozenGrade~satisfies(.AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT), 'frozen does not satisfy source snapshot'
call assert sourceGrade~satisfies(.AlgorithmInputConsistencyConstant~FROZEN_OBSERVATION), 'source satisfies frozen'
call assert coordinatedGrade~satisfies(.AlgorithmInputConsistencyConstant~SOURCE_SNAPSHOT), 'coordinated satisfies source'

b1 = .AlgorithmInputRelationBuilder~new(schema)
call assert b1~addValues(values), 'add frozen row'
s1 = b1~freeze('', 'SELECT A', 'SAME_CONTENT', frozenGrade)
call assert s1 \== .nil, 'freeze frozen observation'

b2 = .AlgorithmInputRelationBuilder~new(schema)
call assert b2~addValues(values), 'add source row'
s2 = b2~freeze('', 'SELECT A', 'SAME_CONTENT', sourceGrade)
call assert s2 \== .nil, 'freeze source snapshot'

call assert s1~contentHash == s2~contentHash, 'consistency does not contaminate row content hash'
call assert s1~sourceOid == s2~sourceOid, 'content-addressed source oid remains row-content identity'
call assert s1~consistencyHash \== s2~consistencyHash, 'consistency evidence has independent identity'
call assert s1~algorithmCanonicalText \== s2~algorithmCanonicalText, 'algorithm-visible input includes consistency context'
call assert s1~consistencyGrade = 'FROZEN_OBSERVATION', 'frozen grade projected'
call assert s2~consistencyGrade = 'SOURCE_SNAPSHOT', 'source grade projected'
call assert \s1~meetsConsistency('SOURCE_SNAPSHOT'), 'snapshot gate sees insufficiency'
call assert s2~meetsConsistency('SOURCE_SNAPSHOT'), 'snapshot gate accepts source snapshot'

say 'content hash:' s1~contentHash
say 'frozen consistency:' s1~consistencyHash
say 'source consistency:' s2~consistencyHash
say 'ALGORITHM INPUT CONSISTENCY: OK'
exit 0

assert: procedure
  use arg condition, message
  if condition then return .true
  raise syntax 93.900 additional('ASSERT FAILED:' message)

::requires '../algorithm/AlgorithmInputRelation.cls'
