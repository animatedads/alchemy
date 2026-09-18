call RxFuncAdd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
root=SysTempFileName('/tmp/webdav-paper-??????'); call SysMkDir root
printer=root||'/prt00e.txt'
call charout printer,'PAGE ONE' || '0A'x || 'LINE TWO' || '0A'x || '0C'x || 'PAGE TWO' || '0A'x
call stream printer,'c','close'
img=.WebDavHerculesPaperBridge~importPrinterFile('JOB001-LISTING',printer)
call assert img~family=.StorageSequentialMediaFamily~PAPER_LISTING,'wrong family'
call assert img~dataRecordCount=3,'wrong line count'
call assert img~boundaryCount=1,'page break lost'
cat=.StorageCatalogue~new; env=.StorageEnvironment~new('dav-paper','LIVE','',0,0,'DIRECT'); ns=.StorageNamespace~new('dav',cat,env)
a=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
r=.WebDavHerculesPaperBridge~publishToWebDav(a,'/listing.txt','JOB001-LISTING',printer)
call assert r~ok,'publish failed'
rr=a~getRepresentation('/listing.txt','text/plain')
call assert rr<>.nil,'render missing'
call assert rr~body='PAGE ONE'||'0A'x||'LINE TWO'||'0A'x||'0C'x||'PAGE TWO'||'0A'x,'render differs'
o=a~objectAt('/listing.txt')
call assert o~eaValue('storage.media.family','')=.StorageSequentialMediaFamily~PAPER_LISTING,'EA family absent'
say 'WEBDAV HERCULES PAPER: OK'
exit 0
assert: procedure
  parse arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'WebDavHerculesPaper.cls'
