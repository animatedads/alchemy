cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAVHTTP',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAVHTTP',cat,env)
storage=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
adapter=.WebDavHttpsAdapter~new(storage,'/dav')
headers=.directory~new
request=.HttpRequest~new('MKCOL','/dav/docs','/dav/docs','', 'HTTP/1.1',headers,'',.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,201,'MKCOL status'
headers=.directory~new; headers['content-type']='text/plain'
request=.HttpRequest~new('PUT','/dav/docs/a.txt','/dav/docs/a.txt','', 'HTTP/1.1',headers,'alpha',.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,201,'PUT status'; et=r~headers['ETag']; call must et<>.nil,'PUT etag'
headers=.directory~new; headers['depth']='1'
request=.HttpRequest~new('PROPFIND','/dav/docs','/dav/docs','', 'HTTP/1.1',headers,'',.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,207,'PROPFIND status'; call must r~body~pos('a.txt')>0,'PROPFIND child'
request=.HttpRequest~new('GET','/dav/docs/a.txt','/dav/docs/a.txt','', 'HTTP/1.1',.directory~new,'',.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,200,'GET status'; call eq r~body,'alpha','GET body'

headers=.directory~new; headers['content-type']='application/vnd.oorexx.card-deck.ascii'
request=.HttpRequest~new('PUT','/dav/docs/job.deck','/dav/docs/job.deck','', 'HTTP/1.1',headers,'//JOB1 JOB' || '0A'x || '//S EXEC PGM=IEFBR14' || '0A'x,.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,201,'media PUT status'
o=storage~objectAt('/docs/job.deck'); call eq o~eaValue('storage.media.family',''),.StorageSequentialMediaFamily~CARD_DECK,'media family EA'
headers=.directory~new; headers['accept']='text/plain'
request=.HttpRequest~new('GET','/dav/docs/job.deck','/dav/docs/job.deck','', 'HTTP/1.1',headers,'',.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,200,'media GET status'; call must r~body~pos('//JOB1 JOB')>0,'media GET projection'

request=.HttpRequest~new('OPTIONS','/dav/','/dav/','', 'HTTP/1.1',.directory~new,'',.true)
r=adapter~beforeRequest(request,.nil); call eq r~status,204,'OPTIONS status'; call must r~headers['DAV']<>.nil,'DAV header'
say 'WEBDAV HTTPS ADAPTER: OK'; exit 0
must: procedure; use arg condition,label; if \condition then do; say 'FAIL:' label; exit 1; end; return
eq: procedure; use arg actual,expected,label; if actual<>expected then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end; return
::requires 'WebDavHttpsAdapter.cls'
