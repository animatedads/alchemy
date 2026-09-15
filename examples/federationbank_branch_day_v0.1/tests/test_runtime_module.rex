m=.FederationBankBranchDayRuntimeModule~new; .FBBranchDayTest~assertEq("FEDERATIONBANK_BRANCH_DAY",m~moduleId); .FBBranchDayTest~assertEq("0.1",m~moduleVersion)
say "PASS: Branch Day runtime module"
::requires "TestSupport.cls"
::requires "FederationBankBranchDayRuntimeModule.cls"
