m=.FederationBankBranchTillAdapterRuntimeModule~new
.FBBranchTillTest~assertEq("FEDERATIONBANK_BRANCH_TILL_ADAPTER",m~moduleId)
.FBBranchTillTest~assertEq("0.1",m~moduleVersion)
.FBBranchTillTest~assertEq("federationbank.branch.till.adapter/0.1",m~apiVersion)
say "PASS: Branch/Till adapter runtime metadata"
::requires "TestSupport.cls"
::requires "FederationBankBranchTillAdapterRuntimeModule.cls"
