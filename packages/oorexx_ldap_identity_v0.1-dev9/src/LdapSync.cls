/* LdapSync.cls
 * RFC 4533 refreshOnly and refreshAndPersist projection over Identity Directory's durable semantic
 * change stream.  This is a network synchronization conversation; it does not
 * change the directory's conflict/authority model.
 */

::class LdapSyncBuild public
::constant API_VERSION "ldap.sync/0.1"
::constant REQUEST_OID "1.3.6.1.4.1.4203.1.9.1.1"
::constant STATE_OID "1.3.6.1.4.1.4203.1.9.1.2"
::constant DONE_OID "1.3.6.1.4.1.4203.1.9.1.3"
::constant INFO_OID "1.3.6.1.4.1.4203.1.9.1.4"
::constant REFRESH_REQUIRED 4096

::class LdapSyncRecord public
::attribute state get
::attribute entry get
::attribute entryUuid get
::attribute entryUuidBytes get
::attribute entityId get
::method init
  expose state entry entryUuid entryUuidBytes entityId
  use strict arg stateArg, entryArg, entryUuidArg, entityIdArg = ""
  state = stateArg~string~upper
  entry = entryArg
  candidate = entryUuidArg~string
  if candidate~length = 16 then do
    entryUuidBytes = candidate
    entryUuid = .LdapSyncCodec~uuidText(candidate)
  end
  else do
    entryUuidBytes = .LdapSyncCodec~uuidBytes(candidate)
    entryUuid = .LdapSyncCodec~uuidText(entryUuidBytes)
  end
  entityId = entityIdArg~string

::class LdapSyncBatch public
::attribute records get
::attribute cookie get
::attribute refreshDeletes get
::method init
  expose records cookie refreshDeletes
  use strict arg recordsArg, cookieArg, refreshDeletesArg = .false
  records = recordsArg
  cookie = cookieArg~string
  refreshDeletes = refreshDeletesArg

::class LdapSyncCodec public
::method uuidText class
  use strict arg bytes
  if bytes~length <> 16 then raise syntax 88.900 array("LDAP Sync UUID must contain 16 octets")
  h = c2x(bytes)~lower
  return h~substr(1,8) || "-" || h~substr(9,4) || "-" || h~substr(13,4) || "-" || h~substr(17,4) || "-" || h~substr(21,12)
::method uuidBytes class
  use strict arg text
  h = text~string~changestr("-", "")
  if h~length <> 32 then raise syntax 88.900 array("LDAP Sync UUID text invalid", text)
  return x2c(h)
::method requestControl class
  use strict arg mode = "REFRESH_ONLY", cookie = .nil, reloadHint = .false, criticality = .true
  m = mode~string~upper
  if m = "REFRESH_ONLY" then modeNum = 1
  else if m = "REFRESH_AND_PERSIST" then modeNum = 3
  else raise syntax 88.900 array("unsupported LDAP Sync mode", mode)
  body = .LdapBer~enumerated(modeNum)
  if cookie <> .nil then if cookie~string <> "" then body ||= .LdapBer~octet(cookie)
  if reloadHint then body ||= .LdapBer~boolean(.true)
  value = .LdapBer~sequence(body)
  return .LdapControl~new(.LdapSyncBuild~REQUEST_OID, criticality, value)
::method decodeRequestControl class
  use strict arg control
  if control == .nil then return self~failure("LDAP_SYNC_CONTROL_REQUIRED")
  if control~controlType <> .LdapSyncBuild~REQUEST_OID then return self~failure("LDAP_SYNC_CONTROL_REQUIRED")
  if \control~valuePresent then return self~failure("LDAP_SYNC_REQUEST_VALUE_REQUIRED")
  seq = .LdapBer~readElement(control~controlValue, 1)
  if \seq["ok"] | seq["tag"] <> 48 | seq["next"] <> control~controlValue~length + 1 then return self~failure("LDAP_SYNC_REQUEST_INVALID")
  mode = .LdapBer~readElement(seq["value"], 1)
  if \mode["ok"] | mode["tag"] <> 10 then return self~failure("LDAP_SYNC_MODE_INVALID")
  modeNum = .LdapBer~decodeUnsignedInteger(mode["value"])
  if modeNum = 1 then modeText = "REFRESH_ONLY"
  else if modeNum = 3 then modeText = "REFRESH_AND_PERSIST"
  else return self~failure("LDAP_SYNC_MODE_UNSUPPORTED")
  cookie = .nil
  reload = .false
  pos = mode["next"]
  if pos <= seq["value"]~length then do
    e = .LdapBer~readElement(seq["value"], pos)
    if \e["ok"] then return e
    if e["tag"] = 4 then do
      cookie = e["value"]
      pos = e["next"]
      if pos <= seq["value"]~length then do
        e = .LdapBer~readElement(seq["value"], pos)
        if \e["ok"] then return e
        if e["tag"] <> 1 then return self~failure("LDAP_SYNC_RELOAD_HINT_INVALID")
        reload = e["value"] <> '00'x
        pos = e["next"]
      end
    end
    else if e["tag"] = 1 then do
      reload = e["value"] <> '00'x
      pos = e["next"]
    end
    else return self~failure("LDAP_SYNC_REQUEST_FIELD_INVALID")
  end
  if pos <= seq["value"]~length then return self~failure("LDAP_SYNC_REQUEST_TRAILING_BYTES")
  out = .directory~new; out["ok"] = .true; out["mode"] = modeText; out["cookie"] = cookie; out["reloadHint"] = reload; return out
::method stateControl class
  use strict arg state, entryUuidBytes, cookie = .nil
  s = state~string~upper
  select
    when s = "PRESENT" then n = 0
    when s = "ADD" then n = 1
    when s = "MODIFY" then n = 2
    when s = "DELETE" then n = 3
    otherwise raise syntax 88.900 array("invalid LDAP Sync state", state)
  end
  if entryUuidBytes~length <> 16 then raise syntax 88.900 array("LDAP Sync UUID must contain 16 octets")
  body = .LdapBer~enumerated(n) || .LdapBer~octet(entryUuidBytes)
  if cookie <> .nil then if cookie~string <> "" then body ||= .LdapBer~octet(cookie)
  return .LdapControl~new(.LdapSyncBuild~STATE_OID, .false, .LdapBer~sequence(body))
::method decodeStateControl class
  use strict arg control
  if control == .nil then return self~failure("LDAP_SYNC_STATE_INVALID")
  if control~controlType <> .LdapSyncBuild~STATE_OID then return self~failure("LDAP_SYNC_STATE_INVALID")
  if \control~valuePresent then return self~failure("LDAP_SYNC_STATE_INVALID")
  seq = .LdapBer~readElement(control~controlValue,1)
  if \seq["ok"] | seq["tag"] <> 48 then return self~failure("LDAP_SYNC_STATE_INVALID")
  state = .LdapBer~readElement(seq["value"],1)
  uuid = .LdapBer~readElement(seq["value"],state["next"])
  if \state["ok"] | state["tag"] <> 10 | \uuid["ok"] | uuid["tag"] <> 4 | uuid["value"]~length <> 16 then return self~failure("LDAP_SYNC_STATE_INVALID")
  n = .LdapBer~decodeUnsignedInteger(state["value"])
  if n = 0 then st = "PRESENT"
  else if n = 1 then st = "ADD"
  else if n = 2 then st = "MODIFY"
  else if n = 3 then st = "DELETE"
  else return self~failure("LDAP_SYNC_STATE_INVALID")
  cookie = .nil
  pos = uuid["next"]
  if pos <= seq["value"]~length then do
    ce = .LdapBer~readElement(seq["value"],pos)
    if \ce["ok"] | ce["tag"] <> 4 then return self~failure("LDAP_SYNC_STATE_COOKIE_INVALID")
    cookie = ce["value"]
    pos = ce["next"]
  end
  if pos <= seq["value"]~length then return self~failure("LDAP_SYNC_STATE_TRAILING_BYTES")
  out=.directory~new; out["ok"]=.true; out["state"]=st; out["entryUuid"]=uuid["value"]; out["cookie"]=cookie; return out
::method doneControl class
  use strict arg cookie = .nil, refreshDeletes = .false
  body = ""
  if cookie <> .nil then if cookie~string <> "" then body ||= .LdapBer~octet(cookie)
  if refreshDeletes then body ||= .LdapBer~boolean(.true)
  return .LdapControl~new(.LdapSyncBuild~DONE_OID, .false, .LdapBer~sequence(body))
::method infoNewCookie class
  use strict arg cookie
  return .LdapBer~tlv(128, cookie~string)
::method infoRefresh class
  use strict arg refreshDeletes = .false, cookie = .nil, refreshDone = .true
  body = ""
  if cookie <> .nil then if cookie~string <> "" then body ||= .LdapBer~octet(cookie)
  /* refreshDone defaults TRUE in RFC 4533; encode only the non-default FALSE. */
  if \refreshDone then body ||= .LdapBer~boolean(.false)
  if refreshDeletes then tag = 161
  else tag = 162
  return .LdapBer~tlv(tag, body)
::method decodeInfoValue class
  use strict arg value
  e = .LdapBer~readElement(value, 1)
  if \e["ok"] | e["next"] <> value~length + 1 then return self~failure("LDAP_SYNC_INFO_INVALID")
  out = .directory~new; out["ok"] = .true; out["cookie"] = .nil; out["refreshDone"] = .false; out["refreshDeletes"] = .false
  if e["tag"] = 128 then do
    out["kind"] = "NEW_COOKIE"; out["cookie"] = e["value"]; return out
  end
  if e["tag"] <> 161 & e["tag"] <> 162 then return self~failure("LDAP_SYNC_INFO_UNSUPPORTED")
  out["kind"] = "REFRESH"; out["refreshDeletes"] = e["tag"] = 161; out["refreshDone"] = .true
  pos = 1
  if pos <= e["value"]~length then do
    f = .LdapBer~readElement(e["value"], pos)
    if \f["ok"] then return f
    if f["tag"] = 4 then do; out["cookie"] = f["value"]; pos = f["next"]; end
  end
  if pos <= e["value"]~length then do
    f = .LdapBer~readElement(e["value"], pos)
    if \f["ok"] | f["tag"] <> 1 then return self~failure("LDAP_SYNC_INFO_REFRESH_DONE_INVALID")
    out["refreshDone"] = f["value"] <> '00'x; pos = f["next"]
  end
  if pos <= e["value"]~length then return self~failure("LDAP_SYNC_INFO_TRAILING_BYTES")
  return out
::method decodeDoneControl class
  use strict arg control
  if control == .nil then return self~failure("LDAP_SYNC_DONE_INVALID")
  if control~controlType <> .LdapSyncBuild~DONE_OID then return self~failure("LDAP_SYNC_DONE_INVALID")
  if \control~valuePresent then return self~failure("LDAP_SYNC_DONE_INVALID")
  seq = .LdapBer~readElement(control~controlValue,1)
  if \seq["ok"] | seq["tag"] <> 48 then return self~failure("LDAP_SYNC_DONE_INVALID")
  cookie=.nil; deletes=.false; pos=1
  if pos <= seq["value"]~length then do
    e=.LdapBer~readElement(seq["value"],pos)
    if \e["ok"] then return e
    if e["tag"]=4 then do; cookie=e["value"]; pos=e["next"]; end
  end
  if pos <= seq["value"]~length then do
    e=.LdapBer~readElement(seq["value"],pos)
    if \e["ok"] | e["tag"]<>1 then return self~failure("LDAP_SYNC_DONE_INVALID")
    deletes=e["value"]<>'00'x; pos=e["next"]
  end
  if pos <= seq["value"]~length then return self~failure("LDAP_SYNC_DONE_TRAILING_BYTES")
  out=.directory~new; out["ok"]=.true; out["cookie"]=cookie; out["refreshDeletes"]=deletes; return out
::method failure class private
  use strict arg code
  d=.directory~new; d["ok"]=.false; d["code"]=code; return d

::class LdapSyncProvider public
::method init
  expose directory personality
  use strict arg directoryArg, personalityArg
  directory = directoryArg
  personality = personalityArg
::method queryHash private
  expose personality
  use strict arg baseDn, scope, filterText, attributes, typesOnly=.false
  text = "LDAP-SYNC-QUERY/1" || '0a'x
  text ||= .DirectoryCanonical~field("PERSONALITY", personality~name)
  text ||= .DirectoryCanonical~field("BASE", .LdapDn~canonical(baseDn))
  text ||= .DirectoryCanonical~field("SCOPE", scope~string~upper)
  text ||= .DirectoryCanonical~field("FILTER", filterText~string~strip)
  text ||= .DirectoryCanonical~field("TYPES_ONLY", .DirectoryCanonical~boolText(typesOnly))
  names=.array~new
  if attributes <> .nil then do n over attributes; names~append(n~string~lower); end
  do n over .DirectoryCanonical~sortedStrings(names)
    text ||= .DirectoryCanonical~field("ATTRIBUTE", n)
  end
  return .DirectoryCanonical~hash(text)
::method encodeCookie private
  expose directory
  use strict arg revision, queryHash
  return "IDLDAPSYNC1:" || c2x(directory~peerId)~lower || ":" || revision || ":" || queryHash
::method decodeCookie private
  expose directory
  use strict arg cookie, queryHash
  text=cookie~string
  parse var text prefix ":" peerHex ":" revisionText ":" cookieHash
  if prefix <> "IDLDAPSYNC1" | peerHex = "" | revisionText = "" | cookieHash = "" then return .DirectoryResult~failure("SYNC_REFRESH_REQUIRED")
  signal on syntax name badCookie
  peer=x2c(peerHex)
  revision=revisionText+0
  signal off syntax
  if peer <> directory~peerId | cookieHash <> queryHash | revision < 0 | revision > directory~revision then return .DirectoryResult~failure("SYNC_REFRESH_REQUIRED")
  return .DirectoryResult~success(revision)
badCookie:
  signal off syntax
  return .DirectoryResult~failure("SYNC_REFRESH_REQUIRED")
::method inScope private
  use strict arg entryDn, baseDn, scope
  ep=.LdapDn~parse(entryDn); bp=.LdapDn~parse(baseDn); s=scope~string~upper
  if \ep~ok | \bp~ok then return .false
  e=ep~value; b=bp~value
  if s="BASE" then return e~canonicalKey=b~canonicalKey
  if s="SUB" then return e~isDescendantOf(b~canonicalText,.true)
  if s="ONE" then return e~relativeDepth(b~canonicalText)=1
  return .false
::method selectAttributes private
  use strict arg entry, requestedAttributes
  if requestedAttributes == .nil then return entry
  selected=.LdapAttributeSet~new
  do name over requestedAttributes
    do value over entry~attributes~get(name); selected~add(name,value); end
  end
  return .LdapEntry~new(entry~dn,selected,entry~semanticEntityId)
::method projectedMatch private
  expose directory personality
  use strict arg entity, baseDn, scope, filterText, requestedAttributes
  if entity == .nil then return .nil
  if \self~inScope(entity~dn,baseDn,scope) then return .nil
  full=personality~project(entity,directory)
  if \.LdapFilter~matches(filterText,full) then return .nil
  return self~selectAttributes(full,requestedAttributes)
::method refreshOnly
  expose directory personality
  use strict arg baseDn, scope="SUB", filterText="(objectClass=*)", requestedAttributes=.nil, cookie=.nil, typesOnly=.false
  qh=self~queryHash(baseDn,scope,filterText,requestedAttributes,typesOnly)
  records=.array~new
  initialRefresh = cookie == .nil
  if \initialRefresh then if cookie~string = "" then initialRefresh = .true
  if initialRefresh then do
    do entity over directory~allEntries
      entry=self~projectedMatch(entity,baseDn,scope,filterText,requestedAttributes)
      if entry <> .nil then records~append(.LdapSyncRecord~new("ADD",entry,.LdapSyncCodec~uuidBytes(entry~attributes~first("entryUUID")),entity~entityId))
    end
    nextCookie=self~encodeCookie(directory~revision,qh)
    return .DirectoryResult~success(.LdapSyncBatch~new(records,nextCookie,.false))
  end
  decoded=self~decodeCookie(cookie,qh)
  if \decoded~ok then return decoded
  fromRevision=decoded~value
  do change over directory~changesSince(fromRevision)
    beforeEntry=self~projectedMatch(change~beforeEntity,baseDn,scope,filterText,requestedAttributes)
    afterEntry=self~projectedMatch(change~afterEntity,baseDn,scope,filterText,requestedAttributes)
    if beforeEntry == .nil & afterEntry == .nil then iterate
    if beforeEntry == .nil then do
      entity=change~afterEntity
      records~append(.LdapSyncRecord~new("ADD",afterEntry,.LdapSyncCodec~uuidBytes(afterEntry~attributes~first("entryUUID")),entity~entityId))
      iterate
    end
    if afterEntry == .nil then do
      entity=change~beforeEntity
      empty=.LdapEntry~new(beforeEntry~dn,.LdapAttributeSet~new,entity~entityId)
      records~append(.LdapSyncRecord~new("DELETE",empty,entity~entryUuidBytes,entity~entityId))
      iterate
    end
    entity=change~afterEntity
    state="MODIFY"
    if change~operation="ADD" then state="ADD"
    records~append(.LdapSyncRecord~new(state,afterEntry,.LdapSyncCodec~uuidBytes(afterEntry~attributes~first("entryUUID")),entity~entityId))
  end
  nextCookie=self~encodeCookie(directory~revision,qh)
  return .DirectoryResult~success(.LdapSyncBatch~new(records,nextCookie,.true))

::requires "src/LdapBer.cls"
