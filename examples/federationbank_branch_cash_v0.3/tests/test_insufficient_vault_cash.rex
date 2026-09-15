call load
p=.FederationBankBranchCashFixturePolicy~new; v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP")
ignore=v~open(.FBBranchCashTestSupport~control,.FBBranchCashTestSupport~bundle(5000),p)
t=.FBBranchCashTestSupport~transfer("TX-1","VAULT","VAULT-1","TILL","TILL-1",6000); r=v~reserveOut(t,.FBBranchCashTestSupport~approval(t),p)
.FBBranchCashTestSupport~assertEq(r~code,"INSUFFICIENT_VAULT_CASH")
say "PASS: branch vault cannot promise physical cash it does not hold"
exit 0
load: return
::requires "TestSupport.cls"
