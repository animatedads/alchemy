/* ooRexx POSIX Foundation v0.1-dev1 - credentials and account records. */

::class PosixCredentials public
::attribute uid get
::attribute euid get
::attribute gid get
::attribute egid get

::method init
  expose uid euid gid egid
  use strict arg uid, euid, gid, egid


::class PosixUser public
::attribute name get
::attribute uid get
::attribute gid get
::attribute realName get
::attribute home get
::attribute shell get
::attribute coherent get
::attribute provider get

::method init
  expose name uid gid realName home shell coherent provider
  use strict arg name, uid, gid, realName, home, shell, provider = 'rxunixsys', coherent = .false


::class PosixGroup public
::attribute name get
::attribute gid get
::attribute members get
::attribute coherent get
::attribute provider get

::method init
  expose name gid members coherent provider
  use strict arg name, gid, members, provider = 'rxunixsys', coherent = .false
