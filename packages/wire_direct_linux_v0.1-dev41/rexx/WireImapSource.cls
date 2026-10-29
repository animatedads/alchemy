/* Wire Direct IMAP source adapter: protocol stays behind this boundary. */
::class WireImapMessageRef public
::attribute mailbox get
::attribute uidValidity get
::attribute uid get
::method init
  expose mailbox uidValidity uid
  use strict arg mailbox, uidValidity, uid

::class WireImapRange public
::attribute rows get
::attribute start get
::attribute count get
::method init
  expose rows start count
  use strict arg start, rows
  count = rows~items

::class WireImapMailboxCollection public
::attribute mailbox get
::attribute uidValidity get
::method init
  expose session mailbox uidValidity uidSet
  use strict arg session, mailbox
  r = session~examine(mailbox)
  if \r~ok then raise syntax 88.900 array("WIRE_IMAP_EXAMINE_FAILED", mailbox)
  uidValidity = session~selectedState~uidValidity
  pair = session~uidSearch("ALL", "COUNT MIN MAX ALL")
  if \pair[1]~ok | pair[2]~all == .nil then raise syntax 88.900 array("WIRE_IMAP_SEARCH_FAILED", mailbox)
  uidSet = pair[2]~all
::method count
  expose uidSet
  return uidSet~count
::method identityAt
  expose uidSet mailbox uidValidity
  use strict arg ordinal
  if ordinal < 1 | ordinal > uidSet~count then raise syntax 88.900 array("WIRE_RANGE", ordinal)
  return .WireImapMessageRef~new(mailbox, uidValidity, uidSet~uidAtOrdinal(ordinal))
::method range
  expose uidSet mailbox uidValidity
  use strict arg start, requested
  if start < 0 | requested < 0 then raise syntax 88.900 array("WIRE_RANGE", start, requested)
  rows = .array~new
  if requested = 0 | start >= uidSet~count then return .WireImapRange~new(start, rows)
  last = start + requested
  if last > uidSet~count then last = uidSet~count
  do ordinal = start + 1 to last
    uid = uidSet~uidAtOrdinal(ordinal)
    rows~append(.WireImapMessageRef~new(mailbox, uidValidity, uid))
  end
  return .WireImapRange~new(start, rows)
::method fetchHeaders
  expose session
  use strict arg messageRef
  return session~uidFetchPeek(messageRef~uid, "UID FLAGS INTERNALDATE RFC822.SIZE BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)]")
::method fetchBody
  expose session
  use strict arg messageRef, offset = 0, length = 65536, sinkFactory = .nil
  if offset < 0 | length < 1 then raise syntax 88.900 array("WIRE_RANGE", offset, length)
  partial = offset || "." || length
  return session~uidFetchBodyPeek(messageRef~uid, "", partial, sinkFactory)

::requires "ImapSession.cls"
