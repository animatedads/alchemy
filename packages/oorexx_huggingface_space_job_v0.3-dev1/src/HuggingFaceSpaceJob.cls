/* ooRexx Hugging Face Space Job v0.2
 *
 * Generic managed invocation of Gradio/Hugging Face Spaces through ApiClient.
 * No curl, no gradio_client, no implicit Git authority, and no write-token
 * propagation into the remote job workspace.
 */

::class HFSpaceJobBuild public
::constant VERSION "0.2"
::constant API "huggingface.space.job/0.3"

/* ---------- evidence ---------- */
::class HFSpaceEvidence public
::attribute events get
::method init
  expose events
  events=.array~new
::method add
  expose events
  use arg phase, code, detail=""
  d=detail~string
  /* Evidence must never contain bearer credentials. */
  if pos("Bearer ",d)>0 | pos("hf_",d)>0 then d="[REDACTED]"
  events~append(phase || "|" || code || "|" || d)
  return self
::method canonical
  expose events
  out=""
  do e over events
    if out<>"" then out=out || "0a"x
    out=out || e
  end
  return out

/* ---------- token-file credential ---------- */
::class HFTokenCredential public
::attribute tokenPath get
::method init
  expose tokenPath
  use arg pathArg
  tokenPath=pathArg~string~strip
  if tokenPath="" then raise syntax 88.900 array("tokenPath must not be empty")
::method validate
  expose tokenPath
  if stream(tokenPath,"C","QUERY EXISTS")="" then return "TOKEN_FILE_MISSING"
  rc=SysFileTree(tokenPath,"hfperm.","F")
  if rc<>0 | hfperm.0<>1 then return "TOKEN_MODE_UNREADABLE"
  mode=word(hfperm.1,4)
  if mode<>"-rw-------" then return "TOKEN_MODE_MISMATCH:" || mode
  return "OK"
::method readToken private
  expose tokenPath
  v=self~validate
  if v<>"OK" then raise syntax 88.900 array(v,tokenPath)
  s=.stream~new(tokenPath)
  if s~open("READ")<>"READY:" then raise syntax 88.900 array("TOKEN_FILE_OPEN_FAILED",tokenPath)
  token=s~lineIn~strip; s~close
  if token="" then raise syntax 88.900 array("TOKEN_EMPTY",tokenPath)
  if token~words<>1 then raise syntax 88.900 array("TOKEN_WHITESPACE_INVALID",tokenPath)
  return token
::method authorizationHeader
  return "Bearer " || self~readToken

/* ---------- target and endpoint contracts ---------- */
::class HFSpaceEndpoint public
::attribute name get
::attribute mode get
::method init
  expose name mode
  use arg nameArg, modeArg="AUTO"
  name=nameArg~string~strip
  if left(name,1)="/" then name=substr(name,2)
  mode=modeArg~string~strip~upper
  if name="" then raise syntax 88.900 array("Space API endpoint name required")
  allowed="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ."
  /* spaces are not valid endpoint path characters here */
  if pos(" ",name)>0 then raise syntax 88.900 array("invalid Space endpoint name",name)
  do i=1 to name~length
    if pos(name~substr(i,1),allowed)=0 then raise syntax 88.900 array("invalid Space endpoint name",name)
  end
  if mode<>"AUTO" & mode<>"V2_NAMED" & mode<>"V1_DATA" then raise syntax 88.900 array("endpoint mode must be AUTO, V2_NAMED or V1_DATA")

::class HFSpaceTarget public
::attribute repoId get
::attribute baseUrl get
::attribute routeRequirement get
::attribute cpuEndpoint get
::attribute largeEndpoint get
::attribute xlargeEndpoint get
::attribute controlParameter get
::attribute payloadParameter get
::method init
  expose repoId baseUrl routeRequirement cpuEndpoint largeEndpoint xlargeEndpoint controlParameter payloadParameter
  use arg repoArg, baseUrlArg="", routeArg=.nil, cpuArg=.nil, largeArg=.nil, xlargeArg=.nil, controlArg="_job", payloadArg=""
  repoId=repoArg~string~strip
  if \self~validRepoId(repoId) then raise syntax 88.900 array("repoId must be safe namespace/name",repoId)
  baseUrl=baseUrlArg~string~strip
  if baseUrl<>"" then do
    u=.ApiUrl~new(baseUrl)
    if u~scheme<>"https" then raise syntax 88.900 array("Space base URL must be HTTPS")
    if u~target<>"/" then raise syntax 88.900 array("Space base URL must not contain a path",baseUrl)
    if right(baseUrl,1)="/" then baseUrl=left(baseUrl,baseUrl~length-1)
  end
  if routeArg==.nil then routeRequirement=.ApiRouteRequirement~new; else routeRequirement=routeArg
  if cpuArg==.nil then cpuEndpoint=.HFSpaceEndpoint~new("job_cpu"); else cpuEndpoint=cpuArg
  if largeArg==.nil then largeEndpoint=.HFSpaceEndpoint~new("job_large"); else largeEndpoint=largeArg
  if xlargeArg==.nil then xlargeEndpoint=.HFSpaceEndpoint~new("job_xlarge"); else xlargeEndpoint=xlargeArg
  controlParameter=controlArg~string~strip
  payloadParameter=payloadArg~string~strip
  if payloadParameter<>"" then do
    if pos(" ",payloadParameter)>0 | pos("/",payloadParameter)>0 | pos("\",payloadParameter)>0 then raise syntax 88.900 array("invalid payload parameter",payloadParameter)
  end
::method validRepoId private
  use arg text
  if text="" | text~pos("/")<=1 | text~lastPos("/")<>text~pos("/") | right(text,1)="/" then return .false
  allowed="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_. /"
  if pos(" ",text)>0 then return .false
  do i=1 to text~length
    if pos(text~substr(i,1),allowed)=0 then return .false
  end
  return .true
::method endpointFor
  expose cpuEndpoint largeEndpoint xlargeEndpoint
  use arg requirement
  tier=requirement~tier
  if tier="CPU" then return cpuEndpoint
  if tier="ZEROGPU_LARGE" then return largeEndpoint
  if tier="ZEROGPU_XLARGE" then return xlargeEndpoint
  return .nil

/* ---------- ZeroGPU resource requirement + explicit quota policy ---------- */
::class HFSpaceJobRequirement public
::attribute accelerator get
::attribute minimumVramMiB get
::attribute expectedGpuSeconds get
::attribute allowPaidCredits get
::attribute networkEgress get
::attribute checkpointable get
::attribute tier get
::attribute quotaCostSeconds get
::method init
  expose accelerator minimumVramMiB expectedGpuSeconds allowPaidCredits networkEgress checkpointable tier quotaCostSeconds
  use arg accelArg="CPU", minVramArg=0, secondsArg=0, paidArg=.false, egressArg=.true, checkpointArg=.false
  accelerator=accelArg~string~strip~upper
  minimumVramMiB=minVramArg+0; expectedGpuSeconds=secondsArg+0
  allowPaidCredits=(paidArg==.true); networkEgress=(egressArg==.true); checkpointable=(checkpointArg==.true)
  if accelerator<>"CPU" & accelerator<>"GPU" then raise syntax 88.900 array("Space accelerator must be CPU or GPU")
  if minimumVramMiB<0 | expectedGpuSeconds<0 then raise syntax 88.900 array("resource values must not be negative")
  if accelerator="CPU" then do
    if minimumVramMiB<>0 | expectedGpuSeconds<>0 then raise syntax 88.900 array("CPU jobs cannot reserve GPU VRAM/time")
    tier="CPU"; quotaCostSeconds=0
  end
  else do
    if expectedGpuSeconds<=0 then raise syntax 88.900 array("GPU jobs require expectedGpuSeconds")
    if minimumVramMiB<=49152 then do; tier="ZEROGPU_LARGE"; quotaCostSeconds=expectedGpuSeconds; end
    else if minimumVramMiB<=98304 then do; tier="ZEROGPU_XLARGE"; quotaCostSeconds=expectedGpuSeconds*2; end
    else raise syntax 88.900 array("ZEROGPU_VRAM_INELIGIBLE",minimumVramMiB)
  end
::method canonical
  expose accelerator minimumVramMiB expectedGpuSeconds allowPaidCredits networkEgress checkpointable tier quotaCostSeconds
  return "accelerator=" || accelerator || ";tier=" || tier || ";minVramMiB=" || minimumVramMiB || ";gpuSeconds=" || expectedGpuSeconds || ";quotaCost=" || quotaCostSeconds || ";paid=" || allowPaidCredits || ";egress=" || networkEgress || ";checkpointable=" || checkpointable

::class HFZeroGpuQuotaReservation public
::attribute allowed get
::attribute code get
::attribute source get
::attribute costSeconds get
::attribute remainingIncludedSeconds get
::method init
  expose allowed code source costSeconds remainingIncludedSeconds
  use arg allowedArg,codeArg,sourceArg,costArg,remainingArg
  allowed=allowedArg; code=codeArg~string; source=sourceArg~string; costSeconds=costArg+0; remainingIncludedSeconds=remainingArg+0

::class HFZeroGpuQuotaBudget public
::attribute includedCapacitySeconds get
::attribute remainingIncludedSeconds get
::attribute paidCreditsEnabled get
::attribute observationRef get
::method init
  expose includedCapacitySeconds remainingIncludedSeconds paidCreditsEnabled observationRef
  use arg capacityArg=0, remainingArg=.nil, paidArg=.false, observationArg="UNCONFIGURED"
  includedCapacitySeconds=capacityArg+0
  if remainingArg==.nil then remainingIncludedSeconds=includedCapacitySeconds; else remainingIncludedSeconds=remainingArg+0
  paidCreditsEnabled=(paidArg==.true); observationRef=observationArg~string
  if includedCapacitySeconds<0 | remainingIncludedSeconds<0 then raise syntax 88.900 array("invalid ZeroGPU quota budget")
::method assess guarded
  expose remainingIncludedSeconds paidCreditsEnabled
  use arg requirement
  cost=requirement~quotaCostSeconds
  if cost=0 then return .HFZeroGpuQuotaReservation~new(.true,"OK","CPU",0,remainingIncludedSeconds)
  if cost<=remainingIncludedSeconds then return .HFZeroGpuQuotaReservation~new(.true,"OK","INCLUDED",cost,remainingIncludedSeconds)
  if paidCreditsEnabled & requirement~allowPaidCredits then return .HFZeroGpuQuotaReservation~new(.true,"OK","PAID_CREDITS",cost,remainingIncludedSeconds)
  return .HFZeroGpuQuotaReservation~new(.false,"ZEROGPU_INCLUDED_QUOTA_INSUFFICIENT","DENIED",cost,remainingIncludedSeconds)
::method reserve guarded
  expose remainingIncludedSeconds paidCreditsEnabled
  use arg requirement
  decision=self~assess(requirement)
  if \decision~allowed then return decision
  if decision~source="INCLUDED" then do
    remainingIncludedSeconds-=decision~costSeconds
    return .HFZeroGpuQuotaReservation~new(.true,"OK","INCLUDED",decision~costSeconds,remainingIncludedSeconds)
  end
  return .HFZeroGpuQuotaReservation~new(.true,"OK",decision~source,decision~costSeconds,remainingIncludedSeconds)
::method resetFromAuthority guarded
  expose remainingIncludedSeconds observationRef
  use arg remainingArg,refArg
  if remainingArg<0 then raise syntax 88.900 array("authoritative remaining quota must not be negative")
  remainingIncludedSeconds=remainingArg+0; observationRef=refArg~string
  return self

/* ---------- local file contract ---------- */
::class HFSpaceInputFile public
::attribute parameterName get
::attribute localPath get
::method init
  expose parameterName localPath
  use arg keyArg,pathArg
  parameterName=keyArg~string~strip; localPath=pathArg~string
  if parameterName="" | localPath="" then raise syntax 88.900 array("input parameter and local path required")

/* ---------- raw API adapter ---------- */
::class HFSpaceApiAdapter public
::attribute client get
::attribute credential get
::attribute target get
::attribute resolvedBaseUrl get
::attribute maxUploadBytes get
::method init
  expose client credential target sequence resolvedBaseUrl maxUploadBytes
  use arg clientArg, credentialArg, targetArg, maxUploadArg=268435456
  if clientArg==.nil | targetArg==.nil then raise syntax 88.900 array("ApiClient and HFSpaceTarget are required")
  client=clientArg; credential=credentialArg; target=targetArg; sequence=0; resolvedBaseUrl=target~baseUrl; maxUploadBytes=maxUploadArg+0
  if maxUploadBytes<1 then raise syntax 88.900 array("maxUploadBytes must be positive")
::method nextId private
  expose sequence
  use arg prefix
  sequence+=1
  return "HFSPACE-" || prefix || "-" || sequence
::method headers private
  expose credential
  use arg contentType=""
  h=.directory~new
  h["accept"]="application/json"
  if contentType<>"" then h["content-type"]=contentType
  if credential<>.nil then h["authorization"]=credential~authorizationHeader
  return h
::method request private
  expose client target
  use arg prefix,method,url,headers=.nil,body="",traffic="RESEARCH",expectedWlu=1000000
  if headers==.nil then headers=self~headers
  r=.ApiRequest~new(self~nextId(prefix),method,url,headers,body,traffic,50,expectedWlu,1000000,"",.nil,target~routeRequirement,"")
  return client~execute(r)
::method resolveBaseUrl
  expose target resolvedBaseUrl
  if resolvedBaseUrl<>"" then return resolvedBaseUrl
  h=self~headers
  resp=self~request("DISCOVER","GET","https://huggingface.co/api/spaces/" || target~repoId,h,"","CONTROL",100000)
  if \resp~ok then return ""
  signal on syntax name discoverBadJson
  doc=.json~fromJSON(resp~body)
  sdk=doc~at("sdk"); if sdk<>.nil then if sdk~string~lower<>"gradio" then return ""
  sub=doc~at("subdomain")
  if sub==.nil | sub~string="" then return ""
  sub=sub~string~strip~lower
  allowed="abcdefghijklmnopqrstuvwxyz0123456789-"
  do i=1 to sub~length
    if pos(sub~substr(i,1),allowed)=0 then return ""
  end
  resolvedBaseUrl="https://" || sub || ".hf.space"
  return resolvedBaseUrl
discoverBadJson:
  return ""
::method apiInfo
  base=self~resolveBaseUrl; if base="" then return .ApiResponse~new("",0,.nil,"",0,"SPACE_DISCOVERY_FAILED")
  return self~request("INFO","GET",base || "/gradio_api/info",self~headers,"","CONTROL",100000)
::method openApi
  base=self~resolveBaseUrl; if base="" then return .ApiResponse~new("",0,.nil,"",0,"SPACE_DISCOVERY_FAILED")
  return self~request("OPENAPI","GET",base || "/gradio_api/openapi.json",self~headers,"","CONTROL",100000)
::method agentsMarkdown
  expose target
  h=self~headers; h["accept"]="text/plain"
  return self~request("AGENTS","GET","https://huggingface.co/spaces/" || target~repoId || "/agents.md",h,"","CONTROL",100000)
::method upload
  expose maxUploadBytes
  use arg localPath
  base=self~resolveBaseUrl; if base="" then return .array~of(.false,"SPACE_DISCOVERY_FAILED","")
  if stream(localPath,"C","QUERY EXISTS")="" then return .array~of(.false,"UPLOAD_FILE_MISSING","")
  s=.stream~new(localPath); if s~open("READ")<>"READY:" then return .array~of(.false,"UPLOAD_FILE_OPEN_FAILED","")
  n=s~chars
  if n>maxUploadBytes then do; s~close; return .array~of(.false,"UPLOAD_TOO_LARGE:" || n,""); end
  data=s~charIn(,n); s~close
  filename=filespec("N",localPath)
  if filename="" then filename="upload.bin"
  boundary="----------------oorexxhf" || time("S") || random(100000,999999)
  crlf="0d0a"x
  body="--" || boundary || crlf || 'Content-Disposition: form-data; name="files"; filename="' || filename || '"' || crlf || "Content-Type: application/octet-stream" || crlf || crlf || data || crlf || "--" || boundary || "--" || crlf
  h=self~headers("multipart/form-data; boundary=" || boundary)
  h["accept"]="application/json"
  resp=self~request("UPLOAD","POST",base || "/gradio_api/upload",h,body,"SOURCE_BULK",data~length+1000)
  if \resp~ok then return .array~of(.false,"UPLOAD_FAILED:" || resp~status,"")
  signal on syntax name uploadBadJson
  doc=.json~fromJSON(resp~body)
  if \doc~isA(.array) | doc~items<1 then return .array~of(.false,"UPLOAD_RESPONSE_INVALID","")
  return .array~of(.true,"OK",doc[1]~string)
uploadBadJson:
  return .array~of(.false,"UPLOAD_RESPONSE_INVALID","")
::method submit
  use arg endpoint,payload
  base=self~resolveBaseUrl; if base="" then return .array~of(.false,"SPACE_DISCOVERY_FAILED","")
  if endpoint~mode="V1_DATA" then return self~submitV1(endpoint,payload)
  h=self~headers("application/json")
  path="/gradio_api/call/v2/" || endpoint~name
  body=.json~toJSON(payload)
  resp=self~request("SUBMIT","POST",base || path,h,body,"RESEARCH",1000000)
  if \resp~ok then do
    if endpoint~mode="AUTO" & (resp~status=404 | resp~status=405) then return self~submitV1(endpoint,payload)
    return .array~of(.false,"SUBMIT_FAILED:" || resp~status,"")
  end
  return self~eventIdFromResponse(resp)
::method submitV1 private
  use arg endpoint,payload
  base=self~resolveBaseUrl; if base="" then return .array~of(.false,"SPACE_DISCOVERY_FAILED","")
  infoResp=self~apiInfo
  if \infoResp~ok then return .array~of(.false,"V1_API_INFO_FAILED:" || infoResp~status,"")
  signal on syntax name submitV1BadInfo
  info=.json~fromJSON(infoResp~body)
  named=info~at("named_endpoints"); if named==.nil then signal submitV1BadInfo
  ep=named~at("/" || endpoint~name); if ep==.nil then ep=named~at(endpoint~name)
  if ep==.nil then return .array~of(.false,"V1_ENDPOINT_INFO_MISSING","")
  params=ep~at("parameters"); if params==.nil | \params~isA(.array) then signal submitV1BadInfo
  data=.array~new
  do p over params
    n=p~at("parameter_name"); if n==.nil then n=p~at("name")
    if n==.nil | n~string="" then signal submitV1BadInfo
    n=n~string
    if \payload~hasIndex(n) then return .array~of(.false,"V1_PARAMETER_MISSING:" || n,"")
    data~append(payload[n])
  end
  wrapper=.directory~new; wrapper["data"]=data
  h=self~headers("application/json")
  resp=self~request("SUBMITV1","POST",base || "/gradio_api/call/" || endpoint~name,h,.json~toJSON(wrapper),"RESEARCH",1000000)
  if \resp~ok then return .array~of(.false,"SUBMIT_FAILED:" || resp~status,"")
  return self~eventIdFromResponse(resp)
submitV1BadInfo:
  return .array~of(.false,"V1_API_INFO_INVALID","")
::method eventIdFromResponse private
  use arg resp
  signal on syntax name eventBadJson
  doc=.json~fromJSON(resp~body); eid=doc~at("event_id")
  if eid==.nil | eid~string="" then return .array~of(.false,"EVENT_ID_MISSING","")
  return .array~of(.true,"OK",eid~string)
eventBadJson:
  return .array~of(.false,"SUBMIT_RESPONSE_INVALID","")
::method poll
  use arg endpoint,eventId
  base=self~resolveBaseUrl; if base="" then return .array~of(.false,"SPACE_DISCOVERY_FAILED",.nil)
  h=self~headers; h["accept"]="text/event-stream"
  resp=self~request("POLL","GET",base || "/gradio_api/call/" || endpoint~name || "/" || eventId,h,"","RESEARCH",1000000)
  if \resp~ok then return .array~of(.false,"POLL_FAILED:" || resp~status,.nil)
  signal on syntax name pollBadSse
  events=.ApiSseParser~parse(resp~body)
  complete=.nil
  do e over events
    if e~event="error" then return .array~of(.false,"REMOTE_ERROR",e~data)
    if e~event="complete" then complete=e
  end
  if complete==.nil then return .array~of(.false,"COMPLETE_EVENT_MISSING",events)
  return .array~of(.true,"OK",complete~data)
pollBadSse:
  return .array~of(.false,"SSE_INVALID",.nil)
::method download
  expose resolvedBaseUrl
  use arg remoteUrl,localPath
  base=self~resolveBaseUrl; if base="" then return "SPACE_DISCOVERY_FAILED"
  signal on syntax name badDownloadUrl
  targetUrl=remoteUrl~string
  if left(targetUrl,1)="/" then targetUrl=base || targetUrl
  remote=.ApiUrl~new(targetUrl); allowed=.ApiUrl~new(base)
  signal off syntax
  if remote~scheme<>"https" | remote~host<>allowed~host | remote~port<>allowed~port then return "DOWNLOAD_HOST_NOT_ALLOWED"
  h=self~headers; h["accept"]="application/octet-stream"
  resp=self~request("DOWNLOAD","GET",targetUrl,h,"","SOURCE_BULK",1000000)
  if \resp~ok then return "DOWNLOAD_FAILED:" || resp~status
  s=.stream~new(localPath); if s~open("WRITE REPLACE")<>"READY:" then return "DOWNLOAD_FILE_OPEN_FAILED"
  ignored=s~charOut(resp~body); s~close
  return "OK"
badDownloadUrl:
  return "DOWNLOAD_URL_INVALID"

/* ---------- managed job ---------- */
::class HFSpaceJobSpec public
::attribute jobId get
::attribute requirement get
::attribute payload get
::attribute inputFiles get
::attribute outputDirectory get
::attribute requireCleanupEvidence get
::attribute operationId get
::method init
  expose jobId requirement payload inputFiles outputDirectory requireCleanupEvidence operationId
  use arg idArg,reqArg,payloadArg=.nil,inputArg=.nil,outputArg="",cleanupArg=.true,operationArg=""
  jobId=idArg~string~strip; requirement=reqArg
  if jobId="" | requirement==.nil then raise syntax 88.900 array("job id and requirement are mandatory")
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
  if inputArg==.nil then inputFiles=.array~new; else inputFiles=inputArg
  outputDirectory=outputArg~string
  requireCleanupEvidence=(cleanupArg==.true); operationId=operationArg~string~strip~upper
  if operationId="" then raise syntax 88.900 array("managed Space jobs require an explicit operationId")

::class HFArtifactReceipt public
::attribute name get
::attribute localPath get
::attribute sizeBytes get
::attribute sha256 get
::method init
  expose name localPath sizeBytes sha256
  use arg nameArg,pathArg,sizeArg,digestArg
  name=nameArg~string; localPath=pathArg~string; sizeBytes=sizeArg+0; sha256=digestArg~string~lower

::class HFSpaceJobResult public
::attribute success get
::attribute code get
::attribute jobId get
::attribute endpoint get
::attribute eventId get
::attribute quotaSource get
::attribute quotaCostSeconds get
::attribute completeData get
::attribute downloadedFiles get
::attribute evidence get
::attribute artifactReceipts get
::method init
  expose success code jobId endpoint eventId quotaSource quotaCostSeconds completeData downloadedFiles evidence artifactReceipts
  use arg okArg,codeArg,idArg,endpointArg="",eventArg="",quotaArg="",costArg=0,dataArg="",filesArg=.nil,evidenceArg=.nil,receiptsArg=.nil
  success=okArg; code=codeArg~string; jobId=idArg~string; endpoint=endpointArg~string; eventId=eventArg~string; quotaSource=quotaArg~string; quotaCostSeconds=costArg+0; completeData=dataArg
  if filesArg==.nil then downloadedFiles=.array~new; else downloadedFiles=filesArg
  if evidenceArg==.nil then evidence=.HFSpaceEvidence~new; else evidence=evidenceArg
  if receiptsArg==.nil then artifactReceipts=.array~new; else artifactReceipts=receiptsArg

::class HFSpaceJobRunner public
::attribute adapter get
::attribute quotaBudget get
::method init
  expose adapter quotaBudget
  use arg adapterArg,budgetArg=.nil
  if adapterArg==.nil then raise syntax 88.900 array("HFSpaceApiAdapter required")
  adapter=adapterArg
  if budgetArg==.nil then quotaBudget=.HFZeroGpuQuotaBudget~new; else quotaBudget=budgetArg
::method run
  expose adapter quotaBudget
  use arg spec
  ev=.HFSpaceEvidence~new
  /* Validate every local input before reserving quota or touching the network. */
  do inp over spec~inputFiles
    if stream(inp~localPath,"C","QUERY EXISTS")="" then return .HFSpaceJobResult~new(.false,"INPUT_FILE_MISSING",spec~jobId,"","","",0,"",.nil,ev~add("VALIDATE","INPUT_FILE_MISSING",inp~localPath))
  end
  if spec~outputDirectory<>"" then do
    rc=SysFileTree(spec~outputDirectory,"hfout.","D")
    if hfout.0=0 then do
      mk=SysMkDir(spec~outputDirectory)
      if mk<>0 then return .HFSpaceJobResult~new(.false,"OUTPUT_DIRECTORY_CREATE_FAILED",spec~jobId,"","","",0,"",.nil,ev~add("VALIDATE","OUTPUT_DIRECTORY_CREATE_FAILED",spec~outputDirectory))
    end
  end
  endpoint=adapter~target~endpointFor(spec~requirement)
  if endpoint==.nil then return .HFSpaceJobResult~new(.false,"NO_ELIGIBLE_SPACE_ENDPOINT",spec~jobId,"","","",0,"",.nil,ev~add("ELIGIBILITY","NO_ENDPOINT",spec~requirement~canonical))
  pp=adapter~target~payloadParameter; cp=adapter~target~controlParameter
  do inp over spec~inputFiles
    key=inp~parameterName
    if key=pp | key=cp then return .HFSpaceJobResult~new(.false,"INPUT_PARAMETER_COLLISION",spec~jobId,endpoint~name,"","",0,"",.nil,ev~add("VALIDATE","INPUT_PARAMETER_COLLISION",key))
  end
  preflight=quotaBudget~assess(spec~requirement)
  ev~add("QUOTA_CHECK",preflight~code,preflight~source || ":cost=" || preflight~costSeconds || ":remaining=" || preflight~remainingIncludedSeconds)
  if \preflight~allowed then return .HFSpaceJobResult~new(.false,preflight~code,spec~jobId,endpoint~name,"",preflight~source,preflight~costSeconds,"",.nil,ev)

  payload=.directory~new
  if pp="" then do k over spec~payload; payload[k]=spec~payload[k]; end
  else payload[pp]=spec~payload
  do inp over spec~inputFiles
    up=adapter~upload(inp~localPath); ev~add("UPLOAD",up[2],filespec("N",inp~localPath))
    if \up[1] then return .HFSpaceJobResult~new(.false,up[2],spec~jobId,endpoint~name,"",preflight~source,preflight~costSeconds,"",.nil,ev)
    f=.directory~new; f["path"]=up[3]; f["orig_name"]=filespec("N",inp~localPath)
    meta=.directory~new; meta["_type"]="gradio.FileData"; f["meta"]=meta
    payload[inp~parameterName]=f
  end
  reservation=quotaBudget~reserve(spec~requirement)
  ev~add("QUOTA_RESERVE",reservation~code,reservation~source || ":cost=" || reservation~costSeconds || ":remaining=" || reservation~remainingIncludedSeconds)
  if \reservation~allowed then return .HFSpaceJobResult~new(.false,reservation~code,spec~jobId,endpoint~name,"",reservation~source,reservation~costSeconds,"",.nil,ev)
  if cp<>"" then do
    control=.directory~new; control["job_id"]=spec~jobId; control["operation_id"]=spec~operationId; control["cleanup_remote"]=.json~true
    control["tier"]=spec~requirement~tier; control["expected_gpu_seconds"]=spec~requirement~expectedGpuSeconds
    if spec~requirement~checkpointable then control["checkpointable"]=.json~true; else control["checkpointable"]=.json~false
    payload[cp]=control
  end
  sub=adapter~submit(endpoint,payload); ev~add("SUBMIT",sub[2],endpoint~name)
  if \sub[1] then return .HFSpaceJobResult~new(.false,sub[2],spec~jobId,endpoint~name,"",reservation~source,reservation~costSeconds,"",.nil,ev)
  eventId=sub[3]
  pol=adapter~poll(endpoint,eventId); ev~add("POLL",pol[2],eventId)
  if \pol[1] then return .HFSpaceJobResult~new(.false,pol[2],spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,"",.nil,ev)
  raw=pol[3]
  signal on syntax name badCompleteJson
  doc=.json~fromJSON(raw)
  signal off syntax
  completeObj=self~unwrap(doc)
  if completeObj==.nil then return .HFSpaceJobResult~new(.false,"COMPLETE_RESULT_INVALID",spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,.nil,ev)
  status=completeObj~at("status")
  if status<>.nil then if status~string~upper<>"COMPLETED" then return .HFSpaceJobResult~new(.false,"REMOTE_STATUS_" || status~string~upper,spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,.nil,ev)
  cleanup=completeObj~at("cleanup")
  if spec~requireCleanupEvidence then do
    if cleanup==.nil | cleanup~string~upper<>"DONE" then return .HFSpaceJobResult~new(.false,"REMOTE_CLEANUP_UNCONFIRMED",spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,.nil,ev~add("CLEANUP","UNCONFIRMED",""))
    ev~add("CLEANUP","DONE","")
  end
  expectedName=""; expectedSha=""; expectedSize=-1
  x=completeObj~at("artifact_name"); if x<>.nil then expectedName=x~string
  x=completeObj~at("artifact_sha256"); if x<>.nil then expectedSha=x~string~lower
  x=completeObj~at("artifact_size"); if x<>.nil then expectedSize=x+0
  if expectedSha<>"" then do
    if expectedSha~length<>64 | verify(expectedSha,"0123456789abcdef")<>0 | expectedName="" | expectedSize<0 then return .HFSpaceJobResult~new(.false,"REMOTE_ARTIFACT_RECEIPT_INVALID",spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,.nil,ev~add("VERIFY","REMOTE_RECEIPT_INVALID",""))
  end
  downloaded=.array~new; receipts=.array~new
  arts=completeObj~at("artifacts")
  if arts<>.nil & arts~isA(.array) then do a over arts
    dl=self~downloadArtifact(a,spec,endpoint,eventId,reservation,raw,downloaded,receipts,ev,expectedName,expectedSize,expectedSha)
    if dl<>"OK" then return .HFSpaceJobResult~new(.false,dl,spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,downloaded,ev)
  end
  /* Gradio endpoints may return [result-json, FileData].  Treat any additional
   * FileData output as an artifact while keeping the first object authoritative
   * for status/cleanup evidence. */
  if doc~isA(.array) & doc~items>=2 then do i=2 to doc~items
    a=doc[i]
    if a~isA(.directory) then do
      meta=a~at("meta"); isFile=.false
      if meta<>.nil then if meta~isA(.directory) then do
        mt=meta~at("_type"); if mt<>.nil then if mt~string="gradio.FileData" then isFile=.true
      end
      if isFile then do
        dl=self~downloadArtifact(a,spec,endpoint,eventId,reservation,raw,downloaded,receipts,ev,expectedName,expectedSize,expectedSha)
        if dl<>"OK" then return .HFSpaceJobResult~new(.false,dl,spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,downloaded,ev,receipts)
      end
    end
  end
  if spec~outputDirectory<>"" & expectedSha<>"" & receipts~items=0 then return .HFSpaceJobResult~new(.false,"ARTIFACT_RECEIPT_NOT_MATERIALIZED",spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,downloaded,ev~add("VERIFY","ARTIFACT_RECEIPT_NOT_MATERIALIZED",expectedName),receipts)
  return .HFSpaceJobResult~new(.true,"COMPLETED",spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,downloaded,ev,receipts)
badCompleteJson:
  return .HFSpaceJobResult~new(.false,"COMPLETE_JSON_INVALID",spec~jobId,endpoint~name,eventId,reservation~source,reservation~costSeconds,raw,.nil,ev)
::method downloadArtifact private
  expose adapter
  use arg a,spec,endpoint,eventId,reservation,raw,downloaded,receipts,ev,expectedName,expectedSize,expectedSha
  name=a~at("name"); if name==.nil then name=a~at("orig_name")
  url=a~at("url")
  if url==.nil then do
    remotePath=a~at("path")
    if remotePath<>.nil then url="/gradio_api/file=" || remotePath~string
  end
  if name==.nil then do
    remotePath=a~at("path")
    if remotePath<>.nil then name=filespec("N",remotePath~string)
  end
  if name==.nil | url==.nil then return "ARTIFACT_REFERENCE_INVALID"
  localName=self~safeArtifactName(name~string)
  if localName="" then return "ARTIFACT_NAME_INVALID"
  if spec~outputDirectory="" then return "OK"
  localPath=spec~outputDirectory || "/" || localName
  dc=adapter~download(url~string,localPath); ev~add("DOWNLOAD",dc,localName)
  if dc<>"OK" then return dc
  downloaded~append(localPath)
  if expectedName<>"" & localName=expectedName then do
    if expectedSha="" | expectedSize<0 then return "REMOTE_ARTIFACT_RECEIPT_MISSING"
    actualSize=self~fileSize(localPath); actualSha=self~fileSha256(localPath)
    if actualSize<>expectedSize then do; ev~add("VERIFY","SIZE_MISMATCH",localName); return "ARTIFACT_SIZE_MISMATCH"; end
    if actualSha<>expectedSha then do; ev~add("VERIFY","SHA256_MISMATCH",localName); return "ARTIFACT_SHA256_MISMATCH"; end
    receipts~append(.HFArtifactReceipt~new(localName,localPath,actualSize,actualSha))
    ev~add("VERIFY","OK",localName || ":sha256=" || actualSha || ":bytes=" || actualSize)
  end
  return "OK"
::method fileSize private
  use arg path
  s=.stream~new(path); if s~open("READ")<>"READY:" then return -1
  n=s~chars; s~close; return n
::method fileSha256 private
  use arg path
  s=.stream~new(path); if s~open("READ")<>"READY:" then return ""
  h=.SHA256~new
  do while s~chars>0
    n=s~chars; if n>1048576 then n=1048576
    h~update(s~charIn(,n))
  end
  s~close
  return h~digest
::method unwrap private
  use arg doc
  if doc==.nil then return .nil
  if doc~isA(.directory) then return doc
  if doc~isA(.array) then do
    if doc~items>=1 then if doc[1]~isA(.directory) then return doc[1]
  end
  return .nil
::method safeArtifactName private
  use arg text
  n=text~string
  if n="" | n="." | n=".." | pos("/",n)>0 | pos("\\",n)>0 then return ""
  allowed="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
  do i=1 to n~length
    if pos(n~substr(i,1),allowed)=0 then return ""
  end
  return n

::requires "ApiClient.cls"
::requires "ApiHttpTransport.cls"
::requires "json.cls"

::requires "crypto.cls"
