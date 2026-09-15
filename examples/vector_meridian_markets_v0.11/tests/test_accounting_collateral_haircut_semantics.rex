v=.VectorMeridianMarkets~new
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
vm=.VMMSyntheticCollateralTransfer~new("VM-1","CON-X","CALL-X","GBP",1000000,"VMM_TO_COUNTERPARTY","CUSTODIAN-X","CONTROL-VM","20260828T130000","VMM-COLLATERAL")
rv=acct~postVariationMarginTransfer(vm,"2026-08-28","2026-08")
call assertTrue rv~ok,"variation margin posted"
call assertEq 100000000,acct~book~balance("1400","GBP")~netDebitMinor,"VM collateral asset"
call assertEq -100000000,acct~book~balance("1000","GBP")~netDebitMinor,"VM cash delivered"
im=.VMMSyntheticInitialMarginTransfer~new("IM-1","CON-X","GBP","GILT-1","SOVEREIGN_BOND",2000000,500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","CUSTODIAN-X","CONTROL-IM","20260828T140000","VMM-COLLATERAL")
ri=acct~postInitialMarginTransfer(im,"2026-08-28","2026-08")
call assertTrue ri~ok,"initial margin reclassification posted"
call assertEq 300000000,acct~book~balance("1400","GBP")~netDebitMinor,"gross collateral carrying value posted"
call assertEq -200000000,acct~book~balance("1300","GBP")~netDebitMinor,"trading asset reclassified"
entry=ri~entry
call assertEq 190000000,entry~lines[1]~dimensions["recognizedRiskValueMinor"],"haircut retained as risk-recognized value only"
call assertEq 200000000,entry~lines[1]~debitMinor,"haircut does not write down accounting carrying value"
say "PASS test_accounting_collateral_haircut_semantics"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccounting.cls"
