/* Architecture: Tom Dyer. Coding: ChatGPT. */
parse arg root
p = .POSIXProvider~new
s = p~stat(root,'sub/f')
call check s['OK'] & s['SIZE'] = 3 & s['KIND'] == 'file', 'regular metadata'
call check s['INODE'] > 0 & s['LINKS'] > 0, 'inode identity'
call check p~stat(root)['KIND'] == 'folder', 'root metadata'
call check \p~stat(root,'link')['OK'], 'leaf link rejected'
call check \p~stat(root,'escape/passwd')['OK'], 'ancestor link rejected'
call check \p~stat(root,'../etc/passwd')['OK'], 'traversal rejected'
call check \p~stat(root,'/etc/passwd')['OK'], 'absolute path rejected'
call check \p~stat(root,'sub/f'||'00'x||'x')['OK'], 'embedded NUL rejected'
call check \p~stat(root,'missing')['OK'], 'missing path'
call check \p~stat(root'/escape','passwd')['OK'], 'linked root rejected'
call check \p~stat(root,'sub//f')['OK'], 'empty component rejected'
c = p~capacity(root)
call check c['OK'] & c['FRAGMENT_BYTES'] > 0 & c['BLOCKS'] >= c['AVAILABLE_BLOCKS'], 'filesystem capacity'
call check p~pageSize > 0, 'page size'
pr = .ProcessProvider~new
call check pr~capabilities~hasItem('process.run.argv'), 'native execution capability preserved'
call check pr~observe('../self') == .nil, 'invalid pid rejected'
call check pr~observe(0) == .nil, 'zero pid rejected'
call check pr~observe(2147483648) == .nil, 'overflow pid rejected'
pid = SysQueryProcess('PID')
proc = pr~observe(pid)
call check proc \== .nil, 'live process observed'
call check proc~pid = pid & proc~isCurrent, 'process identity current'
runner = .ProcessRunner~new(pr)
spec = .ProcessSpec~new(.Array~of('/bin/echo','native argv'))
r = runner~run(spec)
call check r~succeeded & r~stdout~strip('T','0a'x) == 'native argv', 'existing process runner integration'
spec = .ProcessSpec~new(.Array~of('/bin/false'))
r = runner~run(spec)
call check r~started & r~exitCode = 1 & \r~succeeded, 'nonzero exit preserved'
spec = .ProcessSpec~new(.Array~of('/bin/sleep','2'))
spec~timeoutMs = 50
r = runner~run(spec)
call check r~timedOut, 'timeout preserved'
-- Dev2 persistent roots and scans
r = p~openRoot(root)
call check r['OK'], 'persistent root open'
h = r['ROOT']
call check h~stat('sub/f')['INODE'] = s['INODE'], 'persistent stat identity'
call check \h~stat('link')['OK'], 'persistent leaf symlink denied'
call check \h~stat('escape/passwd')['OK'], 'persistent ancestor symlink denied'
call check \h~stat('../etc')['OK'], 'persistent escape denied'
call check \h~stat('sub//f')['OK'], 'persistent empty component denied'
call check \p~openRoot(root'/escape')['OK'], 'persistent linked root denied'
r = h~scan
call check r['OK'], 'scan open'
cursor = r['CURSOR']
call check \cursor~nextBatch(0)['OK'], 'zero batch denied'
call check \cursor~nextBatch(1025)['OK'], 'oversize batch denied'
seen = .Directory~new
batches = 0
do until b['DONE']
  b = cursor~nextBatch(1)
  if \b['OK'] | b['ENTRIES']~items > 1 then exit 2
  batches += 1
  if batches > 20 then exit 2
  do row over b['ENTRIES']; seen[row['NAME']] = 1; end
end
call check seen~items = 4 & seen~hasIndex('sub') & seen~hasIndex('link') & seen~hasIndex('escape') & seen~hasIndex('movable'), 'paged scan complete including link names'
call check cursor~nextBatch(1)['DONE'], 'stable end of scan'
call check cursor~close['OK'], 'cursor close'
call check \cursor~nextBatch(1)['OK'], 'closed cursor refused'
call check \h~scan('link')['OK'], 'scan symlink denied'
call check \h~scan('sub/f')['OK'], 'scan file denied'
m = p~openRoot(root'/movable')['ROOT']
old = m~stat('marker')['INODE']
address system 'mv' root'/movable' root'/renamed'
if rc <> 0 then exit 2
address system 'mkdir' root'/movable'
if rc <> 0 then exit 2
call check m~stat('marker')['INODE'] = old, 'root identity retained across rename'
call check m~capacity()['OK'] & m~capacity('marker')['OK'], 'renamed root capacity retained'
call check \p~stat(root'/movable','marker')['OK'], 'replacement pathname not followed'
call check m~close['OK'], 'renamed root close'
-- dev7: capacity on the same pinned root, without reopening a pathname.
call check \h~hasMethod('CREATEFILE'), 'no competing create publication method'
call check \h~hasMethod('REPLACEFILE'), 'no competing replace publication method'
call check \p~capabilities~hasItem('fs.replace.cooperative'), 'no publication capability advertised'
cap = h~capacity
call check cap['OK'] & cap['FRAGMENT_BYTES'] > 0, 'pinned root capacity'
call check h~capacity('sub/f')['BLOCKS'] = c['BLOCKS'], 'pinned file filesystem capacity'
call check \h~capacity('link')['OK'], 'capacity leaf symlink denied'
call check \h~capacity('escape/passwd')['OK'], 'capacity ancestor symlink denied'
call check \h~capacity('../etc')['OK'], 'capacity traversal denied'
call check \h~capacity('missing')['OK'], 'capacity missing target denied'
call check \h~capacity('/etc')['OK'], 'capacity absolute target denied'
cursor = h~scan['CURSOR']
call check h~close['OK'], 'root close'
call check \h~stat()['OK'], 'closed root refused'
call check \h~capacity()['OK'], 'closed root capacity refused'
call check \cursor~nextBatch(1)['OK'], 'root close invalidates cursors'
call check \h~close['OK'], 'double close refused'
call check proc~class == .NativeObservedProcess, 'native observation subclass'
call check proc~rssKiB >= 0, 'native page size RSS'
-- Dev3 review probes. Mode is fixed by test.sh.
call check s['MODE'] = 420 & s['MODE_OCTAL'] == '0644', 'numeric and octal modes'
rootObj = p~openRoot(root)['ROOT']
call check \.POSIXRoot~new('1')~stat()['OK'], 'guessed sequential root rejected'
call check \.POSIXCursor~new('2')~nextBatch(1)['OK'], 'guessed sequential cursor rejected'
cur = rootObj~scan['CURSOR']
cur~uninit
call check \cur~nextBatch(1)['OK'], 'cursor uninit releases handle'
rootObj~uninit
call check \rootObj~stat()['OK'], 'root uninit releases handle'
-- A live root invalidates a cursor when explicitly closed or collected.
rootObj = p~openRoot(root)['ROOT']
cur = rootObj~scan['CURSOR']
rootObj~uninit
call check \cur~nextBatch(1)['OK'], 'root uninit invalidates cursor'
-- Exercise collection of abandoned roots and cursors. Allocate in groups
-- to induce GC without relying on a private interpreter API.
do j = 1 to 6
  do k = 1 to 64
    call abandon p, root
  end
  do k = 1 to 2048
    garbage = .Array~new(4096)
  end
end
call check p~openRoot(root)['OK'], 'abandoned roots reclaimed under GC pressure'
-- Stress cursors while their root remains reachable.
rootObj = p~openRoot(root)['ROOT']
do j = 1 to 6
  do k = 1 to 64
    call abandonCursor rootObj
  end
  do k = 1 to 2048
    garbage = .Array~new(4096)
  end
end
call check rootObj~scan['OK'], 'abandoned cursors reclaimed under GC pressure'
call check rootObj~close['OK'], 'remaining root closes after stress'
-- Dev4 read and observation checks
h = p~openRoot(root)['ROOT']
b = h~readAt('sub/f',0,2)
call check b['OK'] & b['DATA'] == 'ab' & b['BYTES'] = 2 & b['NEXT_OFFSET'] = 2 & \b['EOF'], 'bounded first read'
b = h~readAt('sub/f',2,2)
call check b['OK'] & b['DATA'] == 'c' & b['EOF'], 'bounded final read'
b = h~readAt('sub/f',3,2)
call check b['OK'] & b['BYTES'] = 0 & b['EOF'], 'read at EOF'
call check \h~readAt('sub/f',0,0)['OK'], 'zero read denied'
call check \h~readAt('sub/f',0,1048577)['OK'], 'oversize read denied'
call check \h~readAt('link')['OK'], 'read leaf symlink refused'
call check \h~readAt('escape/passwd')['OK'], 'read ancestor symlink refused'
call check \h~readAt('../etc/passwd')['OK'], 'read traversal refused'
call check \h~readAt('sub')['OK'], 'read directory refused'
address system 'mkfifo' root'/fifo'
if rc <> 0 then exit 2
call check \h~readAt('fifo')['OK'], 'read FIFO refused without opening'
address system 'printf "a\\000b" >' root'/binary'
if rc <> 0 then exit 2
b = h~readAt('binary',0,8)
call check b['OK'] & b['DATA'] == '610062'x, 'binary NUL preserved'
call check h~close['OK'], 'read root close'
call check \h~readAt('sub/f')['OK'], 'read closed root refused'
t = proc~threadIds
call check t['OK'] & t['IDS']~hasItem(pid) & t['PID'] = pid, 'own thread enumerated'
f = proc~descriptorIds(1)
call check f['OK'] & f['IDS']~items = 1 & f['TRUNCATED'], 'descriptor limit and truncation'
f = proc~descriptorIds(1024)
call check f['OK'] & f['IDS']~items >= 3 & \f['TRUNCATED'], 'own descriptor ids enumerated'
call check \proc~threadIds(0)['OK'], 'zero process list denied'
call check \proc~descriptorIds(1025)['OK'], 'oversize process list denied'
call check \ShellProcessIds(pid,'0','task',128)['OK'], 'stale process identity refused'
call check \ShellProcessIds(pid,t['START_TICKS'],'../fd',128)['OK'], 'unknown process list kind refused'
-- Dev5 pinned reader and process details.
numeric digits 20
h = p~openRoot(root)['ROOT']
r = h~openReader('sub/f')
call check r['OK'], 'reader open'
reader = r['READER']
call check reader~stat['INODE'] = s['INODE'], 'reader pinned inode'
call check reader~readAt(1,2)['DATA'] == 'bc', 'reader random seek'
address system 'mv' root'/sub/f' root'/sub/old'
if rc <> 0 then exit 2
address system 'printf xyz >' root'/sub/f'
if rc <> 0 then exit 2
call check reader~readAt(0,3)['DATA'] == 'abc', 'reader survives pathname replacement'
call check h~readAt('sub/f',0,3)['DATA'] == 'xyz', 'path read observes replacement'
address system 'rm' root'/sub/old'
if rc <> 0 then exit 2
call check reader~readAt(0,4)['DATA'] == 'abc', 'reader survives unlink'
call check reader~stat['LINKS'] = 0, 'reader unlink metadata'
-- A pinned reader retains identity, not a frozen copy of mutable data.
mutable = h~openReader('sub/f')['READER']
address system 'printf qrs >' root'/sub/f'
if rc <> 0 then exit 2
call check mutable~readAt(0,3)['DATA'] == 'qrs', 'pinned reader sees in-place modification'
mutable~close
-- A sparse file verifies a seek beyond the 32-bit boundary without allocating 4 GiB.
address system 'printf Z | dd of='root'/sparse bs=1 seek=4294967296 status=none'
if rc <> 0 then exit 2
sparse = h~openReader('sparse')['READER']
call check sparse~stat['SIZE'] = 4294967297, 'sparse reader size beyond 32 bits'
call check sparse~readAt(4294967296,1)['DATA'] == 'Z', 'reader seek beyond 32 bits'
sparse~close
call check \reader~readAt(0,0)['OK'], 'reader zero size denied'
call check \reader~readAt(0,1048577)['OK'], 'reader oversized read denied'
call check \.POSIXReader~new('1')~stat['OK'], 'reader guessed handle refused'
call check \h~openReader('link')['OK'], 'reader leaf symlink refused'
call check \h~openReader('escape/passwd')['OK'], 'reader ancestor symlink refused'
call check \h~openReader('fifo')['OK'], 'reader FIFO refused'
call check \h~openReader('sub')['OK'], 'reader folder refused'
call check reader~close['OK'], 'reader close'
call check \reader~readAt()['OK'], 'reader closed read refused'
reader = h~openReader('binary')['READER']
call check reader~readAt(0,8)['DATA'] == '610062'x, 'reader binary content'
reader~uninit
call check \reader~stat['OK'], 'reader uninit closes'
reader = h~openReader('binary')['READER']
call check h~close['OK'], 'reader parent close'
call check \reader~stat['OK'] & \reader~readAt()['OK'], 'root close invalidates reader'
creds = proc~credentials
call check creds['OK'] & creds['PID'] = pid & creds['START_TICKS'] == t['START_TICKS'], 'credentials process identity'
call check creds['REAL_UID']~dataType('W') & creds['EFFECTIVE_GID']~dataType('W'), 'credentials IDs'
-- Compare the kernel status directly, without assuming a particular uid.
status = .Stream~new('/proc/'pid'/status')
if status~open('READ') \== 'READY:' then exit 2
uid = ''
gid = ''
do i = 1 to 32
  line = status~lineIn
  if line~left(4) == 'Uid:' then uid = line~substr(5)~translate(' ','09'x)~space
  if line~left(4) == 'Gid:' then gid = line~substr(5)~translate(' ','09'x)~space
  if uid \== "" & gid \== "" then leave
end
status~close
call check uid == (creds['REAL_UID'] creds['EFFECTIVE_UID'] creds['SAVED_UID'] creds['FILESYSTEM_UID']), 'credentials UID matches proc'
call check gid == (creds['REAL_GID'] creds['EFFECTIVE_GID'] creds['SAVED_GID'] creds['FILESYSTEM_GID']), 'credentials GID matches proc'
call check creds['GROUPS']~isA(.Array) & creds['GROUPS']~items <= 1024, 'bounded supplementary groups'
call check creds['CAP_EFFECTIVE']~dataType('X'), 'hex effective capabilities'
l = proc~limits
call check l['OK'] & l['PID'] = pid & l['START_TICKS'] == t['START_TICKS'], 'limits process identity'
found = .false
do row over l['LIMITS']
  if row['NAME'] == 'Max open files' then found = row['SOFT']~dataType('W') & row['UNITS'] == 'files'
end
call check found, 'open-file limits parsed'
call check l['LIMITS']~items >= 10, 'resource limits structured rows'
call check \ShellProcessDetails(pid,'0','credentials')['OK'], 'stale credentials refused'
call check \ShellProcessDetails(pid,'0','limits')['OK'], 'stale limits refused'
call check \ShellProcessDetails(pid,t['START_TICKS'],'environ')['OK'], 'unapproved process detail rejected'
say 'MAIN SUITE PASSED' 
exit 0
abandon:
  use arg provider, path
  r = provider~openRoot(path)
  if \r['OK'] then do; say 'FAIL abandoned root' r['ERROR']; exit 1; end
  c = r['ROOT']~scan
  if \c['OK'] then do; say 'FAIL abandoned cursor' c['ERROR']; exit 1; end
  return
abandonCursor:
  use arg rootHandle
  c = rootHandle~scan
  if \c['OK'] then do; say 'FAIL abandoned cursor' c['ERROR']; exit 1; end
  return
check:
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
::requires 'ProcessProvider.cls'
::requires 'Process.cls'
::requires 'POSIXProvider.cls'
