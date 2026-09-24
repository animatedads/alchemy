/* Rexx-tronics simulation time v0.1-dev15
 * Authoritative time is integer picoseconds. Wall-clock time is never used
 * to evolve circuit state.
 */

::class RexxTronicsBuild public
::constant RELEASE "0.1-dev15"
::constant API_VERSION "rexxtronics/0.1"

::class SimTime public
::constant PS_PER_NS 1000
::constant PS_PER_US 1000000
::constant PS_PER_MS 1000000000
::constant PS_PER_S  1000000000000

::method fromPicoseconds class
  use strict arg value
  return .SimInstant~new(.RexxTronicsUnits~timePicoseconds(value, .Units~picosecond))

::method fromNanoseconds class
  use strict arg value
  return .SimInstant~new(.RexxTronicsUnits~timePicoseconds(value, .Units~nanosecond))

::method fromMicroseconds class
  use strict arg value
  return .SimInstant~new(.RexxTronicsUnits~timePicoseconds(value, .Units~microsecond))

::method fromMilliseconds class
  use strict arg value
  return .SimInstant~new(.RexxTronicsUnits~timePicoseconds(value, .Units~millisecond))

::method fromSeconds class
  use strict arg value
  return .SimInstant~new(.RexxTronicsUnits~timePicoseconds(value, .Units~second))

::method fromQuantity class
  use strict arg value
  return .SimInstant~new(.RexxTronicsUnits~timePicoseconds(value, .Units~second))

::class SimInstant public
::attribute picoseconds get

::method init
  expose picoseconds
  numeric digits 50
  use strict arg value
  picoseconds = .RexxTronicsUnits~timePicoseconds(value)

::method seconds
  expose picoseconds
  numeric digits 50
  return picoseconds / .SimTime~PS_PER_S

::method quantity
  expose picoseconds
  numeric digits 50
  return .Units~q(picoseconds / .SimTime~PS_PER_S, .Units~second)

::method milliseconds
  expose picoseconds
  numeric digits 50
  return picoseconds / .SimTime~PS_PER_MS

::method microseconds
  expose picoseconds
  numeric digits 50
  return picoseconds / .SimTime~PS_PER_US

::method plus
  expose picoseconds
  numeric digits 50
  use strict arg other
  delta = .RexxTronicsUnits~timePicoseconds(other)
  return .SimInstant~new(picoseconds + delta)

::method string
  expose picoseconds
  numeric digits 50
  return picoseconds || ' ps'

::class SimScheduledEvent public
::attribute sequence get
::attribute atPs get
::attribute target get
::attribute messageName get
::attribute arguments get
::attribute cause get

::method init
  expose sequence atPs target messageName arguments cause
  numeric digits 50
  use strict arg sequenceArg, atPsArg, targetArg, messageNameArg, argumentsArg=.nil, causeArg=.nil
  sequence = sequenceArg + 0
  atPs = atPsArg + 0
  target = targetArg
  messageName = messageNameArg~string~upper
  if argumentsArg == .nil then arguments = .array~new
  else arguments = argumentsArg
  cause = causeArg

::class SimulationClock public
::attribute nowPs get
::attribute processedEvents get

::method init
  expose nowPs queue nextSequence processedEvents
  numeric digits 50
  nowPs = 0
  queue = .array~new
  nextSequence = 1
  processedEvents = 0

::method now
  expose nowPs
  numeric digits 50
  return .SimInstant~new(nowPs)

::method scheduleAt
  expose nowPs queue nextSequence
  numeric digits 50
  use strict arg when, target, messageName, arguments=.nil, cause=.nil
  atPs = .RexxTronicsUnits~timePicoseconds(when)
  if atPs < nowPs then raise syntax 93.900 array('cannot schedule an event in simulation-time past')
  ev = .SimScheduledEvent~new(nextSequence, atPs, target, messageName, arguments, cause)
  nextSequence += 1
  queue~append(ev)
  return ev

::method scheduleAfter
  expose nowPs
  numeric digits 50
  use strict arg delta, target, messageName, arguments=.nil, cause=.nil
  deltaPs = .RexxTronicsUnits~timePicoseconds(delta)
  return self~scheduleAt(nowPs + deltaPs, target, messageName, arguments, cause)

::method pendingCount
  expose queue
  numeric digits 50
  return queue~items

::method runFor
  expose nowPs
  numeric digits 50
  use strict arg duration
  deltaPs = .RexxTronicsUnits~timePicoseconds(duration)
  return self~runUntil(nowPs + deltaPs)

::method runUntil
  expose nowPs queue processedEvents
  numeric digits 50
  use strict arg until
  untilPs = .RexxTronicsUnits~timePicoseconds(until)
  if untilPs < nowPs then raise syntax 93.900 array('cannot run simulation backwards')

  do forever
    selectedIndex = 0
    selected = .nil
    do i = 1 to queue~items
      ev = queue[i]
      if ev~atPs <= untilPs then do
        if selected == .nil then do
          selected = ev
          selectedIndex = i
        end
        else if ev~atPs < selected~atPs | (ev~atPs = selected~atPs & ev~sequence < selected~sequence) then do
          selected = ev
          selectedIndex = i
        end
      end
    end
    if selected == .nil then leave
    /* Array~remove() leaves the remaining indexes sparse.  Rebuild the
     * scheduler queue so a subsequent event cannot be hidden behind a hole.
     * Sequence is unique and preserves deterministic same-time ordering. */
    remaining = .array~new
    do queuedEvent over queue
      if queuedEvent~sequence <> selected~sequence then remaining~append(queuedEvent)
    end
    queue = remaining
    nowPs = selected~atPs
    selected~target~sendWith(selected~messageName, selected~arguments)
    processedEvents += 1
  end
  nowPs = untilPs
  return self~now

::class SimulationRunMetrics public
::attribute simulatedSeconds get
::attribute wallSeconds get
::attribute realtimeFactor get

::method init
  expose simulatedSeconds wallSeconds realtimeFactor
  numeric digits 50
  use strict arg simulatedArg, wallArg
  simulatedSeconds = simulatedArg + 0
  wallSeconds = wallArg + 0
  if wallSeconds <= 0 then realtimeFactor = .nil
  else realtimeFactor = simulatedSeconds / wallSeconds

::method simulatedTime
  expose simulatedSeconds
  return .Units~q(simulatedSeconds, .Units~second)

::method wallTime
  expose wallSeconds
  return .Units~q(wallSeconds, .Units~second)

::requires 'RexxTronicsUnits.cls'
