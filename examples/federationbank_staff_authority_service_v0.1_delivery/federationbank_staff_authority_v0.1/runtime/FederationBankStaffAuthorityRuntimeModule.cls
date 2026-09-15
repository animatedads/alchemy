::class FederationBankStaffAuthorityRuntimeModule public
::method componentId class
  return "federationbank.staff.authority"
::method componentVersion class
  return .FederationBankStaffAuthorityBuild~VERSION
::method apiVersion class
  return .FederationBankStaffAuthorityBuild~API_VERSION
::method capabilities class
  return .array~of("STAFF_ROLE_AUTHORITY","MAKER_CHECKER","BOUNDED_DELEGATION","TEMPORARY_ELEVATION","EXACT_BANK_COMMAND_BINDING","INSTITUTIONAL_POLICY_PROVENANCE")
::requires "FederationBankStaffAuthority.cls"
