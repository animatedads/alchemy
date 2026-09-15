.FBRelationshipTestSupport~assertEq("0.1",.FederationBankRelationshipAdapterRuntimeModule~componentVersion,"version")
.FBRelationshipTestSupport~assertEq("federationbank.relationship.adapter/0.1",.FederationBankRelationshipAdapterRuntimeModule~apiVersion,"api")
.FBRelationshipTestSupport~assertTrue(.FederationBankRelationshipAdapterRuntimeModule~capabilities~items>=4,"capabilities")
.FBRelationshipTestSupport~pass("runtime module boundary")
::requires "FederationBankRelationshipAdapterRuntimeModule.cls"
::requires "TestSupport.cls"
