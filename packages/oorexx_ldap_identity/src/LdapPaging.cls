/* LdapPaging.cls
 * RFC 2696 Simple Paged Results control for Identity Directory.
 *
 * Paging is an LDAP conversation concern.  The neutral Identity Directory
 * remains authoritative for identity/resource state and does not acquire a
 * page/cursor concept.  Result-set state is association-local and cookies are
 * opaque, rotated on every page and invalidated on completion/abandonment.
 */

::class LdapPagingBuild public
::constant API_VERSION "ldap.paging/0.1"
::constant CONTROL_OID "1.2.840.113556.1.4.319"

::class LdapPagedSearchPage public
::attribute entries get
::attribute estimatedSize get
::attribute cookie get
::attribute resultCode get
::attribute abandoned get
::method init
  expose entries estimatedSize cookie resultCode abandoned
  use strict arg entriesArg, estimatedSizeArg, cookieArg = "", resultCodeArg = 0, abandonedArg = .false
  entries = entriesArg
  estimatedSize = estimatedSizeArg
  cookie = cookieArg~string
  resultCode = resultCodeArg
  abandoned = abandonedArg
::method complete
  expose cookie
  return cookie = ""

::class LdapPagingCodec public
::method requestControl class
  use strict arg pageSize, cookie = "", criticality = .false
  if pageSize < 0 then raise syntax 88.900 array("LDAP page size must be non-negative")
  value = .LdapBer~sequence(.LdapBer~integer(pageSize) || .LdapBer~octet(cookie))
  return .LdapControl~new(.LdapPagingBuild~CONTROL_OID, criticality, value)
::method responseControl class
  use strict arg estimatedSize = 0, cookie = ""
  if estimatedSize < 0 then estimatedSize = 0
  value = .LdapBer~sequence(.LdapBer~integer(estimatedSize) || .LdapBer~octet(cookie))
  return .LdapControl~new(.LdapPagingBuild~CONTROL_OID, .false, value)
::method decodeControl class
  use strict arg control
  if control == .nil then return self~failure("LDAP_PAGING_CONTROL_REQUIRED")
  if control~controlType <> .LdapPagingBuild~CONTROL_OID then return self~failure("LDAP_PAGING_CONTROL_REQUIRED")
  if \control~valuePresent then return self~failure("LDAP_PAGING_VALUE_REQUIRED")
  seq = .LdapBer~readElement(control~controlValue, 1)
  if \seq["ok"] | seq["tag"] <> 48 | seq["next"] <> control~controlValue~length + 1 then return self~failure("LDAP_PAGING_VALUE_INVALID")
  size = .LdapBer~readElement(seq["value"], 1)
  if \size["ok"] | size["tag"] <> 2 then return self~failure("LDAP_PAGING_SIZE_INVALID")
  cookie = .LdapBer~readElement(seq["value"], size["next"])
  if \cookie["ok"] | cookie["tag"] <> 4 then return self~failure("LDAP_PAGING_COOKIE_INVALID")
  if cookie["next"] <> seq["value"]~length + 1 then return self~failure("LDAP_PAGING_TRAILING_BYTES")
  out = .directory~new
  out["ok"] = .true
  out["size"] = .LdapBer~decodeUnsignedInteger(size["value"])
  out["cookie"] = cookie["value"]
  return out
::method failure class private
  use strict arg code
  d = .directory~new; d["ok"] = .false; d["code"] = code; return d

::class LdapPagedResultSet public
::attribute queryKey get
::attribute entries get
::attribute offset get
::attribute sourceSize get
::attribute truncated get
::attribute cookie get
::method init
  expose queryKey entries offset sourceSize truncated cookie
  use strict arg queryKeyArg, entriesArg, sourceSizeArg, truncatedArg = .false
  queryKey = queryKeyArg~string
  entries = entriesArg
  offset = 0
  sourceSize = sourceSizeArg
  truncated = truncatedArg
  cookie = ""
::method setCookie
  expose cookie
  use strict arg value
  cookie = value~string
  return self
::method advance
  expose offset entries
  use strict arg count
  offset += count
  if offset > entries~items then offset = entries~items
  return offset
::method remaining
  expose offset entries
  return entries~items - offset

::class LdapPagingRegistry public
::method init
  expose states sequence associationSeed maxActive
  use strict arg associationSeedArg = "", maxActiveArg = 64
  states = .directory~new
  sequence = 0
  maxActive = maxActiveArg
  if maxActive < 1 then maxActive = 1
  associationSeed = associationSeedArg~string
  if associationSeed = "" then associationSeed = .DirectoryCanonical~dateTimeText(.DateTime~new)
::method activeCount
  expose states
  return states~items
::method maxActive
  expose maxActive
  return maxActive
::method makeCookie private
  expose sequence associationSeed
  use strict arg queryKey
  sequence += 1
  seed = "LDAP-PAGED-COOKIE/1" || '0a'x
  seed ||= .DirectoryCanonical~field("ASSOCIATION", associationSeed)
  seed ||= .DirectoryCanonical~field("SEQUENCE", sequence)
  seed ||= .DirectoryCanonical~field("QUERY", queryKey)
  seed ||= .DirectoryCanonical~field("TIME", .DirectoryCanonical~dateTimeText(.DateTime~new))
  return "IDLDAPPAGE1:" || .DirectoryCanonical~hash(seed)~lower
::method queryKey class
  use strict arg personalityName, baseDn, scope, filterText, attributes = .nil, typesOnly = .false, sizeLimit = 0, timeLimit = 0, derefAliases = 0
  text = "LDAP-PAGED-QUERY/1" || '0a'x
  text ||= .DirectoryCanonical~field("PERSONALITY", personalityName)
  text ||= .DirectoryCanonical~field("BASE", .LdapDn~canonical(baseDn))
  text ||= .DirectoryCanonical~field("SCOPE", scope~string~upper)
  text ||= .DirectoryCanonical~field("FILTER", filterText~string~strip)
  text ||= .DirectoryCanonical~field("TYPES_ONLY", .DirectoryCanonical~boolText(typesOnly))
  text ||= .DirectoryCanonical~field("SIZE_LIMIT", sizeLimit)
  text ||= .DirectoryCanonical~field("TIME_LIMIT", timeLimit)
  text ||= .DirectoryCanonical~field("DEREF_ALIASES", derefAliases)
  names = .array~new
  if attributes <> .nil then do n over attributes; names~append(n~string~lower); end
  do n over .DirectoryCanonical~sortedStrings(names)
    text ||= .DirectoryCanonical~field("ATTRIBUTE", n)
  end
  return .DirectoryCanonical~hash(text)
::method page
  expose states maxActive
  use strict arg queryKey, allEntries, pageSize, cookie = "", sizeLimit = 0
  if pageSize < 0 then return .DirectoryResult~failure("LDAP_PAGING_SIZE_INVALID")
  cookie = cookie~string

  if pageSize = 0 then do
    if cookie = "" then return .DirectoryResult~failure("LDAP_PAGING_ZERO_SIZE_REQUIRES_COOKIE")
    if \states~hasIndex(cookie) then return .DirectoryResult~failure("LDAP_PAGING_UNRESUMABLE")
    state = states[cookie]
    states~remove(cookie)
    if state~queryKey <> queryKey then return .DirectoryResult~failure("LDAP_PAGING_QUERY_MISMATCH")
    return .DirectoryResult~success(.LdapPagedSearchPage~new(.array~new, state~sourceSize, "", 0, .true))
  end

  if cookie = "" then do
    if states~items >= maxActive then return .DirectoryResult~failure("LDAP_PAGING_TOO_MANY_RESULT_SETS")
    sourceSize = allEntries~items
    entries = .array~new
    maxCount = sourceSize
    truncated = .false
    if sizeLimit > 0 & maxCount > sizeLimit then do
      maxCount = sizeLimit
      truncated = .true
    end
    do i = 1 to maxCount
      entries~append(allEntries[i])
    end
    state = .LdapPagedResultSet~new(queryKey, entries, sourceSize, truncated)
  end
  else do
    if \states~hasIndex(cookie) then return .DirectoryResult~failure("LDAP_PAGING_UNRESUMABLE")
    state = states[cookie]
    states~remove(cookie)
    if state~queryKey <> queryKey then return .DirectoryResult~failure("LDAP_PAGING_QUERY_MISMATCH")
  end

  pageEntries = .array~new
  take = pageSize
  if take > state~remaining then take = state~remaining
  start = state~offset + 1
  do i = start to start + take - 1
    if i >= 1 & i <= state~entries~items then pageEntries~append(state~entries[i])
  end
  ignore = state~advance(take)

  nextCookie = ""
  resultCode = 0
  if state~remaining > 0 then do
    nextCookie = self~makeCookie(queryKey)
    state~setCookie(nextCookie)
    states[nextCookie] = state
  end
  else if state~truncated then resultCode = 4

  return .DirectoryResult~success(.LdapPagedSearchPage~new(pageEntries, state~sourceSize, nextCookie, resultCode, .false))

::requires "src/LdapBer.cls"
