call load
m=.FederationBankBranchCashServiceRuntimeModule~new; .FBBranchCashServiceTestSupport~assertEq(m~moduleId,"FEDERATIONBANK_BRANCH_CASH_SERVICE"); .FBBranchCashServiceTestSupport~assertEq(m~moduleVersion,"0.3")
say "PASS: Branch Cash service runtime module"
exit 0
load: return
::requires "FederationBankBranchCashServiceRuntimeModule.cls"
::requires "TestSupport.cls"
