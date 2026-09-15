call load
p=.FederationBankBranchCashFixturePolicy~new; v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP")
ignore=v~open(.FBBranchCashTestSupport~control,.FBBranchCashTestSupport~bundle(10000),p)
c2=.FBBranchCashTestSupport~control("VAULT-1","IOM-DOUGLAS","STAFF-C","STAFF-D","CTRL-2")
r=v~handover(c2,.FBBranchCashTestSupport~bundle(10000),p); .FBBranchCashTestSupport~assertTrue(r~ok)
.FBBranchCashTestSupport~assertEq(v~primaryStaffId,"STAFF-C"); .FBBranchCashTestSupport~assertEq(v~checkerStaffId,"STAFF-D")
say "PASS: balanced branch vault can transfer dual custody"
exit 0
load: return
::requires "TestSupport.cls"
