::class FederationBankStaffChannelServiceRuntimeModule public
::method componentId class
  return "federationbank.staff.channel.service"
::method componentVersion class
  return .FederationBankStaffChannelServiceBuild~VERSION
::method apiVersion class
  return .FederationBankStaffChannelServiceBuild~API_VERSION
::method capabilities class
  return .array~of("DURABLE_STAFF_WORK","WRITE_AHEAD_CORE_SUBMISSION","MAKER_CHECKER_RESUME","IDEMPOTENT_RECOVERY","AT_LEAST_ONCE_EVENT_OUTBOX","QUEUE_FABRIC_COMMANDS")
::requires "FederationBankStaffChannelService.cls"
