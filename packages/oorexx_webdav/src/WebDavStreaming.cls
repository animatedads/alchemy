/* ooRexx WebDAV v0.1-dev5
 * Abort-safe staged upload contract for a future streaming HTTPS host.
 *
 * The HTTPS server remains transport authority.  This package deliberately
 * does not pretend that HttpRequest~body is a stream.  A host with streaming
 * request support can feed bounded chunks into this session and publish only
 * after commit().
 */

::class WebDavStreamingBuild public
::constant VERSION "0.1-dev5"
::constant API "webdav.streaming/0.1"

::class WebDavUploadState public
::constant NEW "NEW"
::constant RECEIVING "RECEIVING"
::constant ABORTED "ABORTED"
::constant COMMITTED "COMMITTED"
::constant FAILED "FAILED"

::class WebDavUploadCommitResult public
::attribute ok get
::attribute status get
::attribute code get
::attribute message get
::attribute ref get
::method init
  expose ok status code message ref
  use arg okArg,statusArg,codeArg="",messageArg="",refArg=.nil
  ok=(okArg==.true); status=statusArg+0; code=codeArg~string
  message=messageArg~string; ref=refArg

/* A local staging sink with explicit abort cleanup.  It is intentionally a
 * staging implementation, not a new Storage provider. */
::class WebDavLocalStagedSink subclass StorageLocalFileByteSink public
::method abort
  p=self~path
  if self~opened then self~close
  if RxFuncQuery("SysFileDelete")<>0 then call RxFuncAdd "SysFileDelete","RexxUtil","SysFileDelete"
  if stream(p,"c","query exists")<>"" then call SysFileDelete p
  return stream(p,"c","query exists")=""

/* Receives bounded chunks with explicit backpressure information.  No
 * namespace/catalogue publication occurs until commit() succeeds. */
::class WebDavStreamingUploadSession public
::attribute path get
::attribute expectedBytes get
::attribute receivedBytes get
::attribute maximumChunkBytes get
::attribute state get
::attribute cleanupComplete get
::method init
  expose adapter path sink expectedBytes receivedBytes maximumChunkBytes state mediaType ifMatch ifNoneMatch ifHeader cleanupComplete
  use arg adapterArg,pathArg,sinkArg,expectedArg,mediaTypeArg="application/octet-stream",maximumChunkArg=8388608,ifMatchArg="",ifNoneMatchArg="",ifHeaderArg=""
  if adapterArg==.nil | sinkArg==.nil then raise syntax 88.900 array("WebDAV adapter and staging sink are mandatory")
  adapter=adapterArg; path=.StoragePath~normalize(pathArg); sink=sinkArg
  expectedBytes=expectedArg+0; maximumChunkBytes=maximumChunkArg+0
  if expectedBytes<0 | maximumChunkBytes<1 then raise syntax 88.900 array("invalid staged upload size/bound")
  mediaType=mediaTypeArg~string; ifMatch=ifMatchArg~string; ifNoneMatch=ifNoneMatchArg~string; ifHeader=ifHeaderArg~string
  receivedBytes=0; state=.WebDavUploadState~NEW; cleanupComplete=.false

::method begin
  expose sink expectedBytes state
  if state<>.WebDavUploadState~NEW then raise syntax 88.900 array("upload session already started")
  sink~openAt(0,expectedBytes)
  state=.WebDavUploadState~RECEIVING
  return self

::method remainingBytes
  expose expectedBytes receivedBytes
  return expectedBytes-receivedBytes

::method nextMaximum
  expose expectedBytes receivedBytes maximumChunkBytes state
  if state<>.WebDavUploadState~RECEIVING then return 0
  left=expectedBytes-receivedBytes
  if left<maximumChunkBytes then return left
  return maximumChunkBytes

::method acceptChunk
  expose sink expectedBytes receivedBytes maximumChunkBytes state
  use arg dataArg
  if state<>.WebDavUploadState~RECEIVING then return .false
  data=dataArg
  n=data~length
  if n<1 | n>maximumChunkBytes | receivedBytes+n>expectedBytes then return .false
  written=sink~writeChunk(data)
  if written<>n then do; state=.WebDavUploadState~FAILED; return .false; end
  sink~flush
  receivedBytes+=n
  return .true

::method abort
  expose sink state cleanupComplete
  if state=.WebDavUploadState~COMMITTED then return .false
  sink~close
  if sink~hasMethod("ABORT") then cleanupComplete=sink~abort
  else cleanupComplete=.false
  state=.WebDavUploadState~ABORTED
  return cleanupComplete

::method commit
  expose adapter path sink expectedBytes receivedBytes state mediaType ifMatch ifNoneMatch ifHeader cleanupComplete
  if state<>.WebDavUploadState~RECEIVING then
    return .WebDavUploadCommitResult~new(.false,409,"INVALID_STATE","upload is not receiving",.nil)
  if receivedBytes<>expectedBytes then
    return .WebDavUploadCommitResult~new(.false,409,"INCOMPLETE_UPLOAD","received byte count does not match Content-Length",.nil)
  sink~flush; sink~close
  outcome=adapter~commitStagedSink(path,sink,expectedBytes,mediaType,ifMatch,ifNoneMatch,ifHeader)
  if outcome~ok then do
    state=.WebDavUploadState~COMMITTED; cleanupComplete=.true
    return .WebDavUploadCommitResult~new(.true,outcome~status,outcome~code,outcome~message,outcome~ref)
  end
  state=.WebDavUploadState~FAILED
  return .WebDavUploadCommitResult~new(.false,outcome~status,outcome~code,outcome~message,outcome~ref)

/* Host-neutral binding contract.  A future HTTPS server streaming request API
 * only needs to create a session, call begin(), feed chunks no larger than
 * nextMaximum(), then commit() or abort(). */
::class WebDavStreamingIngressFactory public
::method init
  expose adapter maximumChunkBytes
  use arg adapterArg,maximumChunkArg=8388608
  adapter=adapterArg; maximumChunkBytes=maximumChunkArg+0
  if adapter==.nil | maximumChunkBytes<1 then raise syntax 88.900 array("invalid WebDAV streaming ingress factory")
::method localFileSession
  expose adapter maximumChunkBytes
  use arg pathArg,stagingPathArg,expectedArg,mediaTypeArg="application/octet-stream",ifMatchArg="",ifNoneMatchArg="",ifHeaderArg=""
  sink=.WebDavLocalStagedSink~new(stagingPathArg)
  return .WebDavStreamingUploadSession~new(adapter,pathArg,sink,expectedArg,mediaTypeArg,maximumChunkBytes,ifMatchArg,ifNoneMatchArg,ifHeaderArg)

::requires "WebDavCore.cls"
::requires "StorageStreaming.cls"
