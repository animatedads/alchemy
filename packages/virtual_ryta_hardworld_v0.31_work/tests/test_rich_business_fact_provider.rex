say 'RICH BUSINESS FACT PROVIDER START'

doc=.RichFixtureDocument~new('EDI-DOC-1')
n1=.RichFixtureNode~new(doc,'EDI-N1','50')
n2=.RichFixtureNode~new(doc,'XML-N1','5000')
s1=.RichEvidenceSourceRef~new(n1,'EDI-DOC-1#QTY','EDIFACT','EDIFACT_COMPONENT','/INTERCHANGE[1]/MESSAGE[1]/QTY[1]/E1/R1/C2','50',50,'VALID')
s2=.RichEvidenceSourceRef~new(n2,'XML-DOC-1#QTY','XML','ELEMENT','/Order/Quantity[1]','5000',5000,'VALID')
rich=.RichEvidenceValue~new(.array~of(n1,n2),'BUSINESS-ORDER-88:QTY','ORDER_QUANTITY','CONFLICT',.RichEvidenceProjectionState~SCALAR_REFUSED,.nil,.array~of(s1,s2),.array~of('EDIFACT_PARSED','XML_PARSED','CROSS_FORMAT_COMPARED'),'FROZEN_OBSERVATION','CONS-HASH-X')

schema=.AlgorithmSchema~new('RICH_INPUT')
schema~add('FACT_ID','TEXT',.false); schema~add('RICH_VALUE','RICH_OBJECT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'RICH_INPUT')
vals=.directory~new; vals['FACT_ID']='ORDER_QUANTITY'; vals['RICH_VALUE']=rich
call Assert builder~addValues(vals), 'input row accepted'
snapshot=builder~freeze('BUSINESS-88')
provider=.RichBusinessFactAlgorithmProvider~new('..')
engine=.AlgorithmRelationEngine~new
call Assert engine~addProvider(provider), 'provider registered'
context=.AlgorithmExecutionContext~new('RICH-INV-1',snapshot~sourceOid,snapshot~sourceOid)
algorithmResult=engine~execute('RICH_BUSINESS_FACTS',snapshot,context)
call Assert algorithmResult \== .nil, 'provider result'
summary=algorithmResult~relation('RICH_FACT_SUMMARY')
sources=algorithmResult~relation('RICH_FACT_SOURCES')
call Assert summary~rows~items=1, 'one summary row'
call Assert sources~rows~items=2, 'two source rows preserved rather than comma-flattened'
row=summary~rows[1]
call Assert row~value('SCALAR_VALUE') == .nil, 'conflict remains non-scalar'
call Assert row~value('AUTHORITY_DISPOSITION')='EVIDENCE_ONLY', 'provider does not manufacture authority'
call Assert row~value('SOURCE_COUNT')=2, 'source multiplicity preserved'
call Assert sources~rows[1]~value('NATIVE_OBJECT_PRESERVED')=.true, 'first native source object preserved'
call Assert sources~rows[2]~value('NATIVE_OBJECT_PRESERVED')=.true, 'second native source object preserved'
call Assert provider~invocationCount=1, 'one provider execution'

say 'RICH BUSINESS FACT PROVIDER: OK'
exit 0

Assert: procedure
  use arg condition, message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class RichFixtureDocument public
::attribute documentId get
::method init
  expose documentId
  use arg id
  documentId=id
::class RichFixtureNode public
::attribute document get
::attribute nodeId get
::attribute value get
::method init
  expose document nodeId value
  use arg d,id,v
  document=d; nodeId=id; value=v
::method string
  return self~value

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
::requires '../algorithm/RichEvidence.cls'
::requires '../integration/RichBusinessFactAlgorithmProvider.cls'
