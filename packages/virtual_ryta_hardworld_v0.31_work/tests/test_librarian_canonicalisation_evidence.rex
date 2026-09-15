say 'LIBRARIAN CANONICALISATION EVIDENCE START'
root=directory('..')
tmp='/tmp/librarian_canon_' || random(100000,999999) || '.txt'
call lineout tmp, 'TEST CAF ANY 9'
call lineout tmp
factory=.LibrarianDeterministicAnalyzerFactory~new(tmp)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,tmp)
provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-CANON','1',manifest,root)
engine=.AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'

schema=.AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID','TEXT',.false)
schema~add('TEXT','TEXT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
utf8Cafe='CAF' || 'c3a9'x
v=.directory~new; v['DOCUMENT_ID']='CANON1'; v['TEXT']=utf8Cafe
call AssertTrue builder~addValues(v), 'input accepted'
snap=builder~freeze('CANON-SNAP','unicode canonicalisation','TEST')
ctx=.AlgorithmExecutionContext~new('CANON-INV',snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
algorithmResult=engine~execute('LIBRARIAN_TEXT',snap,ctx)
obs=algorithmResult~relation('LIBRARIAN_WORD_OBSERVATIONS')
call AssertTrue obs~rows~items=1, 'one observation'
row=obs~rows[1]
call AssertTrue row~value('RAW_TEXT')=utf8Cafe, 'raw UTF-8 surface preserved'
call AssertTrue row~value('CLEAN_TEXT')='CAF', 'lossy canonical key visible'
call AssertTrue row~value('RESOLUTION_SOURCE')='canonical_compact', 'lossy canonical match is not labelled exact'
call AssertTrue row~value('NORMALISED_SURFACE') \= row~value('CLEAN_TEXT'), 'surface and lexical key separated'
hits=algorithmResult~relation('LIBRARIAN_TARGET_HITS')
call AssertTrue hits~rows~items=1, 'target hit emitted'
call AssertTrue hits~rows[1]~value('MATCH_BASIS')='CANONICAL_LEXICAL_KEY', 'match basis explicit'
ignore=SysFileDelete(tmp)
say 'LIBRARIAN CANONICALISATION EVIDENCE: OK'
exit 0

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
