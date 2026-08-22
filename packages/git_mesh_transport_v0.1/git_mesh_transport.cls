/* git_mesh_transport.cls
 * Deterministic Git-backed message spool addressing for the Alchemy mesh.
 * Runtime state lives under <root>/mesh; this package contains no agent logic.
 */

::class GitMeshTransport public

::method init
  expose root lastError
  use strict arg root = '.'
  root = self~trimTrailingSlash(root)
  if root == '' then root = '.'
  lastError = ''

::attribute root get
::attribute lastError get

::method ensureLayout
  expose root lastError
  lastError = ''
  if \self~ensureDir(root) then return 0
  if \self~ensureDir(root || '/mesh') then return 0
  if \self~ensureDir(root || '/mesh/ctl') then return 0
  if \self~ensureDir(root || '/mesh/announce') then return 0
  if \self~ensureDir(root || '/mesh/notes') then return 0
  return 1

::method routeDir
  expose root lastError
  use strict arg fromNode, toNode
  lastError = ''
  if \self~validPart(fromNode) then do
    lastError = 'invalid from node'
    return .nil
  end
  if \self~validPart(toNode) then do
    lastError = 'invalid to node'
    return .nil
  end
  return root || '/mesh/ctl/' || fromNode || '-' || toNode

::method messagePath
  expose lastError
  use strict arg fromNode, toNode, messageName
  route = self~routeDir(fromNode, toNode)
  if route == .nil then return .nil
  if \self~validPart(messageName) then do
    lastError = 'invalid message name'
    return .nil
  end
  return route || '/' || messageName

::method announcePath
  expose root lastError
  use strict arg node
  lastError = ''
  if \self~validPart(node) then do
    lastError = 'invalid node'
    return .nil
  end
  return root || '/mesh/announce/node.' || node || '.json'

::method notePath
  expose root lastError
  use strict arg node, noteName
  lastError = ''
  if \self~validPart(node) then do
    lastError = 'invalid node'
    return .nil
  end
  if \self~validPart(noteName) then do
    lastError = 'invalid note name'
    return .nil
  end
  return root || '/mesh/notes/' || node || '/' || noteName

::method send
  expose lastError
  use strict arg fromNode, toNode, messageName, jsonText
  lastError = ''
  if left(strip(jsonText), 1) \== '{' then do
    lastError = 'payload must be a JSON object text'
    return 0
  end
  if \self~ensureLayout then return 0
  route = self~routeDir(fromNode, toNode)
  if route == .nil then return 0
  if \self~ensureDir(route) then return 0
  path = self~messagePath(fromNode, toNode, messageName)
  if path == .nil then return 0
  if SysFileExists(path) then do
    lastError = 'message already exists (append-only transport)'
    return 0
  end
  return self~writeFile(path, 'EVENT|' || jsonText)

::method read
  expose lastError
  use strict arg path
  lastError = ''
  if \SysFileExists(path) then do
    lastError = 'message does not exist'
    return .nil
  end
  s = .stream~new(path)
  if s~open('read') \== 'READY:' then do
    lastError = 'cannot open message for read'
    return .nil
  end
  line = s~linein
  s~close
  if left(line, 6) \== 'EVENT|' then do
    lastError = 'invalid message envelope'
    return .nil
  end
  return substr(line, 7)

::method writeAnnouncement
  expose lastError
  use strict arg node, jsonText
  lastError = ''
  if left(strip(jsonText), 1) \== '{' then do
    lastError = 'announcement must be a JSON object text'
    return 0
  end
  if \self~ensureLayout then return 0
  path = self~announcePath(node)
  if path == .nil then return 0
  return self~writeFile(path, jsonText)

::method writeNote
  expose root lastError
  use strict arg node, noteName, text
  lastError = ''
  if \self~ensureLayout then return 0
  path = self~notePath(node, noteName)
  if path == .nil then return 0
  dir = root || '/mesh/notes/' || node
  if \self~ensureDir(dir) then return 0
  if SysFileExists(path) then do
    lastError = 'note already exists'
    return 0
  end
  return self~writeFile(path, text)

::method validPart private
  use strict arg part
  if part == '' then return 0
  if part == '.' | part == '..' then return 0
  allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'
  return verify(part, allowed) == 0

::method ensureDir private
  expose lastError
  use strict arg path
  if SysFileExists(path) then return 1
  rc = SysMkDir(path)
  if rc == 0 then return 1
  lastError = 'cannot create directory: ' || path || ' rc=' || rc
  return 0

::method writeFile private
  expose lastError
  use strict arg path, text
  s = .stream~new(path)
  if s~open('write replace') \== 'READY:' then do
    lastError = 'cannot open file for write: ' || path
    return 0
  end
  s~lineout(text)
  s~close
  return 1

::method trimTrailingSlash private
  use strict arg path
  do while length(path) > 1 & right(path, 1) == '/'
    path = left(path, length(path) - 1)
  end
  return path
