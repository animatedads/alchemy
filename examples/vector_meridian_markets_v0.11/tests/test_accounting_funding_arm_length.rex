v=.VectorMeridianMarkets~new
f=.VMMFundingFacility~new("FAC-A","FEDERATIONBANK_CORE_TREASURY","VECTOR_MERIDIAN_MARKETS_LTD","CORE_TREASURY_CAPITAL","GBP",10000000,365,"LEGAL-LOAN-A","POL-ARM-LENGTH","20271231")
v~registerFundingFacility(f)
d=v~drawFunding("DRAW-A","FAC-A",2500000,"20260828T120000","FB-TREASURY-AUTH","LOAN-OBL-A")
a=v~accrueFundingCost("INT-A","FAC-A",10,"20260828T130000","VMM-TREASURY")
r=v~repayFunding("REPAY-A","FAC-A",500000,"20260828T140000","VMM-TREASURY","LOAN-OBL-A")
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
call assertTrue acct~postFundingDraw(d,"2026-08-28","2026-08")~ok,"funding draw posted"
call assertTrue acct~postFundingAccrual(a,"2026-08-28","2026-08")~ok,"funding interest posted"
call assertTrue acct~postFundingRepayment(r,"2026-08-28","2026-08")~ok,"funding repayment posted"
call assertEq 200000000,acct~book~balance("2100","GBP")~creditMinor-acct~book~balance("2100","GBP")~debitMinor,"borrowing liability after repayment"
call assertEq 200000000,acct~book~balance("1000","GBP")~netDebitMinor,"net principal cash after repayment"
call assertEq "FEDERATIONBANK_CORE_TREASURY",acct~book~entries[1]~lines[1]~dimensions["lenderEntity"],"lender retained as dimension not book owner"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",acct~book~legalEntityId,"only VMM book was posted"
say "PASS test_accounting_funding_arm_length"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccounting.cls"
