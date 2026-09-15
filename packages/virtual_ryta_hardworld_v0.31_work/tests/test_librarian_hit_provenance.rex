say 'LIBRARIAN HIT PROVENANCE START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'
factory = .LibrarianDeterministicAnalyzerFactory~new(topics)
manifest = .LibrarianDeterministicFixture~buildModelManifest(root, topics)
provider = .LibrarianTextAlgorithmProvider~new(factory, 'LIBRARIAN-FIXTURE', '1', manifest, root)
engine = .AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'

schema = .AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID','TEXT',.false)
schema~add('TEXT','TEXT',.false)
b = .AlgorithmInputRelationBuilder~new(schema, 'LIBRARIAN_TEXT_SOURCE', .AlgorithmInputRelationConstant~BAG_UNORDERED)
v = .directory~new
v['DOCUMENT_ID']='DOC-PROV'
v['TEXT']='Warning danger.'
call AssertTrue b~addValues(v), 'input accepted'
snap=b~freeze('LIB-PROV','prov','TEST')
ctx=.AlgorithmExecutionContext~new('LIB-PROV-INV',snap~sourceOid)
r=engine~execute('LIBRARIAN_TEXT',snap,ctx)
hits=r~relation('LIBRARIAN_TARGET_HITS')
call AssertTrue hits~rows~items=2, 'two target hits'
do row over hits~rows
  call AssertTrue row~value('PARAGRAPH_NO')=1, 'paragraph structured'
  call AssertTrue row~value('SENTENCE_NO')=1, 'sentence structured'
  call AssertTrue row~value('WORD_NO') \== .nil, 'word ordinal structured'
  call AssertTrue row~value('COORDINATE') \== '', 'coordinate present'
  call AssertTrue row~value('RAW_TEXT') \== '', 'surface text present'
  call AssertTrue row~value('CLEAN_TEXT') \== '', 'canonical clean form present'
  call AssertTrue row~value('RESOLVED_KEY') \== '', 'resolved key present'
  call AssertTrue row~value('RESOLUTION_SOURCE') \== '', 'resolution provenance present'
  call AssertTrue row~value('MATCH_BASIS') \== '', 'match basis present'
  call AssertTrue row~value('SOURCE_SEED') \== '', 'seed present'
  call AssertTrue row~value('EXPANSION_RULE') \== '', 'expansion rule present'
end
say 'LIBRARIAN HIT PROVENANCE: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
