call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
root=SysTempFileName('/tmp/webdav-storage-content-??????')
call SysMkDir root
cat=.StorageCatalogue~new
env=.StorageEnvironment~new('dav-test','LIVE','',0,0,'DIRECT')
ns=.StorageNamespace~new('dav',cat,env)
content=.WebDavStorageContentProvider~new(root,'webdav-test','posixfs:test','node-test',7)
adapter=.WebDavStorageAdapter~new(ns,content)
r=adapter~putBytes('/hello.bin','abcdefghijklmnopqrstuvwxyz','application/octet-stream')
call assert r~ok, 'put failed'
o=adapter~objectAt('/hello.bin')
call assert o<>.nil, 'object absent'
call assert o~availableLocations~items=1, 'durable location absent'
loc=o~availableLocations[1]
call assert loc~verified, 'location not verified'
call assert left(loc~verificationRef,7)='sha256:', 'verification not sha256'
call assert stream(loc~locator,'c','query exists')<>'', 'location file absent'
rr=adapter~getRepresentation('/hello.bin','application/octet-stream')
call assert rr<>.nil, 'GET representation absent'
call assert rr~body='abcdefghijklmnopqrstuvwxyz', 'GET bytes differ'
d=adapter~deletePath('/hello.bin')
call assert d~ok, 'unlink failed'
call assert stream(loc~locator,'c','query exists')<>'', 'unlink physically destroyed content'
say 'WEBDAV STORAGE CONTENT: OK'
exit 0
assert: procedure
  parse arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'WebDavCore.cls'
