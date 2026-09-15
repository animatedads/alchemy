call load
m=.FederationBankBranchCashRuntimeModule~new
.FBBranchCashTestSupport~assertEq(m~moduleId,"FEDERATIONBANK_BRANCH_CASH")
.FBBranchCashTestSupport~assertEq(m~moduleVersion,"0.3")
say "PASS: Branch Cash runtime module"
exit 0
load: return
::requires "TestSupport.cls"
::requires "FederationBankBranchCashRuntimeModule.cls"
