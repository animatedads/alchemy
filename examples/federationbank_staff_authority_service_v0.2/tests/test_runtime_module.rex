.FBStaffServiceTestSupport~assertEq("federationbank.staff.authority.service",.FederationBankStaffAuthorityServiceRuntimeModule~componentId,"component")
.FBStaffServiceTestSupport~assertEq("0.2",.FederationBankStaffAuthorityServiceRuntimeModule~componentVersion,"version")
.FBStaffServiceTestSupport~assertTrue(.FederationBankStaffAuthorityServiceRuntimeModule~capabilities~items>=5,"capabilities")
.FBStaffServiceTestSupport~pass("runtime service boundary")
::requires "FederationBankStaffAuthorityServiceRuntimeModule.cls"
::requires "TestSupport.cls"
