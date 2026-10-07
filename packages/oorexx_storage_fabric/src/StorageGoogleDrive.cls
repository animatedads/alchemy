/* ooRexx Storage Fabric v0.1-dev6
 *
 * Google Drive bounded HTTP adapter and StorageByteSource/Sink bridge.
 *
 * The adapter deliberately owns neither OAuth persistence nor API egress
 * authority.  It accepts an HTTP executor (normally API Client v0.3+) and a
 * short-lived auth provider (normally Secret Broker).  Bearer tokens and the
 * resumable session URI are never written to the generic Storage catalogue or
 * transfer checkpoint.
 */

::class StorageGoogleDriveBuild public
::constant VERSION "0.1-dev6"
::constant API "storage.fabric.google-drive/0.1"
::constant API_CLIENT "api.client/0.3+"

/* -------------------- HTTP / API Client seam -------------------- */

::class StorageHttpExecutor public
::method execute abstract

/* The concrete ooRexx API Client composition adapter lives in
 * src/StorageApiClientBridge.cls so loading core Drive semantics does not
 * force API Client into every Storage process. */

::class StorageHttpUtil public
::method header class
  use arg headers,nameArg,defaultArg=""
  if headers==.nil then return defaultArg
  name=nameArg~string
  value=headers~at(name)
  if value==.nil then value=headers~at(name~lower)
  if value==.nil then value=headers~at(name~upper)
  if value==.nil then return defaultArg
  return value~string
::method responseCode class
  use arg response
  if response==.nil then return "NO_RESPONSE"
  if response~hasMethod("ERRORCODE") then do
    e=response~errorCode
    if e~string~strip<>"" then return e~string~strip
  end
  if response~hasMethod("STATUS") then return "HTTP_"||response~status
  return "INVALID_RESPONSE"

/* -------------------- auth boundary -------------------- */

::class GoogleDriveAuthLease public
::method bearerToken abstract
::method retire abstract

::class GoogleDriveSecretBrokerAuthLease subclass GoogleDriveAuthLease public
::method init
  expose lease token active
  use arg leaseArg, tokenArg
  lease=leaseArg; token=tokenArg~string; active=.true
::method bearerToken
  expose token active
  if \active then return ""
  return token
::method retire
  expose lease token active
  if \active then return .false
  token=""; active=.false
  if lease<>.nil then if lease~hasMethod("RETIRE") then lease~retire
  lease=.nil
  return .true

::class GoogleDriveAuthProvider public
::method acquire abstract

/* Secret Broker integration by protocol, without importing broker classes. */
::class GoogleDriveSecretBrokerAuthProvider subclass GoogleDriveAuthProvider public
::method init
  expose broker reference
  use arg brokerArg, referenceArg
  if brokerArg==.nil then raise syntax 88.900 array("Secret Broker object is required")
  broker=brokerArg; reference=referenceArg~string~strip
  if reference="" then raise syntax 88.900 array("Drive bearer secret reference is required")
::method acquire
  expose broker reference
  lease=broker~acquire(reference)
  if lease==.nil then return .nil
  if lease~hasMethod("OK") then if \lease~ok then do
    if lease~hasMethod("RETIRE") then lease~retire
    return .nil
  end
  if \lease~hasMethod("SECRETFORTRUSTEDCONSUMER") then do
    if lease~hasMethod("RETIRE") then lease~retire
    return .nil
  end
  value=lease~secretForTrustedConsumer
  if value==.nil | \value~ok then do
    if lease~hasMethod("RETIRE") then lease~retire
    return .nil
  end
  token=value~value~string
  if token="" then do
    if lease~hasMethod("RETIRE") then lease~retire
    return .nil
  end
  return .GoogleDriveSecretBrokerAuthLease~new(lease,token)

/* Explicit fixture-only auth for regression tests.  Never use this class as a
 * production credential store. */
::class GoogleDriveTestAuthProvider subclass GoogleDriveAuthProvider public
::attribute acquisitions get
::attribute retirements get
::method init
  expose token acquisitions retirements
  use arg tokenArg="test-token"
  token=tokenArg~string; acquisitions=0; retirements=0
::method acquire
  expose token acquisitions retirements
  acquisitions+=1
  return .GoogleDriveTestAuthLease~new(self,token)
::method retired
  expose retirements
  retirements+=1

::class GoogleDriveTestAuthLease subclass GoogleDriveAuthLease public
::method init
  expose owner token active
  use arg ownerArg,tokenArg
  owner=ownerArg; token=tokenArg~string; active=.true
::method bearerToken
  expose token active
  if \active then return ""
  return token
::method retire
  expose owner token active
  if \active then return .false
  token=""; active=.false; owner~retired
  return .true

/* -------------------- small JSON / URL helpers -------------------- */

::class GoogleDriveJson public
::method escape class
  use arg valueArg
  s=valueArg~string
  bs="5c"x; dq="22"x
  s=changestr(bs,s,bs||bs)
  s=changestr(dq,s,bs||dq)
  s=changestr("08"x,s,bs||"b")
  s=changestr("0c"x,s,bs||"f")
  s=changestr("0a"x,s,bs||"n")
  s=changestr("0d"x,s,bs||"r")
  s=changestr("09"x,s,bs||"t")
  return s
::method stringField class
  use arg jsonArg, fieldArg
  json=jsonArg~string; field=fieldArg~string
  dq="22"x; bs="5c"x
  needle=dq||field||dq
  p=pos(needle,json)
  if p=0 then return ""
  colon=pos(":",json,p+length(needle))
  if colon=0 then return ""
  i=colon+1
  do while i<=length(json) & pos(substr(json,i,1)," "||"09"x||"0a"x||"0d"x)>0
    i+=1
  end
  if substr(json,i,1)<>dq then return ""
  i+=1; out=""
  do while i<=length(json)
    ch=substr(json,i,1)
    if ch=dq then return out
    if ch=bs then do
      i+=1
      if i>length(json) then return ""
      esc=substr(json,i,1)
      select
        when esc=dq then out=out||dq
        when esc=bs then out=out||bs
        when esc="/" then out=out||"/"
        when esc="b" then out=out||"08"x
        when esc="f" then out=out||"0c"x
        when esc="n" then out=out||"0a"x
        when esc="r" then out=out||"0d"x
        when esc="t" then out=out||"09"x
        otherwise return ""  /* \u is not needed for Drive IDs/digests. */
      end
    end
    else out=out||ch
    i+=1
  end
  return ""

::class GoogleDriveUrl public
::method pathSegment class
  use arg valueArg
  s=valueArg~string; out=""; hex="0123456789ABCDEF"
  do i=1 to length(s)
    ch=substr(s,i,1); n=c2d(ch)
    if (n>=48 & n<=57) | (n>=65 & n<=90) | (n>=97 & n<=122) | ch="-" | ch="_" | ch="." | ch="~" then out=out||ch
    else out=out||"%"||substr(hex,n%16+1,1)||substr(hex,n//16+1,1)
  end
  return out

/* -------------------- Drive protocol result/state -------------------- */

::class GoogleDriveChunkResult public
::attribute ok get
::attribute code get
::attribute httpStatus get
::attribute nextOffset get
::attribute completed get
::method init
  expose ok code httpStatus nextOffset completed
  use arg okArg, codeArg="", statusArg=0, offsetArg=0, completedArg=.false
  ok=(okArg==.true); code=codeArg~string; httpStatus=statusArg+0; nextOffset=offsetArg+0; completed=(completedArg==.true)

::class GoogleDriveRangeResult public
::attribute ok get
::attribute code get
::attribute httpStatus get
::attribute offset get
::attribute data get
::attribute eof get
::method init
  expose ok code httpStatus offset data eof
  use arg okArg,codeArg="",statusArg=0,offsetArg=0,dataArg="",eofArg=.false
  ok=(okArg==.true); code=codeArg~string; httpStatus=statusArg+0; offset=offsetArg+0; data=dataArg; eof=(eofArg==.true)

/* The session URI is a bearer-like capability.  It intentionally has no
 * generic serialization method and must not appear in Storage checkpoints. */
::class GoogleDriveUploadSession public
::attribute totalBytes get
::attribute nextOffset get
::attribute completed get
::attribute remoteFileId get
::attribute remoteSha256 get
::attribute remoteMd5 get
::attribute modifiedTime get
::method init
  expose capability totalBytes nextOffset completed remoteFileId remoteSha256 remoteMd5 modifiedTime
  use arg capabilityArg,totalArg
  capability=capabilityArg~string; totalBytes=totalArg+0; nextOffset=0; completed=.false
  remoteFileId=""; remoteSha256=""; remoteMd5=""; modifiedTime=""
  if capability="" | totalBytes<1 then raise syntax 88.900 array("invalid Drive upload session")
::method transportCapability
  expose capability
  return capability
::method acknowledge
  expose nextOffset totalBytes completed
  use arg offsetArg
  n=offsetArg+0
  if n<0 | n>totalBytes then return .false
  nextOffset=n
  if n=totalBytes then completed=.true
  return .true
::method completeFromBody
  expose nextOffset totalBytes completed remoteFileId remoteSha256 remoteMd5 modifiedTime
  use arg bodyArg
  remoteFileId=.GoogleDriveJson~stringField(bodyArg,"id")
  remoteSha256=.GoogleDriveJson~stringField(bodyArg,"sha256Checksum")~lower
  remoteMd5=.GoogleDriveJson~stringField(bodyArg,"md5Checksum")~lower
  modifiedTime=.GoogleDriveJson~stringField(bodyArg,"modifiedTime")
  nextOffset=totalBytes; completed=.true
  return self

::class GoogleDriveUploadSessionStore public
::method get abstract
::method put abstract
::method remove abstract

/* Process-local fixture/state holder.  Production restart persistence for the
 * resumable session capability belongs behind a secure provider-private state
 * authority; never put the capability into the general catalogue/checkpoint. */
::class GoogleDriveMemoryUploadSessionStore subclass GoogleDriveUploadSessionStore public
::method init
  expose sessions
  sessions=.directory~new
::method get
  expose sessions
  use arg keyArg
  return sessions~at(keyArg~string)
::method put
  expose sessions
  use arg keyArg,sessionArg
  sessions[keyArg~string]=sessionArg
  return sessionArg
::method remove
  expose sessions
  use arg keyArg
  sessions~remove(keyArg~string)
  return self

/* -------------------- Drive API adapter -------------------- */

::class GoogleDriveApiAdapter public
::attribute lastError get
::attribute providerId get
::method init
  expose executor auth providerId apiRoot uploadRoot lastError
  use arg executorArg,authArg,providerArg="google-drive",apiRootArg="https://www.googleapis.com/drive/v3",uploadRootArg="https://www.googleapis.com/upload/drive/v3"
  if executorArg==.nil | authArg==.nil then raise syntax 88.900 array("Drive executor and auth provider are required")
  executor=executorArg; auth=authArg; providerId=providerArg~string
  apiRoot=apiRootArg~string; uploadRoot=uploadRootArg~string; lastError=""
::method startUpload
  expose uploadRoot lastError
  use arg parentArg,nameArg,mimeArg,totalArg
  parent=parentArg~string; name=nameArg~string; mime=mimeArg~string; total=totalArg+0
  if name="" | total<1 then do; lastError="DRIVE_UPLOAD_ARGUMENT_INVALID"; return .nil; end
  if mime="" then mime="application/octet-stream"
  body="{"||'"name":"'||.GoogleDriveJson~escape(name)||'"'
  if parent<>"" then body=body||',"parents":["'||.GoogleDriveJson~escape(parent)||'"]'
  body=body||"}"
  headers=.directory~new
  headers["content-type"]="application/json; charset=UTF-8"
  headers["x-upload-content-type"]=mime
  headers["x-upload-content-length"]=total
  url=uploadRoot||"/files?uploadType=resumable&fields=id,name,size,md5Checksum,sha256Checksum,modifiedTime"
  response=self~authorized("POST",url,headers,body,"CONTROL")
  if response==.nil then return .nil
  if response~status<>200 then do; lastError=.StorageHttpUtil~responseCode(response); return .nil; end
  location=.StorageHttpUtil~header(response~headers,"location","")
  if location="" then do; lastError="DRIVE_SESSION_LOCATION_MISSING"; return .nil; end
  lastError=""
  return .GoogleDriveUploadSession~new(location,total)
::method uploadChunk
  expose lastError
  use arg session,offsetArg,dataArg
  if session==.nil then return .GoogleDriveChunkResult~new(.false,"DRIVE_SESSION_MISSING")
  offset=offsetArg+0; data=dataArg; n=length(data); total=session~totalBytes
  if offset<>session~nextOffset then return .GoogleDriveChunkResult~new(.false,"DRIVE_SESSION_OFFSET_MISMATCH",0,session~nextOffset)
  if n<1 | offset+n>total then return .GoogleDriveChunkResult~new(.false,"DRIVE_CHUNK_INVALID",0,offset)
  final=(offset+n=total)
  if \.GoogleDriveResumableProtocol~validChunk(n,final) then return .GoogleDriveChunkResult~new(.false,"DRIVE_CHUNK_QUANTUM_INVALID",0,offset)
  headers=.directory~new
  headers["content-type"]="application/octet-stream"
  headers["content-length"]=n
  headers["content-range"]=.GoogleDriveResumableProtocol~contentRange(offset,n,total)
  response=self~authorized("PUT",session~transportCapability,headers,data,"SOURCE_BULK")
  if response==.nil then return self~recoverUncertain(session,offset,n)
  if response~errorCode<>"" | response~status>=500 then return self~recoverUncertain(session,offset,n)
  if response~status=308 then do
    next=.GoogleDriveResumableProtocol~nextOffset(.StorageHttpUtil~header(response~headers,"range",""))
    if next<offset | next>offset+n then return .GoogleDriveChunkResult~new(.false,"DRIVE_ACK_RANGE_INVALID",308,offset)
    session~acknowledge(next); lastError=""
    return .GoogleDriveChunkResult~new(.true,"",308,next,.false)
  end
  if response~status=200 | response~status=201 then do
    session~completeFromBody(response~body)
    lastError=""
    return .GoogleDriveChunkResult~new(.true,"",response~status,total,.true)
  end
  if response~status=404 | response~status=410 then do; lastError="DRIVE_SESSION_EXPIRED"; return .GoogleDriveChunkResult~new(.false,lastError,response~status,offset); end
  lastError=.StorageHttpUtil~responseCode(response)
  return .GoogleDriveChunkResult~new(.false,lastError,response~status,offset)
::method queryUpload
  expose lastError
  use arg session
  if session==.nil then return .GoogleDriveChunkResult~new(.false,"DRIVE_SESSION_MISSING")
  headers=.directory~new
  headers["content-length"]="0"
  headers["content-range"]=.GoogleDriveResumableProtocol~statusContentRange(session~totalBytes)
  response=self~authorized("PUT",session~transportCapability,headers,"","CONTROL")
  if response==.nil then return .GoogleDriveChunkResult~new(.false,lastError,0,session~nextOffset)
  if response~status=308 then do
    next=.GoogleDriveResumableProtocol~nextOffset(.StorageHttpUtil~header(response~headers,"range",""))
    if next<0 | next>session~totalBytes then do; lastError="DRIVE_ACK_RANGE_INVALID"; return .GoogleDriveChunkResult~new(.false,lastError,308,session~nextOffset); end
    session~acknowledge(next); lastError=""
    return .GoogleDriveChunkResult~new(.true,"",308,next,.false)
  end
  if response~status=200 | response~status=201 then do
    session~completeFromBody(response~body); lastError=""
    return .GoogleDriveChunkResult~new(.true,"",response~status,session~totalBytes,.true)
  end
  if response~status=404 | response~status=410 then do; lastError="DRIVE_SESSION_EXPIRED"; return .GoogleDriveChunkResult~new(.false,lastError,response~status,session~nextOffset); end
  lastError=.StorageHttpUtil~responseCode(response)
  return .GoogleDriveChunkResult~new(.false,lastError,response~status,session~nextOffset)
::method recoverUncertain private
  expose lastError
  use arg session,offset,n
  q=self~queryUpload(session)
  if q~ok then do
    /* Provider acknowledgement may be behind, equal to, or ahead of the local
     * checkpoint but must never claim bytes outside the uncertain request. */
    if q~nextOffset<offset | q~nextOffset>offset+n then do; lastError="DRIVE_RECOVERY_RANGE_INVALID"; return .GoogleDriveChunkResult~new(.false,lastError,q~httpStatus,offset); end
    return q
  end
  if lastError="" then lastError="DRIVE_UPLOAD_UNCERTAIN"
  return .GoogleDriveChunkResult~new(.false,lastError,q~httpStatus,offset)
::method downloadRange
  expose apiRoot lastError
  use arg fileIdArg,offsetArg,lengthArg,totalArg
  fileId=fileIdArg~string; offset=offsetArg+0; n=lengthArg+0; total=totalArg+0
  if fileId="" | offset<0 | n<1 | total<1 | offset+n>total then return .GoogleDriveRangeResult~new(.false,"DRIVE_RANGE_ARGUMENT_INVALID",0,offset)
  headers=.directory~new
  headers["range"]="bytes="||offset||"-"||(offset+n-1)
  url=apiRoot||"/files/"||.GoogleDriveUrl~pathSegment(fileId)||"?alt=media"
  response=self~authorized("GET",url,headers,"","SOURCE_BULK")
  if response==.nil then return .GoogleDriveRangeResult~new(.false,lastError,0,offset)
  if response~errorCode<>"" then do; lastError=response~errorCode; return .GoogleDriveRangeResult~new(.false,lastError,response~status,offset); end
  if response~status<>206 & \(response~status=200 & offset=0 & n=total) then do
    lastError=.StorageHttpUtil~responseCode(response)
    return .GoogleDriveRangeResult~new(.false,lastError,response~status,offset)
  end
  if length(response~body)<>n then do; lastError="DRIVE_RANGE_LENGTH_MISMATCH"; return .GoogleDriveRangeResult~new(.false,lastError,response~status,offset); end
  lastError=""
  return .GoogleDriveRangeResult~new(.true,"",response~status,offset,response~body,offset+n>=total)
::method fileMetadata
  expose apiRoot lastError
  use arg fileIdArg
  fileId=fileIdArg~string
  if fileId="" then do; lastError="DRIVE_FILE_ID_REQUIRED"; return ""; end
  headers=.directory~new
  url=apiRoot||"/files/"||.GoogleDriveUrl~pathSegment(fileId)||"?fields=id,name,size,mimeType,modifiedTime,md5Checksum,sha1Checksum,sha256Checksum,parents,trashed"
  response=self~authorized("GET",url,headers,"","CONTROL")
  if response==.nil then return ""
  if response~status<>200 | response~errorCode<>"" then do; lastError=.StorageHttpUtil~responseCode(response); return ""; end
  lastError=""; return response~body
::method authorized private
  expose executor auth lastError
  use arg methodArg,urlArg,headersArg,bodyArg,trafficArg
  lease=auth~acquire
  if lease==.nil then do; lastError="DRIVE_AUTH_UNAVAILABLE"; return .nil; end
  token=lease~bearerToken
  if token="" then do; lease~retire; lastError="DRIVE_AUTH_UNAVAILABLE"; return .nil; end
  headersArg["authorization"]="Bearer "||token
  signal on syntax name executorFailure
  response=executor~execute(methodArg,urlArg,headersArg,bodyArg,trafficArg)
  headersArg~remove("authorization")
  token=""; lease~retire
  return response
executorFailure:
  headersArg~remove("authorization")
  token=""; lease~retire
  lastError="DRIVE_HTTP_EXECUTOR_EXCEPTION"
  return .nil

/* -------------------- Storage source / sink -------------------- */

::class GoogleDriveRangeByteSource subclass StorageByteSource public
::attribute sizeBytes get
::attribute position get
::attribute lastError get
::method init
  expose adapter providerId fileId sizeBytes versionToken position opened lastError
  use arg adapterArg,providerArg,fileIdArg,sizeArg,versionArg=""
  adapter=adapterArg; providerId=providerArg~string; fileId=fileIdArg~string; sizeBytes=sizeArg+0; versionToken=versionArg~string
  if adapter==.nil | providerId="" | fileId="" | sizeBytes<1 then raise syntax 88.900 array("invalid Drive byte source")
  position=0; opened=.false; lastError=""
::method resumeIdentity
  expose providerId fileId sizeBytes versionToken
  return "GDRIVE_SOURCE|"||providerId||"|"||fileId||"|"||sizeBytes||"|"||versionToken
::method openAt
  expose position opened sizeBytes lastError
  use arg offsetArg=0
  n=offsetArg+0
  if n<0 | n>sizeBytes then do; lastError="DRIVE_SOURCE_OFFSET_INVALID"; opened=.false; return self; end
  position=n; opened=.true; lastError=""; return self
::method readChunk
  expose adapter fileId sizeBytes position opened lastError
  use arg maximumArg
  if \opened then return .StorageByteChunk~new(position,"",.true)
  max=maximumArg+0
  if max<1 then do; lastError="DRIVE_SOURCE_CHUNK_INVALID"; return .StorageByteChunk~new(position,"",.true); end
  if position>=sizeBytes then return .StorageByteChunk~new(position,"",.true)
  n=max; if position+n>sizeBytes then n=sizeBytes-position
  start=position
  result=adapter~downloadRange(fileId,start,n,sizeBytes)
  if \result~ok then do; lastError=result~code; return .StorageByteChunk~new(start,"",.false); end
  position+=length(result~data); lastError=""
  return .StorageByteChunk~new(start,result~data,position>=sizeBytes)
::method close
  expose opened
  opened=.false; return self

::class GoogleDriveResumableByteSink subclass StorageByteSink public
::attribute position get
::attribute lastError get
::method init
  expose adapter store sessionKey providerId parentId name mime position expected opened lastError
  use arg adapterArg,storeArg,sessionKeyArg,providerArg,parentArg,nameArg,mimeArg="application/octet-stream"
  adapter=adapterArg; store=storeArg; sessionKey=sessionKeyArg~string; providerId=providerArg~string
  parentId=parentArg~string; name=nameArg~string; mime=mimeArg~string
  if adapter==.nil | store==.nil | sessionKey="" | providerId="" | name="" then raise syntax 88.900 array("invalid Drive byte sink")
  position=0; expected=0; opened=.false; lastError=""
::method resumeIdentity
  expose providerId parentId name sessionKey
  /* Stable target identity excludes the secret resumable session URI. */
  return "GDRIVE_SINK|"||providerId||"|"||parentId||"|"||name||"|"||sessionKey
::method reconcileResume
  expose adapter store sessionKey lastError
  use arg checkpointArg,totalArg
  checkpoint=checkpointArg+0; total=totalArg+0
  session=store~get(sessionKey)
  if session==.nil then do
    if checkpoint=0 then return .StorageSinkResumeEvidence~accept(0,"NO_REMOTE_SESSION")
    lastError="DRIVE_SESSION_STATE_MISSING"
    return .StorageSinkResumeEvidence~reject(lastError,checkpoint)
  end
  if session~totalBytes<>total then do; lastError="DRIVE_SESSION_SIZE_MISMATCH"; return .StorageSinkResumeEvidence~reject(lastError,checkpoint); end
  q=adapter~queryUpload(session)
  if \q~ok then do
    lastError=q~code
    if q~code="DRIVE_SESSION_EXPIRED" then store~remove(sessionKey)
    if checkpoint=0 & q~code="DRIVE_SESSION_EXPIRED" then return .StorageSinkResumeEvidence~accept(0,"EXPIRED_SESSION_RESTART")
    return .StorageSinkResumeEvidence~reject(lastError,checkpoint)
  end
  store~put(sessionKey,session); lastError=""
  return .StorageSinkResumeEvidence~accept(q~nextOffset,"DRIVE_RANGE_ACK")
::method openAt
  expose adapter store sessionKey parentId name mime position expected opened lastError
  use arg offsetArg=0,totalArg=0
  offset=offsetArg+0; total=totalArg+0
  expected=total
  if offset<0 | total<1 | offset>total then do; lastError="DRIVE_SINK_OFFSET_INVALID"; opened=.false; return self; end
  session=store~get(sessionKey)
  if session==.nil then do
    if offset<>0 then do; lastError="DRIVE_SESSION_STATE_MISSING"; opened=.false; return self; end
    session=adapter~startUpload(parentId,name,mime,total)
    if session==.nil then do; lastError=adapter~lastError; opened=.false; return self; end
    store~put(sessionKey,session)
  end
  else if session~totalBytes<>total then do; lastError="DRIVE_SESSION_SIZE_MISMATCH"; opened=.false; return self; end
  /* A brand-new Storage transfer with no checkpoint must not attach itself to
   * an old partially acknowledged provider session. */
  if offset=0 & session~nextOffset<>0 then do
    store~remove(sessionKey)
    session=adapter~startUpload(parentId,name,mime,total)
    if session==.nil then do; lastError=adapter~lastError; opened=.false; return self; end
    store~put(sessionKey,session)
  end
  if session~nextOffset<>offset then do; lastError="DRIVE_SESSION_OFFSET_MISMATCH"; opened=.false; return self; end
  position=offset; opened=.true; lastError=""; return self
::method writeChunk
  expose adapter store sessionKey position expected opened lastError
  use arg dataArg
  if \opened then do; if lastError="" then lastError="DRIVE_SINK_NOT_OPEN"; return 0; end
  session=store~get(sessionKey)
  if session==.nil then do; lastError="DRIVE_SESSION_STATE_MISSING"; return 0; end
  start=position; data=dataArg; n=length(data)
  result=adapter~uploadChunk(session,start,data)
  if \result~ok then do; lastError=result~code; return 0; end
  delta=result~nextOffset-start
  if delta<1 | delta>n then do; lastError="DRIVE_ACK_DELTA_INVALID"; return 0; end
  position=result~nextOffset; store~put(sessionKey,session); lastError=""
  return delta
::method flush
  /* Every successful writeChunk has already received provider acknowledgement. */
  return self
::method close
  expose opened
  opened=.false; return self
::method completed
  expose store sessionKey
  session=store~get(sessionKey); if session==.nil then return .false
  return session~completed
::method remoteFileId
  expose store sessionKey
  session=store~get(sessionKey); if session==.nil then return ""
  return session~remoteFileId
::method remoteSha256
  expose store sessionKey
  session=store~get(sessionKey); if session==.nil then return ""
  return session~remoteSha256
::method remoteMd5
  expose store sessionKey
  session=store~get(sessionKey); if session==.nil then return ""
  return session~remoteMd5
::method retireSession
  expose store sessionKey
  store~remove(sessionKey); return self

/* Verification uses Google's SHA-256 content checksum for binary Drive files.
 * The source side remains streamed through sha256sum; the object is never
 * collected into ooRexx memory for hashing. */
::class GoogleDriveSha256Verifier subclass StorageTransferVerifier public
::method verify
  use arg source,sink,transfer
  if \source~hasMethod("VERIFICATIONPATH") | \sink~hasMethod("REMOTESHA256") then return ""
  remote=sink~remoteSha256~string~lower
  if length(remote)<>64 then return ""
  local=.StoragePosixSha256Verifier~new~digestFile(source~verificationPath)
  if local="" | local<>remote then return ""
  return "sha256:"||local

/* Converts a VERIFIED Drive sink into catalogue/location evidence and only
 * then advances StorageTransfer to COMMITTED. */
::class GoogleDriveStorageCommitter public
::method commit
  use arg transfer,object,sink,provider,lifecycleArg=.nil
  if transfer==.nil | object==.nil | sink==.nil | provider==.nil then return .false
  if transfer~state<>.StorageTransferState~VERIFIED | \sink~completed then return .false
  fileId=sink~remoteFileId
  if fileId="" then return .false
  if lifecycleArg==.nil then do
    if provider~hasMethod("LIFECYCLE") then lifecycle=provider~lifecycle
    else lifecycle=.StorageServiceLifecycle~new
  end
  else lifecycle=lifecycleArg
  loc=.StorageLocation~new(provider~providerId,fileId,provider~capacityDomainId,.StorageLocationState~AVAILABLE,date("S")||"T"||time("L"),.true,transfer~verificationRef,lifecycle~safetyClass,lifecycle~state,"")
  object~addLocation(loc)
  if \transfer~commit then return .false
  sink~retireSession
  return .true

::requires "src/StorageStreaming.cls"
