/*----------------------------------------------------------------------------*/
/* ooRexx POSIX Foundation v0.1-dev1                                          */
/* Public facade. Applications should require this file, not provider files.   */
/*----------------------------------------------------------------------------*/

::class PosixBuild public
::constant VERSION '0.1-dev1'
::constant API 'oorexx.posix/0.1'

::class Posix public

::method init
  expose provider
  use strict arg providerArg = .nil
  if providerArg == .nil then provider = .PosixRxUnixSysProvider~new
  else provider = providerArg

::method provider
  expose provider
  return provider~name

::method capabilities
  expose provider
  return provider~capabilities

::method stat
  expose provider
  use strict arg path
  return provider~stat(path)

::method statBasic
  expose provider
  use strict arg path
  return provider~statBasic(path)

::method lstat
  expose provider
  use strict arg path
  return provider~lstat(path)

::method readLink
  expose provider
  use strict arg path
  return provider~readLink(path)

::method listDirectory
  expose provider
  use strict arg path, includeDots = .false
  return provider~listDirectory(path, includeDots)

::method access
  expose provider
  use strict arg path, mode
  return provider~access(path, mode)

::method chmod
  expose provider
  use strict arg path, mode
  return provider~chmod(path, mode)

::method chown
  expose provider
  use strict arg path, uid, gid
  return provider~chown(path, uid, gid)

::method lchown
  expose provider
  use strict arg path, uid, gid
  return provider~lchown(path, uid, gid)

::method link
  expose provider
  use strict arg source, target
  return provider~link(source, target)

::method symlink
  expose provider
  use strict arg targetText, linkPath
  return provider~symlink(targetText, linkPath)

::method mkdir
  expose provider
  use strict arg path, mode = 493
  return provider~mkdir(path, mode)

::method removeDirectory
  expose provider
  use strict arg path
  return provider~removeDirectory(path)

::method unlink
  expose provider
  use strict arg path
  return provider~unlink(path)

::method credentials
  expose provider
  return provider~credentials

::method lookupUser
  expose provider
  use strict arg key
  return provider~lookupUser(key)

::method lookupGroup
  expose provider
  use strict arg key
  return provider~lookupGroup(key)

::method fsync
  expose provider
  use strict arg fd
  return provider~fsync(fd)

::method fdatasync
  expose provider
  use strict arg fd
  return provider~fdatasync(fd)

::method getXattr
  expose provider
  use strict arg path, name
  return provider~getXattr(path, name)

::method listXattrs
  expose provider
  use strict arg path
  return provider~listXattrs(path)

::method getXattrWeak
  expose provider
  use strict arg path, name
  return provider~getXattrWeak(path, name)

::method listXattrsWeak
  expose provider
  use strict arg path
  return provider~listXattrsWeak(path)

::method setXattr
  expose provider
  use strict arg path, name, value
  return provider~setXattr(path, name, value)

::method removeXattr
  expose provider
  use strict arg path, name
  return provider~removeXattr(path, name)

::requires 'PosixResult.cls'
::requires 'PosixCapabilities.cls'
::requires 'PosixStat.cls'
::requires 'PosixDirectory.cls'
::requires 'PosixCredentials.cls'
::requires 'PosixXattr.cls'
::requires 'PosixRxUnixSysProvider.cls'
