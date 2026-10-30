/* ooRexx IMAP/IMAPS v0.1-dev8 core
 *
 * Protocol objects deliberately avoid any assumption that a mailbox, UID set,
 * response literal, or SEARCH result is small.
 */

::class ImapBuild public
::constant VERSION "0.1-dev8"
::constant API "imap/0.1"
::constant CORE_API "imap.core/0.1"


::class ImapTransportSecurity public
::constant PLAINTEXT "PLAINTEXT"
::constant STARTTLS_REQUIRED "STARTTLS_REQUIRED"
::constant IMPLICIT_TLS "IMPLICIT_TLS"
::method canonical class
  use strict arg valueArg
  value = valueArg~string~strip~upper
  if value = "" then return "IMPLICIT_TLS"
  if value = "PLAINTEXT" | value = "PLAIN" then return "PLAINTEXT"
  if value = "STARTTLS_REQUIRED" | value = "STARTTLS" | value = "IMAP_STARTTLS" then return "STARTTLS_REQUIRED"
  if value = "IMPLICIT_TLS" | value = "IMAPS" | value = "IMAP_SSL" | value = "IMAP_OVER_SSL" then return "IMPLICIT_TLS"
  if value = "IMAP" | value = "TLS" | value = "SSL" | value = "SSL_TLS" | value = "SSL/TLS" | value = "SECURE" then -
    raise syntax 88.900 array("IMAP_AMBIGUOUS_SECURITY_LABEL", valueArg, "use IMPLICIT_TLS or STARTTLS_REQUIRED")
  raise syntax 88.900 array("IMAP_SECURITY_MODE_INVALID", valueArg)
::method defaultPort class
  use strict arg valueArg
  value = self~canonical(valueArg)
  if value = "IMPLICIT_TLS" then return 993
  return 143
::method isEncryptedFromConnect class
  use strict arg valueArg
  return self~canonical(valueArg) = "IMPLICIT_TLS"
::method needsStartTls class
  use strict arg valueArg
  return self~canonical(valueArg) = "STARTTLS_REQUIRED"

::class ImapEndpoint public
::attribute host
::attribute port
::attribute security
::method init
  expose host port security
  host = ""; port = 0; security = "IMPLICIT_TLS"
::method validate
  expose host port security
  if host~strip = "" then raise syntax 88.900 array("IMAP host required")
  security = .ImapTransportSecurity~canonical(security)
  if port = 0 then port = .ImapTransportSecurity~defaultPort(security)
  if port < 1 | port > 65535 then raise syntax 88.900 array("IMAP port invalid", port)
  return self
::method encryptedFromConnect
  expose security
  return .ImapTransportSecurity~isEncryptedFromConnect(security)
::method requiresStartTls
  expose security
  return .ImapTransportSecurity~needsStartTls(security)

::class ImapReaderConfig public
::attribute readChunkSize
::attribute maxLineBytes
::attribute maxInlineLiteralBytes
::attribute maxLiteralBytes
::attribute maxResponseRecords
::method init
  expose readChunkSize maxLineBytes maxInlineLiteralBytes maxLiteralBytes maxResponseRecords
  readChunkSize = 16384
  maxLineBytes = 8388608
  maxInlineLiteralBytes = 1048576
  maxLiteralBytes = 2147483648
  maxResponseRecords = 100000
::method validate
  expose readChunkSize maxLineBytes maxInlineLiteralBytes maxLiteralBytes maxResponseRecords
  if readChunkSize < 256 then raise syntax 88.900 array("IMAP readChunkSize too small", readChunkSize)
  if maxLineBytes < 1024 then raise syntax 88.900 array("IMAP maxLineBytes too small", maxLineBytes)
  if maxInlineLiteralBytes < 0 then raise syntax 88.900 array("IMAP maxInlineLiteralBytes invalid", maxInlineLiteralBytes)
  if maxLiteralBytes < 1 | maxLiteralBytes < maxInlineLiteralBytes then raise syntax 88.900 array("IMAP maxLiteralBytes invalid", maxLiteralBytes)
  if maxResponseRecords < 1 then raise syntax 88.900 array("IMAP maxResponseRecords invalid", maxResponseRecords)
  return self

::class ImapInlineLiteralSink public
::attribute bytes get
::attribute length get
::method init
  expose bytes length
  bytes = ""; length = 0
::method write
  expose bytes length
  use strict arg chunk
  bytes = bytes || chunk
  length += chunk~length
  return chunk~length
::method finish
  return self
::method kind
  return "INLINE"
::method reference
  return ""

::class ImapDiscardLiteralSink public
::attribute length get
::method init
  expose length
  length = 0
::method write
  expose length
  use strict arg chunk
  length += chunk~length
  return chunk~length
::method finish
  return self
::method kind
  return "DISCARDED"
::method bytes
  return ""
::method reference
  return ""

::class ImapLiteralSegment public
::attribute announcedLength get
::attribute storedLength get
::attribute kind get
::attribute bytes get
::attribute reference get
::method init
  expose announcedLength storedLength kind bytes reference
  use strict arg announcedLengthArg, sink
  announcedLength = announcedLengthArg + 0
  storedLength = sink~length + 0
  kind = sink~kind~string
  bytes = sink~bytes
  reference = sink~reference

::class ImapResponseRecord public
::attribute classification get
::attribute tag get
::attribute firstLine get
::attribute lineSegments get
::attribute literalSegments get
::method init
  expose classification tag firstLine lineSegments literalSegments
  use strict arg firstLineArg
  firstLine = firstLineArg
  lineSegments = .array~new
  literalSegments = .array~new
  lineSegments~append(firstLineArg)
  first = firstLineArg~word(1)
  if first = "*" then do; classification = "UNTAGGED"; tag = "*"; end
  else if first = "+" then do; classification = "CONTINUATION"; tag = "+"; end
  else do; classification = "TAGGED"; tag = first; end
::method addLine
  expose lineSegments
  use strict arg line
  lineSegments~append(line)
  return self
::method addLiteral
  expose literalSegments
  use strict arg literal
  literalSegments~append(literal)
  return self
::method literalCount
  expose literalSegments
  return literalSegments~items
::method lineCount
  expose lineSegments
  return lineSegments~items
::method completionStatus
  expose classification firstLine
  if classification <> "TAGGED" then return ""
  return firstLine~word(2)~upper
::method responseAtom
  expose firstLine classification
  if classification <> "UNTAGGED" then return ""
  return firstLine~word(2)~upper
::method rendered
  expose lineSegments literalSegments
  out = ""
  lit = 1
  do i = 1 to lineSegments~items
    if i > 1 then out = out || "<literal:" || literalSegments[lit]~announcedLength || ">"
    out = out || lineSegments[i]
    if i > 1 then lit += 1
  end
  return out

::class ImapWireReader public
::attribute bytesRead get
::attribute recordsRead get
::method init
  expose transport config buffer bytesRead recordsRead
  use strict arg transportArg, configArg = .nil
  transport = transportArg
  if configArg == .nil then config = .ImapReaderConfig~new
  else config = configArg
  config~validate
  buffer = ""; bytesRead = 0; recordsRead = 0
::method bufferedBytes
  expose buffer
  return buffer~length
::method readLine
  expose transport config buffer bytesRead
  crlf = "0d0a"x
  do forever
    p = buffer~pos(crlf)
    if p > 0 then do
      if p - 1 > config~maxLineBytes then raise syntax 88.900 array("IMAP_LINE_TOO_LARGE", p - 1, config~maxLineBytes)
      line = buffer~left(p - 1)
      buffer = buffer~substr(p + 2)
      return line
    end
    if buffer~length > config~maxLineBytes then raise syntax 88.900 array("IMAP_LINE_TOO_LARGE", buffer~length, config~maxLineBytes)
    chunk = transport~read(config~readChunkSize)
    if chunk == .nil then raise syntax 88.900 array("IMAP_READ_FAILED")
    if chunk = "" then raise syntax 88.900 array("IMAP_UNEXPECTED_EOF")
    bytesRead += chunk~length
    buffer = buffer || chunk
  end
::method nextRecord
  expose config recordsRead
  use strict arg sinkFactory = .nil
  first = self~readLine
  record = .ImapResponseRecord~new(first)
  line = first
  do forever
    literalLength = self~literalLengthAtEnd(line)
    if literalLength < 0 then leave
    if literalLength > config~maxLiteralBytes then raise syntax 88.900 array("IMAP_LITERAL_TOO_LARGE", literalLength, config~maxLiteralBytes)
    if sinkFactory <> .nil & sinkFactory~hasMethod("CREATELITERALSINK") then sink = sinkFactory~createLiteralSink(literalLength, record)
    else if literalLength <= config~maxInlineLiteralBytes then sink = .ImapInlineLiteralSink~new
    else sink = .ImapDiscardLiteralSink~new
    self~readExactToSink(literalLength, sink)
    sink~finish
    record~addLiteral(.ImapLiteralSegment~new(literalLength, sink))
    line = self~readLine
    record~addLine(line)
  end
  recordsRead += 1
  return record
::method readExactToSink private
  expose transport config buffer bytesRead
  use strict arg wantedArg, sink
  remaining = wantedArg + 0
  if remaining < 0 then raise syntax 88.900 array("negative IMAP literal length")
  do while remaining > 0
    if buffer~length > 0 then do
      take = remaining
      if buffer~length < take then take = buffer~length
      piece = buffer~left(take)
      buffer = buffer~substr(take + 1)
    end
    else do
      ask = remaining
      if ask > config~readChunkSize then ask = config~readChunkSize
      chunk = transport~read(ask)
      if chunk == .nil then raise syntax 88.900 array("IMAP_READ_FAILED_IN_LITERAL", remaining)
      if chunk = "" then raise syntax 88.900 array("IMAP_TRUNCATED_LITERAL", wantedArg, wantedArg - remaining)
      bytesRead += chunk~length
      if chunk~length > remaining then do
        piece = chunk~left(remaining)
        buffer = chunk~substr(remaining + 1) || buffer
      end
      else piece = chunk
    end
    accepted = sink~write(piece)
    if accepted <> piece~length then raise syntax 88.900 array("IMAP_LITERAL_SINK_SHORT_WRITE", piece~length, accepted)
    remaining -= piece~length
  end
::method literalLengthAtEnd private
  use strict arg line
  t = line~strip("T")
  if t = "" then return -1
  if t~right(1) <> "}" then return -1
  open = t~lastPos("{")
  if open = 0 then return -1
  body = t~substr(open + 1, t~length - open - 1)
  if body = "" then return -1
  last = body~right(1)
  if last = "+" | last = "-" then body = body~left(body~length - 1)
  if body = "" | \datatype(body, "W") then return -1
  return body + 0

::class ImapCapabilities public
::method init
  expose values
  values = .directory~new
::method add
  expose values
  use strict arg capability
  cap = capability~string~strip~upper
  if cap <> "" then values[cap] = .true
  return self
::method addWords
  use strict arg text
  do i = 1 to text~words
    self~add(text~word(i))
  end
  return self
::method has
  expose values
  use strict arg capability
  return values~hasIndex(capability~string~strip~upper)
::method hasPrefix
  expose values
  use strict arg prefix
  wanted = prefix~string~strip~upper
  do k over values
    if k~left(wanted~length) = wanted then return .true
  end
  return .false
::method valueForPrefix
  expose values
  use strict arg prefix
  wanted = prefix~string~strip~upper
  do k over values
    if k~left(wanted~length) = wanted then return k~substr(wanted~length + 1)
  end
  return ""
::method items
  expose values
  return values~items
::method all
  expose values
  a = .array~new
  do k over values; a~append(k); end
  a~sort
  return a
::method fromCapabilityLine class
  use strict arg line
  c = .ImapCapabilities~new
  if line~word(1) = "*" & line~word(2)~upper = "CAPABILITY" then do
    do i = 3 to line~words; c~add(line~word(i)); end
  end
  return c

::class ImapUidRange public
::attribute first get
::attribute last get
::method init
  expose first last
  use strict arg firstArg, lastArg = ""
  first = firstArg~string~strip
  if lastArg = "" then last = first
  else last = lastArg~string~strip
  if \self~validEndpoint(first) | \self~validEndpoint(last) then raise syntax 88.900 array("invalid UID range", first, last)
::method validEndpoint private
  use strict arg value
  if value = "*" then return .true
  if \datatype(value, "W") then return .false
  return value + 0 >= 1
::method wire
  expose first last
  if first = last then return first
  return first || ":" || last
::method count
  expose first last
  if first = "*" | last = "*" then return -1
  a = first + 0; b = last + 0
  if b >= a then return b - a + 1
  return a - b + 1
::method contains
  expose first last
  use strict arg uidArg
  uid = uidArg + 0
  if first = "*" | last = "*" then return .false
  a = first + 0; b = last + 0
  if a <= b then return uid >= a & uid <= b
  return uid >= b & uid <= a

::class ImapUidSet public
::attribute ranges get
::method init
  expose ranges
  ranges = .array~new
::method addRange
  expose ranges
  use strict arg first, last = ""
  ranges~append(.ImapUidRange~new(first, last))
  return self
::method addUid
  use strict arg uid
  return self~addRange(uid)
::method wire
  expose ranges
  out = ""
  do i = 1 to ranges~items
    if i > 1 then out = out || ","
    out = out || ranges[i]~wire
  end
  return out
::method count
  expose ranges
  total = 0
  do r over ranges
    n = r~count
    if n < 0 then return -1
    total += n
  end
  return total
::method rangeCount
  expose ranges
  return ranges~items
::method contains
  expose ranges
  use strict arg uid
  do r over ranges
    if r~contains(uid) then return .true
  end
  return .false
::method ordinalOf
  expose ranges
  use strict arg uidArg
  uid = uidArg + 0
  ordinal = 0
  do r over ranges
    n = r~count
    if n < 0 then return 0
    if r~contains(uid) then do
      a = r~first + 0; b = r~last + 0
      if b >= a then return ordinal + (uid - a) + 1
      return ordinal + (a - uid) + 1
    end
    ordinal += n
  end
  return 0
::method uidAtOrdinal
  expose ranges
  use strict arg ordinalArg
  wanted = ordinalArg + 0
  if wanted < 1 then raise syntax 88.900 array("UID_SET_ORDINAL_INVALID", wanted)
  base = 0
  do r over ranges
    n = r~count
    if n < 0 then raise syntax 88.900 array("UID_SET_OPEN_ENDED")
    if wanted <= base + n then do
      offset = wanted - base - 1
      a = r~first + 0; b = r~last + 0
      if b >= a then return a + offset
      return a - offset
    end
    base += n
  end
  raise syntax 88.900 array("UID_SET_ORDINAL_OUTSIDE", wanted, base)
::method toArray
  expose ranges
  use strict arg limit = 10000
  n = self~count
  if n < 0 then raise syntax 88.900 array("UID_SET_OPEN_ENDED")
  if n > limit then raise syntax 88.900 array("UID_SET_MATERIALIZE_LIMIT", n, limit)
  out = .array~new
  do r over ranges
    a = r~first + 0; b = r~last + 0
    step = 1; if b < a then step = -1
    do u = a to b by step; out~append(u); end
  end
  return out
::method parse class
  use strict arg text
  set = .ImapUidSet~new
  rest = text~strip
  if rest = "" then return set
  do while rest <> ""
    comma = rest~pos(",")
    if comma = 0 then do; item = rest; rest = ""; end
    else do; item = rest~left(comma - 1); rest = rest~substr(comma + 1); end
    item = item~strip
    colon = item~pos(":")
    if colon = 0 then set~addRange(item)
    else set~addRange(item~left(colon - 1), item~substr(colon + 1))
  end
  return set

::class ImapSearchResult public
::attribute uidMode
::attribute count
::attribute minimum
::attribute maximum
::attribute all
::attribute complete
::method init
  expose uidMode count minimum maximum all complete
  uidMode = .false; count = -1; minimum = ""; maximum = ""; all = .ImapUidSet~new; complete = .false

::class ImapMailboxState public
::attribute mailbox
::attribute exists
::attribute recent
::attribute unseenCount
::attribute firstUnseenSequence
::attribute uidValidity
::attribute uidNext
::attribute highestModSeq
::attribute readOnly
::attribute flags
::attribute permanentFlags
::method init
  expose mailbox exists recent unseenCount firstUnseenSequence uidValidity uidNext highestModSeq readOnly flags permanentFlags
  mailbox = ""; exists = -1; recent = -1; unseenCount = -1; firstUnseenSequence = -1
  uidValidity = ""; uidNext = ""; highestModSeq = ""; readOnly = .false
  flags = ""; permanentFlags = ""
::method copy
  expose mailbox exists recent unseenCount firstUnseenSequence uidValidity uidNext highestModSeq readOnly flags permanentFlags
  s = .ImapMailboxState~new
  s~mailbox = mailbox; s~exists = exists; s~recent = recent; s~unseenCount = unseenCount; s~firstUnseenSequence = firstUnseenSequence
  s~uidValidity = uidValidity; s~uidNext = uidNext; s~highestModSeq = highestModSeq
  s~readOnly = readOnly; s~flags = flags; s~permanentFlags = permanentFlags
  return s

::class ImapSyncPlan public
::attribute strategy get
::attribute reason get
::attribute requiresFullRebuild get
::attribute fromUid get
::attribute knownUidValidity get
::attribute knownModSeq get
::method init
  expose strategy reason requiresFullRebuild fromUid knownUidValidity knownModSeq
  use strict arg strategyArg, reasonArg = "", rebuildArg = .false, fromUidArg = "", uidvArg = "", modseqArg = ""
  strategy = strategyArg~string; reason = reasonArg~string; requiresFullRebuild = rebuildArg == .true
  fromUid = fromUidArg~string; knownUidValidity = uidvArg~string; knownModSeq = modseqArg~string

::class ImapSyncPlanner public
::method plan class
  use strict arg capabilities, previousState = .nil, currentState = .nil, lastKnownUid = ""
  if previousState == .nil then return .ImapSyncPlan~new("INITIAL_BOUNDED", "no durable baseline; become usable before historical enumeration")
  if currentState <> .nil then do
    if previousState~uidValidity <> "" & currentState~uidValidity <> "" & previousState~uidValidity <> currentState~uidValidity then -
      return .ImapSyncPlan~new("REBUILD_REQUIRED", "UIDVALIDITY changed", .true, "", previousState~uidValidity, previousState~highestModSeq)
  end
  if capabilities~has("QRESYNC") & previousState~uidValidity <> "" & previousState~highestModSeq <> "" then -
    return .ImapSyncPlan~new("QRESYNC", "server supports QRESYNC and durable UIDVALIDITY/MODSEQ baseline exists", .false, "", previousState~uidValidity, previousState~highestModSeq)
  if capabilities~has("CONDSTORE") & previousState~highestModSeq <> "" then -
    return .ImapSyncPlan~new("CONDSTORE", "server supports CONDSTORE and durable MODSEQ baseline exists", .false, "", previousState~uidValidity, previousState~highestModSeq)
  if lastKnownUid <> "" & datatype(lastKnownUid, "W") then -
    return .ImapSyncPlan~new("UID_INCREMENTAL", "fetch only UID range after durable high-water mark", .false, (lastKnownUid + 1)~string, previousState~uidValidity, previousState~highestModSeq)
  return .ImapSyncPlan~new("BOUNDED_RECONCILE", "no change-tracking extension baseline; avoid full mailbox scan on open", .false, "", previousState~uidValidity, previousState~highestModSeq)

::class ImapCodec public
::method quoteString class
  use strict arg value
  s = value~string
  out = '"'
  do i = 1 to s~length
    ch = s~substr(i, 1)
    if ch = '"' | ch = "\" then out = out || "\"
    out = out || ch
  end
  return out || '"'
::method quoteMailbox class
  use strict arg mailbox
  return self~quoteString(mailbox)
::method statusCodeValue class
  use strict arg line, code
  wanted = "[" || code~upper
  upper = line~upper
  p = upper~pos(wanted)
  if p = 0 then return ""
  rest = line~substr(p + wanted~length)~strip("L")
  if rest = "" then return ""
  value = rest~word(1)
  if value~right(1) = "]" then value = value~left(value~length - 1)
  return value
::method betweenParens class
  use strict arg line
  a = line~pos("("); b = line~lastPos(")")
  if a = 0 | b <= a then return ""
  return line~substr(a + 1, b - a - 1)
