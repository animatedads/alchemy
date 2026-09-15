p=.FBBranchTillTest~openTill("TILL-04","TELLER-04",10000); till=p["till"]; ctx=p["context"]
adapter=.FederationBankBranchTillAdapter~new(till,ctx,"CASH-SUP-02","STAFF-AUTH:CASH-SUP-02")
ports=.directory~new; ports["TILL:TILL-04"]=adapter
svc=.FederationBankBranchCashService~new(.FederationBankBranchCashFixturePolicy~new,ports)
vault=.FBBranchTillTest~openVault(100000); ignore=svc~addVault(vault)
x=.FBBranchTillTest~transfer("TX-V2T","VAULT","VAULT-1","TILL","TILL-04",25000); apr=.FBBranchTillTest~branchApproval(x)
r=svc~submit("CMD-V2T","CORR-V2T",x,apr)
.FBBranchTillTest~assertTrue(r~ok,"service failed "||r~code)
w=r~value
.FBBranchTillTest~assertEq("COMPLETED",w~state)
.FBBranchTillTest~assertTrue(w~authority~isA(.FederationBankBranchCashAuthorityEnvelope))
.FBBranchTillTest~assertTrue(w~authority~matchesTransfer(x))
.FBBranchTillTest~assertEq(35000,till~expectedMinor)
.FBBranchTillTest~assertEq(75000,vault~expectedMinor)
say "PASS: vault-to-till path carries exact Branch Cash authority into independent Till custody"
::requires "TestSupport.cls"
