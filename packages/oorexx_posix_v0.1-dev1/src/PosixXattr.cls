/* ooRexx POSIX Foundation v0.1-dev1 - deliberately weak RxUnixSys xattr observations. */

::class PosixXattrValue public
::attribute path get
::attribute name get
::attribute value get
::attribute ambiguousEmpty get
::attribute provider get

::method init
  expose path name value ambiguousEmpty provider
  use strict arg path, name, value, ambiguousEmpty, provider = 'rxunixsys'


::class PosixXattrList public
::attribute path get
::attribute names get
::attribute ambiguousEmpty get
::attribute provider get

::method init
  expose path names ambiguousEmpty provider
  use strict arg path, names, ambiguousEmpty, provider = 'rxunixsys'

::method items
  expose names
  return names~items
