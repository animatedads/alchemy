/* Computer.cls v0.2 - read-only Linux machine as shell objects
   Architecture: Tom Dyer.
   Coding: ChatGPT (v0.1: Computer, LinuxKernel, LinuxMemory, readOne);
           Claude (Opus 5.5) (v0.2: moved onto ShellObject.cls; processes,
           process(pid) with pid+starttime identity; memory refresh).
   Reads /proc only. No subprocesses. No writes.
   Deliberately not exposed: /proc/PID/environ and cmdline (they carry secrets). */
::requires 'ShellObject.cls'

::class Computer public inherit ShellObject
::method hostname
  return readOne('/proc/sys/kernel/hostname')
::method kernel
  return .LinuxKernel~new
::method memory
  return .LinuxMemory~new
::method uptimeSeconds
  return readOne('/proc/uptime')~word(1)
::method kernelRelease
  return self~kernel~release
::method identity
  return 'computer:'readOne('/proc/sys/kernel/random/boot_id')
::method fields
  return .Array~of('hostname', 'kernelRelease', 'uptimeSeconds')
::method process
  use strict arg pid
  proc = .LinuxProcess~open(pid)
  if proc == .nil then raise syntax 93.900 array ('No process' pid)
  return proc
::method processes
  rows = .Array~new
  do f over .File~new('/proc')~listFiles
    if \f~name~dataType('W') then iterate
    proc = .LinuxProcess~open(f~name)      -- may have exited since the listing
    if proc \== .nil then rows~append(proc)
  end
  return .ShellCollection~new(rows)
::method SelfTest
  return .File~new('/proc/sys/kernel/osrelease')~exists & .File~new('/proc/meminfo')~exists

::class LinuxKernel public inherit ShellObject
::method release
  return readOne('/proc/sys/kernel/osrelease')
::method version
  return readOne('/proc/version')
::method osType
  return readOne('/proc/sys/kernel/ostype')
::method fields
  return .Array~of('release', 'version', 'osType')

::class LinuxMemory public inherit ShellObject
::method init
  self~load
::method load private
  expose values
  values = .Directory~new
  stream = .Stream~new('/proc/meminfo')
  if stream~open('READ') <> 'READY:' then raise syntax 93.900 array ('Cannot read /proc/meminfo')
  do forever                             -- /proc files report size 0, so lines() says 0
    line = stream~lineIn
    if line == '', stream~state == 'NOTREADY' then leave
    parse var line key ':' amount .
    values[key] = amount
  end
  stream~close
::method refresh
  self~load
  forward class (super)
::method fields
  return .Array~of('MemTotal', 'MemAvailable', 'MemFree', 'SwapTotal', 'SwapFree')
::method field
  expose values
  use strict arg key
  return values[key]
::method totalKiB
  return self~field('MemTotal')
::method availableKiB
  return self~field('MemAvailable')

/* One process. Identity is pid + kernel start time, so a kept process whose
   PID has been reused reports isCurrent = 0 instead of silently becoming
   another process. */
::class LinuxProcess public inherit ShellObject
::method open class
  use strict arg pid
  line = readMaybe('/proc/'pid'/stat')
  if line == .nil then return .nil
  return self~new(pid, line)
::method init
  expose pid
  use strict arg pid, line
  self~parseStat(line)
::method parseStat private
  expose pid comm state ppid threads startTime rssPages
  use strict arg line
  -- comm sits in parentheses and may itself hold spaces or ')'
  open = line~pos('(')
  close = line~lastPos(')')
  comm = line~substr(open + 1, close - open - 1)
  rest = line~substr(close + 2)          -- field 3 onward
  state     = rest~word(1)               -- field 3
  ppid      = rest~word(2)               -- field 4
  threads   = rest~word(18)              -- field 20
  startTime = rest~word(20)              -- field 22, clock ticks since boot
  rssPages  = rest~word(22)              -- field 24
::method pid
  expose pid
  return pid
::method comm
  expose comm
  return comm
::method state
  expose state
  return state
::method ppid
  expose ppid
  return ppid
::method threads
  expose threads
  return threads
::method rssKiB
  expose rssPages
  return rssPages * 4                    -- 4 KiB pages on x86_64
::method residentMemory
  return self~rssKiB * 1024
::method identity
  expose pid startTime
  return 'pid:'pid':'startTime
::method isCurrent
  expose pid startTime
  line = readMaybe('/proc/'pid'/stat')
  if line == .nil then return .false
  return line~substr(line~lastPos(')') + 2)~word(20) == startTime
::method refresh
  expose pid
  line = readMaybe('/proc/'pid'/stat')
  if line == .nil then raise syntax 93.900 array ('Process' pid 'has gone')
  if line~substr(line~lastPos(')') + 2)~word(20) \== self~identity~substr(self~identity~lastPos(':') + 1) then
    raise syntax 93.900 array ('PID' pid 'now belongs to another process')
  self~parseStat(line)
  forward class (super)
::method fields
  return .Array~of('pid', 'comm', 'state', 'ppid', 'threads', 'rssKiB')

::routine readOne
  use strict arg path
  value = readMaybe(path)
  if value == .nil then raise syntax 93.900 array ('Cannot read' path)
  return value

::routine readMaybe
  use strict arg path
  stream = .Stream~new(path)
  if stream~open('READ') <> 'READY:' then return .nil
  value = stream~lineIn
  stream~close
  return value
