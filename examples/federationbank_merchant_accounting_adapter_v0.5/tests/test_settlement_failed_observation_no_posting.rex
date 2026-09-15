t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(500,"CLIENT-FAIL","FAIL")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
proj=.FederationBankMerchantAccountingProjectionV1~new
a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
a~postSettlementObligation(proj~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08"))
ins=.MBSettlementInstructionEvidence~new("INS-ACC-FAIL",o~obligationId,o~debtor,o~creditor,"GBP",500,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
fail=.MBSettlementObservationEvidence~new("OBS-ACC-FAIL",o~obligationId,ins~instructionId,"EXT-FAIL-1",o~debtor,o~creditor,"GBP",0,"FAILED","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-A",.array~of("FAILURE-RECEIPT"))
mb~recordSettlementObservation(fail)
e=proj~projectSettlementObservation(mb,fail,scale,"2026-08-28","2026-08")
r=a~postSettlementObservation(e)
t~assertEq("NO_POSTING_SETTLEMENT_FAILED",r~status,"failed external settlement has no cash posting")
t~assertEq(1,a~book~entryCount,"failed settlement adds no journal")
t~assertEq(50000,a~book~balance("1315","GBP")~netDebitMinor,"receivable remains outstanding")
t~assertEq(0,a~book~balance("1105","GBP")~netDebitMinor,"failed settlement creates no cash")
t~assertEq("UNSETTLED",o~status,"Merchant obligation remains live after failed instruction")

say "failed settlement accounting assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"
