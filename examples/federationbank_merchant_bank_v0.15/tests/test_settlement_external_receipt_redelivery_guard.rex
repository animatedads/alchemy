mb=.FederationBankMerchantBank~new
ob=mb~createSettlementObligation("OBL-SR-1","CLIENT-SR","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"DERIVATIVE_CLOSE_OUT","EXEC-SR-1")
ins=.MBSettlementInstructionEvidence~new("INS-SR-1","OBL-SR-1","CLIENT-SR","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
first=.MBSettlementObservationEvidence~new("SETTLE-SR-1","OBL-SR-1","INS-SR-1","AGENT-RECEIPT-77","CLIENT-SR","FEDERATIONBANK_MERCHANT_BANK","GBP",20000,"PARTIAL","2026-08-28T16:01:00Z","SETTLEMENT-AGENT-A")
mb~recordSettlementObservation(first)
call assertEq 20000,ob~settledAmount,"first receipt is applied once"
redelivery=.MBSettlementObservationEvidence~new("SETTLE-SR-2","OBL-SR-1","INS-SR-1","AGENT-RECEIPT-77","CLIENT-SR","FEDERATIONBANK_MERCHANT_BANK","GBP",20000,"PARTIAL","2026-08-28T16:02:00Z","SETTLEMENT-AGENT-A")
call expectSyntax "same external receipt under new local id rejected",mb,"recordSettlementObservation",redelivery
call assertEq 20000,ob~settledAmount,"external receipt redelivery cannot double settle"
call assertEq 1,mb~settlementObservationsForObligation("OBL-SR-1")~items,"only first attributable receipt retained"
say "PASS test_settlement_external_receipt_redelivery_guard"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectSyntax
  use strict arg label,target,method,arg1
  caught=.false
  signal on syntax name gotSyntax
  target~sendWith(method,.array~of(arg1))
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
