say 'HARDWORLD RICH EVIDENCE REFERENCE START'

richA = makeEvidence('/Order/Essential[1]','DOC-A#ESSENTIAL')
richA2 = makeEvidence('/Order/Essential[1]','DOC-A#ESSENTIAL')
richB = makeEvidence('/Order/Essential[2]','DOC-A#ESSENTIAL-OTHER')

worldA = makeWorld('WORLD-RICH-A',richA)
worldA2 = makeWorld('WORLD-RICH-A',richA2)
worldB = makeWorld('WORLD-RICH-A',richB)

call Assert worldA~fact('ESSENTIAL_MEDICATION')~evidence == richA, 'HardWorld fact retains rich evidence object identity'

provider=.RYTAAlgorithmProvider~new(.nil,'..')
engine=.AlgorithmRelationEngine~new
call Assert engine~addProvider(provider), 'RYTA provider registered'
ctxA=.AlgorithmExecutionContext~new('RICH-HW-1','WORLD-RICH-A','WORLD-RICH-A')
rA=engine~execute('VIRTUAL_RYTA',worldA,ctxA)
call Assert rA \== .nil, 'world A executes'
call Assert provider~invocationCount=1, 'first evidence executes once'

/* Same semantic evidence, different native object instances -> same content identity/replay. */
ctxA2=.AlgorithmExecutionContext~new('RICH-HW-2','WORLD-RICH-A','WORLD-RICH-A')
rA2=engine~execute('VIRTUAL_RYTA',worldA2,ctxA2)
call Assert rA2 \== .nil, 'equivalent evidence replay'
call Assert provider~invocationCount=1, 'equivalent evidence reuses materialisation'
call Assert rA~materializationId=rA2~materializationId, 'equivalent evidence same materialization identity'
call Assert rA~providerExecutionId=rA2~providerExecutionId, 'equivalent evidence preserves provider execution identity'

/* Same Boolean fact, different source/provenance -> distinct algorithm input identity. */
ctxB=.AlgorithmExecutionContext~new('RICH-HW-3','WORLD-RICH-A','WORLD-RICH-A')
rB=engine~execute('VIRTUAL_RYTA',worldB,ctxB)
call Assert rB \== .nil, 'world B executes'
call Assert provider~invocationCount=2, 'different evidence provenance forces fresh materialisation'
call Assert rA~materializationId \= rB~materializationId, 'different evidence changes materialisation identity'

/* Rule truth did not change merely because evidence provenance changed. */
call Assert rA~relation('RYTA_ACTION_DECISIONS')~rows[1]~value('STATE') = rB~relation('RYTA_ACTION_DECISIONS')~rows[1]~value('STATE'), 'same explicit world facts keep same decision state'

say 'HARDWORLD RICH EVIDENCE REFERENCE: OK'
exit 0

makeWorld: procedure
  use arg snapshotId, evidence
  w=.RYTAWorldState~new(snapshotId)
  w~putKnown('HAS_QUERY',.true)
  w~putKnown('PRODUCT_RELEVANT',.false)
  w~putKnown('PRODUCT_VALUE_HIGH',.false)
  w~putKnown('UPSELL_OPPORTUNITY',.false)
  w~putKnown('ESSENTIAL_MEDICATION',.true,'EXPLICIT_PROMOTION','BUSINESS_POLICY',evidence)
  w~putKnown('IMMEDIATE_ACCESS',.true)
  w~putKnown('GUARANTEED_CUSTODY',.false)
  return w

makeEvidence: procedure
  use arg sourcePath, sourceIdentity
  node=.RichEvidenceTestNode~new('TRUE')
  ref=.RichEvidenceSourceRef~new(node,sourceIdentity,'XML','ELEMENT',sourcePath,'true',.true,'VALID','DOC-A',12,4,'')
  return .RichEvidenceValue~new(node,'ESSENTIAL:' || sourceIdentity,'ESSENTIAL_MEDICATION_FLAG','PRESENT',.RichEvidenceProjectionState~SCALAR_AVAILABLE,.true,.array~of(ref),.array~of('PARSED','EXPLICIT_POLICY_PROMOTION'),'FROZEN_OBSERVATION','CONS-RICH-HW')

Assert: procedure
  use arg condition,message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class RichEvidenceTestNode public
::attribute value get
::method init
  expose value
  use arg v
  value=v
::method string
  expose value
  return value

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/RichEvidence.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
