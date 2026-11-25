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
  caps~append('process.pidfd.optional')
  return caps
::method observe
  use strict arg pid
  numeric digits 20
  if \pid~dataType('W') then return .nil
  if pid < 1 | pid > 2147483647 then return .nil
  return .NativeObservedProcess~open((pid+0))
::method openProcessHandle
  use strict arg observation
  if \observation~isA(.NativeObservedProcess) then raise syntax 93.900 array ("Expected a NativeObservedProcess")
  identity = observation~identity
  return ShellProcessHandleOpen(observation~pid, identity~substr(identity~lastPos(':')+1))
::method pageSize
  return .POSIXProvider~new~pageSize
::class NativeObservedProcess public subclass LinuxProcess
::method threadIds
  use strict arg limit = 128
  return ShellProcessIds(self~pid, self~identity~substr(self~identity~lastPos(':')+1), 'task', limit)
::method descriptorIds
  use strict arg limit = 128
  return ShellProcessIds(self~pid, self~identity~substr(self~identity~lastPos(':')+1), 'fd', limit)
::method portSnapshot
  use strict arg port, protocol = "tcp"
  return ShellProcessPortSnapshot(self~pid, self~identity~substr(self~identity~lastPos(':')+1), port, protocol)
::method parentEdge
  return ShellParentEdge(self~pid, self~identity~substr(self~identity~lastPos(':')+1))
::method lineage
  use strict arg maxDepth = 16
  if \maxDepth~datatype('W') | maxDepth<1 | maxDepth>32 then raise syntax 93.900 array ('Lineage depth must be 1..32')
  edges=.Array~new; seen=.Directory~new
  pid=self~pid; ticks=self~identity~substr(self~identity~lastPos(':')+1); expected=.nil
  complete=.false
  do i=1 to maxDepth
    r=ShellParentEdge(pid,ticks)
    if \r['OK'] then return r
    if expected\==.nil then if r['CHILD_IDENTITY']\==expected then return lineageGap('parent identity changed')
    if seen~hasIndex(r['CHILD_IDENTITY']) then return lineageGap('repeated process identity')
    seen[r['CHILD_IDENTITY']]=1; edges~append(r)
    if \r['LINK_AVAILABLE'] then do; complete=.true; leave; end
    pid=r['PPID'];ticks=r['PARENT_START_TICKS'];expected=r['PARENT_IDENTITY']
  end
  do edge over edges
    r=ShellParentEdge(edge['PID'],edge['START_TICKS'])
    if \r['OK'] then return r
    if r['CHILD_IDENTITY']\==edge['CHILD_IDENTITY'] | r['LINK_AVAILABLE']\==edge['LINK_AVAILABLE'] | r['PARENT_IDENTITY']\==edge['PARENT_IDENTITY'] then return lineageGap('lineage changed during observation')
  end
  out=.Directory~new;out['OK']=1;out['ERRNO']=0;out['ERROR']='';out['EDGES']=edges;out['TRUNCATED']=\complete;out['SCOPE']='CURRENT_PARENT_LINKS';return out
::method securitySnapshot
  return ShellSecurityProcess(self~pid, self~identity~substr(self~identity~lastPos(':')+1))
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

::routine lineageGap
  use strict arg reason
  out=.Directory~new;out['OK']=0;out['ERRNO']=0;out['ERROR']=reason;return out
