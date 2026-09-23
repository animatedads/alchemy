parse source . . here
root=filespec('location',here) || '..'; call directory root
p=.CognitiveAccessPolicy~new
ignore=p~grant('agent:model','cognitive.effects.propose.model','project:learn')
ignore=p~grant('agent:model','cognitive.records.query','project:learn')
ignore=p~grant('cognitive:scheduler','cognitive.learning.delta','project:learn')
svc=.CognitiveContinuityService~new(.CognitiveMemoryJournal~new,p)
call add svc,'SKILL_EPISODE_HINT','queue','Repeated queue inspection sequence', 'agent:model'
call add svc,'LESSON','queue','Use named queue health ability instead of repeated shell probes', 'agent:model'

args=.directory~new; args['scopeRef']='project:learn'; args['sinceSequence']=0
d=svc~dispatch('COGNITIVE.LEARNING.DELTA',args,'cognitive:scheduler')
call must d~ok,'delta'
call eq 2,d~value['count'],'delta count'
req=.CognitiveLearningRequestBuilder~fromDelta(d~value,'HOURLY','NORMAL')
call eq 'cognitive.learning.request/1',req['schema'],'request schema'
call eq 2,req['recordCount'],'request count'

mgr=.FakeQueueManager~new
qa=.CognitiveLearningQueueAdapter~new(mgr)
put=qa~enqueue(req); call must put~ok,'enqueue'
claim=qa~claim; call must claim~ok,'claim'
pkg=claim~value
call eq req['requestId'],pkg~payload['requestId'],'payload round trip'
result=.CognitiveLearningResultBuilder~emptyResult(pkg~payload,'fake-hourly-worker')
call eq 'PROPOSALS_ONLY_NOT_ADMITTED',result['disposition'],'learning result proposal-only'
ack=qa~ack(pkg); call must ack~ok,'ack'
call eq 1,mgr~acked,'acked count'

say 'PASS test_learning_queue'
exit 0
add: procedure
  use arg svc,kind,subject,statement,actor
  e=.directory~new; e['kind']=kind; e['subjectRef']=subject; e['statement']=statement; e['basisRefs']=.array~new
  a=.directory~new; a['scopeRef']='project:learn'; a['effects']=.array~of(e)
  r=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',a,actor)
  if \r~ok then do; say 'FAIL seed'; exit 93; end
  return
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92

::class FakeQueueResult
::attribute ok get
::attribute value get
::method init; expose ok value; use strict arg okArg,valueArg=.nil; ok=okArg; value=valueArg
::class FakePackage
::attribute packageId get
::attribute claimToken get
::attribute payload get
::method init; expose packageId claimToken payload; use strict arg payloadArg; packageId='pkg-1'; claimToken='claim-1'; payload=payloadArg
::class FakeQueueManager
::attribute acked get
::method init; expose stored acked; stored=.nil; acked=0
::method put; expose stored; use strict arg queue,payload,options,actor; stored=.FakePackage~new(payload); return .FakeQueueResult~new(.true,stored)
::method claim; expose stored; use strict arg queue,actor; return .FakeQueueResult~new(.true,stored)
::method ack; expose acked; use strict arg queue,packageId,claimToken,actor; acked+=1; return .FakeQueueResult~new(.true,.nil)
::method nack; use strict arg queue,packageId,claimToken,options,actor; return .FakeQueueResult~new(.true,.nil)
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveLearningQueueAdapter.cls'
