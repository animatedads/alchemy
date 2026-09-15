::class FederationBankStaffChannelRuntimeModule public
::method componentId class
  return "federationbank.staff.channel"
::method componentVersion class
  return .FederationBankStaffChannelBuild~VERSION
::method apiVersion class
  return .FederationBankStaffChannelBuild~API_VERSION
::method capabilities class
  return .array~of("STAFF_CHANNEL_ORCHESTRATION","RELATIONSHIP_AUTHORITY_BINDING","STAFF_AUTHORITY_BINDING","MAKER_CHECKER_RESUME","CORE_ROUTE_SEPARATION","NO_BANK_ACTION_OUTCOME")
::requires "FederationBankStaffChannel.cls"
