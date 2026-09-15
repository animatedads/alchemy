t=.MBAccountingTest~new
numeric digits 50
adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
huge="1234567890123456789012345678901234567890"
e=.MBAccountingDerivativeFairValueTransitionEvidence~new("HUGE-EV","FEDERATIONBANK_MERCHANT_BANK","MB:FV:HUGE:1","2026-08-28","2026-08","T-HUGE","PF-HUGE","ROOT-HUGE","JPY","0",huge,"OPENING_ZERO","MARK-HUGE","VAL-HUGE","MKT-HUGE","JPY-0DP","FEDERATIONBANK_MERCHANT_BANK:VALUATION")
r=adapter~postDerivativeFairValueTransition(e)
t~assertEq("POSTED",r~status,"40-digit Merchant minor-unit transition posts under Accounting Core v0.4 precision contract")
t~assertEq(huge,adapter~book~balance("1300","JPY")~netDebitMinor,"40-digit derivative carrying amount remains exact")
t~assertEq(-huge,adapter~book~balance("4100","JPY")~netDebitMinor,"40-digit fair-value gain remains exact")
t~assertEq("accounting.integer-minor-unit.numeric-digits-50/0.1",adapter~book~arithmeticProfile,"Merchant book exposes Accounting Core arithmetic profile")
call expectTooWide adapter,t
t~assertEq(1,adapter~book~entryCount,"oversized amount cannot create a journal")
say "numeric digits assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::routine expectTooWide
  use strict arg adapter,t
  tooWide="123456789012345678901234567890123456789012345678901"
  signal on syntax name caught
  e=.MBAccountingDerivativeFairValueTransitionEvidence~new("TOO-WIDE","FEDERATIONBANK_MERCHANT_BANK","MB:FV:HUGE:2","2026-08-28","2026-08","T-WIDE","PF-WIDE","ROOT-WIDE","JPY","0",tooWide,"OPENING_ZERO","MARK-WIDE","VAL-WIDE","MKT-WIDE","JPY-0DP","FEDERATIONBANK_MERCHANT_BANK:VALUATION")
  signal off syntax
  t~assertTrue(.false,"51-digit Merchant amount must fail before accounting policy execution")
  return
caught:
  signal off syntax
  t~assertTrue(.true,"oversized Merchant amount fails at precision boundary")
  return

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"
