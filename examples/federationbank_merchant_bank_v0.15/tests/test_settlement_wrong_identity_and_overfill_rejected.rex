mb=.FederationBankMerchantBank~new
ob=mb~createSettlementObligation("OBL-SW-1","CLIENT-SW","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"DERIVATIVE_CLOSE_OUT","EXEC-SW-1")
wrong=.MBSettlementInstructionEvidence~new("INS-SW-WRONG","OBL-SW-1","FEDERATIONBANK_MERCHANT_BANK","CLIENT-SW","GBP",100000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
call expectSyntax "wrong-way debtor/creditor instruction rejected",mb,"recordSettlementInstruction",wrong
call assertEq "UNSETTLED",ob~status,"rejected instruction cannot mutate obligation"
ins=.MBSettlementInstructionEvidence~new("INS-SW-1","OBL-SW-1","CLIENT-SW","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:01:00Z")
mb~recordSettlementInstruction(ins)
over=.MBSettlementObservationEvidence~new("SETTLE-SW-OVER","OBL-SW-1","INS-SW-1","EXT-SW-OVER","CLIENT-SW","FEDERATIONBANK_MERCHANT_BANK","GBP",120000,"COMPLETE","2026-08-28T16:02:00Z","SETTLEMENT-AGENT-A")
call expectSyntax "over-settlement rejected",mb,"recordSettlementObservation",over
call assertEq 0,ob~settledAmount,"over-settlement cannot mutate obligation"
wrongBind=.MBSettlementObservationEvidence~new("SETTLE-SW-BIND","OBL-SW-1","INS-NOT-OURS","EXT-SW-BIND","CLIENT-SW","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"COMPLETE","2026-08-28T16:03:00Z","SETTLEMENT-AGENT-A")
call expectSyntax "unbound external observation rejected",mb,"recordSettlementObservation",wrongBind
call assertEq "INSTRUCTED",ob~status,"valid instruction remains live after rejected observations"
say "PASS test_settlement_wrong_identity_and_overfill_rejected"
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
