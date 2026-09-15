signal on syntax name expectedFailure
x=.FederationBankBranchDayControlTotals~new("GBP",100000,0,0,0,0,100,"",100100,"CTRL")
say "FAIL: unapproved adjustment constructed"; exit 1
expectedFailure:
say "PASS: end-of-day cash adjustment cannot exist without an authority reference"; exit 0
::requires "TestSupport.cls"
