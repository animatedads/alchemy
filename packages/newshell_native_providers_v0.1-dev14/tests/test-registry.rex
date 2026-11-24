/* Architecture: Tom Dyer. Coding: ChatGPT. */
parse arg path
p = .POSIXProvider~new
roots = .Array~new
scans = .Array~new
readers = .Array~new
do i = 1 to 128
  r = p~openRoot(path)
  if \r['OK'] then do; say 'FAIL root allocation' i r['ERROR']; exit 1; end
  roots~append(r['ROOT'])
end
r = p~openRoot(path)
call check \r['OK'] & r['ERRNO'] = 0 & r['ERROR']~pos('ROOT_REGISTRY_FULL') = 1, 'root registry distinct diagnostic'
h = roots[1]
do i = 1 to 128
  r = h~scan
  if \r['OK'] then exit 2
  scans~append(r['CURSOR'])
  r = h~openReader('sub/f')
  if \r['OK'] then exit 2
  readers~append(r['READER'])
end
r = h~scan
call check \r['OK'] & r['ERRNO'] = 0 & r['ERROR']~pos('CURSOR_REGISTRY_FULL') = 1, 'cursor registry distinct diagnostic'
r = h~openReader('sub/f')
call check \r['OK'] & r['ERRNO'] = 0 & r['ERROR']~pos('READER_REGISTRY_FULL') = 1, 'reader registry distinct diagnostic'
r = readers[1]~close
r = h~openReader('sub/f')
call check r['OK'], 'reader capacity recovered after close'
r['READER']~close
r = scans[1]~close
r = h~scan
call check r['OK'], 'cursor capacity recovered after close'
r['CURSOR']~close
call check h~close['OK'], 'root closes full child registries'
r = p~openRoot(path)
call check r['OK'], 'root capacity recovered after close'
h = r['ROOT']
r = h~scan
call check r['OK'], 'cursor capacity recovered after root close'
r['CURSOR']~close
r = h~openReader('sub/f')
call check r['OK'], 'reader capacity recovered after root close'
r['READER']~close
h~close
do i = 2 to 128; roots[i]~close; end
-- Abandoned readers while the root remains live.
h = p~openRoot(path)['ROOT']
do j = 1 to 6
  do k = 1 to 64
    call abandon h
  end
  do k = 1 to 2048
    garbage = .Array~new(4096)
  end
end
r = h~openReader('sub/f')
call check r['OK'], 'abandoned readers reclaimed under GC pressure'
r['READER']~close
h~close
exit 0
abandon:
  use arg rootHandle
  r = rootHandle~openReader('sub/f')
  if \r['OK'] then do; say 'FAIL abandoned reader' r['ERROR']; exit 1; end
  return
check:
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
::requires 'POSIXProvider.cls'
