.FBRelationshipServiceTestSupport~assertEq("0.1",.FederationBankRelationshipAdapterServiceRuntimeModule~componentVersion,"version")
.FBRelationshipServiceTestSupport~assertEq("federationbank.relationship.adapter.service/0.1",.FederationBankRelationshipAdapterServiceRuntimeModule~apiVersion,"api")
.FBRelationshipServiceTestSupport~assertTrue(.FederationBankRelationshipAdapterServiceRuntimeModule~capabilities~items>=5,"caps")
.FBRelationshipServiceTestSupport~pass("runtime service module boundary")
::requires "FederationBankRelationshipAdapterServiceRuntimeModule.cls"
::requires "TestSupport.cls"
