::class FederationBankIntermediaryStaffAuthorityRuntimeModule public
::method componentId class
  return "federationbank.intermediary.staff.authority"
::method componentVersion class
  return .FederationBankIntermediaryStaffAuthorityBuild~VERSION
::method apiVersion class
  return .FederationBankIntermediaryStaffAuthorityBuild~API_VERSION
::method capabilities class
  return .array~of("INSTITUTIONAL_STAFF_SCOPE","EFFECTIVE_EMPLOYEE_RID_REP_BINDING","EXACT_PRODUCT_BINDING","EXACT_JURISDICTION_BINDING","EXACT_ACTIVITY_BINDING","EXACT_ADVICE_MODE_BINDING","EXACT_CASE_BINDING","RID_ACTIVE_PAIR_REQUIRED","NO_CORE_BANKING_AUTHORITY","NO_RID_PERMISSION_SUBSTITUTION")
::requires "FederationBankIntermediaryStaffAuthority.cls"
