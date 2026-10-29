/* Usage: rexx examples/authority_history.rex /trusted/path/new-journal */
parse arg store
if store == '' then do
  say 'Supply an explicit journal pathname (will append if it exists)'
  exit 2
end
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
l=.TimeAuthorityLedger~new(store)
if l~revision \= 0 then do
  say 'Example requires a fresh journal (refuses to overwrite history)'
  exit 2
end
rev=l~addCalendar('SCHOOL','Europe/London','term-r1',0)
rev=l~addEvent('meal-007','SCHOOL','School dinner','MEAL',-
    '2026-10-01','2026-12-31','12:15:00','WEEKLY',1,-
    'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-r1',rev)
rev=l~bindPhrase('SCHOOL','dinner','meal-007',rev)
first=rev
rev=l~moveDate('meal-007','2026-10-26','13:00:00','Revised timetable',rev)
old=l~resolveAt('SCHOOL','dinner','2026-10-26',s,first)
new=l~resolveCurrent('SCHOOL','dinner','2026-10-26',s)
say 'Original:' old['authoritySequence'] old['occurrences'][1]['local']
say 'Revised: ' new['authoritySequence'] new['occurrences'][1]['local']
say 'Journal:' store
::requires 'TzifZoneProvider.cls'
::requires 'TimeAuthorityLedger.cls'
