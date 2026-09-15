route=.ApiRouteRequirement~new('','','PUBLIC','DIRECT')
target=.HFSpaceTarget~new('rexxapiai/rexxapi','https://example.invalid',route,.nil,.nil,.nil,'_job','request')
adapter=.ReceiptFakeAdapter~new(target)
budget=.HFZeroGpuQuotaBudget~new(2400,2400,.false,'TEST')
runner=.HFSpaceJobRunner~new(adapter,budget)
payload=.directory~new; payload['steps']=1
inputs=.array~of(.HFSpaceInputFile~new('input_bundle','input.bundle'))
req=.HFSpaceJobRequirement~new('GPU',16384,10,.false,.true,.true)
call SysMkDir 'output-receipt'
spec=.HFSpaceJobSpec~new('receipt-test',req,payload,inputs,'output-receipt',.true,'MANAGED_SMOKE_V1')
r=runner~run(spec)
if \r~success then call fail 'receipt job failed: ' || r~code
if r~artifactReceipts~items<>1 then call fail 'expected one verified receipt'
rec=r~artifactReceipts[1]
if rec~name<>'managed-output.zip' then call fail 'receipt name'
if rec~sizeBytes<>26 then call fail 'receipt size'
if rec~sha256<>'e6dc8ce6ba6471200248aa3e2d1cce80b85633db7cc370a5f8e630485b682e87' then call fail 'receipt sha'
if pos('VERIFY|OK|managed-output.zip',r~evidence~canonical)=0 then call fail 'verify evidence missing'

/* Provider-reserved logical parameters cannot be overwritten by input files. */
badInputs=.array~of(.HFSpaceInputFile~new('_job','input.bundle'))
bad=.HFSpaceJobSpec~new('collision-test',req,payload,badInputs,'',.true,'MANAGED_SMOKE_V1')
before=adapter~uploads
br=runner~run(bad)
if br~success | br~code<>'INPUT_PARAMETER_COLLISION' then call fail 'collision did not fail closed'
if adapter~uploads<>before then call fail 'collision touched network/upload'

say 'PASS HF SPACE VERIFIED ARTIFACT RECEIPT / PARAMETER CONTAINMENT'
exit 0

fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1

::class ReceiptFakeAdapter
::attribute target get
::attribute uploads get
::method init
  expose target uploads
  use arg targetArg
  target=targetArg; uploads=0
::method upload
  expose uploads
  use arg path
  uploads+=1
  return .array~of(.true,'OK','/tmp/gradio/input.bundle')
::method submit
  use arg endpoint,payload
  return .array~of(.true,'OK','evt-1')
::method poll
  use arg endpoint,eventId
  doc=.directory~new
  doc['status']='COMPLETED'; doc['cleanup']='DONE'; doc['operation_id']='MANAGED_SMOKE_V1'
  doc['artifact_name']='managed-output.zip'; doc['artifact_size']=26
  doc['artifact_sha256']='e6dc8ce6ba6471200248aa3e2d1cce80b85633db7cc370a5f8e630485b682e87'
  f=.directory~new; f['path']='/tmp/gradio/managed-output.zip'; f['url']='https://example.invalid/files/managed-output.zip'; f['orig_name']='managed-output.zip'
  meta=.directory~new; meta['_type']='gradio.FileData'; f['meta']=meta
  return .array~of(.true,'OK',.json~toJSON(.array~of(doc,f)))
::method download
  use arg url,path
  s=.stream~new(path); s~open('WRITE REPLACE'); ignored=s~charOut('managed-output-bundle-456' || '0a'x); s~close
  return 'OK'

::requires 'HuggingFaceSpaceJob.cls'
