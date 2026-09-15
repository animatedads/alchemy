v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",100000000000,50000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-IMRET","AJI","JGB-IMRET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-IMRET","","VAL-IMRET")
s=.VMMPortfolioSnapshot~new("SNAP-IMRET","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-IMRET","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-IMRET","REQ-IMRET","AJI","SNAP-IMRET","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-IMRET","MKT-IMRET","RISK-IMRET")
k=x~acceptOffer("CON-IMRET","OFF-IMRET","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
x~setInitialMarginTerms(k~contractId,.VMMSyntheticInitialMarginTerms~new("IM-TERMS-IMRET","JPY",900000,"SOVEREIGN_BOND",1000,"IM-POL-IMRET"),"VMM-COLLATERAL")
im=.VMMSyntheticInitialMarginTransfer~new("IM-XFER-IMRET",k~contractId,"JPY","JGB-COLL-IMRET","SOVEREIGN_BOND",1000000,500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","THIRD_PARTY_CUSTODIAN","CONTROL-IMRET","20260901T090000","VMM-COLLATERAL")
x~recordInitialMarginTransfer(im)
call assertNear 950000,x~initialMarginRecognized(k~contractId),0.01,"historical initial margin recognized before termination"

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",0,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")
ev=d~declareDefault("DEF-IMRET",k~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-IMRET","VMM-LEGAL")
d~assessUncured("UNCURED-IMRET",ev~eventId,"2026-10-07","UNCURED-IMRET","VMM-LEGAL")
t=d~electTermination("TERM-IMRET",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-IMRET","VAL-AGENT-IMRET","VMM-LEGAL")
co=d~determineCloseout("CLOSE-IMRET",t~terminationId,-500000,"2026-10-10","ISDA-METHOD","MKT-IMRET","CSA-NET-IMRET","VMM-VALUATION")
f=ops~finalizeCloseout("FINAL-IMRET",co~closeoutId,"2026-10-11","VMM-LEGAL")

blocked=.false
signal on syntax name beforeCash
ignore=ops~instructInitialMarginReturn("RETURN-EARLY",co~closeoutId,im~transferId,"2026-10-11","RETURN-INSTRUCTION-EARLY","VMM-COLLATERAL")
signal off syntax
raise syntax 88.900 array("ASSERT_IM_RETURN_BEFORE_CLOSEOUT_SETTLEMENT")
beforeCash:
  blocked=.true; signal off syntax
call assertTrue blocked,"segregated IM cannot be treated as returned before close-out cash settles"

settle=d~settleCloseout("SETTLE-IMRET",co~closeoutId,"2026-10-12","BANK-CLOSEOUT-IMRET","VMM-TREASURY")
ret=ops~instructInitialMarginReturn("RETURN-IMRET",co~closeoutId,im~transferId,"2026-10-12","RETURN-INSTRUCTION-IMRET","VMM-COLLATERAL")
call assertEq "INSTRUCTED",ret~state,"custody return begins as explicit instruction"
call assertEq "2026-10-15",ret~dueDate,"return due date derives from VMM close-out operations policy"
call assertNear 950000,ops~effectiveInitialMarginRecognized(k~contractId),0.01,"risk-recognized IM remains until custody actually returns asset"
ack=ops~acknowledgeCustodyReturn("ACK-IMRET",ret~returnId,"2026-10-13","CUSTODIAN-ACK-IMRET","VMM-COLLATERAL")
call assertEq "ACKNOWLEDGED",ret~state,"custodian acknowledgement is distinct from settlement"
cs=ops~settleCustodyReturn("CUSTODY-SETTLE-IMRET",ret~returnId,"2026-10-14","CONTROL-RETURNED-IMRET","CUSTODIAN-RECEIPT-IMRET","VMM-COLLATERAL")
call assertEq "SETTLED",ret~state,"custody settlement completes segregated asset return"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",cs~returnedToEntity,"segregated VMM asset returns to VMM legal entity"
call assertNear 0,ops~effectiveInitialMarginRecognized(k~contractId),0.01,"effective IM falls only after custody return settles"
call assertNear 950000,x~initialMarginRecognized(k~contractId),0.01,"historical product-service transfer evidence is not rewritten by return"
say "PASS test_post_termination_initial_margin_custody_return"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMCloseoutOperations.cls"
