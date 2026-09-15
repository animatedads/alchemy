call load
v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP"); p=.FederationBankBranchCashFixturePolicy~new
r=v~open(.FBBranchCashTestSupport~control,.FBBranchCashTestSupport~bundle(100000),p)
.FBBranchCashTestSupport~assertTrue(r~ok,"vault should open under dual control")
.FBBranchCashTestSupport~assertEq(v~expectedMinor,100000)
say "PASS: vault opening requires explicit dual custody"
exit 0
load: return
::requires "TestSupport.cls"
