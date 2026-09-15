numeric digits 50
v=.VectorMeridianMarkets~new
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
vm=.VMMSyntheticCollateralTransfer~new("VM-RPT-FN","CON-RPT-FN","CALL-RPT-FN","GBP",1000000,"VMM_TO_COUNTERPARTY","CUSTODIAN-RPT","CONTROL-VM-RPT","20260828T130000","VMM-COLLATERAL")
call assertTrue acct~postVariationMarginTransfer(vm,"2026-08-28","2026-08")~ok,"variation margin posts"
xva=.VMMSyntheticXVAReport~new("XVA-RPT-FN","CON-RPT-FN","VAL-RPT-FN","GBP",5000,3000,"20260828T140000","CREDIT-EVID-RPT","FUNDING-CURVE-RPT","XVA-MODEL-RPT","VMM-XVA")
call assertTrue acct~postXVA(xva,"2026-08-28","2026-08")~ok,"XVA posts"
rpt=.VMMAccountingReportingService~new(eng)
ev=.array~of("REPORT-FUNCTION-EVID")
coll=.VMMAccountingReportingBoundaryFactory~collateralCustody("RPT-COLL","VMM-FINANCE-CONTROL","2026-01-01",ev)
xvab=.VMMAccountingReportingBoundaryFactory~xva("RPT-XVA","VMM-FINANCE-CONTROL","2026-01-01",ev)
collView=rpt~view(coll)
xvaView=rpt~view(xvab)
call assertEq 2,collView~lineCount,"collateral function view has only collateral journal"
call assertEq 2,xvaView~lineCount,"XVA function view has only XVA journal"
call assertEq "COLLATERAL_CUSTODY",collView~lines[1]~dimensions["vmm.accountingFunction"],"collateral function dimension"
call assertEq "XVA",xvaView~lines[1]~dimensions["vmm.accountingFunction"],"XVA function dimension"
say "PASS test_accounting_v07_reporting_functions"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccountingReporting.cls"
