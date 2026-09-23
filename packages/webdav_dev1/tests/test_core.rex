cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAVTEST',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAV',cat,env)
ad=.WebDavStorageAdapter~new(ns)
call must ad~makeCollection('/docs')~ok,'MKCOL'
r=ad~putBytes('/docs/hello.txt','hello webdav','text/plain')
call must r~ok,'PUT new'
call eq ad~getBytes('/docs/hello.txt'),'hello webdav','GET body'
et=ad~etag('/docs/hello.txt')
call must et<>'','etag present'
call must ad~putBytes('/docs/hello.txt','bad','text/plain','"wrong"')~status=412,'If-Match blocks'
r=ad~putBytes('/docs/hello.txt','new','text/plain',et)
call must r~ok,'If-Match allows'
call eq ad~getBytes('/docs/hello.txt'),'new','replacement visible'
call must env~generation>=3,'generation advances'
paths=.array~new; paths~append('/docs'); paths~append('/docs/hello.txt')
xml=.WebDavXml~multistatus(ad,paths)
call must xml~pos('<D:multistatus')>0,'multistatus'
call must xml~pos('hello.txt')>0,'child present'
call must ad~deletePath('/docs/hello.txt')~ok,'DELETE file'
call must \ad~exists('/docs/hello.txt'),'file absent'
call must ad~deletePath('/docs')~ok,'DELETE empty collection'
say 'WEBDAV CORE: OK'
exit 0
must: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
eq: procedure
  use arg actual,expected,label
  if actual<>expected then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'WebDavCore.cls'
