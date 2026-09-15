::class FederationBankTellerCashRuntimeModule public
::method componentId class
  return "federationbank.teller.cash"
::method componentVersion class
  return .FederationBankTellerCashBuild~VERSION
::method apiVersion class
  return .FederationBankTellerCashBuild~API_VERSION
::method capabilities class
  return .array~of("COUNTER_CASH_ORCHESTRATION","STAFF_AUTHORITY_BINDING","CORE_TRANSFER_TRANSLATION","PHYSICAL_TILL_BINDING","COMPENSATION_OUTCOME","RECONCILIATION_OUTCOME","NO_ATM_SEMANTICS")
::requires "FederationBankTellerCash.cls"
