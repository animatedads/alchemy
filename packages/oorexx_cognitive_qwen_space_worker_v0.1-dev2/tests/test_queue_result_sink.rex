request=.directory~new; request['schema']='cognitive.learning.request/2'; request['requestId']='learn-sink'; request['scopeRef']='project:test'; request['fromCorpusPointId']='cp-0'; request['toCorpusPointId']='cp-1'; request['records']=.array~new; request['projectionReceipts']=.array~new; request['projectionOutcomes']=.array~new
lr=.directory~new; lr['schema']='cognitive.learning.result/2'; lr['requestId']='learn-sink'; lr['scopeRef']='project:test'; lr['workerId']='qwen-test'; lr['disposition']='PROPOSALS_ONLY_NOT_ADMITTED'
do n over .array~of('classificationProposals','classificationAnomalies','conceptProposals','lessonCandidates','procedureCandidates','toolCandidates','projectionFindings','integrationProposals'); lr[n]=.array~new; end
q=.FakeQueue~new(request); w=.FakeWorker~new(lr); s=.FakeSink~new(.true)
c=.CognitiveQwenQueueConsumer~new(q,w,s); r=c~runOnce; call must r~ok,'consumer success'; call eq 1,s~captures,'captured'; call eq 1,q~acks,'acked'; call eq 0,q~nacks,'not nacked'; call must s~capturedBeforeAck,'capture before ack'
q2=.FakeQueue~new(request); s2=.FakeSink~new(.false); c2=.CognitiveQwenQueueConsumer~new(q2,w,s2); r2=c2~runOnce; call must \r2~ok,'capture failure'; call eq 'LEARNING_RESULT_CAPTURE_FAILED',r2~code,'failure code'; call eq 0,q2~acks,'no ack'; call eq 1,q2~nacks,'nack'
say 'PASS test_queue_result_sink'
exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e==a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::class FakePackage
::attribute payload get
::attribute packageId get
::attribute claimToken get
::method init; expose payload packageId claimToken; use arg payload; packageId='pkg-1'; claimToken='tok-1'
::class FakeQueue
::attribute acks get
::attribute nacks get
::attribute acked get
::method init; expose req acks nacks acked; use arg req; acks=0; nacks=0; acked=.false
::method claim; expose req; return .CognitiveQwenWorkerResult~success(.FakePackage~new(req))
::method ack; expose acks acked; use arg package; acks+=1; acked=.true; return .CognitiveQwenWorkerResult~success(.true)
::method nack; expose nacks; use arg package,reason=''; nacks+=1; return .CognitiveQwenWorkerResult~success(.true)
::method wasAcked; expose acked; return acked
::class FakeWorker
::method init; expose out; use arg out; self~out=out
::attribute out
::method run; expose out; use arg req; return .CognitiveQwenWorkerResult~success(out)
::class FakeSink
::attribute captures get
::attribute capturedBeforeAck get
::method init; expose ok captures capturedBeforeAck; use arg ok; captures=0; capturedBeforeAck=.true
::method capture
  expose ok captures capturedBeforeAck
  use arg req,res
  captures+=1
  if ok then return .CognitiveQwenWorkerResult~success(.true)
  return .CognitiveQwenWorkerResult~failure('SINK_REJECTED')
::requires 'CognitiveQwenSpaceWorker.cls'
