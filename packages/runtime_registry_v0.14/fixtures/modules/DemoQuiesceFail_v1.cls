::class DemoQuiesceFail public

::method runtimePrepare
  return .true

::method runtimeSelfTest
  return .true

::method runtimeStart
  return .true

::method runtimeQuiesce
  return .false

::method runtimeStop
  return .true

::method version
  return "QUIESCE-FAIL-ONE"
