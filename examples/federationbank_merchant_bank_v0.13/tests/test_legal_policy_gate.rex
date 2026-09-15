mb=.FederationBankMerchantBank~new
badLegal=.MBDecisionEvidence~new("PROHIBITED","PERMITTED","LEGAL-PENSION-NO","POLICY-OK")
call expectAgreement badLegal,"legal prohibition blocks collateral agreement"
badPolicy=.MBDecisionEvidence~new("PERMITTED","PROHIBITED","LEGAL-OK","POLICY-NO")
call expectAgreement badPolicy,"policy prohibition blocks collateral agreement"
missing=.MBDecisionEvidence~new("PERMITTED","PERMITTED","","POLICY-OK")
call expectAgreement missing,"missing legal provenance blocks collateral agreement"
say "PASS test_legal_policy_gate"
exit 0
::routine expectAgreement
  use strict arg evidence,label
  caught=.false
  signal on syntax name gotSyntax
  a=.MBCollateralAgreement~new("CSA-X","PENSION-X","FEDERATIONBANK_MERCHANT_BANK","PENSION-X","PF-X",1000,"GBP",evidence)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
