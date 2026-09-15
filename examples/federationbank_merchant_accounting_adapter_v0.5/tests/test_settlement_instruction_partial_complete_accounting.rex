t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(1000,"CLIENT-PART","PART")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
proj=.FederationBankMerchantAccountingProjectionV1~new
a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
a~postSettlementObligation(proj~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08"))

ins=.MBSettlementInstructionEvidence~new("INS-ACC-PART",o~obligationId,o~debtor,o~creditor,"GBP",1000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
iobs=proj~projectSettlementInstructionObservation(mb,ins,scale)
ir=a~postSettlementInstructionObservation(iobs)
t~assertEq("REJECTED",ir~status,"instruction is non-posting evidence")
t~assertEq("SETTLEMENT_COMPLETION_EVIDENCE_REQUIRED",ir~errorCode,"instruction cannot fabricate cash")
t~assertEq(1,a~book~entryCount,"instruction creates no accounting journal")

p=.MBSettlementObservationEvidence~new("OBS-ACC-PART",o~obligationId,ins~instructionId,"EXT-PART-1",o~debtor,o~creditor,"GBP",400,"PARTIAL","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-A",.array~of("RECEIPT-PART-1"))
mb~recordSettlementObservation(p)
pr=a~postSettlementObservation(proj~projectSettlementObservation(mb,p,scale,"2026-08-28","2026-08"))
t~assertEq("POSTED",pr~status,"attributable partial settlement posts")
t~assertEq(40000,a~book~balance("1105","GBP")~netDebitMinor,"partial cash observed exactly")
t~assertEq(60000,a~book~balance("1315","GBP")~netDebitMinor,"only unsettled receivable remains")
dup=a~postSettlementObservation(proj~projectSettlementObservation(mb,p,scale,"2026-08-28","2026-08"))
t~assertEq("DUPLICATE",dup~status,"same settlement evidence replays through Accounting Core before cumulative guard")
t~assertEq(40000,a~book~balance("1105","GBP")~netDebitMinor,"duplicate replay cannot double cash")
t~assertEq(-100000,a~book~balance("2395","GBP")~netDebitMinor,"derivative close-out control is not silently cleared")

c=.MBSettlementObservationEvidence~new("OBS-ACC-COMP",o~obligationId,ins~instructionId,"EXT-PART-2",o~debtor,o~creditor,"GBP",600,"COMPLETE","2026-08-28T16:02:00Z","SETTLEMENT-AGENT-A",.array~of("RECEIPT-PART-2"))
mb~recordSettlementObservation(c)
cr=a~postSettlementObservation(proj~projectSettlementObservation(mb,c,scale,"2026-08-28","2026-08"))
t~assertEq("POSTED",cr~status,"completion settlement posts")
t~assertEq(100000,a~book~balance("1105","GBP")~netDebitMinor,"full externally observed cash accumulated")
t~assertEq(0,a~book~balance("1315","GBP")~netDebitMinor,"settlement receivable fully cleared")
t~assertEq("SETTLED",o~status,"Merchant obligation independently proves settlement")
t~assertEq(-100000,a~book~balance("2395","GBP")~netDebitMinor,"settlement does not pretend derivative carrying-value derecognition is proved")

say "settlement partial/complete assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"
