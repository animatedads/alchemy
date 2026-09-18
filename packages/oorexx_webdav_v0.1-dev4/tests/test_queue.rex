cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAVQ',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAVQ',cat,env)
ad=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
call must ad~makeCollection('/q')~ok,'mkcol setup'
manager=.ObjectQueueManager~new('',.nil,'admin')
call must manager~createQueue('WEBDAV.MUTATE','TEMPORARY','WEBDAV',0,'admin')~ok,'create queue'
call must manager~grant('WEBDAV.MUTATE','dav-worker',.QueueAccess~GET,'admin')~ok,'grant get'
call must manager~grant('WEBDAV.MUTATE','dav-edge',.QueueAccess~PUT,'admin')~ok,'grant put'
p=.directory~new
p['op']=.WebDavQueueProtocol~PUT; p['path']='/q/fromqueue.txt'; p['body']='queued'; p['contentType']='text/plain'; p['ifMatch']=''; p['ifNoneMatch']=''
call must manager~put('WEBDAV.MUTATE',p,.nil,'dav-edge')~ok,'queue put'
service=.WebDavQueueService~new(manager,'WEBDAV.MUTATE','dav-worker',ad)
r=service~serveOne
call must r~ok,'service mutation'; call eq ad~getBytes('/q/fromqueue.txt'),'queued','queued bytes'
call eq manager~depth('WEBDAV.MUTATE','admin')~value['total'],0,'acked'
say 'WEBDAV QUEUE: OK'; exit 0
must: procedure; use arg condition,label; if \condition then do; say 'FAIL:' label; exit 1; end; return
eq: procedure; use arg actual,expected,label; if actual<>expected then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end; return
::requires 'WebDavQueue.cls'
