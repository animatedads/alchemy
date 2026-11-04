/* Two institutions can have different answers to the same human phrase. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-fixture')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
s~registerZone(p~load('Australia/Sydney'))
c=.TimeEventCatalog~new
school=.TimeInstitutionCalendar~new('EXAMPLE-SCHOOL','Europe/London','term-example')
school~closeDate('2026-10-28','Institutional holiday (example only)')
c~registerCalendar(school)
c~registerCalendar(.TimeInstitutionCalendar~new('EXAMPLE-HOME','Australia/Sydney','family-example'))
c~registerEvent(.TimeNamedEvent~new('school-meal','EXAMPLE-SCHOOL','School dinner','MEAL','2026-10-01','2026-12-31','12:15:00'))
c~registerEvent(.TimeNamedEvent~new('home-meal','EXAMPLE-HOME','Family dinner','MEAL','2026-10-01','2026-12-31','18:30:00','DAILY',1,''))
c~bindPhrase('EXAMPLE-SCHOOL','dinner','school-meal')
c~bindPhrase('EXAMPLE-HOME','dinner','home-meal')
do institution over .array~of('EXAMPLE-SCHOOL','EXAMPLE-HOME')
  answer=c~resolve(institution,'dinner','2026-10-26',s)
  say institution answer['status'] answer['label'] answer['zone']
  do occurrence over answer['occurrences']
    say '  ' occurrence['local'] '=> UTC epoch' occurrence['instantPosixSeconds']
  end
end
answer=c~resolve('EXAMPLE-SCHOOL','dinner','2026-10-28',s)
say 'EXAMPLE-SCHOOL on 2026-10-28:' answer['status'] answer['reason']
::requires 'TzifZoneProvider.cls'
::requires 'TimeEvents.cls'
