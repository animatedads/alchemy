mb=.FederationBankMerchantBank~new
ob=mb~createSettlementObligation("OBL-SI-1","CLIENT-SI","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"DERIVATIVE_CLOSE_OUT","EXEC-SI-1")
ins=.MBSettlementInstructionEvidence~new("INS-SI-1","OBL-SI-1","CLIENT-SI","FEDERATIONBANK_MERCHANT_BANK","GBP",100000,"SETTLEMENT-AGENT-A","MB-SETTLEMENT-AUTH","2026-08-28T16:00:00Z")
mb~recordSettlementInstruction(ins)
call assertEq "INSTRUCTED",ob~status,"instruction changes only operational settlement state"
call assertEq 0,ob~settledAmount,"instruction does not fabricate settled money"
call assertEq 100000,ob~remainingAmount,"full obligation remains outstanding"
call assertEq "INS-SI-1",ob~currentInstructionRef,"current instruction is attributable"
a=mb~settlementStatusAssessment("OBL-SI-1")
call assertEq "INSTRUCTED",a~status,"immutable assessment records instruction state"
call assertEq "INSTRUCTION:INS-SI-1",a~evidenceRef,"assessment binds exact instruction"
call expectNoCoreMutation mb,"Merchant settlement observation has no Core cash mutation API"
say "PASS test_settlement_instruction_not_completion"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine expectNoCoreMutation
  use strict arg target,label
  caught=.false
  signal on syntax name noMethod
  target~postCoreCashMovement("ANY")
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_NO_METHOD",label)
  return
noMethod:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
