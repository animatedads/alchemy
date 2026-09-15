p=.FBBranchTillTest~openTill; t=p["till"]; c=p["context"]
a=.FederationBankBranchTillAdapter~new(t,c,"CASH-SUP-02","STAFF-AUTH:CASH-SUP-02")
x=.FBBranchTillTest~transfer
before=t~expectedMinor
r=a~accept(x,.nil)
.FBBranchTillTest~assertTrue(\r~ok); .FBBranchTillTest~assertEq("BRANCH_CASH_AUTHORITY_REQUIRED",r~code); .FBBranchTillTest~assertEq(before,t~expectedMinor)
say "PASS: till adapter refuses a raw transfer without typed Branch Cash authority"
::requires "TestSupport.cls"
