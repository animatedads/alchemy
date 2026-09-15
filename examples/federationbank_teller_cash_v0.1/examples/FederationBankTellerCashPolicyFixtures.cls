/* Illustrative cash-specific Staff Channel + Staff Authority policy.  These
 * values are test fixtures, not statements of real FederationBank limits. */
::class FederationBankTellerCashPolicyFixtures public
::method channelCatalog class
  p=.FederationBankStaffChannelPolicy~new
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-CASH-WITHDRAW","CUSTOMER_INSTRUCTION","CASH_WITHDRAWAL","NONE","PAYMENTS","counter cash is specialised execution behind the Payments family boundary")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-CASH-DEPOSIT","CUSTOMER_INSTRUCTION","CASH_DEPOSIT","NONE","PAYMENTS","counter cash is specialised execution behind the Payments family boundary")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-TRANSFER","CUSTOMER_INSTRUCTION","TRANSFER","NONE","PAYMENTS")~seal)
  p~seal
  c=.InstitutionalPolicyCatalog~new
  from=.DateTime~fromIsoDate("2025-01-01T00:00:00.000000")
  release=.InstitutionalPolicyRelease~new(.FederationBankStaffChannelBuild~DEFAULT_POLICY_ID,"CASH-1",from,.nil,"FederationBank Staff Channel Cash Routing","Institutional Operations","",p)~seal
  r=c~publish(release); if \r~ok then raise syntax 88.965 array("cash channel policy publication failed",r~code)
  return c
::method staffCatalog class
  p=.FederationBankStaffAuthorityPolicy~new
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-CASH-WITHDRAW","TELLER","CASH_WITHDRAWAL","*",500000,2500000,"SUPERVISOR",1,.true,.true,"","illustrative teller cash withdrawal authority")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-CASH-DEPOSIT","TELLER","CASH_DEPOSIT","*",1000000,5000000,"SUPERVISOR",1,.true,.true,"","illustrative teller cash deposit authority")~seal)
  p~addRule(.FederationBankStaffAuthorityRule~new("TELLER-TRANSFER","TELLER","TRANSFER","*",500000,2500000,"SUPERVISOR",1,.true,.true,"","")~seal)
  p~seal
  c=.InstitutionalPolicyCatalog~new
  from=.DateTime~fromIsoDate("2025-01-01T00:00:00.000000")
  release=.InstitutionalPolicyRelease~new(.FederationBankStaffAuthorityBuild~DEFAULT_POLICY_ID,"CASH-1",from,.nil,"FederationBank Teller Cash Workforce Authority","Institutional Operations","",p)~seal
  r=c~publish(release); if \r~ok then raise syntax 88.966 array("cash staff policy publication failed",r~code)
  return c
::requires "FederationBankTellerCash.cls"
