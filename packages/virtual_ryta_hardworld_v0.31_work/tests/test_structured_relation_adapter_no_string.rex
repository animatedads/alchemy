say 'STRUCTURED RELATION ADAPTER NO IMPLICIT STRING START'

source=.PoisonStructuredSource~new
fact=.FakeStructuredFact~new(source)
rich=.StructuredRelationRichEvidenceAdapter~adaptFact(fact,'FROZEN_OBSERVATION','POISON-CONSISTENCY')
call Assert rich~nativeObject == source, 'native source retained'
call Assert rich~sources[1]~nativeObject == source, 'source ref retains poison object'
call Assert rich~sourceCount=1, 'one source'
call Assert rich~contexts[1]~nativeFact == fact, 'native fact retained'
call Assert rich~contexts[1]~nativeRow == fact~row, 'projection row retained'
call Assert rich~contexts[1]~annotations['policy']='EXPLICIT', 'annotation retained'
canonical=rich~algorithmCanonicalText
call Assert canonical~pos('POISON_VALUE')>0, 'explicit scalar evidence participates in canonical identity'
call Assert rich~processingHistory[1]~nativeObject == fact~processingHistory[1], 'history event retained by identity'

say 'STRUCTURED RELATION ADAPTER NO IMPLICIT STRING: OK'
exit 0

Assert: procedure
  use arg condition,message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class PoisonStructuredSource public
::attribute document get
::method init
  expose document
  document=.PoisonStructuredDocument~new
::method path
  return '/Order/Line[1]/Quantity[1]'
::method provenance
  p=.table~new
  p['kind']='ELEMENT'; p['qName']='Quantity'; p['path']=self~path; p['line']=7
  p['document']=self~document
  return p
::method string
  raise syntax 93.900 additional('POISON SOURCE STRING MUST NEVER BE CALLED')

::class PoisonStructuredDocument public
::attribute source get
::attribute sourceText get
::attribute parserName get
::attribute history get
::attribute transformName get
::method init
  expose source sourceText parserName history transformName
  source='memory:poison.xml'; sourceText='<Order><Quantity>POISON_VALUE</Quantity></Order>'
  parserName='OOREXX_NATIVE_XML_POISON'; transformName=''
  history=.array~of(.FakeProcessingEvent~new)

::class FakeProcessingEvent public
::attribute phase get
::attribute operation get
::attribute detail get
::attribute timestamp get
::method init
  expose phase operation detail timestamp
  phase='PARSE'; operation='POISON_SAFE_PARSE'; detail='memory:poison.xml'; timestamp='2099-01-01T00:00:00Z'
::method string
  raise syntax 93.900 additional('PROCESSING EVENT STRING MUST NEVER BE CALLED')

::class FakeProjection public
::attribute name get
::method init
  expose name
  name='fake_relation'

::class FakeProjectedRow public
::attribute projection get
::method init
  expose projection
  projection=.FakeProjection~new

::class FakeStructuredFact public
::attribute name get
::attribute value get
::attribute state get
::attribute source get
::attribute row get
::attribute semanticType get
::attribute lexicalValue get
::attribute diagnostics get
::attribute annotations get
::attribute createdAt get
::method init
  expose name value state source row semanticType lexicalValue diagnostics annotations createdAt
  use arg sourceArg
  name='quantity'; value='POISON_VALUE'; state='PRESENT'; source=sourceArg; row=.FakeProjectedRow~new
  semanticType='TEXT'; lexicalValue='POISON_VALUE'; diagnostics=.array~new
  annotations=.table~new; annotations['policy']='EXPLICIT'; createdAt='2099-01-01T00:00:01Z'
::method sourceProvenance
  return self~source~provenance
::method sourceDocument
  return self~source~document
::method sourcePath
  return self~source~path
::method processingHistory
  return self~source~document~history

::requires '../algorithm/AlgorithmIntegrity.cls'
::requires '../algorithm/RichEvidence.cls'
::requires '../integration/StructuredRelationRichEvidenceAdapter.cls'
