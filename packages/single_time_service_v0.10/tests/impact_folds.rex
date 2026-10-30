/* The same wall clock can select different real instants within a DST fold. */
numeric digits 30
s=.SingleTimeService~new
s~registerZone(.TzifZoneProvider~new('fixtures','2025b-test-snapshot')~load('Europe/London'))
path='tests/.time_impact_folds.journal'
unused=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
r=l~addCalendar('SHIFT','Europe/London','shift-v1',0)
r=l~addEvent('A','SHIFT','Night shift','WORK','2026-10-01','2026-11-01','01:30:00','WEEKLY',1,'SU',3600,'RECORD','EARLIER','event-A',r)
r=l~bindPhrase('SHIFT','shift','A',r)
prior=r
r=l~unbindPhrase('SHIFT','shift','A',r)
r=l~addEvent('B','SHIFT','Night shift','WORK','2026-10-01','2026-11-01','01:30:00','WEEKLY',1,'SU',3600,'RECORD','LATER','event-B',r)
r=l~bindPhrase('SHIFT','shift','B',r)
a=.TimeImpactAnalyzer~new(l,s)~compare('SHIFT','shift','2026-10-25','2026-10-25',prior,r)
if a['changedDays'] \= 1 | a['unchangedDays'] \= 0 then do; say 'FAIL fold comparison count'; exit 1; end
change=a['changes'][1]
if change['before']['status'] \= 'FOLD' | change['after']['status'] \= 'FOLD' then do; say 'FAIL fold status'; exit 1; end
if change['utcDeltaSeconds'] \= 3600 then do; say 'FAIL fold UTC delta'; exit 1; end
codes=change['reasonCodes']
localChanged=.false; projectionChanged=.false; resolutionChanged=.false
do code over codes
  if code == 'LOCAL_TIME_CHANGED' then localChanged=.true
  if code == 'UTC_PROJECTION_CHANGED' then projectionChanged=.true
  if code == 'RESOLUTION_CHANGED' then resolutionChanged=.true
end
if localChanged | \projectionChanged | \resolutionChanged then do; say 'FAIL fold reason codes'; exit 1; end
if change['before']['occurrences'][1]['local'] \== change['after']['occurrences'][1]['local'] then do; say 'FAIL fold local equality'; exit 1; end
unused=SysFileDelete(path)
say 'PASS: DST fold impact is UTC-only for unchanged local clock and changed selection'
::requires 'TzifZoneProvider.cls'
::requires 'TimeImpactAnalysis.cls'
