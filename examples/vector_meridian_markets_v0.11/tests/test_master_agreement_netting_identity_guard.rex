v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
aji=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD-AJI")
other=.VMMInstitutionalCounterparty~new("TGI","TOKYO_GENERAL_INSURANCE_CO_LTD","REL-TGI","JP","KYC-TGI","ISDA-TGI","CSA-TGI","VMM-ONBOARD-TGI")
x~registerCounterparty(aji); x~registerCounterparty(other)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",1000000000000,500000000000,100,"RISK-POL"),"VMM-RISK")
p1=.VMMPortfolioReferencePosition~new("P-G1","AJI","JGB-G1","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-G1","","VAL-G1")
s1=.VMMPortfolioSnapshot~new("SNAP-G1","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p1),"POS-G1","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s1)
p2=.VMMPortfolioReferencePosition~new("P-G2","TGI","JGB-G2","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"TOKYO_GENERAL_INSURANCE_CO_LTD","","BOOK-G2","","VAL-G2")
s2=.VMMPortfolioSnapshot~new("SNAP-G2","TGI","TOKYO_GENERAL_INSURANCE_CO_LTD","JPY","20260828",.array~of(p2),"POS-G2","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s2)
x~createOffer("OFF-G1","REQ-G1","AJI","SNAP-G1","JPY",5000000,5,25,50000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-G1","MKT-G1","RISK-G1")
k1=x~acceptOffer("CON-G1","OFF-G1","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
x~createOffer("OFF-G2","REQ-G2","TGI","SNAP-G2","JPY",5000000,5,25,50000,"20260901","20310831","20260828T140100","20260828T132300","MODEL-G2","MKT-G2","RISK-G2")
k2=x~acceptOffer("CON-G2","OFF-G2","20260828T132400","TOKYO_GENERAL_INSURANCE_CO_LTD","TGI-SIGNER")
d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",0,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")

ev1=d~declareDefault("DEF-G1",k1~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INS-G1","VMM-LEGAL")
d~assessUncured("UNC-G1",ev1~eventId,"2026-10-07","UNC-G1","VMM-LEGAL")
t1=d~electTermination("TERM-G1",ev1~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-G1","VA-G1","VMM-LEGAL")
co1=d~determineCloseout("CO-G1",t1~terminationId,1000000,"2026-10-10","METHOD-G1","MKT-G1","CSA-G1","VMM-VALUATION")
ops~finalizeCloseout("FINAL-G1",co1~closeoutId,"2026-10-11","VMM-LEGAL")
ev2=d~declareDefault("DEF-G2",k2~contractId,"INSOLVENCY","TOKYO_GENERAL_INSURANCE_CO_LTD","2026-10-06","2026-10-06","INS-G2","VMM-LEGAL")
d~assessUncured("UNC-G2",ev2~eventId,"2026-10-07","UNC-G2","VMM-LEGAL")
t2=d~electTermination("TERM-G2",ev2~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-G2","VA-G2","VMM-LEGAL")
co2=d~determineCloseout("CO-G2",t2~terminationId,-500000,"2026-10-10","METHOD-G2","MKT-G2","CSA-G2","VMM-VALUATION")
ops~finalizeCloseout("FINAL-G2",co2~closeoutId,"2026-10-11","VMM-LEGAL")
blocked=.false
signal on syntax name crossParty
ignore=ops~createNettingSet("NETSET-BAD",.array~of(k1~contractId,k2~contractId),"ENGLISH_LAW","LEGAL-OPINION-BAD","ELECTION-BAD","2026-10-11","VMM-LEGAL")
signal off syntax
raise syntax 88.900 array("ASSERT_CROSS_COUNTERPARTY_NETTING_ACCEPTED")
crossParty:
  blocked=.true; signal off syntax
call assertTrue blocked,"different counterparties/master agreements cannot be netted merely because currency matches"
call assertTrue \ops~isCloseoutCashSettled(co1~closeoutId),"failed netting attempt does not mutate first settlement state"
call assertTrue \ops~isCloseoutCashSettled(co2~closeoutId),"failed netting attempt does not mutate second settlement state"
say "PASS test_master_agreement_netting_identity_guard"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMCloseoutOperations.cls"
