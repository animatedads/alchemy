numeric digits 50
srcRoot=SysTempFileName('/tmp/storage-host-src-??????')
dstRoot=SysTempFileName('/tmp/storage-host-dst-??????')
ckRoot=SysTempFileName('/tmp/storage-host-ck-??????')
call SysMkDir srcRoot
call SysMkDir dstRoot
call SysMkDir ckRoot

signal on syntax name TestFailed

call SysMkDir srcRoot||'/docs'
body=copies('0123456789abcdef',196608) /* 3 MiB */
call charout srcRoot||'/docs/big.bin',body
call stream srcRoot||'/docs/big.bin','c','close'
call charout srcRoot||'/small.txt','hello storage backup floor'
call stream srcRoot||'/small.txt','c','close'
address system '/bin/ln -s -- small.txt '||q(srcRoot||'/small-link')
if rc<>0 then raise syntax 88.900 array('cannot make source symlink')
address system '/bin/ln -s -- /etc '||q(srcRoot||'/escape-dir')
if rc<>0 then raise syntax 88.900 array('cannot make escape symlink')

sourceDigestBefore=digest(srcRoot||'/docs/big.bin')
helper='build/storage-host-commit'
src=.StorageHostFilesystemMount~new('linux-source',srcRoot,'READ_ONLY',helper)
dst=.StorageHostFilesystemMount~new('usb3-destination',dstRoot,'WRITE_COMMIT',helper)

call assertTrue src~readOnly,'source policy read only'
call assertTrue dst~writeCommit,'destination write/commit policy'
call assertTrue \src~kernelReadOnly,'throwaway source filesystem is not kernel-ro; policy remains ro'

/* The mechanical source mount exposes filesystem identity so an audit/backup
 * task can stop at mount boundaries.  byteSource itself refuses cross-device
 * content, preventing /proc or the USB destination from being copied through
 * a root mount by mistake. */
rootSource=.StorageHostFilesystemMount~new('machine-root','/','READ_ONLY',helper)
procEntry=rootSource~entry('proc/version')
if procEntry<>.nil then do
  call assertTrue \rootSource~sameFilesystem(procEntry),'proc is reported as a filesystem boundary'
  call assertCrossFilesystemDenied rootSource,'proc/version'
end

/* Same-filesystem source/destination is rejected by production preflight; the
 * explicit false qualifier exists only for throwaway qualification fixtures. */
pf=.StorageHostBackupPreflight~run(src,dst,'.sf-test-checkpoints',.false,.true)
call assertTrue \pf['ok'],'same-filesystem production preflight rejected'
pfTest=.StorageHostBackupPreflight~run(src,dst,'.sf-test-checkpoints',.false,.false)
call assertTrue pfTest['ok'],'qualification preflight exercises destination commit primitives'

entries=src~list('')
call assertEq 4,entries~items,'root listing count'
link=src~entry('small-link')
call assertTrue link~symbolicLink,'symlink observed without following'
call assertEq 'small.txt',link~symlinkTarget,'symlink target retained'
file=src~entry('docs/big.bin')
call assertTrue file~regularFile,'regular file identified'
call assertEq length(body),file~sizeBytes,'regular file size'

failed=.false
signal on syntax name TraversalDenied
ignore=src~entry('../escape')
signal off syntax
signal AfterTraversal
TraversalDenied:
  failed=.true
  signal off syntax
AfterTraversal:
call assertTrue failed,'relative traversal denied'

failed=.false
signal on syntax name SymlinkReadDenied
ignore=src~byteSource('small-link')
signal off syntax
signal AfterSymlink
SymlinkReadDenied:
  failed=.true
  signal off syntax
AfterSymlink:
call assertTrue failed,'symlink not followed as regular source bytes'


failed=.false
signal on syntax name AncestorEscapeDenied
ignore=src~byteSource('escape-dir/passwd')
signal off syntax
signal AfterAncestorEscape
AncestorEscapeDenied:
  failed=.true
  signal off syntax
AfterAncestorEscape:
call assertTrue failed,'ancestor symlink escape denied before source read'

/* Destination traversal through a symlink component is also denied. */
evil=SysTempFileName('/tmp/storage-host-evil-??????')
call SysMkDir evil
address system '/bin/ln -s -- '||q(evil)||' '||q(dstRoot||'/escape')
if rc<>0 then raise syntax 88.900 array('cannot make destination escape symlink')
failed=.false
signal on syntax name DestinationEscapeDenied
ignore=dst~ensureDirectory('escape/subdir')
signal off syntax
signal AfterDestinationEscape
DestinationEscapeDenied:
  failed=.true
  signal off syntax
AfterDestinationEscape:
call assertTrue failed,'destination symlink component escape denied'
address system '/bin/rm -rf -- '||q(evil)


/* Predictable/stale partial and final names may not be symlinks. */
attackSink=dst~atomicSink('backup/partial-attack.bin','tx-partial-attack',1)
address system '/bin/ln -s -- /etc/passwd '||q(attackSink~tempPath)
if rc<>0 then raise syntax 88.900 array('cannot make partial attack symlink')
failed=.false
signal on syntax name PartialSymlinkDenied
attackSink~openAt(0,1)
signal off syntax
signal AfterPartialSymlink
PartialSymlinkDenied:
  failed=.true
  signal off syntax
AfterPartialSymlink:
call assertTrue failed,'partial symlink refused before open'
address system '/bin/rm -f -- '||q(attackSink~tempPath)

address system '/bin/ln -s -- /etc/passwd '||q(dstRoot||'/backup/final-attack.bin')
if rc<>0 then raise syntax 88.900 array('cannot make final attack symlink')
failed=.false
signal on syntax name FinalSymlinkDenied
ignore=dst~atomicSink('backup/final-attack.bin','tx-final-attack',1)
signal off syntax
signal AfterFinalSymlink
FinalSymlinkDenied:
  failed=.true
  signal off syntax
AfterFinalSymlink:
call assertTrue failed,'final symlink collision refused'
address system '/bin/rm -f -- '||q(dstRoot||'/backup/final-attack.bin')

failed=.false
signal on syntax name SourceWriteDenied
ignore=src~atomicSink('illegal','tx-illegal',1)
signal off syntax
signal AfterSourceWrite
SourceWriteDenied:
  failed=.true
  signal off syntax
AfterSourceWrite:
call assertTrue failed,'read-only mount rejects destination sink'

copier=.StorageHostVerifiedCopy~new(1048576)
checkpoint=ckRoot||'/big-copy'
first=copier~copyFile(src,'docs/big.bin',dst,'backup/docs/big.bin','tx-big',checkpoint,1)
call assertEq 'PAUSED',first~status,'first run pauses after one durable chunk'
call assertTrue stream(dstRoot||'/backup/docs/big.bin','c','query exists')='','final name absent before verification/commit'
partials=0
address system '/usr/bin/find -P '||q(dstRoot||'/backup/docs')||" -maxdepth 1 -name '.sf-partial-*' -type f | /usr/bin/wc -l > "||q(dstRoot||'/partials.count')
partials=linein(dstRoot||'/partials.count')+0
call stream dstRoot||'/partials.count','c','close'
call SysFileDelete dstRoot||'/partials.count'
call assertEq 1,partials,'one hidden partial exists after pause'

second=copier~copyFile(src,'docs/big.bin',dst,'backup/docs/big.bin','tx-big',checkpoint,0)
call assertTrue second~ok,'resume completes'
call assertEq 'COMMITTED',second~status,'verified bytes published'
call assertEq length(body),second~bytes,'committed byte count'
call assertTrue left(second~verificationRef,7)='sha256:','verification reference is SHA-256'
call assertTrue stream(dstRoot||'/backup/docs/big.bin','c','query exists')<>'','final exists only after commit'
call assertEq digest(srcRoot||'/docs/big.bin'),digest(dstRoot||'/backup/docs/big.bin'),'destination digest equals source'

/* Same verified object can be repeated safely; it is not rewritten in place. */
idem=copier~copyFile(src,'docs/big.bin',dst,'backup/docs/big.bin','tx-big-idem',ckRoot||'/big-idem',0)
call assertTrue idem~ok,'idempotent same-content copy accepted'
call assertEq 'ALREADY_COMMITTED',idem~status,'existing identical final reconciled'

/* Different content may not replace an already committed final pathname. */
call charout srcRoot||'/docs/other.bin','DIFFERENT CONTENT'
call stream srcRoot||'/docs/other.bin','c','close'
originalDigest=digest(dstRoot||'/backup/docs/big.bin')
collision=copier~copyFile(src,'docs/other.bin',dst,'backup/docs/big.bin','tx-collision',ckRoot||'/collision',0)
call assertTrue \collision~ok,'different existing final rejected'
call assertEq originalDigest,digest(dstRoot||'/backup/docs/big.bin'),'collision leaves committed final unchanged'

/* A changed source invalidates an existing resume checkpoint. */
changeCp=ckRoot||'/changing'
paused=copier~copyFile(src,'small.txt',dst,'backup/changing.txt','tx-changing',changeCp,0)
call assertTrue paused~ok,'small source initial copy committed'
/* use a new destination path so we can exercise paused resume identity */
call charout srcRoot||'/changing.bin',copies('A',2097152)
call stream srcRoot||'/changing.bin','c','close'
p=copier~copyFile(src,'changing.bin',dst,'backup/changing2.bin','tx-changing2',ckRoot||'/changing2',1)
call assertEq 'PAUSED',p~status,'changing source paused'
call SysSleep 0.02
call charout srcRoot||'/changing.bin',copies('B',2097152),1
call stream srcRoot||'/changing.bin','c','close'
r=copier~copyFile(src,'changing.bin',dst,'backup/changing2.bin','tx-changing2',ckRoot||'/changing2',0)
call assertTrue \r~ok,'changed source cannot resume old checkpoint'
call assertTrue stream(dstRoot||'/backup/changing2.bin','c','query exists')='','changed source never published'
call assertEq sourceDigestBefore,digest(srcRoot||'/docs/big.bin'),'backup floor never mutated source file'

say 'PASS host filesystem read-only source / USB write-commit / verified resume floor'
call cleanup srcRoot,dstRoot,ckRoot
exit 0

TestFailed:
  say 'FAIL host filesystem provider' condition('D')
  call cleanup srcRoot,dstRoot,ckRoot
  exit 1

cleanup:
  use arg a,b,c
  address system '/bin/rm -rf -- '||q(a)||' '||q(b)||' '||q(c)
  return

q:
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

digest:
  use arg p
  tmp=SysTempFileName('/tmp/storage-host-test-sha-??????')
  address system '/usr/bin/sha256sum -- '||q(p)||' > '||q(tmp)
  if rc<>0 then return ''
  line=linein(tmp); call stream tmp,'c','close'; call SysFileDelete tmp
  return word(line,1)~lower

assertCrossFilesystemDenied:
  procedure
  use arg mount,path
  failed=.false
  signal on syntax name denied
  ignore=mount~byteSource(path)
  signal off syntax
  signal done
denied:
  failed=.true
  signal off syntax
done:
  if \failed then do
    say 'FAIL cross-filesystem source bytes denied'
    raise syntax 88.900 array('test assertion failed: cross-filesystem source bytes denied')
  end
  return

assertTrue:
  use arg value,label
  if \value then do
    say 'FAIL' label
    raise syntax 88.900 array('test assertion failed: '||label)
  end
  return

assertEq:
  use arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    raise syntax 88.900 array('test assertion failed: '||label)
  end
  return

::requires 'src/StorageHostFilesystem.cls'
