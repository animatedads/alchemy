::class FederationBankBranchTillAdapterRuntimeModule public
::method moduleId
  return "FEDERATIONBANK_BRANCH_TILL_ADAPTER"
::method moduleVersion
  return .FederationBankBranchTillAdapterBuild~VERSION
::method apiVersion
  return .FederationBankBranchTillAdapterBuild~API_VERSION
::method capabilities
  return .array~of("BRANCH_CASH_AUTHORITY_VALIDATION","TILL_INTERNAL_CASH_TRANSLATION","INDEPENDENT_TILL_CUSTODY")
::requires "FederationBankBranchTillAdapter.cls"
