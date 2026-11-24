/* FileSystem.cls - a directory tree as shell objects
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   fs = .FileSystem~new('/tmp')
   do f over fs            -- every regular file under the root, recursively
     say f~relPath f~size
   end
   f = fs~create('/tmp/test.txt')          -- protected
   f~edit~addLine('test 1234')             -- both protected

   Reading is open. Changing is only through PROTECTED methods (create,
   edit, addLine). Each says which path governs it (authorityPath), and the
   security manager of the calling code decides from that path. The objects
   also keep their own structural limits: nothing outside the root, no
   writing through a symbolic link, and walks never follow links. */
::requires 'ShellObject.cls'

::class FileSystem public inherit ShellObject
::constant SHELL_HELP "DO OVER fs gives every regular file under the root as an FsFile. fs~files is the same list as a ShellCollection, which has sortedBy(fieldName, 'A' or 'D') and first(n). fs~file(path) gives the FsFile for an existing file. fs~create(path) creates an empty file (or returns the existing one) and gives its FsFile. Paths may be absolute or relative to the root. Sizes are bytes."
::constant MAX_ENTRIES 100000
::constant MAX_DEPTH 32

::method init
  expose root
  use strict arg rootArg
  f = .File~new(rootArg)
  if \f~isDirectory then raise syntax 93.900 array ('Not a directory:' rootArg)
  if SysIsFileLink(f~absolutePath) then raise syntax 93.900 array ('Root is a symbolic link:' rootArg)
  root = f~absolutePath
  if root \== '/' then root = root~strip('T', '/')

::method root
  expose root
  return root

::method identity
  expose root
  return 'fs:'root

-- cheap fields only: a table of / must not walk /
::method fields
  return .Array~of('root', 'source', 'capabilities')

::method capabilities
  return .Array~of('READ', 'CREATE(policy)')

::method fileCount
  return self~files~items~items

::method totalBytes
  total = 0
  do f over self~files; total += f~size; end
  return total

::method files
  return .ShellCollection~new(self~walk('FILE'))

::method directories
  return .ShellCollection~new(self~walk('DIR'))

::method links
  return .ShellCollection~new(self~walk('LINK'))

::method makeArray
  return self~files~items

::method supplier
  return self~files~items~supplier

/* An absolute path inside the root, or a syntax error. */
::method resolve
  expose root
  use strict arg path
  if path~left(1) == '/' then full = qualify(path)
  else full = qualify(root'/'path)
  if root \== '/', full \== root, full~left(root~length + 1) \== root'/' then
    raise syntax 93.900 array (path 'is outside' root)
  return full

::method file
  expose root
  use strict arg path
  full = self~resolve(path)
  f = .File~new(full)
  if SysIsFileLink(full) then return .FsFile~new(root, f, 'link')
  if f~isDirectory then return .FsFile~new(root, f, 'dir')
  if \f~isFile then raise syntax 93.900 array ('No such file:' full)
  return .FsFile~new(root, f, 'file')

::method create protected
  expose root
  use strict arg path
  full = self~resolve(path)
  parent = .File~new(filespec('location', full))
  if \parent~isDirectory then raise syntax 93.900 array ('No such directory:' parent~absolutePath)
  if SysIsFileLink(full) then raise syntax 93.900 array ('Will not create through a symbolic link:' full)
  f = .File~new(full)
  if f~isDirectory then raise syntax 93.900 array (full 'is a directory')
  if \f~exists then do
    s = .Stream~new(full)
    if s~open('WRITE REPLACE') \= 'READY:' then raise syntax 93.900 array ('Cannot create' full)
    s~close
  end
  return .FsFile~new(root, .File~new(full), 'file')

/* The path the security manager judges each protected call by. */
::method authorityPath
  expose root
  use strict arg name, args
  if name~upper == 'CREATE', args~items >= 1 then return self~resolve(args[1])
  return root

/* Objects whose methods a proposal may send: one item, for the LLM's view. */
::method relatedSamples
  expose root
  first = self~walk('FILE', 1)
  if first~items > 0 then sample = first[1]
  else sample = .FsFile~new(root, .File~new(root), 'dir')
  return .Array~of(.Array~of('each FsFile (DO OVER fs, fs~file, fs~create)', sample))

/* Breadth-first walk. kind is FILE, DIR or LINK; stop after limit finds. */
::method walk private
  expose root
  use strict arg kind, limit = 0
  found = .Array~new
  queue = .Queue~of(.Array~of(.File~new(root), 0))
  seen = 0
  do while queue~items > 0
    item = queue~pull
    dir = item[1]; depth = item[2]
    entries = dir~listFiles
    if entries == .nil then iterate        -- unreadable directory: skip it
    do e over entries
      seen += 1
      if seen > self~MAX_ENTRIES then raise syntax 93.900 array ('More than' self~MAX_ENTRIES 'entries under' root)
      if SysIsFileLink(e~absolutePath) then do
        if kind == 'LINK' then found~append(.FsFile~new(root, e, 'link'))
      end
      else if e~isDirectory then do
        if kind == 'DIR' then found~append(.FsFile~new(root, e, 'dir'))
        if depth < self~MAX_DEPTH then queue~queue(.Array~of(e, depth + 1))
      end
      else if kind == 'FILE', e~isFile then found~append(.FsFile~new(root, e, 'file'))
      if limit > 0, found~items >= limit then return found
    end
  end
  return found


::class FsFile public inherit ShellObject
::constant SHELL_HELP "size is in bytes. modified is an ISO date-time. relPath is the path below the file system root. f~edit gives a FileEditor for the file (protected)."

::method init
  expose root path name kind size modified
  use strict arg root, file, kind
  path = file~absolutePath
  name = file~name
  if kind == 'file' then size = file~length
  else size = 0
  modified = file~lastModified~isoDate

::method path
  expose path
  return path
::method relPath
  expose root path
  if path == root then return '.'
  if root == '/' then return path~substr(2)
  return path~substr(root~length + 2)
::method name
  expose name
  return name
::method extension
  expose name
  if name~lastPos('.') <= 1 then return ''
  return name~substr(name~lastPos('.') + 1)
::method kind
  expose kind
  return kind
::method size
  expose size
  return size
::method modified
  expose modified
  return modified

::method edit protected
  expose path kind
  if kind \== 'file' then raise syntax 93.900 array ('Can only edit a regular file, not a' kind':' path)
  return .FileEditor~new(path)

::method authorityPath
  expose path
  use strict arg name, args
  return path

::method relatedSamples
  expose path
  return .Array~of(.Array~of('f~edit returns a FileEditor', .FileEditor~new(path)))

::method identity
  expose path
  return 'file:'path

::method isCurrent
  expose path size modified kind
  f = .File~new(path)
  if \f~exists then return .false
  if kind \== 'file' then return .true
  return f~length = size & f~lastModified~isoDate == modified

::method capabilities
  return .Array~of('READ', 'EDIT(policy)')

::method fields
  return .Array~of('relPath', 'size', 'modified')


/* Line-level editing of one file. Reading is open; addLine is protected. */
::class FileEditor public inherit ShellObject
::constant SHELL_HELP "e~addLine(text) appends one line and returns the editor, so calls chain. e~lines gives the file's lines as an Array."

::method init
  expose path
  use strict arg path

::method path
  expose path
  return path

::method lines
  expose path
  list = .Array~new
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then return list
  do forever
    line = s~lineIn
    if line == '', s~state \== 'READY' then leave
    list~append(line)
  end
  s~close
  return list

::method lineCount
  return self~lines~items

::method addLine protected
  expose path
  use strict arg text
  if SysIsFileLink(path) then raise syntax 93.900 array ('Will not write through a symbolic link:' path)
  if \.File~new(path)~isFile then raise syntax 93.900 array ('No such file:' path)
  s = .Stream~new(path)
  if s~open('WRITE APPEND') \= 'READY:' then raise syntax 93.900 array ('Cannot open' path 'to append')
  s~lineOut(text)
  s~close
  return self

::method authorityPath
  expose path
  use strict arg name, args
  return path

::method identity
  expose path
  return 'editor:'path

::method capabilities
  return .Array~of('READ', 'ADDLINE(policy)')

::method fields
  return .Array~of('path', 'lineCount')
