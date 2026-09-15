call load
p=.FederationBankBranchCashFixturePolicy~new; v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP")
ignore=v~open(.FBBranchCashTestSupport~control,.FBBranchCashTestSupport~bundle(100000),p)
t1=.FBBranchCashTestSupport~transfer("TX-1","VAULT","VAULT-1","TILL","TILL-1",10000); t2=.FBBranchCashTestSupport~transfer("TX-2","VAULT","VAULT-1","TILL","TILL-1",20000)
a=.FBBranchCashTestSupport~approval(t1); r=v~reserveOut(t2,a,p)
.FBBranchCashTestSupport~assertEq(r~code,"APPROVAL_TRANSFER_MISMATCH")
say "PASS: checker approval is bound to exact internal cash transfer"
exit 0
load: return
::requires "TestSupport.cls"
