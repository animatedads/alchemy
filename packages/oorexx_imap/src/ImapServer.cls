/* ooRexx IMAP server core v0.1-dev14
 *
 * Rexx-space endpoint architecture.  Authentication, mailbox authority,
 * mailbox state/storage, and transport are independent injected contracts.
 * Dev11 added the first bounded message-data command slice; dev13 adds the
 * selected-mailbox change feed and endpoint-owned IDLE loop while continuing
 * to avoid an IMAP4rev1 claim until the remaining surfaces are qualified.
 */

::class ImapServerBuild public
::constant API "imap.server/0.1"
::constant RELEASE "0.1-dev14"

::class ImapServerResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = (okArg == .true)
  code = codeArg~string~upper
  detail = detailArg~string
  value = valueArg
::method success class
  use strict arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use strict arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class ImapServerIdentity public
::attribute principalId get
::attribute authenticationMethod get
::attribute source get
::method init
  expose principalId authenticationMethod source
  use strict arg principalIdArg, methodArg = "", sourceArg = ""
  principalId = principalIdArg~string
  authenticationMethod = methodArg~string~upper
  source = sourceArg~string
  if principalId~strip = "" then raise syntax 88.900 array("IMAP_SERVER_EMPTY_PRINCIPAL")

/* Identity attribution only.  Mailbox authorization is a separate contract. */
::class ImapAuthenticationProvider public
::method mechanisms
  return .array~new
::method authenticateLogin
  use strict arg user, credential, context = .nil
  return .ImapServerResult~failure("AUTHENTICATION_PROVIDER_NOT_CONFIGURED")

::class ImapCallbackAuthenticationProvider subclass ImapAuthenticationProvider public
::method init
  expose callback
  use strict arg callbackArg
  callback = callbackArg
::method mechanisms
  expose callback
  if callback == .nil then return .array~new
  if callback~hasMethod("MECHANISMS") then return .ImapCollections~copyArray(callback~mechanisms)
  return .array~new
::method authenticateLogin
  expose callback
  use strict arg user, credential, context = .nil
  if callback == .nil then return .ImapServerResult~failure("AUTHENTICATION_PROVIDER_INVALID")
  if \callback~hasMethod("AUTHENTICATELOGIN") then return .ImapServerResult~failure("AUTHENTICATION_PROVIDER_INVALID")
  return callback~authenticateLogin(user, credential, context)

/* Qualification-only provider.  Production code must not retain plaintext
 * credentials in this object. */
::class ImapTestAuthenticationProvider subclass ImapAuthenticationProvider public
::method init
  expose users
  users = .directory~new
::method addUser
  expose users
  use strict arg login, credential, principalId = ""
  if principalId = "" then principalId = login
  row = .directory~new
  row["credential"] = credential~string
  row["principal"] = principalId~string
  users[login~string] = row
  return self
::method mechanisms
  return .array~of("LOGIN")
::method authenticateLogin
  expose users
  use strict arg user, credential, context = .nil
  key = user~string
  if \users~hasIndex(key) then return .ImapServerResult~failure("AUTHENTICATION_FAILED")
  row = users[key]
  if row["credential"] \== credential~string then return .ImapServerResult~failure("AUTHENTICATION_FAILED")
  return .ImapServerResult~success(.ImapServerIdentity~new(row["principal"], "LOGIN", "TEST"), "TEST_AUTHENTICATION")

::class ImapMailboxAuthority public
::method authorize
  use strict arg identity, action, mailbox = "", context = .nil
  return .ImapServerResult~failure("IMAP_MAILBOX_AUTHORITY_NOT_CONFIGURED")

::class ImapCallbackMailboxAuthority subclass ImapMailboxAuthority public
::method init
  expose callback
  use strict arg callbackArg
  callback = callbackArg
::method authorize
  expose callback
  use strict arg identity, action, mailbox = "", context = .nil
  if callback == .nil then return .ImapServerResult~failure("IMAP_MAILBOX_AUTHORITY_INVALID")
  if \callback~hasMethod("AUTHORIZE") then return .ImapServerResult~failure("IMAP_MAILBOX_AUTHORITY_INVALID")
  return callback~authorize(identity, action, mailbox, context)

::class ImapTestAllowAllMailboxAuthority subclass ImapMailboxAuthority public
::method authorize
  use strict arg identity, action, mailbox = "", context = .nil
  if identity == .nil then return .ImapServerResult~failure("IMAP_AUTHENTICATION_REQUIRED")
  return .ImapServerResult~success(.true, "TEST_ALLOW_ALL")

/* Delivery-classification membership is owned by SMTP/mail-delivery authority.
 * An ordinary IMAP command may not manufacture these classifications merely by
 * choosing the mailbox name. */
::class ImapClassifiedInboxPolicy public
::constant VERIFIED_INBOX "INBOX"
::constant UNVERIFIED_INBOX "INBOX-UNSIGNED"
::method isDeliveryManaged class
  use strict arg mailbox
  name = mailbox~string~strip~upper
  if name = self~VERIFIED_INBOX then return .true
  if name = self~UNVERIFIED_INBOX then return .true
  return .false
::method clientMayCreateMembership class
  use strict arg mailbox
  return \self~isDeliveryManaged(mailbox)

::class ImapServerMailboxDescriptor public
::attribute name get
::attribute delimiter get
::attribute attributes get
::attribute role get
::attribute deliveryManaged get
::attribute subscribed get
::method init
  expose name delimiter attributes role deliveryManaged subscribed
  use strict arg nameArg, delimiterArg = "/", attributesArg = "", roleArg = "ORDINARY", managedArg = .false, subscribedArg = .false
  name = nameArg~string
  delimiter = delimiterArg~string
  attributes = attributesArg~string
  role = roleArg~string~upper
  deliveryManaged = (managedArg == .true)
  subscribed = (subscribedArg == .true)

::class ImapServerNamespace public
::attribute personalPrefix get
::attribute delimiter get
::method init
  expose personalPrefix delimiter
  use strict arg prefixArg = "", delimiterArg = "/"
  personalPrefix = prefixArg~string
  delimiter = delimiterArg~string
  if delimiter = "" then raise syntax 88.900 array("IMAP_SERVER_NAMESPACE_DELIMITER_REQUIRED")

::class ImapServerMailboxSnapshot public
::attribute mailbox get
::attribute messageCount get
::attribute recent get
::attribute unseenCount get
::attribute firstUnseenSequence get
::attribute uidValidity get
::attribute uidNext get
::attribute highestModSeq get
::attribute generation get
::attribute readOnly get
::attribute flags get
::attribute permanentFlags get
::method init
  expose mailbox messageCount recent unseenCount firstUnseenSequence uidValidity uidNext highestModSeq generation readOnly flags permanentFlags
  numeric digits 30
  use strict arg mailboxArg, messageCountArg = 0, recentArg = 0, unseenArg = 0, firstUnseenArg = 0, uidValidityArg = "1", uidNextArg = "1", modseqArg = "1", generationArg = "1", readOnlyArg = .false, flagsArg = "\Answered \Flagged \Deleted \Seen \Draft", permanentArg = "\Answered \Flagged \Deleted \Seen \Draft"
  mailbox = mailboxArg~string
  messageCount = .ImapNumber~whole(messageCountArg,"IMAP_SERVER_MESSAGE_COUNT",0)
  recent = .ImapNumber~whole(recentArg,"IMAP_SERVER_RECENT",0)
  unseenCount = .ImapNumber~whole(unseenArg,"IMAP_SERVER_UNSEEN",0)
  firstUnseenSequence = .ImapNumber~whole(firstUnseenArg,"IMAP_SERVER_FIRST_UNSEEN",0)
  uidValidity = uidValidityArg~string
  uidNext = uidNextArg~string
  highestModSeq = modseqArg~string
  generation = generationArg~string
  readOnly = (readOnlyArg == .true)
  flags = flagsArg~string
  permanentFlags = permanentArg~string

::class ImapServerSelection public
::attribute snapshot get
::attribute mailbox get
::attribute readOnly get
::attribute changeCursor get
::method init
  expose snapshot mailbox readOnly changeCursor
  use strict arg snapshotArg, cursorArg = "0"
  snapshot = snapshotArg
  mailbox = snapshot~mailbox
  readOnly = snapshot~readOnly
  changeCursor = cursorArg~string
::method update
  expose snapshot mailbox readOnly changeCursor
  use strict arg snapshotArg, cursorArg
  snapshot = snapshotArg
  mailbox = snapshot~mailbox
  readOnly = snapshot~readOnly
  changeCursor = cursorArg~string
  return self

/* Mailbox change-feed records are protocol-state evidence, not telemetry.
 * They carry only the information needed to keep selected sessions coherent. */
::class ImapMailboxChange public
::attribute changeId get
::attribute mailbox get
::attribute kind get
::attribute generation get
::attribute sequence get
::attribute uid get
::attribute messageCount get
::attribute originId get
::attribute echoToOrigin get
::method init
  expose changeId mailbox kind generation sequence uid messageCount flags originId echoToOrigin
  numeric digits 30
  use strict arg idArg, mailboxArg, kindArg, generationArg, sequenceArg = 0, uidArg = 0, messageCountArg = 0, flagsArg = .nil, originArg = "", echoArg = .false
  changeId = .ImapNumber~whole(idArg, "IMAP_SERVER_CHANGE_ID", 1)
  mailbox = mailboxArg~string
  kind = kindArg~string~upper
  generation = generationArg~string
  sequence = .ImapNumber~whole(sequenceArg, "IMAP_SERVER_CHANGE_SEQUENCE", 0)
  uid = .ImapNumber~whole(uidArg, "IMAP_SERVER_CHANGE_UID", 0)
  messageCount = .ImapNumber~whole(messageCountArg, "IMAP_SERVER_CHANGE_COUNT", 0)
  if flagsArg == .nil then flags = .array~new
  else flags = .ImapCollections~copyArray(flagsArg)
  originId = originArg~string
  echoToOrigin = (echoArg == .true)
::method flags
  expose flags
  return .ImapCollections~copyArray(flags)

::class ImapMailboxChangeBatch public
::attribute nextCursor get
::method init
  expose nextCursor events
  use strict arg cursorArg, eventsArg = .nil
  nextCursor = cursorArg~string
  if eventsArg == .nil then events = .array~new
  else events = .ImapCollections~copyArray(eventsArg)
::method events
  expose events
  return .ImapCollections~copyArray(events)

/* Message-store value object. Bytes are immutable by convention inside the
 * provider and identity is mailbox UID, never sequence number. */
::class ImapServerMessage public
::attribute uid get
::attribute bytes get
::attribute internalDate get
::attribute modSeq get
::method init
  expose uid bytes flags internalDate modSeq
  numeric digits 30
  use strict arg uidArg, bytesArg, flagsArg = .nil, internalDateArg = "", modSeqArg = "1"
  uid = .ImapNumber~whole(uidArg, "IMAP_SERVER_UID", 1)
  bytes = bytesArg~string
  if flagsArg == .nil then flags = .array~new
  else flags = .ImapCollections~copyArray(flagsArg)
  internalDate = internalDateArg~string
  modSeq = .ImapNumber~whole(modSeqArg, "IMAP_SERVER_MODSEQ", 1)
::method flags
  expose flags
  return .ImapCollections~copyArray(flags)
::method hasFlag
  expose flags
  use strict arg wanted
  w = wanted~string~upper
  do f over flags
    if f~string~upper = w then return .true
  end
  return .false
::method setFlags
  expose flags modSeq
  numeric digits 30
  use strict arg newFlags, newModSeq = .nil
  flags = .ImapCollections~copyArray(newFlags)
  if newModSeq <> .nil then modSeq = .ImapNumber~whole(newModSeq, "IMAP_SERVER_MODSEQ", 1)
  return self
::method copyWithUid
  expose bytes flags internalDate modSeq
  use strict arg newUid
  return .ImapServerMessage~new(newUid, bytes, flags, internalDate, modSeq)

::class ImapServerAppendResult public
::attribute uidValidity get
::attribute uid get
::method init
  expose uidValidity uid
  use strict arg uidValidityArg, uidArg
  uidValidity = uidValidityArg~string
  uid = .ImapNumber~whole(uidArg, "IMAP_SERVER_APPEND_UID", 1)

::class ImapServerCopyResult public
::attribute uidValidity get
::method sourceUids
  expose sourceUids
  return sourceUids~copy
::method destinationUids
  expose destinationUids
  return destinationUids~copy
::method init
  expose uidValidity sourceUids destinationUids
  use strict arg uidValidityArg, sourceUidsArg, destinationUidsArg
  uidValidity = uidValidityArg~string
  sourceUids = sourceUidsArg~copy
  destinationUids = destinationUidsArg~copy

/* Provider owns mailbox/message state, never user authentication. */
::class ImapMailboxProvider public
::method capabilities
  return .array~new
::method namespace
  return .ImapServerResult~failure("NAMESPACE_NOT_SUPPORTED")
::method listMailboxes
  use strict arg reference = "", pattern = "*", subscribedOnly = .false
  return .array~new
::method status
  use strict arg mailbox
  return .ImapServerResult~failure("MAILBOX_PROVIDER_NOT_CONFIGURED")
::method select
  use strict arg mailbox, readOnly = .false
  return .ImapServerResult~failure("MAILBOX_PROVIDER_NOT_CONFIGURED")
::method close
  use strict arg mailbox, expungeDeleted = .false, originId = ""
  return .ImapServerResult~failure("MAILBOX_PROVIDER_NOT_CONFIGURED")
::method createMailbox
  use strict arg mailbox
  return .ImapServerResult~failure("MAILBOX_PROVIDER_READ_ONLY")
::method deleteMailbox
  use strict arg mailbox
  return .ImapServerResult~failure("MAILBOX_PROVIDER_READ_ONLY")
::method renameMailbox
  use strict arg sourceMailbox, destinationMailbox
  return .ImapServerResult~failure("MAILBOX_PROVIDER_READ_ONLY")
::method subscribeMailbox
  use strict arg mailbox
  return .ImapServerResult~failure("MAILBOX_PROVIDER_READ_ONLY")
::method unsubscribeMailbox
  use strict arg mailbox
  return .ImapServerResult~failure("MAILBOX_PROVIDER_READ_ONLY")
::method appendMessage
  use strict arg mailbox, bytes, flags = .nil, internalDate = "", originId = ""
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method fetchMessages
  use strict arg mailbox, setSpec, uidMode = .false
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method storeFlags
  use strict arg mailbox, setSpec, uidMode, operation, flags, originId = ""
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method searchMessages
  use strict arg mailbox, criteria, uidMode = .false
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method copyMessages
  use strict arg sourceMailbox, setSpec, uidMode, destinationMailbox, originId = ""
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method moveMessages
  use strict arg sourceMailbox, setSpec, uidMode, destinationMailbox, originId = ""
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method expungeMessages
  use strict arg mailbox, uidSet = .nil, originId = ""
  return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED")
::method currentChangeCursor
  use strict arg mailbox = ""
  return .ImapServerResult~failure("CHANGE_FEED_NOT_SUPPORTED")
::method changesSince
  use strict arg mailbox, cursorArg, limitArg = 256
  return .ImapServerResult~failure("CHANGE_FEED_NOT_SUPPORTED")

/* Dependency-free in-memory message provider for qualification.  It implements a
 * bounded reference message store and change feed; it is not a persistence claim. */
::class ImapMemoryMailboxProvider subclass ImapMailboxProvider public
::method init
  expose mailboxes nextUidValidity generation changeSerial changeLog changeLogLimit
  numeric digits 30
  mailboxes = .directory~new
  nextUidValidity = 10
  generation = 1
  changeSerial = 0
  changeLog = .array~new
  changeLogLimit = 4096
  self~addInitialMailbox("INBOX", "SIGNED_INBOX", .true, .true)
  self~addInitialMailbox("INBOX-UNSIGNED", "UNSIGNED_INBOX", .true, .true)
::method capabilities
  return .array~of("NAMESPACE", "UIDPLUS", "MOVE", "IDLE")
::method currentChangeCursor
  expose mailboxes changeSerial
  use strict arg mailbox = ""
  if mailbox <> "" then do
    k = self~key(mailbox)
    if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  end
  return .ImapServerResult~success(changeSerial~string)

::method changesSince
  expose mailboxes changeSerial changeLog
  numeric digits 30
  use strict arg mailbox, cursorArg, limitArg = 256
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  cursor = .ImapNumber~whole(cursorArg, "IMAP_SERVER_CHANGE_CURSOR", 0)
  limit = .ImapNumber~whole(limitArg, "IMAP_SERVER_CHANGE_LIMIT", 1, 4096)
  if changeLog~items > 0 then do
    firstId = changeLog[1]~changeId
    if cursor < firstId - 1 then return .ImapServerResult~failure("CHANGE_CURSOR_EXPIRED")
  end
  events = .array~new
  nextCursor = cursor
  do event over changeLog
    if event~changeId <= cursor then iterate
    nextCursor = event~changeId
    if self~key(event~mailbox) = k then events~append(event)
    if events~items >= limit then leave
  end
  if events~items < limit then nextCursor = changeSerial
  return .ImapServerResult~success(.ImapMailboxChangeBatch~new(nextCursor, events))

::method publishChange private
  expose changeSerial changeLog changeLogLimit
  numeric digits 30
  use strict arg mailbox, kind, generationArg, sequenceArg = 0, uidArg = 0, messageCountArg = 0, flagsArg = .nil, originArg = "", echoArg = .false
  changeSerial += 1
  event = .ImapMailboxChange~new(changeSerial, mailbox, kind, generationArg, sequenceArg, uidArg, messageCountArg, flagsArg, originArg, echoArg)
  changeLog~append(event)
  if changeLog~items > changeLogLimit then do
    trimmed = .array~new
    first = changeLog~items - changeLogLimit + 1
    do i = first to changeLog~items; trimmed~append(changeLog[i]); end
    changeLog = trimmed
  end
  return event

::method namespace
  return .ImapServerResult~success(.ImapServerNamespace~new("", "/"))
::method key private
  use strict arg mailbox
  name = mailbox~string~strip
  if name~upper = "INBOX" then return "INBOX"
  if name~upper = "INBOX-UNSIGNED" then return "INBOX-UNSIGNED"
  return name
::method addInitialMailbox private
  expose mailboxes nextUidValidity
  numeric digits 30
  use strict arg name, role = "ORDINARY", managed = .false, subscribed = .false
  k = self~key(name)
  row = .directory~new
  row["name"] = name~string
  row["role"] = role~string~upper
  row["managed"] = (managed == .true)
  row["subscribed"] = (subscribed == .true)
  row["messages"] = 0
  row["recent"] = 0
  row["unseen"] = 0
  row["first_unseen"] = 0
  row["uid_validity"] = nextUidValidity~string
  row["uid_next"] = "1"
  row["modseq"] = "1"
  row["message_rows"] = .array~new
  nextUidValidity += 1
  mailboxes[k] = row
  return row
::method descriptorForRow private
  use strict arg row
  attrs = ""
  if row["managed"] then attrs = "\NoInferiors"
  return .ImapServerMailboxDescriptor~new(row["name"], "/", attrs, row["role"], row["managed"], row["subscribed"])
::method snapshotForRow private
  expose generation
  numeric digits 30
  use strict arg row, readOnly = .false
  self~recalculateRow(row)
  return .ImapServerMailboxSnapshot~new(row["name"], row["messages"], row["recent"], row["unseen"], row["first_unseen"], row["uid_validity"], row["uid_next"], row["modseq"], generation~string, readOnly)
::method recalculateRow private
  use strict arg row
  messages = row["message_rows"]
  row["messages"] = messages~items
  unseen = 0; firstUnseen = 0
  do i = 1 to messages~items
    message = messages[i]
    if \message~hasFlag("\Seen") then do
      unseen += 1
      if firstUnseen = 0 then firstUnseen = i
    end
  end
  row["unseen"] = unseen
  row["first_unseen"] = firstUnseen
  return row
::method normalizeFlags private
  use strict arg flagsArg
  out = .array~new
  if flagsArg == .nil then return out
  if flagsArg~isInstanceOf(.Array) then source = flagsArg
  else do
    text = flagsArg~string~strip
    if text~left(1) = "(" then do
      if text~right(1) = ")" then text = text~substr(2, text~length - 2)
    end
    source = .array~new
    do i = 1 to text~words; source~append(text~word(i)); end
  end
  seen = .directory~new
  do f over source
    flag = f~string~strip
    if flag = "" then iterate
    canonical = flag~upper
    if \seen~hasIndex(canonical) then do
      seen[canonical] = .true
      out~append(flag)
    end
  end
  return out
::method selectedMessageRows private
  use strict arg row, setSpec, uidMode = .false
  messages = row["message_rows"]
  selected = .array~new
  spec = setSpec~string~strip
  if spec = "" then return selected
  do i = 1 to messages~items
    message = messages[i]
    value = i
    if uidMode then value = message~uid
    if self~setContains(spec, value, messages, uidMode) then selected~append(.array~of(i, message))
  end
  return selected
::method setContains private
  numeric digits 30
  use strict arg specArg, valueArg, messages, uidMode
  spec = specArg~string~strip
  value = .ImapNumber~whole(valueArg, "IMAP_SERVER_SET_VALUE", 1)
  maximum = messages~items
  if uidMode then do
    maximum = 0
    if messages~items > 0 then maximum = messages[messages~items]~uid
  end
  rest = spec
  do while rest <> ""
    comma = rest~pos(",")
    if comma = 0 then do; item = rest; rest = ""; end
    else do; item = rest~left(comma - 1); rest = rest~substr(comma + 1); end
    item = item~strip
    colon = item~pos(":")
    if colon = 0 then do
      endpoint = item
      if endpoint = "*" then endpoint = maximum
      if datatype(endpoint, "W") then do
        if value = endpoint then return .true
      end
      iterate
    end
    first = item~left(colon - 1)~strip; last = item~substr(colon + 1)~strip
    if first = "*" then first = maximum
    if last = "*" then last = maximum
    if \datatype(first, "W") then iterate
    if \datatype(last, "W") then iterate
    low = first; high = last
    if low > high then do; swap = low; low = high; high = swap; end
    if value >= low then do
      if value <= high then return .true
    end
  end
  return .false
::method matches private
  use strict arg name, pattern
  p = pattern~string
  if p = "*" then return .true
  if p = "%" then return name~pos("/") = 0
  if p~pos("*") = 0 then do
    if p~pos("%") = 0 then do
      if name == p then return .true
      if name~upper = "INBOX" then return p~upper = "INBOX"
      return .false
    end
  end
  /* Bounded qualification wildcard support; full LIST hierarchy grammar is a
   * documented bounded LIST gap rather than silently overclaimed behavior. */
  if p~left(1) = "*" then do
    if p~right(1) = "*" then do
      if p~length >= 2 then return name~pos(p~substr(2, p~length - 2)) > 0
    end
    return name~right(p~length - 1) = p~substr(2)
  end
  if p~right(1) = "*" then return name~left(p~length - 1) = p~left(p~length - 1)
  return .false
::method listMailboxes
  expose mailboxes
  use strict arg reference = "", pattern = "*", subscribedOnly = .false
  names = .array~new
  do k over mailboxes
    row = mailboxes[k]
    if subscribedOnly then do
      if \row["subscribed"] then iterate
    end
    if self~matches(row["name"], pattern) then names~append(row["name"])
  end
  names~sort
  out = .array~new
  do name over names
    out~append(self~descriptorForRow(mailboxes[self~key(name)]))
  end
  return out
::method status
  expose mailboxes
  use strict arg mailbox
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  return .ImapServerResult~success(self~snapshotForRow(mailboxes[k], .true))
::method select
  expose mailboxes
  use strict arg mailbox, readOnly = .false
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  return .ImapServerResult~success(self~snapshotForRow(mailboxes[k], readOnly))
::method close
  expose mailboxes
  use strict arg mailbox, expungeDeleted = .false, originId = ""
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if expungeDeleted then do
    removed = self~expungeMessages(mailbox, .nil, originId)
    if \removed~ok then return removed
  end
  return .ImapServerResult~success(.true)
::method createMailbox
  expose mailboxes generation
  numeric digits 30
  use strict arg mailbox
  name = mailbox~string~strip
  if name = "" then return .ImapServerResult~failure("MAILBOX_NAME_REQUIRED")
  if .ImapClassifiedInboxPolicy~isDeliveryManaged(name) then return .ImapServerResult~failure("DELIVERY_MANAGED_MAILBOX")
  k = self~key(name)
  if mailboxes~hasIndex(k) then return .ImapServerResult~failure("MAILBOX_EXISTS")
  self~addInitialMailbox(name)
  generation += 1
  return .ImapServerResult~success(.true)
::method deleteMailbox
  expose mailboxes generation
  numeric digits 30
  use strict arg mailbox
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if mailboxes[k]["managed"] then return .ImapServerResult~failure("DELIVERY_MANAGED_MAILBOX")
  mailboxes~remove(k)
  generation += 1
  return .ImapServerResult~success(.true)
::method renameMailbox
  expose mailboxes generation
  numeric digits 30
  use strict arg sourceMailbox, destinationMailbox
  sourceKey = self~key(sourceMailbox)
  destinationKey = self~key(destinationMailbox)
  if \mailboxes~hasIndex(sourceKey) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if mailboxes[sourceKey]["managed"] then return .ImapServerResult~failure("DELIVERY_MANAGED_MAILBOX")
  if .ImapClassifiedInboxPolicy~isDeliveryManaged(destinationMailbox) then return .ImapServerResult~failure("DELIVERY_MANAGED_MAILBOX")
  if mailboxes~hasIndex(destinationKey) then return .ImapServerResult~failure("MAILBOX_EXISTS")
  row = mailboxes[sourceKey]
  newRow = .directory~new
  do k over row; newRow[k] = row[k]; end
  newRow["name"] = destinationMailbox~string
  mailboxes[destinationKey] = newRow
  mailboxes~remove(sourceKey)
  generation += 1
  return .ImapServerResult~success(.true)
::method subscribeMailbox
  expose mailboxes generation
  numeric digits 30
  use strict arg mailbox
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  mailboxes[k]["subscribed"] = .true
  generation += 1
  return .ImapServerResult~success(.true)
::method unsubscribeMailbox
  expose mailboxes generation
  numeric digits 30
  use strict arg mailbox
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  mailboxes[k]["subscribed"] = .false
  generation += 1
  return .ImapServerResult~success(.true)

::method appendMessage
  expose mailboxes generation
  numeric digits 30
  use strict arg mailbox, bytes, flags = .nil, internalDate = "", originId = ""
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  row = mailboxes[k]
  uid = row["uid_next"]
  nextUid = .ImapNumber~whole(uid, "IMAP_SERVER_UIDNEXT", 1) + 1
  nextModSeq = .ImapNumber~whole(row["modseq"], "IMAP_SERVER_MODSEQ", 1) + 1
  message = .ImapServerMessage~new(uid, bytes, self~normalizeFlags(flags), internalDate, nextModSeq)
  row["message_rows"]~append(message)
  row["uid_next"] = nextUid~string
  row["modseq"] = nextModSeq~string
  generation += 1
  self~recalculateRow(row)
  ignore = self~publishChange(row["name"], "EXISTS", generation, row["messages"], uid, row["messages"], .nil, originId, .true)
  return .ImapServerResult~success(.ImapServerAppendResult~new(row["uid_validity"], uid), "APPENDED")
::method fetchMessages
  expose mailboxes
  use strict arg mailbox, setSpec, uidMode = .false
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  return .ImapServerResult~success(self~selectedMessageRows(mailboxes[k], setSpec, uidMode))
::method storeFlags
  expose mailboxes generation
  numeric digits 30
  use strict arg mailbox, setSpec, uidMode, operation, flags, originId = ""
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  row = mailboxes[k]
  selected = self~selectedMessageRows(row, setSpec, uidMode)
  requested = self~normalizeFlags(flags)
  changed = .array~new
  op = operation~string~upper
  do pair over selected
    message = pair[2]
    current = message~flags
    map = .directory~new
    do f over current; map[f~string~upper] = f~string; end
    if op = "FLAGS" then do
      map = .directory~new
      do f over requested; map[f~string~upper] = f~string; end
    end
    else if op = "+FLAGS" then do
      do f over requested; map[f~string~upper] = f~string; end
    end
    else if op = "-FLAGS" then do
      do f over requested
        key = f~string~upper
        if map~hasIndex(key) then map~remove(key)
      end
    end
    else return .ImapServerResult~failure("STORE_OPERATION_INVALID")
    next = .array~new
    do key over map; next~append(map[key]); end
    next~sort
    nextModSeq = .ImapNumber~whole(row["modseq"], "IMAP_SERVER_MODSEQ", 1) + 1
    row["modseq"] = nextModSeq~string
    message~setFlags(next, nextModSeq)
    changed~append(pair)
  end
  if changed~items > 0 then do
    generation += 1
    do pair over changed
      message = pair[2]
      ignore = self~publishChange(row["name"], "FLAGS", generation, pair[1], message~uid, row["messages"], message~flags, originId, .false)
    end
  end
  self~recalculateRow(row)
  return .ImapServerResult~success(changed)
::method searchMessages
  expose mailboxes
  use strict arg mailbox, criteria, uidMode = .false
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  row = mailboxes[k]; messages = row["message_rows"]
  wanted = criteria~string~strip~upper
  out = .array~new
  do i = 1 to messages~items
    message = messages[i]; matched = .false
    select
      when wanted = "ALL" then matched = .true
      when wanted = "SEEN" then matched = message~hasFlag("\Seen")
      when wanted = "UNSEEN" then matched = \message~hasFlag("\Seen")
      when wanted = "DELETED" then matched = message~hasFlag("\Deleted")
      when wanted = "UNDELETED" then matched = \message~hasFlag("\Deleted")
      otherwise return .ImapServerResult~failure("SEARCH_CRITERIA_UNSUPPORTED")
    end
    if matched then do
      value = i; if uidMode then value = message~uid
      out~append(value)
    end
  end
  return .ImapServerResult~success(out)
::method copyMessages
  expose mailboxes generation
  numeric digits 30
  use strict arg sourceMailbox, setSpec, uidMode, destinationMailbox, originId = ""
  sourceKey = self~key(sourceMailbox); destinationKey = self~key(destinationMailbox)
  if \mailboxes~hasIndex(sourceKey) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if \mailboxes~hasIndex(destinationKey) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if .ImapClassifiedInboxPolicy~isDeliveryManaged(destinationMailbox) then return .ImapServerResult~failure("DELIVERY_MANAGED_MAILBOX")
  sourceRow = mailboxes[sourceKey]; destinationRow = mailboxes[destinationKey]
  selected = self~selectedMessageRows(sourceRow, setSpec, uidMode)
  sourceUids = .ImapUidSet~new; destinationUids = .ImapUidSet~new
  do pair over selected
    sourceMessage = pair[2]
    newUid = destinationRow["uid_next"]
    destinationRow["uid_next"] = (.ImapNumber~whole(newUid, "IMAP_SERVER_UIDNEXT", 1) + 1)~string
    nextModSeq = .ImapNumber~whole(destinationRow["modseq"], "IMAP_SERVER_MODSEQ", 1) + 1
    destinationRow["modseq"] = nextModSeq~string
    copy = .ImapServerMessage~new(newUid, sourceMessage~bytes, sourceMessage~flags, sourceMessage~internalDate, nextModSeq)
    destinationRow["message_rows"]~append(copy)
    sourceUids~addUid(sourceMessage~uid); destinationUids~addUid(newUid)
  end
  if selected~items > 0 then do
    generation += 1
    self~recalculateRow(destinationRow)
    lastUid = 0
    if destinationRow["message_rows"]~items > 0 then lastUid = destinationRow["message_rows"][destinationRow["message_rows"]~items]~uid
    ignore = self~publishChange(destinationRow["name"], "EXISTS", generation, destinationRow["messages"], lastUid, destinationRow["messages"], .nil, originId, .true)
  end
  else self~recalculateRow(destinationRow)
  return .ImapServerResult~success(.ImapServerCopyResult~new(destinationRow["uid_validity"], sourceUids, destinationUids))
::method moveMessages
  expose mailboxes generation
  use strict arg sourceMailbox, setSpec, uidMode, destinationMailbox, originId = ""
  copied = self~copyMessages(sourceMailbox, setSpec, uidMode, destinationMailbox, originId)
  if \copied~ok then return copied
  sourceKey = self~key(sourceMailbox)
  sourceRow = mailboxes[sourceKey]
  selected = self~selectedMessageRows(sourceRow, setSpec, uidMode)
  exact = .ImapUidSet~new
  do pair over selected; exact~addUid(pair[2]~uid); end
  removed = self~removeExactMessages(sourceRow, exact)
  if removed~items > 0 then do
    generation += 1
    self~recalculateRow(sourceRow)
    do i = removed~items to 1 by -1
      pair = removed[i]
      ignore = self~publishChange(sourceRow["name"], "EXPUNGE", generation, pair[1], pair[2], sourceRow["messages"], .nil, originId, .false)
    end
  end
  else self~recalculateRow(sourceRow)
  return .ImapServerResult~success(.array~of(copied~value, removed), "MOVED")
::method removeExactMessages private
  use strict arg row, uidSet
  messages = row["message_rows"]
  kept = .array~new; removed = .array~new
  do i = 1 to messages~items
    message = messages[i]
    if uidSet~contains(message~uid) then removed~append(.array~of(i, message~uid))
    else kept~append(message)
  end
  row["message_rows"] = kept
  return removed
::method expungeMessages
  expose mailboxes generation
  use strict arg mailbox, uidSet = .nil, originId = ""
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  row = mailboxes[k]; messages = row["message_rows"]
  kept = .array~new; removed = .array~new
  do i = 1 to messages~items
    message = messages[i]
    eligible = message~hasFlag("\Deleted")
    if eligible then do
      if uidSet <> .nil then eligible = uidSet~contains(message~uid)
    end
    if eligible then removed~append(.array~of(i, message~uid))
    else kept~append(message)
  end
  row["message_rows"] = kept
  if removed~items > 0 then do
    generation += 1
    self~recalculateRow(row)
    do i = removed~items to 1 by -1
      pair = removed[i]
      ignore = self~publishChange(row["name"], "EXPUNGE", generation, pair[1], pair[2], row["messages"], .nil, originId, .false)
    end
  end
  else self~recalculateRow(row)
  return .ImapServerResult~success(removed)

::class ImapParsedCommand public
::attribute ok get
::attribute tag get
::attribute command get
::attribute code get
::attribute detail get
::method init
  expose ok tag command args code detail
  use strict arg okArg, tagArg = "*", commandArg = "", argsArg = .nil, codeArg = "", detailArg = ""
  ok = (okArg == .true)
  tag = tagArg~string
  command = commandArg~string~upper
  if argsArg == .nil then args = .array~new
  else args = .ImapCollections~copyArray(argsArg)
  code = codeArg~string~upper
  detail = detailArg~string
::method args
  expose args
  return .ImapCollections~copyArray(args)

::class ImapServerParser public
::method parseLine class
  use strict arg lineArg, maxLineBytes = 1048576
  numeric digits 30
  line = lineArg~string
  if line~length > maxLineBytes then return .ImapParsedCommand~new(.false, "*", "", .nil, "LINE_TOO_LARGE")
  if line~pos('00'x) > 0 then return .ImapParsedCommand~new(.false, "*", "", .nil, "CONTROL_CHARACTER")
  if line~pos('0d'x) > 0 then return .ImapParsedCommand~new(.false, "*", "", .nil, "CONTROL_CHARACTER")
  if line~pos('0a'x) > 0 then return .ImapParsedCommand~new(.false, "*", "", .nil, "CONTROL_CHARACTER")
  tokens = self~tokens(line)
  if tokens == .nil then return .ImapParsedCommand~new(.false, "*", "", .nil, "SYNTAX")
  if tokens~items < 2 then return .ImapParsedCommand~new(.false, "*", "", .nil, "TAG_AND_COMMAND_REQUIRED")
  tag = tokens[1]
  if tag = "" then return .ImapParsedCommand~new(.false, tag, "", .nil, "INVALID_TAG")
  if tag = "*" then return .ImapParsedCommand~new(.false, tag, "", .nil, "INVALID_TAG")
  if tag = "+" then return .ImapParsedCommand~new(.false, tag, "", .nil, "INVALID_TAG")
  command = tokens[2]~upper
  args = .array~new
  do i = 3 to tokens~items; args~append(tokens[i]); end
  return .ImapParsedCommand~new(.true, tag, command, args)
::method tokens class private
  use strict arg line
  out = .array~new
  token = ""; tokenStarted = .false; quoted = .false; escaped = .false; groupDepth = 0
  do i = 1 to line~length
    ch = line~substr(i, 1)
    if quoted then do
      if escaped then do
        token = token || ch; tokenStarted = .true; escaped = .false; iterate
      end
      if ch = "\" then do; escaped = .true; iterate; end
      if ch = '"' then do; quoted = .false; iterate; end
      token = token || ch; tokenStarted = .true
      iterate
    end
    if ch = '"' then do; quoted = .true; tokenStarted = .true; iterate; end
    if ch = "(" then do; groupDepth += 1; token = token || ch; tokenStarted = .true; iterate; end
    if ch = ")" then do
      if groupDepth < 1 then return .nil
      groupDepth -= 1; token = token || ch; tokenStarted = .true; iterate
    end
    if ch = " " | ch = '09'x then do
      if groupDepth = 0 then do
        if tokenStarted then do; out~append(token); token = ""; tokenStarted = .false; end
        iterate
      end
    end
    token = token || ch; tokenStarted = .true
  end
  if quoted then return .nil
  if escaped then return .nil
  if groupDepth <> 0 then return .nil
  if tokenStarted then out~append(token)
  return out

::class ImapServerResponse public
::attribute closeConnection get
::attribute status get
::method init
  expose lines closeConnection status
  use strict arg linesArg = .nil, closeArg = .false, statusArg = ""
  if linesArg == .nil then lines = .array~new
  else lines = .ImapCollections~copyArray(linesArg)
  closeConnection = (closeArg == .true)
  status = statusArg~string~upper
::method lines
  expose lines
  return .ImapCollections~copyArray(lines)
::method wire
  expose lines
  out = ""
  do line over lines; out = out || line || '0d0a'x; end
  return out

::class ImapServerSession public
::attribute state get
::attribute identity get
::attribute selectedState get
::attribute tlsActive get
::attribute sessionId get
::attribute idleActive get
::method init
  expose authenticationProvider mailboxProvider authority state identity selectedState tlsActive maxLineBytes sessionId idleTransportCapable idleActive idleTag
  use strict arg authenticationProviderArg, mailboxProviderArg, authorityArg, tlsActiveArg = .false, maxLineBytesArg = 1048576, sessionIdArg = ""
  numeric digits 30
  if authenticationProviderArg == .nil then raise syntax 88.900 array("IMAP_SERVER_AUTH_PROVIDER_REQUIRED")
  if mailboxProviderArg == .nil then raise syntax 88.900 array("IMAP_SERVER_MAILBOX_PROVIDER_REQUIRED")
  if authorityArg == .nil then raise syntax 88.900 array("IMAP_SERVER_AUTHORITY_REQUIRED")
  if \authenticationProviderArg~hasMethod("AUTHENTICATELOGIN") then raise syntax 88.900 array("IMAP_SERVER_AUTH_PROVIDER_INVALID")
  if \mailboxProviderArg~hasMethod("LISTMAILBOXES") then raise syntax 88.900 array("IMAP_SERVER_MAILBOX_PROVIDER_INVALID")
  if \authorityArg~hasMethod("AUTHORIZE") then raise syntax 88.900 array("IMAP_SERVER_AUTHORITY_INVALID")
  authenticationProvider = authenticationProviderArg
  mailboxProvider = mailboxProviderArg
  authority = authorityArg
  tlsActive = (tlsActiveArg == .true)
  maxLineBytes = .ImapNumber~whole(maxLineBytesArg,"IMAP_SERVER_MAX_LINE",1024)
  if maxLineBytes < 1024 then raise syntax 88.900 array("IMAP_SERVER_MAX_LINE_TOO_SMALL", maxLineBytes)
  sessionId = sessionIdArg~string~strip
  if sessionId = "" then sessionId = "imap-" || date("S") || "-" || time("L")~changeStr(":","") || "-" || random(100000,999999)
  idleTransportCapable = .false
  idleActive = .false
  idleTag = ""
  state = "NOT_AUTHENTICATED"; identity = .nil; selectedState = .nil
::method setTlsActive
  expose tlsActive
  use strict arg value
  tlsActive = (value == .true)
  return tlsActive
::method setIdleTransportCapable
  expose idleTransportCapable
  use strict arg value
  idleTransportCapable = (value == .true)
  return idleTransportCapable
::method capabilityArray
  expose mailboxProvider tlsActive idleTransportCapable
  /* Do not claim IMAP4rev1 until the mandatory message-data surface exists. */
  out = .array~of("X-OOREXX-SERVER-CORE")
  if \tlsActive then out~append("LOGINDISABLED")
  providerCaps = mailboxProvider~capabilities
  do c over providerCaps
    cap = c~string~strip~upper
    if cap = "NAMESPACE" | cap = "UIDPLUS" | cap = "MOVE" then out~append(cap)
    else if cap = "IDLE" then do
      if idleTransportCapable then do
        if self~changeFeedAvailable then out~append("IDLE")
      end
    end
  end
  if self~messageDataAvailable then out~append("X-OOREXX-SERVER-MESSAGE")
  out~sort
  return out
::method capabilityText private
  caps = self~capabilityArray
  out = ""
  do c over caps
    if out <> "" then out = out || " "
    out = out || c
  end
  return out
::method greeting
  return "* OK [CAPABILITY " || self~capabilityText || "] ooRexx IMAP server core ready"
::method requireAuthenticated private
  expose state identity
  if identity == .nil then return .false
  if state = "AUTHENTICATED" then return .true
  if state = "SELECTED" then return .true
  return .false
::method authorize private
  expose authority identity
  use strict arg action, mailbox = "", context = .nil
  if identity == .nil then return .ImapServerResult~failure("IMAP_AUTHENTICATION_REQUIRED")
  decision = authority~authorize(identity, action, mailbox, context)
  if decision == .nil then return .ImapServerResult~failure("IMAP_MAILBOX_AUTHORITY_INVALID")
  if \decision~hasMethod("OK") then return .ImapServerResult~failure("IMAP_MAILBOX_AUTHORITY_INVALID")
  return decision
::method tagged private
  use strict arg tag, status, text
  return tag || " " || status || " " || text
::method response private
  use strict arg tag, status, text, untagged = .nil, closeConnection = .false
  lines = .array~new
  if untagged <> .nil then do l over untagged; lines~append(l); end
  lines~append(self~tagged(tag, status, text))
  return .ImapServerResponse~new(lines, closeConnection, status)
::method providerFailure private
  use strict arg tag, result, operation
  code = result~code
  if code = "NO_SUCH_MAILBOX" then return self~response(tag, "NO", "[NONEXISTENT] " || operation || " failed")
  if code = "MAILBOX_EXISTS" then return self~response(tag, "NO", "[ALREADYEXISTS] " || operation || " failed")
  if code = "DELIVERY_MANAGED_MAILBOX" then return self~response(tag, "NO", "[NOPERM] delivery-managed mailbox")
  if code = "NAMESPACE_NOT_SUPPORTED" then return self~response(tag, "NO", "[CANNOT] NAMESPACE not supported")
  return self~response(tag, "NO", "[SERVERBUG] " || operation || " failed: " || code)
::method messageDataAvailable
  expose mailboxProvider
  if \mailboxProvider~hasMethod("APPENDMESSAGE") then return .false
  return mailboxProvider~hasMethod("FETCHMESSAGES")
::method changeFeedAvailable
  expose mailboxProvider
  if \mailboxProvider~hasMethod("CURRENTCHANGECURSOR") then return .false
  if \mailboxProvider~hasMethod("CHANGESSINCE") then return .false
  return .true
::method providerChangeCursor private
  expose mailboxProvider
  use strict arg mailbox
  if \self~changeFeedAvailable then return "0"
  r = mailboxProvider~currentChangeCursor(mailbox)
  if r == .nil then return "0"
  if \r~hasMethod("OK") then return "0"
  if \r~ok then return "0"
  return r~value~string
::method pollSelectedChanges
  expose state selectedState mailboxProvider sessionId
  if state <> "SELECTED" then return .ImapServerResult~success(.array~new)
  if selectedState == .nil then return .ImapServerResult~success(.array~new)
  if \self~changeFeedAvailable then return .ImapServerResult~success(.array~new)
  /* Revalidate mailbox authority on each unsolicited update read. A session
   * selected before LDAP revocation must not retain read access via NOOP or
   * IDLE merely because its IMAP state is still SELECTED. */
  decision = self~authorize("IMAP_SELECT", selectedState~mailbox)
  if \decision~ok then return .ImapServerResult~failure("IMAP_AUTHORIZATION_REVOKED")
  r = mailboxProvider~changesSince(selectedState~mailbox, selectedState~changeCursor, 256)
  if r == .nil then return .ImapServerResult~failure("CHANGE_FEED_INVALID")
  if \r~hasMethod("OK") then return .ImapServerResult~failure("CHANGE_FEED_INVALID")
  if \r~ok then return r
  batch = r~value
  if batch == .nil then return .ImapServerResult~failure("CHANGE_FEED_INVALID")
  lines = .array~new
  do event over batch~events
    emit = .true
    if event~originId = sessionId then do
      if \event~echoToOrigin then emit = .false
    end
    if \emit then iterate
    kind = event~kind
    if kind = "EXISTS" then lines~append("* " || event~messageCount || " EXISTS")
    else if kind = "EXPUNGE" then lines~append("* " || event~sequence || " EXPUNGE")
    else if kind = "FLAGS" then lines~append("* " || event~sequence || " FETCH (FLAGS (" || self~flagsText(event~flags) || ") UID " || event~uid || ")")
  end
  refreshed = mailboxProvider~select(selectedState~mailbox, selectedState~readOnly)
  if refreshed == .nil then return .ImapServerResult~failure("CHANGE_FEED_REFRESH_FAILED")
  if \refreshed~hasMethod("OK") then return .ImapServerResult~failure("CHANGE_FEED_REFRESH_FAILED")
  if \refreshed~ok then return refreshed
  selectedState~update(refreshed~value, batch~nextCursor)
  return .ImapServerResult~success(lines)
::method processIdleStart
  expose state selectedState idleTransportCapable idleActive idleTag
  use strict arg parsed
  tag = parsed~tag
  if parsed~command <> "IDLE" then return self~response(tag, "BAD", "IDLE command required")
  args = parsed~args
  if args~items <> 0 then return self~response(tag, "BAD", "IDLE takes no arguments")
  if state <> "SELECTED" then return self~response(tag, "BAD", "IDLE requires selected state")
  if \idleTransportCapable then return self~response(tag, "NO", "[CANNOT] IDLE transport readiness unavailable")
  if \self~changeFeedAvailable then return self~response(tag, "NO", "[CANNOT] IDLE mailbox change feed unavailable")
  decision = self~authorize("IMAP_IDLE", selectedState~mailbox)
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] IDLE denied")
  idleActive = .true
  idleTag = tag
  return .ImapServerResponse~new(.array~of("+ idling"), .false, "CONTINUE")
::method finishIdle
  expose idleActive idleTag
  if \idleActive then return .ImapServerResponse~new(.array~of("* BAD no IDLE command is active"), .false, "BAD")
  tag = idleTag
  idleActive = .false
  idleTag = ""
  return self~response(tag, "OK", "IDLE terminated")
::method abortIdle
  expose idleActive idleTag
  use strict arg detail = "expected DONE"
  tag = idleTag
  if tag = "" then tag = "*"
  idleActive = .false
  idleTag = ""
  return self~response(tag, "BAD", "IDLE terminated: " || detail)
::method processLine
  use strict arg line
  return self~processLineWithLiteral(line, .nil)
::method processLineWithLiteral
  expose state authenticationProvider mailboxProvider identity selectedState tlsActive maxLineBytes
  use strict arg line, literalBytes = .nil
  if state = "LOGOUT" then return .ImapServerResponse~new(.array~of("* BYE session is closed"), .true, "BYE")
  parsed = .ImapServerParser~parseLine(line, maxLineBytes)
  if \parsed~ok then return self~response(parsed~tag, "BAD", "[PARSE] " || parsed~code)
  tag = parsed~tag; command = parsed~command; args = parsed~args

  if command = "CAPABILITY" then do
    if args~items <> 0 then return self~response(tag, "BAD", "CAPABILITY takes no arguments")
    return self~response(tag, "OK", "CAPABILITY completed", .array~of("* CAPABILITY " || self~capabilityText))
  end
  if command = "NOOP" then do
    if args~items <> 0 then return self~response(tag, "BAD", "NOOP takes no arguments")
    changes = .ImapServerResult~success(.array~new)
    if state = "SELECTED" then changes = self~pollSelectedChanges
    if \changes~ok then return self~response(tag, "NO", "[ALERT] selected mailbox state requires refresh")
    return self~response(tag, "OK", "NOOP completed", changes~value)
  end
  if command = "LOGOUT" then do
    state = "LOGOUT"; selectedState = .nil
    return self~response(tag, "OK", "LOGOUT completed", .array~of("* BYE ooRexx IMAP server logging out"), .true)
  end
  if command = "LOGIN" then do
    if state <> "NOT_AUTHENTICATED" then return self~response(tag, "BAD", "LOGIN not valid in this state")
    if args~items <> 2 then return self~response(tag, "BAD", "LOGIN requires user and password")
    if \tlsActive then return self~response(tag, "NO", "[PRIVACYREQUIRED] LOGIN requires an encrypted transport")
    authResult = authenticationProvider~authenticateLogin(args[1], args[2], self)
    if authResult == .nil then return self~response(tag, "NO", "[AUTHENTICATIONFAILED] authentication provider returned no result")
    if \authResult~hasMethod("OK") then return self~response(tag, "NO", "[AUTHENTICATIONFAILED] authentication provider returned an invalid result")
    if \authResult~ok then return self~response(tag, "NO", "[AUTHENTICATIONFAILED] credentials rejected")
    candidateIdentity = authResult~value
    if candidateIdentity == .nil then return self~response(tag, "NO", "[AUTHENTICATIONFAILED] authentication provider omitted identity")
    if \candidateIdentity~hasMethod("PRINCIPALID") then return self~response(tag, "NO", "[AUTHENTICATIONFAILED] authentication provider identity is invalid")
    if candidateIdentity~principalId~string~strip = "" then return self~response(tag, "NO", "[AUTHENTICATIONFAILED] authentication provider identity is empty")
    identity = candidateIdentity; state = "AUTHENTICATED"
    return self~response(tag, "OK", "LOGIN completed")
  end

  if \self~requireAuthenticated then return self~response(tag, "NO", "[AUTHENTICATIONREQUIRED] authenticate first")

  if command = "NAMESPACE" then do
    if args~items <> 0 then return self~response(tag, "BAD", "NAMESPACE takes no arguments")
    decision = self~authorize("IMAP_NAMESPACE")
    if \decision~ok then return self~response(tag, "NO", "[NOPERM] NAMESPACE denied")
    nsResult = mailboxProvider~namespace
    if \nsResult~ok then return self~providerFailure(tag, nsResult, "NAMESPACE")
    ns = nsResult~value
    if ns == .nil then return self~response(tag, "NO", "[SERVERBUG] NAMESPACE provider returned no namespace")
    if \ns~hasMethod("PERSONALPREFIX") then return self~response(tag, "NO", "[SERVERBUG] invalid NAMESPACE provider object")
    if \ns~hasMethod("DELIMITER") then return self~response(tag, "NO", "[SERVERBUG] invalid NAMESPACE provider object")
    nsLine = "* NAMESPACE ((" || .ImapCodec~quoteString(ns~personalPrefix) || " " || .ImapCodec~quoteString(ns~delimiter) || ")) NIL NIL"
    return self~response(tag, "OK", "NAMESPACE completed", .array~of(nsLine))
  end

  if command = "LIST" | command = "LSUB" then do
    if args~items <> 2 then return self~response(tag, "BAD", command || " requires reference and pattern")
    subscribedOnly = (command = "LSUB")
    rows = mailboxProvider~listMailboxes(args[1], args[2], subscribedOnly)
    lines = .array~new
    do d over rows
      decision = self~authorize("IMAP_LIST", d~name)
      if \decision~ok then iterate
      attrs = d~attributes
      if subscribedOnly then do
        if attrs~pos("\Subscribed") = 0 then do
          if attrs <> "" then attrs = attrs || " "
          attrs = attrs || "\Subscribed"
        end
      end
      lines~append("* " || command || " (" || attrs || ") " || .ImapCodec~quoteString(d~delimiter) || " " || .ImapCodec~quoteMailbox(d~name))
    end
    return self~response(tag, "OK", command || " completed", lines)
  end

  if command = "STATUS" then do
    if args~items <> 2 then return self~response(tag, "BAD", "STATUS requires mailbox and item list")
    decision = self~authorize("IMAP_STATUS", args[1])
    if \decision~ok then return self~response(tag, "NO", "[NOPERM] STATUS denied")
    r = mailboxProvider~status(args[1])
    if \r~ok then return self~providerFailure(tag, r, "STATUS")
    snapshot = r~value
    items = self~statusItems(snapshot, args[2])
    if items == .nil then return self~response(tag, "BAD", "unsupported STATUS item")
    return self~response(tag, "OK", "STATUS completed", .array~of("* STATUS " || .ImapCodec~quoteMailbox(snapshot~mailbox) || " (" || items || ")"))
  end

  if command = "SELECT" | command = "EXAMINE" then do
    if args~items <> 1 then return self~response(tag, "BAD", command || " requires one mailbox")
    readOnly = (command = "EXAMINE")
    action = "IMAP_SELECT"; if readOnly then action = "IMAP_EXAMINE"
    decision = self~authorize(action, args[1])
    if \decision~ok then return self~response(tag, "NO", "[NOPERM] " || command || " denied")
    r = mailboxProvider~select(args[1], readOnly)
    if \r~ok then return self~providerFailure(tag, r, command)
    snapshot = r~value
    cursor = self~providerChangeCursor(snapshot~mailbox)
    selectedState = .ImapServerSelection~new(snapshot, cursor); state = "SELECTED"
    mode = "[READ-WRITE]"; if snapshot~readOnly then mode = "[READ-ONLY]"
    return self~response(tag, "OK", mode || " " || command || " completed", self~selectionLines(snapshot))
  end

  if command = "CLOSE" then do
    if state <> "SELECTED" then return self~response(tag, "BAD", "CLOSE requires selected state")
    if args~items <> 0 then return self~response(tag, "BAD", "CLOSE takes no arguments")
    expunge = \selectedState~readOnly
    action = "IMAP_CLOSE"; if expunge then action = "IMAP_CLOSE_EXPUNGE"
    decision = self~authorize(action, selectedState~mailbox)
    if \decision~ok then return self~response(tag, "NO", "[NOPERM] CLOSE denied")
    r = mailboxProvider~close(selectedState~mailbox, expunge, sessionId)
    if \r~ok then return self~providerFailure(tag, r, "CLOSE")
    selectedState = .nil; state = "AUTHENTICATED"
    return self~response(tag, "OK", "CLOSE completed")
  end

  if command = "CREATE" then return self~oneMailboxMutation(tag, command, args, "IMAP_CREATE")
  if command = "DELETE" then return self~oneMailboxMutation(tag, command, args, "IMAP_DELETE")
  if command = "SUBSCRIBE" then return self~oneMailboxMutation(tag, command, args, "IMAP_SUBSCRIBE")
  if command = "UNSUBSCRIBE" then return self~oneMailboxMutation(tag, command, args, "IMAP_UNSUBSCRIBE")
  if command = "RENAME" then do
    if args~items <> 2 then return self~response(tag, "BAD", "RENAME requires source and destination")
    a = self~authorize("IMAP_RENAME_SOURCE", args[1])
    if \a~ok then return self~response(tag, "NO", "[NOPERM] RENAME source denied")
    b = self~authorize("IMAP_RENAME_DESTINATION", args[2])
    if \b~ok then return self~response(tag, "NO", "[NOPERM] RENAME destination denied")
    r = mailboxProvider~renameMailbox(args[1], args[2])
    if \r~ok then return self~providerFailure(tag, r, "RENAME")
    return self~response(tag, "OK", "RENAME completed")
  end

  if command = "APPEND" then return self~appendCommand(tag, args, literalBytes)
  if command = "FETCH" then return self~fetchCommand(tag, args, .false)
  if command = "STORE" then return self~storeCommand(tag, args, .false)
  if command = "SEARCH" then return self~searchCommand(tag, args, .false)
  if command = "COPY" then return self~copyCommand(tag, args, .false)
  if command = "MOVE" then return self~moveCommand(tag, args, .false)
  if command = "EXPUNGE" then return self~expungeCommand(tag, args, .nil)
  if command = "UID" then return self~uidCommand(tag, args)
  if command = "CHECK" then do
    if state <> "SELECTED" then return self~response(tag, "BAD", "CHECK requires selected state")
    if args~items <> 0 then return self~response(tag, "BAD", "CHECK takes no arguments")
    changes = self~pollSelectedChanges
    if \changes~ok then return self~response(tag, "NO", "[ALERT] selected mailbox state requires refresh")
    return self~response(tag, "OK", "CHECK completed", changes~value)
  end
  if command = "IDLE" then return self~response(tag, "BAD", "IDLE requires endpoint continuation handling")
  return self~response(tag, "BAD", "unknown or unsupported command")
::method requireSelectedWritable private
  expose state selectedState
  if state <> "SELECTED" then return .ImapServerResult~failure("SELECTED_STATE_REQUIRED")
  if selectedState~readOnly then return .ImapServerResult~failure("READ_ONLY_SELECTION")
  return .ImapServerResult~success(.true)
::method appendCommand private
  expose mailboxProvider sessionId
  use strict arg tag, args, literalBytes
  if args~items < 2 then return self~response(tag, "BAD", "APPEND requires mailbox and final literal marker")
  mailbox = args[1]
  if .ImapClassifiedInboxPolicy~isDeliveryManaged(mailbox) then return self~response(tag, "NO", "[NOPERM] delivery-managed mailbox")
  decision = self~authorize("IMAP_APPEND", mailbox)
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] APPEND denied")
  literalMarker = args[args~items]
  announced = self~literalMarkerLength(literalMarker)
  if announced < 0 then return self~response(tag, "BAD", "APPEND requires final {n} literal marker")
  if literalBytes == .nil then return self~response(tag, "BAD", "[LITERALREQUIRED] APPEND literal bytes were not supplied")
  if literalBytes~length <> announced then return self~response(tag, "BAD", "[LITERALMISMATCH] APPEND literal length mismatch")
  flags = .array~new; internalDate = ""
  if args~items >= 3 then do
    candidate = args[2]
    if candidate~left(1) = "(" then flags = self~flagArray(candidate)
    else internalDate = candidate
  end
  if args~items >= 4 then internalDate = args[3]
  r = mailboxProvider~appendMessage(mailbox, literalBytes, flags, internalDate, sessionId)
  if \r~ok then return self~providerFailure(tag, r, "APPEND")
  appended = r~value
  return self~response(tag, "OK", "[APPENDUID " || appended~uidValidity || " " || appended~uid || "] APPEND completed")
::method fetchCommand private
  expose state selectedState mailboxProvider
  use strict arg tag, args, uidMode
  if state <> "SELECTED" then return self~response(tag, "BAD", "FETCH requires selected state")
  if args~items <> 2 then return self~response(tag, "BAD", "FETCH requires set and data items")
  decision = self~authorize("IMAP_FETCH", selectedState~mailbox)
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] FETCH denied")
  r = mailboxProvider~fetchMessages(selectedState~mailbox, args[1], uidMode)
  if \r~ok then return self~providerFailure(tag, r, "FETCH")
  requested = args[2]~upper
  lines = .array~new
  do pair over r~value
    sequence = pair[1]; message = pair[2]
    payload = self~fetchData(message, requested, uidMode)
    if payload == .nil then return self~response(tag, "BAD", "unsupported FETCH data item")
    lines~append("* " || sequence || " FETCH (" || payload || ")")
  end
  return self~response(tag, "OK", "FETCH completed", lines)
::method fetchData private
  use strict arg message, requested, uidMode
  req = requested~strip
  if req~left(1) = "(" then do
    if req~right(1) = ")" then req = req~substr(2, req~length - 2)
  end
  wantFlags = req~pos("FLAGS") > 0
  wantUid = uidMode | req~pos("UID") > 0
  wantSize = req~pos("RFC822.SIZE") > 0
  wantBody = req~pos("BODY[]") > 0 | req~pos("BODY.PEEK[]") > 0 | req~pos("RFC822") > 0
  if \wantFlags then do
    if \wantUid then do
      if \wantSize then do
        if \wantBody then return .nil
      end
    end
  end
  out = ""
  if wantUid then out = "UID " || message~uid
  if wantFlags then do
    if out <> "" then out = out || " "
    out = out || "FLAGS (" || self~flagsText(message~flags) || ")"
  end
  if wantSize then do
    if out <> "" then out = out || " "
    out = out || "RFC822.SIZE " || message~bytes~length
  end
  if wantBody then do
    if out <> "" then out = out || " "
    out = out || "BODY[] {" || message~bytes~length || "}" || '0d0a'x || message~bytes
  end
  return out
::method storeCommand private
  expose state selectedState mailboxProvider sessionId
  use strict arg tag, args, uidMode
  rw = self~requireSelectedWritable
  if \rw~ok then return self~response(tag, "NO", "[READ-ONLY] STORE requires read-write selection")
  if args~items <> 3 then return self~response(tag, "BAD", "STORE requires set, item and flags")
  decision = self~authorize("IMAP_STORE", selectedState~mailbox)
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] STORE denied")
  item = args[2]~upper; silent = item~pos(".SILENT") > 0
  operation = item~changeStr(".SILENT", "")
  if operation <> "FLAGS" then do
    if operation <> "+FLAGS" then do
      if operation <> "-FLAGS" then return self~response(tag, "BAD", "unsupported STORE item")
    end
  end
  r = mailboxProvider~storeFlags(selectedState~mailbox, args[1], uidMode, operation, self~flagArray(args[3]), sessionId)
  if \r~ok then return self~providerFailure(tag, r, "STORE")
  lines = .array~new
  if \silent then do
    do pair over r~value
      lines~append("* " || pair[1] || " FETCH (FLAGS (" || self~flagsText(pair[2]~flags) || ") UID " || pair[2]~uid || ")")
    end
  end
  return self~response(tag, "OK", "STORE completed", lines)
::method searchCommand private
  expose state selectedState mailboxProvider
  use strict arg tag, args, uidMode
  if state <> "SELECTED" then return self~response(tag, "BAD", "SEARCH requires selected state")
  if args~items < 1 then criteria = "ALL"
  else do
    criteria = args[1]
    if args~items > 1 then return self~response(tag, "BAD", "dev11 SEARCH accepts one criterion")
  end
  decision = self~authorize("IMAP_SEARCH", selectedState~mailbox)
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] SEARCH denied")
  r = mailboxProvider~searchMessages(selectedState~mailbox, criteria, uidMode)
  if \r~ok then do
    if r~code = "SEARCH_CRITERIA_UNSUPPORTED" then return self~response(tag, "BAD", "unsupported SEARCH criterion")
    return self~providerFailure(tag, r, "SEARCH")
  end
  line = "* SEARCH"
  do value over r~value; line = line || " " || value; end
  return self~response(tag, "OK", "SEARCH completed", .array~of(line))
::method copyCommand private
  expose state selectedState mailboxProvider sessionId
  use strict arg tag, args, uidMode
  if state <> "SELECTED" then return self~response(tag, "BAD", "COPY requires selected state")
  if args~items <> 2 then return self~response(tag, "BAD", "COPY requires set and destination")
  if .ImapClassifiedInboxPolicy~isDeliveryManaged(args[2]) then return self~response(tag, "NO", "[NOPERM] delivery-managed mailbox")
  a = self~authorize("IMAP_COPY_SOURCE", selectedState~mailbox)
  if \a~ok then return self~response(tag, "NO", "[NOPERM] COPY source denied")
  b = self~authorize("IMAP_COPY_DESTINATION", args[2])
  if \b~ok then return self~response(tag, "NO", "[NOPERM] COPY destination denied")
  r = mailboxProvider~copyMessages(selectedState~mailbox, args[1], uidMode, args[2], sessionId)
  if \r~ok then return self~providerFailure(tag, r, "COPY")
  copied = r~value
  return self~response(tag, "OK", "[COPYUID " || copied~uidValidity || " " || copied~sourceUids~wire || " " || copied~destinationUids~wire || "] COPY completed")
::method moveCommand private
  expose state selectedState mailboxProvider sessionId
  use strict arg tag, args, uidMode
  rw = self~requireSelectedWritable
  if \rw~ok then return self~response(tag, "NO", "[READ-ONLY] MOVE requires read-write selection")
  if args~items <> 2 then return self~response(tag, "BAD", "MOVE requires set and destination")
  if .ImapClassifiedInboxPolicy~isDeliveryManaged(args[2]) then return self~response(tag, "NO", "[NOPERM] delivery-managed mailbox")
  a = self~authorize("IMAP_MOVE_SOURCE", selectedState~mailbox)
  if \a~ok then return self~response(tag, "NO", "[NOPERM] MOVE source denied")
  b = self~authorize("IMAP_MOVE_DESTINATION", args[2])
  if \b~ok then return self~response(tag, "NO", "[NOPERM] MOVE destination denied")
  r = mailboxProvider~moveMessages(selectedState~mailbox, args[1], uidMode, args[2], sessionId)
  if \r~ok then return self~providerFailure(tag, r, "MOVE")
  copied = r~value[1]; removed = r~value[2]
  lines = .array~new
  do pair over removed; lines~insert("* " || pair[1] || " EXPUNGE", 1); end
  return self~response(tag, "OK", "[COPYUID " || copied~uidValidity || " " || copied~sourceUids~wire || " " || copied~destinationUids~wire || "] MOVE completed", lines)
::method expungeCommand private
  expose selectedState mailboxProvider sessionId
  use strict arg tag, args, exactUidSet
  rw = self~requireSelectedWritable
  if \rw~ok then return self~response(tag, "NO", "[READ-ONLY] EXPUNGE requires read-write selection")
  if args~items <> 0 then return self~response(tag, "BAD", "EXPUNGE takes no arguments")
  action = "IMAP_EXPUNGE"; if exactUidSet <> .nil then action = "IMAP_UID_EXPUNGE"
  decision = self~authorize(action, selectedState~mailbox)
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] EXPUNGE denied")
  r = mailboxProvider~expungeMessages(selectedState~mailbox, exactUidSet, sessionId)
  if \r~ok then return self~providerFailure(tag, r, "EXPUNGE")
  lines = .array~new
  do pair over r~value; lines~insert("* " || pair[1] || " EXPUNGE", 1); end
  return self~response(tag, "OK", "EXPUNGE completed", lines)
::method uidCommand private
  use strict arg tag, args
  if args~items < 2 then return self~response(tag, "BAD", "UID requires subcommand and arguments")
  sub = args[1]~upper
  rest = .array~new
  do i = 2 to args~items; rest~append(args[i]); end
  if sub = "FETCH" then return self~fetchCommand(tag, rest, .true)
  if sub = "STORE" then return self~storeCommand(tag, rest, .true)
  if sub = "SEARCH" then return self~searchCommand(tag, rest, .true)
  if sub = "COPY" then return self~copyCommand(tag, rest, .true)
  if sub = "MOVE" then return self~moveCommand(tag, rest, .true)
  if sub = "EXPUNGE" then do
    if rest~items <> 1 then return self~response(tag, "BAD", "UID EXPUNGE requires UID set")
    set = .ImapUidSet~parse(rest[1])
    return self~expungeCommand(tag, .array~new, set)
  end
  return self~response(tag, "BAD", "unsupported UID subcommand")
::method literalMarkerLength
  numeric digits 30
  use strict arg markerArg
  marker = markerArg~string~strip
  if marker~length < 3 then return -1
  if marker~left(1) <> "{" then return -1
  if marker~right(1) <> "}" then return -1
  body = marker~substr(2, marker~length - 2)
  if body~right(1) = "+" then body = body~left(body~length - 1)
  if \datatype(body, "W") then return -1
  return .ImapNumber~whole(body, "IMAP_SERVER_LITERAL", 0, 2147483648)
::method flagArray private
  use strict arg textArg
  text = textArg~string~strip
  if text~left(1) = "(" then do
    if text~right(1) = ")" then text = text~substr(2, text~length - 2)
  end
  out = .array~new
  do i = 1 to text~words; out~append(text~word(i)); end
  return out
::method flagsText private
  use strict arg flags
  out = ""
  do flag over flags
    if out <> "" then out = out || " "
    out = out || flag
  end
  return out
::method oneMailboxMutation private
  expose mailboxProvider
  use strict arg tag, command, args, action
  if args~items <> 1 then return self~response(tag, "BAD", command || " requires one mailbox")
  decision = self~authorize(action, args[1])
  if \decision~ok then return self~response(tag, "NO", "[NOPERM] " || command || " denied")
  select
    when command = "CREATE" then r = mailboxProvider~createMailbox(args[1])
    when command = "DELETE" then r = mailboxProvider~deleteMailbox(args[1])
    when command = "SUBSCRIBE" then r = mailboxProvider~subscribeMailbox(args[1])
    when command = "UNSUBSCRIBE" then r = mailboxProvider~unsubscribeMailbox(args[1])
    otherwise return self~response(tag, "BAD", "unsupported mailbox mutation")
  end
  if \r~ok then return self~providerFailure(tag, r, command)
  return self~response(tag, "OK", command || " completed")
::method statusItems private
  use strict arg snapshot, requested
  list = requested~strip
  if list~left(1) = "(" then do
    if list~right(1) = ")" then list = list~substr(2, list~length - 2)
  end
  out = ""
  do i = 1 to list~words
    item = list~word(i)~upper
    select
      when item = "MESSAGES" then value = snapshot~messageCount
      when item = "RECENT" then value = snapshot~recent
      when item = "UNSEEN" then value = snapshot~unseenCount
      when item = "UIDNEXT" then value = snapshot~uidNext
      when item = "UIDVALIDITY" then value = snapshot~uidValidity
      when item = "HIGHESTMODSEQ" then value = snapshot~highestModSeq
      otherwise return .nil
    end
    if out <> "" then out = out || " "
    out = out || item || " " || value
  end
  return out
::method selectionLines private
  use strict arg snapshot
  lines = .array~new
  lines~append("* FLAGS (" || snapshot~flags || ")")
  lines~append("* " || snapshot~messageCount || " EXISTS")
  lines~append("* " || snapshot~recent || " RECENT")
  lines~append("* OK [UIDVALIDITY " || snapshot~uidValidity || "] UIDs valid")
  lines~append("* OK [UIDNEXT " || snapshot~uidNext || "] Predicted next UID")
  if snapshot~highestModSeq <> "" then lines~append("* OK [HIGHESTMODSEQ " || snapshot~highestModSeq || "] Highest mod-sequence")
  lines~append("* OK [PERMANENTFLAGS (" || snapshot~permanentFlags || ")] Permanent flags")
  return lines

/* Endpoint loop over an already-established line transport.  Listener/TLS
 * ownership remains outside this object. */
::class ImapServerEndpoint public
::method init
  expose session maxCommands maxLineBytes observer idlePollSeconds maxIdlePolls
  use strict arg sessionArg, maxCommandsArg = 100000, maxLineBytesArg = 1048576, observerArg = .nil, idlePollSecondsArg = 1, maxIdlePollsArg = 1740
  numeric digits 30
  session = sessionArg
  observer = observerArg
  maxCommands = .ImapNumber~whole(maxCommandsArg,"IMAP_SERVER_MAX_COMMANDS",1)
  maxLineBytes = .ImapNumber~whole(maxLineBytesArg,"IMAP_SERVER_MAX_LINE",1024)
  if \datatype(idlePollSecondsArg,"N") then raise syntax 88.900 array("IMAP_SERVER_IDLE_POLL_INVALID", idlePollSecondsArg)
  if idlePollSecondsArg <= 0 then raise syntax 88.900 array("IMAP_SERVER_IDLE_POLL_INVALID", idlePollSecondsArg)
  idlePollSeconds = idlePollSecondsArg
  maxIdlePolls = .ImapNumber~whole(maxIdlePollsArg,"IMAP_SERVER_IDLE_POLLS",1,86400)
  if maxCommands < 1 then raise syntax 88.900 array("IMAP_SERVER_MAX_COMMANDS_INVALID", maxCommands)
  if maxLineBytes < 1024 then raise syntax 88.900 array("IMAP_SERVER_MAX_LINE_TOO_SMALL", maxLineBytes)
::method observedCommandName private
  expose maxLineBytes
  use strict arg line
  parsed = .ImapServerParser~parseLine(line, maxLineBytes)
  if \parsed~ok then return "PARSE"
  command = parsed~command~string~upper
  if command = "UID" then do
    args = parsed~args
    if args~items > 0 then command = "UID_" || args[1]~string~upper
  end
  return command
::method observerCall private
  expose observer
  use strict arg methodName, a1 = .nil, a2 = .nil
  if observer == .nil then return .false
  name = methodName~string~upper
  if \observer~hasMethod(name) then return .false
  if arg() = 1 then observer~send(name)
  else if arg() = 2 then observer~send(name, a1)
  else observer~send(name, a1, a2)
  return .true
::method finishObservation private
  expose session
  use strict arg serverResult
  self~observerCall("SESSIONCLOSED", session~state)
  return serverResult
::method failObservation private
  use strict arg code, detail = ""
  self~observerCall("TRANSPORTFAILURE", code)
  return self~finishObservation(.ImapServerResult~failure(code, detail))
::method transportSupportsIdle private
  use strict arg transport
  if transport~hasMethod("SUPPORTSREADINESS") then return transport~supportsReadiness
  return transport~hasMethod("WAITREADABLE")
::method updateWire private
  use strict arg lines
  return .ImapServerResponse~new(lines, .false, "UPDATE")~wire
::method serve
  expose session maxCommands maxLineBytes idlePollSeconds maxIdlePolls
  use strict arg transport
  if transport == .nil then return .ImapServerResult~failure("IMAP_SERVER_TRANSPORT_REQUIRED")
  if \transport~hasMethod("READLINE") then return .ImapServerResult~failure("IMAP_SERVER_TRANSPORT_INVALID", "readLine")
  if \transport~hasMethod("WRITEALL") then return .ImapServerResult~failure("IMAP_SERVER_TRANSPORT_INVALID", "writeAll")

  ignore = session~setIdleTransportCapable(self~transportSupportsIdle(transport))
  self~observerCall("SESSIONOPENED", session~tlsActive)
  greeting = session~greeting || '0d0a'x
  if \transport~writeAll(greeting) then return self~failObservation("IMAP_SERVER_GREETING_WRITE_FAILED")
  self~observerCall("BYTESOUT", greeting~length)

  do commandCount = 1 to maxCommands
    line = transport~readLine(maxLineBytes)
    if line == .nil then return self~finishObservation(.ImapServerResult~success(commandCount - 1, "CLIENT_CLOSED"))
    self~observerCall("BYTESIN", line~length + 2)
    parsedForEndpoint = .ImapServerParser~parseLine(line, maxLineBytes)
    commandName = self~observedCommandName(line)
    self~observerCall("COMMANDACCEPTED", commandName)

    if commandName = "IDLE" then do
      idleResponse = session~processIdleStart(parsedForEndpoint)
      if idleResponse~status <> "CONTINUE" then do
        self~observerCall("COMMANDCOMPLETED", commandName, idleResponse~status)
        idleWire = idleResponse~wire
        if \transport~writeAll(idleWire) then return self~failObservation("IMAP_SERVER_RESPONSE_WRITE_FAILED", commandCount~string)
        self~observerCall("BYTESOUT", idleWire~length)
        iterate
      end

      idleWire = idleResponse~wire
      if \transport~writeAll(idleWire) then return self~failObservation("IMAP_SERVER_IDLE_CONTINUATION_WRITE_FAILED")
      self~observerCall("BYTESOUT", idleWire~length)
      self~observerCall("IDLESTARTED")
      idlePollCount = 0

      do while session~idleActive
        changes = session~pollSelectedChanges
        if \changes~ok then do
          bye = "* BYE [ALERT] selected mailbox change history unavailable" || '0d0a'x
          if changes~code = "IMAP_AUTHORIZATION_REVOKED" then bye = "* BYE [ALERT] selected mailbox access revoked" || '0d0a'x
          ignoreWrite = transport~writeAll(bye)
          if ignoreWrite then return self~failObservation("IMAP_SERVER_RESPONSE_WRITE_FAILED", "idle-change-feed")
          self~observerCall("BYTESOUT", bye~length)
          self~observerCall("IDLESTOPPED", "CHANGE_FEED_FAILURE")
          self~observerCall("COMMANDFAILED", commandName, changes~code)
          return self~finishObservation(.ImapServerResult~failure("IMAP_SERVER_CHANGE_FEED_FAILED", changes~code))
        end
        updateLines = changes~value
        if updateLines~items > 0 then do
          updateWire = self~updateWire(updateLines)
          if \transport~writeAll(updateWire) then do
            self~observerCall("IDLESTOPPED", "UPDATE_WRITE_FAILED")
            return self~failObservation("IMAP_SERVER_IDLE_UPDATE_WRITE_FAILED")
          end
          self~observerCall("BYTESOUT", updateWire~length)
          self~observerCall("IDLEUPDATE", updateLines~items)
        end

        idlePollCount += 1
        if idlePollCount > maxIdlePolls then do
          bye = "* BYE [TIMEOUT] IDLE server limit reached" || '0d0a'x
          ignoreWrite = transport~writeAll(bye)
          if ignoreWrite then return self~failObservation("IMAP_SERVER_RESPONSE_WRITE_FAILED", "idle-timeout")
          self~observerCall("BYTESOUT", bye~length)
          self~observerCall("IDLESTOPPED", "TIMEOUT")
          self~observerCall("COMMANDFAILED", commandName, "IDLE_TIMEOUT")
          return self~finishObservation(.ImapServerResult~failure("IMAP_SERVER_IDLE_TIMEOUT"))
        end

        ready = transport~waitReadable(idlePollSeconds)
        if ready == .nil then do
          self~observerCall("IDLESTOPPED", "READINESS_FAILED")
          return self~failObservation("IMAP_SERVER_IDLE_READINESS_FAILED")
        end
        if \datatype(ready,"N") then do
          self~observerCall("IDLESTOPPED", "READINESS_INVALID")
          return self~failObservation("IMAP_SERVER_IDLE_READINESS_INVALID")
        end
        if ready < 0 then do
          self~observerCall("IDLESTOPPED", "READINESS_UNAVAILABLE")
          return self~failObservation("IMAP_SERVER_IDLE_READINESS_UNAVAILABLE")
        end
        if ready = 0 then iterate

        doneLine = transport~readLine(maxLineBytes)
        if doneLine == .nil then do
          self~observerCall("IDLESTOPPED", "CLIENT_CLOSED")
          return self~finishObservation(.ImapServerResult~success(commandCount - 1, "CLIENT_CLOSED"))
        end
        self~observerCall("BYTESIN", doneLine~length + 2)
        if doneLine~strip~upper = "DONE" then do
          finished = session~finishIdle
          idleStopReason = "DONE"
        end
        else do
          finished = session~abortIdle("expected DONE")
          idleStopReason = "INVALID_TERMINATOR"
        end
        self~observerCall("IDLESTOPPED", idleStopReason)
        self~observerCall("COMMANDCOMPLETED", commandName, finished~status)
        finishedWire = finished~wire
        if \transport~writeAll(finishedWire) then return self~failObservation("IMAP_SERVER_RESPONSE_WRITE_FAILED", "idle-finish")
        self~observerCall("BYTESOUT", finishedWire~length)
      end
      iterate
    end

    literalBytes = .nil
    marker = line~word(line~words)
    length = session~literalMarkerLength(marker)
    if length >= 0 then do
      if \transport~hasMethod("READEXACT") then do
        self~observerCall("COMMANDFAILED", commandName, "READ_EXACT_REQUIRED")
        return self~failObservation("IMAP_SERVER_TRANSPORT_INVALID", "readExact required for literal")
      end
      nonSync = marker~pos("+}") > 0
      if \nonSync then do
        continuation = "+ Ready for literal" || '0d0a'x
        if \transport~writeAll(continuation) then do
          self~observerCall("COMMANDFAILED", commandName, "CONTINUATION_WRITE_FAILED")
          return self~failObservation("IMAP_SERVER_CONTINUATION_WRITE_FAILED")
        end
        self~observerCall("BYTESOUT", continuation~length)
      end
      literalBytes = transport~readExact(length)
      if literalBytes == .nil then do
        self~observerCall("COMMANDFAILED", commandName, "LITERAL_READ_FAILED")
        return self~failObservation("IMAP_SERVER_LITERAL_READ_FAILED")
      end
      if literalBytes~length <> length then do
        self~observerCall("BYTESIN", literalBytes~length)
        self~observerCall("LITERALBYTESIN", literalBytes~length)
        self~observerCall("COMMANDFAILED", commandName, "LITERAL_TRUNCATED")
        return self~failObservation("IMAP_SERVER_LITERAL_TRUNCATED")
      end
      self~observerCall("BYTESIN", length)
      self~observerCall("LITERALBYTESIN", length)
      trailer = transport~readLine(maxLineBytes)
      if trailer == .nil then do
        self~observerCall("COMMANDFAILED", commandName, "LITERAL_TRAILER_MISSING")
        return self~failObservation("IMAP_SERVER_LITERAL_TRAILER_MISSING")
      end
      self~observerCall("BYTESIN", trailer~length + 2)
      if trailer <> "" then do
        self~observerCall("COMMANDFAILED", commandName, "LITERAL_TRAILER_INVALID")
        return self~failObservation("IMAP_SERVER_LITERAL_TRAILER_INVALID")
      end
    end

    oldState = session~state
    response = session~processLineWithLiteral(line, literalBytes)
    newState = session~state
    if oldState <> newState then self~observerCall("STATETRANSITION", oldState, newState)
    self~observerCall("COMMANDCOMPLETED", commandName, response~status)
    wire = response~wire
    if \transport~writeAll(wire) then return self~failObservation("IMAP_SERVER_RESPONSE_WRITE_FAILED", commandCount~string)
    self~observerCall("BYTESOUT", wire~length)
    if response~closeConnection then return self~finishObservation(.ImapServerResult~success(commandCount, "LOGOUT"))
  end
  return self~failObservation("IMAP_SERVER_COMMAND_LIMIT", maxCommands~string)

::requires "ImapCore.cls"
