v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-DEF-CURE","AJI","JGB-CURE","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","BOOK-CURE","","VAL-CURE")
s=.VMMPortfolioSnapshot~new("SNAP-DEF-CURE","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"AJI-POSITIONS-CURE","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-DEF-CURE","REQ-DEF-CURE","AJI","SNAP-DEF-CURE","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-CURE","MKT-CURE","RISK-CURE")
k=x~acceptOffer("CON-DEF-CURE","OFF-DEF-CURE","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
pp=.VMMSyntheticPremiumPeriod~new("PREM-DEF-CURE","JPY","20260901","20260930","20261005",120000000,"SCHED-CURE")
x~setPremiumSchedule(k~contractId,.array~of(pp),"VMM-OTC-OPS")
x~recordPremiumAccrual("ACCR-DEF-CURE",k~contractId,pp~periodId,30,30,"20260930","ACCR-EVID-CURE","VMM-FINANCE")

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-POL-JPY","JPY",2,1,3,"ISDA-2002-CLOSEOUT-AMOUNT","POL-DEFAULT-JPY"),"VMM-LEGAL")
e=d~declareDefault("DEF-CURE-1",k~contractId,"FAILURE_TO_PAY_PREMIUM","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","UNPAID-PREMIUM-EVIDENCE","VMM-LEGAL")
call assertEq "2026-10-08",e~cureDeadline,"payment cure deadline derived from policy"
call assertEq "OPEN",e~state,"default begins as notice/open rather than termination"
call assertEq "ACTIVE",k~state,"default notice alone does not terminate contract"
cu=d~cureDefault("CURE-1",e~eventId,"ALL_JAPAN_INSURANCE","2026-10-08","PAYMENT-CURE-EVIDENCE","AJI-TREASURY")
call assertEq "CURED",e~state,"timely cure closes default event"
call assertEq "ACTIVE",k~state,"timely cure leaves contract active"
call assertEq "ALL_JAPAN_INSURANCE",cu~curingEntity,"cure authority belongs to defaulting party"
lateRejected=.false
signal on syntax name late
ignore=d~assessUncured("UNCURED-BAD",e~eventId,"2026-10-09","NO-CURE-EVID","VMM-LEGAL")
signal off syntax
late:
  lateRejected=.true; signal off syntax
call assertTrue lateRejected,"cured event cannot later be relabelled uncured"
say "PASS test_synthetic_default_cure"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMDefaultCloseout.cls"
