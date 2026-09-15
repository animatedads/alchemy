::class FederationBankBranchDayRuntimeModule public
::method moduleId
  return "FEDERATIONBANK_BRANCH_DAY"
::method moduleVersion
  return .FederationBankBranchDayBuild~VERSION
::method apiVersion
  return .FederationBankBranchDayBuild~API_VERSION
::method capabilities
  return .array~of("BRANCH_OPEN_CERTIFICATION","END_OF_DAY_PHYSICAL_RECONCILIATION","CASH_CONTROL_TOTALS","DUAL_APPROVAL")
::requires "FederationBankBranchDay.cls"
