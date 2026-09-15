numeric digits 50
storePath="./tests/tmp_vmm_accounting_reporting_restart_v011.jsonl"
v=.VectorMeridianMarkets~new
f=.VMMFundingFacility~new("FAC-RST-RPT","FEDERATIONBANK_MERCHANT_CAPITAL","VECTOR_MERIDIAN_MARKETS_LTD","MERCHANT_CAPITAL","GBP",10000000,300,"LEGAL-RST-RPT","POL-RST-RPT","20271231")
v~registerFundingFacility(f)
d=v~drawFunding("DRAW-RST-RPT","FAC-RST-RPT",2000000,"20260828T090000","FB-MERCHANT-AUTH","LOAN-RST-RPT")
eng=.VMMAccountingStore~createEngine(storePath,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
call assertTrue acct~postFundingDraw(d,"2026-08-28","2026-08")~ok,"durable funding post"
ev=.array~of("REPORT-CONTROL-EVID")
b=.VMMAccountingReportingBoundaryFactory~treasuryFunding("RPT-RST","VMM-FINANCE-CONTROL","2026-01-01",ev)
view1=.VMMAccountingReportingService~new(eng)~view(b)
call assertEq 2,view1~lineCount,"pre-restart funding report"

eng2=.VMMAccountingStore~recoverEngine(storePath)
view2=.VMMAccountingReportingService~new(eng2)~view(b)
call assertEq 2,view2~lineCount,"post-restart funding report"
call assertEq "TREASURY_FUNDING",view2~lines[1]~dimensions["vmm.businessLine"],"business-line dimension survives store recovery"
call assertEq "FUNDING",view2~lines[1]~dimensions["vmm.accountingFunction"],"accounting-function dimension survives store recovery"
t1=view1~totals; t2=view2~totals
call assertEq t1["GBP"]["debit_minor"],t2["GBP"]["debit_minor"],"debits byte-equivalent through restart"
call assertEq t1["GBP"]["credit_minor"],t2["GBP"]["credit_minor"],"credits byte-equivalent through restart"
call assertEq "vmm.accounting.reporting/0.11",.VMMAccountingReportingBuild~protocol,"reporting protocol"
say "PASS test_accounting_v07_reporting_restart"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccountingReporting.cls"
