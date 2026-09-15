::class FederationBankRelationshipAdapterRuntimeModule public
::method componentId class
  return "federationbank.relationship.adapter"
::method componentVersion class
  return .FederationBankRelationshipAdapterBuild~VERSION
::method apiVersion class
  return .FederationBankRelationshipAdapterBuild~API_VERSION
::method capabilities class
  return .array~of("RELATIONSHIP_DECISION_TO_BANK_COMMAND","CASE_DECISION_REFERENCE_VERIFICATION","POLICY_DRIVEN_AUTHORITY_MAPPING","NO_BANK_ACTION_OUTCOME")
::requires "FederationBankRelationshipAdapter.cls"
