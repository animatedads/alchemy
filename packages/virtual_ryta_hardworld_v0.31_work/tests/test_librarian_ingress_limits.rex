say 'LIBRARIAN INGRESS LIMITS START'
root=directory('..')
topics=root || '/librarian/fixtures/librarian_topics.txt'

-- Byte/character envelope: all-invalid input must not construct an analyzer.
factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
limits=.LibrarianInvocationLimits~new(10,5,4096,50000,50000)
algorithmResult=RunInput(root,factory,manifest,limits,.Array~of(.Array~of('B','Danger.')),'BYTE')
call AssertError algorithmResult,'LIMIT_DOCUMENT_BYTES'
call AssertTrue factory~buildCount=0, 'byte-rejected invocation constructs no analyzer'

-- Document-count envelope: first row may be valid; overflow row must be rejected.
factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
limits=.LibrarianInvocationLimits~new(1,200000,4096,50000,50000)
rows=.Array~new
rows~append(.Array~of('D1','Danger.'))
rows~append(.Array~of('D2','Warning.'))
algorithmResult=RunInput(root,factory,manifest,limits,rows,'DOCS')
call AssertError algorithmResult,'LIMIT_DOCUMENTS'
call AssertTrue algorithmResult~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows~items=1, 'one document accepted at document limit'
call AssertTrue factory~buildCount=1, 'valid prefix constructs one analyzer'

-- Exact token boundary and one-over boundary.
factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
limits=.LibrarianInvocationLimits~new(10,200000,2,50000,50000)
rows=.Array~new
rows~append(.Array~of('T2','Danger Warning'))
rows~append(.Array~of('T3','Danger Warning Product'))
algorithmResult=RunInput(root,factory,manifest,limits,rows,'TOK')
call AssertError algorithmResult,'LIMIT_TOKENS_PER_DOCUMENT'
call AssertTrue algorithmResult~relation('LIBRARIAN_DOCUMENT_ANALYSIS')~rows~items=1, 'exact token limit accepted, one-over rejected'

say 'LIBRARIAN INGRESS LIMITS: OK'
exit 0

::routine RunInput
  use arg root,factory,manifest,limits,inputRows,suffix
  provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-FIXTURE','1',manifest,root,limits)
  engine=.AlgorithmRelationEngine~new
  call AssertTrue engine~addProvider(provider), 'provider registration ' || suffix
  schema=.AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
  schema~add('DOCUMENT_ID','TEXT',.false)
  schema~add('TEXT','TEXT',.false)
  builder=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
  do pair over inputRows
    v=.directory~new; v['DOCUMENT_ID']=pair[1]; v['TEXT']=pair[2]
    call AssertTrue builder~addValues(v), 'input captured ' || suffix
  end
  snap=builder~freeze('INGRESS-' || suffix,'limits','TEST')
  ctx=.AlgorithmExecutionContext~new('INGRESS-INV-' || suffix,snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
  return engine~execute('LIBRARIAN_TEXT',snap,ctx)

::routine AssertError
  use arg algorithmResult,expectedCode
  found=0
  do row over algorithmResult~relation('LIBRARIAN_ANALYSIS_ERRORS')~rows
    if row~value('ERROR_CODE')=expectedCode then found=1
  end
  call AssertTrue found=1, expectedCode || ' emitted'
  return 1

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
