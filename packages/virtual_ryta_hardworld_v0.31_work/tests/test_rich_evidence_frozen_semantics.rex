say 'RICH EVIDENCE FROZEN SEMANTICS START'

node=.MutableRichFixtureNode~new('50')
source=.RichEvidenceSourceRef~new(node,'DOC1#QTY1','XML','ELEMENT','/Order/Quantity[1]','50',50,'VALID','DOC1',17,9,'')
rich=.RichEvidenceValue~new(node,'DOC1:QTY1','ORDER_QUANTITY','PRESENT',.RichEvidenceProjectionState~SCALAR_AVAILABLE,'50',.array~of(source),.array~of('PARSED'),'FROZEN_OBSERVATION','SOURCE-CONS-1')

schema=.AlgorithmSchema~new('RICH_INPUT')
schema~add('FACT_ID','TEXT',.false)
schema~add('RICH_VALUE','RICH_OBJECT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'RICH_INPUT')
vals=.directory~new; vals['FACT_ID']='QTY'; vals['RICH_VALUE']=rich
call Assert builder~addValues(vals), 'rich input accepted'
snapshot=builder~freeze('RICH-FROZEN-1')
originalHash=snapshot~contentHash
originalCanonical=rich~algorithmCanonicalText

/* Mutate the actual native object after capture. Frozen evidence semantics must
   continue to use the copied source metadata, not re-read the native object. */
node~setValue('999999')
call Assert node~string='999999', 'native source really changed'
call Assert rich~scalarValue='50', 'presentation value remains captured value'
call Assert source~lexicalValue='50', 'source lexical value remains captured value'
call Assert source~typedValue=50, 'source typed value remains captured value'
call Assert rich~algorithmCanonicalText=originalCanonical, 'canonical evidence identity does not follow native mutation'
call Assert snapshot~contentHash=originalHash, 'frozen relation identity does not follow native mutation'
call Assert rich~nativeObject == node, 'native object remains reachable by identity'
call Assert source~nativeObject == node, 'source native object remains reachable by identity'

say 'RICH EVIDENCE FROZEN SEMANTICS: OK'
exit 0

Assert: procedure
  use arg condition, message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class MutableRichFixtureNode public
::attribute currentValue get
::method init
  expose currentValue
  use arg initialValue
  currentValue=initialValue
::method setValue
  expose currentValue
  use arg newValue
  currentValue=newValue
  return .true
::method string
  expose currentValue
  return currentValue

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/RichEvidence.cls'
