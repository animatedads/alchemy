/* Architecture: Tom Dyer. Coding: ChatGPT. Trusted internal provider, read-only. */
::class POSIXProvider public
::method name
  return 'rxshellposix'
::method capabilities
  return .Array~of('fs.stat.nofollow', 'fs.capacity', 'os.pagesize', 'fs.root.openat2', 'fs.root.capacity', 'fs.scan.bounded', 'fs.read.bounded', 'fs.reader.pinned')
::method stat
  use strict arg root, relative = '.'
  return PosixNativeStat(root, relative)
::method capacity
  use strict arg root, relative = '.'
  return PosixNativeCapacity(root, relative)
::method pageSize
  return PosixNativePageSize()
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
::requires 'rxshellposix' LIBRARY
