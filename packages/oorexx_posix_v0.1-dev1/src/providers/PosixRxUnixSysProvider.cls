/*----------------------------------------------------------------------------*/
/* ooRexx POSIX Foundation v0.1-dev1                                          */
/* Existing-runtime provider: RxUnixSys first, RexxUtil where appropriate.    */
/*                                                                            */
/* This provider intentionally DOES NOT pretend repeated SysStat() calls form */
/* a coherent metadata snapshot. Strong stat/lstat/readlink remain explicit   */
/* capability gaps until the native extension / gap provider is supplied.     */
/*----------------------------------------------------------------------------*/

::class PosixRxUnixSysProvider public

::method init
  expose capabilities
  capabilities = .PosixCapabilities~new

  if self~hasRoutine('SysStat') then capabilities~add('posix.stat.basic')
  if self~hasRoutine('SysGetdirlist') then capabilities~add('posix.dir.iterate')
  if self~hasRoutine('SysAccess') then capabilities~add('posix.access')
  if self~hasRoutine('SysChmod') then capabilities~add('posix.chmod')
  if self~hasRoutine('SysChown') then capabilities~add('posix.chown')
  if self~hasRoutine('SysLchown') then capabilities~add('posix.lchown')
  if self~hasRoutine('SysLink') then capabilities~add('posix.link')
  if self~hasRoutine('SysSymlink') then capabilities~add('posix.symlink')
  if self~hasRoutine('SysMkdirUnix') then capabilities~add('posix.mkdir')
  if self~hasRoutine('SysRmdirUnix') then capabilities~add('posix.rmdir')
  if self~hasRoutine('SysUnLink') then capabilities~add('posix.unlink')

  if self~hasRoutine('SysGetuid') & self~hasRoutine('SysGeteuid') & -
     self~hasRoutine('SysGetgid') & self~hasRoutine('SysGetegid') then -
    capabilities~add('posix.credentials')

  if self~hasRoutine('SysGetpwnam') & self~hasRoutine('SysGetpwuid') then -
    capabilities~add('posix.user.scalar')

  /* Do not advertise arbitrary group lookup in the supplied 5.3.0 r13196
     build: SysGetgrnam/SysGetgrgid segfault on a missing record. */

  /* RxUnixSys read APIs cannot distinguish a legitimate empty xattr/list
     from failure because success does not clear errno. Advertise that fact. */
  if self~hasRoutine('SysGetxattr') & self~hasRoutine('SysListxattr') then -
    capabilities~add('posix.xattr.weak-read')
  if self~hasRoutine('SysSetxattr') & self~hasRoutine('SysRemovexattr') then -
    capabilities~add('posix.xattr.write')

  if self~hasRoutine('SysFileCopy') then capabilities~add('rexxutil.file.copy')
  if self~hasRoutine('SysFileMove') then capabilities~add('rexxutil.file.move')
  if self~hasRoutine('SysFileDelete') then capabilities~add('rexxutil.file.delete')
  if self~hasRoutine('SysFileTree') then capabilities~add('rexxutil.file.tree')
  if self~hasRoutine('SysTempFileName') then capabilities~add('rexxutil.temp-name')
  if self~hasRoutine('SysFork') then capabilities~add('rexxutil.process.fork')
  if self~hasRoutine('SysWait') then capabilities~add('rexxutil.process.wait-any')
  if self~hasRoutine('SysCreatePipe') then capabilities~add('rexxutil.pipe')

::method name
  return 'rxunixsys'

::method capabilities
  expose capabilities
  return capabilities

::method hasRoutine private
  use strict arg name
  return RxFuncQuery(name) = 0

::method nativeFailure private
  use strict arg operation, capability, path = '', paths = .nil
  /* SysGeterrno must be the first native call after the failed operation. */
  e = SysGeterrno()
  message = SysGeterrnomsg(e)
  evidence = .PosixEvidence~new(operation, self~name, capability, path, paths, .nil, .nil, 1, 'NATIVE')
  error = .PosixError~new(operation, self~name, capability, path, paths, e, '', message)
  return .PosixResult~failure(error, evidence)

::method unsupported private
  use strict arg operation, capability, path = ''
  return .PosixResult~unsupported(operation, self~name, capability, path)

::method mutationResult private
  use strict arg rc, operation, capability, path = '', paths = .nil
  if rc = 0 then do
    evidence = .PosixEvidence~new(operation, self~name, capability, path, paths, .nil, .nil, 1, 'NATIVE')
    return .PosixResult~success(rc, evidence)
  end
  return self~nativeFailure(operation, capability, path, paths)

::method stat
  use strict arg path
  return self~unsupported('stat', 'posix.stat.coherent', path)

::method lstat
  use strict arg path
  return self~unsupported('lstat', 'posix.lstat.coherent', path)

::method readLink
  use strict arg path
  return self~unsupported('readLink', 'posix.readlink', path)

::method statBasic
  use strict arg path
  if \self~capabilities~has('posix.stat.basic') then -
    return self~unsupported('statBasic', 'posix.stat.basic', path)

  values = .directory~new
  values['path'] = path
  values['provider'] = self~name
  values['coherent'] = .false
  values['observationCount'] = 11

  v = SysStat(path, 'DEVICE')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['device'] = v

  v = SysStat(path, 'INODE')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['inode'] = v

  v = SysStat(path, 'PERMISSIONS')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['permissions'] = v

  v = SysStat(path, 'NUMBERLINKS')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['linkCount'] = v

  v = SysStat(path, 'UID')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['uid'] = v

  v = SysStat(path, 'GID')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['gid'] = v

  v = SysStat(path, 'REALDEV')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['realDevice'] = v

  v = SysStat(path, 'SIZE')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['size'] = v

  v = SysStat(path, 'ACCESS')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['accessed'] = v

  v = SysStat(path, 'MODIFIED')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['modified'] = v

  v = SysStat(path, 'CHANGED')
  if v == '' then return self~nativeFailure('statBasic', 'posix.stat.basic', path)
  values['changed'] = v

  stat = .PosixStat~new(values)
  evidence = .PosixEvidence~new('statBasic', self~name, 'posix.stat.basic', path, .nil, .true, .false, 11, -
                                'MULTI_OBSERVATION', 'Repeated SysStat calls are not a coherent snapshot')
  return .PosixResult~success(stat, evidence)

::method listDirectory
  use strict arg path, includeDots = .false
  if \self~capabilities~has('posix.dir.iterate') then -
    return self~unsupported('listDirectory', 'posix.dir.iterate', path)

  raw = SysGetdirlist(path)
  /* RxUnixSys documents an empty array as the open-directory error result.
     It normally includes . and .. on a successful empty directory. */
  if raw~items = 0 then return self~nativeFailure('listDirectory', 'posix.dir.iterate', path)

  entries = .array~new
  do entry over raw
    if \includeDots & (entry == '.' | entry == '..') then iterate
    entries~append(entry)
  end
  listing = .PosixDirectoryListing~new(path, entries, self~name, includeDots, raw~items)
  evidence = .PosixEvidence~new('listDirectory', self~name, 'posix.dir.iterate', path, .nil, .false, .false, 1, -
                                'SINGLE_DIRECTORY_STREAM', 'Directory contents may change during iteration')
  return .PosixResult~success(listing, evidence)

::method access
  use strict arg path, mode
  if \self~capabilities~has('posix.access') then return self~unsupported('access', 'posix.access', path)
  rc = SysAccess(path, mode)
  if rc = 0 then do
    evidence = .PosixEvidence~new('access', self~name, 'posix.access', path, .nil, .true, .nil, 1, 'NATIVE')
    return .PosixResult~success(.true, evidence)
  end
  return self~nativeFailure('access', 'posix.access', path)

::method chmod
  use strict arg path, mode
  if \self~capabilities~has('posix.chmod') then return self~unsupported('chmod', 'posix.chmod', path)
  rc = SysChmod(path, mode)
  return self~mutationResult(rc, 'chmod', 'posix.chmod', path)

::method chown
  use strict arg path, uid, gid
  if \self~capabilities~has('posix.chown') then return self~unsupported('chown', 'posix.chown', path)
  rc = SysChown(path, uid, gid)
  return self~mutationResult(rc, 'chown', 'posix.chown', path)

::method lchown
  use strict arg path, uid, gid
  if \self~capabilities~has('posix.lchown') then return self~unsupported('lchown', 'posix.lchown', path)
  rc = SysLchown(path, uid, gid)
  return self~mutationResult(rc, 'lchown', 'posix.lchown', path)

::method link
  use strict arg source, target
  if \self~capabilities~has('posix.link') then return self~unsupported('link', 'posix.link', source)
  paths = .array~of(source, target)
  rc = SysLink(source, target)
  return self~mutationResult(rc, 'link', 'posix.link', source, paths)

::method symlink
  use strict arg targetText, linkPath
  if \self~capabilities~has('posix.symlink') then return self~unsupported('symlink', 'posix.symlink', linkPath)
  paths = .array~of(targetText, linkPath)
  rc = SysSymlink(targetText, linkPath)
  return self~mutationResult(rc, 'symlink', 'posix.symlink', linkPath, paths)

::method mkdir
  use strict arg path, mode = 493
  if \self~capabilities~has('posix.mkdir') then return self~unsupported('mkdir', 'posix.mkdir', path)
  rc = SysMkdirUnix(path, mode)
  return self~mutationResult(rc, 'mkdir', 'posix.mkdir', path)

::method removeDirectory
  use strict arg path
  if \self~capabilities~has('posix.rmdir') then return self~unsupported('removeDirectory', 'posix.rmdir', path)
  rc = SysRmdirUnix(path)
  return self~mutationResult(rc, 'removeDirectory', 'posix.rmdir', path)

::method unlink
  use strict arg path
  if \self~capabilities~has('posix.unlink') then return self~unsupported('unlink', 'posix.unlink', path)
  rc = SysUnLink(path)
  return self~mutationResult(rc, 'unlink', 'posix.unlink', path)

::method credentials
  if \self~capabilities~has('posix.credentials') then return self~unsupported('credentials', 'posix.credentials')
  c = .PosixCredentials~new(SysGetuid(), SysGeteuid(), SysGetgid(), SysGetegid())
  evidence = .PosixEvidence~new('credentials', self~name, 'posix.credentials', '', .nil, .nil, .false, 4, -
                                'MULTI_OBSERVATION', 'Credential fields are separate native observations')
  return .PosixResult~success(c, evidence)

::method lookupUser
  use strict arg key
  if \self~capabilities~has('posix.user.scalar') then return self~unsupported('lookupUser', 'posix.user.scalar')
  byUid = datatype(key, 'W')
  if byUid then name = SysGetpwuid(key, 'NAME')
  else name = SysGetpwnam(key, 'NAME')
  if name == '' then do
    evidence = .PosixEvidence~new('lookupUser', self~name, 'posix.user.scalar', '', .nil, .nil, .false, 1, -
                                  'LOOKUP', 'RxUnixSys returns empty with errno 0 when no passwd record exists')
    error = .PosixError~new('lookupUser', self~name, 'posix.user.scalar', '', .nil, 0, '', -
                            'No matching user record', .false, 'LOOKUP_NOT_FOUND')
    return .PosixResult~failure(error, evidence)
  end
  if byUid then do
    uid = SysGetpwuid(key, 'USER'); gid = SysGetpwuid(key, 'GROUP')
    realName = SysGetpwuid(key, 'REALNAME'); home = SysGetpwuid(key, 'DIRECTORY'); shell = SysGetpwuid(key, 'SHELL')
  end
  else do
    uid = SysGetpwnam(key, 'USER'); gid = SysGetpwnam(key, 'GROUP')
    realName = SysGetpwnam(key, 'REALNAME'); home = SysGetpwnam(key, 'DIRECTORY'); shell = SysGetpwnam(key, 'SHELL')
  end
  user = .PosixUser~new(name, uid, gid, realName, home, shell, self~name, .false)
  evidence = .PosixEvidence~new('lookupUser', self~name, 'posix.user.scalar', '', .nil, .nil, .false, 6, -
                                'MULTI_OBSERVATION', 'RxUnixSys account lookup is option-selecting')
  return .PosixResult~success(user, evidence)

::method lookupGroup
  use strict arg key
  /* Fail closed. In the supplied ooRexx 5.3.0 r13196 debug build both
     SysGetgrnam() and SysGetgrgid() terminate the interpreter when the
     requested record is absent. A facade must not turn that into a public
     lookup contract. */
  return self~unsupported('lookupGroup', 'posix.group.safe-lookup')

::method fsync
  use strict arg fd
  return self~unsupported('fsync', 'posix.sync.fsync')

::method fdatasync
  use strict arg fd
  return self~unsupported('fdatasync', 'posix.sync.fdatasync')

::method getXattr
  use strict arg path, name
  /* A strong getXattr result is impossible with current RxUnixSys because
     empty binary value and error both return an empty string. */
  return self~unsupported('getXattr', 'posix.xattr', path)

::method listXattrs
  use strict arg path
  /* A strong list is impossible because empty success and error are both an
     empty array while errno is not reset by successful native calls. */
  return self~unsupported('listXattrs', 'posix.xattr', path)

::method getXattrWeak
  use strict arg path, name
  if \self~capabilities~has('posix.xattr.weak-read') then -
    return self~unsupported('getXattrWeak', 'posix.xattr.weak-read', path)
  value = SysGetxattr(path, name)
  ambiguous = value~length = 0
  obs = .PosixXattrValue~new(path, name, value, ambiguous, self~name)
  warning = ''
  if ambiguous then warning = 'Empty value is ambiguous: RxUnixSys also returns empty on error'
  evidence = .PosixEvidence~new('getXattrWeak', self~name, 'posix.xattr.weak-read', path, .nil, .true, .false, 1, -
                                'WEAK_EMPTY_SENTINEL', warning)
  return .PosixResult~success(obs, evidence)

::method listXattrsWeak
  use strict arg path
  if \self~capabilities~has('posix.xattr.weak-read') then -
    return self~unsupported('listXattrsWeak', 'posix.xattr.weak-read', path)
  names = SysListxattr(path)
  ambiguous = names~items = 0
  obs = .PosixXattrList~new(path, names, ambiguous, self~name)
  warning = ''
  if ambiguous then warning = 'Empty list is ambiguous: RxUnixSys also returns empty on error'
  evidence = .PosixEvidence~new('listXattrsWeak', self~name, 'posix.xattr.weak-read', path, .nil, .true, .false, 1, -
                                'WEAK_EMPTY_SENTINEL', warning)
  return .PosixResult~success(obs, evidence)

::method setXattr
  use strict arg path, name, value
  if \self~capabilities~has('posix.xattr.write') then -
    return self~unsupported('setXattr', 'posix.xattr.write', path)
  rc = SysSetxattr(path, name, value)
  return self~mutationResult(rc, 'setXattr', 'posix.xattr.write', path)

::method removeXattr
  use strict arg path, name
  if \self~capabilities~has('posix.xattr.write') then -
    return self~unsupported('removeXattr', 'posix.xattr.write', path)
  rc = SysRemovexattr(path, name)
  return self~mutationResult(rc, 'removeXattr', 'posix.xattr.write', path)

::requires 'PosixResult.cls'
::requires 'PosixCapabilities.cls'
::requires 'PosixStat.cls'
::requires 'PosixDirectory.cls'
::requires 'PosixCredentials.cls'
::requires 'PosixXattr.cls'
::requires 'rxunixsys' LIBRARY
