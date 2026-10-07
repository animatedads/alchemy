cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAV3HTTP',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAV3HTTP',cat,env)
storage=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
adapter=.WebDavHttpsAdapter~new(storage,'/dav')

h=.directory~new
req=.HttpRequest~new('MKCOL','/dav/docs','','','',h,'',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,201,'MKCOL'

h=.directory~new; h['Content-Type']='text/plain'
req=.HttpRequest~new('PUT','/dav/docs/range.txt','','','',h,'0123456789',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,201,'PUT'

h=.directory~new; h['Range']='bytes=2-5'
req=.HttpRequest~new('GET','/dav/docs/range.txt','','','',h,'',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,206,'range status'; call eq r~body,'2345','range body'
call eq r~headers['Content-Range'],'bytes 2-5/10','content range'

h=.directory~new; h['Destination']='/dav/docs/copied.txt'
req=.HttpRequest~new('COPY','/dav/docs/range.txt','','','',h,'',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,201,'COPY'
call eq storage~getBytes('/docs/copied.txt'),'0123456789','copy via http'

h=.directory~new; h['Destination']='/dav/docs/moved.txt'
req=.HttpRequest~new('MOVE','/dav/docs/copied.txt','','','',h,'',.true)
r=adapter~beforeRequest(req,.nil); call must r~status=201 | r~status=204,'MOVE'
call must \storage~exists('/docs/copied.txt'),'move old absent'

body='<D:propertyupdate xmlns:D="DAV:"><D:set><D:prop><Z:colour xmlns:Z="urn:test">blue</Z:colour></D:prop></D:set></D:propertyupdate>'
req=.HttpRequest~new('PROPPATCH','/dav/docs/moved.txt','','','',.directory~new,body,.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,207,'PROPPATCH'
call eq storage~deadProperties('/docs/moved.txt')[1]~value,'blue','dead prop value'

h=.directory~new; h['Depth']='infinity'
req=.HttpRequest~new('PROPFIND','/dav/docs','','','',h,'<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,207,'PROPFIND infinity'; call must r~body~pos('moved.txt')>0,'child in multistatus'

lockBody='<D:lockinfo xmlns:D="DAV:"><D:lockscope><D:exclusive/></D:lockscope><D:locktype><D:write/></D:locktype><D:owner>architect</D:owner></D:lockinfo>'
h=.directory~new; h['Depth']='0'; h['Timeout']='Second-60'
req=.HttpRequest~new('LOCK','/dav/docs/moved.txt','','','',h,lockBody,.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,200,'LOCK'
token=r~headers['Lock-Token']; call must token<>.nil,'lock token'

h=.directory~new; h['Content-Type']='text/plain'
req=.HttpRequest~new('PUT','/dav/docs/moved.txt','','','',h,'blocked',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,423,'locked PUT'

h=.directory~new; h['Lock-Token']=token
req=.HttpRequest~new('UNLOCK','/dav/docs/moved.txt','','','',h,'',.true)
r=adapter~beforeRequest(req,.nil); call eq r~status,204,'UNLOCK'

say 'WEBDAV DEV3 HTTPS SEMANTICS: OK'
exit 0
must: procedure; use arg c,l; if \c then do; say 'FAIL:' l; exit 1; end; return
eq: procedure; use arg a,e,l; if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'WebDavHttpsAdapter.cls'
