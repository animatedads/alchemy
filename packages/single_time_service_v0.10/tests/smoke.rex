/* Limited, explicit 2026 rules fixture — no general timezone database claim */

service = .SingleTimeService~new
london = .TimeZoneRules~new('Europe/London')
london~addPeriod(1750000000,3600,'BST')
london~addPeriod(1792890000,0,'GMT')
sydney = .TimeZoneRules~new('Australia/Sydney')
sydney~addPeriod(1750000000,36000,'AEST')
sydney~addPeriod(1791043200,39600,'AEDT')
service~registerZone(london)~registerZone(sydney)

/* midday London on each date, represented by UTC seconds */
dates = .array~of('2026-10-01','2026-10-08','2026-10-31')
instants = .array~of(1790852400,1791457200,1793448000)
expected = .array~of(32400,36000,39600)
failures = 0
do i = 1 to dates~items
  actual = service~differenceAt('Europe/London','Australia/Sydney',.TimeInstant~new(instants[i]))
  say dates[i] 'Sydney ahead seconds:' actual 'expected:' expected[i]
  if actual \= expected[i] then failures = failures + 1
end
if failures > 0 then do
  say 'FAIL:' failures 'scenario(s)'
  exit 1
end
say 'PASS: 3 scenario(s)'
exit 0

::requires 'SingleTime.cls'
