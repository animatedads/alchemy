/*----------------------------------------------------------------------------*/
/* Temporary coherent-stat provider over librxposixgap.                       */
/*                                                                            */
/* This class exists only as a migration seam until these generally useful    */
/* primitives are available from RxUnixSys. All non-gap operations delegate   */
/* to PosixRxUnixSysProvider.                                                  */
/*----------------------------------------------------------------------------*/

::class PosixGapProvider public

::method init
  expose base capabilities
  base = .PosixRxUnixSysProvider~new
  capabilities = .PosixCapabilities~new(base~capabilities~names)
  capabilities~add('posix.stat.coherent')
  capabilities~add('posix.lstat.coherent')
  capabilities~add('posix.readlink')
  capabilities~add('posix.sync.fsync')
  capabilities~add('posix.sync.fdatasync')

::method name
  return 'rxposixgap+rxunixsys'

::method capabilities
  expose capabilities
  return capabilities

::method nativeError private
  use strict arg d, operation, capability, path = ''
  e = d['ERRNO']
  msg = d['ERROR_MESSAGE']
  evidence = .PosixEvidence~new(operation, 'rxposixgap', capability, path, .nil, .nil, .nil, 1, 'NATIVE')
  error = .PosixError~new(operation, 'rxposixgap', capability, path, .nil, e, '', msg)
  return .PosixResult~failure(error, evidence)

::method modeBit private
  use strict arg mode, bit
  return (mode // (bit * 2)) >= bit

::method permissionsFor private
  use strict arg mode, fileType
  select
    when fileType == 'DIRECTORY' then p = 'd'
    when fileType == 'SYMLINK' then p = 'l'
    when fileType == 'CHARACTER_DEVICE' then p = 'c'
    when fileType == 'BLOCK_DEVICE' then p = 'b'
    when fileType == 'FIFO' then p = 'p'
    when fileType == 'SOCKET' then p = 's'
    otherwise p = '-'
  end
  bits = .array~of(256,128,64,32,16,8,4,2,1)
  chars = 'rwxrwxrwx'
  do i = 1 to 9
    if self~modeBit(mode, bits[i]) then p ||= substr(chars, i, 1)
    else p ||= '-'
  end
  /* setuid/setgid/sticky decoration */
  if self~modeBit(mode, 2048) then do
    c = substr(p, 4, 1); if c == 'x' then c = 's'; else c = 'S'; p = overlay(c, p, 4)
  end
  if self~modeBit(mode, 1024) then do
    c = substr(p, 7, 1); if c == 'x' then c = 's'; else c = 'S'; p = overlay(c, p, 7)
  end
  if self~modeBit(mode, 512) then do
    c = substr(p, 10, 1); if c == 'x' then c = 't'; else c = 'T'; p = overlay(c, p, 10)
  end
  return p

::method fromNativeStat private
  use strict arg d, operation, capability, path
  if \d['OK'] then return self~nativeError(d, operation, capability, path)
  values = .directory~new
  values['path'] = d['PATH']
  values['device'] = d['DEVICE']
  values['inode'] = d['INODE']
  values['mode'] = d['MODE']
  values['fileType'] = d['FILETYPE']
  values['permissions'] = self~permissionsFor(d['MODE'], d['FILETYPE'])
  values['linkCount'] = d['LINKCOUNT']
  values['uid'] = d['UID']
  values['gid'] = d['GID']
  values['rdev'] = d['RDEV']
  values['realDevice'] = d['RDEV']
  values['size'] = d['SIZE']
  values['blockSize'] = d['BLOCKSIZE']
  values['blocks'] = d['BLOCKS']
  values['atimeSec'] = d['ATIME_SEC']
  values['atimeNsec'] = d['ATIME_NSEC']
  values['mtimeSec'] = d['MTIME_SEC']
  values['mtimeNsec'] = d['MTIME_NSEC']
  values['ctimeSec'] = d['CTIME_SEC']
  values['ctimeNsec'] = d['CTIME_NSEC']
  values['birthTimeSec'] = .nil
  values['birthTimeNsec'] = .nil
  values['accessed'] = .nil
  values['modified'] = .nil
  values['changed'] = .nil
  values['followedSymlink'] = d['FOLLOWED_SYMLINK']
  values['coherent'] = .true
  values['provider'] = 'rxposixgap'
  values['observationCount'] = 1
  stat = .PosixStat~new(values)
  evidence = .PosixEvidence~new(operation, 'rxposixgap', capability, path, .nil, d['FOLLOWED_SYMLINK'], .true, 1, -
                                'SINGLE_NATIVE_STAT')
  return .PosixResult~success(stat, evidence)

::method stat
  use strict arg path
  return self~fromNativeStat(PosixGapStatInfo(path), 'stat', 'posix.stat.coherent', path)

::method lstat
  use strict arg path
  return self~fromNativeStat(PosixGapLstatInfo(path), 'lstat', 'posix.lstat.coherent', path)

::method readLink
  use strict arg path
  d = PosixGapReadlink(path)
  if \d['OK'] then return self~nativeError(d, 'readLink', 'posix.readlink', path)
  evidence = .PosixEvidence~new('readLink', 'rxposixgap', 'posix.readlink', path, .nil, .false, .nil, 1, -
                                'PATH_OBSERVATION')
  return .PosixResult~success(d['VALUE'], evidence)

::method fsync
  use strict arg fd
  d = PosixGapFsync(fd)
  if \d['OK'] then return self~nativeError(d, 'fsync', 'posix.sync.fsync')
  evidence = .PosixEvidence~new('fsync', 'rxposixgap', 'posix.sync.fsync', '', .nil, .nil, .nil, 1, 'NATIVE')
  return .PosixResult~success(0, evidence)

::method fdatasync
  use strict arg fd
  d = PosixGapFdatasync(fd)
  if \d['OK'] then return self~nativeError(d, 'fdatasync', 'posix.sync.fdatasync')
  evidence = .PosixEvidence~new('fdatasync', 'rxposixgap', 'posix.sync.fdatasync', '', .nil, .nil, .nil, 1, 'NATIVE')
  return .PosixResult~success(0, evidence)

/* Everything already owned by RxUnixSys remains delegated to it. */
::method statBasic; expose base; use strict arg path; return base~statBasic(path)
::method listDirectory; expose base; use strict arg path, includeDots = .false; return base~listDirectory(path, includeDots)
::method access; expose base; use strict arg path, mode; return base~access(path, mode)
::method chmod; expose base; use strict arg path, mode; return base~chmod(path, mode)
::method chown; expose base; use strict arg path, uid, gid; return base~chown(path, uid, gid)
::method lchown; expose base; use strict arg path, uid, gid; return base~lchown(path, uid, gid)
::method link; expose base; use strict arg source, target; return base~link(source, target)
::method symlink; expose base; use strict arg targetText, linkPath; return base~symlink(targetText, linkPath)
::method mkdir; expose base; use strict arg path, mode = 493; return base~mkdir(path, mode)
::method removeDirectory; expose base; use strict arg path; return base~removeDirectory(path)
::method unlink; expose base; use strict arg path; return base~unlink(path)
::method credentials; expose base; return base~credentials
::method lookupUser; expose base; use strict arg key; return base~lookupUser(key)
::method lookupGroup; expose base; use strict arg key; return base~lookupGroup(key)
::method getXattr; expose base; use strict arg path, name; return base~getXattr(path, name)
::method listXattrs; expose base; use strict arg path; return base~listXattrs(path)
::method getXattrWeak; expose base; use strict arg path, name; return base~getXattrWeak(path, name)
::method listXattrsWeak; expose base; use strict arg path; return base~listXattrsWeak(path)
::method setXattr; expose base; use strict arg path, name, value; return base~setXattr(path, name, value)
::method removeXattr; expose base; use strict arg path, name; return base~removeXattr(path, name)

::requires 'PosixResult.cls'
::requires 'PosixCapabilities.cls'
::requires 'PosixStat.cls'
::requires 'PosixRxUnixSysProvider.cls'
::requires 'rxposixgap' LIBRARY
