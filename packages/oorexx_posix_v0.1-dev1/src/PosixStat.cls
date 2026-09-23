/* ooRexx POSIX Foundation v0.1-dev1 - filesystem metadata objects. */

::class PosixFileIdentity public
::attribute device get
::attribute inode get
::attribute fileType get

::method init
  expose device inode fileType
  use strict arg device, inode, fileType = ''

::method string
  expose device inode fileType
  s = device || ':' || inode
  if fileType \== '' & fileType \== .nil then s ||= ':' || fileType
  return s


::class PosixStat public
::attribute observedPath get
::attribute path get
::attribute device get
::attribute inode get
::attribute mode get
::attribute fileType get
::attribute permissions get
::attribute linkCount get
::attribute uid get
::attribute gid get
::attribute rdev get
::attribute realDevice get
::attribute size get
::attribute blockSize get
::attribute blocks get
::attribute atimeSec get
::attribute atimeNsec get
::attribute mtimeSec get
::attribute mtimeNsec get
::attribute ctimeSec get
::attribute ctimeNsec get
::attribute birthTimeSec get
::attribute birthTimeNsec get
::attribute accessed get
::attribute modified get
::attribute changed get
::attribute followedSymlink get
::attribute coherent get
::attribute provider get
::attribute observationCount get

::method init
  expose observedPath path device inode mode fileType permissions linkCount uid gid rdev realDevice size -
         blockSize blocks atimeSec atimeNsec mtimeSec mtimeNsec ctimeSec ctimeNsec birthTimeSec birthTimeNsec -
         accessed modified changed followedSymlink coherent provider observationCount
  use strict arg values
  path = values['path']
  if path == .nil then path = values['observedPath']
  observedPath = path
  device = values['device']
  inode = values['inode']
  mode = values['mode']
  fileType = values['fileType']
  permissions = values['permissions']
  linkCount = values['linkCount']
  uid = values['uid']
  gid = values['gid']
  rdev = values['rdev']
  if rdev == .nil then rdev = values['realDevice']
  realDevice = rdev
  size = values['size']
  blockSize = values['blockSize']
  blocks = values['blocks']
  atimeSec = values['atimeSec']
  atimeNsec = values['atimeNsec']
  mtimeSec = values['mtimeSec']
  mtimeNsec = values['mtimeNsec']
  ctimeSec = values['ctimeSec']
  ctimeNsec = values['ctimeNsec']
  birthTimeSec = values['birthTimeSec']
  birthTimeNsec = values['birthTimeNsec']
  accessed = values['accessed']
  modified = values['modified']
  changed = values['changed']
  followedSymlink = values['followedSymlink']
  coherent = values['coherent']
  provider = values['provider']
  observationCount = values['observationCount']

::method identity
  expose coherent device inode fileType
  if \coherent then return .nil
  return .PosixFileIdentity~new(device, inode, fileType)

::method weakIdentity
  expose device inode fileType
  return .PosixFileIdentity~new(device, inode, fileType)
