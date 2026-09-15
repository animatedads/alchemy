v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-E","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-E","REQ-E","AJI","AJI-SNAP-E","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-E","MKT-E","RISK-E")
rejected=.false
signal on syntax name expired
x~acceptOffer("CON-E","OFF-E","20260828T140001","ALL_JAPAN_INSURANCE","AJI-SIGNER")
signal off syntax
raise syntax 88.900 array("ASSERT_EXPIRED_OFFER_ACCEPTED")
expired:
  rejected=.true
  signal off syntax
if \rejected then raise syntax 88.900 array("ASSERT_EXPIRED_OFFER_REJECTION")
call assertEq "OPEN",x~offer("OFF-E")~state,"expired acceptance does not mutate offer state"
say "PASS test_synthetic_offer_expiry"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
