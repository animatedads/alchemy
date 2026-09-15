.FBIntermediaryStaffTestSupport~assertEq("federationbank.intermediary.staff.authority",.FederationBankIntermediaryStaffAuthorityRuntimeModule~componentId,"component")
.FBIntermediaryStaffTestSupport~assertEq("0.1",.FederationBankIntermediaryStaffAuthorityRuntimeModule~componentVersion,"version")
.FBIntermediaryStaffTestSupport~assertTrue(.FederationBankIntermediaryStaffAuthorityRuntimeModule~capabilities~items>=8,"capabilities")
.FBIntermediaryStaffTestSupport~pass("intermediary staff authority runtime module boundary")
::requires "FederationBankIntermediaryStaffAuthorityRuntimeModule.cls"
::requires "TestSupport.cls"
