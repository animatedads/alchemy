numeric digits 50
v=.VectorMeridianMarkets~new
/* One arm's-length Treasury event. */
f=.VMMFundingFacility~new("FAC-RPT","FEDERATIONBANK_CORE_TREASURY","VECTOR_MERIDIAN_MARKETS_LTD","CORE_TREASURY_CAPITAL","JPY",500000000,365,"LEGAL-RPT","POL-ARM-RPT","20271231")
v~registerFundingFacility(f)
d=v~drawFunding("DRAW-RPT","FAC-RPT",250000000,"20260910T090000","FB-TREASURY-AUTH","LOAN-RPT")
/* One direct institutional synthetic accrual. */
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-RPT","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-RPT","REQ-RPT","AJI","AJI-SNAP-RPT","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-PREM","MKT-PREM","RISK-PREM")
x~acceptOffer("CON-RPT","OFF-RPT","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
pp=.VMMSyntheticPremiumPeriod~new("PREM-RPT","JPY","20260901","20260930","20261005",120000000,"SCHED-PREM-RPT")
x~setPremiumSchedule("CON-RPT",.array~of(pp),"VMM-OTC-OPS")
a=x~recordPremiumAccrual("ACCR-RPT","CON-RPT","PREM-RPT",30,30,"20260930","ACCR-EVID-RPT","VMM-FINANCE")

eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-09","2026-09-01","2026-09-30"))
acct=.VMMAccountingService~new(v,eng)
call assertTrue acct~postFundingDraw(d,"2026-09-10","2026-09")~ok,"funding draw posts"
call assertTrue acct~postPremiumAccrual(a,"2026-09-30","2026-09")~ok,"premium accrual posts"

rpt=.VMMAccountingReportingService~new(eng)
ev=.array~of("BOARD-APPROVED-BOUNDARY-2026")
whole=.VMMAccountingReportingBoundaryFactory~wholeFirm("RPT-WHOLE","VMM-FINANCE-CONTROL","2026-01-01",ev)
synth=.VMMAccountingReportingBoundaryFactory~institutionalSynthetics("RPT-SYN","VMM-FINANCE-CONTROL","2026-01-01",ev)
fund=.VMMAccountingReportingBoundaryFactory~treasuryFunding("RPT-FUND","VMM-FINANCE-CONTROL","2026-01-01",ev)
wholeView=rpt~view(whole,"2026-09-01","2026-09-30")
synthView=rpt~view(synth,"2026-09-01","2026-09-30")
fundView=rpt~view(fund,"2026-09-01","2026-09-30")
call assertEq 4,wholeView~lineCount,"whole firm contains both balanced journals"
call assertEq 2,synthView~lineCount,"synthetic view contains only premium journal"
call assertEq 2,fundView~lineCount,"funding view contains only Treasury journal"
call assertEq "INSTITUTIONAL_SYNTHETICS",synthView~lines[1]~dimensions["vmm.businessLine"],"synthetic business line retained"
call assertEq "TREASURY_FUNDING",fundView~lines[1]~dimensions["vmm.businessLine"],"funding business line retained"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",whole~includedLegalEntities[1],"boundary is exact VMM entity"
call assertEq "VMM-STAT",whole~includedBookIds[1],"boundary is exact VMM statutory book"

/* A caller cannot smuggle Federation into a VMM reporting boundary. */
bad=.AccountingReportingBoundary~new("BAD","BAD-AUTH","WHOLE_FIRM","2026-01-01","",.array~of("VECTOR_MERIDIAN_MARKETS_LTD","FEDERATIONBANK_MERCHANT_BANK"),.array~of("VMM-STAT"),.directory~new,.VMMAccountingReportingBuild~policyRef,.VMMAccountingReportingBuild~policyIdentityBase||":bad",.array~of("BAD-EVID"),.directory~new)
call expectSyntax rpt,"view",bad,"cross-company reporting boundary rejected"
say "PASS test_accounting_v07_reporting_boundaries"
exit 0

::routine expectSyntax
  use strict arg target,methodName,arg1,label
  signal on syntax name expected
  target~sendWith(methodName,.array~of(arg1))
  signal off syntax
  raise syntax 88.900 array("EXPECTED_SYNTAX",label)
expected:
  signal off syntax
  return
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccountingReporting.cls"
