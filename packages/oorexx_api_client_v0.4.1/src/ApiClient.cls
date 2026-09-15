/* ooRexx API Client v0.3
 * Enterprise outbound API execution and coordinated egress-session core.
 * This is deliberately not a curl wrapper.
 */

::class ApiClientBuild public
::constant VERSION "0.4"
::constant API "api.client/0.4"

::class ApiRouteRequirement public
::attribute country get
::attribute vpn get
::attribute network get
::attribute egressClass get
::attribute requiredTags get
::method init
  expose country vpn network egressClass requiredTags
  use arg countryArg="", vpnArg="", networkArg="", egressClassArg="", tagsArg=.nil
  country=countryArg~string~upper
  vpn=vpnArg~string~upper
  network=networkArg~string~upper
  egressClass=egressClassArg~string~upper
  if tagsArg==.nil then requiredTags=.array~new; else requiredTags=tagsArg
::method unconstrained
  expose country vpn network egressClass requiredTags
  return country="" & vpn="" & network="" & egressClass="" & requiredTags~items=0

::class ApiRequest public
::attribute id get
::attribute method get
::attribute url get
::attribute headers get
::attribute body get
::attribute trafficClass get
::attribute priority get
::attribute expectedMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute callbackName get
::attribute metadata get
::attribute routeRequirement get
::attribute originNodeId get
::method init
  expose id method url headers body trafficClass priority expectedMicroWlu requestedRateMicroWluPerSecond callbackName metadata routeRequirement originNodeId
  use arg idArg, methodArg, urlArg, headersArg=.nil, bodyArg="", trafficArg="INTERACTIVE", priorityArg=50, expectedArg=1000000, rateArg=1000000, callbackArg="", metadataArg=.nil, routeArg=.nil, originNodeArg=""
  id=idArg~string; method=methodArg~string~upper; url=urlArg~string
  if headersArg==.nil then headers=.directory~new; else headers=headersArg
  body=bodyArg
  trafficClass=trafficArg~string~upper
  priority=priorityArg+0
  if priority<0 then priority=0
  if priority>100 then priority=100
  expectedMicroWlu=expectedArg+0; requestedRateMicroWluPerSecond=rateArg+0
  callbackName=callbackArg~string
  if metadataArg==.nil then metadata=.directory~new; else metadata=metadataArg
  if routeArg==.nil then routeRequirement=.ApiRouteRequirement~new; else routeRequirement=routeArg
  originNodeId=originNodeArg~string

::class ApiResponse public
::attribute requestId get
::attribute status get
::attribute headers get
::attribute body get
::attribute elapsedMs get
::attribute errorCode get
::attribute retryAfterSeconds get
::attribute egressNodeId
::attribute sessionId
::attribute finalUrl
::attribute httpVersion
::attribute redirectCount
::method init
  expose requestId status headers body elapsedMs errorCode retryAfterSeconds egressNodeId sessionId finalUrl httpVersion redirectCount
  use arg requestId, status=0, headersArg=.nil, body="", elapsedMs=0, errorCode="", retryAfterSeconds=0, egressNodeArg="", sessionArg="", finalUrlArg="", httpVersionArg="", redirectCountArg=0
  if headersArg==.nil then headers=.directory~new; else headers=headersArg
  egressNodeId=egressNodeArg~string; sessionId=sessionArg~string
  finalUrl=finalUrlArg~string; httpVersion=httpVersionArg~string; redirectCount=redirectCountArg+0
::method ok
  expose status errorCode
  return errorCode="" & status>=200 & status<300

::class ApiCallbackRegistry public
::method init
  expose callbacks
  callbacks=.directory~new
::method register guarded
  expose callbacks
  use arg name, target, methodName="CALL"
  if name~string="" then raise syntax 88.900 array("callback name required")
  b=.directory~new; b["target"]=target; b["method"]=methodName~string~upper
  callbacks[name~string]=b
  return self
::method unregister guarded
  expose callbacks
  use arg name
  callbacks~remove(name~string)
::method invoke guarded
  expose callbacks
  use arg name, response, request
  if name~string="" then return .false
  b=callbacks~at(name~string)
  if b==.nil then return .false
  target=b["target"]; methodName=b["method"]
  target~sendWith(methodName, .array~of(response,request))
  return .true

::class ApiCompletionRouter public
::method deliver abstract

::class ApiLocalCompletionRouter subclass ApiCompletionRouter public
::method init
  expose callbacks
  use arg callbackRegistry
  callbacks=callbackRegistry
::method deliver
  expose callbacks
  use arg callbackName,response,request,session=.nil
  return callbacks~invoke(callbackName,response,request)

::class ApiRateWindow public
::attribute limit get
::attribute remaining get
::attribute resetEpoch get
::attribute retryAfterSeconds get
::method init
  expose limit remaining resetEpoch retryAfterSeconds
  limit=0; remaining=-1; resetEpoch=0; retryAfterSeconds=0
::method observe guarded
  expose limit remaining resetEpoch retryAfterSeconds
  use arg headers
  limit=self~headerNumber(headers,"x-ratelimit-limit",limit)
  remaining=self~headerNumber(headers,"x-ratelimit-remaining",remaining)
  resetEpoch=self~headerNumber(headers,"x-ratelimit-reset",resetEpoch)
  retryAfterSeconds=self~headerNumber(headers,"retry-after",0)
::method headerNumber private
  use arg headers,name,default
  v=headers~at(name); if v==.nil then v=headers~at(name~upper)
  if v==.nil then return default
  if \datatype(v~string,"N") then return default
  return v+0

::class ApiTrafficPolicy public
::method classWeight
  use arg trafficClass
  select
    when trafficClass="CONTROL" then return 1000
    when trafficClass="INTERACTIVE" then return 800
    when trafficClass="TRANSACTIONAL" then return 700
    when trafficClass="RESEARCH" then return 350
    when trafficClass="SOURCE_BULK" then return 200
    when trafficClass="NEWS_INGEST" then return 150
    otherwise return 300
  end
::method effectivePriority
  use arg request
  return self~classWeight(request~trafficClass) + request~priority

::class ApiEgressNode public
::attribute id get
::attribute countries get
::attribute vpns get
::attribute networks get
::attribute egressClasses get
::attribute tags get
::attribute maxSessions get
::attribute activeSessions get
::attribute generation get
::attribute proofRef get
::attribute online get
::method init
  expose id countries vpns networks egressClasses tags maxSessions activeSessions generation proofRef online
  use arg idArg, countriesArg=.nil, vpnsArg=.nil, networksArg=.nil, classesArg=.nil, tagsArg=.nil, maxArg=32, generationArg=1, proofArg=""
  id=idArg~string
  countries=self~toSet(countriesArg); vpns=self~toSet(vpnsArg); networks=self~toSet(networksArg)
  egressClasses=self~toSet(classesArg); tags=self~toSet(tagsArg)
  maxSessions=maxArg+0; activeSessions=0; generation=generationArg+0; proofRef=proofArg~string; online=.true
::method toSet private
  use arg values
  s=.directory~new
  if values==.nil then return s
  do v over values
    s[v~string~upper]=.true
  end
  return s
::method setOnline guarded
  expose online
  use arg value
  online=value
::method supports guarded
  expose countries vpns networks egressClasses tags maxSessions activeSessions online
  use arg route
  if \online then return .false
  if maxSessions>=0 & activeSessions>=maxSessions then return .false
  if route~country<>"" & countries~at(route~country)==.nil then return .false
  if route~vpn<>"" & vpns~at(route~vpn)==.nil then return .false
  if route~network<>"" & networks~at(route~network)==.nil then return .false
  if route~egressClass<>"" & egressClasses~at(route~egressClass)==.nil then return .false
  do tag over route~requiredTags
    if tags~at(tag~string~upper)==.nil then return .false
  end
  return .true
::method reserve guarded
  expose activeSessions maxSessions online
  if \online then return .false
  if maxSessions>=0 & activeSessions>=maxSessions then return .false
  activeSessions+=1
  return .true
::method release guarded
  expose activeSessions
  if activeSessions>0 then activeSessions-=1

::class ApiEgressRegistry public
::method init
  expose nodes
  nodes=.directory~new
::method advertise guarded
  expose nodes
  use arg node
  old=nodes~at(node~id)
  if old<>.nil then if old~generation>node~generation then return .false
  nodes[node~id]=node
  return .true
::method revoke guarded
  expose nodes
  use arg nodeId
  n=nodes~at(nodeId~string)
  if n<>.nil then n~setOnline(.false)
::method node guarded
  expose nodes
  use arg nodeId
  return nodes~at(nodeId~string)
::method eligible guarded
  expose nodes
  use arg route
  out=.array~new
  do nodeId over nodes
    n=nodes~at(nodeId)
    if n~supports(route) then out~append(n)
  end
  return out

::class ApiEgressSession public
::attribute id get
::attribute nodeId get
::attribute ownerNodeId get
::attribute requestId get
::attribute routeRequirement get
::attribute state get
::attribute node get
::method init
  expose id nodeId ownerNodeId requestId routeRequirement state node
  use arg idArg,nodeArg,ownerArg,requestArg,routeArg
  id=idArg~string; node=nodeArg; nodeId=nodeArg~id; ownerNodeId=ownerArg~string; requestId=requestArg~string; routeRequirement=routeArg; state="RESERVED"
::method activate
  expose state
  state="ACTIVE"
::method complete
  expose state
  state="COMPLETE"
::method fail
  expose state
  state="FAILED"

::class ApiSessionManager public
::method init
  expose registry localNodeId sequence sessions
  use arg registryArg, localNodeArg=""
  registry=registryArg; localNodeId=localNodeArg~string; sequence=0; sessions=.directory~new
::method acquire guarded
  expose registry localNodeId sequence sessions
  use arg route,requestId,ownerNodeId=""
  eligible=registry~eligible(route)
  if eligible~items=0 then return .nil
  chosen=.nil; chosenScore=-999999
  do n over eligible
    score=100000-n~activeSessions
    if n~id=localNodeId then score+=1000
    if score>chosenScore then do; chosen=n; chosenScore=score; end
  end
  if chosen==.nil then return .nil
  if \chosen~reserve then return .nil
  sequence+=1
  owner=ownerNodeId~string; if owner="" then owner=localNodeId
  sid="EGRESS-" || sequence || "-" || requestId
  s=.ApiEgressSession~new(sid,chosen,owner,requestId,route)
  sessions[sid]=s
  return s
::method release guarded
  expose sessions
  use arg session,success=.true
  if session==.nil then return
  if success then session~complete; else session~fail
  session~node~release
  sessions~remove(session~id)
::method activeCount guarded
  expose sessions
  return sessions~items

::class ApiAdmissionController public
/* WLU authority seam. Routing is resolved before admission so policy can account
 * for the actual egress/session selected for the work. */
::method init
  expose authority
  use arg authorityArg=.nil
  authority=authorityArg
::method assess
  expose authority
  use arg request,session=.nil
  if authority==.nil then return .ApiAdmissionDecision~allow(.nil)
  if authority~hasMethod("ASSESSROUTEDAPIREQUEST") then return authority~assessRoutedApiRequest(request,session)
  if authority~hasMethod("ASSESSAPIREQUEST") then return authority~assessApiRequest(request)
  return .ApiAdmissionDecision~deny("WLU_AUTHORITY_INCOMPATIBLE",0)

::class ApiAdmissionDecision public
::attribute allowed get
::attribute code get
::attribute retryAfterSeconds get
::attribute reservation get
::method init
  expose allowed code retryAfterSeconds reservation
  use arg allowedArg,codeArg="",retryArg=0,reservationArg=.nil
  allowed=allowedArg; code=codeArg; retryAfterSeconds=retryArg; reservation=reservationArg
::method allow class
  use arg r=.nil
  return self~new(.true,"",0,r)
::method deny class
  use arg code,retry=0
  return self~new(.false,code,retry,.nil)

::class ApiTransport public
::method execute abstract

::class ApiClient public
::attribute rateWindow get
::method init
  expose transport policy admission callbacks completionRouter sessionManager pending sequence rateWindow completed failed routeFailures
  use arg transportArg, admissionArg=.nil, callbacksArg=.nil, policyArg=.nil, sessionManagerArg=.nil, completionRouterArg=.nil
  transport=transportArg
  if admissionArg==.nil then admission=.ApiAdmissionController~new; else admission=admissionArg
  if callbacksArg==.nil then callbacks=.ApiCallbackRegistry~new; else callbacks=callbacksArg
  if policyArg==.nil then policy=.ApiTrafficPolicy~new; else policy=policyArg
  sessionManager=sessionManagerArg
  if completionRouterArg==.nil then completionRouter=.ApiLocalCompletionRouter~new(callbacks); else completionRouter=completionRouterArg
  pending=.array~new; sequence=0; rateWindow=.ApiRateWindow~new; completed=0; failed=0; routeFailures=0
::method submit guarded
  expose pending sequence
  use arg request
  sequence+=1
  e=.directory~new; e["request"]=request; e["sequence"]=sequence
  pending~append(e)
  return request~id
::method pendingCount guarded
  expose pending
  return pending~items
::method executeNext guarded
  expose pending policy
  if pending~items=0 then return .nil
  best=1; bestScore=-999999999; bestSeq=999999999
  do i=1 to pending~items
    e=pending[i]; score=policy~effectivePriority(e["request"])
    if score>bestScore | (score=bestScore & e["sequence"]<bestSeq) then do
      best=i; bestScore=score; bestSeq=e["sequence"]
    end
  end
  e=pending[best]; pending~delete(best)
  return self~perform(e["request"])
::method execute guarded
  use arg request
  if request==.nil then raise syntax 88.900 array("request is required")
  return self~perform(request)
::method perform private unguarded
  expose transport admission completionRouter sessionManager rateWindow completed failed routeFailures
  use arg request
  session=.nil
  if sessionManager<>.nil then do
    session=sessionManager~acquire(request~routeRequirement,request~id,request~originNodeId)
    if session==.nil then do
      response=.ApiResponse~new(request~id,0,.nil,"",0,"ROUTE_UNAVAILABLE",0,"","")
      failed+=1; routeFailures+=1
      ignore=completionRouter~deliver(request~callbackName,response,request,.nil)
      return response
    end
    session~activate
  end
  decision=admission~assess(request,session)
  if \decision~allowed then do
    nodeId=""; sid=""
    if session<>.nil then do; nodeId=session~nodeId; sid=session~id; sessionManager~release(session,.false); end
    response=.ApiResponse~new(request~id,0,.nil,"",0,decision~code,decision~retryAfterSeconds,nodeId,sid)
    failed+=1
    ignore=completionRouter~deliver(request~callbackName,response,request,session)
    return response
  end
  started=.dateTime~new~microseconds
  response=transport~execute(request,session)
  finished=.dateTime~new~microseconds
  if response~elapsedMs=0 then response~elapsedMs=((finished-started)%1000)
  if session<>.nil then do
    response~egressNodeId=session~nodeId; response~sessionId=session~id
  end
  rateWindow~observe(response~headers)
  success=response~ok
  if success then completed+=1; else failed+=1
  ignore=completionRouter~deliver(request~callbackName,response,request,session)
  if session<>.nil then sessionManager~release(session,success)
  return response
::method drain
  expose pending
  out=.array~new
  do while pending~items>0
    out~append(self~executeNext)
  end
  return out
::method metrics
  expose pending completed failed routeFailures rateWindow sessionManager
  d=.directory~new
  d["pending"]=pending~items; d["completed"]=completed; d["failed"]=failed; d["routeFailures"]=routeFailures
  d["rateLimit"]=rateWindow~limit; d["rateRemaining"]=rateWindow~remaining
  d["retryAfterSeconds"]=rateWindow~retryAfterSeconds
  if sessionManager==.nil then d["activeSessions"]=0; else d["activeSessions"]=sessionManager~activeCount
  return d
