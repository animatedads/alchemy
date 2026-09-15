say 'LIBRARIAN SENSE EVIDENCE START'
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
v=.directory~new; v['DOCUMENT_ID']='SENSE1'; v['TEXT']='Danger.'
call AssertTrue builder~addValues(v), 'input accepted'
snap=builder~freeze('SENSE-SNAP','sense evidence','TEST')
ctx=.AlgorithmExecutionContext~new('SENSE-INV',snap~sourceOid,'','','',.AlgorithmRelationConstant~FRESH)
algorithmResult=engine~execute('LIBRARIAN_TEXT',snap,ctx)
row=algorithmResult~relation('LIBRARIAN_WORD_OBSERVATIONS')~rows[1]
call AssertTrue row~value('RESOLVED_KEY')='DANGER', 'resolved DANGER'
call AssertTrue row~value('RESOLVED_SENSE_OFFSET')='5', 'sense offset exposed'
call AssertTrue row~value('RESOLVED_LEX_CATEGORY')='NOUN.STATE', 'lex category exposed'
call AssertTrue row~value('RESOLVED_SENSE_SOURCE')='fixture', 'sense source exposed'
say 'LIBRARIAN SENSE EVIDENCE: OK'
exit 0

::routine AssertTrue
  use arg condition,message
  if \condition then raise syntax 93.900 array('ASSERT FAILED: ' || message)
  return 1

::requires '../librarian/LibrarianDeterministicFixture.cls'
::requires '../integration/LibrarianTextAlgorithmProvider.cls'
