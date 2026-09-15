/* Illustrative staff-channel routing policy.  It decides orchestration shape,
 * not whether an employee or customer is actually authorised. */
::class FederationBankStaffChannelPolicyFixtures public
::method standardPolicy class
  p=.FederationBankStaffChannelPolicy~new
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-TRANSFER","CUSTOMER_INSTRUCTION","TRANSFER","NONE","PAYMENTS","customer instruction proceeds to staff authority then Payments")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-OPEN","CUSTOMER_INSTRUCTION","OPEN_ACCOUNT","NONE","ACCOUNT","customer application proceeds to staff authority then Account Authority")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-BEN-ADD","CUSTOMER_INSTRUCTION","ADD_BENEFICIARY","NONE","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-BEN-AMEND","CUSTOMER_INSTRUCTION","AMEND_BENEFICIARY","NONE","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("DIRECT-BEN-SUSPEND","CUSTOMER_INSTRUCTION","SUSPEND_BENEFICIARY","NONE","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("CASE-TRANSFER","RELATIONSHIP_DECISION","TRANSFER","REQUIRED","PAYMENTS","case-derived banking action requires prior Relationship Adapter authority")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("CASE-OPEN","RELATIONSHIP_DECISION","OPEN_ACCOUNT","REQUIRED","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("CASE-BEN-ADD","RELATIONSHIP_DECISION","ADD_BENEFICIARY","REQUIRED","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("CASE-BEN-AMEND","RELATIONSHIP_DECISION","AMEND_BENEFICIARY","REQUIRED","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("CASE-BEN-SUSPEND","RELATIONSHIP_DECISION","SUSPEND_BENEFICIARY","REQUIRED","ACCOUNT")~seal)
  p~addRule(.FederationBankStaffChannelRule~new("CASE-NO-ACTION","RELATIONSHIP_DECISION","NONE","REQUIRED","NONE","durably coordinate a specialist decision that intentionally causes no Core action")~seal)
  return p~seal
::method publishedCatalog class
  p=self~standardPolicy
  c=.InstitutionalPolicyCatalog~new
  from=.DateTime~fromIsoDate("2025-01-01T00:00:00.000000")
  release=.InstitutionalPolicyRelease~new(.FederationBankStaffChannelBuild~DEFAULT_POLICY_ID,"1",from,.nil,"FederationBank Staff Channel Routing","Institutional Operations","",p)~seal
  r=c~publish(release); if \r~ok then raise syntax 88.969 array("Could not publish Staff Channel policy",r~code,r~detail)
  return c
::requires "FederationBankStaffChannel.cls"
