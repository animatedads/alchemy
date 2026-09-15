::class DemoRules public
::attribute context get

::method init
  expose context
  context = .nil

::method runtimePrepare
  expose context
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
  return "RULES-TWO"

::method disposition
  use arg action
  if action~upper = "SELL_BAG" then return "REQUIRES_APPROVAL"
  return "PERMITTED"
