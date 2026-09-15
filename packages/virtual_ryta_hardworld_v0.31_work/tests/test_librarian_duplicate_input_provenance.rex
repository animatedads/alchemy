say 'LIBRARIAN DUPLICATE INPUT PROVENANCE START'
root=directory('..')
topics=root || '/librarian/fixtures/librarian_topics.txt'
factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-FIXTURE','1',manifest,root)
engine=.AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'
schema=.AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID','TEXT',.false)
schema~add('TEXT','TEXT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
v=.directory~new; v['DOCUMENT_ID']='SAME'; v['TEXT']='Danger.'
call AssertTrue builder~addValues(v), 'first duplicate'
call AssertTrue builder~addValues(v), 'second duplicate'
snap=builder~freeze('DUP-SNAP','duplicates','TEST')
ctx=.AlgorithmExecutionContext~new('DUP-INV',snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
algorithmResult=engine~execute('LIBRARIAN_TEXT',snap,ctx)
docs=algorithmResult~relation('LIBRARIAN_DOCUMENT_ANALYSIS')
hits=algorithmResult~relation('LIBRARIAN_TARGET_HITS')
call AssertTrue docs~rows~items=2, 'two document rows preserved'
call AssertTrue hits~rows~items=2, 'two hit rows preserved'
seen1=0; seen2=0
do row over hits~rows
  if row~value('INPUT_ROW_ORDINAL')=1 then seen1=seen1+1
  if row~value('INPUT_ROW_ORDINAL')=2 then seen2=seen2+1
end
call AssertTrue seen1=1 & seen2=1, 'duplicate instances disambiguated by ordinal'
say 'LIBRARIAN DUPLICATE INPUT PROVENANCE: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
