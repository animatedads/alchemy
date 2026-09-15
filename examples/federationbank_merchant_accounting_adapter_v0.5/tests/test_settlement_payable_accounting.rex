t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(-750,"CLIENT-PAY","PAY")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
proj=.FederationBankMerchantAccountingProjectionV1~new
p=proj~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08")
t~assertEq("PAYABLE",p~settlementSide,"negative Merchant settlement is payable")
t~assertEq("FEDERATIONBANK_MERCHANT_BANK",o~debtor,"Merchant is contractual debtor")

a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
r=a~postSettlementObligation(p)
t~assertEq("POSTED",r~status,"payable obligation posts")
t~assertEq(75000,a~book~balance("1395","GBP")~netDebitMinor,"payable uses explicit pending derecognition control asset")
t~assertEq(-75000,a~book~balance("2315","GBP")~netDebitMinor,"settlement payable recognised")
ins=.MBSettlementInstructionEvidence~new("INS-ACC-PAY",o~obligationId,o~debtor,o~creditor,"GBP",750,"SETTLEMENT-AGENT-B","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
obs=.MBSettlementObservationEvidence~new("OBS-ACC-PAY",o~obligationId,ins~instructionId,"EXT-PAY-1",o~debtor,o~creditor,"GBP",750,"COMPLETE","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-B")
mb~recordSettlementObservation(obs)
sr=a~postSettlementObservation(proj~projectSettlementObservation(mb,obs,scale,"2026-08-28","2026-08"))
t~assertEq("POSTED",sr~status,"observed outgoing settlement posts")
t~assertEq(0,a~book~balance("2315","GBP")~netDebitMinor,"payable clears on observed completion")
t~assertEq(-75000,a~book~balance("1105","GBP")~netDebitMinor,"cash-at-settlement-agent reflects externally observed outflow")

say "settlement payable assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"
