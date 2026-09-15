v=.VectorMeridianMarkets~new
f=.VMMFundingFacility~new("FAC-CORE-1","FEDERATIONBANK_CORE_TREASURY","VECTOR_MERIDIAN_MARKETS_LTD","CORE_TREASURY_CAPITAL","GBP",10000000,425,"LEGAL-INTERCO-LOAN-1","POL-ARM-LENGTH-7","20271231")
v~registerFundingFacility(f)
d=v~drawFunding("DRAW-1","FAC-CORE-1",2500000,"20260828T102000","FEDERATIONBANK_TREASURY_AUTH","LOAN-OBL-1001")
call assertEq 2500000,f~outstanding,"arm length debt outstanding"
call assertEq "LOAN-OBL-1001",d~loanObligationRef,"draw is a loan obligation"
call expectBadSource
call expectWrongBorrower
say "PASS test_arm_length_funding"
exit 0

::routine expectBadSource
  signal on syntax name gotSyntax
  f=.VMMFundingFacility~new("FAC-X","FEDERATIONBANK_RETAIL","VECTOR_MERIDIAN_MARKETS_LTD","CUSTOMER_DEPOSIT","GBP",1000,100,"LEGAL-X","POL-X","20271231")
  signal off syntax
  raise syntax 88.900 array("direct customer deposit funding unexpectedly accepted",f)
gotSyntax:
  signal off syntax
  return

::routine expectWrongBorrower
  signal on syntax name gotSyntax2
  f=.VMMFundingFacility~new("FAC-Y","FEDERATIONBANK_CORE_TREASURY","FEDERATIONBANK_MERCHANT_BANK","CORE_TREASURY_CAPITAL","GBP",1000,100,"LEGAL-Y","POL-Y","20271231")
  signal off syntax
  raise syntax 88.900 array("wrong borrower unexpectedly accepted",f)
gotSyntax2:
  signal off syntax
  return

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
