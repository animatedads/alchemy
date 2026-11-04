/* ooRexx IMAP/IMAPS v0.1-dev8 session engine.
 * Sequence numbers are confined to live protocol operations. Durable callers
 * should use UID/UIDVALIDITY only.
 */

::class ImapCommandResult public
::attribute tag get
::attribute status get
::attribute text get
::attribute untagged get
::attribute continuations get
::attribute ok get
::method init
  expose tag status text untagged continuations ok
  use strict arg tagArg, statusArg = "", textArg = "", untaggedArg = .nil, continuationsArg = .nil
  tag = tagArg~string; status = statusArg~string~upper; text = textArg~string
  if untaggedArg == .nil then untagged = .array~new; else untagged = untaggedArg
  if continuationsArg == .nil then continuations = .array~new; else continuations = continuationsArg
  ok = status = "OK"


::class ImapAppendResult public
::attribute commandResult get
::attribute uidValidity get
::attribute uidSet get
::attribute hasAppendUid get
::method init
  expose commandResult uidValidity uidSet hasAppendUid
  use strict arg commandResultArg, uidValidityArg = "", uidSetArg = .nil
  commandResult = commandResultArg
  uidValidity = uidValidityArg~string
  uidSet = uidSetArg
  hasAppendUid = (uidValidity <> "" & uidSet \== .nil)
::method ok
  expose commandResult
  return commandResult~ok

::class ImapStringLiteralSource public
::attribute length get
::method init
  expose bytes offset length
  use strict arg bytesArg
  bytes = bytesArg; offset = 1; length = bytes~length
::method read
  expose bytes offset length
  use strict arg maximum = 16384
  if offset > length then return ""
  take = maximum
  remaining = length - offset + 1
  if take > remaining then take = remaining
  chunk = bytes~substr(offset, take)
  offset += take
  return chunk

::class ImapSession public
::attribute capabilities get
::attribute greeting get
::attribute selectedState get
::attribute state get
::attribute eventSink get
::attribute lastEventError get
::method init
  expose transport reader config tagCounter capabilities greeting selectedState state eventSink lastEventError
  use strict arg transportArg, readerConfig = .nil, eventSinkArg = .nil
  transport = transportArg
  if readerConfig == .nil then config = .ImapReaderConfig~new; else config = readerConfig
  reader = .ImapWireReader~new(transport, config)
  tagCounter = 0; capabilities = .ImapCapabilities~new; greeting = .nil; selectedState = .nil; state = "CONNECTED"
  eventSink = .nil; lastEventError = ""
  if eventSinkArg \== .nil then self~setEventSink(eventSinkArg)
::method setEventSink public
  expose eventSink lastEventError
  use strict arg sink
  if sink \== .nil then if \sink~hasMethod("EMIT") then raise syntax 88.900 array("IMAP_EVENT_SINK_INVALID")
  eventSink = sink
  lastEventError = ""
  return self
::method emitDiagnostic private
  expose eventSink lastEventError
  use strict arg point, level = "DEBUG", payload = .nil
  if eventSink == .nil then return .false
  signal on syntax name diagnosticFailure
  emitted = eventSink~emit(self, point, level, payload)
  signal off syntax
  return emitted
diagnosticFailure:
  signal off syntax
  lastEventError = condition("D")
  if lastEventError = "" then do
    a = condition("A")
    if a \== .nil then if a~items > 0 then lastEventError = a[1]~string
  end
  if lastEventError = "" then lastEventError = "IMAP_DIAGNOSTIC_SINK_FAILURE"
  return .false
::method safeCommandName private
  use strict arg commandText
  text = commandText~strip
  if text = "" then return ""
  first = text~word(1)~upper
  if first = "UID" & text~words >= 2 then return "UID " || text~word(2)~upper
  return first
::method commandPayload private
  use strict arg commandName, tag = "", status = "", untaggedCount = .nil, continuationCount = .nil
  d = .directory~new
  d["command"] = commandName
  if tag <> "" then d["tag"] = tag
  if status <> "" then d["status"] = status
  if untaggedCount \== .nil then d["untagged_count"] = untaggedCount
  if continuationCount \== .nil then d["continuation_count"] = continuationCount
  return d
::method mailboxPayload private
  use strict arg s
  d = .directory~new
  d["exists"] = s~exists
  d["recent"] = s~recent
  d["unseen_count"] = s~unseenCount
  d["first_unseen_sequence"] = s~firstUnseenSequence
  d["uid_validity"] = s~uidValidity
  d["uid_next"] = s~uidNext
  d["highest_modseq"] = s~highestModSeq
  d["read_only"] = s~readOnly
  return d
::method acceptGreeting
  expose reader greeting state capabilities
  record = reader~nextRecord
  greeting = record
  if record~classification <> "UNTAGGED" then raise syntax 88.900 array("IMAP_BAD_GREETING", record~firstLine)
  atom = record~responseAtom
  if atom = "BYE" then do; state = "LOGOUT"; raise syntax 88.900 array("IMAP_SERVER_BYE", record~firstLine); end
  if atom <> "OK" & atom <> "PREAUTH" then raise syntax 88.900 array("IMAP_BAD_GREETING", record~firstLine)
  self~captureBracketCapabilities(record~firstLine)
  if atom = "PREAUTH" then state = "AUTHENTICATED"
  d = .directory~new; d["response"] = atom; d["preauthenticated"] = (atom = "PREAUTH")
  ignore = self~emitDiagnostic("GREETING", "INFO", d)
  return record
::method nextTag private
  expose tagCounter
  tagCounter += 1
  n = tagCounter~string
  do while n~length < 6; n = "0" || n; end
  return "A" || n
::method writeLine private
  expose transport
  use strict arg line
  return transport~writeAll(line || "0d0a"x)
::method command
  use strict arg commandText, sinkFactory = .nil
  return self~execute(commandText, sinkFactory)
::method execute
  expose transport reader config
  use strict arg commandText, sinkFactory = .nil
  tag = self~nextTag
  commandName = self~safeCommandName(commandText)
  ignore = self~emitDiagnostic("COMMAND_BEGIN", "TRACE", self~commandPayload(commandName, tag))
  if \self~writeLine(tag || " " || commandText) then do
    ignore = self~emitDiagnostic("COMMAND_WRITE_FAILED", "ERROR", self~commandPayload(commandName, tag, "WRITE_FAILED"))
    raise syntax 88.900 array("IMAP_WRITE_FAILED", tag)
  end
  cmdResult = self~collect(tag, sinkFactory)
  level = "DEBUG"; if \cmdResult~ok then level = "WARN"
  ignore = self~emitDiagnostic("COMMAND_COMPLETE", level, self~commandPayload(commandName, tag, cmdResult~status, cmdResult~untagged~items, cmdResult~continuations~items))
  return cmdResult
::method collect private
  expose reader config
  use strict arg tag, sinkFactory = .nil, initialUntagged = .nil, initialContinuations = .nil
  if initialUntagged == .nil then untagged = .array~new; else untagged = initialUntagged
  if initialContinuations == .nil then continuations = .array~new; else continuations = initialContinuations
  do count = 1 to config~maxResponseRecords
    record = reader~nextRecord(sinkFactory)
    if record~classification = "UNTAGGED" then do; untagged~append(record); iterate; end
    if record~classification = "CONTINUATION" then do; continuations~append(record); iterate; end
    if record~tag <> tag then raise syntax 88.900 array("IMAP_UNEXPECTED_TAG", tag, record~tag, record~firstLine)
    status = record~completionStatus
    text = record~firstLine~subword(3)
    return .ImapCommandResult~new(tag, status, text, untagged, continuations)
  end
  raise syntax 88.900 array("IMAP_TOO_MANY_RESPONSE_RECORDS", tag, config~maxResponseRecords)
::method executeLiteral
  expose transport reader config capabilities
  use strict arg commandPrefix, source, literalLengthArg, commandSuffix = "", sinkFactory = .nil, allowNonSynchronizing = .true
  literalLength = literalLengthArg + 0
  if literalLength < 0 then raise syntax 88.900 array("negative literal length")
  tag = self~nextTag
  commandName = self~safeCommandName(commandPrefix)
  nonsync = allowNonSynchronizing & capabilities~has("LITERAL+")
  ld = self~commandPayload(commandName, tag); ld["literal_length"] = literalLength; ld["non_synchronizing"] = nonsync
  ignore = self~emitDiagnostic("LITERAL_BEGIN", "DEBUG", ld)
  marker = "{" || literalLength
  if nonsync then marker = marker || "+"
  marker = marker || "}"
  if \self~writeLine(tag || " " || commandPrefix || " " || marker) then raise syntax 88.900 array("IMAP_WRITE_FAILED", tag)
  preUntagged = .array~new; preContinuations = .array~new
  if \nonsync then do count = 1 to config~maxResponseRecords
    r = reader~nextRecord(sinkFactory)
    if r~classification = "UNTAGGED" then do; preUntagged~append(r); iterate; end
    if r~classification = "CONTINUATION" then do; preContinuations~append(r); leave; end
    if r~classification = "TAGGED" then do
      if r~tag <> tag then raise syntax 88.900 array("IMAP_UNEXPECTED_TAG", tag, r~tag)
      return .ImapCommandResult~new(tag, r~completionStatus, r~firstLine~subword(3), preUntagged, preContinuations)
    end
  end
  sent = 0
  do while sent < literalLength
    ask = literalLength - sent
    if ask > 16384 then ask = 16384
    chunk = source~read(ask)
    if chunk == .nil | chunk = "" then raise syntax 88.900 array("IMAP_LITERAL_SOURCE_SHORT", literalLength, sent)
    if chunk~length > ask then raise syntax 88.900 array("IMAP_LITERAL_SOURCE_OVERRUN", chunk~length, ask)
    if \transport~writeAll(chunk) then raise syntax 88.900 array("IMAP_WRITE_FAILED_IN_LITERAL", tag, sent)
    sent += chunk~length
  end
  if \transport~writeAll(commandSuffix || "0d0a"x) then raise syntax 88.900 array("IMAP_WRITE_FAILED_AFTER_LITERAL", tag)
  cmdResult = self~collect(tag, sinkFactory, preUntagged, preContinuations)
  ld = self~commandPayload(commandName, tag, cmdResult~status, cmdResult~untagged~items, cmdResult~continuations~items); ld["literal_length"] = literalLength
  level = "DEBUG"; if \cmdResult~ok then level = "WARN"
  ignore = self~emitDiagnostic("LITERAL_COMPLETE", level, ld)
  return cmdResult
::method capability
  expose capabilities
  cmdResult = self~execute("CAPABILITY")
  if cmdResult~ok then do
    fresh = .ImapCapabilities~new
    do record over cmdResult~untagged
      if record~firstLine~word(1) = "*" & record~firstLine~word(2)~upper = "CAPABILITY" then do i = 3 to record~firstLine~words
        fresh~add(record~firstLine~word(i))
      end
    end
    capabilities = fresh
    d = .directory~new; d["count"] = capabilities~items
    ignore = self~emitDiagnostic("CAPABILITIES", "INFO", d)
  end
  return cmdResult
::method bootstrapSecurity
  expose transport
  use strict arg securityArg = ""
  if securityArg~strip = "" then do
    if transport~hasMethod("SECURITY") then securityArg = transport~security
    else securityArg = "IMPLICIT_TLS"
  end
  security = .ImapTransportSecurity~canonical(securityArg)
  self~acceptGreeting
  if security = "IMPLICIT_TLS" then do
    if transport~hasMethod("ENCRYPTED") then if \transport~encrypted then -
      raise syntax 88.900 array("IMAP_SECURITY_POLICY_MISMATCH", security, "transport is not encrypted")
    cmdResult = self~capability
    if cmdResult~ok then do
      d = .directory~new; d["security"] = security; d["encrypted"] = .true
      if transport~hasMethod("TLSPROTOCOL") then d["tls_protocol"] = transport~tlsProtocol
      if transport~hasMethod("TLSCIPHER") then d["tls_cipher"] = transport~tlsCipher
      ignore = self~emitDiagnostic("SECURITY_READY", "INFO", d)
    end
    return cmdResult
  end
  if security = "STARTTLS_REQUIRED" then do
    if transport~hasMethod("ENCRYPTED") then if transport~encrypted then -
      raise syntax 88.900 array("IMAP_SECURITY_POLICY_MISMATCH", security, "transport was encrypted before STARTTLS")
    if self~capabilities~items = 0 then do
      before = self~capability
      if \before~ok then return before
    end
    if \self~capabilities~has("STARTTLS") then raise syntax 88.900 array("IMAP_CAPABILITY_REQUIRED", "STARTTLS")
    upgraded = self~startTls
    if \upgraded~ok then return upgraded
    cmdResult = self~capability
    if cmdResult~ok then do
      d = .directory~new; d["security"] = security; d["encrypted"] = .true
      if transport~hasMethod("TLSPROTOCOL") then d["tls_protocol"] = transport~tlsProtocol
      if transport~hasMethod("TLSCIPHER") then d["tls_cipher"] = transport~tlsCipher
      ignore = self~emitDiagnostic("SECURITY_READY", "INFO", d)
    end
    return cmdResult
  end
  /* PLAINTEXT describes the transport, not permission to send a password.
   * login() still refuses cleartext credentials. */
  cmdResult = self~capability
  if cmdResult~ok then do
    d = .directory~new; d["security"] = security; d["encrypted"] = .false
    ignore = self~emitDiagnostic("SECURITY_READY", "WARN", d)
  end
  return cmdResult
::method startTls
  expose transport reader capabilities
  if capabilities~items > 0 & \capabilities~has("STARTTLS") then raise syntax 88.900 array("IMAP_CAPABILITY_REQUIRED", "STARTTLS")
  if \transport~hasMethod("STARTTLS") then raise syntax 88.900 array("IMAP_TRANSPORT_STARTTLS_UNAVAILABLE")
  cmdResult = self~execute("STARTTLS")
  if \cmdResult~ok then return cmdResult
  if reader~bufferedBytes <> 0 then raise syntax 88.900 array("IMAP_STARTTLS_PLAINTEXT_BUFFER_NOT_EMPTY", reader~bufferedBytes)
  if \transport~startTls then raise syntax 88.900 array("IMAP_TLS_HANDSHAKE_FAILED", transport~lastError)
  capabilities = .ImapCapabilities~new
  return cmdResult
::method login
  expose transport state capabilities
  use strict arg user, password
  if capabilities~has("LOGINDISABLED") then raise syntax 88.900 array("IMAP_LOGIN_DISABLED")
  if transport~hasMethod("ENCRYPTED") then if \transport~encrypted then raise syntax 88.900 array("IMAP_CLEARTEXT_CREDENTIAL_FORBIDDEN")
  /* Deliberately do not retain the credential or return the command text. */
  cmdResult = self~execute("LOGIN " || .ImapCodec~quoteString(user) || " " || .ImapCodec~quoteString(password))
  if cmdResult~ok then state = "AUTHENTICATED"
  d = .directory~new; d["mechanism"] = "LOGIN"; d["success"] = cmdResult~ok
  level = "INFO"; if \cmdResult~ok then level = "WARN"
  ignore = self~emitDiagnostic("AUTHENTICATION", level, d)
  return cmdResult
::method logout
  expose state
  cmdResult = self~execute("LOGOUT")
  state = "LOGOUT"
  return cmdResult
::method noop
  return self~execute("NOOP")
::method examine
  expose selectedState
  use strict arg mailbox, parameters = ""
  command = "EXAMINE " || .ImapCodec~quoteMailbox(mailbox)
  if parameters~strip <> "" then command = command || " " || parameters
  cmdResult = self~execute(command)
  if cmdResult~ok then do
    selectedState = self~parseMailboxState(mailbox, cmdResult, .true)
    ignore = self~emitDiagnostic("MAILBOX_STATE", "INFO", self~mailboxPayload(selectedState))
  end
  return cmdResult
::method select
  expose selectedState
  use strict arg mailbox, parameters = ""
  command = "SELECT " || .ImapCodec~quoteMailbox(mailbox)
  if parameters~strip <> "" then command = command || " " || parameters
  cmdResult = self~execute(command)
  if cmdResult~ok then do
    selectedState = self~parseMailboxState(mailbox, cmdResult, .false)
    ignore = self~emitDiagnostic("MAILBOX_STATE", "INFO", self~mailboxPayload(selectedState))
  end
  return cmdResult
::method status
  use strict arg mailbox, items = "MESSAGES UNSEEN UIDNEXT UIDVALIDITY HIGHESTMODSEQ"
  cmdResult = self~execute("STATUS " || .ImapCodec~quoteMailbox(mailbox) || " (" || items || ")")
  if \cmdResult~ok then return .nil
  s = .ImapMailboxState~new; s~mailbox = mailbox
  do record over cmdResult~untagged
    line = record~firstLine
    if line~word(1) <> "*" | line~word(2)~upper <> "STATUS" then iterate
    body = .ImapCodec~betweenParens(line)
    self~applyStatusPairs(s, body)
  end
  ignore = self~emitDiagnostic("MAILBOX_STATUS", "INFO", self~mailboxPayload(s))
  return s
::method createMailbox
  use strict arg mailbox
  return self~execute("CREATE " || .ImapCodec~quoteMailbox(mailbox))
::method deleteMailbox
  use strict arg mailbox
  return self~execute("DELETE " || .ImapCodec~quoteMailbox(mailbox))
::method renameMailbox
  use strict arg oldMailbox, newMailbox
  return self~execute("RENAME " || .ImapCodec~quoteMailbox(oldMailbox) || " " || .ImapCodec~quoteMailbox(newMailbox))
::method subscribeMailbox
  use strict arg mailbox
  return self~execute("SUBSCRIBE " || .ImapCodec~quoteMailbox(mailbox))
::method unsubscribeMailbox
  use strict arg mailbox
  return self~execute("UNSUBSCRIBE " || .ImapCodec~quoteMailbox(mailbox))
::method closeMailbox
  expose selectedState
  cmdResult = self~execute("CLOSE")
  if cmdResult~ok then selectedState = .nil
  return cmdResult
::method uidFetchPeek
  use strict arg uidSet, items, sinkFactory = .nil
  wire = uidSet
  if uidSet~hasMethod("WIRE") then wire = uidSet~wire
  upper = items~upper
  /* Background/read-only typed surface refuses known seen-mutating fetch forms. */
  if upper~pos("BODY[") > 0 & upper~pos("BODY.PEEK[") = 0 then raise syntax 88.900 array("IMAP_PEEK_REQUIRED", items)
  if upper~wordPos("RFC822") > 0 | upper~wordPos("RFC822.TEXT") > 0 then raise syntax 88.900 array("IMAP_PEEK_REQUIRED", items)
  return self~execute("UID FETCH " || wire || " (" || items || ")", sinkFactory)
::method uidFetchBodyPeek
  use strict arg uidSet, section = "", partial = "", sinkFactory = .nil
  wire = uidSet
  if uidSet~hasMethod("WIRE") then wire = uidSet~wire
  item = "BODY.PEEK[" || section || "]"
  if partial <> "" then item = item || "<" || partial || ">"
  return self~execute("UID FETCH " || wire || " (UID " || item || ")", sinkFactory)
::method uidStore
  use strict arg uidSet, storeOperation, flags
  wire = uidSet; if uidSet~hasMethod("WIRE") then wire = uidSet~wire
  return self~execute("UID STORE " || wire || " " || storeOperation || " (" || flags || ")")
::method uidCopy
  use strict arg uidSet, mailbox
  wire = uidSet; if uidSet~hasMethod("WIRE") then wire = uidSet~wire
  return self~execute("UID COPY " || wire || " " || .ImapCodec~quoteMailbox(mailbox))
::method uidMove
  expose capabilities
  use strict arg uidSet, mailbox
  if \capabilities~has("MOVE") then raise syntax 88.900 array("IMAP_CAPABILITY_REQUIRED", "MOVE")
  wire = uidSet; if uidSet~hasMethod("WIRE") then wire = uidSet~wire
  return self~execute("UID MOVE " || wire || " " || .ImapCodec~quoteMailbox(mailbox))
::method uidMarkDeleted
  use strict arg uidSet
  return self~uidStore(uidSet, "+FLAGS.SILENT", "\Deleted")
::method uidUnmarkDeleted
  use strict arg uidSet
  return self~uidStore(uidSet, "-FLAGS.SILENT", "\Deleted")
::method uidExpunge
  expose capabilities
  use strict arg uidSet
  if \capabilities~has("UIDPLUS") then raise syntax 88.900 array("IMAP_CAPABILITY_REQUIRED", "UIDPLUS")
  wire = uidSet; if uidSet~hasMethod("WIRE") then wire = uidSet~wire
  return self~execute("UID EXPUNGE " || wire)
::method appendBytes
  use strict arg mailbox, bytes, flags = "", internalDate = "", sinkFactory = .nil
  prefix = "APPEND " || .ImapCodec~quoteMailbox(mailbox)
  if flags <> "" then prefix = prefix || " (" || flags || ")"
  if internalDate <> "" then prefix = prefix || " " || .ImapCodec~quoteString(internalDate)
  source = .ImapStringLiteralSource~new(bytes)
  return self~executeLiteral(prefix, source, source~length, "", sinkFactory)
::method appendSource
  use strict arg mailbox, source, length, flags = "", internalDate = "", sinkFactory = .nil
  prefix = "APPEND " || .ImapCodec~quoteMailbox(mailbox)
  if flags <> "" then prefix = prefix || " (" || flags || ")"
  if internalDate <> "" then prefix = prefix || " " || .ImapCodec~quoteString(internalDate)
  return self~executeLiteral(prefix, source, length, "", sinkFactory)
::method appendBytesResult
  use strict arg mailbox, bytes, flags = "", internalDate = "", sinkFactory = .nil
  return self~parseAppendResult(self~appendBytes(mailbox, bytes, flags, internalDate, sinkFactory))
::method appendSourceResult
  use strict arg mailbox, source, length, flags = "", internalDate = "", sinkFactory = .nil
  return self~parseAppendResult(self~appendSource(mailbox, source, length, flags, internalDate, sinkFactory))
::method appendBytesWithIntent
  use strict arg mailbox, bytes, profile, role = "ORDINARY", intent = "STORE", flags = "", internalDate = "", sinkFactory = .nil
  decision = profile~planAppend(role, intent)
  self~emitAppendDecision(decision)
  self~requireAppendDecision(decision)
  return self~appendBytes(mailbox, bytes, flags, internalDate, sinkFactory)
::method appendSourceWithIntent
  use strict arg mailbox, source, length, profile, role = "ORDINARY", intent = "STORE", flags = "", internalDate = "", sinkFactory = .nil
  decision = profile~planAppend(role, intent)
  self~emitAppendDecision(decision)
  self~requireAppendDecision(decision)
  return self~appendSource(mailbox, source, length, flags, internalDate, sinkFactory)
::method appendBytesWithIntentResult
  use strict arg mailbox, bytes, profile, role = "ORDINARY", intent = "STORE", flags = "", internalDate = "", sinkFactory = .nil
  decision = profile~planAppend(role, intent)
  self~emitAppendDecision(decision)
  self~requireAppendDecision(decision)
  return self~parseAppendResult(self~appendBytes(mailbox, bytes, flags, internalDate, sinkFactory))
::method appendSourceWithIntentResult
  use strict arg mailbox, source, length, profile, role = "ORDINARY", intent = "STORE", flags = "", internalDate = "", sinkFactory = .nil
  decision = profile~planAppend(role, intent)
  self~emitAppendDecision(decision)
  self~requireAppendDecision(decision)
  return self~parseAppendResult(self~appendSource(mailbox, source, length, flags, internalDate, sinkFactory))
::method parseAppendResult public
  use strict arg cmdResult
  uidValidity = ""; uidSet = .nil
  if cmdResult~ok then do
    text = cmdResult~text
    upper = text~upper
    p = upper~pos("[APPENDUID ")
    if p > 0 then do
      rest = text~substr(p + 11)
      e = rest~pos("]")
      if e > 0 then rest = rest~left(e - 1)
      if rest~words >= 2 then do
        uidValidity = rest~word(1)
        token = rest~word(2)
        if datatype(uidValidity, "W") then uidSet = .ImapUidSet~parse(token)
        else uidValidity = ""
      end
    end
  end
  return .ImapAppendResult~new(cmdResult, uidValidity, uidSet)
::method requireAppendDecision private
  use strict arg decision
  if decision~allowed then return .true
  raise syntax 88.900 array("IMAP_APPEND_SEMANTICS_NOT_AUTHORIZED", decision~profileName, decision~mailboxRole, decision~intent, decision~actualEffect, decision~expectedEffect, decision~reason)
::method emitAppendDecision private
  use strict arg decision
  d = .directory~new
  d["profile"] = decision~profileName
  d["mailbox_role"] = decision~mailboxRole
  d["intent"] = decision~intent
  d["effect"] = decision~actualEffect
  d["expected_effect"] = decision~expectedEffect
  d["allowed"] = decision~allowed
  d["requires_explicit_policy"] = decision~requiresExplicitPolicy
  if decision~reason <> "" then d["reason"] = decision~reason
  level = "INFO"; if \decision~allowed then level = "WARN"
  ignore = self~emitDiagnostic("MUTATION_PLAN", level, d)
  return .true
::method uidSearch
  expose capabilities
  use strict arg criteria, returnItems = ""
  if returnItems <> "" & capabilities~has("ESEARCH") then command = "UID SEARCH RETURN (" || returnItems || ") " || criteria
  else command = "UID SEARCH " || criteria
  cmdResult = self~execute(command)
  search = self~parseSearchResult(cmdResult)
  d = .directory~new; d["complete"] = search~complete; d["count"] = search~count; d["minimum"] = search~minimum; d["maximum"] = search~maximum
  if search~all \== .nil then d["range_count"] = search~all~rangeCount
  ignore = self~emitDiagnostic("SEARCH_RESULT", "DEBUG", d)
  return .array~of(cmdResult, search)
::method parseSearchResult private
  use strict arg cmdResult
  out = .ImapSearchResult~new
  do record over cmdResult~untagged
    line = record~firstLine
    if line~word(1) <> "*" then iterate
    atom = line~word(2)~upper
    if atom = "SEARCH" then do
      set = .ImapUidSet~new
      do i = 3 to line~words
        token = line~word(i)
        if datatype(token, "W") then set~addUid(token)
      end
      out~all = set; out~count = set~count; out~complete = .true
    end
    else if atom = "ESEARCH" then self~parseEsearchLine(out, line)
  end
  return out
::method parseEsearchLine private
  use strict arg out, line
  /* Sufficiently generic for COUNT/MIN/MAX/ALL; correlator text is skipped. */
  upper = line~upper
  if upper~pos(" UID ") > 0 then out~uidMode = .true
  words = line~makeArray(" ")
  do i = 1 to words~items
    key = words[i]~strip~upper
    if key = "COUNT" & i < words~items then out~count = words[i + 1]
    else if key = "MIN" & i < words~items then out~minimum = words[i + 1]
    else if key = "MAX" & i < words~items then out~maximum = words[i + 1]
    else if key = "ALL" & i < words~items then do
      token = words[i + 1]~strip
      do while token~right(1) = ")" | token~right(1) = "]"; token = token~left(token~length - 1); end
      out~all = .ImapUidSet~parse(token)
    end
  end
  out~complete = .true
::method parseMailboxState private
  use strict arg mailbox, cmdResult, readOnlyDefault
  s = .ImapMailboxState~new; s~mailbox = mailbox; s~readOnly = readOnlyDefault
  do record over cmdResult~untagged
    line = record~firstLine
    if line~word(1) <> "*" then iterate
    if datatype(line~word(2), "W") then do
      n = line~word(2) + 0; atom = line~word(3)~upper
      if atom = "EXISTS" then s~exists = n
      else if atom = "RECENT" then s~recent = n
    end
    if line~word(2)~upper = "FLAGS" then s~flags = .ImapCodec~betweenParens(line)
    v = .ImapCodec~statusCodeValue(line, "UIDVALIDITY"); if v <> "" then s~uidValidity = v
    v = .ImapCodec~statusCodeValue(line, "UIDNEXT"); if v <> "" then s~uidNext = v
    v = .ImapCodec~statusCodeValue(line, "UNSEEN"); if v <> "" then s~firstUnseenSequence = v
    v = .ImapCodec~statusCodeValue(line, "HIGHESTMODSEQ"); if v <> "" then s~highestModSeq = v
    if line~upper~pos("[READ-ONLY]") > 0 then s~readOnly = .true
    if line~upper~pos("[READ-WRITE]") > 0 then s~readOnly = .false
    if line~upper~pos("[PERMANENTFLAGS") > 0 then s~permanentFlags = .ImapCodec~betweenParens(line)
  end
  return s
::method applyStatusPairs private
  use strict arg s, body
  parts = body~makeArray(" ")
  i = 1
  do while i <= parts~items
    key = parts[i]~strip~upper
    if i = parts~items then leave
    value = parts[i + 1]~strip
    if key = "MESSAGES" then s~exists = value
    else if key = "RECENT" then s~recent = value
    else if key = "UNSEEN" then s~unseenCount = value
    else if key = "UIDNEXT" then s~uidNext = value
    else if key = "UIDVALIDITY" then s~uidValidity = value
    else if key = "HIGHESTMODSEQ" then s~highestModSeq = value
    i += 2
  end
::method captureBracketCapabilities private
  expose capabilities
  use strict arg line
  upper = line~upper
  p = upper~pos("[CAPABILITY ")
  if p = 0 then return
  rest = line~substr(p + 12)
  e = rest~pos("]")
  if e > 0 then rest = rest~left(e - 1)
  capabilities~addWords(rest)

::requires "ImapCore.cls"
::requires "ImapSemantics.cls"
