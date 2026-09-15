say 'ALGORITHM RELATION LIBRARIAN START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'
factory = .LibrarianDeterministicAnalyzerFactory~new(topics)
modelManifest = .LibrarianDeterministicFixture~buildModelManifest(root, topics)
modelFingerprint = modelManifest~hash
provider = .LibrarianTextAlgorithmProvider~new(factory, 'LIBRARIAN-FIXTURE', '1', modelManifest, root)
engine = .AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'

-- Catalog and schema are observational only.
catalog = engine~catalog
schemaCatalog = engine~schemaCatalog
call AssertTrue provider~invocationCount = 0, 'metadata must not execute Librarian'
call AssertTrue provider~sourceManifestMode = 'FILE_HASHED', 'source manifest must be file hashed'
call AssertTrue provider~determinism = .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT, 'determinism contract'
call AssertTrue catalog~rows~items = 8, 'eight declared Librarian relations'

inputSchema = .AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
inputSchema~add('DOCUMENT_ID', 'TEXT', .false)
inputSchema~add('TEXT', 'TEXT', .false)
builder = .AlgorithmInputRelationBuilder~new(inputSchema, 'LIBRARIAN_TEXT_SOURCE', .AlgorithmInputRelationConstant~BAG_UNORDERED)
values = .directory~new
values['DOCUMENT_ID'] = 'DOC-ALG-1'
values['TEXT'] = 'We sell product. Warning danger. Medication warning.'
call AssertTrue builder~addValues(values), 'input row accepted'
inputSnapshot = builder~freeze('LIBRARIAN-INPUT-1', 'fixture text', 'TEST')
call AssertTrue inputSnapshot \== .nil, 'input snapshot frozen'

context = .AlgorithmExecutionContext~new('LIB-INV-1', inputSnapshot~sourceOid)
algorithmResult = engine~execute('LIBRARIAN_TEXT', inputSnapshot, context)
call AssertTrue algorithmResult \== .nil, 'algorithm result exists'
call AssertTrue algorithmResult~validationErrors~items = 0, 'result validates'
call AssertTrue provider~invocationCount = 1, 'provider executed once'

call AssertTrue algorithmResult~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows~items = 1, 'one document row'
call AssertTrue algorithmResult~relation('LIBRARIAN_SENTENCE_ANALYSIS')~rows~items = 3, 'three sentence rows'
call AssertTrue algorithmResult~relation('LIBRARIAN_WORD_OBSERVATIONS')~rows~items = 7, 'seven word observations'
call AssertTrue algorithmResult~relation('LIBRARIAN_TARGET_HITS')~rows~items = 6, 'six target hits'
call AssertTrue algorithmResult~relation('LIBRARIAN_TARGET_HIT_PROVENANCE')~rows~items = 6, 'six target provenance paths'
call AssertTrue algorithmResult~relation('LIBRARIAN_RESOLUTION_CANDIDATES')~rows~items = 0, 'no fuzzy candidates for exact fixture'
call AssertTrue algorithmResult~relation('LIBRARIAN_ANALYSIS_ERRORS')~rows~items = 0, 'no analysis errors'

row = algorithmResult~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows~at(1)
call AssertTrue row~value('TARGET_SCORE') = 46, 'target score 46'
call AssertTrue row~value('TARGET_HIT_COUNT') = 6, 'document hit count 6'
call AssertContains row~value('CONCEPTS'), 'MEDICATION', 'medication concept'

-- Same materialized content under a different audit invocation must not rerun.
context2 = .AlgorithmExecutionContext~new('LIB-INV-2', inputSnapshot~sourceOid)
replayResult = engine~execute('LIBRARIAN_TEXT', inputSnapshot, context2)
call AssertTrue provider~invocationCount = 1, 'replay must not rerun provider'
call AssertTrue replayResult~providerExecutionId = algorithmResult~providerExecutionId, 'provider execution identity preserved'
call AssertTrue replayResult~invocationId = 'LIB-INV-2', 'audit invocation rebound'

say '  model_fingerprint=' || modelFingerprint
say '  input_hash=' || inputSnapshot~contentHash
say '  target_hits=' || algorithmResult~relation('LIBRARIAN_TARGET_HITS')~rows~items
say '  provider_invocations=' || provider~invocationCount
say 'ALGORITHM RELATION LIBRARIAN: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::routine AssertContains
  use arg text, needle, message
  call AssertTrue pos(needle, text) > 0, message || ' text=' || text
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
