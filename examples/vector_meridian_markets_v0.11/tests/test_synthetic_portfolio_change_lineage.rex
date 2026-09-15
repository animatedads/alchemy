v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
r=.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,20,"POL-SYN-JPY"); r~addWrongWayEntity("FEDERATIONBANK_HOLDINGS","VMM-FUNDING-DEPENDENCY-FED")
x~setRiskPolicy(r,"VMM-RISK")
x~setLifecyclePolicy(.VMMSyntheticLifecyclePolicy~new("LIFE-JPY","JPY",5,10,80,"POL-LIFE-JPY"),"VMM-RISK")
p1=.VMMPortfolioReferencePosition~new("P1","AJI","JGB-A","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","BOOK-A","","VAL-A")
s1=.VMMPortfolioSnapshot~new("SNAP-A","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T130000",.array~of(p1),"AJI-POSITIONS-A","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s1)
p2=.VMMPortfolioReferencePosition~new("P2","AJI","JGB-B","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10200000000,"ALL_JAPAN_INSURANCE","","BOOK-B","","VAL-B")
s2=.VMMPortfolioSnapshot~new("SNAP-B","AJI","ALL_JAPAN_INSURANCE","JPY","20260930T130000",.array~of(p2),"AJI-POSITIONS-B","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s2)
p3=.VMMPortfolioReferencePosition~new("P3","AJI","JGB-REDEMPTION","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",8000000000,"ALL_JAPAN_INSURANCE","","BOOK-C","","VAL-C")
s3=.VMMPortfolioSnapshot~new("SNAP-C","AJI","ALL_JAPAN_INSURANCE","JPY","20261031T130000",.array~of(p3),"AJI-POSITIONS-C","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s3)
x~createOffer("OFF-PC","REQ-PC","AJI","SNAP-A","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-PC","MKT-PC","RISK-PC")
k=x~acceptOffer("CON-PC","OFF-PC","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
ch1=x~applyPortfolioChange("CHG-1","CON-PC","SNAP-B","CLIENT_SUBSTITUTION","20260930","AJI-SUBSTITUTION-EVID","VMM-RISK-APPROVAL","VMM-OTC-CONTROL")
call assertNear 2,ch1~valueDriftPct,0.000001,"client substitution value drift"
call assertEq "SNAP-B",k~currentSnapshotId,"contract points to substituted immutable snapshot"
call assertNear 10000000000,k~initialReferenceValue,0.01,"substitution does not rewrite original reference value"
ch2=x~applyPortfolioChange("CHG-2","CON-PC","SNAP-C","CORPORATE_ACTION","20261031","REDEMPTION-CORP-ACTION-EVID","VMM-RISK-APPROVAL-2","VMM-OTC-CONTROL")
call assertEq "CORPORATE_ACTION",ch2~changeType,"corporate action retained as distinct lifecycle cause"
call assertEq "SNAP-C",k~currentSnapshotId,"corporate action advances reference lineage"
/* A replacement snapshot that creates excessive wrong-way exposure is rejected before contract mutation. */
wp=.VMMPortfolioReferencePosition~new("PW","AJI","FED-DEBT","FEDERATIONBANK_HOLDINGS","BANK_DEBT","JPY",3000000000,"ALL_JAPAN_INSURANCE","","BOOK-W","","VAL-W")
jp=.VMMPortfolioReferencePosition~new("PJ","AJI","JGB-W","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",7000000000,"ALL_JAPAN_INSURANCE","","BOOK-W","","VAL-J")
sw=.VMMPortfolioSnapshot~new("SNAP-W","AJI","ALL_JAPAN_INSURANCE","JPY","20261130T130000",.array~of(wp,jp),"AJI-POSITIONS-W","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(sw)
blocked=.false
signal on syntax name wrongWay
x~applyPortfolioChange("CHG-W","CON-PC","SNAP-W","CORPORATE_ACTION","20261130","CORP-EVID-W","RISK-W","VMM-OTC-CONTROL")
signal off syntax
raise syntax 88.900 array("ASSERT_WRONG_WAY_PORTFOLIO_CHANGE_ACCEPTED")
wrongWay:
  blocked=.true; signal off syntax
if \blocked then raise syntax 88.900 array("ASSERT_WRONG_WAY_PORTFOLIO_CHANGE_REJECTION")
call assertEq "SNAP-C",k~currentSnapshotId,"rejected change cannot mutate contract reference snapshot"
say "PASS test_synthetic_portfolio_change_lineage"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
