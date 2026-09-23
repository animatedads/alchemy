root = directory()
path = root || '/tests/.denominator_fixture.csv'

set = .CrimeAreaDenominatorSet~new('test.denominators')
pop = .CrimeAreaDenominator~new('E0001', 'POPULATION', 1250)
pop~effectiveFromPeriod = '2021-01'
pop~sourceRef = 'ONS, Census "2021"'
pop~sourceRevision = 'rev-1'
set~add(pop)
area = .CrimeAreaDenominator~new('E0001', 'AREA_KM2', 0.5)
area~sourceRef = 'NoSQLServer GIS area'
set~add(area)

.CrimeAreaDenominatorCsvWriter~write(set, path)
loaded = .CrimeAreaDenominatorCsvReader~read(path, 'loaded.denominators')
if loaded~count <> 2 then do; say 'FAIL denominator count' loaded~count; exit 1; end
loadedPop = loaded~lookup('E0001', 'POPULATION', '2025-06')
if loadedPop = .nil then do; say 'FAIL population missing'; exit 1; end
if loadedPop~value <> 1250 then do; say 'FAIL population value' loadedPop~value; exit 1; end
if loadedPop~sourceRef <> 'ONS, Census "2021"' then do; say 'FAIL quoted source ref' loadedPop~sourceRef; exit 1; end
loadedArea = loaded~lookup('E0001', 'AREA_KM2', '2025-06')
if loadedArea~value <> 0.5 then do; say 'FAIL area value' loadedArea~value; exit 1; end
call SysFileDelete path
say 'PASS crime_area_analytics_v0.3 denominator CsvStream I/O smoke'
exit 0
::requires 'CrimeMetricModel.cls'
