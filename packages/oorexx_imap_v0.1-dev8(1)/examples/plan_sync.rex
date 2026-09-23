caps = .ImapCapabilities~new~add("QRESYNC")~add("CONDSTORE")
previous = .ImapMailboxState~new
previous~uidValidity = "12345"
previous~highestModSeq = "890"
plan = .ImapSyncPlanner~plan(caps, previous, previous~copy, "900000")
say plan~strategy ":" plan~reason
::requires "ImapCore.cls"
