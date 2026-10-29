/* Two **archived** TZif datasets, same dinner intention, different projection.
 * The synthetic UK fixed zone is a TEST fixture, not historical timezone data.
 */
numeric digits 30
catalog=.TimeRuleSnapshotCatalog~new('snapshots')
old=catalog~loadService('fixture-2025b',.array~of('Europe/London'))
new=catalog~loadService('synthetic-uk-fixed',.array~of('Europe/London'))
path='examples/.pinned_time_example.journal'
unused=SysFileDelete(path)
ledger=.TimeAuthorityLedger~new(path)
r=ledger~addCalendar('SCHOOL','Europe/London','summer-2026',0)
r=ledger~addEvent('dinner-01','SCHOOL','School dinner','MEAL','2026-07-01','2026-07-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-v1',r)
r=ledger~bindPhrase('SCHOOL','dinner','dinner-01',r)
report=.TimeImpactAnalyzer~new(ledger,old,new)~compare('SCHOOL','dinner','2026-07-07','2026-07-07',r,r)
say 'Changed days:' report['changedDays']
say 'UTC shift from synthetic change:' report['changes'][1]['utcDeltaSeconds'] 'seconds'
say 'Original local intention unchanged:' report['changes'][1]['before']['occurrences'][1]['local']
unused=SysFileDelete(path)
::requires 'TimeRuleSnapshots.cls'
::requires 'TimeImpactAnalysis.cls'
