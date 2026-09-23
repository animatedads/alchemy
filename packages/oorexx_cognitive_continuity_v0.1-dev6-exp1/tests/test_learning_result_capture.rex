parse source . . here
root=filespec('location',here) || '..'; call directory root
tmp='/tmp/cognitive-learning-result-'||random(10000,99999)
address command 'rm -rf' tmp
address command 'mkdir -p' tmp
p=.CognitiveAccessPolicy~new
scope='project:learning-result'; operator='operator:test'; learner='cognitive:qwen'
do cap over .array~of('cognitive.effects.propose.operator','cognitive.records.query','cognitive.learning.delta','cognitive.context.project','cognitive.context.explain','cognitive.dogfood.observe')
  call must p~grant(operator,cap,scope),'grant operator 'cap
end
call must p~grant(operator,'cognitive.authority.project_owner',scope),'grant project owner'
call must p~grant(learner,'cognitive.learning.result.record',scope),'grant result record'
call must p~grant(learner,'cognitive.learning.result.query',scope),'grant result query'
svc=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(tmp||'/cognitive.jsonl'),p,.CognitiveJsonlMeasurementJournal~new(tmp||'/measure.jsonl'))
/* One cognitive record and one dog-food measurement give the worker two grounded basis refs. */
e=.directory~new; e['kind']='SKILL_EPISODE_HINT'; e['subjectRef']='safety29'; e['statement']='Authoritative artifact selected by pinned member hash'; e['basisRefs']=.array~new
pa=.directory~new; pa['scopeRef']=scope; pa['effects']=.array~of(e); pa['evidenceManifest']=.array~new
pr=svc~dispatch('COGNITIVE.EFFECTS.PROPOSE',pa,operator); call must pr~ok,'seed cognitive record'
d=.directory~new; d['scopeRef']=scope; d['observationClass']='CLIENT_REPLY_CORRELATION_FAILURE'; d['task']='Safety29'; d['expectedBehavior']='correlated reply'; d['observedBehavior']='old reply'; d['evidenceManifest']=.array~of('e:reply'); d['evidenceRefs']=.array~of('e:reply')
dr=svc~dispatch('COGNITIVE.DOGFOOD.OBSERVE',d,operator); call must dr~ok,'seed dogfood'; dogId=dr~value['measurementId']
ba=.directory~new; ba['scopeRef']=scope; ba['sinceSequence']=0; ba['sinceMeasurementSequence']=0
bundle=svc~dispatch('COGNITIVE.LEARNING.BUNDLE',ba,operator); call must bundle~ok,'bundle'
request=.CognitiveLearningRequestBuilder~fromBundle(bundle~value,'HOURLY','LOW_COST')
lesson=.directory~new; lesson['kind']='LESSON_CANDIDATE'; lesson['statement']='Prefer content identity over presentation filename'; lesson['basisRefs']=.array~of('cog-000000001',dogId)
lr=.CognitiveLearningResultBuilder~emptyResult(request,'qwen:test'); lr['modelId']='Qwen/Test'; lr['lessonCandidates']~append(lesson)
a=.directory~new; a['learningRequest']=request; a['learningResult']=lr
rr=svc~dispatch('COGNITIVE.LEARNING.RESULT.RECORD',a,learner); call must rr~ok,'record learning result'; call eq 'MEASUREMENT_ONLY_NOT_COGNITIVE_AUTHORITY',rr~value['disposition'],'measurement only'
call eq 'cognitive.learning.result/2',rr~value['learningResult']['schema'],'result retained'
replay=svc~dispatch('COGNITIVE.LEARNING.RESULT.RECORD',a,learner); call must replay~ok,'idempotent replay'; call eq 'COGNITIVE_LEARNING_RESULT_REPLAYED',replay~code,'replay code'
conf=.CognitiveLearningResultBuilder~emptyResult(request,'qwen:test'); x=.directory~new; x['kind']='LESSON_CANDIDATE'; x['statement']='different result for same request'; x['basisRefs']=.array~of('cog-000000001'); conf['lessonCandidates']~append(x)
ca=.directory~new; ca['learningRequest']=request; ca['learningResult']=conf
cr=svc~dispatch('COGNITIVE.LEARNING.RESULT.RECORD',ca,learner); call must \cr~ok,'conflicting replay rejected'; call eq 'LEARNING_RESULT_REQUEST_CONFLICT',cr~code,'conflict code'
/* Unknown evidence is rejected. */
bad=.CognitiveLearningResultBuilder~emptyResult(request,'qwen:test'); b=.directory~new; b['kind']='LESSON_CANDIDATE'; b['statement']='invented'; b['basisRefs']=.array~of('measure-999999999'); bad['lessonCandidates']~append(b)
ba2=.directory~new; ba2['learningRequest']=request; ba2['learningResult']=bad
br=svc~dispatch('COGNITIVE.LEARNING.RESULT.RECORD',ba2,learner); call must \br~ok,'reject unknown basis'; call eq 'LEARNING_RESULT_BASIS_REF_UNKNOWN',br~code,'unknown basis code'
/* Nested authority injection is rejected. */
auth=.CognitiveLearningResultBuilder~emptyResult(request,'qwen:test'); c=.directory~new; c['kind']='LESSON_CANDIDATE'; c['statement']='bad authority'; c['basisRefs']=.array~of('cog-000000001'); c['authority']='MODEL'; auth['lessonCandidates']~append(c)
aa=.directory~new; aa['learningRequest']=request; aa['learningResult']=auth
ar=svc~dispatch('COGNITIVE.LEARNING.RESULT.RECORD',aa,learner); call must \ar~ok,'reject authority'; call eq 'LEARNING_RESULT_AUTHORITY_FIELD_FORBIDDEN',ar~code,'authority code'
/* Query and replay prove durable measurement, while cognitive record count stays one. */
q=.directory~new; q['scopeRef']=scope; q['sinceMeasurementSequence']=0
listed=svc~dispatch('COGNITIVE.LEARNING.RESULTS',q,learner); call must listed~ok,'query learning results'; call eq 1,listed~value['count'],'one result'
rq=.directory~new; rq['scopeRef']=scope
records=svc~dispatch('COGNITIVE.RECORDS.QUERY',rq,operator); call eq 1,records~value['count'],'learning result not admitted as record'
svc2=.CognitiveContinuityService~new(.CognitiveJsonlJournal~new(tmp||'/cognitive.jsonl'),p,.CognitiveJsonlMeasurementJournal~new(tmp||'/measure.jsonl'))
listed2=svc2~dispatch('COGNITIVE.LEARNING.RESULTS',q,learner); call eq 1,listed2~value['count'],'learning result replay'
address command 'rm -rf' tmp
say 'PASS test_learning_result_capture'
exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::requires 'CognitiveContinuity.cls'
::requires 'CognitiveLearningQueueAdapter.cls'
