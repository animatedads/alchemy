call load
p=.FederationBankBranchCashFixturePolicy~new; v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP")
ignore=v~open(.FBBranchCashTestSupport~control,.FBBranchCashTestSupport~bundle(100000),p)
t=.FBBranchCashTestSupport~transfer("TX-1","VAULT","VAULT-1","TILL","TILL-1",25000); a=.FBBranchCashTestSupport~approval(t)
r=v~reserveOut(t,a,p); .FBBranchCashTestSupport~assertTrue(r~ok)
.FBBranchCashTestSupport~assertEq(v~expectedMinor,100000,"reservation must not yet remove physical cash")
.FBBranchCashTestSupport~assertEq(v~availableMinor,75000)
r=v~commitOut(t); .FBBranchCashTestSupport~assertTrue(r~ok); .FBBranchCashTestSupport~assertEq(v~expectedMinor,75000)
say "PASS: vault outgoing cash is reserved then explicitly committed"
exit 0
load: return
::requires "TestSupport.cls"
