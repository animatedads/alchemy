m=.FederationBankBranchDayServiceRuntimeModule~new; .FBBranchDayServiceTest~assertEq(m~moduleId,"FEDERATIONBANK_BRANCH_DAY_SERVICE"); .FBBranchDayServiceTest~assertEq(m~moduleVersion,"0.1")
say "PASS: Branch Day service runtime module"
::requires "TestSupport.cls"
::requires "FederationBankBranchDayServiceRuntimeModule.cls"
