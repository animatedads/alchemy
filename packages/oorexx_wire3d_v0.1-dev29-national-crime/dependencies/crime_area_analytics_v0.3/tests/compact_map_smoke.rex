dataset = .CrimeAreaDataset~new('test.compact')
do i = 1 to 4
  code = 'A' || i
  frame = dataset~ensureFrame('2025-01', code, code)
  frame~totalCrimeCount = i * 2
end
request = .CrimeMapRequest~new('2025-01')
request~compactThreshold = 2
service = .CrimeMapSemanticService~new(dataset)
frame = service~build(request)
if frame~assessmentDetail <> 'COMPACT' then do; say 'FAIL detail' frame~assessmentDetail; exit 1; end
if frame~areaFacts~items <> 0 then do; say 'FAIL rich facts should be empty'; exit 1; end
if frame~compactAreaLayer = .nil then do; say 'FAIL compact layer missing'; exit 1; end
if frame~compactAreaLayer~itemCount <> 4 then do; say 'FAIL compact item count' frame~compactAreaLayer~itemCount; exit 1; end
if frame~compactAreaLayer~areaCodes[1] <> 'A1' then do; say 'FAIL first area'; exit 1; end
if frame~compactAreaLayer~metricValues[4] <> 8 then do; say 'FAIL last metric' frame~compactAreaLayer~metricValues[4]; exit 1; end
if frame~compactAreaLayer~hotspotBands[4] = '' then do; say 'FAIL compact hotspot band'; exit 1; end
say 'PASS crime_area_analytics_v0.3 compact map smoke'
exit 0
::requires 'CrimeMapSemanticService.cls'
