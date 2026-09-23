/* AudioHApiFeeder.rex - governed ooRexx API Client v0.3 control-plane feeder for ed209h. */
parse arg mode baseUrl caFile tokenFile payload bridgeDir
mode=mode~strip~lower
if mode='' | baseUrl='' | caFile='' | tokenFile='' | bridgeDir='' then do
  say 'usage: AudioHApiFeeder.rex health|submit|status|observe|replay|streams BASE_URL CA_FILE TOKEN_FILE PAYLOAD BRIDGE_DIR'
  say '       submit PAYLOAD=job envelope file; status PAYLOAD=job id'
  say '       observe PAYLOAD=observation envelope file; replay PAYLOAD=node[:after[:max]]; health/streams PAYLOAD=-'
  exit 2
end
if mode<>'health' & mode<>'submit' & mode<>'status' & mode<>'observe' & mode<>'replay' & mode<>'streams' then do
  say 'FAIL unsupported feeder mode' mode
  exit 2
end
if baseUrl~right(1)='/' then baseUrl=baseUrl~left(baseUrl~length-1)
token=readToken(tokenFile)
if token='' then do
  say 'FAIL empty H API token'
  exit 3
end

cfg=.ApiHttpTransportConfig~new
cfg~bridgeDirectory=bridgeDir
cfg~caFile=caFile
cfg~verifyPeer=.true
cfg~readTimeout=15
cfg~writeTimeout=15
cfg~maxHeaderBytes=32768
cfg~maxBodyBytes=1048576
transport=.ApiHttpsTransport~new(cfg)

/* API Client owns route/session/admission/transport.  The feeder advertises the
 * controller's qualified public HTTPS egress capability and requests it as a
 * hard route requirement rather than opening a transport directly. */
registry=.ApiEgressRegistry~new
countries=.array~new
networks=.array~of('PUBLIC')
classes=.array~of('HTTPS')
tags=.array~of('AUDIO_CONTROL')
egress=.ApiEgressNode~new('AUDIO-CONTROL-EGRESS',countries,.array~new,networks,classes,tags,4,1,'audio-h-feeder-local-egress')
registry~advertise(egress)
sessions=.ApiSessionManager~new(registry,'AUDIO-CONTROL-EGRESS')
client=.ApiClient~new(transport,.nil,.nil,.nil,sessions)

headers=.directory~new
headers['authorization']='Bearer '||token
headers['accept']='application/json'
route=.ApiRouteRequirement~new('','','PUBLIC','HTTPS',.array~of('AUDIO_CONTROL'))
metadata=.directory~new
metadata['purpose']='ed209h-control'
metadata['target_node']='ed209h'
body=''; method='GET'; url=''
select
  when mode='health' then url=baseUrl||'/v1/health'
  when mode='streams' then url=baseUrl||'/v1/streams'
  when mode='status' then do
    if \trustedId(payload) then do
      say 'FAIL invalid job id'
      exit 2
    end
    metadata['job_id']=payload
    url=baseUrl||'/v1/status?job_id='||payload
  end
  when mode='replay' then do
    parse var payload nodeId ':' after ':' maxItems
    if \trustedNode(nodeId) then do
      say 'FAIL invalid replay node id'
      exit 2
    end
    if after='' then after='0'
    if maxItems='' then maxItems='50'
    if \datatype(after,'W') | \datatype(maxItems,'W') then do
      say 'FAIL invalid replay range'
      exit 2
    end
    metadata['node_id']=nodeId
    url=baseUrl||'/v1/observations?node_id='||nodeId||'&after='||after||'&max='||maxItems
  end
  when mode='submit' then do
    body=readWhole(payload)
    if body='' then do
      say 'FAIL empty H job envelope'
      exit 3
    end
    method='POST'
    url=baseUrl||'/v1/jobs'
    headers['content-type']='application/x-oorexx-audio-h-job-v1; charset=utf-8'
    metadata['envelope_path']=payload
  end
  when mode='observe' then do
    body=readWhole(payload)
    if body='' then do
      say 'FAIL empty observation envelope'
      exit 3
    end
    method='POST'
    url=baseUrl||'/v1/observations'
    headers['content-type']='application/x-oorexx-audio-observation-v1; charset=utf-8'
    metadata['envelope_path']=payload
  end
end

id='HFEED-'||mode~upper||'-'||.dateTime~new~microseconds
request=.ApiRequest~new(id,method,url,headers,body,'CONTROL',100,250000,250000,'',metadata,route,'audio-controller')
/* Use the scheduler seam even for a one-item feeder invocation. */
queued=client~submit(request)
if queued<>id | client~pendingCount<>1 then do
  transport~close
  say 'FAIL H FEED scheduler did not retain request'
  exit 4
end
response=client~executeNext
metrics=client~metrics
transport~close
if response==.nil then do
  say 'FAIL H FEED no response'
  exit 5
end
if response~errorCode<>'' then do
  say 'FAIL H FEED transport='response~errorCode
  detail=response~headers~at('x-oorexx-transport-detail')
  if detail<>.nil then say detail
  exit 5
end
if response~body<>'' then say response~body
if \response~ok then do
  say 'FAIL H FEED http_status='response~status
  exit 6
end
say 'PASS H FEED mode='mode 'status='response~status 'elapsed_ms='response~elapsedMs 'session='response~sessionId 'pending='metrics['pending']
exit 0

readToken: procedure
  use strict arg path
  s=.stream~new(path); s~open('read')
  if s~state<>'READY' then return ''
  t=s~linein~strip; s~close
  return t

readWhole: procedure
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

trustedId: procedure
  use strict arg id
  if id='' | id~length>80 then return .false
  allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'
  do i=1 to id~length
    if allowed~pos(id~substr(i,1))=0 then return .false
  end
  return .true

trustedNode: procedure
  use strict arg id
  id=id~lower
  return .array~of('ed209a','ed209b','ed209c','ed209d','ed209e','ed209i','ed209f','ed209g','ed209h','controller','reviewer')~hasItem(id)

::requires 'ApiHttpTransport.cls'
