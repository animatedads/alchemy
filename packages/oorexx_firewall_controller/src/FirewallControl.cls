/* ooRexx Queue Fabric Firewall Controller
 * API firewall.control/0.1
 *
 * Security model:
 *   - requesters REPORT one hostile source IPv4 address;
 *   - requesters do not choose CIDRs, timeouts, nftables tables or commands;
 *   - the gateway-side service derives /32 and /24 policy locally;
 *   - protected addresses/networks are checked before provider mutation;
 *   - Queue Fabric authenticated peer identity is bound to from_node;
 *   - changed-content reuse of request_id is rejected.
 */

::class FirewallControlBuild public
::constant VERSION "0.1-dev2"
::constant API "firewall.control/0.1"

::class FirewallControlContract public
::constant API "firewall.control/0.1"
::constant REQUEST_SCHEMA "firewall.control.request/1"
::constant RESPONSE_SCHEMA "firewall.control.response/1"
::constant SECURITY_DOMAIN "FIREWALL"
::constant REQUEST_QUEUE "FIREWALL.CONTROL.REQUEST"
::constant REPLY_PREFIX "FIREWALL.CONTROL.REPLY."
::constant EXACT_BLOCK_MINUTES 1440
::constant NET24_BLOCK_MINUTES 10

::class FirewallControlOperation public
::constant HEALTH "HEALTH"
::constant BLOCK_HOSTILE_SOURCE "BLOCK_HOSTILE_SOURCE"

::class FirewallControlCodec public
::method value class
  use strict arg d,key,defaultValue=""
  if d==.nil then return defaultValue
  if \d~isA(.Directory) then return defaultValue
  v=d[key]
  if v==.nil then return defaultValue
  return v

::method normaliseIpv4 class
  use strict arg valueArg
  ip=valueArg~string~strip
  if ip="" then return ""
  wordsIp=translate(ip," ",".")
  if words(wordsIp)<>4 then return ""
  a=word(wordsIp,1); b=word(wordsIp,2); c=word(wordsIp,3); d=word(wordsIp,4)
  if \self~validOctet(a) then return ""
  if \self~validOctet(b) then return ""
  if \self~validOctet(c) then return ""
  if \self~validOctet(d) then return ""
  return a||"."||b||"."||c||"."||d

::method validOctet class
  use strict arg oct
  if oct="" then return .false
  if \datatype(oct,"W") then return .false
  if length(oct)>1 then do
    if left(oct,1)="0" then return .false
  end
  if oct<0 then return .false
  if oct>255 then return .false
  return .true

::method network24 class
  use strict arg ipArg
  ip=self~normaliseIpv4(ipArg)
  if ip="" then return ""
  wordsIp=translate(ip," ",".")
  return word(wordsIp,1)||"."||word(wordsIp,2)||"."||word(wordsIp,3)||".0/24"

::method canonicalRequest class
  use strict arg request
  return self~value(request,"schema","")||"1F"x|| -
         self~value(request,"api","")||"1F"x|| -
         self~value(request,"request_id","")||"1F"x|| -
         self~value(request,"from_node","")||"1F"x|| -
         self~value(request,"to_node","")||"1F"x|| -
         self~value(request,"operation","")~upper||"1F"x|| -
         self~value(request,"source_ip","")||"1F"x|| -
         self~value(request,"reason","")||"1F"x|| -
         self~value(request,"evidence_id","")

::method newRequest class
  use strict arg requestId,fromNode,toNode,operation,sourceIp="",reason="",evidenceId=""
  d=.directory~new
  d["schema"]=.FirewallControlContract~REQUEST_SCHEMA
  d["api"]=.FirewallControlContract~API
  d["request_id"]=requestId~string
  d["from_node"]=fromNode~string
  d["to_node"]=toNode~string
  d["operation"]=operation~string~upper
  if sourceIp<>"" then d["source_ip"]=sourceIp~string
  if reason<>"" then d["reason"]=reason~string
  if evidenceId<>"" then d["evidence_id"]=evidenceId~string
  return d

::method response class
  use strict arg request,sourceNode,status,code,detail="",payload=.nil
  d=.directory~new
  d["schema"]=.FirewallControlContract~RESPONSE_SCHEMA
  d["api"]=.FirewallControlContract~API
  d["request_id"]=self~value(request,"request_id","")
  d["from_node"]=self~value(request,"from_node","")
  d["to_node"]=self~value(request,"to_node","")
  d["source_node"]=sourceNode~string
  d["operation"]=self~value(request,"operation","")~upper
  d["status"]=status~string~upper
  d["code"]=code~string
  d["detail"]=detail~string
  if payload<>.nil then d["payload"]=payload
  return d

::class FirewallPeerAccessPolicy public
::method init
  expose allowed
  allowed=.directory~new

::method allow
  expose allowed
  use strict arg peerNodeId
  id=peerNodeId~string~strip
  if id="" then raise syntax 88.900 array("firewall peer id is required")
  allowed[id]=.true
  return self

::method permits
  expose allowed
  use strict arg peerNodeId
  id=peerNodeId~string~strip
  if id="" then return .false
  return allowed[id]<>.nil

::class FirewallProtectedSources public
::method init
  expose exact net24 tokens
  exact=.directory~new
  net24=.directory~new
  tokens=.array~new
  /* Loopback can never be a hostile remote source. */
  self~protect("127.0.0.0/24")

::method protect
  expose exact net24 tokens
  use strict arg sourceArg
  source=sourceArg~string~strip
  if source="" then raise syntax 88.900 array("protected source cannot be empty")
  slash=pos("/",source)
  if slash=0 then do
    ip=.FirewallControlCodec~normaliseIpv4(source)
    if ip="" then raise syntax 88.900 array("invalid protected IPv4 address",source)
    exact[ip]=.true
    tokens~append(ip)
    return self
  end
  ipPart=substr(source,1,slash-1)
  prefix=substr(source,slash+1)
  if prefix<>"24" then raise syntax 88.900 array("v0.1 protected CIDR must be /24",source)
  net=.FirewallControlCodec~network24(ipPart)
  if net="" then raise syntax 88.900 array("invalid protected IPv4 /24",source)
  net24[net]=.true
  tokens~append(net)
  return self

::method isProtected
  expose exact net24
  use strict arg ipArg
  ip=.FirewallControlCodec~normaliseIpv4(ipArg)
  if ip="" then return .true
  if exact[ip]<>.nil then return .true
  net=.FirewallControlCodec~network24(ip)
  if net24[net]<>.nil then return .true
  return .false

::method all
  expose tokens
  copy=.array~new
  do item over tokens
    copy~append(item)
  end
  return copy

::class FirewallProviderResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use strict arg okArg,codeArg,detailArg=""
  ok=(okArg==.true)
  code=codeArg~string
  detail=detailArg~string
::method success class
  use strict arg codeArg="OK",detailArg=""
  return self~new(.true,codeArg,detailArg)
::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg)

/* Deterministic provider for qualification. */
::class FirewallMemoryProvider public
::method init
  expose exact net24 operations
  exact=.directory~new
  net24=.directory~new
  operations=.array~new
::method ensureReady
  use strict arg protectedSources
  return .FirewallProviderResult~success("READY")
::method block
  expose exact net24 operations
  use strict arg ip,network24,exactMinutes,networkMinutes
  exact[ip]=exactMinutes
  net24[network24]=networkMinutes
  operations~append(ip||"|"||network24||"|"||exactMinutes||"|"||networkMinutes)
  return .FirewallProviderResult~success("BLOCKED")
::method exactMinutes
  expose exact
  use strict arg ip
  v=exact[ip]
  if v==.nil then return 0
  return v
::method networkMinutes
  expose net24
  use strict arg network24
  v=net24[network24]
  if v==.nil then return 0
  return v
::method operationCount
  expose operations
  return operations~items

/* Linux nftables provider.  All untrusted values have already been reduced to
 * canonical decimal IPv4 and /24 strings.  The helper performs its own second
 * validation and owns nftables syntax. */
::class FirewallNftablesProvider public
::method init
  expose helperPath
  use strict arg helperPathArg
  helperPath=helperPathArg~string~strip
  if helperPath="" then raise syntax 88.900 array("nftables helper path is required")

::method ensureReady
  expose helperPath
  use strict arg protectedSources
  cmd='"'||helperPath||'" init'
  address system cmd
  if rc<>0 then return .FirewallProviderResult~failure("NFT_INIT_FAILED","rc="||rc)
  do source over protectedSources~all
    cmd='"'||helperPath||'" protect '||source
    address system cmd
    if rc<>0 then return .FirewallProviderResult~failure("NFT_PROTECT_FAILED",source||" rc="||rc)
  end
  return .FirewallProviderResult~success("READY")

::method block
  expose helperPath
  use strict arg ip,network24,exactMinutes,networkMinutes
  cmd='"'||helperPath||'" block '||ip||' '||network24||' '||exactMinutes||' '||networkMinutes
  address system cmd
  if rc<>0 then return .FirewallProviderResult~failure("NFT_BLOCK_FAILED","rc="||rc)
  return .FirewallProviderResult~success("BLOCKED")

::class FirewallReplayLedger public
::method init
  expose entries path
  use strict arg pathArg=""
  entries=.directory~new
  path=pathArg~string~strip
  if path<>"" then self~load

::method load
  expose entries path
  if stream(path,"C","QUERY EXISTS")="" then return
  s=.stream~new(path)
  ignore=s~open("READ")
  do while s~lines>0
    line=s~linein
    parse var line idHex "09"x canonicalHex "09"x codeHex
    if idHex="" then iterate
    id=x2c(idHex)
    canonical=x2c(canonicalHex)
    code=x2c(codeHex)
    d=.directory~new
    d["canonical"]=canonical
    d["code"]=code
    entries[id]=d
  end
  ignore=s~close

::method inspect
  expose entries
  use strict arg requestId,canonical
  d=entries[requestId]
  if d==.nil then return "NEW"
  if d["canonical"]=canonical then return "REPLAY:"||d["code"]
  return "CONFLICT"

::method remember
  expose entries path
  use strict arg requestId,canonical,code
  d=.directory~new
  d["canonical"]=canonical
  d["code"]=code
  entries[requestId]=d
  if path<>"" then do
    s=.stream~new(path)
    ignore=s~open("WRITE APPEND")
    ignore=s~lineout(c2x(requestId)||"09"x||c2x(canonical)||"09"x||c2x(code))
    ignore=s~close
  end
  return .true

::class FirewallReceiptStore public
::method init
  expose path
  use strict arg pathArg=""
  path=pathArg~string~strip
::method record
  expose path
  use strict arg request,authenticatedPeer,code,ip="",net=""
  if path="" then return .true
  line=date("S")||"T"||time("L")||"09"x|| -
       c2x(.FirewallControlCodec~value(request,"request_id",""))||"09"x|| -
       c2x(authenticatedPeer~string)||"09"x|| -
       c2x(.FirewallControlCodec~value(request,"operation",""))||"09"x|| -
       c2x(ip)||"09"x||c2x(net)||"09"x||c2x(code)
  s=.stream~new(path)
  ignore=s~open("WRITE APPEND")
  ignore=s~lineout(line)
  ignore=s~close
  return .true

::class FirewallControlService public
::method init
  expose nodeId provider protected access ledger receipts
  use strict arg nodeIdArg,providerArg,protectedArg,accessArg,ledgerArg=.nil,receiptArg=.nil
  nodeId=nodeIdArg~string~strip
  provider=providerArg
  protected=protectedArg
  access=accessArg
  if ledgerArg==.nil then ledger=.FirewallReplayLedger~new; else ledger=ledgerArg
  if receiptArg==.nil then receipts=.FirewallReceiptStore~new; else receipts=receiptArg
  if nodeId="" then raise syntax 88.900 array("firewall controller node id is required")
  if provider==.nil then raise syntax 88.900 array("firewall provider is required")
  if protected==.nil then raise syntax 88.900 array("protected-source registry is required")
  if access==.nil then raise syntax 88.900 array("peer access policy is required")

::method start
  expose provider protected
  return provider~ensureReady(protected)

::method handleFrom
  expose nodeId provider protected access ledger receipts
  use strict arg authenticatedPeerArg,request
  authenticatedPeer=authenticatedPeerArg~string~strip
  if authenticatedPeer="" then return .FirewallControlCodec~response(.directory~new,nodeId,"ERROR","AUTHENTICATED_PEER_REQUIRED")
  if \access~permits(authenticatedPeer) then return .FirewallControlCodec~response(request,nodeId,"DENIED","PEER_NOT_AUTHORISED")
  if request==.nil then return .FirewallControlCodec~response(.directory~new,nodeId,"ERROR","REQUEST_INVALID")
  if \request~isA(.Directory) then return .FirewallControlCodec~response(.directory~new,nodeId,"ERROR","REQUEST_INVALID")
  if .FirewallControlCodec~value(request,"schema","")<>.FirewallControlContract~REQUEST_SCHEMA then return .FirewallControlCodec~response(request,nodeId,"ERROR","CONTRACT_MISMATCH")
  if .FirewallControlCodec~value(request,"api","")<>.FirewallControlContract~API then return .FirewallControlCodec~response(request,nodeId,"ERROR","CONTRACT_MISMATCH")
  if .FirewallControlCodec~value(request,"to_node","")<>nodeId then return .FirewallControlCodec~response(request,nodeId,"ERROR","DESTINATION_MISMATCH")
  if .FirewallControlCodec~value(request,"from_node","")<>authenticatedPeer then return .FirewallControlCodec~response(request,nodeId,"DENIED","PEER_IDENTITY_MISMATCH")
  requestId=.FirewallControlCodec~value(request,"request_id","")~strip
  if requestId="" then return .FirewallControlCodec~response(request,nodeId,"ERROR","REQUEST_ID_REQUIRED")
  canonical=.FirewallControlCodec~canonicalRequest(request)
  replay=ledger~inspect(requestId,canonical)
  if replay="CONFLICT" then return .FirewallControlCodec~response(request,nodeId,"DENIED","REQUEST_ID_CONFLICT")
  if left(replay,7)="REPLAY:" then do
    previous=substr(replay,8)
    payload=.directory~new
    payload["replayed"]=.true
    payload["previous_code"]=previous
    return .FirewallControlCodec~response(request,nodeId,"OK","REPLAY","",payload)
  end
  op=.FirewallControlCodec~value(request,"operation","")~upper
  if op=.FirewallControlOperation~HEALTH then do
    ledger~remember(requestId,canonical,"HEALTHY")
    payload=.directory~new
    payload["node_id"]=nodeId
    payload["api"]=.FirewallControlContract~API
    payload["exact_block_minutes"]=.FirewallControlContract~EXACT_BLOCK_MINUTES
    payload["net24_block_minutes"]=.FirewallControlContract~NET24_BLOCK_MINUTES
    return .FirewallControlCodec~response(request,nodeId,"OK","HEALTHY","",payload)
  end
  if op<>.FirewallControlOperation~BLOCK_HOSTILE_SOURCE then return .FirewallControlCodec~response(request,nodeId,"ERROR","OPERATION_UNSUPPORTED")
  rawIp=.FirewallControlCodec~value(request,"source_ip","")
  ip=.FirewallControlCodec~normaliseIpv4(rawIp)
  if ip="" then return .FirewallControlCodec~response(request,nodeId,"DENIED","SOURCE_IP_INVALID")
  if protected~isProtected(ip) then do
    receipts~record(request,authenticatedPeer,"DENIED_PROTECTED_SOURCE",ip,"")
    ledger~remember(requestId,canonical,"DENIED_PROTECTED_SOURCE")
    return .FirewallControlCodec~response(request,nodeId,"DENIED","DENIED_PROTECTED_SOURCE")
  end
  net=.FirewallControlCodec~network24(ip)
  providerResult=provider~block(ip,net,.FirewallControlContract~EXACT_BLOCK_MINUTES,.FirewallControlContract~NET24_BLOCK_MINUTES)
  if \providerResult~ok then do
    receipts~record(request,authenticatedPeer,providerResult~code,ip,net)
    return .FirewallControlCodec~response(request,nodeId,"ERROR",providerResult~code,providerResult~detail)
  end
  ledger~remember(requestId,canonical,"BLOCKED")
  receipts~record(request,authenticatedPeer,"BLOCKED",ip,net)
  payload=.directory~new
  payload["source_ip"]=ip
  payload["network24"]=net
  payload["exact_block_minutes"]=.FirewallControlContract~EXACT_BLOCK_MINUTES
  payload["net24_block_minutes"]=.FirewallControlContract~NET24_BLOCK_MINUTES
  payload["reason"]=.FirewallControlCodec~value(request,"reason","")
  payload["evidence_id"]=.FirewallControlCodec~value(request,"evidence_id","")
  return .FirewallControlCodec~response(request,nodeId,"OK","BLOCKED","",payload)

/* Optional QueueRexx / Queue Fabric binding.  This consumes the existing
 * service-neutral bindServiceRoute() peer relationship and does not create a
 * second socket or trust model. */
::class FirewallQueueRexxBinding public
::method bindClient class
  use strict arg peerMesh,peerNodeId,clientId,principal="firewall-client",remoteRequestQueue="",timeoutMs=10000
  if remoteRequestQueue="" then remoteRequestQueue=.FirewallControlContract~REQUEST_QUEUE
  localReply=.FirewallControlContract~REPLY_PREFIX||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"FIREWALL.REQUEST."||clientId,localReply,remoteRequestQueue,.FirewallControlContract~SECURITY_DOMAIN,principal)
  if route==.nil then return route
  if \route~ok then return route
  ignore=peerMesh~queueManager~grant(localReply,principal,"GET",peerMesh~adminPrincipal)
  d=route~value
  transport=.FirewallQueueRexxClientTransport~new(peerMesh,d["remote_alias"],d["sender_channel"],localReply,principal,timeoutMs)
  return .FirewallBindingResult~success(transport,d)

::method bindServer class
  use strict arg peerMesh,peerNodeId,clientId,service,servicePrincipal="firewall-service",remoteReplyPrefix=""
  if remoteReplyPrefix="" then remoteReplyPrefix=.FirewallControlContract~REPLY_PREFIX
  requestQueue=.FirewallControlContract~REQUEST_QUEUE
  remoteReply=remoteReplyPrefix||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"FIREWALL.REPLY."||clientId,requestQueue,remoteReply,.FirewallControlContract~SECURITY_DOMAIN,servicePrincipal)
  if route==.nil then return route
  if \route~ok then return route
  ignore=peerMesh~queueManager~grant(requestQueue,servicePrincipal,"GET",peerMesh~adminPrincipal)
  d=route~value
  server=.FirewallQueueRexxServer~new(peerMesh,peerNodeId,service,requestQueue,d["remote_alias"],d["sender_channel"],servicePrincipal)
  return .FirewallBindingResult~success(server,d)

::class FirewallBindingResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::attribute route get
::method init
  expose ok code detail value route
  use strict arg okArg,codeArg,detailArg,valueArg=.nil,routeArg=.nil
  ok=(okArg==.true)
  code=codeArg~string
  detail=detailArg~string
  value=valueArg
  route=routeArg
::method success class
  use strict arg valueArg,routeArg=.nil
  return self~new(.true,"OK","",valueArg,routeArg)
::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg)

::class FirewallQueueRexxClientTransport public
::method init
  expose channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
  use strict arg peerMeshArg,requestAliasArg,requestChannelArg,replyQueueArg,principalArg,timeoutArg=10000
  channels=peerMeshArg~channels
  manager=peerMeshArg~queueManager
  listener=peerMeshArg~listener
  admin=peerMeshArg~adminPrincipal
  requestAlias=requestAliasArg~string
  requestChannel=requestChannelArg~string
  replyQueue=replyQueueArg~string
  localPrincipal=principalArg~string
  if \datatype(timeoutArg,"W") then raise syntax 88.900 array("firewall QueueRexx timeout must be a whole number")
  timeoutMs=timeoutArg
::method request
  expose channels manager requestAlias requestChannel replyQueue listener admin localPrincipal timeoutMs
  use strict arg peerNodeId,request
  if listener<>.nil then do
    if \listener~start then return .nil
    activity=.FirewallServeOneActivity~new(listener)
    ignore=activity~run
  end
  options=.table~new
  options["persistent"]=.true
  options["securityDomain"]=.FirewallControlContract~SECURITY_DOMAIN
  options["correlationId"]=.FirewallControlCodec~value(request,"request_id","")
  sent=channels~put(requestAlias,request,options,localPrincipal)
  if \sent~ok then return .nil
  pumped=channels~pump(requestChannel,0,admin)
  if \pumped~ok then return .nil
  loops=timeoutMs%25
  if loops<1 then loops=1
  do i=1 to loops
    got=self~nextReply(manager,replyQueue,localPrincipal,i)
    if got~ok then return got~value~payload
    if got~code<>"QUEUE_EMPTY" then return .nil
    call SysSleep 0.025
  end
  return .nil

::method nextReply
  use strict arg manager,replyQueue,localPrincipal,attemptNumber
  if attemptNumber<1 then return .nil
  return manager~get(replyQueue,localPrincipal)

::class FirewallQueueRexxClient public
::method init
  expose localNodeId transport counter
  use strict arg localNodeIdArg,transportArg
  localNodeId=localNodeIdArg~string~strip
  transport=transportArg
  counter=0
  if localNodeId="" then raise syntax 88.900 array("firewall client local node id required")
::method blockHostileSource
  expose localNodeId transport counter
  use strict arg peerNodeId,sourceIp,reason="HOSTILE_HTTPS_SCAN",evidenceId=""
  counter+=1
  requestId="firewall-"||localNodeId||"-"||counter||"-"||time("F")
  request=.FirewallControlCodec~newRequest(requestId,localNodeId,peerNodeId,.FirewallControlOperation~BLOCK_HOSTILE_SOURCE,sourceIp,reason,evidenceId)
  return transport~request(peerNodeId,request)
::method health
  expose localNodeId transport counter
  use strict arg peerNodeId
  counter+=1
  requestId="firewall-health-"||localNodeId||"-"||counter||"-"||time("F")
  request=.FirewallControlCodec~newRequest(requestId,localNodeId,peerNodeId,.FirewallControlOperation~HEALTH)
  return transport~request(peerNodeId,request)

::class FirewallServeOneActivity public
::method init
  expose listener
  use strict arg listenerArg
  listener=listenerArg
::method run
  expose listener
  reply .true
  ignore=listener~serveOne
  return

::class FirewallQueueRexxServer public
::method init
  expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
  use strict arg peerMeshArg,expectedPeerArg,serviceArg,requestQueueArg,replyAliasArg,replyChannelArg,principalArg
  expectedPeerNodeId=expectedPeerArg~string~strip
  service=serviceArg
  requestQueue=requestQueueArg~string
  replyAlias=replyAliasArg~string
  replyChannel=replyChannelArg~string
  servicePrincipal=principalArg~string
  manager=peerMeshArg~queueManager
  channels=peerMeshArg~channels
  admin=peerMeshArg~adminPrincipal
  if expectedPeerNodeId="" then raise syntax 88.900 array("firewall QueueRexx server requires authenticated peer identity")
::method processOne
  expose service expectedPeerNodeId requestQueue replyAlias replyChannel servicePrincipal manager channels admin
  got=manager~get(requestQueue,servicePrincipal)
  if \got~ok then return .FirewallBindingResult~failure(got~code,got~detail)
  response=service~handleFrom(expectedPeerNodeId,got~value~payload)
  options=.table~new
  options["persistent"]=.true
  options["securityDomain"]=.FirewallControlContract~SECURITY_DOMAIN
  options["correlationId"]=.FirewallControlCodec~value(response,"request_id","")
  sent=channels~put(replyAlias,response,options,servicePrincipal)
  if \sent~ok then return .FirewallBindingResult~failure(sent~code,sent~detail)
  pumped=channels~pump(replyChannel,0,admin)
  if \pumped~ok then return .FirewallBindingResult~failure(pumped~code,pumped~detail)
  return .FirewallBindingResult~success(response)
