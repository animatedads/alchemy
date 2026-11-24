/* Architecture: Tom Dyer. Coding: ChatGPT. Trusted internal adapter, not an LLM grant. */
::class ProcessProvider public subclass ProcessNativeProvider
::method capabilities
  caps = self~capabilities:super
  caps~append('process.observe.linux')
  caps~append('process.pagesize')
  caps~append('process.threads.ids')
  caps~append('process.descriptors.ids')
  caps~append('process.credentials')
  caps~append('process.limits')
  return caps
::method observe
  use strict arg pid
  numeric digits 20
  if \pid~dataType('W') then return .nil
  if pid < 1 | pid > 2147483647 then return .nil
  return .NativeObservedProcess~open((pid+0))
::method pageSize
  return .POSIXProvider~new~pageSize
::class NativeObservedProcess public subclass LinuxProcess
::method threadIds
  use strict arg limit = 128
  return ShellProcessIds(self~pid, self~identity~substr(self~identity~lastPos(':')+1), 'task', limit)
::method descriptorIds
  use strict arg limit = 128
  return ShellProcessIds(self~pid, self~identity~substr(self~identity~lastPos(':')+1), 'fd', limit)
::method credentials
  return ShellProcessDetails(self~pid, self~identity~substr(self~identity~lastPos(':')+1), 'credentials')
::method limits
  return ShellProcessDetails(self~pid, self~identity~substr(self~identity~lastPos(':')+1), 'limits')
::method rssKiB
  numeric digits 20
  if .LinuxProcess~hasMethod("PAGESIZEAWARE") then return self~rssKiB:super
  -- dev6 superclass exposes RSS using 4096 bytes/page; undo that
  -- conversion, then apply the actual native page size.
  return (self~rssKiB:super / 4) * (.POSIXProvider~new~pageSize / 1024)
::requires 'ProcessNativeProvider.cls' 
::requires 'Computer.cls'
::requires 'POSIXProvider.cls'
