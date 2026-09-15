m=.RelationshipCRMRuntimeModule~new
.CRMTest~assertEqual("relationship_crm",m~componentId)
.CRMTest~assertEqual("0.1",m~version)
.CRMTest~assertTrue(m~capabilities~items >= 7)
say "PASS runtime module"
::requires "TestSupport.cls"
::requires "RelationshipCRMRuntimeModule.cls"
