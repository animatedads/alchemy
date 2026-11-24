/* Architecture: Tom Dyer. Coding: ChatGPT. Trusted internal provider, read-only. */
::class POSIXProvider public
::method name
  return 'rxshellposix'
::method capabilities
  return .Array~of('fs.stat.nofollow', 'fs.capacity', 'os.pagesize', 'fs.root.openat2', 'fs.root.capacity', 'fs.scan.bounded', 'fs.read.bounded', 'fs.reader.pinned', 'fs.watch.inotify', 'event.epoll', 'event.timerfd')
::method stat
  use strict arg root, relative = '.'
  return PosixNativeStat(root, relative)
::method capacity
  use strict arg root, relative = '.'
  return PosixNativeCapacity(root, relative)
::method pageSize
  return PosixNativePageSize()
::method timer
  use strict arg first, interval = 0
  r = PosixTimerOpen(first, interval)
  if \r['OK'] then return r
  r['TIMER'] = .POSIXTimer~new(r['HANDLE'])
  r~remove('HANDLE')
  return r
::method eventMux
  return .POSIXEventMux~new
::method openRoot
  use strict arg path
  r = PosixRootOpen(path)
  if \r['OK'] then return r
  r['ROOT'] = .POSIXRoot~new(r['HANDLE'])
  r~remove('HANDLE')
  return r

::class POSIXRoot public
::method init
  expose handle
  use strict arg handle
::method stat
  expose handle
  use strict arg relative = '.'
  return PosixRootStat(handle, relative)
::method capacity
  expose handle
  use strict arg relative = '.'
  return PosixRootCapacity(handle, relative)
::method readAt
  expose handle
  use strict arg relative, offset = 0, limit = 65536
  return PosixRootRead(handle, relative, offset, limit)
::method openReader
  expose handle
  use strict arg relative
  r = PosixReaderOpen(handle, relative)
  if \r['OK'] then return r
  r['READER'] = .POSIXReader~new(r['HANDLE'])
  r~remove('HANDLE')
  return r
::method watch
  expose handle
  use strict arg relative = '.'
  r = PosixWatchOpen(handle, relative)
  if \r['OK'] then return r
  r['WATCH'] = .POSIXWatch~new(r['HANDLE'])
  r~remove('HANDLE')
  return r
::method scan
  expose handle
  use strict arg relative = '.'
  r = PosixScanOpen(handle, relative)
  if \r['OK'] then return r
  r['CURSOR'] = .POSIXCursor~new(r['HANDLE'])
  r~remove('HANDLE')
  return r
::method close
  expose handle
  r = PosixRootClose(handle)
  handle = ""
  return r
::method uninit
  expose handle
  if symbol("HANDLE") == "VAR" then do
    if handle \== "" then call PosixRootClose handle
    handle = ""
  end

::class POSIXCursor public
::method init
  expose handle
  use strict arg handle
::method nextBatch
  expose handle
  use strict arg limit = 128
  return PosixScanNext(handle, limit)
::method close
  expose handle
  r = PosixScanClose(handle)
  handle = ""
  return r
::method uninit
  expose handle
  if symbol("HANDLE") == "VAR" then do
    if handle \== "" then call PosixScanClose handle
    handle = ""
  end
::class POSIXReader public
::method init
  expose handle
  use strict arg handle
::method readAt
  expose handle
  use strict arg offset = 0, limit = 65536
  return PosixReaderRead(handle, offset, limit)
::method stat
  expose handle
  return PosixReaderStat(handle)
::method close
  expose handle
  r = PosixReaderClose(handle)
  handle = ""
  return r
::method uninit
  expose handle
  if symbol("HANDLE") == "VAR" then do
    if handle \== "" then call PosixReaderClose handle
    handle = ""
  end
::routine ShellProcessDetails public
  use strict arg pid, expected, kind
  return PosixProcessDetails(pid, expected, kind)
::routine ShellProcessIds public
  use strict arg pid, expected, kind, limit
  return PosixProcessList(pid, expected, kind, limit)
/* Trusted internal process reference, not a proposal-facing object. */
::class POSIXProcessHandle public
::method init
  expose handle
  use strict arg handle
::method waitExit
  expose handle
  use strict arg milliseconds = 0
  return PosixPidWait(handle, milliseconds)
::method signal
  expose handle
  use strict arg number
  return PosixPidSignal(handle, number)
::method eventToken
  expose handle
  return handle
::method close
  expose handle
  r = PosixPidClose(handle)
  handle = ""
  return r
::method uninit
  expose handle
  if symbol("HANDLE") == "VAR" then do
    if handle \== "" then call PosixPidClose handle
    handle = ""
  end
::routine ShellProcessHandleOpen public
  use strict arg pid, expected
  r = PosixPidOpen(pid, expected)
  if \r['OK'] then return r
  r['PROCESS_HANDLE'] = .POSIXProcessHandle~new(r['HANDLE'])
  r~remove('HANDLE')
  return r
/* Internal, non-recursive kernel watch. No proposal grants. */
::class POSIXWatch public
::method init
  expose handle
  use strict arg handle
::method nextBatch
  expose handle
  use strict arg limit = 128
  return PosixWatchNext(handle, limit)
::method waitReady
  expose handle
  use strict arg milliseconds = 0
  return PosixWatchWait(handle, milliseconds)
::method eventToken
  expose handle
  return handle
::method close
  expose handle
  r = PosixWatchClose(handle)
  handle = ""
  return r
::method uninit
  expose handle
  if symbol("HANDLE") == "VAR" then do
    if handle \== "" then call PosixWatchClose handle
    handle = ""
  end
/* Internal timer and single-consumer multiplexer. No proposal grants. */
::class POSIXTimer public
::method init
  expose handle
  use strict arg handle
::method eventToken
  expose handle
  return handle
::method drain
  expose handle
  return PosixTimerDrain(handle)
::method close
  expose handle
  r = PosixTimerClose(handle)
  handle = ""
  return r
::method uninit
  expose handle
  if symbol("HANDLE") == "VAR" then do
    if handle \== "" then call PosixTimerClose handle
    handle = ""
  end
::class POSIXEventMux public
::method wait
  use strict arg sources, milliseconds = 0
  if \sources~isA(.Array) then raise syntax 93.900 array ('Expected an array of event sources')
  if sources~items = 0 | sources~items > 128 | sources~items <> sources~size then raise syntax 93.900 array ('Expected 1..128 dense event sources')
  keys = .Array~new
  do source over sources
    if \source~isA(.POSIXWatch) & \source~isA(.POSIXProcessHandle) & \source~isA(.POSIXTimer) then raise syntax 93.900 array ('Unsupported event source')
    keys~append(source~eventToken)
  end
  return PosixEventWait(keys, milliseconds)
::requires 'rxshellposix' LIBRARY
