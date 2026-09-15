::class FederationBankBranchDayServiceRuntimeModule public
::method moduleId
  return "FEDERATIONBANK_BRANCH_DAY_SERVICE"
::method moduleVersion
  return .FederationBankBranchDayServiceBuild~VERSION
::method apiVersion
  return .FederationBankBranchDayServiceBuild~API_VERSION
::method capabilities
  return .array~of("DURABLE_BRANCH_DAY","END_OF_DAY_WORKFLOW","QUEUE_FABRIC_COMMANDS","DURABLE_EVENT_OUTBOX")
::requires "FederationBankBranchDayService.cls"
