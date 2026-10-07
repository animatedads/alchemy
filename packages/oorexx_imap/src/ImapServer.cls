/* ooRexx IMAP server core v0.1-dev10
 *
 * Rexx-space endpoint architecture.  Authentication, mailbox authority,
 * mailbox state/storage, and transport are independent injected contracts.
 * The dev10 server intentionally exposes only the bounded metadata/session
 * command slice it actually implements; it does not claim IMAP4rev1 yet.
 */

::class ImapServerBuild public
::constant API "imap.server/0.1"
::constant RELEASE "0.1-dev10"

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
::method init
  expose snapshot mailbox readOnly
  use strict arg snapshotArg
  snapshot = snapshotArg
  mailbox = snapshot~mailbox
  readOnly = snapshot~readOnly

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
  use strict arg mailbox, expungeDeleted = .false
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

/* Dependency-free metadata provider for qualification.  It does not pretend to
 * implement message bytes, APPEND, FETCH or expunge. */
::class ImapMemoryMailboxProvider subclass ImapMailboxProvider public
::method init
  expose mailboxes nextUidValidity generation
  numeric digits 30
  mailboxes = .directory~new
  nextUidValidity = 10
  generation = 1
  self~addInitialMailbox("INBOX", "SIGNED_INBOX", .true, .true)
  self~addInitialMailbox("INBOX-UNSIGNED", "UNSIGNED_INBOX", .true, .true)
::method capabilities
  return .array~of("NAMESPACE")
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
  return .ImapServerMailboxSnapshot~new(row["name"], row["messages"], row["recent"], row["unseen"], row["first_unseen"], row["uid_validity"], row["uid_next"], row["modseq"], generation~string, readOnly)
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
   * documented dev10 gap rather than silently overclaimed behavior. */
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
  use strict arg mailbox, expungeDeleted = .false
  k = self~key(mailbox)
  if \mailboxes~hasIndex(k) then return .ImapServerResult~failure("NO_SUCH_MAILBOX")
  if expungeDeleted then return .ImapServerResult~failure("MESSAGE_STORE_NOT_IMPLEMENTED", "dev10 metadata provider cannot claim CLOSE expunge")
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
::method init
  expose lines closeConnection
  use strict arg linesArg = .nil, closeArg = .false
  if linesArg == .nil then lines = .array~new
  else lines = .ImapCollections~copyArray(linesArg)
  closeConnection = (closeArg == .true)
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
::method init
  expose authenticationProvider mailboxProvider authority state identity selectedState tlsActive maxLineBytes
  use strict arg authenticationProviderArg, mailboxProviderArg, authorityArg, tlsActiveArg = .false, maxLineBytesArg = 1048576
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
  state = "NOT_AUTHENTICATED"; identity = .nil; selectedState = .nil
::method setTlsActive
  expose tlsActive
  use strict arg value
  tlsActive = (value == .true)
  return tlsActive
::method capabilityArray
  expose mailboxProvider tlsActive
  /* Do not claim IMAP4rev1 until the mandatory message-data surface exists. */
  out = .array~of("X-OOREXX-SERVER-CORE")
  if \tlsActive then out~append("LOGINDISABLED")
  providerCaps = mailboxProvider~capabilities
  do c over providerCaps
    cap = c~string~strip~upper
    if cap = "NAMESPACE" then out~append(cap)
  end
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
  return .ImapServerResponse~new(lines, closeConnection)
::method providerFailure private
  use strict arg tag, result, operation
  code = result~code
  if code = "NO_SUCH_MAILBOX" then return self~response(tag, "NO", "[NONEXISTENT] " || operation || " failed")
  if code = "MAILBOX_EXISTS" then return self~response(tag, "NO", "[ALREADYEXISTS] " || operation || " failed")
  if code = "DELIVERY_MANAGED_MAILBOX" then return self~response(tag, "NO", "[NOPERM] delivery-managed mailbox")
  if code = "NAMESPACE_NOT_SUPPORTED" then return self~response(tag, "NO", "[CANNOT] NAMESPACE not supported")
  return self~response(tag, "NO", "[SERVERBUG] " || operation || " failed: " || code)
::method processLine
  expose state authenticationProvider mailboxProvider identity selectedState tlsActive maxLineBytes
  use strict arg line
  if state = "LOGOUT" then return .ImapServerResponse~new(.array~of("* BYE session is closed"), .true)
  parsed = .ImapServerParser~parseLine(line, maxLineBytes)
  if \parsed~ok then return self~response(parsed~tag, "BAD", "[PARSE] " || parsed~code)
  tag = parsed~tag; command = parsed~command; args = parsed~args

  if command = "CAPABILITY" then do
    if args~items <> 0 then return self~response(tag, "BAD", "CAPABILITY takes no arguments")
    return self~response(tag, "OK", "CAPABILITY completed", .array~of("* CAPABILITY " || self~capabilityText))
  end
  if command = "NOOP" then do
    if args~items <> 0 then return self~response(tag, "BAD", "NOOP takes no arguments")
    return self~response(tag, "OK", "NOOP completed")
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
    selectedState = .ImapServerSelection~new(snapshot); state = "SELECTED"
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
    r = mailboxProvider~close(selectedState~mailbox, expunge)
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

  if command = "APPEND" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "FETCH" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "STORE" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "SEARCH" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "COPY" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "MOVE" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "EXPUNGE" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "UID" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  if command = "IDLE" then return self~response(tag, "BAD", "[NOTIMPLEMENTED] dev10 message-data command not yet bound")
  return self~response(tag, "BAD", "unknown or unsupported command")
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
  expose session maxCommands maxLineBytes
  use strict arg sessionArg, maxCommandsArg = 100000, maxLineBytesArg = 1048576
  numeric digits 30
  session = sessionArg
  maxCommands = .ImapNumber~whole(maxCommandsArg,"IMAP_SERVER_MAX_COMMANDS",1)
  maxLineBytes = .ImapNumber~whole(maxLineBytesArg,"IMAP_SERVER_MAX_LINE",1024)
  if maxCommands < 1 then raise syntax 88.900 array("IMAP_SERVER_MAX_COMMANDS_INVALID", maxCommands)
  if maxLineBytes < 1024 then raise syntax 88.900 array("IMAP_SERVER_MAX_LINE_TOO_SMALL", maxLineBytes)
::method serve
  expose session maxCommands maxLineBytes
  use strict arg transport
  if transport == .nil then return .ImapServerResult~failure("IMAP_SERVER_TRANSPORT_REQUIRED")
  if \transport~hasMethod("READLINE") then return .ImapServerResult~failure("IMAP_SERVER_TRANSPORT_INVALID", "readLine")
  if \transport~hasMethod("WRITEALL") then return .ImapServerResult~failure("IMAP_SERVER_TRANSPORT_INVALID", "writeAll")
  if \transport~writeAll(session~greeting || '0d0a'x) then return .ImapServerResult~failure("IMAP_SERVER_GREETING_WRITE_FAILED")
  do commandCount = 1 to maxCommands
    line = transport~readLine(maxLineBytes)
    if line == .nil then return .ImapServerResult~success(commandCount - 1, "CLIENT_CLOSED")
    response = session~processLine(line)
    if \transport~writeAll(response~wire) then return .ImapServerResult~failure("IMAP_SERVER_RESPONSE_WRITE_FAILED", commandCount~string)
    if response~closeConnection then return .ImapServerResult~success(commandCount, "LOGOUT")
  end
  return .ImapServerResult~failure("IMAP_SERVER_COMMAND_LIMIT", maxCommands~string)

::requires "ImapCore.cls"
