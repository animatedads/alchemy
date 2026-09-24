/* Qualification: SimulationClock processes multiple events, including events
 * sharing one timestamp, without sparse-array loss and in sequence order.
 */
rec = .EventRecorder~new
clock = .SimulationClock~new
clock~scheduleAt('2 ms', rec, 'RECORD', .array~of('third'), 'third event')
clock~scheduleAt('1 ms', rec, 'RECORD', .array~of('first'), 'first event')
clock~scheduleAt('1 ms', rec, 'RECORD', .array~of('second'), 'second event')
clock~runUntil('3 ms')

if rec~items <> 3 then do
  say 'FAIL expected 3 scheduled events, got' rec~items
  exit 1
end
if rec~at(1) <> 'first' | rec~at(2) <> 'second' | rec~at(3) <> 'third' then do
  say 'FAIL event ordering:' rec~at(1) rec~at(2) rec~at(3)
  exit 1
end
if clock~processedEvents <> 3 then do
  say 'FAIL processedEvents expected 3, got' clock~processedEvents
  exit 1
end
if clock~pendingCount <> 0 then do
  say 'FAIL pendingCount expected 0, got' clock~pendingCount
  exit 1
end
say 'REXX-TRONICS MULTI-EVENT SCHEDULER: OK'
say 'order:' rec~at(1) rec~at(2) rec~at(3)
exit 0

::class EventRecorder
::attribute values get
::method init
  expose values
  values = .array~new
::method record
  expose values
  use strict arg value
  values~append(value)
::method items
  expose values
  return values~items
::method at
  expose values
  use strict arg i
  return values[i]

::requires 'RexxTronicsTime.cls'
