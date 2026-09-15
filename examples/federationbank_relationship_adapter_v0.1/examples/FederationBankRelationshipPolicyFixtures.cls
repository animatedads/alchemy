/* Illustrative integration policy only.  It governs which institutional
 * relationship decisions may be submitted to Core Banking.  Core Banking's
 * own policies/legal/security checks remain independently authoritative. */
::class FederationBankRelationshipPolicyFixtures public
::method standardPolicy class
  p=.FederationBankRelationshipActionPolicy~new
  /* Durable no-action outcome for investigations such as external political pressure. */
  p~addRule(.FederationBankRelationshipActionRule~new("NO-ACTION-COMPLIANCE","COMPLIANCE_DECISION","NO_BANK_ACTION","NONE","*","STAFF",.true,.false,.true,"compliance may record an explicit no-bank-action outcome"))
  /* Customer/staff transactional decisions. */
  p~addRule(.FederationBankRelationshipActionRule~new("STAFF-TRANSFER","STAFF_TRANSACTION_AUTHORITY","CUSTOMER_INSTRUCTION_VALIDATED","TRANSFER","TELLER","STAFF",.true,.false,.true,"validated customer payment instruction may be submitted; Core Banking still decides"))
  p~addRule(.FederationBankRelationshipActionRule~new("STAFF-BEN-ADD","STAFF_TRANSACTION_AUTHORITY","BENEFICIARY_MAINTENANCE","ADD_BENEFICIARY","TELLER","STAFF",.true,.false,.true,"beneficiary request may be submitted"))
  p~addRule(.FederationBankRelationshipActionRule~new("STAFF-BEN-AMEND","STAFF_TRANSACTION_AUTHORITY","BENEFICIARY_MAINTENANCE","AMEND_BENEFICIARY","TELLER","STAFF",.true,.false,.true,"beneficiary request may be submitted"))
  p~addRule(.FederationBankRelationshipActionRule~new("STAFF-BEN-SUSPEND","STAFF_TRANSACTION_AUTHORITY","BENEFICIARY_MAINTENANCE","SUSPEND_BENEFICIARY","TELLER","STAFF",.true,.false,.true,"beneficiary request may be submitted"))
  p~addRule(.FederationBankRelationshipActionRule~new("ONBOARDING-OPEN","ACCOUNT_ONBOARDING_AUTHORITY","ACCOUNT_OPENING_APPROVED","OPEN_ACCOUNT","TELLER","STAFF",.true,.true,.true,"approved onboarding may be submitted to Account Authority"))
  /* Payment reservations are not generic account restrictions. */
  p~addRule(.FederationBankRelationshipActionRule~new("PAYMENT-RESERVE","PAYMENTS_AUTHORITY","PAYMENT_RESERVATION_APPROVED","PLACE_HOLD","*","STAFF",.true,.false,.true,"payments authority may request a monetary reservation"))
  p~addRule(.FederationBankRelationshipActionRule~new("PAYMENT-RELEASE","PAYMENTS_AUTHORITY","PAYMENT_RESERVATION_RELEASE","RELEASE_HOLD","*","STAFF",.true,.false,.true,"payments authority may release a monetary reservation"))
  /* Structural deny for common non-authorities, even if a future wildcard allow appears. */
  p~addRule(.FederationBankRelationshipActionRule~new("DENY-OBSERVATION","OBSERVATION_NOT_DECISION","*","*","*","STAFF",.false,.false,.false,"observations are evidence, never bank authority"))
  p~addRule(.FederationBankRelationshipActionRule~new("DENY-CRM","CRM_RECORD","*","*","*","STAFF",.false,.false,.false,"CRM records are not banking authority"))
  p~addRule(.FederationBankRelationshipActionRule~new("DENY-SERVICE-GUIDANCE","SERVICE_GUIDANCE","*","*","*","STAFF",.false,.false,.false,"service treatment never grants banking authority"))
  return p~seal
::method publishedCatalog class
  p=self~standardPolicy; c=.InstitutionalPolicyCatalog~new
  from=.DateTime~fromIsoDate("2025-01-01T00:00:00.000000")
  release=.InstitutionalPolicyRelease~new(.FederationBankRelationshipAdapterBuild~DEFAULT_POLICY_ID,"1",from,.nil,"FederationBank Relationship Integration","Institutional Operations","",p)~seal
  result=c~publish(release)
  if \result~ok then raise syntax 88.980 array("Could not publish FederationBank Relationship adapter policy: "||result~code||":"||result~detail)
  return c
::requires "FederationBankRelationshipAdapter.cls"
