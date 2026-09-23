dataset = .CrimeAreaDataset~new('test.normalized')
months = .array~of('2025-01','2025-02','2025-03','2025-04','2025-05','2025-06')
aValues = .array~of(1,2,3,4,5,6)
bValues = .array~of(4,4,4,4,4,4)
cValues = .array~of(3,3,3,3,3,3)
do i = 1 to months~items
  call putCount dataset, months[i], 'A', aValues[i]
  call putCount dataset, months[i], 'B', bValues[i]
  call putCount dataset, months[i], 'C', cValues[i]
end

denoms = .CrimeAreaDenominatorSet~new('test.denominators')
denoms~add(.CrimeAreaDenominator~new('A','POPULATION',1000))
denoms~add(.CrimeAreaDenominator~new('B','POPULATION',2000))
denoms~add(.CrimeAreaDenominator~new('A','AREA_KM2',0.5))
denoms~add(.CrimeAreaDenominator~new('B','AREA_KM2',2.0))

service = .CrimeMapSemanticService~new(dataset, denoms)
request = .CrimeMapRequest~new('2025-06')
request~metricKind = 'RATE_PER_1000'
request~includeTrend = .true
request~includeTemporalPattern = .true
frame = service~build(request)
if frame~metricKind <> 'RATE_PER_1000' then do; say 'FAIL frame metric'; exit 1; end
if frame~metricUnit <> 'PER_1000_RESIDENTS' then do; say 'FAIL frame unit' frame~metricUnit; exit 1; end
facts = byArea(frame)
if facts~at('A')~metricValue <> 6 then do; say 'FAIL A rate' facts~at('A')~metricValue; exit 1; end
if facts~at('B')~metricValue <> 2 then do; say 'FAIL B rate' facts~at('B')~metricValue; exit 1; end
if facts~at('C')~metricAvailable then do; say 'FAIL C should be unavailable'; exit 1; end
if facts~at('C')~metricUnavailableReason <> 'POPULATION_DENOMINATOR_MISSING' then do; say 'FAIL C missing reason' facts~at('C')~metricUnavailableReason; exit 1; end
if facts~at('A')~trendAssessment~evidenceGrade <> 'TREND_WINDOW' then do; say 'FAIL trend grade' facts~at('A')~trendAssessment~evidenceGrade; exit 1; end
if facts~at('A')~temporalAssessment~numberOfPoints <> 6 then do; say 'FAIL temporal points'; exit 1; end

change = .CrimeMapRequest~new('2025-06')
change~metricKind = 'RATE_PER_1000'
change~comparisonKind = 'PERCENT_CHANGE'
change~baselinePeriodKey = '2025-05'
changeFrame = service~build(change)
changeFacts = byArea(changeFrame)
if abs(changeFacts~at('A')~metricValue - 20) > 0.000001 then do; say 'FAIL A percent change' changeFacts~at('A')~metricValue; exit 1; end
if changeFacts~at('B')~metricValue <> 0 then do; say 'FAIL B percent change' changeFacts~at('B')~metricValue; exit 1; end
if changeFrame~metricUnit <> 'PERCENT' then do; say 'FAIL percent unit'; exit 1; end

density = .CrimeMapRequest~new('2025-06')
density~metricKind = 'DENSITY_PER_KM2'
densityFrame = service~build(density)
densityFacts = byArea(densityFrame)
if densityFacts~at('A')~metricValue <> 12 then do; say 'FAIL A density' densityFacts~at('A')~metricValue; exit 1; end
if densityFacts~at('B')~metricValue <> 2 then do; say 'FAIL B density' densityFacts~at('B')~metricValue; exit 1; end

say 'PASS crime_area_analytics_v0.3 normalized map smoke'
exit 0

putCount: procedure
  use arg dataset, periodKey, areaCode, count
  frame = dataset~ensureFrame(periodKey, areaCode, areaCode)
  frame~totalCrimeCount = count
  frame~crimeTypeCounts~put(count, 'Burglary')
  return

byArea: procedure
  use arg frame
  out = .directory~new
  do fact over frame~areaFacts
    out~put(fact, fact~area~code)
  end
  return out

::requires 'CrimeMapSemanticService.cls'
