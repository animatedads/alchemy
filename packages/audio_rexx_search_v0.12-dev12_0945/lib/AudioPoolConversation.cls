/* AudioPoolConversation.cls - durable Observation-v0.5-backed worker conversation hub. */

::class AudioPoolConversationSnapshot public
::attribute generation get
::attribute terminalType get
::attribute visibleText get
::attribute contentDigest get
::method init
  expose generation terminalType visibleText contentDigest
  use strict arg generationArg, textArg, digestArg
  generation=generationArg+0
  terminalType='AUDIO_WORKER_CHAT'
  visibleText=textArg~string
  contentDigest=digestArg~string
::method copyDetached
  expose generation visibleText contentDigest
  return .AudioPoolConversationSnapshot~new(generation,visibleText,contentDigest)

::class AudioPoolConversationObserver public
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init
  expose nodeId sessionId terminalType deviceName generation snapshots currentSnapshot
  use strict arg nodeArg
  nodeId=nodeArg~string
  sessionId='AUDIO-POOL-'||nodeId
  terminalType='AUDIO_WORKER_CHAT'
  deviceName=nodeId
  generation=0
  snapshots=.array~new
  currentSnapshot=.nil
::method accept
  expose generation snapshots currentSnapshot
  use strict arg messageId, body
  generation+=1
  currentSnapshot=.AudioPoolConversationSnapshot~new(generation,body,messageId)
  snapshots~append(currentSnapshot)
  return currentSnapshot~copyDetached
::method snapshot
  expose currentSnapshot
  if currentSnapshot==.nil then return .nil
  return currentSnapshot~copyDetached
::method current
  return self~snapshot
::method back
  expose snapshots
  use arg distance=1
  d=distance+0
  if d<1 then d=1
  idx=snapshots~items-d
  if idx<1 then return .nil
  return snapshots[idx]~copyDetached
::method history
  expose snapshots
  out=.array~new
  do s over snapshots; out~append(s~copyDetached); end
  return out
::method knownStateStatus
  expose currentSnapshot
  if currentSnapshot==.nil then return 'EMPTY'
  return 'CURRENT'
::method knownStateId
  expose currentSnapshot
  if currentSnapshot==.nil then return ''
  return currentSnapshot~contentDigest
::method knownStateGeneration
  expose generation
  return generation
::method knownStateHistory
  return self~history

::class AudioPoolConversationHub public
::method init
  expose root fsyncHelper service observers streams producerIds messageIndex restoring
  use strict arg rootArg, fsyncArg=''
  root=rootArg~string
  fsyncHelper=fsyncArg~string
  observers=.directory~new
  streams=.directory~new
  producerIds=.directory~new
  messageIndex=.directory~new
  service=.ObservationQueueService~new(.nil,'','audio-pool')
  restoring=.false
  call conversationMakeDir root
  call conversationMakeDir root'/messages'
  call conversationMakeDir root'/ids'
  self~restore
::method ensureNode private
  expose observers streams producerIds service
  use strict arg nodeId
  n=nodeId~string
  if observers~hasIndex(n) then return streams[n]
  observer=.AudioPoolConversationObserver~new(n)
  producerId='AUDIO-PRODUCER-'||n
  streamId='audio.pool.'||n
  producer=.ObservationProducerRegistration~new(producerId,n,'',0)
  pr=service~registerProducer(producer)
  if \pr~ok then raise syntax 88.910 array('cannot register observation producer',n,pr~code)
  stream=.ObservationStream~new(streamId,observer,4096)
  sr=service~registerStream(producerId,stream,n)
  if \sr~ok then raise syntax 88.911 array('cannot register observation stream',n,sr~code)
  observers[n]=observer
  streams[n]=stream
  producerIds[n]=producerId
  return stream
::method publish
  expose root fsyncHelper service observers streams producerIds messageIndex restoring
  use strict arg body
  parsed=conversationParseObservation(body)
  if \parsed['ok'] then return conversationResult(.false,parsed['code'])
  messageId=parsed['message_id']; nodeId=parsed['node_id']; kind=parsed['kind']
  if messageIndex~hasIndex(messageId) then do
    known=messageIndex[messageId]
    knownPath=known['path']
    if conversationFileExists(knownPath) then do
      old=conversationReadWhole(knownPath)
      if old=body then do
        out=conversationResult(.true,'OK')
        out['idempotent']=.true; out['message_id']=messageId; out['node_id']=nodeId; out['stream_id']=known['stream_id']; out['sequence']=known['sequence']
        return out
      end
    end
    return conversationResult(.false,'MESSAGE_ID_CONFLICT')
  end
  stream=self~ensureNode(nodeId)
  observers[nodeId]~accept(messageId,body)
  published=service~publishLatest(producerIds[nodeId],stream~streamId)
  if \published~ok then return conversationResult(.false,published~code)
  rec=published~value
  seq=rec~sequence
  dir=root'/messages/'nodeId
  call conversationMakeDir dir
  seqText=right(seq,12,'0')
  final=dir'/'seqText'-'messageId'.obs'
  temp=dir'/.'seqText'-'messageId'.tmp.'||.dateTime~new~microseconds
  call conversationWriteWhole temp,body
  address system 'chmod 600 -- 'conversationShellQuote(temp)
  if rc<>0 then return conversationResult(.false,'OBSERVATION_CHMOD_FAILED')
  address system 'mv -f -- 'conversationShellQuote(temp)' 'conversationShellQuote(final)
  if rc<>0 then return conversationResult(.false,'OBSERVATION_COMMIT_FAILED')
  meta=root'/ids/'messageId'.id'
  metaTemp=root'/ids/.'messageId'.tmp.'||.dateTime~new~microseconds
  metaBody='node_id='||nodeId||'0a'x||'stream_id='||stream~streamId||'0a'x||'sequence='||seq||'0a'x||'path='||final||'0a'x
  call conversationWriteWhole metaTemp,metaBody
  address system 'chmod 600 -- 'conversationShellQuote(metaTemp)
  if rc<>0 then return conversationResult(.false,'OBSERVATION_INDEX_CHMOD_FAILED')
  address system 'mv -f -- 'conversationShellQuote(metaTemp)' 'conversationShellQuote(meta)
  if rc<>0 then return conversationResult(.false,'OBSERVATION_INDEX_COMMIT_FAILED')
  if fsyncHelper<>'' & \restoring then do
    address system conversationShellQuote(fsyncHelper)' 'conversationShellQuote(final)' 'conversationShellQuote(meta)
    if rc<>0 then return conversationResult(.false,'OBSERVATION_FSYNC_FAILED')
  end
  entry=.directory~new; entry['path']=final; entry['stream_id']=stream~streamId; entry['sequence']=seq; entry['node_id']=nodeId
  messageIndex[messageId]=entry
  out=conversationResult(.true,'OK')
  out['idempotent']=.false; out['message_id']=messageId; out['node_id']=nodeId; out['stream_id']=stream~streamId; out['sequence']=seq
  return out
::method replay
  expose service streams
  use strict arg nodeId, afterSequence=0, maxItems=50, consumerId='audio-bigger-monkey'
  n=nodeId~string
  out=conversationResult(.true,'OK')
  out['node_id']=n; out['records']=.array~new
  if \streams~hasIndex(n) then do
    out['ok']=.false; out['code']='STREAM_NOT_FOUND'; return out
  end
  m=maxItems+0; if m<1 then m=1; if m>200 then m=200
  req=.ObservationReplayRequest~new('REPLAY-'||.dateTime~new~microseconds,consumerId,streams[n]~streamId,afterSequence,m)
  rr=service~replay(req)
  if \rr~ok then do; out['ok']=.false; out['code']=rr~code; return out; end
  do rec over rr~value
    row=.directory~new
    row['sequence']=rec~sequence
    row['record_kind']=rec~kind
    row['body']=rec~envelope~snapshot~visibleText
    parsed=conversationParseObservation(row['body'])
    if parsed['ok'] then row['kind']=parsed['kind']; else row['kind']=rec~kind
    out['records']~append(row)
  end
  return out
::method nodes
  expose streams
  out=.array~new
  do nodeId over streams; out~append(nodeId); end
  out~sort
  return out
::method restore private
  expose root restoring messageIndex
  restoring=.true
  files=.array~new
  call SysFileTree root'/messages/*.obs','tree.','FSO'
  do i=1 to tree.0; files~append(tree.i); end
  if files~items>1 then files~sort
  do path over files
    body=conversationReadWhole(path)
    parsed=conversationParseObservation(body)
    if \parsed['ok'] then iterate
    r=self~publish(body)
    if \r['ok'] then iterate
    /* A stale sidecar may have been loaded into messageIndex first in a future
       revision.  Current restore reconstructs solely from authoritative .obs files. */
  end
  restoring=.false
  return

::routine conversationParseObservation
  use strict arg body
  d=.directory~new; d['ok']=.false; d['code']='INVALID_OBSERVATION'
  if body='' | body~length>65536 then do; d['code']='INVALID_BODY_SIZE'; return d; end
  text=body~changeStr('0d0a'x,'0a'x)~changeStr('0d'x,'0a'x)
  lines=text~makeArray('0a'x); kv=.directory~new
  do i=1 to lines~items
    line=lines[i]
    if line='' then iterate
    p=line~pos('=')
    if p<=1 then do; d['code']='MALFORMED_LINE'; return d; end
    key=line~left(p-1)~strip; value=line~substr(p+1)
    if \conversationTrustedKey(key) then do; d['code']='INVALID_KEY'; return d; end
    if kv~hasIndex(key) then do; d['code']='DUPLICATE_KEY'; return d; end
    kv[key]=value
  end
  if conversationGet(kv,'schema','')<>'audio.pool.observation/1' then do; d['code']='SCHEMA_MISMATCH'; return d; end
  do k over .array~of('message_id','node_id','kind','thread_id','summary','evidence_ref')
    if \kv~hasIndex(k) then do; d['code']='INCOMPLETE_OBSERVATION'; return d; end
  end
  messageId=conversationGet(kv,'message_id','')
  nodeId=conversationGet(kv,'node_id','')
  kind=conversationGet(kv,'kind','')~upper
  if \conversationTrustedId(messageId) then do; d['code']='INVALID_MESSAGE_ID'; return d; end
  if \conversationValidNode(nodeId) then do; d['code']='INVALID_NODE_ID'; return d; end
  if \conversationValidKind(kind) then do; d['code']='INVALID_KIND'; return d; end
  threadId=conversationGet(kv,'thread_id','')
  if threadId<>'' & \conversationTrustedId(threadId) then do; d['code']='INVALID_THREAD_ID'; return d; end
  reply=conversationGet(kv,'in_reply_to','')
  if reply<>'' & \conversationTrustedId(reply) then do; d['code']='INVALID_REPLY_ID'; return d; end
  candidate=conversationGet(kv,'candidate_id','')
  if candidate~length>256 then do; d['code']='INVALID_CANDIDATE_ID'; return d; end
  summary=conversationGet(kv,'summary','')
  if summary='' | summary~length>4096 | summary~pos('0a'x)>0 | summary~pos('0d'x)>0 then do; d['code']='INVALID_SUMMARY'; return d; end
  evidence=conversationGet(kv,'evidence_ref','')
  if evidence~length>1024 | evidence~pos('0a'x)>0 | evidence~pos('0d'x)>0 then do; d['code']='INVALID_EVIDENCE_REF'; return d; end
  if kv~hasIndex('score') then do
    score=kv['score']~strip
    if score<>'' & \datatype(score,'N') then do; d['code']='INVALID_SCORE'; return d; end
  end
  d['ok']=.true; d['code']=''; d['message_id']=messageId; d['node_id']=nodeId; d['kind']=kind; d['values']=kv
  return d

::routine conversationValidNode
  use strict arg nodeId
  return .array~of('ed209a','ed209b','ed209c','ed209d','ed209e','ed209i','ed209f','ed209g','ed209h','controller','reviewer')~hasItem(nodeId~lower)
::routine conversationValidKind
  use strict arg kind
  return .array~of('RESULT','VOICE_DETECTED','FRONTIER','HYPOTHESIS','REQUEST','REPLY','CAPABILITY','REVIEW','WARNING','STATUS')~hasItem(kind~upper)
::routine conversationTrustedKey
  use strict arg x
  if x='' | x~length>80 then return .false
  allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'
  do i=1 to x~length; if allowed~pos(x~substr(i,1))=0 then return .false; end
  return .true
::routine conversationTrustedId
  use strict arg x
  return conversationTrustedKey(x)
::routine conversationGet
  use strict arg d,k,default
  if d~hasIndex(k) then return d[k]
  return default
::routine conversationResult
  use strict arg ok,code
  d=.directory~new; d['ok']=ok; d['code']=code
  return d
::routine conversationFileExists
  use strict arg path
  return stream(path,'c','query exists')<>''
::routine conversationReadWhole
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
::routine conversationWriteWhole
  use strict arg path,text
  s=.stream~new(path); s~open('write replace'); s~charout(text); s~close
  return
::routine conversationMakeDir
  use strict arg path
  address system 'mkdir -p -- 'conversationShellQuote(path)
  if rc<>0 then raise syntax 88.912 array('cannot create conversation directory',path)
  return
::routine conversationShellQuote
  use strict arg v
  return "'"||v~changeStr("'","'\\''")||"'"

::requires 'Observation.cls'
