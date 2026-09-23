/* ooRexx IMAP v0.1-dev5 semantic mutation planning.
 *
 * IMAP APPEND/COPY/MOVE are wire operations.  Their application meaning is
 * server- and mailbox-dependent.  This module keeps that meaning separate from
 * the protocol engine so a room-oriented server such as Citadel can expose
 * posting/submission semantics without contaminating generic IMAP parsing.
 */

::class ImapMailboxRole public
::method canonical class
  use strict arg value
  v = value~string~strip~upper
  select
    when v = "" | v = "ORDINARY" | v = "NORMAL" then return "ORDINARY"
    when v = "SENT" | v = "\SENT" then return "SENT"
    when v = "DRAFTS" | v = "\DRAFTS" then return "DRAFTS"
    when v = "JUNK" | v = "SPAM" | v = "\JUNK" then return "JUNK"
    when v = "TRASH" | v = "DELETED" | v = "\TRASH" then return "TRASH"
    when v = "ARCHIVE" | v = "\ARCHIVE" then return "ARCHIVE"
    otherwise raise syntax 88.900 array("IMAP_UNKNOWN_MAILBOX_ROLE", value)
  end

::class ImapMutationIntent public
::method canonical class
  use strict arg value
  v = value~string~strip~upper
  select
    when v = "STORE" | v = "PASSIVE_STORE" then return "STORE"
    when v = "RESTORE" then return "RESTORE"
    when v = "MIGRATE" | v = "MIGRATION" then return "MIGRATE"
    when v = "POST" then return "POST"
    when v = "SUBMIT" | v = "SEND" then return "SUBMIT"
    otherwise raise syntax 88.900 array("IMAP_UNKNOWN_MUTATION_INTENT", value)
  end
::method expectedEffect class
  use strict arg value
  v = self~canonical(value)
  if v = "POST" then return "POST"
  if v = "SUBMIT" then return "SUBMIT"
  return "PASSIVE_STORE"

::class ImapMutationDecision public
::attribute allowed get
::attribute requiresExplicitPolicy get
::attribute profileName get
::attribute mailboxRole get
::attribute intent get
::attribute actualEffect get
::attribute expectedEffect get
::attribute reason get
::method init
  expose allowed requiresExplicitPolicy profileName mailboxRole intent actualEffect expectedEffect reason
  use strict arg allowedArg, explicitArg, profileArg, roleArg, intentArg, actualArg, expectedArg, reasonArg = ""
  allowed = allowedArg
  requiresExplicitPolicy = explicitArg
  profileName = profileArg~string
  mailboxRole = roleArg~string
  intent = intentArg~string
  actualEffect = actualArg~string
  expectedEffect = expectedArg~string
  reason = reasonArg~string

::class ImapServerBehaviorProfile public
::attribute name get
::attribute defaultAppendEffect get
::attribute sentAppendEffect get
::attribute draftsAppendEffect get
::attribute smtpAutoRecordsSent get
::method init
  expose name defaultAppendEffect sentAppendEffect draftsAppendEffect smtpAutoRecordsSent
  use strict arg nameArg, defaultEffect = "PASSIVE_STORE", sentEffect = "SERVER_DEFINED", draftsEffect = "SERVER_DEFINED", smtpRecordsSent = .false
  name = nameArg~string~strip
  if name = "" then raise syntax 88.900 array("IMAP_PROFILE_NAME_REQUIRED")
  defaultAppendEffect = self~canonicalEffect(defaultEffect)
  sentAppendEffect = self~canonicalEffect(sentEffect)
  draftsAppendEffect = self~canonicalEffect(draftsEffect)
  smtpAutoRecordsSent = smtpRecordsSent
::method canonicalEffect private
  use strict arg value
  v = value~string~strip~upper
  if v = "PASSIVE_STORE" | v = "POST" | v = "SUBMIT" | v = "SERVER_DEFINED" then return v
  raise syntax 88.900 array("IMAP_UNKNOWN_APPEND_EFFECT", value)
::method generic class
  return .ImapServerBehaviorProfile~new("GENERIC", "PASSIVE_STORE", "SERVER_DEFINED", "SERVER_DEFINED", .false)
::method citadel class
  /* Citadel is historically room/message-posting oriented.  APPEND to an
   * ordinary room is modelled as POST, while APPEND to Sent can intentionally
   * act as submission.  SMTP submission is recorded in Sent by the server, so
   * a client must not automatically append a second Sent copy. */
  return .ImapServerBehaviorProfile~new("CITADEL", "POST", "SUBMIT", "SERVER_DEFINED", .true)
::method effectForRole
  expose defaultAppendEffect sentAppendEffect draftsAppendEffect
  use strict arg roleArg
  role = .ImapMailboxRole~canonical(roleArg)
  if role = "SENT" then return sentAppendEffect
  if role = "DRAFTS" then return draftsAppendEffect
  return defaultAppendEffect
::method planAppend
  expose name
  use strict arg roleArg = "ORDINARY", intentArg = "STORE"
  role = .ImapMailboxRole~canonical(roleArg)
  intent = .ImapMutationIntent~canonical(intentArg)
  expected = .ImapMutationIntent~expectedEffect(intent)
  actual = self~effectForRole(role)
  if actual = "SERVER_DEFINED" then return .ImapMutationDecision~new(.false, .true, name, role, intent, actual, expected, "SERVER_DEFINED_SEMANTICS")
  if actual = expected then return .ImapMutationDecision~new(.true, .false, name, role, intent, actual, expected, "")
  return .ImapMutationDecision~new(.false, .true, name, role, intent, actual, expected, "SEMANTIC_MISMATCH")
::method shouldClientAppendSentAfterSmtp
  expose smtpAutoRecordsSent
  return \smtpAutoRecordsSent
