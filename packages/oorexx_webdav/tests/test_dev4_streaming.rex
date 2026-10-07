cat=.StorageCatalogue~new
env=.StorageEnvironment~new('STREAM',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('STREAM',cat,env)
ad=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
call must ad~makeCollection('/data')~ok,'mkcol'

/* Large object exists only as StorageByteSource: no whole body in DAV store. */
ref=.StorageRef~new('large-object','sha256:synthetic')
obj=.StorageObject~new(ref,'large.bin',20971520,'application/octet-stream')
cat~put(obj); ns~bind('/data/large.bin',ref,.StorageWritePolicy~DIRECT)
source=.PatternByteSource~new(20971520,'Z')
ad~registerByteSource(ref,source)

http=.WebDavHttpsAdapter~new(ad,'/dav')
h=.directory~new; h['Range']='bytes=100-199'
req=.HttpRequest~new('GET','/dav/data/large.bin','','','',h,'',.true)
r=http~beforeRequest(req,.nil)
call eq r~status,206,'large ranged GET'
call eq r~body~length,100,'bounded range length'
call eq r~body,copies('Z',100),'bounded range content'
call must source~largestRead<=100,'source never asked for whole object'

h=.directory~new
req=.HttpRequest~new('HEAD','/dav/data/large.bin','','','',h,'',.true)
r=http~beforeRequest(req,.nil)
call eq r~status,200,'stream HEAD'
call eq r~headers['Content-Length'],20971520,'stream size without whole read'
call eq r~body,'','HEAD body empty'

req=.HttpRequest~new('GET','/dav/data/large.bin','','','',.directory~new,'',.true)
r=http~beforeRequest(req,.nil)
call eq r~status,501,'unbounded full GET fails closed until HTTPS streaming response exists'

/* Bounded source -> StorageByteSink ingestion and SHA-256 identity. */
small=.PatternByteSource~new(1048576,'Q')
sinkPath='/tmp/oorexx-webdav-dev4-stream-'||time('S')||'.bin'
address system 'rm -f' sinkPath
sink=.StorageLocalFileByteSink~new(sinkPath)
mr=ad~putFromSource('/data/upload.bin',small,sink,'application/octet-stream','','','',65536)
call must mr~ok,'bounded streamed PUT'
call must left(mr~ref~digest,7)='sha256:','stream identity is SHA-256'
call must small~largestRead<=65536,'PUT source bounded to configured chunk'
part=ad~readRange('/data/upload.bin',131072,64,1024)
call eq part,copies('Q',64),'uploaded source readable by bounded range'
address system 'rm -f' sinkPath

say 'WEBDAV DEV4 BOUNDED BYTE PLANE: OK'
exit 0

must: procedure; use arg c,l; if \c then do; say 'FAIL:' l; exit 1; end; return
eq: procedure; use arg a,e,l; if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return

::class PatternByteSource
::attribute sizeBytes get
::attribute largestRead get
::method init
  expose sizeBytes position opened pattern largestRead
  use arg sizeArg,patternArg
  sizeBytes=sizeArg+0; pattern=patternArg~string; position=0; opened=.false; largestRead=0
::method resumeIdentity
  expose sizeBytes pattern
  return 'PATTERN|'||pattern||'|'||sizeBytes
::method openAt
  expose sizeBytes position opened
  use arg offsetArg=0
  offset=offsetArg+0
  if offset<0 | offset>sizeBytes then raise syntax 88.900 array('bad offset')
  position=offset; opened=.true; return self
::method readChunk
  expose sizeBytes position opened pattern largestRead
  use arg maximumArg
  if \opened then raise syntax 88.900 array('not open')
  maximum=maximumArg+0
  if maximum>largestRead then largestRead=maximum
  remaining=sizeBytes-position
  if remaining<=0 then return .StorageByteChunk~new(position,'',.true)
  n=maximum; if n>remaining then n=remaining
  data=copies(pattern,n)
  c=.StorageByteChunk~new(position,data,(position+n>=sizeBytes))
  position+=n
  return c
::method close
  expose opened
  opened=.false; return self

::requires 'WebDavHttpsAdapter.cls'
