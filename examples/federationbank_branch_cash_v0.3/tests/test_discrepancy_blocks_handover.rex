call load
p=.FederationBankBranchCashFixturePolicy~new; v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP")
ignore=v~open(.FBBranchCashTestSupport~control,.FBBranchCashTestSupport~bundle(10000),p)
c2=.FBBranchCashTestSupport~control("VAULT-1","IOM-DOUGLAS","STAFF-C","STAFF-D","CTRL-2")
r=v~handover(c2,.FBBranchCashTestSupport~bundle(9999),p)
.FBBranchCashTestSupport~assertEq(r~code,"VAULT_DISCREPANCY_REQUIRES_RESOLUTION")
.FBBranchCashTestSupport~assertEq(v~primaryStaffId,"STAFF-A")
say "PASS: custody handover cannot conceal a vault discrepancy"
exit 0
load: return
::requires "TestSupport.cls"
