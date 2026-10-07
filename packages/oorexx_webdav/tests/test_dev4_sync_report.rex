cat=.StorageCatalogue~new
env=.StorageEnvironment~new('SYNC',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('SYNC',cat,env)
ad=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
call must ad~makeCollection('/docs')~ok,'mkcol'
call must ad~putBytes('/docs/a','A','text/plain')~ok,'put a'
token=ad~syncToken
call must ad~putBytes('/docs/b','B','text/plain')~ok,'put b'
call must ad~deletePath('/docs/a')~ok,'delete a'

syncOutcome=ad~syncChanges(token,'/docs',100)
call must syncOutcome~ok,'sync token accepted'
call eq syncOutcome~changes~items,2,'two incremental changes'
call eq syncOutcome~changes[1]~path,'/docs/b','put path'
call eq syncOutcome~changes[2]~path,'/docs/a','delete path'
call eq syncOutcome~changes[2]~status,404,'delete projects 404'
call must syncOutcome~token<>token,'token advances'

/* HTTPS REPORT initial + incremental */
http=.WebDavHttpsAdapter~new(ad,'/dav')
body='<D:sync-collection xmlns:D="DAV:"><D:sync-token>'||token||'</D:sync-token><D:sync-level>infinity</D:sync-level></D:sync-collection>'
req=.HttpRequest~new('REPORT','/dav/docs','','','',.directory~new,body,.true)
r=http~beforeRequest(req,.nil)
call eq r~status,207,'REPORT status'
call must r~body~pos('/dav/docs/b')>0,'REPORT contains changed put'
call must r~body~pos('404 Not Found')>0,'REPORT contains deletion'
call must r~body~pos('sync-token')>0,'REPORT returns token'

initial='<D:sync-collection xmlns:D="DAV:"><D:sync-token/></D:sync-collection>'
req=.HttpRequest~new('REPORT','/dav/docs','','','',.directory~new,initial,.true)
r=http~beforeRequest(req,.nil)
call eq r~status,207,'initial REPORT'
call must r~body~pos('/dav/docs/b')>0,'initial sync enumerates current member'

say 'WEBDAV DEV4 SYNC REPORT: OK'
exit 0
must: procedure; use arg c,l; if \c then do; say 'FAIL:' l; exit 1; end; return
eq: procedure; use arg a,e,l; if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'WebDavHttpsAdapter.cls'
