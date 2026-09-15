say 'LIBRARIAN SOUNDEX REGRESSION START'
root = directory('..')
topics = root || '/librarian/fixtures/librarian_topics.txt'
factory = .LibrarianDeterministicAnalyzerFactory~new(topics)
manifest = .LibrarianDeterministicFixture~buildModelManifest(root, topics)
provider = .LibrarianTextAlgorithmProvider~new(factory, 'LIBRARIAN-FIXTURE', '1', manifest, root)
engine = .AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'

schema=.AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID','TEXT',.false)
schema~add('TEXT','TEXT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
v=.directory~new; v['DOCUMENT_ID']='SOUND1'; v['TEXT']='Donger.'
call AssertTrue builder~addValues(v), 'input accepted'
snap=builder~freeze('LIB-SOUNDEX','soundex regression','TEST')
ctx=.AlgorithmExecutionContext~new('LIB-SOUNDEX-INV',snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
algorithmResult=engine~execute('LIBRARIAN_TEXT',snap,ctx)
call AssertTrue algorithmResult \== .nil, 'provider returned result'
obs=algorithmResult~relation('LIBRARIAN_WORD_OBSERVATIONS')
call AssertTrue obs~rows~items=1, 'one observation'
row=obs~rows[1]
call AssertTrue row~value('RESOLVED_KEY')='DANGER', 'DONGER resolves to DANGER'
call AssertTrue row~value('RESOLUTION_SOURCE')~left(8)='soundex:', 'soundex source'
candidates=algorithmResult~relation('LIBRARIAN_RESOLUTION_CANDIDATES')
call AssertTrue candidates~rows~items>=1, 'candidate evidence emitted'
selected=0
do c over candidates~rows
  if c~value('SELECTED')=1 then do
    selected=selected+1
    call AssertTrue c~value('CANDIDATE_KEY')='DANGER', 'selected candidate DANGER'
    call AssertTrue c~value('DISTANCE')=1, 'edit distance one'
  end
end
call AssertTrue selected=1, 'one selected soundex candidate'
call AssertTrue algorithmResult~relation('LIBRARIAN_ANALYSIS_ERRORS')~rows~items=0, 'no provider error'
say 'LIBRARIAN SOUNDEX REGRESSION: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
