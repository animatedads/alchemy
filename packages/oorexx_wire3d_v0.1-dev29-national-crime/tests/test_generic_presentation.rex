/* Generic presentation + crime analytics consumer qualification. */
area=.CrimeAreaRef~new('E01000001','City of London 001A')
area~geometryRef='nosql:lsoa_2021_geometry:E01000001'
aug=.CrimePeriod~new('2025-08'); sep=.CrimePeriod~new('2025-09')
series=.CrimeTrendSeries~new(area~code,'Burglary','COUNT')
series~addPoint(.CrimeSeriesPoint~new(aug,10))
series~addPoint(.CrimeSeriesPoint~new(sep,15))
fact=.CrimeMapAreaFact~new(area,sep); fact~crimeType='Burglary'; fact~metricValue=15
frame=.CrimeMapFrame~new(sep~key,'AREA'); frame~addAreaFact(fact)

areaSelector=.WireObjectSelector~new('area')
timeSelector=.WireTimeSelector~new('period','2025-08','2025-09','MONTH')
map=.WireGeometryMap~new('areas',.WireDataFeed~new('crime-map-frame',frame))
map~objectSelector(areaSelector); map~timeSelector(timeSelector)
graph=.WireTimeGraph~new('trend',.WireDataSeries~new('burglary',series,'period','count'))
graph~objectSelector(areaSelector); graph~timeSelector(timeSelector)
details=.WireObjectDetails~new('area-details'); details~objectSelector(areaSelector)
view=.WirePresentation~new('crime-area-analytics')
view~add(map); view~add(graph); view~add(details)

map~selectObject(area)
if areaSelector~selected \== area then call fail 'map selection did not retain area object identity'
if details~currentObject \== area then call fail 'details did not observe shared selector state'
graph~activateTime(sep)
if timeSelector~selected \== sep then call fail 'graph time activation did not retain period object identity'
if timeSelector~rangeStart <> '2025-08' then call fail 'time range start lost'
if timeSelector~rangeEnd <> '2025-09' then call fail 'time range end lost'
if view~elements~items <> 3 then call fail 'presentation composition count'
if graph~source~source \== series then call fail 'graph source changed analytics series identity'
if map~source~source \== frame then call fail 'map source changed analytics frame identity'
say 'GENERIC_PRESENTATION_CRIME_PASS area='areaSelector~selected~code 'time='timeSelector~selected~key 'elements='view~elements~items
exit 0
fail: procedure
  parse arg message
  say 'GENERIC_PRESENTATION_CRIME_FAIL' message
  exit 1

::requires 'WirePresentation.cls'
::requires 'CrimeAreaModel.cls'
