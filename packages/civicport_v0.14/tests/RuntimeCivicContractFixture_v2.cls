/* Second metadata-only generation for Runtime Registry pin rollover tests. */
::class RuntimeCivicContractFixture public
::method runtimePrepare
  use arg context
  return .true
::method runtimeSelfTest
  return .true
::method runtimeStart
  return .true
::method runtimeQuiesce
  return .true
::method runtimeStop
  return .true
::method version
  return "CIVIC-CONTRACT-FIXTURE-2"
::method runtimeInvokeAbility
  use arg abilityId, context
  return context~failure("CIVIC_FIXTURE_NOT_A_NETWORK_HANDLER", abilityId)
