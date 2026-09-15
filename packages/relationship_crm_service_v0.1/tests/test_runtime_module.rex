m=.RelationshipCRMServiceRuntimeModule~new; .CRMServiceTest~assertEqual("relationship_crm_service",m~componentId); .CRMServiceTest~assertEqual("0.1",m~version); .CRMServiceTest~assertTrue(m~capabilities~items>=6); say "PASS runtime module"
::requires "TestSupport.cls"
::requires "RelationshipCRMServiceRuntimeModule.cls"
