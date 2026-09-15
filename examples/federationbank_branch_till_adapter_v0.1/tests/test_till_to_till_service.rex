p1=.FBBranchTillTest~openTill("TILL-04","TELLER-04",50000); p2=.FBBranchTillTest~openTill("TILL-05","TELLER-05",10000)
a1=.FederationBankBranchTillAdapter~new(p1["till"],p1["context"],"CASH-SUP-02","STAFF-AUTH:CASH-SUP-02")
a2=.FederationBankBranchTillAdapter~new(p2["till"],p2["context"],"CASH-SUP-03","STAFF-AUTH:CASH-SUP-03")
ports=.directory~new; ports["TILL:TILL-04"]=a1; ports["TILL:TILL-05"]=a2
svc=.FederationBankBranchCashService~new(.FederationBankBranchCashFixturePolicy~new,ports)
x=.FBBranchTillTest~transfer("TX-T2T","TILL","TILL-04","TILL","TILL-05",15000); apr=.FBBranchTillTest~branchApproval(x)
r=svc~submit("CMD-T2T","CORR-T2T",x,apr)
.FBBranchTillTest~assertTrue(r~ok,"service failed "||r~code)
.FBBranchTillTest~assertEq(35000,p1["till"]~expectedMinor); .FBBranchTillTest~assertEq(25000,p2["till"]~expectedMinor)
say "PASS: till-to-till transfer preserves one Branch Cash authority across two independent till custody decisions"
::requires "TestSupport.cls"
