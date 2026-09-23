/* LdapWireServer.cls
 * LDAPv3 TCP server for Identity Directory v0.1-dev9.
 *
 * Wire protocol, controls, StartTLS and Sync are conversation edges. Identity,
 * ACL, credential, key and replication semantics remain in the neutral core.
 */

::class LdapWireBuild public
::constant RELEASE "0.1-dev9"
::constant API_VERSION "ldap.wire/0.1"
::constant LDAP_VERSION 3
::constant EXECUTION_MODEL "WIRE_CONVERSATION_OVER_IDENTITY_DIRECTORY"

::class LdapWireServer public
::attribute host get
::attribute port get
::attribute namingContext get
::attribute running get
::method init
  expose service host port namingContext listener running tlsProvider syncProvider implicitTls syncPollSeconds syncHeartbeatSeconds activeClients schemaRegistry
  use strict arg serviceArg, hostArg = "127.0.0.1", portArg = 1389, namingContextArg = "dc=example,dc=org", tlsProviderArg = .nil, syncProviderArg = .nil, implicitTlsArg = .false, syncPollSecondsArg = 0.05, syncHeartbeatSecondsArg = 15, schemaRegistryArg = .nil
  service = serviceArg
  host = hostArg~string
  port = portArg
  namingContext = namingContextArg~string
  tlsProvider = tlsProviderArg
  if syncProviderArg == .nil then syncProvider = .LdapSyncProvider~new(service~directory, service~personality)
  else syncProvider = syncProviderArg
  implicitTls = implicitTlsArg
  syncPollSeconds = syncPollSecondsArg
  if syncPollSeconds <= 0 then syncPollSeconds = 0.05
  syncHeartbeatSeconds = syncHeartbeatSecondsArg
  if syncHeartbeatSeconds <= 0 then syncHeartbeatSeconds = 15
  listener = .nil
  running = .false
  activeClients = 0
  if schemaRegistryArg == .nil then schemaRegistry = .LdapSchemaRegistry~new
  else schemaRegistry = schemaRegistryArg
::method compatibilitySnapshot
  expose service tlsProvider syncProvider implicitTls
  d = .directory~new
  d["schema"] = "ldap.wire.capabilities/0.1"
  d["release"] = .LdapWireBuild~RELEASE
  d["ldapVersion"] = 3
  d["rootDse"] = .true
  d["simpleBind"] = .true
  d["anonymousBind"] = .true
  d["search"] = .true
  d["compare"] = .true
  d["add"] = .true
  d["delete"] = .true
  d["modifyDn"] = .true
  d["modify"] = .true
  tlsAvailable = .false
  if tlsProvider <> .nil then tlsAvailable = tlsProvider~available
  d["tls"] = tlsAvailable
  d["startTls"] = tlsAvailable & \implicitTls
  d["ldaps"] = tlsAvailable & implicitTls
  d["implicitTls"] = implicitTls
  d["sasl"] = service~saslMechanisms~items > 0
  d["generalControls"] = .true
  d["rfc2696PagedResults"] = .true
  d["pagedResultsAssociationLocal"] = .true
  d["pagedResultsRotatingCookies"] = .true
  d["pagedResultsMaxActivePerAssociation"] = 64
  d["rfc4533Sync"] = syncProvider <> .nil
  d["rfc4533RefreshOnly"] = syncProvider <> .nil
  d["rfc4533RefreshAndPersistNotifications"] = syncProvider <> .nil
  d["rfc4533RefreshAndPersist"] = syncProvider <> .nil
  d["rfc3909Cancel"] = .true
  d["rfc4533Cancel"] = .true
  d["messageIdDemultiplexing"] = .true
  d["persistentOperationDispatch"] = .true
  d["asyncAccept"] = .true
  /* Ordinary point operations remain serially executed by the single
   * association event loop. Persistent operations remain logically outstanding
   * and are advanced between reads; this is message multiplexing, not parallel
   * point-operation execution. */
  d["concurrentDispatch"] = .false
  d["rfc4514DnSyntax"] = .true
  d["dnComparisonProfile"] = .LdapDnBuild~COMPARISON_PROFILE
  d["rfc4515Filters"] = .true
  d["filterAndOrNot"] = .true
  d["filterEqualityPresenceSubstringOrderingApprox"] = .true
  d["filterExtensibleMatch"] = .false
  d["subschemaDiscovery"] = .true
  d["schemaEnforcement"] = .false
  d["semanticAuthority"] = .IdentityDirectoryBuild~API_VERSION
  d["vendorPolicyInCore"] = .false
  return d
::method serve unguarded
  expose host port listener running
  use strict arg maxConnections = 0, readyFile = ""
  listener = .Socket~new
  listener~setOption("SO_REUSEADDR", 1)
  address = .InetAddress~new(host, port)
  if listener~bind(address) < 0 then raise syntax 93.900 additional("LDAP wire bind failed errno=" || listener~errno)
  if listener~listen(32) < 0 then raise syntax 93.900 additional("LDAP wire listen failed errno=" || listener~errno)
  running = .true
  if readyFile <> "" then do
    call lineout readyFile, "READY " || host || ":" || port
    call stream readyFile, "C", "CLOSE"
  end
  say "oorexx LDAP wire listener on" host || ":" || port
  served = 0
  do while running
    client = listener~accept
    if client == .nil then leave
    if \running then do; client~close; leave; end
    self~clientStarted
    self~serveClientAsync(client)
    served += 1
    if maxConnections > 0 & served >= maxConnections then leave
  end
  running = .false
  if listener \== .nil then listener~close
  /* serve() owns the provider lifetime.  Do not return while asynchronous
   * client conversations are still using TLS, Sync or directory services. */
  do while self~activeClientCount > 0
    call syssleep 0.01
  end
  return served
::method clientStarted
  expose activeClients
  activeClients += 1
::method clientFinished
  expose activeClients
  if activeClients > 0 then activeClients -= 1
::method activeClientCount
  expose activeClients
  return activeClients
::method serveClientAsync unguarded
  use strict arg client
  reply
  self~serveClient(client)
  self~clientFinished
::method stop unguarded
  expose listener running
  running = .false
  if listener \== .nil then listener~close
::method serveClient unguarded
  expose service namingContext tlsProvider syncProvider implicitTls syncPollSeconds syncHeartbeatSeconds schemaRegistry
  use strict arg socket
  session = .LdapSession~new("anonymous", "", .false)
  transport = socket
  sender = .LdapAssociationSender~new(transport)
  registry = .LdapOperationRegistry~new
  pagingRegistry = .LdapPagingRegistry~new(socket~string || ":" || .DirectoryCanonical~dateTimeText(.DateTime~new))
  tlsActive = .false
  signal on syntax name clientFailure
  if value("LDAP_WIRE_DEBUG",,"ENVIRONMENT")="1" then say "LDAP DEBUG client socket=" socket~string
  if implicitTls then do
    if tlsProvider == .nil then do; .LdapSocketIO~close(socket); return; end
    if \tlsProvider~available then do; .LdapSocketIO~close(socket); return; end
    upgraded = tlsProvider~upgradeServer(socket)
    if \upgraded~ok then do; .LdapSocketIO~close(socket); return; end
    transport = .LdapTlsTransport~new(socket, upgraded~value)
    ignore = sender~replaceTransport(transport)
    tlsActive = .true
    session = .LdapSession~new("anonymous-ldaps", "", .false)
  end
  do forever
    self~pollPersistentOperations(sender,registry)
    reads = .array~of(socket); writes = .array~new; excepts = .array~new
    pollTimeout = 1
    if registry~activeCount > 0 then pollTimeout = syncPollSeconds
    selected = socket~select(reads,writes,excepts,pollTimeout)
    if selected == .nil then leave
    if selected = 0 then iterate
    frame = .LdapSocketIO~recvFrame(transport)
    if frame == .nil then leave
    msg = .LdapWireCodec~decodeMessage(frame)
    if \msg["ok"] then leave
    messageId = msg["messageId"]
    op = msg["opTag"]
    controls = msg["controls"]
    if value("LDAP_WIRE_DEBUG",,"ENVIRONMENT") = "1" then say "LDAP DEBUG op=" || op || " id=" || messageId

    allowedControls = .array~new
    if op = .LdapWireCodec~OP_SEARCH_REQUEST then do
      allowedControls~append(.LdapSyncBuild~REQUEST_OID)
      allowedControls~append(.LdapPagingBuild~CONTROL_OID)
    end
    badControl = self~unsupportedCriticalControl(controls, allowedControls)
    if badControl <> "" then do
      responseTag = self~responseTagFor(op)
      if responseTag = .LdapWireCodec~OP_EXTENDED_RESPONSE then self~sendExtended(sender, messageId, 12, "", "unavailable critical control " || badControl)
      else self~sendResult(sender, responseTag, messageId, 12, "", "unavailable critical control " || badControl)
      iterate
    end

    select
      when op = .LdapWireCodec~OP_UNBIND_REQUEST then leave

      when op = .LdapWireCodec~OP_EXTENDED_REQUEST then do
        req = .LdapWireCodec~decodeExtendedRequest(msg["opValue"])
        if \req["ok"] then do; self~sendExtended(sender,messageId,2,"",req["code"]); iterate; end

        if req["requestName"] = .LdapCancelBuild~CANCEL_OID then do
          if req["requestValue"] == .nil then do
            self~sendExtended(sender,messageId,2,"","Cancel requestValue required")
            iterate
          end
          cancelReq = .LdapCancelCodec~decodeRequestValue(req["requestValue"])
          if \cancelReq["ok"] then do
            self~sendExtended(sender,messageId,2,"",cancelReq["code"])
            iterate
          end
          cancelCode = registry~requestCancel(cancelReq["cancelId"])
          if cancelCode = 0 then do
            self~finishCanceledOperation(sender,registry,cancelReq["cancelId"])
            self~sendExtended(sender,messageId,0)
          end
          else if cancelCode = .LdapCancelBuild~RESULT_NO_SUCH_OPERATION then self~sendExtended(sender,messageId,cancelCode,"","no such outstanding operation")
          else if cancelCode = .LdapCancelBuild~RESULT_TOO_LATE then self~sendExtended(sender,messageId,cancelCode,"","operation already completed")
          else self~sendExtended(sender,messageId,.LdapCancelBuild~RESULT_CANNOT_CANCEL,"","operation cannot be canceled")
          iterate
        end

        if req["requestName"] <> .LdapTlsBuild~STARTTLS_OID then do
          self~sendExtended(sender,messageId,2,"","unsupported extended operation")
          iterate
        end
        if req["requestValue"] <> .nil then do
          self~sendExtended(sender,messageId,2,"","StartTLS requestValue must be absent",.LdapTlsBuild~STARTTLS_OID)
          iterate
        end
        if registry~activeCount > 0 then do
          self~sendExtended(sender,messageId,1,"","outstanding operations prevent StartTLS",.LdapTlsBuild~STARTTLS_OID)
          iterate
        end
        if tlsActive then do
          self~sendExtended(sender,messageId,1,"","TLS already active",.LdapTlsBuild~STARTTLS_OID)
          iterate
        end
        if tlsProvider == .nil then do
          self~sendExtended(sender,messageId,2,"","StartTLS unavailable",.LdapTlsBuild~STARTTLS_OID)
          iterate
        end
        if \tlsProvider~available then do
          self~sendExtended(sender,messageId,2,"","StartTLS unavailable",.LdapTlsBuild~STARTTLS_OID)
          iterate
        end
        /* RFC 4511: success is sent on the LDAP message layer before TLS
         * negotiation begins. No further LDAP PDU is read until handshake. */
        self~sendExtended(sender,messageId,0,"","",.LdapTlsBuild~STARTTLS_OID)
        upgraded = tlsProvider~upgradeServer(socket)
        if \upgraded~ok then leave
        transport = .LdapTlsTransport~new(socket, upgraded~value)
        ignore = sender~replaceTransport(transport)
        tlsActive = .true
        /* Establishing TLS changes the authentication state. Re-bind over the
         * protected layer rather than carrying plaintext attribution forward. */
        session = .LdapSession~new("anonymous-tls-" || messageId, "", .false)
      end

      when op = .LdapWireCodec~OP_BIND_REQUEST then do
        req = .LdapWireCodec~decodeBindRequest(msg["opValue"])
        if \req["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,2,"",req["code"]); iterate; end
        if req["version"] <> 3 then do; self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,2,"","LDAPv3 required"); iterate; end
        if req["authType"] = "SIMPLE" then do
          if req["name"] = "" & req["credential"] = "" then do
            session = .LdapSession~new("anonymous-" || messageId, "", .false)
            self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,0)
            iterate
          end
          bound = service~bind(req["name"], req["credential"])
          if \bound~ok then self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,49,"",bound~code)
          else do; session=bound~value; self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,0); end
        end
        else do
          bound = service~bindSasl(req["mechanism"], req["credential"], tlsActive)
          if \bound~ok then do
            code = self~saslResultCode(bound~code)
            self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,code,"",bound~code)
          end
          else do; session=bound~value; self~sendResult(sender,.LdapWireCodec~OP_BIND_RESPONSE,messageId,0); end
        end
      end

      when op = .LdapWireCodec~OP_SEARCH_REQUEST then do
        if value("LDAP_WIRE_DEBUG",,"ENVIRONMENT") = "1" then say "LDAP DEBUG search decode"
        req = .LdapWireCodec~decodeSearchRequest(msg["opValue"])
        if \req["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,2,"",req["code"]); iterate; end
        syncControl = .LdapWireCodec~findControl(controls,.LdapSyncBuild~REQUEST_OID)
        pagingControl = .LdapWireCodec~findControl(controls,.LdapPagingBuild~CONTROL_OID)
        if syncControl <> .nil & pagingControl <> .nil then do
          self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,53,"","RFC4533 Sync and RFC2696 paging controls cannot be combined")
          iterate
        end
        if syncControl <> .nil then do
          syncReq = .LdapSyncCodec~decodeRequestControl(syncControl)
          if \syncReq["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,2,"",syncReq["code"]); iterate; end
          auth = service~authorizeOperation(session,"LDAP_SEARCH",req["baseDn"])
          if \auth~ok then do; self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,self~directoryResultCode(auth~code),"",auth~code); iterate; end
          requested = self~requestedAttributes(req["attributes"])
          if syncReq["mode"] = "REFRESH_AND_PERSIST" then do
            operation = .LdapOutstandingOperation~new(messageId,"RFC4533_REFRESH_AND_PERSIST",.true)
            if \registry~register(operation) then do
              self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,1,"","duplicate outstanding message id")
              iterate
            end
            started = self~startSyncPersist(sender,registry,operation,req,requested,syncReq["cookie"])
            if \started then registry~complete(messageId)
            iterate
          end
          batchResult = syncProvider~refreshOnly(req["baseDn"],req["scope"],req["filterText"],requested,syncReq["cookie"],req["typesOnly"])
          if \batchResult~ok then do
            if batchResult~code="SYNC_REFRESH_REQUIRED" then self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,.LdapSyncBuild~REFRESH_REQUIRED,"",batchResult~code)
            else self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,53,"",batchResult~code)
            iterate
          end
          batch=batchResult~value
          do record over batch~records
            sc=.array~of(.LdapSyncCodec~stateControl(record~state,record~entryUuidBytes))
            if \sender~send(.LdapWireCodec~encodeSearchEntry(messageId,record~entry,req["typesOnly"],sc)) then return
          end
          doneControls=.array~of(.LdapSyncCodec~doneControl(batch~cookie,batch~refreshDeletes))
          self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,0,"","",doneControls)
          iterate
        end
        if req["baseDn"] = "" & req["scope"] = "BASE" then do
          root = self~rootDse(req["attributes"],tlsActive)
          roots = .array~of(root)
          self~sendSearchEntries(sender,messageId,req,roots,pagingControl,pagingRegistry)
          iterate
        end
        if req["scope"] = "BASE" & .LdapDn~equivalent(req["baseDn"], .LdapSchemaBuild~SUBSCHEMA_DN) then do
          schemaFull = schemaRegistry~entry(.nil)
          schemaEntries = .array~new
          if .LdapFilter~matches(req["filterText"], schemaFull) then schemaEntries~append(schemaRegistry~entry(req["attributes"]))
          self~sendSearchEntries(sender,messageId,req,schemaEntries,pagingControl,pagingRegistry)
          iterate
        end
        requested=self~requestedAttributes(req["attributes"])
        if value("LDAP_WIRE_DEBUG",,"ENVIRONMENT") = "1" then say "LDAP DEBUG search service begin " || req["filterText"]
        result=service~search(session,req["baseDn"],req["scope"],req["filterText"],requested)
        if value("LDAP_WIRE_DEBUG",,"ENVIRONMENT") = "1" then say "LDAP DEBUG search service end ok=" || result~ok
        if \result~ok then do; self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,self~directoryResultCode(result~code),"",result~code); iterate; end
        self~sendSearchEntries(sender,messageId,req,result~value,pagingControl,pagingRegistry)
      end

      when op = .LdapWireCodec~OP_COMPARE_REQUEST then do
        req=.LdapWireCodec~decodeCompareRequest(msg["opValue"])
        if \req["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_COMPARE_RESPONSE,messageId,2,"",req["code"]); iterate; end
        result=service~compare(session,req["dn"],req["attribute"],req["value"])
        if \result~ok then self~sendResult(sender,.LdapWireCodec~OP_COMPARE_RESPONSE,messageId,self~directoryResultCode(result~code),"",result~code)
        else if result~value then self~sendResult(sender,.LdapWireCodec~OP_COMPARE_RESPONSE,messageId,6)
        else self~sendResult(sender,.LdapWireCodec~OP_COMPARE_RESPONSE,messageId,5)
      end
      when op = .LdapWireCodec~OP_ADD_REQUEST then do
        req=.LdapWireCodec~decodeAddRequest(msg["opValue"])
        if \req["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_ADD_RESPONSE,messageId,2,"",req["code"]); iterate; end
        result=service~add(session,req["entry"])
        if result~ok then self~sendResult(sender,.LdapWireCodec~OP_ADD_RESPONSE,messageId,0)
        else self~sendResult(sender,.LdapWireCodec~OP_ADD_RESPONSE,messageId,self~directoryResultCode(result~code),"",result~code)
      end
      when op = .LdapWireCodec~OP_DELETE_REQUEST then do
        result=service~delete(session,msg["opValue"])
        if result~ok then self~sendResult(sender,.LdapWireCodec~OP_DELETE_RESPONSE,messageId,0)
        else self~sendResult(sender,.LdapWireCodec~OP_DELETE_RESPONSE,messageId,self~directoryResultCode(result~code),"",result~code)
      end
      when op = .LdapWireCodec~OP_MODDN_REQUEST then do
        req=.LdapWireCodec~decodeModifyDnRequest(msg["opValue"])
        if \req["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_MODDN_RESPONSE,messageId,2,"",req["code"]); iterate; end
        oldDn=req["dn"]
        oldParsed = .LdapDn~parse(oldDn)
        if \oldParsed~ok then do; self~sendResult(sender,.LdapWireCodec~OP_MODDN_RESPONSE,messageId,34,"","invalid DN syntax"); iterate; end
        if req["newSuperior"]<>"" then superior = req["newSuperior"]
        else superior = oldParsed~value~parentText
        composed = .LdapDn~compose(req["newRdn"], superior)
        if \composed~ok then do; self~sendResult(sender,.LdapWireCodec~OP_MODDN_RESPONSE,messageId,34,"",composed~code); iterate; end
        newDn = composed~value
        result=service~modifyDn(session,oldDn,newDn)
        if result~ok then self~sendResult(sender,.LdapWireCodec~OP_MODDN_RESPONSE,messageId,0)
        else self~sendResult(sender,.LdapWireCodec~OP_MODDN_RESPONSE,messageId,self~directoryResultCode(result~code),"",result~code)
      end
      when op = .LdapWireCodec~OP_MODIFY_REQUEST then do
        req=.LdapWireCodec~decodeModifyRequest(msg["opValue"])
        if \req["ok"] then do; self~sendResult(sender,.LdapWireCodec~OP_MODIFY_RESPONSE,messageId,2,"",req["code"]); iterate; end
        result=service~modify(session,req["dn"],req["modifications"])
        if result~ok then self~sendResult(sender,.LdapWireCodec~OP_MODIFY_RESPONSE,messageId,0)
        else self~sendResult(sender,.LdapWireCodec~OP_MODIFY_RESPONSE,messageId,self~directoryResultCode(result~code),"",result~code)
      end
      otherwise do
        self~sendExtended(sender,messageId,2,"","unsupported protocol operation")
        leave
      end
    end
  end
  registry~cancelAll("ASSOCIATION_CLOSED")
  self~discardOutstanding(registry)
  sender~markClosed
  .LdapSocketIO~close(transport)
  return
clientFailure:
  failure = condition("O")
  signal off syntax
  detail = ""
  if failure <> .nil then do
    if failure~hasIndex("MESSAGE") then detail = failure["MESSAGE"]
    if detail = "" & failure~hasIndex("ADDITIONAL") then detail = failure["ADDITIONAL"]
  end
  say "LDAP WIRE CLIENT FAILURE:" detail
  registry~cancelAll("ASSOCIATION_CLOSED")
  self~discardOutstanding(registry)
  sender~markClosed
  .LdapSocketIO~close(transport)
  return
::method startSyncPersist private unguarded
  expose syncProvider syncPollSeconds syncHeartbeatSeconds
  use strict arg sender, registry, operation, req, requested, cookie
  messageId = operation~messageId
  batchResult = syncProvider~refreshOnly(req["baseDn"],req["scope"],req["filterText"],requested,cookie,req["typesOnly"])
  if \batchResult~ok then do
    if batchResult~code="SYNC_REFRESH_REQUIRED" then self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,.LdapSyncBuild~REFRESH_REQUIRED,"",batchResult~code)
    else self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,53,"",batchResult~code)
    return .false
  end
  batch = batchResult~value
  do record over batch~records
    sc = .array~of(.LdapSyncCodec~stateControl(record~state,record~entryUuidBytes))
    if \sender~send(.LdapWireCodec~encodeSearchEntry(messageId,record~entry,req["typesOnly"],sc)) then return .false
  end
  infoValue = .LdapSyncCodec~infoRefresh(batch~refreshDeletes,batch~cookie,.true)
  if \sender~send(.LdapWireCodec~encodeIntermediateResponse(messageId,.LdapSyncBuild~INFO_OID,infoValue)) then return .false
  context = .directory~new
  context["req"] = req
  context["requested"] = requested
  context["cookie"] = batch~cookie
  context["idlePolls"] = 0
  heartbeatPolls = syncHeartbeatSeconds % syncPollSeconds
  if heartbeatPolls < 1 then heartbeatPolls = 1
  context["heartbeatPolls"] = heartbeatPolls
  operation~context = context
  return .true
::method pollPersistentOperations private unguarded
  expose syncProvider
  use strict arg sender, registry
  operations = registry~activeOperations
  do operation over operations
    if operation~operationType <> "RFC4533_REFRESH_AND_PERSIST" then iterate
    if operation~cancelRequested then do
      self~finishCanceledOperation(sender,registry,operation~messageId)
      iterate
    end
    context = operation~context
    if context == .nil then iterate
    req = context["req"]; requested = context["requested"]; currentCookie = context["cookie"]
    nextResult = syncProvider~refreshOnly(req["baseDn"],req["scope"],req["filterText"],requested,currentCookie,req["typesOnly"])
    if \nextResult~ok then do
      if nextResult~code="SYNC_REFRESH_REQUIRED" then self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,operation~messageId,.LdapSyncBuild~REFRESH_REQUIRED,"",nextResult~code)
      else self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,operation~messageId,53,"",nextResult~code)
      registry~complete(operation~messageId)
      iterate
    end
    nextBatch = nextResult~value
    if nextBatch~cookie = currentCookie then do
      context["idlePolls"] = context["idlePolls"] + 1
      if context["idlePolls"] >= context["heartbeatPolls"] then do
        infoValue = .LdapSyncCodec~infoNewCookie(currentCookie)
        if \sender~send(.LdapWireCodec~encodeIntermediateResponse(operation~messageId,.LdapSyncBuild~INFO_OID,infoValue)) then do
          registry~complete(operation~messageId)
          iterate
        end
        context["idlePolls"] = 0
      end
      iterate
    end
    context["idlePolls"] = 0
    count = nextBatch~records~items; index = 0
    do record over nextBatch~records
      index += 1; stateCookie = .nil
      if index = count then stateCookie = nextBatch~cookie
      sc = .array~of(.LdapSyncCodec~stateControl(record~state,record~entryUuidBytes,stateCookie))
      if \sender~send(.LdapWireCodec~encodeSearchEntry(operation~messageId,record~entry,req["typesOnly"],sc)) then do
        registry~complete(operation~messageId)
        leave
      end
    end
    if registry~lookup(operation~messageId) == .nil then iterate
    if count = 0 then do
      infoValue = .LdapSyncCodec~infoNewCookie(nextBatch~cookie)
      if \sender~send(.LdapWireCodec~encodeIntermediateResponse(operation~messageId,.LdapSyncBuild~INFO_OID,infoValue)) then do
        registry~complete(operation~messageId)
        iterate
      end
    end
    context["cookie"] = nextBatch~cookie
  end
  return .true
::method finishCanceledOperation private unguarded
  use strict arg sender, registry, messageId
  operation = registry~lookup(messageId)
  if operation == .nil then return .false
  if operation~cancelReason = "CLIENT_CANCEL" then self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,.LdapCancelBuild~RESULT_CANCELED,"","canceled")
  registry~complete(messageId)
  return .true
::method discardOutstanding private unguarded
  use strict arg registry
  operations = registry~activeOperations
  do operation over operations
    registry~complete(operation~messageId)
  end
  return .true

::method sendResult private unguarded
  use strict arg sender, appTag, messageId, resultCode, matchedDn = "", diagnostic = "", controls = .nil
  return sender~send(.LdapWireCodec~encodeResult(appTag,messageId,resultCode,matchedDn,diagnostic,controls))
::method sendExtended private unguarded
  use strict arg sender,messageId,resultCode,matchedDn="",diagnostic="",responseName=.nil,responseValue=.nil,controls=.nil
  return sender~send(.LdapWireCodec~encodeExtendedResponse(messageId,resultCode,matchedDn,diagnostic,responseName,responseValue,controls))
::method unsupportedCriticalControl private
  use strict arg controls, allowedOids = .nil
  do c over controls
    if \c~criticality then iterate
    allowed = .false
    if allowedOids <> .nil then do oid over allowedOids
      if c~controlType = oid then do; allowed = .true; leave; end
    end
    if \allowed then return c~controlType
  end
  return ""
::method sendSearchEntries private unguarded
  expose service
  use strict arg sender, messageId, req, entries, pagingControl = .nil, pagingRegistry = .nil
  if pagingControl <> .nil then do
    decoded = .LdapPagingCodec~decodeControl(pagingControl)
    if \decoded["ok"] then return self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,2,"",decoded["code"])
    pageSize = decoded["size"]
    /* RFC 2696 says a page size greater than or equal to a non-zero Search
     * sizeLimit can be ignored because the request is satisfiable as one page. */
    if \(decoded["cookie"] = "" & req["sizeLimit"] > 0 & pageSize >= req["sizeLimit"] & pageSize > 0) then do
      qk = .LdapPagingRegistry~queryKey(service~personality~name,req["baseDn"],req["scope"],req["filterText"],req["attributes"],req["typesOnly"],req["sizeLimit"],req["timeLimit"],req["derefAliases"])
      paged = pagingRegistry~page(qk,entries,pageSize,decoded["cookie"],req["sizeLimit"])
      if \paged~ok then return self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,53,"",paged~code)
      page = paged~value
      do entry over page~entries
        if \sender~send(.LdapWireCodec~encodeSearchEntry(messageId,entry,req["typesOnly"])) then return .false
      end
      responseControls = .array~of(.LdapPagingCodec~responseControl(page~estimatedSize,page~cookie))
      if page~resultCode = 4 then return self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,4,"","size limit exceeded",responseControls)
      return self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,0,"","",responseControls)
    end
  end
  limit=req["sizeLimit"]; count=0; limited=.false
  do entry over entries
    if limit>0 & count>=limit then do; limited=.true; leave; end
    if \sender~send(.LdapWireCodec~encodeSearchEntry(messageId,entry,req["typesOnly"])) then return .false
    count+=1
  end
  if limited then return self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,4,"","size limit exceeded")
  return self~sendResult(sender,.LdapWireCodec~OP_SEARCH_DONE,messageId,0)
::method responseTagFor private
  use strict arg op
  select
    when op=.LdapWireCodec~OP_BIND_REQUEST then return .LdapWireCodec~OP_BIND_RESPONSE
    when op=.LdapWireCodec~OP_SEARCH_REQUEST then return .LdapWireCodec~OP_SEARCH_DONE
    when op=.LdapWireCodec~OP_MODIFY_REQUEST then return .LdapWireCodec~OP_MODIFY_RESPONSE
    when op=.LdapWireCodec~OP_ADD_REQUEST then return .LdapWireCodec~OP_ADD_RESPONSE
    when op=.LdapWireCodec~OP_DELETE_REQUEST then return .LdapWireCodec~OP_DELETE_RESPONSE
    when op=.LdapWireCodec~OP_MODDN_REQUEST then return .LdapWireCodec~OP_MODDN_RESPONSE
    when op=.LdapWireCodec~OP_COMPARE_REQUEST then return .LdapWireCodec~OP_COMPARE_RESPONSE
    otherwise return .LdapWireCodec~OP_EXTENDED_RESPONSE
  end
::method saslResultCode private
  use strict arg code
  c=code~string~upper
  if c="SASL_CONFIDENTIALITY_REQUIRED" then return 13
  if c="SASL_MECHANISM_UNAVAILABLE" | c="SASL_NOT_CONFIGURED" then return 7
  return 49
::method directoryResultCode private
  use strict arg code
  code=code~string~upper
  if code="LDAP_NO_SUCH_OBJECT" | code="NO_SUCH_ENTITY" then return 32
  if code="ENTITY_EXISTS" | code="DN_EXISTS" | code="LDAP_ALREADY_EXISTS" then return 68
  if code="ACL_DENY" | code="ACL_DEFAULT_DENY" | code="LDAP_AUTHENTICATION_REQUIRED" | code="AUTHORITY_NOT_CONFIGURED" then return 50
  if code="NO_SUCH_OWNER" | code="NO_SUCH_SUBJECT" | code="NO_SUCH_RESOURCE" | code="NO_SUCH_PRINCIPAL" | code="NO_SUCH_GROUP" | code="NO_SUCH_MEMBER" | code="LDAP_NO_SUCH_MEMBER" then return 32
  if code="LDAP_NO_SUCH_ATTRIBUTE" then return 16
  if code="LDAP_ATTRIBUTE_OR_VALUE_EXISTS" then return 20
  if code="LDAP_ATTRIBUTE_IMMUTABLE" | code="LDAP_ATTRIBUTE_REQUIRED" | code="LDAP_SINGLE_VALUE_ATTRIBUTE" then return 19
  if code="LDAP_INVALID_DATETIME" then return 21
  if code="LDAP_INVALID_DN" | code="LDAP_INVALID_RDN" then return 34
  if code="LDAP_INVALID_FILTER" then return 87
  if code="LDAP_MODIFY_KIND_UNSUPPORTED" then return 53
  return 53
::method requestedAttributes private
  use strict arg names
  if names == .nil then return .nil
  if names~items=0 then return .nil
  do name over names; if name="*" then return .nil; end
  out=.array~new
  do name over names; if name<>"1.1" then out~append(name); end
  return out
::method rootDse private
  expose namingContext service tlsProvider syncProvider
  use strict arg requested,tlsActive=.false
  attrs=.LdapAttributeSet~new
  attrs~add("objectClass","top")
  attrs~add("namingContexts",namingContext)
  attrs~add("supportedLDAPVersion","3")
  attrs~add("vendorName","ooRexx Identity Directory")
  attrs~add("vendorVersion",.IdentityDirectoryBuild~RELEASE)
  attrs~add("subschemaSubentry","cn=subschema")
  if syncProvider<>.nil then attrs~add("supportedControl",.LdapSyncBuild~REQUEST_OID)
  attrs~add("supportedControl",.LdapPagingBuild~CONTROL_OID)
  attrs~add("supportedExtension",.LdapCancelBuild~CANCEL_OID)
  if tlsProvider<>.nil then if tlsProvider~available then attrs~add("supportedExtension",.LdapTlsBuild~STARTTLS_OID)
  do mechanism over service~saslMechanisms; attrs~add("supportedSASLMechanisms",mechanism); end
  entry=.LdapEntry~new("",attrs,"root-dse")
  selected=self~requestedAttributes(requested)
  if selected==.nil then return entry
  out=.LdapAttributeSet~new
  do name over selected; do value over attrs~get(name); out~add(name,value); end; end
  return .LdapEntry~new("",out,"root-dse")

::requires "src/LdapSchema.cls"
::requires "src/LdapSocketIO.cls"
::requires "src/LdapPaging.cls"
::requires "src/LdapCancel.cls"
::requires "src/LdapSync.cls"
::requires "src/LdapTls.cls"
::requires "src/LdapSecretBrokerAdapter.cls"
