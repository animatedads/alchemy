/* ooRexx Storage Fabric v0.1-dev6
 *
 * Bounded-memory byte source/sink contracts and restartable transfer engine.
 * The engine never requires a whole-object body in memory; provider adapters
 * expose ranged/chunked reads and writes through StorageByteSource/Sink.
 */

::class StorageStreamingBuild public
::constant VERSION "0.1-dev6"
::constant API "storage.fabric.streaming/0.1"

::class StorageTransferRunStatus public
::constant COMPLETED "COMPLETED"
::constant PAUSED "PAUSED"
::constant FAILED "FAILED"

::class StorageByteChunk public
::attribute offset get
::attribute data get
::attribute eof get
::attribute size get
::method init
  expose offset data eof size
  use arg offsetArg, dataArg="", eofArg=.false
  offset=offsetArg+0
  data=dataArg
  size=data~length
  eof=(eofArg==.true)
  if offset<0 then raise syntax 88.900 array("chunk offset must not be negative")

/* Provider-neutral streaming contracts.  A future Google Drive adapter can
 * implement ranged GET and resumable PUT without changing the copy engine. */
::class StorageByteSource public
::method sizeBytes abstract
::method resumeIdentity abstract
::method openAt abstract
::method readChunk abstract
::method close abstract

::class StorageByteSink public
::method resumeIdentity abstract
::method openAt abstract
::method writeChunk abstract
::method flush abstract
::method close abstract

/* Optional provider-authoritative resume reconciliation.  Local random-access
 * sinks can rely on the Storage checkpoint alone.  Remote resumable protocols
 * may have stronger acknowledgement evidence at the provider.  A sink that
 * implements RECONCILERESUME returns this object before the transfer object is
 * restored from the local checkpoint. */
::class StorageSinkResumeEvidence public
::attribute ok get
::attribute offset get
::attribute code get
::attribute evidenceRef get
::method init
  expose ok offset code evidenceRef
  use arg okArg, offsetArg=0, codeArg="", evidenceArg=""
  ok=(okArg==.true)
  offset=offsetArg+0
  code=codeArg~string
  evidenceRef=evidenceArg~string
::method accept class
  use arg offsetArg=0,evidenceArg=""
  return self~new(.true,offsetArg,"",evidenceArg)
::method reject class
  use arg codeArg,offsetArg=0,evidenceArg=""
  return self~new(.false,offsetArg,codeArg,evidenceArg)

::class StorageLocalFileByteSource subclass StorageByteSource public
::attribute path get
::attribute sizeBytes get
::attribute position get
::attribute opened get
::attribute sourceTimestamp get
::method init
  expose path sizeBytes position opened sourceTimestamp canonicalPath
  use arg pathArg
  path=pathArg~string
  canonicalPath=stream(path,"c","query exists")
  if canonicalPath="" then raise syntax 88.900 array("source file does not exist",path)
  qsize=stream(path,"c","query size")
  if datatype(qsize,"N")=0 then raise syntax 88.900 array("source size is unavailable",path)
  sizeBytes=qsize+0
  sourceTimestamp=stream(path,"c","query timestamp")
  position=0; opened=.false
::method resumeIdentity
  expose canonicalPath sizeBytes sourceTimestamp
  return "LOCAL_FILE_SOURCE|"||canonicalPath||"|"||sizeBytes||"|"||sourceTimestamp
::method openAt
  expose path sizeBytes position opened sourceTimestamp canonicalPath
  use arg offsetArg=0
  offset=offsetArg+0
  if offset<0 | offset>sizeBytes then raise syntax 88.900 array("source offset outside object",offset,sizeBytes)
  /* Refuse resume if the local source changed since this source object was made. */
  current=stream(path,"c","query exists")
  if current="" then raise syntax 88.900 array("source file disappeared",path)
  currentSize=stream(path,"c","query size")
  currentStamp=stream(path,"c","query timestamp")
  if currentSize+0<>sizeBytes | currentStamp<>sourceTimestamp then raise syntax 88.900 array("source file changed",path)
  if opened then self~close
  answer=stream(path,"c","open read")
  if left(answer,6)<>"READY:" then raise syntax 88.900 array("cannot open source",path,answer)
  position=offset; opened=.true
  return self
::method readChunk
  expose path sizeBytes position opened sourceTimestamp
  use arg maximumArg
  if \opened then raise syntax 88.900 array("source is not open")
  maximum=maximumArg+0
  if maximum<1 then raise syntax 88.900 array("chunk size must be positive")
  /* Detect truncation/replacement while a transfer is running.  A same-size
   * in-place mutation is caught by final cryptographic verification. */
  currentSize=stream(path,"c","query size")
  if datatype(currentSize,"N")=0 | currentSize+0<>sizeBytes then raise syntax 88.900 array("source size changed during transfer",path)
  if position>=sizeBytes then return .StorageByteChunk~new(position,"",.true)
  remaining=sizeBytes-position
  want=maximum
  if want>remaining then want=remaining
  start=position
  data=charin(path,position+1,want)
  got=data~length
  if got<>want then raise syntax 88.900 array("short source read",path,want,got)
  position+=got
  return .StorageByteChunk~new(start,data,position>=sizeBytes)
::method close
  expose path opened
  if opened then call stream path,"c","close"
  opened=.false
  return self
::method verificationPath
  expose path
  return path

::class StorageLocalFileByteSink subclass StorageByteSink public
::attribute path get
::attribute position get
::attribute opened get
::attribute expectedBytes get
::method init
  expose path position opened expectedBytes
  use arg pathArg
  path=pathArg~string
  if path="" then raise syntax 88.900 array("sink path must not be empty")
  position=0; opened=.false; expectedBytes=0
::method resumeIdentity
  expose path
  /* Sink identity intentionally excludes current size/timestamp: those change
   * as the resumable upload progresses. */
  return "LOCAL_FILE_SINK|"||path
::method openAt
  expose path position opened expectedBytes
  use arg offsetArg=0, totalArg=0
  offset=offsetArg+0; expectedBytes=totalArg+0
  if offset<0 | expectedBytes<0 | offset>expectedBytes then raise syntax 88.900 array("invalid sink offset/size",offset,expectedBytes)
  if opened then self~close
  if offset=0 then do
    answer=stream(path,"c","open write replace")
    if left(answer,6)<>"READY:" then raise syntax 88.900 array("cannot create sink",path,answer)
    call stream path,"c","close"
  end
  else do
    exists=stream(path,"c","query exists")
    if exists="" then raise syntax 88.900 array("resume sink is missing",path)
    physical=stream(path,"c","query size")
    if datatype(physical,"N")=0 then raise syntax 88.900 array("resume sink size unavailable",path)
    physical=physical+0
    if physical<offset then raise syntax 88.900 array("resume sink shorter than checkpoint",physical,offset)
    if physical>expectedBytes then raise syntax 88.900 array("resume sink exceeds expected object size",physical,expectedBytes)
  end
  position=offset; opened=.true
  return self
::method writeChunk
  expose path position opened expectedBytes
  use arg dataArg
  if \opened then raise syntax 88.900 array("sink is not open")
  data=dataArg
  n=data~length
  if n=0 then return 0
  if position+n>expectedBytes then raise syntax 88.900 array("write exceeds expected object size",position+n,expectedBytes)
  unwritten=charout(path,data,position+1)
  if unwritten<>0 then raise syntax 88.900 array("short sink write",path,n-unwritten,n)
  position+=n
  return n
::method flush
  expose path opened
  if opened then do
    answer=stream(path,"c","flush")
    if left(answer,6)<>"READY:" & answer<>"" then raise syntax 88.900 array("sink flush failed",path,answer)
  end
  return self
::method close
  expose path opened
  if opened then do
    self~flush
    call stream path,"c","close"
  end
  opened=.false
  return self
::method sizeOnDisk
  expose path
  q=stream(path,"c","query size")
  if datatype(q,"N")=0 then return -1
  return q+0
::method verificationPath
  expose path
  return path

::class StorageAdler32 public
::method of class
  use arg valueArg
  value=valueArg
  a=1; b=0
  do i=1 to value~length
    a=(a+c2d(substr(value,i,1)))//65521
    b=(b+a)//65521
  end
  return b*65536+a

/* A two-slot checkpoint keeps the previous complete record while the next
 * one is being written.  This avoids a single torn checkpoint becoming the
 * only recovery evidence. */
::class StorageTransferCheckpoint public
::attribute sequence get
::attribute transferId get
::attribute sourceIdentity get
::attribute targetIdentity get
::attribute totalBytes get
::attribute bytesTransferred get
::attribute chunkBytes get
::attribute state get
::attribute verificationRef get
::attribute updatedAt get
::method init
  expose sequence transferId sourceIdentity targetIdentity totalBytes bytesTransferred chunkBytes state verificationRef updatedAt
  use arg transferArg, sourceArg, targetArg, totalArg, chunkArg
  sequence=0
  transferId=transferArg~string
  sourceIdentity=sourceArg~string
  targetIdentity=targetArg~string
  totalBytes=totalArg+0
  bytesTransferred=0
  chunkBytes=chunkArg+0
  state=.StorageTransferState~COPYING
  verificationRef=""
  updatedAt=self~now
  if transferId="" | sourceIdentity="" | targetIdentity="" | totalBytes<0 | chunkBytes<1 then raise syntax 88.900 array("invalid transfer checkpoint")
::method advance
  expose sequence bytesTransferred totalBytes state verificationRef updatedAt
  use arg bytesArg, stateArg="COPYING", verificationArg=""
  bytes=bytesArg+0
  if bytes<0 | bytes>totalBytes then raise syntax 88.900 array("checkpoint bytes outside transfer",bytes,totalBytes)
  sequence+=1
  bytesTransferred=bytes
  state=stateArg~string~upper
  verificationRef=verificationArg~string
  updatedAt=self~now
  return self
::method matches
  expose transferId sourceIdentity targetIdentity totalBytes
  use arg transferArg, sourceArg, targetArg, totalArg
  return transferId=transferArg~string & sourceIdentity=sourceArg~string & targetIdentity=targetArg~string & totalBytes=totalArg+0
::method save
  expose sequence transferId sourceIdentity targetIdentity totalBytes bytesTransferred chunkBytes state verificationRef updatedAt
  use arg rootArg
  root=rootArg~string
  if root="" then return self
  tab="09"x
  body="STORAGE-XFER-CKPT-1"||tab||sequence||tab||.StorageCodec~enc(transferId)||tab||.StorageCodec~enc(sourceIdentity)||tab||.StorageCodec~enc(targetIdentity)||tab||totalBytes||tab||bytesTransferred||tab||chunkBytes||tab||state||tab||.StorageCodec~enc(verificationRef)||tab||.StorageCodec~enc(updatedAt)
  checksum=.StorageAdler32~of(body)
  if sequence//2=0 then slot=root||".a"
  else slot=root||".b"
  call SysFileDelete slot
  call lineout slot,body||tab||checksum
  call lineout slot
  return self
::method loadLatest class
  use arg rootArg
  root=rootArg~string
  if root="" then return .nil
  a=self~loadSlot(root||".a")
  b=self~loadSlot(root||".b")
  if a==.nil then return b
  if b==.nil then return a
  if a~sequence>=b~sequence then return a
  return b
::method loadSlot class private
  use arg pathArg
  path=pathArg~string
  if stream(path,"c","query exists")="" then return .nil
  line=linein(path)
  call stream path,"c","close"
  p=lastpos("09"x,line)
  if p=0 then return .nil
  body=left(line,p-1); supplied=substr(line,p+1)
  if datatype(supplied,"N")=0 then return .nil
  if .StorageAdler32~of(body)<>supplied+0 then return .nil
  f=.StorageCodec~splitTabs(body)
  if f~items<>11 then return .nil
  if f[1]<>"STORAGE-XFER-CKPT-1" then return .nil
  if datatype(f[2],"N")=0 | datatype(f[6],"N")=0 | datatype(f[7],"N")=0 | datatype(f[8],"N")=0 then return .nil
  cp=.StorageTransferCheckpoint~new(.StorageCodec~dec(f[3]),.StorageCodec~dec(f[4]),.StorageCodec~dec(f[5]),f[6]+0,f[8]+0)
  cp~restore(f[2]+0,f[7]+0,f[9],.StorageCodec~dec(f[10]),.StorageCodec~dec(f[11]))
  return cp
::method restore private
  expose sequence bytesTransferred state verificationRef updatedAt totalBytes
  use arg sequenceArg, bytesArg, stateArg, verificationArg, updatedArg
  if bytesArg+0<0 | bytesArg+0>totalBytes then raise syntax 88.900 array("invalid checkpoint bytes")
  sequence=sequenceArg+0
  bytesTransferred=bytesArg+0
  state=stateArg~string~upper
  verificationRef=verificationArg~string
  updatedAt=updatedArg~string
  return self
::method now private
  return date("S")||"T"||time("L")

::class StorageTransferRunResult public
::attribute status get
::attribute bytesTransferred get
::attribute chunks get
::attribute resumed get
::attribute verificationRef get
::attribute failure get
::method init
  expose status bytesTransferred chunks resumed verificationRef failure
  use arg statusArg, bytesArg=0, chunksArg=0, resumedArg=.false, verificationArg="", failureArg=""
  status=statusArg~string
  bytesTransferred=bytesArg+0
  chunks=chunksArg+0
  resumed=(resumedArg==.true)
  verificationRef=verificationArg~string
  failure=failureArg~string
::method completed
  expose status
  return status=.StorageTransferRunStatus~COMPLETED

::class StorageTransferVerifier public
::method verify abstract

/* POSIX qualification verifier.  sha256sum is a streaming program, so this
 * preserves the bounded-memory property.  Cloud providers can replace this
 * with provider checksums without changing the copy engine. */
::class StoragePosixSha256Verifier subclass StorageTransferVerifier public
::method verify
  use arg source, sink, transfer
  src=self~digestFile(source~verificationPath)
  if src="" then return ""
  dst=self~digestFile(sink~verificationPath)
  if dst="" | dst<>src then return ""
  return "sha256:"||src
::method digestFile
  use arg pathArg
  path=pathArg~string
  if stream(path,"c","query exists")="" then return ""
  tmp=SysTempFileName("/tmp/oorexx-storage-sha256-??????")
  qpath=self~shellQuote(path); qtmp=self~shellQuote(tmp)
  address system "/usr/bin/sha256sum -- "||qpath||" > "||qtmp||" 2>/dev/null"
  result=rc
  if result<>0 then do; call SysFileDelete tmp; return ""; end
  line=linein(tmp); call stream tmp,"c","close"; call SysFileDelete tmp
  digest=word(line,1)~lower
  if length(digest)<>64 then return ""
  return digest
::method shellQuote private
  use arg s
  sq="'"; dq='"'
  replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::class StorageResumableTransferEngine public
::attribute chunkBytes get
::method init
  expose chunkBytes
  use arg chunkArg=8388608
  chunkBytes=chunkArg+0
  if chunkBytes<1 then raise syntax 88.900 array("transfer chunk size must be positive")
::method copy
  expose chunkBytes
  use arg transfer, source, sink, checkpointRootArg="", maxChunksArg=0, verifier=.nil
  if transfer==.nil | source==.nil | sink==.nil then return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,0,0,.false,"","MISSING_ARGUMENT")
  total=source~sizeBytes
  if transfer~sizeBytes<>total then do
    transfer~fail("SOURCE_SIZE_MISMATCH")
    return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,0,0,.false,"","SOURCE_SIZE_MISMATCH")
  end
  sourceIdentity=source~resumeIdentity
  targetIdentity=sink~resumeIdentity
  root=checkpointRootArg~string
  cp=.nil; resumed=.false
  if root<>"" then cp=.StorageTransferCheckpoint~loadLatest(root)
  if cp<>.nil then do
    if \cp~matches(transfer~transferId,sourceIdentity,targetIdentity,total) then do
      transfer~fail("CHECKPOINT_IDENTITY_MISMATCH")
      return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,0,0,.false,"","CHECKPOINT_IDENTITY_MISMATCH")
    end
    /* For a remote resumable sink the provider acknowledgement is allowed to
     * correct a stale local COPYING checkpoint in either direction.  This is
     * done before restoring StorageTransfer because progress() is monotonic.
     * Only the sink owning the remote protocol may publish this correction. */
    if cp~state=.StorageTransferState~COPYING & sink~hasMethod("RECONCILERESUME") then do
      rec=sink~reconcileResume(cp~bytesTransferred,total)
      if rec==.nil | \rec~ok then do
        code="SINK_RESUME_REJECTED"
        if rec<>.nil then if rec~code<>"" then code=rec~code
        transfer~fail(code)
        return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,cp~bytesTransferred,0,cp~bytesTransferred>0,"",code)
      end
      authoritative=rec~offset
      if authoritative<0 | authoritative>total then do
        transfer~fail("SINK_RESUME_OFFSET_INVALID")
        return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,cp~bytesTransferred,0,cp~bytesTransferred>0,"","SINK_RESUME_OFFSET_INVALID")
      end
      if authoritative<>cp~bytesTransferred then do
        cp~advance(authoritative,.StorageTransferState~COPYING)
        if root<>"" then cp~save(root)
      end
    end
    resumed=cp~bytesTransferred>0
    if \self~restoreTransfer(transfer,cp) then return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,transfer~bytesTransferred,0,resumed,"","CHECKPOINT_STATE_INVALID")
    if cp~state=.StorageTransferState~VERIFIED then return .StorageTransferRunResult~new(.StorageTransferRunStatus~COMPLETED,total,0,resumed,cp~verificationRef,"")
    if cp~state=.StorageTransferState~COPIED then return self~finishVerification(transfer,source,sink,cp,root,verifier,resumed,0)
  end
  else do
    if \transfer~begin then return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,transfer~bytesTransferred,0,.false,"","TRANSFER_NOT_PLANNED")
    cp=.StorageTransferCheckpoint~new(transfer~transferId,sourceIdentity,targetIdentity,total,chunkBytes)
    cp~advance(0,.StorageTransferState~COPYING)
    if root<>"" then cp~save(root)
  end

  offset=cp~bytesTransferred
  /* A checkpoint's original chunk size is not required to match a later
   * process' chunk size.  Resume occurs at an exact byte offset. */
  source~openAt(offset)
  sink~openAt(offset,total)
  chunks=0; maxChunks=maxChunksArg+0
  do while offset<total
    remain=total-offset
    ask=chunkBytes
    if ask>remain then ask=remain
    chunk=source~readChunk(ask)
    if chunk~offset<>offset | chunk~size=0 then do
      source~close; sink~close; transfer~fail("INVALID_SOURCE_CHUNK")
      return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,offset,chunks,resumed,"","INVALID_SOURCE_CHUNK")
    end
    wrote=sink~writeChunk(chunk~data)
    if datatype(wrote,"W")=0 | wrote<1 | wrote>chunk~size then do
      source~close; sink~close
      code=self~sinkFailure(sink,"SHORT_SINK_WRITE")
      transfer~fail(code)
      return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,offset,chunks,resumed,"",code)
    end
    /* Flush/remote acknowledgement before checkpointing: the checkpoint must
     * never claim bytes the sink has not first made durable/acknowledged. */
    sink~flush
    offset+=wrote
    transfer~progress(offset)
    cp~advance(offset,.StorageTransferState~COPYING)
    if root<>"" then cp~save(root)
    chunks+=1
    /* A remote protocol may acknowledge only part of a requested chunk after
     * recovering from an uncertain network outcome.  Re-open the source at
     * the acknowledged offset so the unacknowledged suffix is re-read rather
     * than silently skipped. */
    if wrote<chunk~size then do
      source~close
      source~openAt(offset)
    end
    if maxChunks>0 & chunks>=maxChunks & offset<total then do
      source~close; sink~close
      return .StorageTransferRunResult~new(.StorageTransferRunStatus~PAUSED,offset,chunks,resumed,"","")
    end
  end
  source~close; sink~close
  if \transfer~copied then do
    transfer~fail("COPY_STATE_INVALID")
    return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,offset,chunks,resumed,"","COPY_STATE_INVALID")
  end
  cp~advance(total,.StorageTransferState~COPIED)
  if root<>"" then cp~save(root)
  return self~finishVerification(transfer,source,sink,cp,root,verifier,resumed,chunks)
::method sinkFailure private
  use arg sink, defaultArg="SINK_WRITE_FAILED"
  if sink<>.nil then if sink~hasMethod("LASTERROR") then do
    detail=sink~lastError
    if detail~string~strip<>"" then return detail~string~strip
  end
  return defaultArg~string

::method restoreTransfer private
  use arg transfer, cp
  if transfer~state<>.StorageTransferState~PLANNED then return .false
  if \transfer~begin then return .false
  if \transfer~progress(cp~bytesTransferred) then return .false
  select
    when cp~state=.StorageTransferState~COPYING then return .true
    when cp~state=.StorageTransferState~COPIED then return transfer~copied
    when cp~state=.StorageTransferState~VERIFIED then do
      if \transfer~copied then return .false
      return transfer~verify(cp~verificationRef)
    end
    otherwise return .false
  end
::method finishVerification private
  use arg transfer, source, sink, cp, root, verifier, resumed, chunks
  if verifier==.nil then return .StorageTransferRunResult~new(.StorageTransferRunStatus~COMPLETED,transfer~bytesTransferred,chunks,resumed,"","")
  verification=verifier~verify(source,sink,transfer)
  if verification="" then do
    transfer~fail("VERIFICATION_FAILED")
    return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,transfer~bytesTransferred,chunks,resumed,"","VERIFICATION_FAILED")
  end
  if \transfer~verify(verification) then return .StorageTransferRunResult~new(.StorageTransferRunStatus~FAILED,transfer~bytesTransferred,chunks,resumed,"","VERIFY_STATE_INVALID")
  cp~advance(transfer~bytesTransferred,.StorageTransferState~VERIFIED,verification)
  if root<>"" then cp~save(root)
  return .StorageTransferRunResult~new(.StorageTransferRunStatus~COMPLETED,transfer~bytesTransferred,chunks,resumed,verification,"")


/* Executable protocol primitives for Google Drive resumable transfer.  The
 * actual HTTP/auth adapter remains separate, but these methods make the
 * chunk/range semantics explicit and testable. */
::class GoogleDriveResumableProtocol public
::constant CHUNK_QUANTUM_BYTES 262144
::constant RECOMMENDED_CHUNK_BYTES 8388608
::method validChunk class
  use arg bytesArg, finalArg=.false
  bytes=bytesArg+0
  if bytes<1 then return .false
  if finalArg==.true then return .true
  return bytes//262144=0
::method contentRange class
  use arg offsetArg, lengthArg, totalArg
  offset=offsetArg+0; length=lengthArg+0; total=totalArg+0
  if offset<0 | length<1 | total<1 | offset+length>total then raise syntax 88.900 array("invalid Drive content range",offset,length,total)
  return "bytes "||offset||"-"||(offset+length-1)||"/"||total
::method statusContentRange class
  use arg totalArg
  total=totalArg+0
  if total<1 then raise syntax 88.900 array("invalid Drive total size",total)
  return "bytes */"||total
::method nextOffset class
  use arg rangeArg
  r=rangeArg~string~strip
  if r="" then return 0
  /* Expected server form: bytes=0-42. */
  if left(r,6)~lower<>"bytes=" then return -1
  dash=lastpos("-",r)
  if dash=0 then return -1
  last=substr(r,dash+1)~strip
  if datatype(last,"W")=0 then return -1
  return last+1

::requires "src/StorageFabric.cls"