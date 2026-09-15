say 'LIBRARIAN OUTPUT LIMITS START'
root=directory('..')
-- one ordinary hit/observation must trip each independently when that envelope is zero.
call RunLimitCase root, 'Danger.', .LibrarianInvocationLimits~new(10,200000,4096,0,50000,100000,100000), 'LIMIT_OBSERVATIONS'
call RunLimitCase root, 'Danger.', .LibrarianInvocationLimits~new(10,200000,4096,50000,0,100000,100000), 'LIMIT_TARGET_HITS'
call RunLimitCase root, 'Danger.', .LibrarianInvocationLimits~new(10,200000,4096,50000,50000,0,100000), 'LIMIT_TARGET_PROVENANCE'
-- DONGER takes the Soundex candidate path in the deterministic fixture.
call RunLimitCase root, 'Donger.', .LibrarianInvocationLimits~new(10,200000,4096,50000,50000,100000,0), 'LIMIT_RESOLUTION_CANDIDATES'
say 'LIBRARIAN OUTPUT LIMITS: OK'
exit 0

::routine RunLimitCase
  use arg root, text, limits, expectedCode
  topics=root || '/librarian/fixtures/librarian_topics.txt'
  factory=.LibrarianDeterministicAnalyzerFactory~new(topics)
  manifest=.LibrarianDeterministicFixture~buildModelManifest(root,topics)
  provider=.LibrarianTextAlgorithmProvider~new(factory,'LIBRARIAN-FIXTURE','1',manifest,root,limits)
  engine=.AlgorithmRelationEngine~new
  call AssertTrue engine~addProvider(provider), 'provider registration for ' || expectedCode
  schema=.AlgorithmSchema~new('LIBRARIAN_TEXT_SOURCE')
  schema~add('DOCUMENT_ID','TEXT',.false)
  schema~add('TEXT','TEXT',.false)
  builder=.AlgorithmInputRelationBuilder~new(schema,'LIBRARIAN_TEXT_SOURCE',.AlgorithmInputRelationConstant~BAG_UNORDERED)
  v=.directory~new; v['DOCUMENT_ID']='LIMIT'; v['TEXT']=text
  call AssertTrue builder~addValues(v), 'input captured for ' || expectedCode
  snap=builder~freeze('LIMIT-SNAP-' || expectedCode,'limit','TEST')
  ctx=.AlgorithmExecutionContext~new('LIMIT-INV-' || expectedCode,snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
  algorithmResult=engine~execute('LIBRARIAN_TEXT',snap,ctx)
  errors=algorithmResult~relation('LIBRARIAN_ANALYSIS_ERRORS')
  found=0
  do row over errors~rows
    if row~value('ERROR_CODE')=expectedCode then found=1
  end
  call AssertTrue found=1, expectedCode || ' emitted'
  call AssertTrue factory~buildCount=1, expectedCode || ' is post-analyzer output envelope'
  return 1

::routine AssertTrue
  use arg condition, message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
