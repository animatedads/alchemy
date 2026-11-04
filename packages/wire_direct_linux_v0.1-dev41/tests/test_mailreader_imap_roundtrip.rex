/* Real MailReader composition over the Wire IMAP adapter, with a deterministic
   in-process IMAP session double.  Protocol access remains behind WireImapMailboxCollection. */
call directory filespec('location', sourceLine(1))
call directory '..'

session = .FakeImapSession~new(200000, 4242)
mailbox = .WireImapMailboxCollection~new(session, "INBOX")
call assert mailbox~count == 200000, "200000-message UID collection retained behind source adapter"
window = mailbox~range(0, 100)
call assert window~count == 100, "source window is bounded to 100 identities"
call assert session~bodyFetches == 0, "list window does not fetch message bodies"

model = .WireApplicationModel~new
model~addElement("messages", .WireElementState~new("messages", "VirtualList"))
model~addElement("message", .WireElementState~new("message", "Document"))
projection = .TraceProjection~new
model~projection = projection

allowed = .directory~new
allowed["message"] = .true
scopes = .directory~new
scopes["messages"] = allowed

resolver = .WireImapMessageResolver~new(mailbox)
target = .WireElementTarget~new(model~ui, "message")
selection = .WireSelectionProjection~new(resolver, target, "value")
subject = .WireEventSubjectProjection~new("identity")
behaviour = .WireMailReaderBehaviour~new(subject, selection)
model~addBinding(.WireBinding~new("mail.select.imap", "messages", "SelectionChanged", behaviour, "selectionChanged"))
controller = .WireApplicationController~new(model)
port = .WireRendererEventPort~new(controller, model, scopes)

/* UID 8738 is deliberately nowhere near the first 100-row window.  Selection
   is by durable identity, never by GTK/list ordinal. */
identity = "INBOX|4242|8738"
results = port~dispatch("messages", "SelectionChanged", "identity", identity, "gtk4")
call assert results~items == 1, "one MailReader binding dispatched"
call assert session~bodyFetches == 1, "only selected message body fetched"
call assert session~lastBodyUid == "8738", "selected stable UID reached IMAP adapter"
call assert model~elementProperty("message", "value") == "Subject: ACTION REQUIRED" || '0a'x || "Body: selected by stable UID 8738", "IMAP body projected through authoritative Wire state"
call assert projection~updates == 1, "one renderer-neutral document projection"
call assert projection~entry(1)~left(14) == "message|value|", "projection targets semantic message element"

say "wire-mailreader-imap-roundtrip=PASS count=200000 window=100 identity=" || identity || " bodyFetches=" || session~bodyFetches
exit 0

assert: procedure
  use strict arg condition, label
  if \condition then do
    say "FAIL:" label
    exit 1
  end
return

::class FakeCommandResult
::attribute ok get
::method init
  expose ok
  use strict arg ok = .true

::class FakeBodyResult
::attribute text get
::method init
  expose text
  use strict arg text

::class FakeImapSession
::attribute selectedState get
::attribute bodyFetches get
::attribute lastBodyUid get
::method init
  expose messageCount uidValidity selectedState bodyFetches lastBodyUid
  use strict arg messageCount = 200000, uidValidity = 4242
  selectedState = .nil
  bodyFetches = 0
  lastBodyUid = ""
::method examine
  expose messageCount uidValidity selectedState
  use strict arg mailbox
  selectedState = .ImapMailboxState~new
  selectedState~mailbox = mailbox
  selectedState~exists = messageCount
  selectedState~uidValidity = uidValidity
  selectedState~readOnly = .true
  return .FakeCommandResult~new(.true)
::method uidSearch
  expose messageCount
  use strict arg criteria, returnItems = ""
  search = .ImapSearchResult~new
  search~uidMode = .true
  search~count = messageCount
  search~minimum = 1
  search~maximum = messageCount
  search~all = .ImapUidSet~new
  search~all~addRange(1, messageCount)
  search~complete = .true
  return .array~of(.FakeCommandResult~new(.true), search)
::method uidFetchPeek
  use strict arg uidSet, items, sinkFactory = .nil
  return .FakeCommandResult~new(.true)
::method uidFetchBodyPeek
  expose bodyFetches lastBodyUid
  use strict arg uidSet, section = "", partial = "", sinkFactory = .nil
  lastBodyUid = uidSet~string
  bodyFetches += 1
  if lastBodyUid == "8738" then return .FakeBodyResult~new("Subject: ACTION REQUIRED" || '0a'x || "Body: selected by stable UID 8738")
  return .FakeBodyResult~new("Unexpected UID " || lastBodyUid)

::class TraceProjection
::method init
  expose entries
  entries = .array~new
::method setElementProperty
  expose entries
  use strict arg id, name, value
  entries~append(id || "|" || name || "|" || value)
  return .true
::method updates
  expose entries
  return entries~items
::method entry
  expose entries
  use strict arg n
  return entries[n]

::requires "../rexx/WireElementState.cls"
::requires "../rexx/WireApplicationModel.cls"
::requires "../rexx/WireBinding.cls"
::requires "../rexx/WireApplicationController.cls"
::requires "../rexx/WireRendererEventPort.cls"
::requires "../rexx/WireElementTarget.cls"
::requires "../rexx/WireSelectionProjection.cls"
::requires "../rexx/WireEventSubjectProjection.cls"
::requires "../rexx/WireMailReaderBehaviour.cls"
::requires "../rexx/WireImapMessageResolver.cls"
