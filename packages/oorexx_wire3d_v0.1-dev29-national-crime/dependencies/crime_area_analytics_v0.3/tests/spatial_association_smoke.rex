set = .CrimeAreaDataset~new
set~ensureArea("A", "Area A")
set~ensureArea("B", "Area B")
set~ensureArea("C", "Area C")
do i = 1 to 8
  p = "2025-" || i~right(2, "0")
  call addCount set, p, "A", "Burglary", i
  if i = 1 then b = 0
  else b = i - 1
  call addCount set, p, "B", "Burglary", b
  call addCount set, p, "C", "Burglary", 10 - i
end

graph = .CrimeAreaNeighbourGraph~new
graph~sourceRevision = "synthetic-touching-polygons"
graph~addEdge(.CrimeAreaNeighbourEdge~new("A", "B", "TOUCHES", "gis:A:B"))
graph~addEdge(.CrimeAreaNeighbourEdge~new("B", "C", "TOUCHES", "gis:B:C"))
call assert graph~edgeCount = 2, "two neighbour edges"
call assert graph~neighbours("B")~items = 2, "B has two neighbours"

crimeTypes = .array~of("Burglary")
associationFrame = .CrimeSpatialAssociationBatchAnalyzer~assessNeighbours(set, graph, crimeTypes, 2, 4, 0.60)
call assert associationFrame~assessments~items >= 1, "association assessments"
facts = .CrimeSpatialMapProjector~facts(set, associationFrame, 0.60)
call assert facts~items >= 1, "map association facts"
call assert facts[1]~interpretation~pos("not offender movement") > 0, "interpretation lock"

say "PASS crime_area_analytics_v0.3 spatial association smoke"
exit 0

addCount: procedure
  use arg set, periodKey, areaCode, crimeType, count
  frame = set~ensureFrame(periodKey, areaCode)
  frame~totalCrimeCount += count
  frame~crimeTypeCounts~put(count, crimeType)
  return

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeSpatialAnalysis.cls"
