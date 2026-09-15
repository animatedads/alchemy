mb=.FederationBankMerchantBank~new
ob=mb~createSettlementObligation("OBL-SP-1","CLIENT-SP","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"DERIVATIVE_CLOSE_OUT","EXEC-SP-1")
ins=.MBSettlementInstructionEvidence~new("INS-SP-1","OBL-SP-1","CLIENT-SP","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
p=.MBSettlementObservationEvidence~new("SETTLE-SP-P1","OBL-SP-1","INS-SP-1","EXT-SP-001","CLIENT-SP","FEDERATIONBANK_MERCHANT_BANK","GBP",40000,"PARTIAL","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-A",.array~of("AGENT-RECEIPT:001"))
a1=mb~recordSettlementObservation(p)
call assertEq "PARTIALLY_SETTLED",ob~status,"partial observation does not extinguish obligation"
call assertEq 40000,ob~settledAmount,"partial amount accumulates"
call assertEq 60000,ob~remainingAmount,"remaining obligation is exact"
call assertEq "PARTIALLY_SETTLED",a1~status,"partial checkpoint retained"
c=.MBSettlementObservationEvidence~new("SETTLE-SP-C1","OBL-SP-1","INS-SP-1","EXT-SP-002","CLIENT-SP","FEDERATIONBANK_MERCHANT_BANK","GBP",60000,"COMPLETE","2026-08-28T16:02:00Z","SETTLEMENT-AGENT-A",.array~of("AGENT-RECEIPT:002"))
a2=mb~recordSettlementObservation(c)
call assertEq "SETTLED",ob~status,"only exact cumulative external observation settles obligation"
call assertEq 100000,ob~settledAmount,"full contractual amount settled"
call assertEq 0,ob~remainingAmount,"nothing remains after exact completion"
call assertEq "SETTLED",a2~status,"final settlement checkpoint retained"
stream=mb~settlementObservationsForObligation("OBL-SP-1")
call assertEq 2,stream~items,"both external observations retained"
call assertEq "SETTLE-SP-P1",stream[1]~evidenceId,"historical partial evidence preserved"
call assertEq "SETTLE-SP-C1",stream[2]~evidenceId,"completion evidence preserved"
say "PASS test_settlement_partial_then_complete"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
