::class FederationBankRelationshipAdapterServiceRuntimeModule public
::method componentId class
  return "federationbank.relationship.adapter.service"
::method componentVersion class
  return .FederationBankRelationshipAdapterServiceBuild~VERSION
::method apiVersion class
  return .FederationBankRelationshipAdapterServiceBuild~API_VERSION
::method capabilities class
  return .array~of("DURABLE_BANK_ACTION_SUBMISSION","BANK_RESULT_CORRELATION","QUEUE_FABRIC_INGRESS","OUTBOX_EVENTS","NO_LEDGER_INGRESS")
::requires "FederationBankRelationshipAdapterService.cls"
