/* ShellNative.cls - the native providers, when they are there (newshell v0.1-dev7)
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
   The providers themselves (POSIXProvider, ProcessProvider, librxshellposix): ChatGPT,
   newshell_native_providers v0.1-dev10 (published 9f1a714c).

   The providers are loaded at run time, once. When they cannot be loaded (ooRexx 5.2,
   which the library does not support, or a kit built without the library), every
   object falls back to plain Rexx and says so: .ShellNative~mode is 'native' or
   'rexx', and .ShellNative~whyNot gives the reason.

   Raw providers, handles and tokens are trusted internals: nothing here is a shell
   object, and proposals cannot name these classes (ProposalCheck refuses dot names). */

::class ShellNative public

::method init class
  expose loaded posix whyNot pageSize
  loaded = .false
  posix = .nil
  whyNot = ''
  pageSize = 0

::method load class private
  expose loaded posix whyNot
  if loaded then return
  loaded = .true
  if value('NEWSHELL_NATIVE', , 'ENVIRONMENT') == 'off' then do
    whyNot = 'NEWSHELL_NATIVE=off'
    return
  end
  signal on syntax name failed
  pkg = .context~package~loadPackage('POSIXProvider.cls')
  cls = pkg~findClass('POSIXProvider')
  if cls == .nil then do; whyNot = 'POSIXProvider.cls has no POSIXProvider class'; return; end
  posix = cls~new
  if \datatype(posix~pageSize, 'W') then do; posix = .nil; whyNot = 'pageSize did not answer'; end
  return
failed:
  c = condition('O')
  whyNot = 'native providers not loaded:' c~message
  posix = .nil
  return

/* The POSIXProvider, or .nil. */
::method posix class
  expose posix
  self~load
  return posix

::method mode class
  if self~posix == .nil then return 'rexx'
  return 'native'

::method whyNot class
  expose whyNot
  self~load
  return whyNot

/* Bytes per memory page: sysconf through the provider, else the kernel's own
   statement in /proc/self/smaps ("KernelPageSize: 4 kB"), else 4096. */
::method pageSize class
  expose pageSize
  if pageSize > 0 then return pageSize
  p = self~posix
  if p \== .nil then pageSize = p~pageSize
  else pageSize = smapsPageSize()
  return pageSize

/* Free and total bytes of the file system holding path (statvfs through a root the
   provider pins), or .nil when there is no provider: the caller falls back to df. */
::method capacity class
  use strict arg path
  p = self~posix
  if p == .nil then return .nil
  r = p~openRoot(path)
  if \r['OK'] then return .nil
  root = r['ROOT']
  signal on syntax name closeAndFail
  c = root~capacity
  root~close
  if \c['OK'] then return .nil
  numeric digits 30
  d = .Directory~new
  d['free'] = c['AVAILABLE_BLOCKS'] * c['FRAGMENT_BYTES']
  d['total'] = c['BLOCKS'] * c['FRAGMENT_BYTES']
  return d
closeAndFail:
  root~close
  return .nil

/* Metadata of path without following a link: KIND, DEVICE, INODE, MODE_OCTAL, UID,
   GID, LINKS, SIZE, MTIME_SEC, MTIME_NS; or .nil without a provider or on failure. */
::method stat class
  use strict arg path
  p = self~posix
  if p == .nil then return .nil
  if path == '/' then do; dir = '/'; rel = '.'; end
  else do
    dir = filespec('location', path)~strip('T', '/')
    if dir == '' then dir = '/'
    rel = filespec('name', path)
  end
  s = p~stat(dir, rel)
  if \s['OK'] then return .nil
  return s

::routine smapsPageSize
  s = .Stream~new('/proc/self/smaps')
  if s~open('READ') \= 'READY:' then return 4096
  size = 4096
  do 64
    line = s~lineIn
    if line~word(1) == 'KernelPageSize:' then do
      size = line~word(2) * 1024
      leave
    end
  end
  s~close
  return size
