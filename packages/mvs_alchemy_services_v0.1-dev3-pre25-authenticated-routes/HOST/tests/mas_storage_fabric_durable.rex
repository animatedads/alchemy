/* Durable/restartable Storage Fabric PATH qualification. */
root='/tmp/mas-storage-fabric-durable-test'
call SysFileTree root,'old.','FOS'
do i=1 to old.0; call SysFileDelete old.i; end
call SysRmDir root||'/objects'
call SysFileDelete root||'/objects.journal'
call SysRmDir root

store=.MasHostStorageFabricStore~new(root,'ED209Z-USS',.StorageWritePolicy~DIRECT)
svc=.MasStorageFabricDsfsService~new(store)
d=.MasPathSessionDispatcher~new(svc)

r=d~open('/u/USER/sample.txt','OWRONLY OCREAT OTRUNC','TEXT')
call assertTrue r~ok,'open create'
h=r~value
call assertEqual 12,d~write(h,'HELLO WORLD'||'0a'x)~value,'write'
r1=d~close(h)~value
call assertTrue r1<>.nil,'close ref1'

r=d~open('/u/USER/sample.txt','ORDWR OAPPEND','TEXT')
h=r~value
ignore=d~append(h,'SECOND'||'0a'x)
r2=d~close(h)~value
call assertTrue r2~objectId<>r1~objectId,'version changes'
call assertEqual 2,store~catalogue~count,'two immutable objects'

/* Simulate daemon restart: reconstruct Storage catalogue and namespace from journal. */
store2=.MasHostStorageFabricStore~new(root,'ED209Z-USS',.StorageWritePolicy~DIRECT)
svc2=.MasStorageFabricDsfsService~new(store2)
d2=.MasPathSessionDispatcher~new(svc2)
call assertEqual 2,store2~catalogue~count,'catalogue reload'
r=d2~open('/u/USER/sample.txt','ORDONLY','TEXT')
call assertEqual 'HELLO WORLD'||'0a'x||'SECOND'||'0a'x,d2~read(r~value)~value,'restart read'
ignore=d2~close(r~value)
call assertEqual r2~objectId,store2~resolve('/u/USER/sample.txt')~objectId,'namespace reload current ref'

say 'PASS MAS_STORAGE_FABRIC_DURABLE'
say 'ROOT='root
say 'REF1='r1~objectId
say 'REF2='r2~objectId
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 2; end
  return
assertTrue: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 2; end
  return

::requires '../src/MasStorageFabricDsfs.cls'
