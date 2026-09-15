say 'LIBRARIAN ORDER / ISOLATION START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'

-- Forensic check: the surviving analyzer itself must not change per-document
-- scores merely because two documents are analysed in the opposite order.
a1 = .LibrarianDeterministicFixture~buildAnalyzer(topics)
aDocA = .LibrarianArticle~new('A', 'We sell product.')
aDocB = .LibrarianArticle~new('B', 'Warning danger.')
a1~analyseArticle(aDocA)
a1~analyseArticle(aDocB)

a2 = .LibrarianDeterministicFixture~buildAnalyzer(topics)
bDocB = .LibrarianArticle~new('B', 'Warning danger.')
bDocA = .LibrarianArticle~new('A', 'We sell product.')
a2~analyseArticle(bDocB)
a2~analyseArticle(bDocA)
call AssertTrue aDocA~score = bDocA~score, 'A article score order independent'
call AssertTrue aDocA~targetScore = bDocA~targetScore, 'A target score order independent'
call AssertTrue aDocA~concepts = bDocA~concepts, 'A concepts order independent'
call AssertTrue aDocB~score = bDocB~score, 'B article score order independent'
call AssertTrue aDocB~targetScore = bDocB~targetScore, 'B target score order independent'
call AssertTrue aDocB~concepts = bDocB~concepts, 'B concepts order independent'

-- Production adapter check: each provider execution gets a fresh analyzer.
factory = .LibrarianDeterministicAnalyzerFactory~new(topics)
manifest = .LibrarianDeterministicFixture~buildModelManifest(root, topics)
provider = .LibrarianTextAlgorithmProvider~new(factory, 'LIBRARIAN-FIXTURE', '1', manifest, root)
engine = .AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'

schema = .AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID','TEXT',.false)
schema~add('TEXT','TEXT',.false)

ab = .AlgorithmInputRelationBuilder~new(schema, 'LIBRARIAN_TEXT_SOURCE', .AlgorithmInputRelationConstant~ORDERED)
va=.directory~new; va['DOCUMENT_ID']='A'; va['TEXT']='We sell product.'
vb=.directory~new; vb['DOCUMENT_ID']='B'; vb['TEXT']='Warning danger.'
call AssertTrue ab~addValues(va), 'AB A accepted'
call AssertTrue ab~addValues(vb), 'AB B accepted'
snapAB=ab~freeze('LIB-ORDER-AB','A then B','TEST')

ba = .AlgorithmInputRelationBuilder~new(schema, 'LIBRARIAN_TEXT_SOURCE', .AlgorithmInputRelationConstant~ORDERED)
call AssertTrue ba~addValues(vb), 'BA B accepted'
call AssertTrue ba~addValues(va), 'BA A accepted'
snapBA=ba~freeze('LIB-ORDER-BA','B then A','TEST')
call AssertTrue snapAB~contentHash \= snapBA~contentHash, 'ORDERED input identity preserves sequence'

ctxAB=.AlgorithmExecutionContext~new('LIB-ORDER-INV-AB',snapAB~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
rAB=engine~execute('LIBRARIAN_TEXT',snapAB,ctxAB)
ctxBA=.AlgorithmExecutionContext~new('LIB-ORDER-INV-BA',snapBA~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
rBA=engine~execute('LIBRARIAN_TEXT',snapBA,ctxBA)
call AssertTrue provider~invocationCount=2, 'two explicit fresh provider executions'
call AssertTrue factory~buildCount=2, 'fresh analyzer built for each materialisation'

call CompareDocument rAB, rBA, 'A'
call CompareDocument rAB, rBA, 'B'

-- BAG_UNORDERED canonicalisation deliberately erases document row order.
bag1=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
call AssertTrue bag1~addValues(va), 'bag1 A'
call AssertTrue bag1~addValues(vb), 'bag1 B'
bagSnap1=bag1~freeze('BAG1','bag1','TEST')
bag2=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
call AssertTrue bag2~addValues(vb), 'bag2 B'
call AssertTrue bag2~addValues(va), 'bag2 A'
bagSnap2=bag2~freeze('BAG2','bag2','TEST')
call AssertTrue bagSnap1~contentHash=bagSnap2~contentHash, 'BAG_UNORDERED identity ignores source row order'

say '  analyzer_factory_builds=' || factory~buildCount
say 'LIBRARIAN ORDER / ISOLATION: OK'
exit 0

::routine CompareDocument
  use arg resultOne, resultTwo, docId
  rowOne = FindDocument(resultOne~relation('LIBRARIAN_DOCUMENT_ANALYSIS'), docId)
  rowTwo = FindDocument(resultTwo~relation('LIBRARIAN_DOCUMENT_ANALYSIS'), docId)
  call AssertTrue rowOne \== .nil, 'document present first ' || docId
  call AssertTrue rowTwo \== .nil, 'document present second ' || docId
  call AssertTrue rowOne~value('ARTICLE_SCORE') = rowTwo~value('ARTICLE_SCORE'), 'article score stable ' || docId
  call AssertTrue rowOne~value('TARGET_SCORE') = rowTwo~value('TARGET_SCORE'), 'target score stable ' || docId
  call AssertTrue rowOne~value('CONCEPTS') = rowTwo~value('CONCEPTS'), 'concepts stable ' || docId
  return 1

::routine FindDocument
  use arg relation, docId
  do row over relation~rows
    if row~value('DOCUMENT_ID') == docId then return row
  end
  return .nil

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
