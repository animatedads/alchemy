.FBStaffTestSupport~assertEq("federationbank.staff.authority",.FederationBankStaffAuthorityRuntimeModule~componentId,"component")
.FBStaffTestSupport~assertEq("0.1",.FederationBankStaffAuthorityRuntimeModule~componentVersion,"version")
.FBStaffTestSupport~assertTrue(.FederationBankStaffAuthorityRuntimeModule~capabilities~items>=5,"capabilities")
.FBStaffTestSupport~pass("runtime module boundary")
::requires "FederationBankStaffAuthorityRuntimeModule.cls"
::requires "TestSupport.cls"
