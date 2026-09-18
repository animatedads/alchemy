/* Queue/Space nearline worker for Cognitive Continuity.
 * Qwen is a proposal-only analysis worker.  It cannot admit cognitive state.
 */
::class CognitiveQwenWorkerResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::method init
  expose ok code value detail
  use strict arg okArg, codeArg, valueArg=.nil, detailArg=''
  ok=okArg; code=codeArg~string; value=valueArg; detail=detailArg~string
::method success class
  use strict arg valueArg
  return self~new(.true,'OK',valueArg,'')
::method failure class
  use strict arg codeArg, detailArg=''
  return self~new(.false,codeArg,.nil,detailArg)

::class CognitiveQwenSpaceWorker public
::constant API "cognitive.qwen.space-worker/0.1"
::constant REQUEST_SCHEMA "cognitive.learning.request/2"
::constant RESULT_SCHEMA "cognitive.learning.result/2"
::constant OPERATION_ID "COGNITIVE_QWEN_INTEGRATION_V1"
::attribute runner get
::attribute workDirectory get
::method init
  expose runner workDirectory expectedGpuSeconds minimumVramMiB allowPaidCredits
  use strict arg runnerArg, workDirectoryArg, expectedSecondsArg=100, minVramArg=49152, paidArg=.false
  if runnerArg==.nil then raise syntax 88.900 array('HFSpaceJobRunner is required')
  runner=runnerArg; workDirectory=workDirectoryArg~string~strip
  if workDirectory='' then raise syntax 88.900 array('worker directory is required')
  expectedGpuSeconds=expectedSecondsArg+0; minimumVramMiB=minVramArg+0; allowPaidCredits=(paidArg==.true)
  if expectedGpuSeconds<=0 then raise syntax 88.900 array('expected GPU seconds must be positive')

::method run
  expose runner workDirectory expectedGpuSeconds minimumVramMiB allowPaidCredits
  use strict arg request
  checked=self~validateRequest(request); if \checked~ok then return checked
  requestId=request['requestId']~string
  safeId=self~safeName(requestId)
  if safeId='' then return .CognitiveQwenWorkerResult~failure('REQUEST_ID_INVALID',requestId)
  ignore=SysFileTree(workDirectory,'wd.','D')
  if wd.0=0 then do
    mk=SysMkDir(workDirectory); if mk<>0 then return .CognitiveQwenWorkerResult~failure('WORK_DIRECTORY_CREATE_FAILED',workDirectory)
  end
  inputPath=workDirectory || '/' || safeId || '-learning-request.json'
  outputDir=workDirectory || '/' || safeId || '-output'
  call charout inputPath,.json~toJSON(request)
  call stream inputPath,'c','close'
  req=.HFSpaceJobRequirement~new('GPU',minimumVramMiB,expectedGpuSeconds,allowPaidCredits,.true,.false)
  payload=.directory~new; payload['temperature']=0.1; payload['max_new_tokens']=1536
  inputs=.array~of(.HFSpaceInputFile~new('input_bundle',inputPath))
  spec=.HFSpaceJobSpec~new('cognitive-qwen-'||safeId,req,payload,inputs,outputDir,.true,self~OPERATION_ID)
  result=runner~run(spec)
  if \result~success then return .CognitiveQwenWorkerResult~failure('HF_SPACE_'||result~code,result~jobId)
  parsed=self~parseComplete(result~completeData)
  if parsed==.nil then return .CognitiveQwenWorkerResult~failure('QWEN_COMPLETE_RESULT_INVALID')
  op=parsed~at('operation_result')
  if op==.nil | \op~isA(.Directory) then return .CognitiveQwenWorkerResult~failure('QWEN_OPERATION_RESULT_MISSING')
  valid=self~validateResult(op,request); if \valid~ok then return valid
  return .CognitiveQwenWorkerResult~success(op)

::method validateRequest private
  use strict arg request
  if request==.nil | \request~isA(.Directory) then return .CognitiveQwenWorkerResult~failure('LEARNING_REQUEST_INVALID')
  if \request~hasIndex('schema') | request['schema']<>self~REQUEST_SCHEMA then return .CognitiveQwenWorkerResult~failure('LEARNING_REQUEST_SCHEMA_UNSUPPORTED')
  do name over .array~of('requestId','scopeRef','records','projectionReceipts','projectionOutcomes')
    if \request~hasIndex(name) then return .CognitiveQwenWorkerResult~failure('LEARNING_REQUEST_FIELD_REQUIRED',name)
  end
  if \request['records']~isA(.Array) | \request['projectionReceipts']~isA(.Array) | \request['projectionOutcomes']~isA(.Array) then return .CognitiveQwenWorkerResult~failure('LEARNING_REQUEST_ARRAY_INVALID')
  return .CognitiveQwenWorkerResult~success(request)

::method validateResult private
  use strict arg result, request
  if \result~hasIndex('schema') | result['schema']<>self~RESULT_SCHEMA then return .CognitiveQwenWorkerResult~failure('LEARNING_RESULT_SCHEMA_UNSUPPORTED')
  if \result~hasIndex('requestId') | result['requestId']<>request['requestId'] then return .CognitiveQwenWorkerResult~failure('LEARNING_RESULT_REQUEST_MISMATCH')
  if \result~hasIndex('scopeRef') | result['scopeRef']<>request['scopeRef'] then return .CognitiveQwenWorkerResult~failure('LEARNING_RESULT_SCOPE_MISMATCH')
  if \result~hasIndex('disposition') | result['disposition']<>'PROPOSALS_ONLY_NOT_ADMITTED' then return .CognitiveQwenWorkerResult~failure('LEARNING_RESULT_DISPOSITION_INVALID')
  do forbidden over .array~of('actorId','principalId','authority','origin','epistemicState','decisionAuthority','verificationState','toolVerified','qualified','admitted')
    if result~hasIndex(forbidden) then return .CognitiveQwenWorkerResult~failure('LEARNING_RESULT_AUTHORITY_FIELD_FORBIDDEN',forbidden)
  end
  return .CognitiveQwenWorkerResult~success(result)

::method parseComplete private
  use strict arg raw
  signal on syntax name badJson
  doc=.json~fromJSON(raw)
  signal off syntax
  if doc==.nil then return .nil
  if doc~isA(.Directory) then return doc
  if doc~isA(.Array) then if doc~items>=1 then if doc[1]~isA(.Directory) then return doc[1]
  return .nil
badJson:
  return .nil

::method safeName private
  use strict arg text
  n=text~string
  if n='' then return ''
  allowed='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.'
  do i=1 to n~length
    if pos(n~substr(i,1),allowed)=0 then return ''
  end
  if n~length>120 then return ''
  return n

::class CognitiveQwenQueueConsumer public
::method init
  expose queueAdapter worker resultSink
  use strict arg queueAdapterArg, workerArg, resultSinkArg=.nil
  queueAdapter=queueAdapterArg; worker=workerArg; resultSink=resultSinkArg
::method runOnce
  expose queueAdapter worker resultSink
  claim=queueAdapter~claim
  if \claim~ok then return .CognitiveQwenWorkerResult~failure('QUEUE_CLAIM_FAILED')
  package=claim~value
  learnResult=worker~run(package~payload)
  if learnResult~ok then do
    if resultSink<>.nil then do
      stored=resultSink~capture(package~payload,learnResult~value)
      if \stored~ok then do
        ignore=queueAdapter~nack(package,'LEARNING_RESULT_CAPTURE_FAILED')
        return .CognitiveQwenWorkerResult~failure('LEARNING_RESULT_CAPTURE_FAILED',stored~code)
      end
    end
    ack=queueAdapter~ack(package)
    if \ack~ok then return .CognitiveQwenWorkerResult~failure('QUEUE_ACK_FAILED')
    return learnResult
  end
  ignore=queueAdapter~nack(package,learnResult~code)
  return learnResult

::requires 'HuggingFaceSpaceJob.cls'
::requires 'json.cls'
