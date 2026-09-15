/* Virtual Browser v0.9 shared-observation/application-runtime/API mesh test */
route=.ApiRouteRequirement~new("US","LEGAL-EU","VPN","CONTROLLED",.array~of("MAIL"))
er=.ApiEgressRegistry~new
er~advertise(.ApiEgressNode~new("NODE-Z",.array~of("US"),.array~of("LEGAL-EU"),.array~of("VPN"),.array~of("CONTROLLED"),.array~of("MAIL"),4,7,"egress-proof"))
sm=.ApiSessionManager~new(er,"NODE-Z")
transport=.HtmlFixtureTransport~new
api=.ApiClient~new(transport,.nil,.nil,.nil,sm)
network=.ApiClientVirtualNetworkAdapter~new(api)
policy=.VirtualResourcePolicy~new(8,2,30000)
js=.FixtureJsRuntime~new
engine=.VirtualBrowserEngine~new(network,.BasicHtmlDocumentFactory~new,policy,js)

commands=.array~new
commands~append(.VirtualBrowserCommand~new("NAVIGATE","","","","https://mail.example.test/login"))
commands~append(.VirtualBrowserCommand~new("SET_VALUE","TEXTBOX","Username","support user"))
commands~append(.VirtualBrowserCommand~new("SET_VALUE","TEXTBOX","Password","credential-capability-value"))
commands~append(.VirtualBrowserCommand~new("ACTIVATE","BUTTON","Sign in"))
commands~append(.VirtualBrowserCommand~new("RUN_TIMERS","","","",1000))
commands~append(.VirtualBrowserCommand~new("RUN_TIMERS","","","",30000))
commands~append(.VirtualBrowserCommand~new("READ_TEXT","ARTICLE","Newest support message"))
lease=.PlacementLeaseFixture~new("PLACE-1-VB-JOB-1","VB-JOB-1","NODE-Z",11)
req=.VirtualBrowserRequest~new("VB-JOB-1","OWNER-UK","NODE-Z",lease,route,"RESEARCH",25,500000,250000,commands)
result=engine~execute(req,1000)
if \result~ok then call fail "browser execution:" result~code
if result~outputs~items<>3 then call fail "unexpected outputs"
if result~outputs[1]<>0 then call fail "short timer fired"
if result~outputs[2]<>1 then call fail "clamped timer did not fire"
if result~outputs[3]<>"Printer service unavailable" then call fail "wrong output:" result~outputs[3]
if result~session~document~title<>"Support inbox" then call fail "HTML title parse"
if result~session~requestCount<>5 then call fail "unexpected network count:" result~session~requestCount
if result~session~cookieJar~count<>1 then call fail "cookie not captured"
if js~attachCount<>2 then call fail "JS realm not attached per document"
if js~executeCount<>2 then call fail "inline/external scripts not executed"
if js~eventCount<>1 then call fail "click event not dispatched"
if js~timerCount<>1 then call fail "timer not dispatched"
if js~lastCookie<>"" then call fail "HttpOnly cookie leaked to script"
if transport~cookieSeenCount<>3 then call fail "cookie not replayed on governed requests:" transport~cookieSeenCount
if sm~activeCount<>0 then call fail "egress session leaked"

/* Browser observation port is deliberately terminal-observer shaped. */
observer=result~session~observationPort
if observer~sessionId<>result~session~id then call fail "observer session identity"
if observer~terminalType<>"VIRTUAL-BROWSER" then call fail "observer terminal type"
if observer~deviceName<>"NODE-Z" then call fail "observer device/execution identity"
snap=observer~snapshot
if snap==.nil then call fail "observer snapshot missing"
if snap~generation<2 then call fail "observer generation did not advance"
if snap~terminalType<>"VIRTUAL-BROWSER" then call fail "snapshot terminal type"
if snap~visibleText~pos("Printer service unavailable")=0 then call fail "semantic page not observable"
if observer~current~generation<>snap~generation then call fail "current mismatch"
if observer~history~items<4 then call fail "observer history too short"
if observer~back(1)==.nil then call fail "observer back missing"
if observer~knownStateStatus<>"UNTRACKED" then call fail "known-state compatibility"
contract=.ObservationProtocol~validateObserver(observer)
if \contract~ok then call fail "shared observation contract rejected browser"
monitor=.SemanticObservationMonitor~new
envelope=monitor~capture(observer)
if envelope==.nil then call fail "shared observation capture missing"
if envelope~terminalType<>"VIRTUAL-BROWSER" then call fail "shared observation envelope type"
rendered=monitor~render(observer)
if rendered~pos("Type: VIRTUAL-BROWSER")=0 then call fail "monitor not protocol-shaped"
if rendered~pos("Support inbox")=0 then call fail "monitor semantic render missing"
if monitor~delta(observer)~pos("GENERATION")=0 then call fail "monitor delta missing"

/* Earlier login observation must retain a non-display password field without secret value. */
secretSeen=.false
do oldSnap over observer~history
  secretField=oldSnap~field("p")
  if secretField<>.nil then do
    secretSeen=.true
    if \secretField~nonDisplay then call fail "password field not marked non-display"
    if secretField~value<>"" then call fail "password leaked through observer"
  end
end
if \secretSeen then call fail "login password evidence not retained"

/* Rendering resources remain suppressed before API Client. */
r=result~session~fetchResource("GET","https://mail.example.test/logo.png","IMAGE")
if r~errorCode<>"RESOURCE_POLICY_BLOCKED" then call fail "image not blocked"
if result~session~requestCount<>5 then call fail "blocked image consumed network"

/* Route and placement remain hard constraints. */
badRoute=.ApiRouteRequirement~new("US","OTHER-VPN","VPN","CONTROLLED",.array~of("MAIL"))
badCommands=.array~of(.VirtualBrowserCommand~new("NAVIGATE","","","","https://mail.example.test/login"))
badReq=.VirtualBrowserRequest~new("VB-JOB-2","OWNER-UK","NODE-Z",.PlacementLeaseFixture~new("P2","VB-JOB-2","NODE-Z",11),badRoute,"RESEARCH",25,1,1,badCommands)
bad=engine~execute(badReq,1000)
if bad~code<>"ROUTE_UNAVAILABLE" then call fail "route failure softened"
wrong=.VirtualBrowserRequest~new("VB-JOB-3","OWNER-UK","NODE-X",.PlacementLeaseFixture~new("P3","VB-JOB-3","NODE-Z",11),route,"RESEARCH",25,1,1,badCommands)
wrongResult=engine~execute(wrong,1000)
if wrongResult~code<>"PLACEMENT_CONTEXT_INVALID" then call fail "placement mismatch not rejected"

stream=.ObservationStream~new("VBSTREAM-1",observer)
rec=stream~publish
if rec==.nil | rec~generation<>observer~snapshot~generation then call fail "browser stream publish"
sub=stream~subscribe
if stream~read(sub,10)~items<>1 then call fail "browser stream read"
checkpoint=stream~latestCheckpoint
if checkpoint~sessionId<>observer~sessionId then call fail "browser stream checkpoint identity"
router=.ObservationQueryRouter~new
qr=router~execute(observer,.ObservationQueryEnvelope~new("VBQ1","SNAPSHOT"))
if \qr~ok then call fail "browser generic observation query"
forbidden=router~execute(observer,.ObservationQueryEnvelope~new("VBQ2","ACTIVATE"))
if forbidden~code<>"OBSERVATION_MUTATION_FORBIDDEN" then call fail "browser control leaked into observation"

/* Same real browser observer through the neutral gateway. */
gateway=.ObservationGateway~new(30)
if \gateway~registerStream(stream)~ok then call fail "browser gateway register"
if gateway~subscribe("AI-MONITOR","VBSTREAM-1",0)~code<>"OBSERVATION_ACCESS_DENIED" then call fail "browser gateway ACL"
gateway~grant("AI-MONITOR","VBSTREAM-1")
gs=gateway~subscribe("AI-MONITOR","VBSTREAM-1",0,30)
if \gs~ok then call fail "browser gateway subscribe"
gq=gateway~query(gs~value,.ObservationQueryEnvelope~new("VBQ3","CURRENT"),1)
if \gq~ok | \gq~value~ok then call fail "browser gateway query"
if gq~value~value~terminalType<>"VIRTUAL-BROWSER" then call fail "browser gateway type lost"
gmut=gateway~query(gs~value,.ObservationQueryEnvelope~new("VBQ4","ACTIVATE"),1)
if gmut~value~code<>"OBSERVATION_MUTATION_FORBIDDEN" then call fail "browser gateway mutation leaked"

/* v0.8 proves the real browser observer supports shared structural deltas,
   backpressure and external-authority gateway semantics. */
prev=observer~back(1); cur=observer~current
sd=.ObservationStructuralDeltaBuilder~between(prev,cur)
if sd~toGeneration<>cur~generation then call fail "browser structural delta generation"
auth=.BrowserObservationAuthorizer~new
gateway2=.ObservationGateway~new(30,auth)
stream2=.ObservationStream~new("VBSTREAM-2",observer,32)
gateway2~registerStream(stream2); stream2~publish
if gateway2~subscribe("AI-2","VBSTREAM-2",0)~code<>"OBSERVATION_ACCESS_DENIED" then call fail "browser external authority fail closed"
auth~allow("AI-2","VBSTREAM-2")
bl=gateway2~subscribe("AI-2","VBSTREAM-2",0,30,.nil,1)~value
if gateway2~read(bl,1,10)~value~items<>1 then call fail "browser credit first read"
if gateway2~read(bl,1,10)~value~items<>0 then call fail "browser backpressure"
if gateway2~ack(bl,1,1)~value<>1 then call fail "browser ack"
/* v0.9 proves the real browser observer can be registered/published/replayed
   through the neutral Observation Queue Service without browser-specific logic. */
producer=.ObservationProducerRegistration~new("VB-PRODUCER","NODE-Z","proof:vb",9)
qsvc=.BrowserObservationQueueManager~new
osvc=.ObservationQueueService~new(qsvc,"observation.queue","observation-service")
if \osvc~registerProducer(producer)~ok then call fail "browser service producer"
stream3=.ObservationStream~new("VBSTREAM-3",observer,32)
sr=osvc~registerStream("VB-PRODUCER",stream3)
if \sr~ok then call fail "browser service stream"
if sr~value~terminalType<>"VIRTUAL-BROWSER" then call fail "browser service descriptor type"
if sr~value~nodeId<>"NODE-Z" then call fail "browser service node identity"
if \osvc~publishLatest("VB-PRODUCER","VBSTREAM-3",10)~ok then call fail "browser service publish"
if qsvc~puts<>1 then call fail "browser service queue delivery"
rep=osvc~replay(.ObservationReplayRequest~new("VB-R1","AI-3","VBSTREAM-3",0,10))
if \rep~ok | rep~value~items<>1 then call fail "browser service replay"
cp=osvc~commitCheckpoint("AI-3","VBSTREAM-3",rep~value[1]~sequence,rep~value[1]~generation,11)
if \cp~ok then call fail "browser service checkpoint"
if osvc~checkpoint("AI-3","VBSTREAM-3")~sequence<>rep~value[1]~sequence then call fail "browser service checkpoint read"
say "PASS virtual browser v0.9 observation queue service shared observation scripts cookies timers host authority resource policy placement API mesh"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class HtmlFixtureTransport subclass ApiTransport
::attribute lastMethod get
::attribute lastBody get
::attribute cookieSeenCount get
::method init
  expose lastMethod lastBody cookieSeenCount
  lastMethod=""; lastBody=""; cookieSeenCount=0
::method execute
  expose lastMethod lastBody cookieSeenCount
  use arg request,session=.nil
  lastMethod=request~method; lastBody=request~body
  cookie=request~headers~at("Cookie"); if cookie==.nil then cookie=request~headers~at("cookie")
  if cookie<>.nil then if cookie~pos("SID=abc")>0 then cookieSeenCount+=1
  h=.directory~new
  if request~url="https://mail.example.test/login" then do
    html='<html><head><title>Sign in</title></head><body><form id="login" action="/inbox" method="post"><input id="u" name="username" aria-label="Username"><input id="p" name="password" type="password" aria-label="Password"><button id="s" aria-label="Sign in">Sign in</button></form><img src="/logo.png"></body></html>'
    return .ApiResponse~new(request~id,200,h,html,1)
  end
  if request~url="https://mail.example.test/inbox" & request~method="POST" then do
    h["Set-Cookie"]="SID=abc; Path=/; Secure; HttpOnly"
    html='<html><head><title>Support inbox</title></head><body><article id="m1" aria-label="Newest support message">Printer service unavailable</article><script>VB_FETCH_BOOTSTRAP</script><script src="/app.js"></script></body></html>'
    return .ApiResponse~new(request~id,200,h,html,1)
  end
  if request~url="https://mail.example.test/api/bootstrap" then return .ApiResponse~new(request~id,200,h,'{"ok":true}',1)
  if request~url="https://mail.example.test/app.js" then return .ApiResponse~new(request~id,200,h,'VB_SET_FAST_TIMER',1)
  if request~url="https://mail.example.test/poll" then return .ApiResponse~new(request~id,204,h,"",1)
  return .ApiResponse~new(request~id,404,h,"",1,"HTTP_404")

::class FixtureJsRuntime subclass VirtualJavaScriptRuntime
::attribute attachCount get
::attribute executeCount get
::attribute eventCount get
::attribute timerCount get
::attribute lastCookie get
::method init
  expose attachCount executeCount eventCount timerCount lastCookie
  attachCount=0; executeCount=0; eventCount=0; timerCount=0; lastCookie=""
::method attach
  expose attachCount lastCookie
  use arg session,document,host
  attachCount+=1; lastCookie=host~cookie
  return .true
::method execute
  expose executeCount lastCookie
  use arg session,code,sourceUrl,host
  executeCount+=1; lastCookie=host~cookie
  if code~pos("VB_FETCH_BOOTSTRAP")>0 then do
    r=host~fetch("GET","/api/bootstrap","",.nil,"FETCH")
    if \r~ok then return "FETCH_FAILED"
  end
  if code~pos("VB_SET_FAST_TIMER")>0 then host~setTimeout("POLL",250,0)
  return .nil
::method dispatchEvent
  expose eventCount
  use arg session,element,eventName,host=.nil
  eventCount+=1
  return .nil
::method dispatchTimer
  expose timerCount
  use arg session,token,host
  timerCount+=1
  if token="POLL" then host~fetch("GET","/poll","",.nil,"FETCH")
  return .nil

::class BrowserObservationAuthorizer subclass ObservationAuthorizer
::method init; expose grants; grants=.directory~new
::method allow; expose grants; use arg p,s; grants[p||"|"||s]=1
::method mayObserve; expose grants; use arg p,s; return grants~hasIndex(p||"|"||s)

::class PlacementLeaseFixture
::attribute placementId get
::attribute jobId get
::attribute nodeId get
::attribute capabilityGeneration get
::method init
  expose placementId jobId nodeId capabilityGeneration
  use arg p,j,n,g
  placementId=p; jobId=j; nodeId=n; capabilityGeneration=g
::method isExpired
  use arg now
  return .false


::class BrowserObservationQueueResult public
::attribute ok get
::method init; expose ok; use arg v; ok=v
::class BrowserObservationQueueManager public
::attribute puts get
::method init; expose puts; puts=0
::method put
  expose puts
  use arg queue,payload,options,principal
  puts+=1
  return .BrowserObservationQueueResult~new(.true)

::requires "src/VirtualBrowser.cls"
