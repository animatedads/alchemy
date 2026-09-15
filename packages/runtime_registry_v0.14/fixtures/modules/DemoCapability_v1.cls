::class DemoCapability public
::attribute context get
::attribute starts get
::attribute quiesces get
::attribute stops get

::method init
  expose context starts quiesces stops
  context = .nil
  starts = 0
  quiesces = 0
  stops = 0

::method runtimePrepare
  expose context
  use arg context
  return .true

::method runtimeSelfTest
  return .true

::method runtimeStart
  expose starts
  starts = starts + 1
  return .true

::method runtimeQuiesce
  expose quiesces
  quiesces = quiesces + 1
  return .true

::method runtimeStop
  expose stops
  stops = stops + 1
  return .true

::method version
  return "ONE"

::method answer
  use arg text = ""
  return "ONE:" || text
