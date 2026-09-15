say 'LIBRARIAN LIMITS START'
root=directory('..')
topics=root || '/librarian/fixtures/librarian_topics.txt'
factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
limits=.LibrarianInvocationLimits~new(10,200000,4096,50000,50000)
provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-FIXTURE','1',manifest,root,limits)
engine=.AlgorithmRelationEngine~new
call AssertTrue engine~addProvider(provider), 'provider registration'
text=''
do i=1 to 5000
  text=text || ' Danger'
end
schema=.AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
schema~add('DOCUMENT_ID','TEXT',.false)
schema~add('TEXT','TEXT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
v=.directory~new; v['DOCUMENT_ID']='BIG'; v['TEXT']=text
call AssertTrue builder~addValues(v), 'large input captured'
snap=builder~freeze('LIMIT-SNAP','limit','TEST')
ctx=.AlgorithmExecutionContext~new('LIMIT-INV',snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
algorithmResult=engine~execute('LIBRARIAN_TEXT',snap,ctx)
errors=algorithmResult~relation('LIBRARIAN_ANALYSIS_ERRORS')
call AssertTrue errors~rows~items=1, 'one limit error'
call AssertTrue errors~rows[1]~value('ERROR_CODE')='LIMIT_TOKENS_PER_DOCUMENT', 'token limit enforced before analysis'
call AssertTrue algorithmResult~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows~items=0, 'oversize document not analysed'
call AssertTrue factory~buildCount=0, 'all-invalid oversized invocation must not construct analyzer'
say 'LIBRARIAN LIMITS: OK'
exit 0

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
