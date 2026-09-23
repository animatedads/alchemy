parse source . . here
root=filespec('location',here) || '..'; call directory root
tmp='/tmp/cognitive-dogfood-'||random(10000,99999)
address command 'rm -rf' tmp
address command 'mkdir -p' tmp
p=.CognitiveAccessPolicy~new
scope='project:dogfood-real'; observer='operator:dogfood'; learner='cognitive:scheduler'
call must p~grant(observer,'cognitive.dogfood.observe',scope),'grant observe'
call must p~grant(observer,'cognitive.context.explain',scope),'grant explain'
call must p~grant(learner,'cognitive.learning.delta',scope),'grant learn'
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(tmp||'/cognitive.jsonl'),p,.CognitiveJsonlMeasurementJournal~new(tmp||'/measure.jsonl'))
manifest=.array~of('codex:safety29:ask','codex:safety29:wrong-next')
a=.directory~new; a['scopeRef']=scope; a['observationClass']='CLIENT_REPLY_CORRELATION_FAILURE'; a['task']='Safety29 MVT long run'; a['expectedBehavior']='Return the reply correlated to the Safety29 request id'; a['observedBehavior']='FIFO next returned an older QueueRexx deployment plan'; a['evidenceManifest']=manifest; a['evidenceRefs']=.array~of('codex:safety29:ask','codex:safety29:wrong-next')
r=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVE',a,observer); call must r~ok,'record correlation observation'; call eq 'MEASUREMENT_ONLY_NOT_COGNITIVE_AUTHORITY',r~value['disposition'],'non authority'
b=.directory~new; b['scopeRef']=scope; b['observationClass']='COGNITIVE_CONTEXT_BYPASS'; b['task']='Safety29 MVT long run'; b['expectedBehavior']='Ordinary PA ask consumes task-scoped Cognitive Continuity context'; b['observedBehavior']='Candidate6 ordinary ask path did not consume Cognitive Continuity'; b['evidenceManifest']=.array~of('codex:candidate6:path-review'); b['evidenceRefs']=.array~of('codex:candidate6:path-review')
r2=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVE',b,observer); call must r2~ok,'record bypass observation'
bad=.directory~new; bad['scopeRef']=scope; bad['observationClass']='PROJECTION_OVERINCLUSION'; bad['evidenceManifest']=.array~of('e:known'); bad['evidenceRefs']=.array~of('e:invented')
br=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVE',bad,observer); call must \br~ok,'reject unbound evidence'; call eq 'DOGFOOD_EVIDENCE_REF_NOT_IN_MANIFEST',br~code,'unbound code'
q=.directory~new; q['scopeRef']=scope; q['sinceMeasurementSequence']=0
listed=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVATIONS',q,observer); call must listed~ok,'list observations'; call eq 2,listed~value['count'],'observation count'
la=.directory~new; la['scopeRef']=scope; la['sinceSequence']=0; la['sinceMeasurementSequence']=0
bundle=svc~dispatch('COGNITIVE.LEARNING.BUNDLE',la,learner); call must bundle~ok,'learning bundle'; call eq 2,bundle~value['dogfoodObservationCount'],'bundle observation count'
req=.CognitiveLearningRequestBuilder~fromBundle(bundle~value,'HOURLY','LOW_COST')
call eq 2,req['dogfoodObservations']~items,'request observations'; call eq 'cognitive.learning.request/2',req['schema'],'schema remains v2'
/* Restart proves observations are durable measurements but not cognitive records. */
svc2=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(tmp||'/cognitive.jsonl'),p,.CognitiveJsonlMeasurementJournal~new(tmp||'/measure.jsonl'))
listed2=svc2~dispatch('COGNITIVE.DOGFOOD.OBSERVATIONS',q,observer); call eq 2,listed2~value['count'],'observation replay'
address command 'rm -rf' tmp
say 'PASS test_dogfood_observation'
exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveLearningQueueAdapter.cls'
