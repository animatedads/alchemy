say 'RICH NO IMPLICIT STRINGIFICATION START'

native=.NoStringRichNative~new('NATIVE-1')
source=.RichEvidenceSourceRef~new(native,'DOC-NOSTRING#N1','EDIFACT','EDIFACT_COMPONENT','/INTERCHANGE[1]/MESSAGE[1]/QTY[1]/E1/R1/C2','50',50,'VALID','DOC-NOSTRING',4,1,'')
rich=.RichEvidenceValue~new(native,'DOC-NOSTRING:QTY','ORDER_QUANTITY','PRESENT',.RichEvidenceProjectionState~SCALAR_AVAILABLE,'50',.array~of(source),.array~of('PARSED'),'FROZEN_OBSERVATION','CONS-NOSTRING')

schema=.AlgorithmSchema~new('RICH_INPUT')
schema~add('FACT_ID','TEXT',.false)
schema~add('RICH_VALUE','RICH_OBJECT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'RICH_INPUT')
vals=.directory~new; vals['FACT_ID']='QTY'; vals['RICH_VALUE']=rich
call Assert builder~addValues(vals), 'native object accepted without STRING'
snapshot=builder~freeze('NOSTRING-SNAPSHOT')
call Assert snapshot \== .nil, 'snapshot frozen without STRING'
call Assert snapshot~contentHash~length=64, 'content hash produced without STRING'

provider=.RichBusinessFactAlgorithmProvider~new('..')
engine=.AlgorithmRelationEngine~new
call Assert engine~addProvider(provider), 'provider registered'
ctx=.AlgorithmExecutionContext~new('NOSTRING-INV',snapshot~sourceOid,snapshot~sourceOid)
algorithmResult=engine~execute('RICH_BUSINESS_FACTS',snapshot,ctx)
call Assert algorithmResult \== .nil, 'explicit projection completes without native STRING'
call Assert algorithmResult~relation('RICH_FACT_SOURCES')~rows[1]~value('NATIVE_OBJECT_PRESERVED')=.true, 'native object preserved'
call Assert algorithmResult~relation('RICH_FACT_SUMMARY')~rows[1]~value('SCALAR_VALUE')='50', 'explicit presentation value projected'
call Assert provider~invocationCount=1, 'provider runs once'

say 'RICH NO IMPLICIT STRINGIFICATION: OK'
exit 0

Assert: procedure
  use arg condition,message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class NoStringRichNative public
::attribute identity get
::method init
  expose identity
  use arg id
  identity=id
::method string
  raise syntax 93.900 additional('NATIVE SOURCE MUST NOT BE STRINGIFIED')

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/RichEvidence.cls'
::requires '../integration/RichBusinessFactAlgorithmProvider.cls'
