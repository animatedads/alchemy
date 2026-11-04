/* Native TZif fixtures, no Python or host timezone conversion at runtime. */
numeric digits 30
provider = .TzifZoneProvider~new('fixtures','HOST-TZDATA-2025')
s = .SingleTimeService~new
names = .array~of('Europe/London','Australia/Sydney','Australia/Brisbane', 'Australia/Lord_Howe','Pacific/Apia','Asia/Kathmandu','Etc/UTC','Pacific/Chatham')
do i = 1 to names~items
  rules = provider~load(names[i])
  say names[i] 'periods:' rules~periodCount 'first:' rules~periodNumber(1)~abbreviation
  s~registerZone(rules)
end
instants = .array~of(1790852400,1791457200,1793448000)
expected = .array~of(32400,36000,39600)
do i=1 to 3
  actual = s~differenceAt('Europe/London','Australia/Sydney',.TimeInstant~new(instants[i]))
  if actual \= expected[i] then do
    say 'FAIL difference' i actual expected[i]
    exit 1
  end
end
r = s~resolveLocal('Europe/London',.TimeLocalReading~new(1774747800))
if r~status \= 'GAP' then do; say 'FAIL UK gap' r~status; exit 1; end
r = s~resolveLocal('Europe/London',.TimeLocalReading~new(1792891800))
if r~status \= 'FOLD' then do; say 'FAIL UK fold' r~status; exit 1; end
say 'PASS: native TZif samples and London/Sydney 2026, UK gap/fold'
::requires 'TzifZoneProvider.cls'
