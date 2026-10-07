cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAVQ3',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAVQ3',cat,env)
ad=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
x=ad~makeCollection('/q')
x=ad~putBytes('/q/source','queued-object','text/plain')

m=.WebDavQueueMutation~new(.WebDavQueueProtocol~COPY,'/q/source','','application/octet-stream','','','','/q/copy',.true,'infinity')
manager=.FakeManager~new(m)
service=.WebDavQueueService~new(manager,'WEBDAV.MUTATE','dav-worker',ad)
r=service~serveOne
call must r~ok,'typed COPY mutation'
call eq ad~getBytes('/q/copy'),'queued-object','queue COPY result'
call must manager~payload==m,'full ooRexx queue mutation object preserved'
call eq manager~ackCount,1,'ACK after execution'

patches=.array~new
patches~append(.WebDavPropertyPatch~new('SET','urn:test','queueprop','yes'))
m2=.WebDavQueueMutation~new(.WebDavQueueProtocol~PROPPATCH,'/q/copy','','','','','','',.true,'infinity',patches)
manager2=.FakeManager~new(m2)
service2=.WebDavQueueService~new(manager2,'WEBDAV.MUTATE','dav-worker',ad)
r=service2~serveOne
call must r~ok,'typed PROPPATCH mutation'
call eq ad~deadProperties('/q/copy')[1]~value,'yes','queued property object retained'

say 'WEBDAV DEV3 QUEUE OBJECTS: OK'
exit 0

must: procedure
  use arg c,l
  if \c then do; say 'FAIL:' l; exit 1; end
  return
eq: procedure
  use arg a,e,l
  if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return

::class FakeResult
::attribute ok get
::attribute value get
::method init
 expose ok value
 use arg okArg,valueArg=.nil
 ok=(okArg==.true); value=valueArg

::class FakePackage
::attribute packageId get
::attribute claimToken get
::attribute payload get
::method init
 expose packageId claimToken payload
 use arg payloadArg
 packageId='pkg-1'; claimToken='claim-1'; payload=payloadArg

::class FakeManager
::attribute payload get
::attribute ackCount get
::method init
 expose payload ackCount
 use arg payloadArg
 payload=payloadArg; ackCount=0
::method claim
 expose payload
 use arg queue,principal
 return .FakeResult~new(.true,.FakePackage~new(payload))
::method ack
 expose ackCount
 use arg queue,packageId,claimToken,principal
 ackCount+=1
 return .FakeResult~new(.true,.nil)

::requires 'WebDavQueue.cls'
