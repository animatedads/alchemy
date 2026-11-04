/* Projection is deterministic, advisory, and never dispatches. */
::requires 'TimeChangePublication.cls'

args=.directory~new
args['schema']='single.time.impact/0.1'
args['effect']='ADVISORY_ONLY'
args['institution']='example.school'
args['phrase']='dinner'
args['fromDate']='2026-10-26'
args['throughDate']='2026-10-26'
args['fromRevision']=3
args['toRevision']=4
args['fromHeadChecksum']='old-head'
args['toHeadChecksum']='new-head'
args['ruleComparisonMode']='SAME_PROVIDER'
change=.directory~new
change['date']='2026-10-26'
change['reasonCodes']=.array~of('LOCAL_TIME_CHANGED','UTC_PROJECTION_CHANGED')
change['before']=.directory~new
change['after']=.directory~new
change['utcDeltaSeconds']=2700
args['changes']=.array~of(change)
args['changedDays']=1
planner=.TimeChangePublication~new('school-time')
first=planner~project(args)
second=planner~project(args)
if first~items \= 1 then raise syntax 93.900 array ('expected one publication')
if first[1]['idempotencyKey'] \== second[1]['idempotencyKey'] then raise syntax 93.900 array ('projection key not deterministic')
if first[1]['utcDeltaSeconds'] \= 2700 then raise syntax 93.900 array ('shift lost')
if first[1]['deliverySemantics'] \== 'UNPUBLISHED_PROJECTION' then raise syntax 93.900 array ('projection incorrectly claims delivery')
args['changes']=.array~new
args['changedDays']=0
if planner~project(args)~items \= 0 then raise syntax 93.900 array ('no-effect changes must not publish')
say 'PASS change publication'
