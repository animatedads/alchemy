t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(300,"CLIENT-GATE","GATE")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
proj=.FederationBankMerchantAccountingProjectionV1~new
ins=.MBSettlementInstructionEvidence~new("INS-ACC-GATE",o~obligationId,o~debtor,o~creditor,"GBP",300,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
obs=.MBSettlementObservationEvidence~new("OBS-ACC-GATE",o~obligationId,ins~instructionId,"EXT-GATE-1",o~debtor,o~creditor,"GBP",300,"COMPLETE","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-A")
mb~recordSettlementObservation(obs)
e=proj~projectSettlementObservation(mb,obs,scale,"2026-08-28","2026-08")
a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
r=a~postSettlementObservation(e)
t~assertEq("REJECTED",r~status,"cash settlement cannot precede accounting recognition of contractual obligation")
t~assertEq("SETTLEMENT_OBLIGATION_NOT_ACCOUNTED",r~errorCode,"explicit sequence gate")
t~assertEq(0,a~book~entryCount,"no orphan cash journal")

-- Once the real obligation is accounted, a forged scalar event still cannot over-clear it.
a~postSettlementObligation(proj~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08"))
forged=.MBAccountingSettlementObservationEvidence~new("FORGED","FEDERATIONBANK_MERCHANT_BANK","MB:ACCOUNTING:SETTLEMENT_OBSERVATION:FORGED","2026-08-28","2026-08","FORGED",o~obligationId,ins~instructionId,"EXT-FORGED",o~debtor,o~creditor,"CLIENT-GATE","GBP",40000,"RECEIVABLE","COMPLETE","FORGED-AUTH")
fr=a~postSettlementObservation(forged)
t~assertEq("REJECTED",fr~status,"scalar boundary independently rejects over-clear")
t~assertEq("SETTLEMENT_ACCOUNTING_BINDING_MISMATCH",fr~errorCode,"over-clear is caught against recognised obligation")
t~assertEq(0,a~book~balance("1105","GBP")~netDebitMinor,"forged over-clear creates no cash")

say "settlement obligation gate assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"
