::class DemoConsumer public

::method init
  expose rules context
  rules = .nil
  context = .nil

::method runtimePrepare
  expose rules context
  use arg context
  rules = context~dependency("demo.rules")
  if rules == .nil then return .false
  return .true

::method runtimeSelfTest
  expose rules
  if rules == .nil then return .false
  return .true

::method runtimeStart
  return .true

::method runtimeQuiesce
  return .true

::method runtimeStop
  expose rules context
  rules = .nil
  context = .nil
  return .true

::method ruleVersion
  expose rules
  if rules == .nil then return "NONE"
  return rules~version

::method disposition
  expose rules
  use arg action
  if rules == .nil then return "NO_RULES"
  return rules~disposition(action)

::method attemptDependencyRelease
  expose context
  if context == .nil then return .nil
  return context~releaseDependencies
