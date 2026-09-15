p=.FBBranchTillTest~openTill("TILL-04","TELLER-04",50000); till=p["till"]; ctx=p["context"]
adapter=.FederationBankBranchTillAdapter~new(till,ctx,"CASH-SUP-02","STAFF-AUTH:CASH-SUP-02")
ports=.directory~new; ports["TILL:TILL-04"]=adapter
svc=.FederationBankBranchCashService~new(.FederationBankBranchCashFixturePolicy~new,ports)
vault=.FBBranchTillTest~openVault(100000); ignore=svc~addVault(vault)
x=.FBBranchTillTest~transfer("TX-T2V","TILL","TILL-04","VAULT","VAULT-1",20000); apr=.FBBranchTillTest~branchApproval(x)
r=svc~submit("CMD-T2V","CORR-T2V",x,apr)
.FBBranchTillTest~assertTrue(r~ok,"service failed "||r~code)
.FBBranchTillTest~assertEq(30000,till~expectedMinor); .FBBranchTillTest~assertEq(120000,vault~expectedMinor)
say "PASS: till skim uses Branch Cash authority and Till custody without customer semantics"
::requires "TestSupport.cls"
