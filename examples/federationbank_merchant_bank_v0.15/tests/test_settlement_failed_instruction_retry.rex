mb=.FederationBankMerchantBank~new
ob=mb~createSettlementObligation("OBL-SF-1","FEDERATIONBANK_MERCHANT_BANK","CLIENT-SF","GBP",90000,"DERIVATIVE_CLOSE_OUT","EXEC-SF-1")
ins1=.MBSettlementInstructionEvidence~new("INS-SF-1","OBL-SF-1","FEDERATIONBANK_MERCHANT_BANK","CLIENT-SF","GBP",90000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins1)
failed=.MBSettlementObservationEvidence~new("SETTLE-SF-FAIL","OBL-SF-1","INS-SF-1","EXT-SF-FAIL","FEDERATIONBANK_MERCHANT_BANK","CLIENT-SF","GBP",0,"FAILED","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-A",.array~of("AGENT-FAILURE:001"))
a1=mb~recordSettlementObservation(failed)
call assertEq "UNSETTLED",ob~status,"failed instruction does not extinguish obligation"
call assertEq 90000,ob~remainingAmount,"failed instruction leaves entire obligation outstanding"
call assertEq "UNSETTLED",a1~status,"failure checkpoint records outstanding state"
ins2=.MBSettlementInstructionEvidence~new("INS-SF-2","OBL-SF-1","FEDERATIONBANK_MERCHANT_BANK","CLIENT-SF","GBP",90000,"SETTLEMENT-AGENT-B","MB-SETTLEMENT-AUTH-2","2026-08-28T16:02:00Z")
mb~recordSettlementInstruction(ins2)
complete=.MBSettlementObservationEvidence~new("SETTLE-SF-COMPLETE","OBL-SF-1","INS-SF-2","EXT-SF-OK","FEDERATIONBANK_MERCHANT_BANK","CLIENT-SF","GBP",90000,"COMPLETE","2026-08-28T16:03:00Z","SETTLEMENT-AGENT-B",.array~of("AGENT-RECEIPT:009"))
mb~recordSettlementObservation(complete)
call assertEq "SETTLED",ob~status,"independent retry can settle the still-live obligation"
call assertEq 2,mb~settlementInstructionsForObligation("OBL-SF-1")~items,"failed and replacement instructions are both retained"
call assertEq 2,mb~settlementObservationsForObligation("OBL-SF-1")~items,"failure and completion evidence both retained"
say "PASS test_settlement_failed_instruction_retry"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
