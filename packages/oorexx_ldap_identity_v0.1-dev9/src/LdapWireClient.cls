/* LdapWireClient.cls - LDAPv3 DUA peer for v0.1-dev9 qualification. */

::class LdapWireClient public
::attribute host get
::attribute port get
::attribute connected get
::attribute tlsActive get
::method init
  expose host port socket connected nextMessageId tlsActive pendingMessages
  use strict arg hostArg = "127.0.0.1", portArg = 389
  host = hostArg~string
  port = portArg
  socket = .nil
  connected = .false
  tlsActive = .false
  nextMessageId = 1
  pendingMessages = .directory~new
::method connect
  expose host port socket connected
  socket = .Socket~new
  if socket~connect(.InetAddress~new(host, port)) < 0 then return .DirectoryResult~failure("LDAP_CONNECT_FAILED", socket~errno)
  connected = .true
  return .DirectoryResult~success(self)
::method connectTls
  expose host port socket connected tlsActive
  use strict arg tlsProvider
  if connected then return .DirectoryResult~failure("LDAP_ALREADY_CONNECTED")
  if tlsProvider == .nil then return .DirectoryResult~failure("TLS_PROVIDER_UNAVAILABLE")
  if \tlsProvider~available then return .DirectoryResult~failure("TLS_PROVIDER_UNAVAILABLE")
  raw = .Socket~new
  if raw~connect(.InetAddress~new(host, port)) < 0 then return .DirectoryResult~failure("LDAP_CONNECT_FAILED", raw~errno)
  upgraded = tlsProvider~upgradeClient(raw, host)
  if \upgraded~ok then do; raw~close; return upgraded; end
  socket = .LdapTlsTransport~new(raw, upgraded~value)
  connected = .true; tlsActive = .true
  return .DirectoryResult~success(upgraded~value)
::method allocateId private
  expose nextMessageId
  id = nextMessageId
  nextMessageId += 1
  return id
::method queueMessage private
  expose pendingMessages
  use strict arg msg
  key = msg["messageId"]~string
  if \pendingMessages~hasIndex(key) then pendingMessages[key] = .array~new
  pendingMessages[key]~append(msg)
  return .true
::method popQueuedMessage private
  expose pendingMessages
  use strict arg messageId
  key = messageId~string
  if \pendingMessages~hasIndex(key) then return .nil
  q = pendingMessages[key]
  if q~items = 0 then do; pendingMessages~remove(key); return .nil; end
  msg = q[1]
  if q~items = 1 then pendingMessages~remove(key)
  else do
    rest = .array~new
    do i = 2 to q~items; rest~append(q[i]); end
    pendingMessages[key] = rest
  end
  return msg
::method readForMessage private
  expose socket connected
  use strict arg messageId
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  queued = self~popQueuedMessage(messageId)
  if queued <> .nil then return .DirectoryResult~success(queued)
  do forever
    frame = .LdapSocketIO~recvFrame(socket)
    if frame == .nil then return .DirectoryResult~failure("LDAP_CONNECTION_CLOSED")
    msg = .LdapWireCodec~decodeMessage(frame)
    if \msg["ok"] then return .DirectoryResult~failure(msg["code"])
    if msg["messageId"] = messageId then return .DirectoryResult~success(msg)
    self~queueMessage(msg)
  end
::method sendAndRead private
  expose socket connected
  use strict arg bytes, messageId
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  if \.LdapSocketIO~sendAll(socket, bytes) then return .DirectoryResult~failure("LDAP_SEND_FAILED")
  return self~readForMessage(messageId)
::method startTls
  expose socket connected host tlsActive
  use strict arg tlsProvider
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  if tlsActive then return .DirectoryResult~failure("LDAP_TLS_ALREADY_ACTIVE")
  if tlsProvider == .nil then return .DirectoryResult~failure("TLS_PROVIDER_UNAVAILABLE")
  if \tlsProvider~available then return .DirectoryResult~failure("TLS_PROVIDER_UNAVAILABLE")
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeExtendedRequest(id, .LdapTlsBuild~STARTTLS_OID), id)
  if \r~ok then return r
  msg = r~value
  if msg["messageId"] <> id | msg["opTag"] <> .LdapWireCodec~OP_EXTENDED_RESPONSE then return .DirectoryResult~failure("LDAP_STARTTLS_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeExtendedResponse(msg["opValue"])
  if \result["ok"] then return .DirectoryResult~failure(result["code"])
  if result["resultCode"] <> 0 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
  rawSocket = socket
  upgraded = tlsProvider~upgradeClient(rawSocket, host)
  if \upgraded~ok then do
    rawSocket~close
    socket = .nil
    connected = .false
    return upgraded
  end
  socket = .LdapTlsTransport~new(rawSocket, upgraded~value)
  tlsActive = .true
  return .DirectoryResult~success(upgraded~value)
::method bindSasl
  use strict arg mechanism, credentials = .nil
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeSaslBindRequest(id, mechanism, credentials), id)
  if \r~ok then return r
  msg = r~value
  if msg["messageId"] <> id | msg["opTag"] <> .LdapWireCodec~OP_BIND_RESPONSE then return .DirectoryResult~failure("LDAP_BIND_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if \result["ok"] then return .DirectoryResult~failure(result["code"])
  if result["resultCode"] <> 0 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
  return .DirectoryResult~success(.true)
::method bind
  use strict arg bindName, credential
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeBindRequest(id, bindName, credential), id)
  if \r~ok then return r
  msg = r~value
  if msg["messageId"] <> id | msg["opTag"] <> .LdapWireCodec~OP_BIND_RESPONSE then return .DirectoryResult~failure("LDAP_BIND_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if \result["ok"] then return .DirectoryResult~failure(result["code"])
  if result["resultCode"] <> 0 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
  return .DirectoryResult~success(.true)
::method search
  expose socket connected
  use strict arg baseDn, scope = "SUB", filterText = "(objectClass=*)", attributes = .nil
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  id = self~allocateId
  bytes = .LdapWireCodec~encodeSearchRequest(id, baseDn, scope, filterText, attributes)
  if \.LdapSocketIO~sendAll(socket, bytes) then return .DirectoryResult~failure("LDAP_SEND_FAILED")
  entries = .array~new
  do forever
    rr = self~readForMessage(id)
    if \rr~ok then return rr
    msg = rr~value
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_ENTRY then do
      decoded = .LdapWireCodec~decodeSearchEntry(msg["opValue"])
      if \decoded["ok"] then return .DirectoryResult~failure(decoded["code"])
      entries~append(decoded["entry"])
      iterate
    end
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_DONE then do
      result = .LdapWireCodec~decodeResult(msg["opValue"])
      if \result["ok"] then return .DirectoryResult~failure(result["code"])
      if result["resultCode"] <> 0 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
      return .DirectoryResult~success(entries)
    end
    return .DirectoryResult~failure("LDAP_SEARCH_RESPONSE_INVALID")
  end
::method searchPage
  expose socket connected
  use strict arg baseDn, scope = "SUB", filterText = "(objectClass=*)", attributes = .nil, pageSize = 100, cookie = "", sizeLimit = 0, timeLimit = 0, typesOnly = .false
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  id = self~allocateId
  pageControl = .LdapPagingCodec~requestControl(pageSize,cookie,.false)
  bytes = .LdapWireCodec~encodeSearchRequest(id,baseDn,scope,filterText,attributes,sizeLimit,timeLimit,typesOnly,.array~of(pageControl))
  if \.LdapSocketIO~sendAll(socket,bytes) then return .DirectoryResult~failure("LDAP_SEND_FAILED")
  entries = .array~new
  do forever
    rr = self~readForMessage(id)
    if \rr~ok then return rr
    msg = rr~value
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_ENTRY then do
      decoded = .LdapWireCodec~decodeSearchEntry(msg["opValue"])
      if \decoded["ok"] then return .DirectoryResult~failure(decoded["code"])
      entries~append(decoded["entry"])
      iterate
    end
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_DONE then do
      result = .LdapWireCodec~decodeResult(msg["opValue"])
      if \result["ok"] then return .DirectoryResult~failure(result["code"])
      /* A page size >= non-zero Search sizeLimit may be ignored under RFC2696.
       * In that case a normal SearchResultDone legitimately has no page control. */
      response = .LdapWireCodec~findControl(msg["controls"],.LdapPagingBuild~CONTROL_OID)
      ignored = cookie = "" & sizeLimit > 0 & pageSize >= sizeLimit & pageSize > 0
      if response == .nil then do
        if \ignored then do
          if result["resultCode"] <> 0 & result["resultCode"] <> 4 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"],result["diagnostic"])
          return .DirectoryResult~success(.LdapPagedSearchPage~new(entries,entries~items,"",result["resultCode"],.false))
        end
        return .DirectoryResult~failure("LDAP_PAGING_RESPONSE_CONTROL_REQUIRED")
      end
      decodedControl = .LdapPagingCodec~decodeControl(response)
      if \decodedControl["ok"] then return .DirectoryResult~failure(decodedControl["code"])
      if result["resultCode"] <> 0 & result["resultCode"] <> 4 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"],result["diagnostic"])
      return .DirectoryResult~success(.LdapPagedSearchPage~new(entries,decodedControl["size"],decodedControl["cookie"],result["resultCode"],pageSize=0 & cookie<>""))
    end
    return .DirectoryResult~failure("LDAP_PAGING_RESPONSE_INVALID")
  end
::method searchAllPaged
  use strict arg baseDn, scope = "SUB", filterText = "(objectClass=*)", attributes = .nil, pageSize = 100
  if pageSize <= 0 then return .DirectoryResult~failure("LDAP_PAGING_SIZE_INVALID")
  out = .array~new
  cookie = ""
  do forever
    pageResult = self~searchPage(baseDn,scope,filterText,attributes,pageSize,cookie)
    if \pageResult~ok then return pageResult
    page = pageResult~value
    do entry over page~entries; out~append(entry); end
    cookie = page~cookie
    if cookie = "" then leave
  end
  return .DirectoryResult~success(out)
::method abandonPagedSearch
  use strict arg baseDn, scope, filterText, attributes, cookie
  if cookie~string = "" then return .DirectoryResult~failure("LDAP_PAGING_COOKIE_REQUIRED")
  return self~searchPage(baseDn,scope,filterText,attributes,0,cookie)

::method compare
  use strict arg dn, attributeName, assertionValue
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeCompareRequest(id, dn, attributeName, assertionValue), id)
  if \r~ok then return r
  msg = r~value
  if msg["messageId"] <> id | msg["opTag"] <> .LdapWireCodec~OP_COMPARE_RESPONSE then return .DirectoryResult~failure("LDAP_COMPARE_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if \result["ok"] then return .DirectoryResult~failure(result["code"])
  if result["resultCode"] = 6 then return .DirectoryResult~success(.true)
  if result["resultCode"] = 5 then return .DirectoryResult~success(.false)
  return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
::method add
  use strict arg ldapEntry
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeAddRequest(id, ldapEntry), id)
  if \r~ok then return r
  msg = r~value
  if msg["opTag"] <> .LdapWireCodec~OP_ADD_RESPONSE then return .DirectoryResult~failure("LDAP_ADD_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if result["resultCode"] = 0 then return .DirectoryResult~success(.true)
  return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
::method modify
  use strict arg dn, modifications
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeModifyRequest(id, dn, modifications), id)
  if \r~ok then return r
  msg = r~value
  if msg["opTag"] <> .LdapWireCodec~OP_MODIFY_RESPONSE then return .DirectoryResult~failure("LDAP_MODIFY_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if result["resultCode"] = 0 then return .DirectoryResult~success(.true)
  return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
::method modifyDn
  use strict arg dn, newRdn, newSuperior = ""
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeModifyDnRequest(id, dn, newRdn, .true, newSuperior), id)
  if \r~ok then return r
  msg = r~value
  if msg["opTag"] <> .LdapWireCodec~OP_MODDN_RESPONSE then return .DirectoryResult~failure("LDAP_MODDN_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if result["resultCode"] = 0 then return .DirectoryResult~success(.true)
  return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
::method delete
  use strict arg dn
  id = self~allocateId
  r = self~sendAndRead(.LdapWireCodec~encodeDeleteRequest(id, dn), id)
  if \r~ok then return r
  msg = r~value
  if msg["opTag"] <> .LdapWireCodec~OP_DELETE_RESPONSE then return .DirectoryResult~failure("LDAP_DELETE_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeResult(msg["opValue"])
  if result["resultCode"] = 0 then return .DirectoryResult~success(.true)
  return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
::method syncRefreshOnly
  expose socket connected
  use strict arg baseDn, scope = "SUB", filterText = "(objectClass=*)", attributes = .nil, cookie = .nil
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  id = self~allocateId
  syncControl = .LdapSyncCodec~requestControl("REFRESH_ONLY", cookie, .false, .true)
  bytes = .LdapWireCodec~encodeSearchRequest(id, baseDn, scope, filterText, attributes, 0, 0, .false, .array~of(syncControl))
  if \.LdapSocketIO~sendAll(socket, bytes) then return .DirectoryResult~failure("LDAP_SEND_FAILED")
  records = .array~new
  nextCookie = ""
  refreshDeletes = .false
  do forever
    rr = self~readForMessage(id)
    if \rr~ok then return rr
    msg = rr~value
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_ENTRY then do
      decoded = .LdapWireCodec~decodeSearchEntry(msg["opValue"])
      if \decoded["ok"] then return .DirectoryResult~failure(decoded["code"])
      stateControl = .LdapWireCodec~findControl(msg["controls"], .LdapSyncBuild~STATE_OID)
      if stateControl == .nil then return .DirectoryResult~failure("LDAP_SYNC_STATE_CONTROL_REQUIRED")
      state = .LdapSyncCodec~decodeStateControl(stateControl)
      if \state["ok"] then return .DirectoryResult~failure(state["code"])
      entry = decoded["entry"]
      entityId = entry~attributes~first("oorexxEntityId")
      records~append(.LdapSyncRecord~new(state["state"], entry, .LdapSyncCodec~uuidText(state["entryUuid"]), entityId))
      if state["cookie"] <> .nil then nextCookie = state["cookie"]
      iterate
    end
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_DONE then do
      result = .LdapWireCodec~decodeResult(msg["opValue"])
      if \result["ok"] then return .DirectoryResult~failure(result["code"])
      if result["resultCode"] = .LdapSyncBuild~REFRESH_REQUIRED then return .DirectoryResult~failure("SYNC_REFRESH_REQUIRED", result["diagnostic"])
      if result["resultCode"] <> 0 then return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"], result["diagnostic"])
      doneControl = .LdapWireCodec~findControl(msg["controls"], .LdapSyncBuild~DONE_OID)
      if doneControl == .nil then return .DirectoryResult~failure("LDAP_SYNC_DONE_CONTROL_REQUIRED")
      done = .LdapSyncCodec~decodeDoneControl(doneControl)
      if \done["ok"] then return .DirectoryResult~failure(done["code"])
      if done["cookie"] <> .nil then nextCookie = done["cookie"]
      refreshDeletes = done["refreshDeletes"]
      return .DirectoryResult~success(.LdapSyncBatch~new(records, nextCookie, refreshDeletes))
    end
    return .DirectoryResult~failure("LDAP_SYNC_RESPONSE_INVALID")
  end
::method syncRefreshAndPersist
  expose socket connected
  use strict arg baseDn, scope = "SUB", filterText = "(objectClass=*)", attributes = .nil, cookie = .nil
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  id = self~allocateId
  syncControl = .LdapSyncCodec~requestControl("REFRESH_AND_PERSIST", cookie, .false, .true)
  bytes = .LdapWireCodec~encodeSearchRequest(id, baseDn, scope, filterText, attributes, 0, 0, .false, .array~of(syncControl))
  if \.LdapSocketIO~sendAll(socket, bytes) then return .DirectoryResult~failure("LDAP_SEND_FAILED")
  refresh = .array~new; newestCookie = ""
  do forever
    rr = self~readForMessage(id)
    if \rr~ok then return rr
    msg = rr~value
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_ENTRY then do
      decoded = .LdapWireCodec~decodeSearchEntry(msg["opValue"]); if \decoded["ok"] then return .DirectoryResult~failure(decoded["code"])
      sc = .LdapWireCodec~findControl(msg["controls"], .LdapSyncBuild~STATE_OID); if sc == .nil then return .DirectoryResult~failure("LDAP_SYNC_STATE_CONTROL_REQUIRED")
      state = .LdapSyncCodec~decodeStateControl(sc); if \state["ok"] then return .DirectoryResult~failure(state["code"])
      entry = decoded["entry"]; entityId = entry~attributes~first("oorexxEntityId")
      refresh~append(.LdapSyncRecord~new(state["state"], entry, .LdapSyncCodec~uuidText(state["entryUuid"]), entityId))
      if state["cookie"] <> .nil then newestCookie = state["cookie"]
      iterate
    end
    if msg["opTag"] = .LdapWireCodec~OP_INTERMEDIATE_RESPONSE then do
      ir = .LdapWireCodec~decodeIntermediateResponse(msg["opValue"]); if \ir["ok"] then return .DirectoryResult~failure(ir["code"])
      if ir["responseName"] <> .LdapSyncBuild~INFO_OID | ir["responseValue"] == .nil then return .DirectoryResult~failure("LDAP_SYNC_INFO_INVALID")
      info = .LdapSyncCodec~decodeInfoValue(ir["responseValue"]); if \info["ok"] then return .DirectoryResult~failure(info["code"])
      if info["cookie"] <> .nil then newestCookie = info["cookie"]
      if info["kind"] = "REFRESH" & info["refreshDone"] then return .DirectoryResult~success(.LdapSyncSubscription~new(self,id,refresh,newestCookie,info["refreshDeletes"]))
      iterate
    end
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_DONE then do
      result = .LdapWireCodec~decodeResult(msg["opValue"]); if \result["ok"] then return .DirectoryResult~failure(result["code"])
      if result["resultCode"] = .LdapSyncBuild~REFRESH_REQUIRED then return .DirectoryResult~failure("SYNC_REFRESH_REQUIRED",result["diagnostic"])
      return .DirectoryResult~failure("LDAP_SYNC_PERSIST_TERMINATED",result["diagnostic"])
    end
    return .DirectoryResult~failure("LDAP_SYNC_RESPONSE_INVALID")
  end
::method syncNextPersistentEvent
  expose socket connected
  use strict arg messageId
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  do forever
    rr = self~readForMessage(messageId)
    if \rr~ok then return rr
    msg = rr~value
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_ENTRY then do
      decoded=.LdapWireCodec~decodeSearchEntry(msg["opValue"]); if \decoded["ok"] then return .DirectoryResult~failure(decoded["code"])
      sc=.LdapWireCodec~findControl(msg["controls"],.LdapSyncBuild~STATE_OID); if sc==.nil then return .DirectoryResult~failure("LDAP_SYNC_STATE_CONTROL_REQUIRED")
      state=.LdapSyncCodec~decodeStateControl(sc); if \state["ok"] then return .DirectoryResult~failure(state["code"])
      entry=decoded["entry"]; entityId=entry~attributes~first("oorexxEntityId")
      event=.directory~new; event["kind"]="ENTRY"; event["record"]=.LdapSyncRecord~new(state["state"],entry,.LdapSyncCodec~uuidText(state["entryUuid"]),entityId); event["cookie"]=state["cookie"]
      return .DirectoryResult~success(event)
    end
    if msg["opTag"] = .LdapWireCodec~OP_INTERMEDIATE_RESPONSE then do
      ir=.LdapWireCodec~decodeIntermediateResponse(msg["opValue"]); if \ir["ok"] then return .DirectoryResult~failure(ir["code"])
      if ir["responseName"]<>.LdapSyncBuild~INFO_OID | ir["responseValue"]==.nil then return .DirectoryResult~failure("LDAP_SYNC_INFO_INVALID")
      info=.LdapSyncCodec~decodeInfoValue(ir["responseValue"]); if \info["ok"] then return .DirectoryResult~failure(info["code"])
      event=.directory~new; event["kind"]=info["kind"]; event["cookie"]=info["cookie"]; event["info"]=info; return .DirectoryResult~success(event)
    end
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_DONE then do
      result=.LdapWireCodec~decodeResult(msg["opValue"]); if \result["ok"] then return .DirectoryResult~failure(result["code"])
      if result["resultCode"]=.LdapSyncBuild~REFRESH_REQUIRED then return .DirectoryResult~failure("SYNC_REFRESH_REQUIRED",result["diagnostic"])
      return .DirectoryResult~failure("LDAP_SYNC_PERSIST_TERMINATED",result["diagnostic"])
    end
    return .DirectoryResult~failure("LDAP_SYNC_RESPONSE_INVALID")
  end

::method cancelOperation
  expose socket connected
  use strict arg targetMessageId
  if \connected then return .DirectoryResult~failure("LDAP_NOT_CONNECTED")
  cancelId = self~allocateId
  requestValue = .LdapCancelCodec~encodeRequestValue(targetMessageId)
  r = self~sendAndRead(.LdapWireCodec~encodeExtendedRequest(cancelId,.LdapCancelBuild~CANCEL_OID,requestValue), cancelId)
  if \r~ok then return r
  msg = r~value
  if msg["opTag"] <> .LdapWireCodec~OP_EXTENDED_RESPONSE then return .DirectoryResult~failure("LDAP_CANCEL_RESPONSE_INVALID")
  result = .LdapWireCodec~decodeExtendedResponse(msg["opValue"])
  if \result["ok"] then return .DirectoryResult~failure(result["code"])
  if result["resultCode"] = 0 then return .DirectoryResult~success(.true)
  if result["resultCode"] = .LdapCancelBuild~RESULT_NO_SUCH_OPERATION then return .DirectoryResult~failure("LDAP_CANCEL_NO_SUCH_OPERATION",result["diagnostic"])
  if result["resultCode"] = .LdapCancelBuild~RESULT_TOO_LATE then return .DirectoryResult~failure("LDAP_CANCEL_TOO_LATE",result["diagnostic"])
  if result["resultCode"] = .LdapCancelBuild~RESULT_CANNOT_CANCEL then return .DirectoryResult~failure("LDAP_CANCEL_CANNOT_CANCEL",result["diagnostic"])
  return .DirectoryResult~failure("LDAP_RESULT_" || result["resultCode"],result["diagnostic"])
::method awaitSearchCanceled
  use strict arg targetMessageId
  do forever
    r = self~readForMessage(targetMessageId)
    if \r~ok then return r
    msg = r~value
    /* Responses already emitted before the Cancel took effect are legal and
     * remain part of the canceled operation.  Consume them until its terminal
     * SearchResultDone arrives. */
    if msg["opTag"] = .LdapWireCodec~OP_SEARCH_ENTRY | msg["opTag"] = .LdapWireCodec~OP_INTERMEDIATE_RESPONSE then iterate
    if msg["opTag"] <> .LdapWireCodec~OP_SEARCH_DONE then return .DirectoryResult~failure("LDAP_CANCEL_TARGET_RESPONSE_INVALID")
    result = .LdapWireCodec~decodeResult(msg["opValue"])
    if \result["ok"] then return .DirectoryResult~failure(result["code"])
    if result["resultCode"] = .LdapCancelBuild~RESULT_CANCELED then return .DirectoryResult~success(.true)
    return .DirectoryResult~failure("LDAP_CANCEL_TARGET_NOT_CANCELED",result["resultCode"])
  end

::method unbind
  expose socket connected tlsActive
  if \connected then return .true
  id = self~allocateId
  ignore = .LdapSocketIO~sendAll(socket, .LdapWireCodec~encodeUnbindRequest(id))
  .LdapSocketIO~close(socket)
  socket = .nil
  connected = .false
  tlsActive = .false
  return .true

::class LdapSyncSubscription public
::attribute refreshRecords get
::attribute cookie get
::attribute refreshDeletes get
::attribute messageId get
::method init
  expose client messageId refreshRecords cookie refreshDeletes closed
  use strict arg clientArg,messageIdArg,refreshArg,cookieArg="",refreshDeletesArg=.false
  client=clientArg; messageId=messageIdArg; refreshRecords=refreshArg; cookie=cookieArg~string; refreshDeletes=refreshDeletesArg; closed=.false
::method next
  expose client messageId cookie closed
  if closed then return .DirectoryResult~failure("LDAP_SYNC_SUBSCRIPTION_CLOSED")
  r=client~syncNextPersistentEvent(messageId)
  if r~ok then do
    e=r~value
    if e["cookie"]<>.nil then cookie=e["cookie"]~string
  end
  return r
::method close
  expose client messageId closed
  if closed then return .DirectoryResult~success(.true)
  canceled = client~cancelOperation(messageId)
  if \canceled~ok then return canceled
  completed = client~awaitSearchCanceled(messageId)
  if completed~ok then closed = .true
  return completed

::requires "src/LdapSocketIO.cls"
::requires "src/LdapCancel.cls"
::requires "src/LdapBer.cls"
::requires "src/LdapPaging.cls"
::requires "src/LdapSync.cls"
::requires "src/LdapTls.cls"
