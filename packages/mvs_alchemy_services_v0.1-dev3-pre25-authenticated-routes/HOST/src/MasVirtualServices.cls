/* MasVirtualServices.cls - MAS dev3-pre6 host virtual service layer.
 * Runs on ED209C.  Stable MAS semantics are separated from provider-native APIs.
 */

::class MasMemoryQueueProvider public
::method init public
  expose queues
  queues = .directory~new

::method _queue private
  expose queues
  use strict arg name
  key = name~string~translate
  if \queues~hasIndex(key) then queues[key] = .queue~new
  return queues[key]

::method put public
  use strict arg name, payload
  q = self~_queue(name)
  q~queue(payload)
  return q~items

::method get public
  use strict arg name
  q = self~_queue(name)
  if q~items = 0 then return .nil
  return q~pull

::method depth public
  use strict arg name
  return self~_queue(name)~items

::class MasMemoryDatabaseProvider public
::method init public
  expose databases
  databases = .directory~new

::method _database private
  expose databases
  use strict arg name
  key = name~string~translate
  if \databases~hasIndex(key) then databases[key] = .directory~new
  return databases[key]

::method put public
  use strict arg name, key, value
  db = self~_database(name)
  db[key] = value
  return .true

::method get public
  use strict arg name, key
  db = self~_database(name)
  if \db~hasIndex(key) then return .nil
  return db[key]

::method delete public
  use strict arg name, key
  db = self~_database(name)
  if \db~hasIndex(key) then return .false
  db~remove(key)
  return .true

::method scan public
  use strict arg name, afterKey = '', limit = 50
  if limit < 1 | limit > 256 then raise syntax 88.900 array('BAD_PAGE_LIMIT')
  db = self~_database(name)
  keys = db~allIndexes
  sorted = keys~sort
  rows = .array~new
  do key over sorted
    if key > afterKey then do
      rows~append(.array~of(key, db[key]))
      if rows~items >= limit then leave
    end
  end
  return rows

::class MasMailMessage public
::method init public
  expose uidvalidity uid mailbox sender subject headers body parts seen
  use strict arg uidvalidity, uid, mailbox, sender, subject, headers, body, parts = (.array~new)
  seen = .false
::attribute uidvalidity get
::attribute uid get
::attribute mailbox get
::attribute sender get
::attribute subject get
::attribute headers get
::attribute body get
::attribute parts get
::attribute seen

::class MasMemoryImapProvider public
::method init public
  expose mailboxes
  mailboxes = .directory~new
  inbox = .array~new
  inbox~append(.MasMailMessage~new(71, 1001, 'INBOX', 'alice@example.test', 'signed one',,
    'From: alice@example.test' || '0d0a'x || 'Subject: signed one' || '0d0a'x, 'hello' || '0d0a'x, .array~of('attachment' || '00ff'x)))
  inbox~append(.MasMailMessage~new(71, 1002, 'INBOX', 'bob@example.test', 'signed two',,
    'From: bob@example.test' || '0d0a'x || 'Subject: signed two' || '0d0a'x, 'second' || '0d0a'x))
  unsigned = .array~new
  unsigned~append(.MasMailMessage~new(72, 2001, 'INBOX-UNSIGNED', 'unknown@example.test', 'unverified',,
    'From: unknown@example.test' || '0d0a'x || 'Subject: unverified' || '0d0a'x, 'unsigned' || '0d0a'x))
  mailboxes['INBOX'] = inbox
  mailboxes['INBOX-UNSIGNED'] = unsigned

::method listMailboxes public
  expose mailboxes
  return mailboxes~allIndexes~sort

::method page public
  expose mailboxes
  use strict arg mailbox, afterUid = 0, limit = 50
  key = mailbox~string~translate
  if \mailboxes~hasIndex(key) then return .nil
  if limit < 1 | limit > 256 then raise syntax 88.900 array('BAD_PAGE_LIMIT')
  messages = .array~new
  do m over mailboxes[key]
    if m~uid > afterUid then do
      messages~append(m)
      if messages~items >= limit then leave
    end
  end
  return messages

::method get public
  expose mailboxes
  use strict arg mailbox, uidvalidity, uid
  key = mailbox~string~translate
  if \mailboxes~hasIndex(key) then return .nil
  do m over mailboxes[key]
    if m~uid = uid then do
      if m~uidvalidity <> uidvalidity then raise syntax 88.900 array('UIDVALIDITY_CHANGED')
      return m
    end
  end
  return .nil

::method setSeen public
  use strict arg mailbox, uidvalidity, uid, seen = .true
  m = self~get(mailbox, uidvalidity, uid)
  if m == .nil then return .false
  m~seen = seen
  return seen

::class MasOutboundDraft public
::method init public
  expose sender recipients body signaturePresent signatureVerified identityMatches emailSendAuthorized egressPermitted state
  sender = ''; recipients = .array~new; body = ''
  signaturePresent = .false; signatureVerified = .false; identityMatches = .false
  emailSendAuthorized = .false; egressPermitted = .false; state = 'DRAFT'
::attribute sender
::attribute recipients get
::attribute body
::attribute signaturePresent
::attribute signatureVerified
::attribute identityMatches
::attribute emailSendAuthorized
::attribute egressPermitted
::attribute state
::method addRecipient public
  expose recipients
  use strict arg recipient
  recipients~append(recipient)

::class MasMemorySmtpProvider public
::method init public
  expose relayed
  relayed = .array~new
::attribute relayed get

::method submit public
  expose relayed
  use strict arg draft
  if draft~sender = '' | draft~recipients~items = 0 then return 'ENVELOPE_INCOMPLETE'
  if \draft~signaturePresent then return 'MESSAGE_SIGNATURE_REQUIRED'
  if \draft~signatureVerified then return 'MESSAGE_SIGNATURE_INVALID'
  if \draft~identityMatches then return 'SIGNATURE_IDENTITY_MISMATCH'
  if \draft~emailSendAuthorized then return 'EMAIL_SEND_NOT_AUTHORIZED'
  if \draft~egressPermitted then return 'EGRESS_POLICY_DENIED'
  draft~state = 'RELAY_ELIGIBLE'
  relayed~append(draft)
  return 'RELAY_ELIGIBLE'

::class MasVirtualServices public
::method init public
  expose queueProvider databaseProvider imapProvider smtpProvider
  use strict arg queueProvider = (.MasMemoryQueueProvider~new),,
                 databaseProvider = (.MasMemoryDatabaseProvider~new),,
                 imapProvider = (.MasMemoryImapProvider~new),,
                 smtpProvider = (.MasMemorySmtpProvider~new)
::attribute queueProvider get
::attribute databaseProvider get
::attribute imapProvider get
::attribute smtpProvider get

::method inventory public
  inventory = .directory~new
  inventory['QUEUE'] = 'AVAILABLE'
  inventory['DATABASE'] = 'AVAILABLE'
  inventory['IMAP'] = 'AVAILABLE'
  inventory['SMTP'] = 'AVAILABLE'
  return inventory
