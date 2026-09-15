t=.MBAccountingTest~new
scale=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP","GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP")
t~assertEq(1234,scale~toMinor(12.34,"GBP","exact amount"),"exact two-decimal amount converts")
call expectScaleSyntax scale,12.345,"GBP",t
call expectScaleSyntax scale,12.34,"USD",t
say "currency scale assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::routine expectScaleSyntax
  use strict arg scale,amount,currency,t
  caught=.false
  signal on syntax name got
  x=scale~toMinor(amount,currency,"probe")
  signal off syntax
  t~assertTrue(.false,"non-exact/wrong-currency scale must fail")
  return
got:
  caught=.true
  signal off syntax
  t~assertTrue(caught,"scale guard raised syntax")
  return

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"
