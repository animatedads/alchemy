say 'RICH EVIDENCE OBJECT INPUT START'

/* Two native source nodes deliberately stringify to the same value while
   retaining different identities/paths. */
doc = .RichFixtureDocument~new('DOC-XML-1','XML','HASH-ABC')
n1 = .RichFixtureNode~new(doc,'NODE-1','ELEMENT','/Order/Quantity[1]','50')
n2 = .RichFixtureNode~new(doc,'NODE-2','ELEMENT','/Order/Quantity[2]','5000')

s1 = .RichEvidenceSourceRef~new(n1,'DOC-XML-1#NODE-1','XML','ELEMENT','/Order/Quantity[1]','50',50,'VALID')
s2 = .RichEvidenceSourceRef~new(n2,'DOC-XML-1#NODE-2','XML','ELEMENT','/Order/Quantity[2]','5000',5000,'VALID')
rich = .RichEvidenceValue~new(.array~of(n1,n2),'XML:HASH-ABC:/Order/Quantity','ORDER_QUANTITY','CARDINALITY_ERROR',.RichEvidenceProjectionState~CARDINALITY_ERROR,.nil,.array~of(s1,s2),.array~of('PARSED','XPATH_SELECTED'),'FROZEN_OBSERVATION','CONSISTENCY-1')

schema=.AlgorithmSchema~new('RICH_INPUT')
schema~add('FACT_ID','TEXT',.false)
schema~add('RICH_VALUE','RICH_OBJECT',.false)
builder=.AlgorithmInputRelationBuilder~new(schema,'RICH_INPUT')
vals=.directory~new
vals['FACT_ID']='QTY'
vals['RICH_VALUE']=rich
call Assert builder~addValues(vals), 'rich object accepted without string coercion'
snapshot=builder~freeze('RICH-SNAPSHOT-1')
call Assert snapshot \== .nil, 'snapshot created'
call Assert snapshot~rows[1]~value('RICH_VALUE')~nativeObject == rich~nativeObject, 'native object preserved by identity'
call Assert rich~scalarValue == .nil, 'ambiguous fact refuses scalar projection'

/* Same visible scalar but different source path is different rich evidence. */
s3=.RichEvidenceSourceRef~new(n1,'DOC-XML-1#NODE-OTHER','XML','ELEMENT','/Order/Other[1]','50',50,'VALID')
rich2=.RichEvidenceValue~new(n1,'XML:HASH-ABC:/Order/Other','ORDER_QUANTITY','PRESENT',.RichEvidenceProjectionState~SCALAR_AVAILABLE,'50',.array~of(s3),.array~of('PARSED'),'FROZEN_OBSERVATION','CONSISTENCY-1')
b2=.AlgorithmInputRelationBuilder~new(schema,'RICH_INPUT')
v2=.directory~new; v2['FACT_ID']='QTY'; v2['RICH_VALUE']=rich2
call Assert b2~addValues(v2), 'second rich object accepted'
snapshot2=b2~freeze('RICH-SNAPSHOT-2')
call Assert snapshot~contentHash \= snapshot2~contentHash, 'same-looking value with different provenance has different rich semantic identity'

say 'RICH EVIDENCE OBJECT INPUT: OK'
exit 0

Assert: procedure
  use arg condition, message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class RichFixtureDocument public
::attribute documentId get
::attribute sourceFormat get
::attribute documentHash get
::method init
  expose documentId sourceFormat documentHash
  use arg documentIdArg, sourceFormatArg, documentHashArg
  documentId=documentIdArg; sourceFormat=sourceFormatArg; documentHash=documentHashArg

::class RichFixtureNode public
::attribute document get
::attribute nodeId get
::attribute kind get
::attribute path get
::attribute value get
::method init
  expose document nodeId kind path value
  use arg documentArg,nodeIdArg,kindArg,pathArg,valueArg
  document=documentArg; nodeId=nodeIdArg; kind=kindArg; path=pathArg; value=valueArg
::method string
  return self~value

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/RichEvidence.cls'
