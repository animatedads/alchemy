v=.VectorMeridianMarkets~new
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
f=.VMMFundingFacility~new("FAC-I","EXTERNAL_LENDER","VECTOR_MERIDIAN_MARKETS_LTD","EXTERNAL_WHOLESALE","GBP",5000000,100,"LEGAL-I","POL-I","20271231")
v~registerFundingFacility(f)
d=.VMMFundingDraw~new("DRAW-I","FAC-I",1000000,"GBP","20260828T120000","LENDER-AUTH","OBL-I")
r1=acct~postFundingDraw(d,"2026-08-28","2026-08")
r2=acct~postFundingDraw(d,"2026-08-28","2026-08")
call assertEq "POSTED",r1~status,"first source event posted"
call assertEq "DUPLICATE",r2~status,"same source event idempotent"
d2=.VMMFundingDraw~new("DRAW-I","FAC-I",1100000,"GBP","20260828T120000","LENDER-AUTH","OBL-I")
r3=acct~postFundingDraw(d2,"2026-08-28","2026-08")
call assertEq "SOURCE_EVENT_CONFLICT",r3~errorCode,"same source identity with changed economics rejected"
call assertEq 1,acct~book~entryCount,"conflict did not mutate book"
say "PASS test_accounting_source_idempotency"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccounting.cls"
