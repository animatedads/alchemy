p=.FBBranchTillTest~openTill; t=p["till"]; c=p["context"]
a=.FederationBankBranchTillAdapter~new(t,c,"CASH-SUP-02","STAFF-AUTH:CASH-SUP-02")
x=.FBBranchTillTest~transfer("TX-BIND","VAULT","VAULT-1","TILL","TILL-04",20000); auth=.FBBranchTillTest~authority(x)
y=.FBBranchTillTest~transfer("TX-BIND","VAULT","VAULT-1","TILL","TILL-04",21000)
before=t~expectedMinor
r=a~accept(y,auth)
.FBBranchTillTest~assertTrue(\r~ok); .FBBranchTillTest~assertEq("BRANCH_CASH_AUTHORITY_MISMATCH",r~code); .FBBranchTillTest~assertEq(before,t~expectedMinor)
say "PASS: Branch Cash authority cannot be reused for a modified till transfer"
::requires "TestSupport.cls"
