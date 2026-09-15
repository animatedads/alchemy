::class FederationBankStaffAuthorityServiceRuntimeModule public
::method componentId class
  return "federationbank.staff.authority.service"
::method componentVersion class
  return .FederationBankStaffAuthorityServiceBuild~VERSION
::method apiVersion class
  return .FederationBankStaffAuthorityServiceBuild~API_VERSION
::method capabilities class
  return .array~of("DURABLE_STAFF_CONTEXT_CACHE","MAKER_CHECKER_APPROVALS","ACTION_AUTHORITY_ISSUANCE","QUEUE_FABRIC_INGRESS","OUTBOX_EVENTS","NO_LEDGER_INGRESS","AUTHORITY_SCOPE_PERSISTENCE","LEGACY_STATE_MIGRATION")
::requires "FederationBankStaffAuthorityService.cls"
