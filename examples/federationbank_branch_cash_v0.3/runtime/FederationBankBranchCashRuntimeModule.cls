::class FederationBankBranchCashRuntimeModule public
::method moduleId
  return "FEDERATIONBANK_BRANCH_CASH"
::method moduleVersion
  return .FederationBankBranchCashBuild~VERSION
::method apiVersion
  return .FederationBankBranchCashBuild~API_VERSION
::method capabilities
  a=.array~new; a~append("BRANCH_VAULT_CUSTODY"); a~append("INTERNAL_CASH_TRANSFER_AUTHORITY"); a~append("DUAL_CONTROL"); a~append("BRANCH_CASH_RECONCILIATION"); a~append("EXACT_ACTION_AUTHORITY_ENVELOPE"); a~append("EXTERNAL_CASH_VAULT_BOUNDARY"); return a
::requires "FederationBankBranchCash.cls"
