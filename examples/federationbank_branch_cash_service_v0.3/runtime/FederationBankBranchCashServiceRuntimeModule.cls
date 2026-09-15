::class FederationBankBranchCashServiceRuntimeModule public
::method moduleId
  return "FEDERATIONBANK_BRANCH_CASH_SERVICE"
::method moduleVersion
  return .FederationBankBranchCashServiceBuild~VERSION
::method apiVersion
  return .FederationBankBranchCashServiceBuild~API_VERSION
::method capabilities
  a=.array~new; a~append("DURABLE_INTERNAL_CASH_TRANSFER"); a~append("IN_TRANSIT_CUSTODY"); a~append("RECONCILIATION_WORK"); a~append("QUEUE_FABRIC_COMMANDS"); return a
::requires "FederationBankBranchCashService.cls"
