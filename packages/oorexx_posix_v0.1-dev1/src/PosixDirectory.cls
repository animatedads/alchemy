/* ooRexx POSIX Foundation v0.1-dev1 - directory listing objects. */

::class PosixDirectoryListing public
::attribute path get
::attribute entries get
::attribute provider get
::attribute includesDots get
::attribute rawEntryCount get
::attribute coherent get

::method init
  expose path entries provider includesDots rawEntryCount coherent
  use strict arg path, entries, provider, includesDots = .false, rawEntryCount = 0
  coherent = .false

::method items
  expose entries
  return entries~items
