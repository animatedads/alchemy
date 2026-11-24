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
   writing through a symbolic link, and walks never follow links.

   dev7: directories are FsFolder objects (Tom Dyer's rule: no shell class takes an
   ooRexx built-in name; .Directory is a collection, not a folder). With the native
   providers (ChatGPT, providers dev10), FsFile carries device, inode, permissions
   and nanosecond times from a stat that never follows a link, and FsFolder lists
   entries in bounded batches from a pinned directory. Without them, plain Rexx. */
::requires 'ShellObject.cls'
::requires 'ShellNative.cls'

::class FileSystem public inherit ShellObject
::constant SHELL_HELP "DO OVER fs gives every regular file under the root as an FsFile. fs~files is the same list as a ShellCollection, which has sortedBy(fieldName, 'A' or 'D') and first(n). fs~folders lists every folder (FsFolder). fs~file(path) gives the FsFile (or FsFolder) for an existing path. fs~folder(path) gives an FsFolder. fs~create(path) creates an empty file (or returns the existing one) and gives its FsFile. Paths may be absolute or relative to the root. Sizes are bytes."
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

::method folders
  return .ShellCollection~new(self~walk('DIR'))
::method directories            -- dev6 name, kept for old proposals
  return self~folders

::method folder
  use strict arg path
  full = self~resolve(path)
  if SysIsFileLink(full) then raise syntax 93.900 array ('A symbolic link is not a folder:' full)
  if \.File~new(full)~isDirectory then raise syntax 93.900 array ('No such folder:' full)
  return .FsFolder~new(self~root, .File~new(full))

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
  if f~isDirectory then return .FsFolder~new(root, f)
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
  else sample = .FsFolder~new(root, .File~new(root))
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
        if kind == 'DIR' then found~append(.FsFolder~new(root, e))
        if depth < self~MAX_DEPTH then queue~queue(.Array~of(e, depth + 1))
      end
      else if kind == 'FILE', e~isFile then found~append(.FsFile~new(root, e, 'file'))
      if limit > 0, found~items >= limit then return found
    end
  end
  return found


::class FsFile public inherit ShellObject
::constant SHELL_HELP "size is in bytes. modified is an ISO date-time. relPath is the path below the file system root. mode is the octal permission (e.g. 0644) when the native provider is present. f~openSource gives a SourceFile: read, find, grep, lint, check, line edits and save. f~edit gives a FileEditor that only appends lines (protected)."

::method init
  expose root path name kind size modified device inode mode uid mtimeNs
  use strict arg root, file, kind
  path = file~absolutePath
  name = file~name
  if kind == 'file' then size = file~length
  else size = 0
  modified = file~lastModified~isoDate
  device = ''; inode = ''; mode = ''; uid = ''; mtimeNs = ''
  -- dev7: one stat that does not follow links, when the provider is there
  st = .ShellNative~stat(path)
  if st \== .nil then do
    device = st['DEVICE']; inode = st['INODE']; mode = st['MODE_OCTAL']; uid = st['UID']
    mtimeNs = st['MTIME_SEC']'.'right(st['MTIME_NS'], 9, '0')
    if kind == 'file' then size = st['SIZE']
  end

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
::method mode
  expose mode
  return mode
::method rootPath
  expose root
  return root
::method uid
  expose uid
  return uid
::method inode
  expose inode
  return inode

::method edit protected
  expose path kind
  if kind \== 'file' then raise syntax 93.900 array ('Can only edit a regular file, not a' kind':' path)
  return .FileEditor~new(path)

/* dev7: the file as a SourceFile (oorexx_source_editor dev9): read, find, grep, lint,
   check; line edits and save are protected on the SourceFile itself. Loaded when first
   used, so a kit without the editor still has every other file object. */
::method openSource
  expose path kind
  if kind \== 'file' then raise syntax 93.900 array ('Only a regular file has source, not a' kind':' path)
  signal on syntax name noEditor
  pkg = .context~package~loadPackage('ShellSource.cls')
  signal off syntax
  return pkg~findClass('SourceFile')~new(path)
noEditor:
  c = condition('O')
  if c~code~left(3) == '93.' then raise propagate
  raise syntax 93.900 array ('The source editor is not installed here:' c~message)

::method authorityPath
  expose path
  use strict arg name, args
  return path

::method relatedSamples
  expose path kind
  samples = .Array~of(.Array~of('f~edit returns a FileEditor', .FileEditor~new(path)))
  -- dev7: the SourceFile, when the editor is installed and this is a regular file
  if kind == 'file' then do
    signal on syntax name noSource
    samples~append(.Array~of('f~openSource returns a SourceFile', self~openSource))
  end
noSource:
  return samples

::method identity
  expose path device inode
  -- dev7: with the provider the identity is the inode, so a replaced file is a different file
  if inode \== '' then return 'file:'path'@'device':'inode
  return 'file:'path

::method isCurrent
  expose path size modified kind inode mtimeNs
  if inode \== '' then do
    st = .ShellNative~stat(path)
    if st == .nil then return .false
    if st['INODE'] \== inode then return .false
    if kind \== 'file' then return .true
    return st['SIZE'] = size & st['MTIME_SEC']'.'right(st['MTIME_NS'], 9, '0') == mtimeNs
  end
  f = .File~new(path)
  if \f~exists then return .false
  if kind \== 'file' then return .true
  return f~length = size & f~lastModified~isoDate == modified

::method capabilities
  return .Array~of('READ', 'EDIT(policy)')

::method fields
  expose mode
  if mode == '' then return .Array~of('relPath', 'size', 'modified')
  return .Array~of('relPath', 'size', 'modified', 'mode')


/* dev7: a folder. Lists its own entries (not recursive); fs~folders walks the tree. */
::class FsFolder public subclass FsFile
::constant SHELL_HELP "A folder (a directory on disk). d~entries gives its own files and folders as a ShellCollection, not recursive, at most 2000 (d~entries(n) for fewer). d~files and d~folders split them. Links are listed, never followed."
::constant MAX_ENTRIES 2000
::method init
  use strict arg root, file
  self~init:super(root, file, 'folder')
::method entries
  use strict arg limit = (self~MAX_ENTRIES)
  if \datatype(limit, 'W') | limit < 1 then raise syntax 93.900 array ('entries(n): n must be a whole number from 1')
  limit = min(limit, self~MAX_ENTRIES)
  return .ShellCollection~new(self~listOwn(limit))
::method files
  rows = .Array~new
  do e over self~listOwn(self~MAX_ENTRIES)
    if e~kind == 'file' then rows~append(e)
  end
  return .ShellCollection~new(rows)
::method folders
  rows = .Array~new
  do e over self~listOwn(self~MAX_ENTRIES)
    if e~kind == 'folder' then rows~append(e)
  end
  return .ShellCollection~new(rows)
::method edit protected
  raise syntax 93.900 array ('A folder cannot be edited:' self~path)
::method relatedSamples
  return .Array~new
::method capabilities
  return .Array~of('READ')
::method fields
  return .Array~of('relPath', 'kind', 'modified')

/* Native: a pinned directory read in bounded batches, closed on every path.
   Plain Rexx: .File~listFiles. Either way links are listed and not followed. */
::method listOwn private
  use strict arg limit
  rows = .Array~new
  p = .ShellNative~posix
  if p \== .nil then do
    r = p~openRoot(self~path)
    if r['OK'] then do
      root = r['ROOT']
      signal on syntax name nativeFailed
      c = root~scan
      if c['OK'] then do
        cursor = c['CURSOR']
        done = .false
        do while \done, rows~items < limit
          b = cursor~nextBatch(min(256, limit - rows~items))
          if \b['OK'] then leave
          do e over b['ENTRIES']
            if e['NAME'] == '.' | e['NAME'] == '..' then iterate
            rows~append(self~entryFor(self~path'/'e['NAME']))
            if rows~items >= limit then leave
          end
          done = b['DONE']
        end
        cursor~close
      end
      root~close
      return rows
    end
  end
  entries = .File~new(self~path)~listFiles
  if entries == .nil then return rows
  do e over entries
    rows~append(self~entryFor(e~absolutePath))
    if rows~items >= limit then leave
  end
  return rows
nativeFailed:
  c = condition('O')
  if symbol('CURSOR') == 'VAR' then cursor~close
  root~close
  raise propagate

::method entryFor private
  use strict arg full
  f = .File~new(full)
  if SysIsFileLink(full) then return .FsFile~new(self~rootOf, f, 'link')
  if f~isDirectory then return .FsFolder~new(self~rootOf, f)
  if f~isFile then return .FsFile~new(self~rootOf, f, 'file')
  return .FsFile~new(self~rootOf, f, 'other')

::method rootOf private
  return self~rootPath            -- the root lives in FsFile's variable scope


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
