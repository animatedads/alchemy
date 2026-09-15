parse arg bridgeDir caFile
cfg=.ApiHttpTransportConfig~new
cfg~bridgeDirectory=bridgeDir; cfg~caFile=caFile; cfg~readTimeout=5; cfg~writeTimeout=5
transport=.ApiHttpsTransport~new(cfg)
reg=.ApiEgressRegistry~new
node=.ApiEgressNode~new('NODE-LOCAL',.array~new,.array~new,.array~of('PUBLIC'),.array~of('DIRECT'),.array~new,4,1,'test')
reg~advertise(node)
sessions=.ApiSessionManager~new(reg,'NODE-LOCAL')
client=.ApiClient~new(transport,.nil,.nil,.nil,sessions)
cred=.HFTokenCredential~new('../tests/huggingface.key')
route=.ApiRouteRequirement~new('','','PUBLIC','DIRECT')
target=.HFSpaceTarget~new('rexxapiai/rexxapi','https://localhost:18444',route,.nil,.nil,.nil,'_job','request')
adapter=.HFSpaceApiAdapter~new(client,cred,target)
budget=.HFZeroGpuQuotaBudget~new(2400,2400,.false,'TEST-FRESH-PRO')
runner=.HFSpaceJobRunner~new(adapter,budget)

payload=.directory~new; payload['label']='fallback'
inputs=.array~of(.HFSpaceInputFile~new('input_bundle','../tests/input.bundle'))
req=.HFSpaceJobRequirement~new('CPU',0,0,.false,.true,.false)
spec=.HFSpaceJobSpec~new('gradio-v1-fallback',req,payload,inputs,'../tests/output',.true,'MANAGED_SMOKE_V1')
r=runner~run(spec)
if \r~success then do; say 'FAIL FALLBACK RUN' r~code; say r~evidence~canonical; exit 2; end
if r~endpoint<>"job_cpu" then do; say 'FAIL FALLBACK ENDPOINT' r~endpoint; exit 3; end
if r~quotaCostSeconds<>0 | budget~remainingIncludedSeconds<>2400 then do; say 'FAIL FALLBACK CPU QUOTA'; exit 4; end
if r~downloadedFiles~items<>1 then do; say 'FAIL FALLBACK DOWNLOAD COUNT' r~downloadedFiles~items; exit 5; end
p=r~downloadedFiles[1]
s=.stream~new(p); s~open('READ'); line=s~lineIn; s~close
if line<>"managed-output-bundle-456" then do; say 'FAIL FALLBACK ARTIFACT' line; exit 6; end
if sessions~activeCount<>0 then do; say 'FAIL FALLBACK SESSION LEAK' sessions~activeCount; exit 7; end
if pos('hf_test_token',r~evidence~canonical)>0 then do; say 'FAIL FALLBACK TOKEN EVIDENCE'; exit 8; end
transport~close
say 'PASS HF SPACE AUTO V2-TO-V1 INTROSPECTED FALLBACK'
exit 0
::requires 'HuggingFaceSpaceJob.cls'
