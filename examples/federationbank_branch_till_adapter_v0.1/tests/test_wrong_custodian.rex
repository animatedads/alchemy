p=.FBBranchTillTest~openTill("TILL-04","TELLER-04",10000); till=p["till"]
wrong=.FBBranchTillTest~context("TILL-04","TELLER-99")
a=.FederationBankBranchTillAdapter~new(till,wrong,"CASH-SUP-02","STAFF-AUTH:CASH-SUP-02")
x=.FBBranchTillTest~transfer("TX-CUST","VAULT","VAULT-1","TILL","TILL-04",20000); auth=.FBBranchTillTest~authority(x)
r=a~accept(x,auth)
.FBBranchTillTest~assertTrue(\r~ok); .FBBranchTillTest~assertEq("NOT_CUSTODIAN",r~code); .FBBranchTillTest~assertEq(10000,till~expectedMinor)
say "PASS: valid Branch Cash authority does not override current till custody"
::requires "TestSupport.cls"
