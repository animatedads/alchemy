/* Two institutional revisions; advisory impact, no scheduling side effects. */
numeric digits 30
s=.SingleTimeService~new
s~registerZone(.TzifZoneProvider~new('fixtures','2025b-fixture')~load('Europe/London'))
path='examples/.time_impact_example.journal'
unused=SysFileDelete(path)
a=.TimeAuthorityLedger~new(path)
r=a~addCalendar('SCHOOL','Europe/London','term-2026',0)
r=a~addEvent('meal-007','SCHOOL','School dinner','MEAL','2026-10-01','2026-12-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-v1',r)
r=a~bindPhrase('SCHOOL','dinner','meal-007',r)
oldRevision=r
r=a~moveDate('meal-007','2026-10-26','13:00:00','Lunchtime timetable change',r)
checker=.TimeImpactAnalyzer~new(a,s)
report=checker~compare('SCHOOL','dinner','2026-10-26','2026-10-28',oldRevision,r)
say 'Scanned:' report['scannedDays'] 'Changed:' report['changedDays'] 'Unchanged:' report['unchangedDays']
do item over report['changes']
  say item['date'] item['before']['occurrences'][1]['local'] '->' item['after']['occurrences'][1]['local']
  say '  UTC shift seconds:' item['utcDeltaSeconds'] 'Advice only; no dispatch'
end
unused=SysFileDelete(path)
::requires 'TzifZoneProvider.cls'
::requires 'TimeImpactAnalysis.cls'
