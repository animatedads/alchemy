parse arg bridgeDir caFile
cfg=.ApiHttpTransportConfig~new
cfg~bridgeDirectory=bridgeDir; cfg~caFile=caFile; cfg~readTimeout=5; cfg~writeTimeout=5
transport=.ApiHttpsTransport~new(cfg)

/* Exercise the real ApiClient route/session seam, not transport directly. */
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

payload=.directory~new; payload['steps']=100; payload['vocab_target']=65536
inputs=.array~of(.HFSpaceInputFile~new('input_bundle','../tests/input.bundle'))
req=.HFSpaceJobRequirement~new('GPU',16384,100,.false,.true,.true)
spec=.HFSpaceJobSpec~new('gemma-recovery-acceptance',req,payload,inputs,'../tests/output',.true,'GEMMA_OOREXX_RECOVERY_V1')
r=runner~run(spec)
if \r~success then do; say 'FAIL RUN' r~code; say r~evidence~canonical; exit 2; end
if r~endpoint<>"job_large" then do; say 'FAIL ENDPOINT' r~endpoint; exit 3; end
if r~quotaSource<>"INCLUDED" | r~quotaCostSeconds<>100 then do; say 'FAIL QUOTA' r~quotaSource r~quotaCostSeconds; exit 4; end
if budget~remainingIncludedSeconds<>2300 then do; say 'FAIL QUOTA REMAIN' budget~remainingIncludedSeconds; exit 5; end
if r~downloadedFiles~items<>1 then do; say 'FAIL DOWNLOAD COUNT' r~downloadedFiles~items; exit 6; end
if r~artifactReceipts~items<>1 then do; say 'FAIL RECEIPT COUNT' r~artifactReceipts~items; exit 61; end
if r~artifactReceipts[1]~sha256<>'e6dc8ce6ba6471200248aa3e2d1cce80b85633db7cc370a5f8e630485b682e87' then do; say 'FAIL RECEIPT SHA'; exit 62; end
if r~artifactReceipts[1]~sizeBytes<>26 then do; say 'FAIL RECEIPT SIZE'; exit 63; end
if pos('VERIFY|OK|managed-output.zip',r~evidence~canonical)=0 then do; say 'FAIL VERIFY EVIDENCE'; exit 64; end
p=r~downloadedFiles[1]
s=.stream~new(p); s~open('READ'); line=s~lineIn; s~close
if line<>"managed-output-bundle-456" then do; say 'FAIL ARTIFACT' line; exit 7; end
if sessions~activeCount<>0 then do; say 'FAIL SESSION LEAK' sessions~activeCount; exit 8; end
if pos('hf_test_token',r~evidence~canonical)>0 then do; say 'FAIL TOKEN EVIDENCE'; exit 9; end
transport~close
say 'PASS HF SPACE API CLIENT HTTPS UPLOAD V2 SUBMIT SSE DOWNLOAD CLEANUP'
exit 0
::requires 'HuggingFaceSpaceJob.cls'
