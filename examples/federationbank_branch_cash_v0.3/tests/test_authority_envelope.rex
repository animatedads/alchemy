b=.FBBranchCashTestSupport~bundle(25000)
t=.FederationBankBranchCashTransfer~new("TX-AUTH","DOUGLAS","VAULT","VAULT-1","TILL","TILL-04",b,"REPLENISHMENT","BRANCH-OPS","STAFF-AUTH:BRANCH-OPS")
a=.FederationBankBranchCashApproval~new("APR-AUTH",t~semanticIdentity,"CASH-SUP-01","STAFF-AUTH:CASH-SUP-01")
r=.FederationBankBranchCashAuthorityIssuer~new~issue(t,a,.FederationBankBranchCashFixturePolicy~new)
.FBBranchCashTestSupport~assertTrue(r~ok)
e=r~value
.FBBranchCashTestSupport~assertTrue(e~isA(.FederationBankBranchCashAuthorityEnvelope))
.FBBranchCashTestSupport~assertTrue(e~matchesTransfer(t))
.FBBranchCashTestSupport~assertEq(t~semanticIdentity,e~transferIdentity)
.FBBranchCashTestSupport~assertEq("APR-AUTH",e~checkerApprovalId)
.FBBranchCashTestSupport~assertEq("CASH-SUP-01",e~checkerStaffId)

b2=.FBBranchCashTestSupport~bundle(26000)
t2=.FederationBankBranchCashTransfer~new("TX-AUTH","DOUGLAS","VAULT","VAULT-1","TILL","TILL-04",b2,"REPLENISHMENT","BRANCH-OPS","STAFF-AUTH:BRANCH-OPS")
.FBBranchCashTestSupport~assertTrue(\e~matchesTransfer(t2))

bad=.FederationBankBranchCashApproval~new("APR-BAD",t~semanticIdentity,"BRANCH-OPS","STAFF-AUTH:BRANCH-OPS")
r2=.FederationBankBranchCashAuthorityIssuer~new~issue(t,bad,.FederationBankBranchCashFixturePolicy~new)
.FBBranchCashTestSupport~assertTrue(\r2~ok)
.FBBranchCashTestSupport~assertEq("SEPARATION_OF_DUTIES",r2~code)
say "PASS: exact Branch Cash authority envelope binds transfer, checker and upstream staff authority"
::requires "TestSupport.cls"
