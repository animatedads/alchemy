say 'LIBRARIAN CONSISTENCY PROVENANCE START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'
factory = .LibrarianDeterministicAnalyzerFactory~new(topics)
modelManifest = .LibrarianDeterministicFixture~buildModelManifest(root, topics)
provider = .LibrarianTextAlgorithmProvider~new(factory, 'LIBRARIAN-FIXTURE', '1', modelManifest, root)
engine = .AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'

schema = .AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID', 'TEXT', .false)
schema~add('TEXT', 'TEXT', .false)

frozenGrade = .AlgorithmInputConsistencyDescriptor~new('FROZEN_OBSERVATION', 0, '', '', .array~of('TEST=FROZEN'))
sourceGrade = .AlgorithmInputConsistencyDescriptor~new('SOURCE_SNAPSHOT', 1, '', 'TEST-SNAPSHOT-1', .array~of('TEST=SOURCE'))
frozen = makeInput(schema, frozenGrade)
source = makeInput(schema, sourceGrade)
call AssertTrue frozen~contentHash = source~contentHash, 'same text content identity'
call AssertTrue frozen~consistencyHash \= source~consistencyHash, 'consistency identity differs'

ctx1 = .AlgorithmExecutionContext~new('LIB-CONS-1', frozen~sourceOid)
r1 = engine~execute('LIBRARIAN_TEXT', frozen, ctx1)
call AssertTrue r1 \== .nil, 'frozen result'
hit1 = r1~relation('LIBRARIAN_TARGET_HITS')~rows[1]
doc1 = r1~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows[1]
call AssertTrue hit1~value('INPUT_CONSISTENCY_GRADE') = 'FROZEN_OBSERVATION', 'hit carries frozen grade'
call AssertTrue hit1~value('INPUT_CONSISTENCY_HASH') = frozen~consistencyHash, 'hit carries frozen hash'
call AssertTrue doc1~value('INPUT_CONSISTENCY_GRADE') = 'FROZEN_OBSERVATION', 'document carries frozen grade'

ctx2 = .AlgorithmExecutionContext~new('LIB-CONS-2', source~sourceOid)
r2 = engine~execute('LIBRARIAN_TEXT', source, ctx2)
call AssertTrue r2 \== .nil, 'source result'
hit2 = r2~relation('LIBRARIAN_TARGET_HITS')~rows[1]
doc2 = r2~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows[1]
call AssertTrue hit2~value('INPUT_CONSISTENCY_GRADE') = 'SOURCE_SNAPSHOT', 'hit carries source grade'
call AssertTrue hit2~value('INPUT_CONSISTENCY_HASH') = source~consistencyHash, 'hit carries source hash'
call AssertTrue doc2~value('INPUT_CONSISTENCY_GRADE') = 'SOURCE_SNAPSHOT', 'document carries source grade'
call AssertTrue r1~materializationId \= r2~materializationId, 'temporal evidence changes Librarian materialization identity'
call AssertTrue provider~invocationCount = 2, 'two temporal identities execute separately'

say 'frozen materialization:' r1~materializationId
say 'source materialization:' r2~materializationId
say 'LIBRARIAN CONSISTENCY PROVENANCE: OK'
exit 0

makeInput: procedure
  use arg schema, consistency
  builder = .AlgorithmInputRelationBuilder~new(schema, 'LIBRARIAN_TEXT_SOURCE', .AlgorithmInputRelationConstant~BAG_UNORDERED)
  values = .directory~new
  values['DOCUMENT_ID'] = 'DOC-CONSISTENCY'
  values['TEXT'] = 'Warning danger.'
  call AssertTrue builder~addValues(values), 'input row accepted'
  return builder~freeze('', 'SAME TEXT QUERY', 'TEST', consistency)

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
