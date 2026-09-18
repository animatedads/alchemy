tmp='/tmp/cognitive-qwen-worker-'||random(10000,99999)
address command 'rm -rf' tmp
address command 'mkdir -p' tmp
req=.directory~new; req['schema']='cognitive.learning.request/2'; req['requestId']='learn-1'; req['scopeRef']='project:test'; req['records']=.array~new; req['projectionReceipts']=.array~new; req['projectionOutcomes']=.array~new
runner=.FakeRunner~new
worker=.CognitiveQwenSpaceWorker~new(runner,tmp,100,49152,.false)
r=worker~run(req); call must r~ok,'worker run'; call eq 'cognitive.learning.result/2',r~value['schema'],'result schema'; call eq 'PROPOSALS_ONLY_NOT_ADMITTED',r~value['disposition'],'proposal only'; call eq 'COGNITIVE_QWEN_INTEGRATION_V1',runner~operation,'operation id'
/* Result authority injection fails closed. */
runner~injectAuthority=.true
r2=worker~run(req); call must \r2~ok,'authority injection rejected'; call eq 'LEARNING_RESULT_AUTHORITY_FIELD_FORBIDDEN',r2~code,'authority code'
address command 'rm -rf' tmp
say 'PASS test_worker'; exit 0
must: procedure; use arg c,l; if c then return; say 'FAIL' l; exit 91
eq: procedure; use arg e,a,l; if e == a then return; say 'FAIL' l 'expected='e 'actual='a; exit 92
::class FakeSpaceResult
::attribute success get
::attribute code get
::attribute jobId get
::attribute completeData get
::method init
  expose success code jobId completeData
  use strict arg data
  success=.true; code='COMPLETED'; jobId='fake'; completeData=data
::class FakeRunner
::attribute operation get
::attribute injectAuthority
::method init
  expose operation injectAuthority
  operation=''; injectAuthority=.false
::method run
  expose operation injectAuthority
  use strict arg spec
  operation=spec~operationId
  r=.directory~new; r['schema']='cognitive.learning.result/2'; r['requestId']='learn-1'; r['scopeRef']='project:test'; r['workerId']='qwen-test'; r['disposition']='PROPOSALS_ONLY_NOT_ADMITTED'
  do n over .array~of('classificationProposals','classificationAnomalies','conceptProposals','lessonCandidates','procedureCandidates','toolCandidates','projectionFindings','integrationProposals'); r[n]=.array~new; end
  if injectAuthority then r['authority']='MODEL'
  c=.directory~new; c['status']='COMPLETED'; c['cleanup']='DONE'; c['operation_result']=r
  return .FakeSpaceResult~new(.json~toJSON(c))
::requires 'CognitiveQwenSpaceWorker.cls'
::requires 'json.cls'
