/* Qualification-only API-compatible subset for the external Logging v0.7
   seam.  It is not production code and is never installed by this package. */
::class Log public
::constant INFO "INFO"
::constant INTERNAL "INTERNAL"
::constant BODY "BODY"
::method normalizeScope class
  use strict arg scope
  return scope

::class LogEvent public
::method init
  expose level payload point component
  use strict arg level, payload, point, component = ""
::attribute level get
::attribute payload get
::attribute point get
::attribute component get

::class LogMemoryTarget public
::method init
  expose name scope events
  use strict arg name, scope
  events = .array~new
::method accept
  expose events
  use strict arg event
  events~append(event)
  return event
::method count
  expose events
  return events~items
::attribute events get

::class LogService public
::method init
  expose name targets
  use strict arg name
  targets = .array~new
::method addTarget
  expose targets
  use strict arg target
  targets~append(target)
  return target
::method loggerFor
  expose targets
  use strict arg owner, methodName, args, scope
  return .StubLogger~new(targets)

::class StubLogger
::method init
  expose targets
  use strict arg targets
::method log
  expose targets
  use strict arg level, payload, point
  event = .LogEvent~new(level, payload, point, payload["component"])
  do target over targets
    accepted = target~accept(event)
  end
  return event
