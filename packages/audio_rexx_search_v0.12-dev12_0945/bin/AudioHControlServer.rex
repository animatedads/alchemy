/* AudioHControlServer.rex - HTTPS control endpoint for ed209h Strategy H. */
parse arg certificate privateKey port tokenFile spoolRoot audioRoot bindAddress bridgeDir fsyncHelper
if certificate='' | privateKey='' | tokenFile='' | spoolRoot='' | audioRoot='' | bridgeDir='' then do
  say 'usage: AudioHControlServer.rex CERT KEY PORT TOKEN_FILE SPOOL_ROOT AUDIO_ROOT BIND BRIDGE_DIR [FSYNC_HELPER]'
  exit 2
end
if port='' then port=9443
if bindAddress='' then bindAddress='0.0.0.0'
call makeDir spoolRoot
call makeDir spoolRoot'/pending'
call makeDir spoolRoot'/active'
call makeDir spoolRoot'/complete'
call makeDir spoolRoot'/failed'
token=readToken(tokenFile)
if token='' then do
  say 'FAIL: H API token file is empty'
  exit 3
end

app=.AudioHControlApplication~new(spoolRoot,audioRoot,fsyncHelper)
auth=.AudioHAuthorizationInterceptor~new(token)
config=.HttpsServerConfig~new
config~bindAddress=bindAddress
config~port=port+0
config~certificateFile=certificate
config~privateKeyFile=privateKey
config~bridgeDirectory=bridgeDir
config~maxBodyBytes=262144
config~maxHeaderBytes=32768
config~maxHeaderCount=64
config~maxRequestsPerConnection=1
/* One tiny control-plane worker serializes durable job/observation commits.  H's
 * DSP worker remains a separate process, so this does not serialize audio execution. */
config~connectionWorkers=1
config~maxPendingConnections=8
config~maxConnections=16
config~readTimeout=10
config~writeTimeout=10
config~accessLog=.true
server=.HttpsServer~new(config)
/* HTTPS owns transport.  Authorization is an application interceptor and
 * therefore remains separate from TLS evidence. */
server~interceptor(auth,'beforeRequest','afterResponse')
server~route('GET','/v1/health',app,'health')
server~route('POST','/v1/jobs',app,'submit')
server~route('GET','/v1/status',app,'status')
server~route('GET','/v1/capabilities',app,'capabilities')
server~route('POST','/v1/observations',app,'observe')
server~route('GET','/v1/observations',app,'observations')
server~route('GET','/v1/streams',app,'streams')
say 'AUDIO_H_CONTROL_READY node=ed209h port='port 'spool='spoolRoot 'audio_root='audioRoot
server~serve
exit 0

::class AudioHAuthorizationInterceptor
::method init
  expose token
  use strict arg tokenArg
  token=tokenArg
::method beforeRequest
  expose token
  use strict arg request,context
  supplied=request~header('authorization','')
  if supplied<>('Bearer '||token) then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"UNAUTHORIZED"}',401)
  context~put('principal','audio-controller')
  context~put('authenticated',.true)
  return .nil
::method afterResponse
  use strict arg request,response,context
  response~header('Cache-Control','no-store')
  response~header('X-Audio-Control-Schema','audio.h.control/2')
  response~header('X-Audio-Request-Id',context~requestId)
  return response

::class AudioHControlApplication
::method init
  expose spoolRoot audioRoot fsyncHelper conversationHub
  use strict arg spoolArg,audioArg,fsyncArg=''
  spoolRoot=spoolArg; audioRoot=audioArg; fsyncHelper=fsyncArg
  conversationHub=.AudioPoolConversationHub~new(spoolRoot'/conversation',fsyncHelper)
::method health
  expose audioRoot
  use strict arg request
  body='{"schema":"audio.h.control.health/2","ok":true,"node":"ed209h","strategy":"H","transport":"ooRexx HTTPS Server v0.4.4","authorization":"https-interceptor","audio_root":'||jsonString(audioRoot)||'}'
  return .HttpResponse~json(body,200)
::method capabilities
  use strict arg request
  body='{"schema":"audio.h.control.capabilities/2","node":"ed209h","roles":["HTTPS_INGRESS","OBSERVATION_HUB","VOICE_FRONTIER_REFINEMENT"],"accepts":["audio.h.refinement.control/2","audio.pool.observation/1"],"execution":"serial-durable-spool","observation":{"api":"observation.readonly/0.5","authority":"evidence-only","replay":true},"temporal_pursuit":{"radius_sec":180,"window_sec":180,"step_sec":90,"overlap_sec":90},"additive_voice_mix":{"enabled":true,"schema":"audio.h.additive.voice-mix/1","pool_depth":24,"selection":"rank-1-plus-quietest-top24-residual","minimum_attenuation_db":0,"gains":[1,1],"final_limiter":"sample-local-.88-.98-no-normalization"},"max_parent_count":20,"max_reject_bands":6}'
  return .HttpResponse~json(body,200)
::method observe
  expose conversationHub
  use strict arg request
  ctype=request~header('content-type','')~lower
  if ctype~pos('application/x-oorexx-audio-observation-v1')<>1 then return .HttpResponse~json('{"schema":"audio.pool.observation.response/1","ok":false,"code":"UNSUPPORTED_CONTENT_TYPE"}',400)
  r=conversationHub~publish(request~body)
  if r['ok'] then do
    body='{"schema":"audio.pool.observation.response/1","ok":true,"accepted":true,"idempotent":'||jsonBool(r['idempotent'])||',"message_id":'||jsonString(r['message_id'])||',"node_id":'||jsonString(r['node_id'])||',"stream_id":'||jsonString(r['stream_id'])||',"sequence":'||r['sequence']||'}'
    return .HttpResponse~json(body,202)
  end
  statusCode=400
  if r['code']='MESSAGE_ID_CONFLICT' then statusCode=409
  return .HttpResponse~json('{"schema":"audio.pool.observation.response/1","ok":false,"code":'||jsonString(r['code'])||'}',statusCode)
::method observations
  expose conversationHub
  use strict arg request
  nodeId=queryValue(request~query,'node_id')
  afterText=queryValue(request~query,'after')
  maxText=queryValue(request~query,'max')
  if afterText='' then afterText='0'
  if maxText='' then maxText='50'
  if \datatype(afterText,'W') | \datatype(maxText,'W') then return .HttpResponse~json('{"schema":"audio.pool.observation.replay/1","ok":false,"code":"INVALID_REPLAY_RANGE"}',400)
  rr=conversationHub~replay(nodeId,afterText+0,maxText+0,'audio-bigger-monkey')
  if \rr['ok'] then return .HttpResponse~json('{"schema":"audio.pool.observation.replay/1","ok":false,"code":'||jsonString(rr['code'])||'}',404)
  rows='['
  first=.true
  do rec over rr['records']
    if \first then rows=rows||','
    first=.false
    rows=rows||'{"sequence":'||rec['sequence']||',"record_kind":'||jsonString(rec['record_kind'])||',"kind":'||jsonString(rec['kind'])||',"body":'||jsonString(rec['body'])||'}'
  end
  rows=rows||']'
  body='{"schema":"audio.pool.observation.replay/1","ok":true,"node_id":'||jsonString(nodeId)||',"records":'||rows||'}'
  return .HttpResponse~json(body,200)
::method streams
  expose conversationHub
  use strict arg request
  nodes='['; first=.true
  do nodeId over conversationHub~nodes
    if \first then nodes=nodes||','
    first=.false
    nodes=nodes||jsonString(nodeId)
  end
  nodes=nodes||']'
  return .HttpResponse~json('{"schema":"audio.pool.streams/1","ok":true,"nodes":'||nodes||'}',200)
::method submit
  expose spoolRoot fsyncHelper
  use strict arg request
  ctype=request~header('content-type','')~lower
  if ctype~pos('application/x-oorexx-audio-h-job-v1')<>1 then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"UNSUPPORTED_CONTENT_TYPE"}',400)
  body=request~body
  if body='' | body~length>262144 then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"INVALID_BODY_SIZE"}',400)
  parsed=validateJob(body)
  if \parsed['ok'] then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":'||jsonString(parsed['code'])||'}',400)
  jobId=parsed['job_id']
  pending=spoolRoot'/pending/'jobId'.job'; active=spoolRoot'/active/'jobId'.job'; complete=spoolRoot'/complete/'jobId'.job'; failed=spoolRoot'/failed/'jobId'.job'
  do path over .array~of(pending,active,complete,failed)
    if fileExists(path) then do
      old=readWhole(path)
      if old=body then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":true,"accepted":true,"idempotent":true,"job_id":'||jsonString(jobId)||'}',202)
      return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"JOB_ID_CONFLICT","job_id":'||jsonString(jobId)||'}',409)
    end
  end
  temp=spoolRoot'/pending/.'jobId'.tmp.'||.dateTime~new~microseconds
  call writeWhole temp,body
  address system 'chmod 600 -- 'shellQuote(temp)
  if rc<>0 then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"SPOOL_CHMOD_FAILED"}',500)
  address system 'mv -f -- 'shellQuote(temp)' 'shellQuote(pending)
  if rc<>0 then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"SPOOL_COMMIT_FAILED"}',500)
  if fsyncHelper<>'' then do
    address system shellQuote(fsyncHelper)' 'shellQuote(pending)
    if rc<>0 then return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":false,"code":"SPOOL_FSYNC_FAILED"}',500)
  end
  return .HttpResponse~json('{"schema":"audio.h.control.response/2","ok":true,"accepted":true,"idempotent":false,"job_id":'||jsonString(jobId)||'}',202)
::method status
  expose spoolRoot
  use strict arg request
  id=queryValue(request~query,'job_id')
  if \trustedId(id) then return .HttpResponse~json('{"schema":"audio.h.control.status/2","ok":false,"code":"INVALID_JOB_ID"}',400)
  state='UNKNOWN'; detail=''; resultRef=''
  if fileExists(spoolRoot'/pending/'id'.job') then state='PENDING'
  else if fileExists(spoolRoot'/active/'id'.job') then state='RUNNING'
  else if fileExists(spoolRoot'/complete/'id'.job') then do
    state='COMPLETE'; result=spoolRoot'/complete/'id'.result'
    if fileExists(result) then resultRef=readWhole(result)~strip
  end
  else if fileExists(spoolRoot'/failed/'id'.job') then do
    state='FAILED'; reason=spoolRoot'/failed/'id'.reason'
    if fileExists(reason) then detail=readWhole(reason)~strip
  end
  return .HttpResponse~json('{"schema":"audio.h.control.status/2","ok":true,"job_id":'||jsonString(id)||',"state":'||jsonString(state)||',"detail":'||jsonString(detail)||',"result_ref":'||jsonString(resultRef)||'}',200)

::routine validateJob
  use strict arg body
  d=.directory~new; d['ok']=.false; d['code']='INVALID_JOB'
  text=body~changeStr('0d0a'x,'0a'x)~changeStr('0d'x,'0a'x)
  lines=text~makeArray('0a'x); kv=.directory~new
  do i=1 to lines~items
    line=lines[i]~strip
    if line='' then iterate
    p=line~pos('=')
    if p<=1 then do; d['code']='MALFORMED_LINE'; return d; end
    key=line~left(p-1)~strip; value=line~substr(p+1)~strip
    if \trustedKey(key) then do; d['code']='INVALID_KEY'; return d; end
    if kv~hasIndex(key) then do; d['code']='DUPLICATE_KEY'; return d; end
    kv[key]=value
  end
  schema=getv(kv,'schema','')
  if schema<>'audio.h.refinement.control/2' then do; d['code']='SCHEMA_MISMATCH'; return d; end
  id=getv(kv,'job_id','')
  if \trustedId(id) then do; d['code']='INVALID_JOB_ID'; return d; end
  do k over .array~of('source_recording','companion_recording')
    if \safeBasename(getv(kv,k,'')) then do; d['code']='INVALID_RECORDING_NAME'; return d; end
  end
  pc=getv(kv,'parent_count','')
  if \datatype(pc,'W') | pc<1 | pc>20 then do; d['code']='INVALID_PARENT_COUNT'; return d; end
  do k over .array~of('source_start_sec','companion_start_sec','companion_duration_sec','temporal_radius_sec','window_duration_sec','window_step_sec','window_overlap_sec','shortlist_count','workspace_budget_gib')
    v=getv(kv,k,'')
    if \datatype(v,'W') then do; d['code']='INVALID_NUMERIC_FIELD'; return d; end
  end
  radius=getv(kv,'temporal_radius_sec',0)+0; win=getv(kv,'window_duration_sec',0)+0; step=getv(kv,'window_step_sec',0)+0; overlap=getv(kv,'window_overlap_sec',0)+0
  shortlist=getv(kv,'shortlist_count',0)+0; workspace=getv(kv,'workspace_budget_gib',0)+0; companionDuration=getv(kv,'companion_duration_sec',0)+0
  /* H is intentionally bounded by node-local capability.  Per-job policy may
   * choose less work, but an authenticated instruction cannot enlarge H beyond
   * its qualified 10 GiB / 64-output / +/-3-minute envelope. */
  if radius>180 | win<30 | win>180 | step<10 | step>win | overlap<0 | overlap>=win | (win-step)<>overlap then do; d['code']='INVALID_WINDOW_POLICY'; return d; end
  if shortlist<1 | shortlist>64 then do; d['code']='INVALID_SHORTLIST'; return d; end
  if workspace<1 | workspace>10 then do; d['code']='INVALID_WORKSPACE_BUDGET'; return d; end
  if companionDuration<30 | companionDuration>300 then do; d['code']='INVALID_COMPANION_DURATION'; return d; end
  do n=1 to pc
    prefix='parent.'n'.'
    do k over .array~of('node','rank','candidate_id','score','gain_db','highpass_hz','lowpass_hz','denoise_floor_db','echo_delay_ms','echo_gain','cancel_strength','cancel_tweak_ms','compress','compress_ratio','compress_threshold_db','reject_bands')
      if \kv~hasIndex(prefix||k) then do; d['code']='INCOMPLETE_PARENT'; return d; end
    end
    if \trustedId(getv(kv,prefix||'node','')) then do; d['code']='INVALID_PARENT_NODE'; return d; end
    rank=getv(kv,prefix||'rank','')
    if \datatype(rank,'W') | rank<1 | rank>9999 then do; d['code']='INVALID_PARENT_RANK'; return d; end
    cid=getv(kv,prefix||'candidate_id','')
    if cid='' | cid~length>256 then do; d['code']='INVALID_PARENT_ID'; return d; end
    bands=getv(kv,prefix||'reject_bands','')
    if \validRejectBands(bands) then do; d['code']='INVALID_REJECT_BANDS'; return d; end
  end
  d['ok']=.true; d['code']=''; d['job_id']=id
  return d


::routine validRejectBands
  use strict arg text
  if text='' then return .true
  count=0
  do token over text~makeArray(';')
    token=token~strip
    if token='' then return .false
    parse var token lo '-' hi
    lo=lo~strip; hi=hi~strip
    if lo='' | hi='' | lo~pos(' ')>0 | hi~pos(' ')>0 then return .false
    if \datatype(lo,'N') | \datatype(hi,'N') then return .false
    lo=lo+0; hi=hi+0
    if lo<0 | hi<=lo | hi>8000 then return .false
    count=count+1
    if count>6 then return .false
  end
  return count>0

::routine getv
  use strict arg d,k,default
  if d~hasIndex(k) then return d[k]
  return default
::routine trustedKey
  use strict arg x
  if x='' | x~length>80 then return .false
  allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'
  do i=1 to x~length
    if allowed~pos(x~substr(i,1))=0 then return .false
  end
  return .true
::routine trustedId
  use strict arg x
  return trustedKey(x)
::routine safeBasename
  use strict arg x
  if x='' | x~length>255 | x~pos('/')>0 | x~pos('\\')>0 | x~pos('..')>0 then return .false
  return .true
::routine queryValue
  use strict arg query,wanted
  rest=query
  do while rest<>''
    p=rest~pos('&')
    if p=0 then do; item=rest; rest=''; end
    else do; item=rest~left(p-1); rest=rest~substr(p+1); end
    e=item~pos('=')
    if e=0 then do; k=item; v=''; end
    else do; k=item~left(e-1); v=item~substr(e+1); end
    if k=wanted then return v
  end
  return ''
::routine fileExists
  use strict arg path
  return stream(path,'c','query exists')<>''
::routine readToken
  use strict arg path
  s=.stream~new(path); s~open('read')
  if s~state<>'READY' then return ''
  t=s~linein~strip; s~close
  return t
::routine readWhole
  use strict arg path
  s=.stream~new(path); s~open('read')
  if s~state<>'READY' then return ''
  out=''
  do while s~lines>0
    if out<>'' then out=out||'0a'x
    out=out||s~linein
  end
  s~close
  if out<>'' then out=out||'0a'x
  return out
::routine writeWhole
  use strict arg path,text
  s=.stream~new(path); s~open('write replace'); s~charout(text); s~close
  return
::routine makeDir
  use strict arg path
  address system 'mkdir -p -- 'shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot create directory',path)
  return
::routine shellQuote
  use strict arg v
  return "'"||v~changeStr("'","'\\''")||"'"
::routine jsonString
  use strict arg x
  t=x~string~changeStr('\\','\\\\')~changeStr('"','\\"')~changeStr('0a'x,'\\n')~changeStr('0d'x,'\\r')
  return '"'||t||'"'
::routine jsonBool
  use strict arg x
  if x==.true | x=1 | x='1' then return 'true'
  return 'false'

::requires 'AudioPoolConversation.cls'
::requires 'https_server.cls'
