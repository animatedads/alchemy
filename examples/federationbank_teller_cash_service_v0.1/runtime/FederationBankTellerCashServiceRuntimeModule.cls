::class FederationBankTellerCashServiceRuntimeModule public
::method componentId class
  return "federationbank.teller.cash.service"
::method componentVersion class
  return .FederationBankTellerCashServiceBuild~VERSION
::method apiVersion class
  return .FederationBankTellerCashServiceBuild~API_VERSION
::method capabilities class
  return .array~of("DURABLE_COUNTER_CASH_WORK","STAFF_CHANNEL_COMPOSITION","TELLER_TILL_COMPOSITION","CORE_RETRY_BOUNDARY","COMPENSATION_WORK","RECONCILIATION_WORK","AT_LEAST_ONCE_EVENT_OUTBOX","QUEUE_FABRIC_COMMANDS")
::requires "FederationBankTellerCashService.cls"
