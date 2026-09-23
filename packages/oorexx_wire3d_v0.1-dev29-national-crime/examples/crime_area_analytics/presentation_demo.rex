/* Crime-area analytics is a consumer of generic Wire presentation objects. */
area=.CrimeAreaRef~new('E01000001','City of London 001A')
area~geometryRef='nosql:lsoa_2021_geometry:E01000001'
period=.CrimePeriod~new('2025-09')
series=.CrimeTrendSeries~new(area~code,'Burglary','COUNT')
series~addPoint(.CrimeSeriesPoint~new(.CrimePeriod~new('2025-08'),10))
series~addPoint(.CrimeSeriesPoint~new(period,15))
frame=.CrimeMapFrame~new(period~key,'AREA')
fact=.CrimeMapAreaFact~new(area,period); fact~crimeType='Burglary'; fact~metricValue=15; frame~addAreaFact(fact)
areaSelection=.WireObjectSelector~new('area')
timeSelection=.WireTimeSelector~new('period','2025-08','2025-09','MONTH')
map=.WireGeometryMap~new('area-map',.WireDataFeed~new('map-frame',frame)); map~objectSelector(areaSelection); map~timeSelector(timeSelection)
graph=.WireTimeGraph~new('area-trend',.WireDataSeries~new('trend',series,'period','value')); graph~objectSelector(areaSelection); graph~timeSelector(timeSelection)
view=.WirePresentation~new('crime-area-analytics'); view~add(map); view~add(graph)
map~selectObject(area); graph~activateTime(period)
say 'presentation='view~presentationId 'area='areaSelection~selected~code 'period='timeSelection~selected~key
::requires 'WirePresentation.cls'
::requires 'CrimeAreaModel.cls'
