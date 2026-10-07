cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAV3',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAV3',cat,env)
locks=.WebDavLockStore~new
ad=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new,.nil,'/dav',.nil,locks)

call must ad~makeCollection('/docs')~ok,'MKCOL docs'
call must ad~putBytes('/docs/a.txt','abcdefghij','text/plain')~ok,'PUT a'
call must ad~putBytes('/docs/b.txt','bravo','text/plain')~ok,'PUT b'

/* dead properties */
call must ad~setDeadProperty('/docs/a.txt','urn:test','colour','blue'),'set object dead property'
call must ad~setDeadProperty('/docs','urn:test','owner','architect'),'set collection dead property'
call eq ad~deadProperties('/docs')~items,1,'collection property visible'

/* COPY rebinds StorageRef instead of duplicating immutable content. */
before=ns~resolve('/docs/a.txt')~entry~ref
r=ad~copyPath('/docs/a.txt','/docs/copy.txt',.true,'infinity','')
call must r~ok,'COPY file'
after=ns~resolve('/docs/copy.txt')~entry~ref
call must before==after,'COPY preserves StorageRef object identity'
call eq ad~getBytes('/docs/copy.txt'),'abcdefghij','copy bytes visible'

/* MOVE preserves identity and removes old path. */
r=ad~movePath('/docs/copy.txt','/docs/moved.txt',.true,'')
call must r~ok,'MOVE file'
call must \ad~exists('/docs/copy.txt'),'old move path absent'
call must ns~resolve('/docs/moved.txt')~entry~ref==before,'MOVE preserves StorageRef'

/* Collection tree copy. */
call must ad~makeCollection('/tree')~ok,'MKCOL tree'
call must ad~makeCollection('/tree/sub')~ok,'MKCOL tree/sub'
call must ad~putBytes('/tree/sub/x','x','text/plain')~ok,'PUT nested'
r=ad~copyPath('/tree','/treecopy',.true,'infinity','')
call must r~ok,'COPY tree'
call must ad~isCollection('/treecopy/sub'),'copied subcollection'
call eq ad~getBytes('/treecopy/sub/x'),'x','copied nested file'

/* Locks gate mutations and token refresh/unlock works. */
lock=locks~lock('/docs/a.txt','0','architect',3600)
call must lock<>.nil,'LOCK acquired'
r=ad~putBytes('/docs/a.txt','blocked','text/plain','','','')
call eq r~status,423,'locked PUT rejected'
ifh='(< '||lock~token||' >)'
r=ad~putBytes('/docs/a.txt','allowed','text/plain','','',ifh)
call must r~ok,'lock token admits PUT'
call must locks~unlock('/docs/a.txt',lock~token),'UNLOCK'
r=ad~putBytes('/docs/a.txt','free','text/plain')
call must r~ok,'PUT after unlock'

/* bounded infinity traversal */
walk=ad~walk('/',100)
call must walk~items>=8,'Depth infinity walk'

say 'WEBDAV DEV3 CORE FEATURES: OK'
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
