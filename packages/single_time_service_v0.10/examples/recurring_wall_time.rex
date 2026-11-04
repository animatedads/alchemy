/* Demonstrates how a fixed London local wall time changes UTC instant. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
engine=.TimeRecurrenceEngine~new(s)
pattern=.TimeRecurrenceSpec~new('office-open','Europe/London','2026-10-23T09:00:00', 'WEEKLY',1,'MO,TU,WE,TH,FR','SKIP','EARLIER')
rows=engine~expand(pattern,'2026-10-23T00:00:00','2026-10-27T23:59:59')
say 'Intention: every weekday 09:00 Europe/London, no weekend occurrences'
do o over rows
  say o~localIso '=> POSIX:' o~instant~ticks 'offset:' o~offsetSeconds 'edition:' o~edition
end
say 'The date/time intention remains stable; its UTC projection changes.'
::requires 'TzifZoneProvider.cls'
::requires 'TimeRecurrence.cls'
