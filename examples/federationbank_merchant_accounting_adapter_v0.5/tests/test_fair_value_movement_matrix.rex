t=.MBAccountingTest~new
adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
call postOne adapter,"E1","S1","A1","ASSET","INCREASE",100
call postOne adapter,"E2","S2","A2","ASSET","DECREASE",30
call postOne adapter,"E3","S3","L1","LIABILITY","INCREASE",80
call postOne adapter,"E4","S4","L2","LIABILITY","DECREASE",20

t~assertEq(70,adapter~book~balance("1300","GBP")~netDebitMinor,"asset carrying movements use asset account")
t~assertEq(-60,adapter~book~balance("2300","GBP")~netDebitMinor,"liability carrying movements use liability account")
t~assertEq(-120,adapter~book~balance("4100","GBP")~netDebitMinor,"asset increase and liability decrease produce gains")
t~assertEq(110,adapter~book~balance("5100","GBP")~netDebitMinor,"asset decrease and liability increase produce losses")
t~assertEq(4,adapter~book~entryCount,"each attributable movement remains its own journal")

say "fair value matrix assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::routine postOne
  use arg adapter,eid,sref,trade,side,direction,amount
  e=.MBAccountingDerivativeFairValueMovementEvidence~new(eid,"FEDERATIONBANK_MERCHANT_BANK",sref,"2026-08-28","2026-08",trade,"PF-M","ROOT-M","GBP",amount,side,direction,"MERCHANT_VALUATION")
  r=adapter~postDerivativeFairValueMovement(e)
  if r~status<>"POSTED" then do
    say "FAIL: movement did not post" eid r~errorCode r~message
    exit 1
  end
  return

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"
