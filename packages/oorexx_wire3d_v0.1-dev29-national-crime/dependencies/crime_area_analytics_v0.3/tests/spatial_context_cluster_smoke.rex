root = directory()
path = root || '/tests/.neighbour_fixture.csv'
out = .CsvStream~new(path, .false)
out~open('WRITE REPLACE')
out~csvLineOut(.array~of('area_a','area_b','relation_type','evidence_ref','source_revision'))
out~csvLineOut(.array~of('A','B','TOUCHES','gis:A-B','gis-rev-1'))
out~csvLineOut(.array~of('B','C','TOUCHES','gis:B-C','gis-rev-1'))
out~csvLineOut(.array~of('C','D','TOUCHES','gis:C-D','gis-rev-1'))
out~close

graph = .CrimeAreaNeighbourGraphCsvReader~read(path)
call SysFileDelete path
if graph~edgeCount <> 3 then do; say 'FAIL edge count' graph~edgeCount; exit 1; end
if graph~sourceRevision <> 'gis-rev-1' then do; say 'FAIL graph revision'; exit 1; end

dataset = .CrimeAreaDataset~new('test.spatial')
call putCount dataset, '2025-01', 'A', 0
call putCount dataset, '2025-01', 'B', 10
call putCount dataset, '2025-01', 'C', 10
call putCount dataset, '2025-01', 'D', 0

service = .CrimeMapSemanticService~new(dataset, .nil, graph)
request = .CrimeMapRequest~new('2025-01')
request~includeNeighbourContext = .true
request~includeClusters = .true
request~clusterMinimumBand = 'ELEVATED'
frame = service~build(request)
if frame~clusterFacts~items <> 1 then do; say 'FAIL cluster count' frame~clusterFacts~items; exit 1; end
cluster = frame~clusterFacts[1]
if cluster~areaCount <> 2 then do; say 'FAIL cluster area count' cluster~areaCount; exit 1; end
if cluster~areaCodes[1] <> 'B' then do; say 'FAIL cluster B'; exit 1; end
if cluster~areaCodes[2] <> 'C' then do; say 'FAIL cluster C'; exit 1; end
facts = .directory~new
do fact over frame~areaFacts
  facts~put(fact, fact~area~code)
end
if facts~at('B')~neighbourAssessment = .nil then do; say 'FAIL B neighbour assessment'; exit 1; end
if facts~at('B')~neighbourAssessment~contextBand <> 'ELEVATED' then do; say 'FAIL B context band' facts~at('B')~neighbourAssessment~contextBand; exit 1; end
if facts~at('C')~neighbourAssessment~contextBand <> 'ELEVATED' then do; say 'FAIL C context band' facts~at('C')~neighbourAssessment~contextBand; exit 1; end
say 'PASS crime_area_analytics_v0.3 spatial context/cluster smoke'
exit 0

putCount: procedure
  use arg dataset, periodKey, areaCode, count
  frame = dataset~ensureFrame(periodKey, areaCode, areaCode)
  frame~totalCrimeCount = count
  return

::requires 'CrimeMapSemanticService.cls'
::requires 'csvStream.cls'
