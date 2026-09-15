t=.FakeTransport~new
client=.ApiClient~new(t)
target=.HFSpaceTarget~new('rexxapiai/rexxapi')
a=.HFSpaceApiAdapter~new(client,.nil,target)
base=a~resolveBaseUrl
if base<>"https://rexxapiai-rexxapi.hf.space" then call fail 'bad discovered base: ' || base
if t~count<>1 then call fail 'discovery request count'
if t~lastUrl<>"https://huggingface.co/api/spaces/rexxapiai/rexxapi" then call fail 'wrong Hub discovery URL: ' || t~lastUrl
say 'PASS HF SPACE HUB DISCOVERY THROUGH APICLIENT'
exit 0
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::class FakeTransport subclass ApiTransport
::attribute count get
::attribute lastUrl get
::method init
  expose count lastUrl
  count=0; lastUrl=""
::method execute
  expose count lastUrl
  use arg request,session=.nil
  count+=1; lastUrl=request~url
  body='{"id":"rexxapiai/rexxapi","sdk":"gradio","subdomain":"rexxapiai-rexxapi","runtime":{"stage":"RUNNING"}}'
  return .ApiResponse~new(request~id,200,.directory~new,body,1)
::requires 'HuggingFaceSpaceJob.cls'
