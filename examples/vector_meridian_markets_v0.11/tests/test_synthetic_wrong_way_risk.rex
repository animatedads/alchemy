v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
p=.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,20,"POL-SYN-JPY")
p~addWrongWayEntity("FEDERATIONBANK_HOLDINGS","VMM-FUNDING-DEPENDENCY-FED")
x~setRiskPolicy(p,"VMM-INDEPENDENT-RISK")
a=.VMMPortfolioReferencePosition~new("P-FED","AJI","FED-SENIOR-2031","FEDERATIONBANK_HOLDINGS","BANK_DEBT","JPY",3000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-FED")
b=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB-BASKET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",7000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-WWR","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T131000",.array~of(a,b),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
failed=.false
signal on syntax name expectedRiskReject
x~createOffer("OFF-WWR","REQ-WWR","AJI","AJI-SNAP-WWR","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132000","MODEL-WWR","MKT-WWR","RISK-WWR")
signal off syntax
raise syntax 88.900 array("ASSERT_EXPECTED_WRONG_WAY_REJECTION")
expectedRiskReject:
  failed=.true
  signal off syntax
if \failed then raise syntax 88.900 array("ASSERT_WRONG_WAY_REJECTION")
say "PASS test_synthetic_wrong_way_risk"
exit 0
::requires "VMMSyntheticProducts.cls"
