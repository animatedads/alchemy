/* Architecture: Tom Dyer. Coding: ChatGPT. Test mutations in disposable fixture only. */
parse arg path
p = .POSIXProvider~new
r = p~openRoot(path)
if \r['OK'] then exit 2
root = r['ROOT']
call check p~capabilities~hasItem('fs.watch.inotify'), 'inotify capability'
call check \root~watch('escape')['OK'], 'watch symlink rejected'
call check \root~watch('../')['OK'], 'watch parent escape rejected'
call check \root~watch('sub/f')['OK'], 'watch regular file refused'
r = root~watch('watchdir')
if \r['OK'] then do; say 'FAIL watch open' r['ERROR']; exit 1; end
w = r['WATCH']
call check w~waitReady['OK'] & \w~waitReady['READY'], 'watch initially empty'
r = w~waitReady(20)
call check r['OK'] & r['TIMED_OUT'] & \r['READY'], 'watch bounded wait timeout'
call check \w~waitReady(5001)['OK'], 'watch excessive wait rejected'
call check \w~nextBatch(0)['OK'] & \w~nextBatch(1025)['OK'], 'watch invalid batch bounds'
r = w~nextBatch(1)
call check r['OK'] & r['DRAINED'] & r['EVENTS']~items = 0, 'watch empty drain'
f = path'/watchdir/a'
s = .Stream~new(f)
s~charOut('abc')
s~close
'mv --' f path'/watchdir/b'
if rc <> 0 then exit 2
call SysFileDelete path'/watchdir/b'
call check w~waitReady(1000)['READY'], 'watch event ready'
seen = .Directory~new
from = 0; to = 0; count = 0
 do i = 1 to 64
  r = w~nextBatch(1)
  if \r['OK'] | r['EVENTS']~items > 1 then exit 2
  do e over r['EVENTS']
   count += 1
   do k over e['KINDS']
    seen[k':'e['NAME']] = 1
    if k = 'MOVED_FROM' then from = e['COOKIE']
    if k = 'MOVED_TO' then to = e['COOKIE']
   end
  end
  if r['DRAINED'] then leave
 end
call check r['DRAINED'] & count >= 5, 'watch bounded drain retains events'
call check seen~hasIndex('CREATE:a'), 'watch create event'
call check seen~hasIndex('CLOSE_WRITE:a'), 'watch close write event'
call check seen~hasIndex('MOVED_FROM:a') & seen~hasIndex('MOVED_TO:b') & from = to & from <> 0, 'watch rename cookie pairing'
call check seen~hasIndex('DELETE:b'), 'watch delete event'
call check \r['RESCAN_REQUIRED'], 'watch normal drain no rescan'
-- Child directories are not recursively watched.
s = .Stream~new(path'/watchdir/child/hidden')
s~charOut('x'); s~close
call check \w~waitReady['READY'], 'watch nonrecursive'
'mv --' path'/watchdir' path'/watchmoved'
if rc <> 0 then exit 2
call check w~waitReady(1000)['READY'], 'watch moved directory notification'
r = w~nextBatch(128)
call check r['INVALIDATED'] & r['RESCAN_REQUIRED'], 'watch moved directory requires rescan'
r = w~nextBatch(128)
call check r['INVALIDATED'] & r['RESCAN_REQUIRED'], 'watch invalidation sticky'
call check w~close['OK'], 'watch explicit close'
call check \w~nextBatch['OK'] & \w~waitReady['OK'], 'watch closed invalid'
call check \ .POSIXWatch~new('1')~nextBatch['OK'], 'watch guessed token refused'
r = root~watch('watchmoved')
if \r['OK'] then exit 2
w = r['WATCH']; w~uninit
call check \w~waitReady['OK'], 'watch uninit close'
r = root~watch('watchmoved'); if \r['OK'] then exit 2
w = r['WATCH']
call check root~close['OK'] & \w~nextBatch['OK'], 'watch root close invalidates'
-- Real queue overflow if configured kernel queue is bounded enough for this test.
q = linein('/proc/sys/fs/inotify/max_queued_events')
call stream '/proc/sys/fs/inotify/max_queued_events','c','close'
if datatype(q,'W') & q > 0 & q <= 65536 then do
 root = p~openRoot(path)['ROOT']; r = root~watch('watchmoved'); if \r['OK'] then exit 2
 w = r['WATCH']; f = path'/watchmoved/overflow'
 do i = 1 to q % 2 + 2
   s = .Stream~new(f); s~charOut('x'); s~close
   if SysFileDelete(f) <> 0 then exit 2
 end
 found = .false
 do i = 1 to q + 10
  r = w~nextBatch(1024)
  if \r['OK'] then exit 2
  if r['OVERFLOW'] then do; found = .true; leave; end
  if r['DRAINED'] then leave
 end
 call check found & r['RESCAN_REQUIRED'], 'watch real kernel queue overflow'
 r = w~nextBatch(1024)
 call check r['OVERFLOW'] & r['RESCAN_REQUIRED'], 'watch overflow sticky'
 w~close; root~close
end
else say 'SKIP watch overflow: kernel queue outside test budget' q
say 'WATCH SUITE PASSED'
exit 0
check:
 use arg ok, label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::requires 'POSIXProvider.cls'
