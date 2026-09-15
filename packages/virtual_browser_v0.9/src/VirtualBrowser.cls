/* ooRexx Virtual Browser v0.4
 * Non-rendering, command-oriented web application execution core.
 * Network authority remains with API Client; placement authority remains with
 * Job-to-Node Allocation.  This component owns browser/application state.
 */

::class VirtualBrowserBuild public
::constant VERSION "0.4"
::constant API "virtual.browser/0.4"

::class VirtualBrowserRequest public
::attribute id get
::attribute ownerNodeId get
::attribute executionNodeId get
::attribute placementLease get
::attribute routeRequirement get
::attribute trafficClass get
::attribute priority get
::attribute expectedMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute commands get
::method init
  expose id ownerNodeId executionNodeId placementLease routeRequirement trafficClass priority expectedMicroWlu requestedRateMicroWluPerSecond commands
  use arg idArg, ownerArg, executionArg, placementArg=.nil, routeArg=.nil, trafficArg="INTERACTIVE", priorityArg=50, expectedArg=1000000, rateArg=1000000, commandsArg=.nil
  id=idArg~string; ownerNodeId=ownerArg~string; executionNodeId=executionArg~string
  placementLease=placementArg; routeRequirement=routeArg
  trafficClass=trafficArg~string~upper; priority=priorityArg+0
  expectedMicroWlu=expectedArg+0; requestedRateMicroWluPerSecond=rateArg+0
  if commandsArg==.nil then commands=.array~new; else commands=commandsArg

::class VirtualBrowserCommand public
::attribute operation get
::attribute role get
::attribute name get
::attribute value get
::attribute argument get
::method init
  expose operation role name value argument
  use arg operationArg, roleArg="", nameArg="", valueArg="", argumentArg=""
  operation=operationArg~string~upper; role=roleArg~string~upper; name=nameArg~string; value=valueArg; argument=argumentArg

::class VirtualResourcePolicy public
::attribute maxRequestsPerNavigation get
::attribute maxConcurrentPerOrigin get
::attribute minimumPollIntervalMs get
::method init
  expose maxRequestsPerNavigation maxConcurrentPerOrigin minimumPollIntervalMs
  use arg maxReqArg=32, maxConcurrentArg=2, pollMsArg=30000
  maxRequestsPerNavigation=maxReqArg+0; maxConcurrentPerOrigin=maxConcurrentArg+0; minimumPollIntervalMs=pollMsArg+0
::method allows
  use arg resourceKind, semanticEssential=.false
  k=resourceKind~string~upper
  if semanticEssential then return .true
  select
    when k="DOCUMENT" then return .true
    when k="HTML" then return .true
    when k="SCRIPT" then return .true
    when k="JAVASCRIPT" then return .true
    when k="XHR" then return .true
    when k="FETCH" then return .true
    when k="DATA" then return .true
    when k="JSON" then return .true
    when k="FORM" then return .true
    when k="CSS" then return .false
    when k="STYLE" then return .false
    when k="IMAGE" then return .false
    when k="FONT" then return .false
    when k="AUDIO" then return .false
    when k="VIDEO" then return .false
    when k="ANALYTICS" then return .false
    when k="ADVERTISING" then return .false
    when k="PREFETCH" then return .false
    when k="PRELOAD" then return .false
    otherwise return .false
  end

::class VirtualCookie public
::attribute name get
::attribute value get
::attribute domain get
::attribute path get
::attribute secure get
::attribute httpOnly get
::method init
  expose name value domain path secure httpOnly
  use arg nameArg,valueArg,domainArg="",pathArg="/",secureArg=.false,httpOnlyArg=.false
  name=nameArg~string; value=valueArg~string; domain=domainArg~string~lower; path=pathArg~string
  secure=secureArg; httpOnly=httpOnlyArg

::class VirtualCookieJar public
::method init
  expose cookies
  cookies=.directory~new
::method put guarded
  expose cookies
  use arg cookie
  key=cookie~domain || "|" || cookie~path || "|" || cookie~name
  cookies[key]=cookie
::method count guarded
  expose cookies
  return cookies~items
::method captureSetCookie guarded
  use arg headerValue,url
  if headerValue==.nil then return .false
  raw=headerValue~string; semi=raw~pos(";")
  if semi=0 then first=raw; else first=raw~substr(1,semi-1)
  eq=first~pos("="); if eq=0 then return .false
  name=first~substr(1,eq-1)~strip; value=first~substr(eq+1)~strip
  host=self~hostFromUrl(url); path="/"; domain=host; secure=.false; httpOnly=.false
  rest=""; if semi>0 then rest=raw~substr(semi+1)
  do while rest<>""
    next=rest~pos(";")
    if next=0 then do; part=rest~strip; rest=""; end
    else do; part=rest~substr(1,next-1)~strip; rest=rest~substr(next+1); end
    parse var part key "=" val
    key=key~strip~lower
    select
      when key="domain" then do; domain=val~strip~lower; if domain~left(1)="." then domain=domain~substr(2); end
      when key="path" then path=val~strip
      when key="secure" then secure=.true
      when key="httponly" then httpOnly=.true
      otherwise nop
    end
  end
  self~put(.VirtualCookie~new(name,value,domain,path,secure,httpOnly))
  return .true
::method headerFor guarded
  expose cookies
  use arg url
  host=self~hostFromUrl(url); reqPath=self~pathFromUrl(url); secure=(url~lower~left(8)="https://")
  out=""; first=.true
  do key over cookies
    c=cookies[key]
    if c~secure & \secure then iterate
    if host<>c~domain then do
      suffix="."||c~domain
      if host~length<suffix~length then iterate
      if host~right(suffix~length)<>suffix then iterate
    end
    if reqPath~left(c~path~length)<>c~path then iterate
    if \first then out=out||"; "; first=.false
    out=out||c~name||"="||c~value
  end
  return out
::method scriptVisibleCookie guarded
  expose cookies
  use arg url
  host=self~hostFromUrl(url); reqPath=self~pathFromUrl(url)
  out=""; first=.true
  do key over cookies
    c=cookies[key]
    if c~httpOnly then iterate
    if host<>c~domain then do
      suffix="."||c~domain
      if host~length<suffix~length then iterate
      if host~right(suffix~length)<>suffix then iterate
    end
    if reqPath~left(c~path~length)<>c~path then iterate
    if \first then out=out||"; "; first=.false
    out=out||c~name||"="||c~value
  end
  return out
::method hostFromUrl private
  use arg url
  u=url~string; p=u~pos("://"); if p=0 then return ""
  rest=u~substr(p+3); slash=rest~pos("/"); if slash>0 then rest=rest~substr(1,slash-1)
  colon=rest~pos(":"); if colon>0 then rest=rest~substr(1,colon-1)
  return rest~lower
::method pathFromUrl private
  use arg url
  u=url~string; p=u~pos("://"); if p=0 then return "/"
  rest=u~substr(p+3); slash=rest~pos("/"); if slash=0 then return "/"
  path=rest~substr(slash); q=path~pos("?"); if q>0 then path=path~substr(1,q-1)
  return path

::class VirtualTimer public
::attribute token get
::attribute dueMs get
::attribute requestedDelayMs get
::attribute effectiveDelayMs get
::method init
  expose token dueMs requestedDelayMs effectiveDelayMs
  use arg tokenArg,dueArg,requestedArg,effectiveArg
  token=tokenArg~string; dueMs=dueArg+0; requestedDelayMs=requestedArg+0; effectiveDelayMs=effectiveArg+0

::class VirtualTimerQueue public
::attribute minimumIntervalMs get
::method init
  expose timers minimumIntervalMs
  use arg minArg=30000
  timers=.array~new; minimumIntervalMs=minArg+0
::method schedule guarded
  expose timers minimumIntervalMs
  use arg token,delayMs,nowMs=0
  requested=delayMs+0; effective=requested
  if effective<minimumIntervalMs then effective=minimumIntervalMs
  t=.VirtualTimer~new(token,nowMs+effective,requested,effective); timers~append(t); return t
::method due guarded
  expose timers
  use arg nowMs,maxCount=16
  out=.array~new; keep=.array~new
  do t over timers
    if t~dueMs<=nowMs & out~items<maxCount then out~append(t); else keep~append(t)
  end
  timers=keep; return out
::method count guarded
  expose timers
  return timers~items

::class VirtualScript public
::attribute source get
::attribute src get
::attribute inline get
::method init
  expose source src inline
  use arg sourceArg="",srcArg=""
  source=sourceArg~string; src=srcArg~string; inline=(src="")

::class VirtualElement public
::attribute id get
::attribute role get
::attribute name get
::attribute tag get
::attribute text
::attribute value
::attribute href get
::attribute action get
::attribute method get
::attribute enabled
::attribute inputName get
::attribute inputType get
::attribute formId get
::attribute attributes get
::method init
  expose id role name tag text value href action method enabled inputName inputType formId attributes
  use arg idArg,roleArg,nameArg,tagArg="",textArg="",valueArg="",hrefArg="",actionArg="",methodArg="GET",enabledArg=.true,inputNameArg="",inputTypeArg="",formIdArg="",attributesArg=.nil
  id=idArg~string; role=roleArg~string~upper; name=nameArg~string; tag=tagArg~string~upper
  text=textArg~string; value=valueArg~string; href=hrefArg~string; action=actionArg~string; method=methodArg~string~upper; enabled=enabledArg
  inputName=inputNameArg~string; inputType=inputTypeArg~string~upper; formId=formIdArg~string
  if attributesArg==.nil then attributes=.directory~new; else attributes=attributesArg

::class VirtualDocument public
::attribute url get
::attribute title
::method init
  expose url title elements byId scripts
  use arg urlArg,titleArg=""
  url=urlArg~string; title=titleArg~string; elements=.array~new; byId=.directory~new; scripts=.array~new
::method addScript
  expose scripts
  use arg script
  scripts~append(script); return self
::method scripts
  expose scripts
  return scripts
::method addElement
  expose elements byId
  use arg element
  elements~append(element)
  if element~id<>"" then byId[element~id]=element
  return self
::method findSemantic
  expose elements
  use arg roleArg,nameArg
  role=roleArg~string~upper; name=nameArg~string
  do e over elements
    if (role="" | e~role=role) & (name="" | e~name=name) then return e
  end
  return .nil
::method elementById
  expose byId
  use arg idArg
  return byId~at(idArg~string)
::method elementCount
  expose elements
  return elements~items
::method elements
  expose elements
  out=.array~new
  do e over elements
    out~append(e)
  end
  return out
::method formControls
  expose elements
  use arg formIdArg
  out=.array~new
  do e over elements
    if e~formId=formIdArg & e~inputName<>"" then out~append(e)
  end
  return out

::class VirtualDocumentFactory public
::method parse abstract

/* Small non-rendering HTML parser.  It intentionally extracts application
 * semantics rather than layout: forms, inputs, buttons, links, articles and
 * script source references.  A richer standards parser can replace this
 * factory without changing browser/session authority. */
::class BasicHtmlDocumentFactory subclass VirtualDocumentFactory public
::method parse
  use arg url,body,headers=.nil
  d=.VirtualDocument~new(url)
  html=body~string
  low=html~lower
  ts=low~pos("<title")
  if ts>0 then do
    gt=html~pos(">",ts)
    te=low~pos("</title>",gt+1)
    if gt>0 & te>gt then d~title=self~decode(html~substr(gt+1,te-gt-1))~strip
  end
  currentForm=""; formAction=""; formMethod="GET"; pos=1; seq=0
  do while pos<=html~length
    lt=html~pos("<",pos); if lt=0 then leave
    gt=html~pos(">",lt+1); if gt=0 then leave
    raw=html~substr(lt+1,gt-lt-1)~strip
    if raw="" then do; pos=gt+1; iterate; end
    closing=raw~left(1)="/"
    if closing then raw=raw~substr(2)~strip
    parse var raw tag " " rest
    if rest="" then tag=raw
    tag=tag~lower
    if closing then do
      if tag="form" then do; currentForm=""; formAction=""; formMethod="GET"; end
      pos=gt+1; iterate
    end
    attrs=self~attrs(rest)
    if tag="form" then do
      seq+=1; currentForm=self~aval(attrs,"id","FORM-"||seq); formAction=self~aval(attrs,"action",url); formMethod=self~aval(attrs,"method","GET")~upper
      pos=gt+1; iterate
    end
    if tag="input" then do
      seq+=1; typ=self~aval(attrs,"type","text")~upper; rid=self~roleForInput(typ)
      id=self~aval(attrs,"id","E-"||seq); inp=self~aval(attrs,"name",id); nm=self~aval(attrs,"aria-label",inp); val=self~aval(attrs,"value","")
      e=.VirtualElement~new(id,rid,nm,"INPUT","",val,"",formAction,formMethod,.true,inp,typ,currentForm,attrs); d~addElement(e)
      pos=gt+1; iterate
    end
    if tag="script" then do
      close="</script>"; ep=low~pos(close,gt+1); code=""
      if ep>gt+1 then code=html~substr(gt+1,ep-gt-1)
      src=self~aval(attrs,"src","")
      d~addScript(.VirtualScript~new(code,src))
      if ep>gt then pos=ep+close~length; else pos=gt+1
      iterate
    end
    if tag="button" | tag="a" | tag="article" then do
      seq+=1; close="</"||tag||">"; ep=low~pos(close,gt+1); if ep=0 then ep=gt+1
      tx=""; if ep>gt+1 then tx=self~stripTags(html~substr(gt+1,ep-gt-1))~strip
      id=self~aval(attrs,"id","E-"||seq); nm=self~aval(attrs,"aria-label",tx)
      if tag="button" then role="BUTTON"; else if tag="a" then role="LINK"; else role="ARTICLE"
      href=self~aval(attrs,"href",""); e=.VirtualElement~new(id,role,nm,tag~upper,tx,"",href,formAction,formMethod,.true,"","",currentForm,attrs); d~addElement(e)
      if ep>gt then pos=ep+close~length; else pos=gt+1
      iterate
    end
    pos=gt+1
  end
  return d
::method attrs private
  use arg text
  out=.directory~new; s=text~strip
  do while s<>""
    s=s~strip; eq=s~pos("=")
    sp=s~pos(" ")
    if eq=0 then leave
    if sp>0 & sp<eq then do; s=s~substr(sp+1); iterate; end
    key=s~substr(1,eq-1)~strip~lower; rem=s~substr(eq+1)~strip
    q=rem~left(1)
    if q='"' | q="'" then do
      z=rem~pos(q,2); if z=0 then leave
      val=rem~substr(2,z-2); s=rem~substr(z+1)
    end
    else do
      z=rem~pos(" "); if z=0 then do; val=rem; s=""; end; else do; val=rem~substr(1,z-1); s=rem~substr(z+1); end
    end
    out[key]=self~decode(val)
  end
  return out
::method aval private
  use arg attrs,key,default=""
  v=attrs~at(key); if v==.nil then return default; return v
::method roleForInput private
  use arg typ
  if typ="SUBMIT" | typ="BUTTON" then return "BUTTON"
  return "TEXTBOX"
::method stripTags private
  use arg s
  out=""; inside=.false
  do i=1 to s~length
    c=s~substr(i,1)
    if c="<" then inside=.true
    else if c=">" then inside=.false
    else if \inside then out=out||c
  end
  return self~decode(out)
::method decode private
  use arg s
  s=s~changestr("&amp;","&")~changestr("&lt;","<")~changestr("&gt;",">")~changestr("&quot;",'"')~changestr("&#39;","'")
  return s

/* Terminal-observer compatible semantic projection.  This is deliberately
 * protocol-compatible rather than type-coupled to TerminalCore.cls, so the
 * browser package does not acquire terminal-machine authority or dependency. */
::class VirtualBrowserObservationField public
::attribute fieldId get
::attribute row get
::attribute column get
::attribute length get
::attribute value get
::attribute inputCapable get
::attribute protected get
::attribute nonDisplay get
::attribute modified get
::attribute numeric get
::attribute attributes get
::method init
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  use arg idArg,rowArg,columnArg,lengthArg,valueArg="",inputArg=.false,protectedArg=.true,nonDisplayArg=.false,modifiedArg=.false,numericArg=.false,attrsArg=.nil
  fieldId=idArg~string; row=rowArg+0; column=columnArg+0; length=lengthArg+0; value=valueArg~string
  inputCapable=inputArg==.true; protected=protectedArg==.true; nonDisplay=nonDisplayArg==.true; modified=modifiedArg==.true; numeric=numericArg==.true
  if attrsArg==.nil then attributes=.directory~new; else attributes=attrsArg
::method attribute
  expose attributes
  use arg nameArg
  return attributes~at(nameArg~string)
::method copyDetached
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  copied=.directory~new
  do k over attributes; copied[k]=attributes[k]; end
  return .VirtualBrowserObservationField~new(fieldId,row,column,length,value,inputCapable,protected,nonDisplay,modified,numeric,copied)
::method displayValue
  expose value nonDisplay length
  if \nonDisplay then return value
  if length<=0 then return "<SECRET>"
  return copies("*",length)

::class VirtualBrowserObservationSnapshot public
::attribute generation get
::attribute terminalType get
::attribute rows get
::attribute columns get
::attribute cursorRow get
::attribute cursorColumn get
::attribute keyboardState get
::attribute sessionState get
::attribute contentDigest get
::attribute layoutFingerprint get
::attribute timestamp get
::method init
  expose generation terminalType rows columns cursorRow cursorColumn keyboardState sessionState contentDigest layoutFingerprint timestamp textRows fields metadata
  use arg generationArg,textRowsArg,fieldsArg,metadataArg,sessionStateArg="ACTIVE",contentDigestArg="",layoutArg="",timestampArg=""
  generation=generationArg+0; terminalType="VIRTUAL-BROWSER"; cursorRow=0; cursorColumn=0; keyboardState="UNLOCKED"; sessionState=sessionStateArg~string~upper
  textRows=.array~new; maxColumns=0
  if textRowsArg<>.nil then do line over textRowsArg; textRows~append(line~string); if line~string~length>maxColumns then maxColumns=line~string~length; end
  rows=textRows~items; columns=maxColumns
  fields=.array~new
  if fieldsArg<>.nil then do f over fieldsArg; fields~append(f~copyDetached); end
  metadata=.directory~new
  if metadataArg<>.nil then do k over metadataArg; metadata[k]=metadataArg[k]; end
  contentDigest=contentDigestArg~string; layoutFingerprint=layoutArg~string
  if timestampArg="" then timestamp=.DateTime~new~utcIsoDate; else timestamp=timestampArg~string
::method copyDetached
  expose generation textRows fields metadata sessionState contentDigest layoutFingerprint timestamp
  return .VirtualBrowserObservationSnapshot~new(generation,self~textRows,self~fields,self~metadata,sessionState,contentDigest,layoutFingerprint,timestamp)
::method textRows
  expose textRows
  out=.array~new; do line over textRows; out~append(line); end; return out
::method fields
  expose fields
  out=.array~new; do f over fields; out~append(f~copyDetached); end; return out
::method metadata
  expose metadata
  out=.directory~new; do k over metadata; out[k]=metadata[k]; end; return out
::method rowText
  expose textRows
  use arg rowNumber
  if rowNumber<1 | rowNumber>textRows~items then return ""
  return textRows[rowNumber]
::method visibleText
  expose textRows
  out=""
  do line over textRows
    if out<>"" then out=out||"0a"x
    out=out||line
  end
  return out
::method field
  expose fields
  use arg idArg
  wanted=idArg~string
  do f over fields; if f~fieldId=wanted then return f~copyDetached; end
  return .nil
::method fieldAt
  expose fields
  use arg rowArg,columnArg
  do f over fields
    if f~row=rowArg then do
      if columnArg>=f~column & columnArg<(f~column+f~length) then return f~copyDetached
    end
  end
  return .nil
::method capabilities
  caps=.directory~new
  caps["SEMANTIC_DOCUMENT"]=1; caps["FIELDS"]=1; caps["READ_ONLY_OBSERVATION"]=1
  return caps
::method operatorCondition
  return .nil

::class VirtualBrowserWatchAlong public
::attribute capacity get
::attribute lastSeenGeneration get
::method init
  expose history capacity lastSeenGeneration
  use arg capacityArg=64
  capacity=capacityArg+0; if capacity<1 then capacity=1
  history=.array~new; lastSeenGeneration=0
::method observe guarded
  expose history capacity lastSeenGeneration
  use arg snapshot
  detached=snapshot~copyDetached; history~append(detached); lastSeenGeneration=detached~generation
  do while history~items>capacity; history~remove(1); end
  return self
::method current guarded
  expose history
  if history~items=0 then return .nil
  return history[history~items]~copyDetached
::method back guarded
  expose history
  use arg count=1
  index=history~items-count
  if index<1 | index>history~items then return .nil
  return history[index]~copyDetached
::method history guarded
  expose history
  out=.array~new; do snap over history; out~append(snap~copyDetached); end; return out
::method rows
  use arg fromRow,toRow,snapshotArg=.nil
  if snapshotArg==.nil then snapshot=self~current; else snapshot=snapshotArg
  if snapshot==.nil then return ""
  if fromRow<1 then fromRow=1; if toRow>snapshot~rows then toRow=snapshot~rows
  out=""; do r=fromRow to toRow; if out<>"" then out=out||"0a"x; out=out||right(r,2)||"  "||snapshot~rowText(r); end
  return out
::method snippet
  use arg radius=2,snapshotArg=.nil
  if snapshotArg==.nil then snapshot=self~current; else snapshot=snapshotArg
  if snapshot==.nil then return ""
  return self~rows(1,snapshot~rows,snapshot)

/* Drop-in read-only observer surface matching TN5250ObservationSession. */
::class VirtualBrowserObservationSession public
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init
  expose sessionId terminalType deviceName session watchAlong
  use arg sessionArg
  session=sessionArg; sessionId=session~id; terminalType="VIRTUAL-BROWSER"; deviceName=session~executionNodeId; watchAlong=session~watchAlong
::method snapshot
  expose session
  return session~snapshot
::method current
  expose watchAlong
  return watchAlong~current
::method back
  expose watchAlong
  use arg count=1
  return watchAlong~back(count)
::method history
  expose watchAlong
  return watchAlong~history
::method knownStateStatus
  return "UNTRACKED"
::method knownStateId
  return ""
::method knownStateGeneration
  return 0
::method knownStateHistory
  return .array~new

::class VirtualBrowserHost public
::method init
  expose session
  use arg sessionArg
  session=sessionArg
::method fetch
  expose session
  use arg methodArg,urlArg,bodyArg="",headersArg=.nil,kindArg="FETCH"
  return session~fetchResource(methodArg,session~resolveUrl(urlArg),kindArg,headersArg,bodyArg,.false)
::method navigate
  expose session
  use arg urlArg
  return session~navigate(session~resolveUrl(urlArg))
::method setTimeout
  expose session
  use arg token,delayMs,nowMs=0
  return session~timerQueue~schedule(token,delayMs,nowMs)
::method cookie
  expose session
  return session~cookieJar~scriptVisibleCookie(session~currentUrl)
::method setCookie
  expose session
  use arg cookieText
  return session~cookieJar~captureSetCookie(cookieText,session~currentUrl)

::class VirtualJavaScriptRuntime public
/* ECMAScript language-engine seam. The runtime receives browser host authority,
 * never raw socket/file authority. */
::method attach abstract
::method execute abstract
::method dispatchEvent abstract
::method dispatchTimer abstract

::class VirtualNetworkAdapter public
::method request abstract

::class ApiClientVirtualNetworkAdapter subclass VirtualNetworkAdapter public
::method init
  expose apiClient sequence
  use arg apiClientArg
  apiClient=apiClientArg; sequence=0
::method request guarded
  expose apiClient sequence
  use arg browserRequest, methodArg, urlArg, headersArg=.nil, bodyArg="", resourceKind="FETCH"
  sequence+=1
  meta=.directory~new
  meta["virtualBrowserRequestId"]=browserRequest~id
  meta["resourceKind"]=resourceKind~string~upper
  id=browserRequest~id || "-NET-" || sequence
  r=.ApiRequest~new(id,methodArg,urlArg,headersArg,bodyArg,browserRequest~trafficClass,browserRequest~priority,browserRequest~expectedMicroWlu,browserRequest~requestedRateMicroWluPerSecond,"",meta,browserRequest~routeRequirement,browserRequest~executionNodeId)
  apiClient~submit(r)
  do forever
    response=apiClient~executeNext
    if response==.nil then return .ApiResponse~new(id,0,.nil,"",0,"API_CLIENT_EMPTY")
    if response~requestId=id then return response
  end

::class VirtualBrowserSession public
::attribute id get
::attribute request get
::attribute ownerNodeId get
::attribute executionNodeId get
::attribute placementId get
::attribute capabilityGeneration get
::attribute currentUrl get
::attribute document get
::attribute state get
::attribute requestCount get
::attribute blockedResourceCount get
::attribute cookieJar get
::attribute timerQueue get
::attribute watchAlong get
::method init
  expose id request ownerNodeId executionNodeId placementId capabilityGeneration currentUrl document state requestCount blockedResourceCount cookieJar timerQueue watchAlong observationGeneration resourcePolicy network documentFactory jsRuntime navigationRequestCount
  use arg idArg, requestArg, networkArg, documentFactoryArg, resourcePolicyArg=.nil, jsRuntimeArg=.nil
  id=idArg~string; request=requestArg; ownerNodeId=requestArg~ownerNodeId; executionNodeId=requestArg~executionNodeId
  placementId=""; capabilityGeneration=0
  if requestArg~placementLease<>.nil then do
    placementId=requestArg~placementLease~placementId
    capabilityGeneration=requestArg~placementLease~capabilityGeneration
  end
  network=networkArg; documentFactory=documentFactoryArg
  if resourcePolicyArg==.nil then resourcePolicy=.VirtualResourcePolicy~new; else resourcePolicy=resourcePolicyArg
  jsRuntime=jsRuntimeArg; currentUrl=""; document=.nil; state="READY"; requestCount=0; blockedResourceCount=0; navigationRequestCount=0
  cookieJar=.VirtualCookieJar~new
  timerQueue=.VirtualTimerQueue~new(resourcePolicy~minimumPollIntervalMs)
  watchAlong=.VirtualBrowserWatchAlong~new(64); observationGeneration=0
::method observationPort
  return .VirtualBrowserObservationSession~new(self)
::method snapshot
  expose watchAlong
  return watchAlong~current
::method observe guarded
  expose observationGeneration currentUrl document state requestCount blockedResourceCount ownerNodeId executionNodeId placementId capabilityGeneration watchAlong cookieJar timerQueue
  use arg reasonArg="STATE"
  observationGeneration+=1
  rows=.array~new; fields=.array~new; meta=.directory~new
  meta["surface"]="VIRTUAL_BROWSER"; meta["url"]=currentUrl; meta["reason"]=reasonArg~string~upper
  meta["ownerNodeId"]=ownerNodeId; meta["executionNodeId"]=executionNodeId; meta["placementId"]=placementId; meta["capabilityGeneration"]=capabilityGeneration
  meta["requestCount"]=requestCount; meta["blockedResourceCount"]=blockedResourceCount; meta["cookieCount"]=cookieJar~count; meta["timerCount"]=timerQueue~count
  if document==.nil then do
    rows~append("Virtual Browser: "||state)
  end
  else do
    rows~append("Document: "||document~title)
    rows~append("URL: "||currentUrl)
    seq=0
    do e over document~elements
      seq+=1
      label=e~role||" "||e~name
      if e~text<>"" then label=label||" :: "||e~text
      rows~append(label)
      attrs=.directory~new; attrs["role"]=e~role; attrs["name"]=e~name; attrs["tag"]=e~tag; attrs["href"]=e~href; attrs["formId"]=e~formId
      input=(e~role="TEXTBOX" & e~enabled); secret=(e~inputType="PASSWORD")
      rawValue=e~value; displayLen=rawValue~length
      if displayLen<1 then displayLen=1
      if secret then observedValue=""; else observedValue=rawValue
      fields~append(.VirtualBrowserObservationField~new(e~id,seq+2,1,displayLen,observedValue,input,\input,secret,.false,.false,attrs))
    end
    meta["title"]=document~title; meta["elementCount"]=document~elementCount
  end
  content="VBSEM:"||observationGeneration||":"||currentUrl||":"||requestCount||":"||blockedResourceCount
  layout="VBDOM:"; if document<>.nil then layout=layout||document~elementCount
  snap=.VirtualBrowserObservationSnapshot~new(observationGeneration,rows,fields,meta,state,content,layout)
  watchAlong~observe(snap)
  return snap~copyDetached

::method validatePlacement
  expose request executionNodeId
  use arg nowEpochMs=0
  lease=request~placementLease
  if lease==.nil then return .true
  if lease~nodeId<>executionNodeId then return .false
  if lease~jobId<>request~id then return .false
  if nowEpochMs>0 then if lease~isExpired(nowEpochMs) then return .false
  return .true
::method fetchResource
  expose request network resourcePolicy requestCount blockedResourceCount navigationRequestCount cookieJar
  use arg methodArg,urlArg,kindArg="FETCH",headersArg=.nil,bodyArg="",essentialArg=.false
  if \resourcePolicy~allows(kindArg,essentialArg) then do
    blockedResourceCount+=1
    return .ApiResponse~new(request~id || "-BLOCKED",0,.nil,"",0,"RESOURCE_POLICY_BLOCKED")
  end
  if navigationRequestCount>=resourcePolicy~maxRequestsPerNavigation then return .ApiResponse~new(request~id || "-BUDGET",0,.nil,"",0,"NAVIGATION_REQUEST_BUDGET_EXHAUSTED")
  if headersArg==.nil then headersArg=.directory~new
  cookie=cookieJar~headerFor(urlArg)
  if cookie<>"" & headersArg~at("Cookie")==.nil & headersArg~at("cookie")==.nil then headersArg["Cookie"]=cookie
  navigationRequestCount+=1; requestCount+=1
  response=network~request(request,methodArg,urlArg,headersArg,bodyArg,kindArg)
  setCookie=response~headers~at("set-cookie"); if setCookie==.nil then setCookie=response~headers~at("Set-Cookie")
  if setCookie<>.nil then cookieJar~captureSetCookie(setCookie,urlArg)
  return response
::method navigate
  expose currentUrl document documentFactory state navigationRequestCount jsRuntime
  use arg urlArg
  navigationRequestCount=0; state="NAVIGATING"
  response=self~fetchResource("GET",urlArg,"DOCUMENT",.nil,"",.true)
  if \response~ok then do; state="FAILED"; return response; end
  currentUrl=urlArg~string
  document=documentFactory~parse(currentUrl,response~body,response~headers)
  if document==.nil then do; state="FAILED"; return .ApiResponse~new(response~requestId,0,.nil,"",0,"DOCUMENT_PARSE_FAILED"); end
  if \self~attachDocument then do; state="FAILED"; return .ApiResponse~new(response~requestId,0,.nil,"",0,"SCRIPT_LOAD_FAILED"); end
  state="ACTIVE"
  self~observe("NAVIGATION")
  return response
::method attachDocument
  expose document jsRuntime
  if jsRuntime==.nil then return .true
  host=.VirtualBrowserHost~new(self)
  jsRuntime~attach(self,document,host)
  do script over document~scripts
    code=script~source; sourceUrl=self~currentUrl
    if \script~inline then do
      sourceUrl=self~resolveUrl(script~src)
      r=self~fetchResource("GET",sourceUrl,"SCRIPT",.nil,"",.false)
      if \r~ok then return .false
      code=r~body
    end
    jsRuntime~execute(self,code,sourceUrl,host)
  end
  return .true
::method runDueTimers
  expose timerQueue jsRuntime
  use arg nowMs,maxCount=16
  fired=.array~new
  if jsRuntime==.nil then return fired
  host=.VirtualBrowserHost~new(self)
  due=timerQueue~due(nowMs,maxCount)
  do timer over due
    jsRuntime~dispatchTimer(self,timer~token,host)
    fired~append(timer~token)
  end
  if fired~items>0 then self~observe("TIMER_FIRED")
  return fired
::method find
  expose document
  use arg role,name
  if document==.nil then return .nil
  return document~findSemantic(role,name)

::method resolveUrl
  expose currentUrl
  use arg target
  target=target~string
  if target~lower~left(7)="http://" | target~lower~left(8)="https://" then return target
  if currentUrl="" then return target
  p=currentUrl~pos("://"); if p=0 then return target
  slash=currentUrl~pos("/",p+3)
  if slash=0 then origin=currentUrl; else origin=currentUrl~substr(1,slash-1)
  if target~left(1)="/" then return origin||target
  if slash=0 then base=currentUrl||"/"; else do
    last=currentUrl~lastPos("/"); base=currentUrl~substr(1,last)
  end
  return base||target
::method encodeForm
  use arg element
  controls=self~document~formControls(element~formId)
  out=""; first=.true
  do c over controls
    if c~inputType="SUBMIT" | c~inputType="BUTTON" then iterate
    if \first then out=out||"&"; first=.false
    out=out||self~urlEncode(c~inputName)||"="||self~urlEncode(c~value)
  end
  return out
::method urlEncode private
  use arg value
  s=value~string; out=""; hex="0123456789ABCDEF"
  do i=1 to s~length
    c=s~substr(i,1); n=c~c2d
    if (n>=48 & n<=57) | (n>=65 & n<=90) | (n>=97 & n<=122) | c="-" | c="_" | c="." | c="~" then out=out||c
    else if c=" " then out=out||"+"
    else out=out||"%"||hex~substr(n%16+1,1)||hex~substr(n//16+1,1)
  end
  return out
::method activate
  expose jsRuntime
  use arg element
  if jsRuntime<>.nil then do
    r=jsRuntime~dispatchEvent(self,element,"click")
    if r<>.nil then if r~string="CANCEL" then return .ApiResponse~new(self~request~id||"-EVENT",204,.nil,"",0,"")
  end
  if element~formId<>"" & element~action<>"" then do
    target=self~resolveUrl(element~action); method=element~method
    if method="POST" then return self~submitForm(element,target)
    return self~navigate(target)
  end
  if element~href<>"" then return self~navigate(self~resolveUrl(element~href))
  self~observe("CONTROL_ACTIVATED")
  return .ApiResponse~new(self~request~id||"-NOOP",204,.nil,"",0,"")
::method submitForm
  expose currentUrl document documentFactory state navigationRequestCount jsRuntime
  use arg element,target
  navigationRequestCount=0; state="SUBMITTING"; body=self~encodeForm(element)
  h=.directory~new; h["content-type"]="application/x-www-form-urlencoded"
  response=self~fetchResource("POST",target,"FORM",h,body,.true)
  if \response~ok then do; state="FAILED"; return response; end
  currentUrl=target; document=documentFactory~parse(currentUrl,response~body,response~headers)
  if document==.nil then do; state="FAILED"; return .ApiResponse~new(response~requestId,0,.nil,"",0,"DOCUMENT_PARSE_FAILED"); end
  if \self~attachDocument then do; state="FAILED"; return .ApiResponse~new(response~requestId,0,.nil,"",0,"SCRIPT_LOAD_FAILED"); end
  state="ACTIVE"; self~observe("FORM_SUBMITTED"); return response

::class VirtualBrowserResult public
::attribute requestId get
::attribute code get
::attribute outputs get
::attribute session get
::method init
  expose requestId code outputs session
  use arg requestArg,codeArg,outputsArg=.nil,sessionArg=.nil
  requestId=requestArg~string; code=codeArg~string
  if outputsArg==.nil then outputs=.array~new; else outputs=outputsArg
  session=sessionArg
::method ok
  expose code
  return code="OK"

::class VirtualBrowserEngine public
::method init
  expose network documentFactory resourcePolicy jsRuntime sequence
  use arg networkArg, documentFactoryArg, resourcePolicyArg=.nil, jsRuntimeArg=.nil
  network=networkArg; documentFactory=documentFactoryArg
  if resourcePolicyArg==.nil then resourcePolicy=.VirtualResourcePolicy~new; else resourcePolicy=resourcePolicyArg
  jsRuntime=jsRuntimeArg; sequence=0
::method execute guarded
  expose network documentFactory resourcePolicy jsRuntime sequence
  use arg browserRequest, nowEpochMs=0
  sequence+=1
  session=.VirtualBrowserSession~new("VBSESSION-" || sequence || "-" || browserRequest~id,browserRequest,network,documentFactory,resourcePolicy,jsRuntime)
  if \session~validatePlacement(nowEpochMs) then return .VirtualBrowserResult~new(browserRequest~id,"PLACEMENT_CONTEXT_INVALID",.nil,session)
  session~observe("SESSION_READY")
  out=.array~new
  do command over browserRequest~commands
    op=command~operation
    select
      when op="NAVIGATE" then do
        r=session~navigate(command~argument)
        if \r~ok then return .VirtualBrowserResult~new(browserRequest~id,r~errorCode,.nil,session)
      end
      when op="SET_VALUE" then do
        e=session~find(command~role,command~name)
        if e==.nil then return .VirtualBrowserResult~new(browserRequest~id,"ELEMENT_NOT_FOUND",.nil,session)
        if \e~enabled then return .VirtualBrowserResult~new(browserRequest~id,"ELEMENT_DISABLED",.nil,session)
        e~value=command~value
        session~observe("VALUE_CHANGED")
      end
      when op="RUN_TIMERS" then do
        fired=session~runDueTimers(command~argument+0)
        out~append(fired~items)
      end
      when op="READ_TEXT" then do
        e=session~find(command~role,command~name)
        if e==.nil then return .VirtualBrowserResult~new(browserRequest~id,"ELEMENT_NOT_FOUND",.nil,session)
        out~append(e~text)
      end
      when op="ACTIVATE" then do
        e=session~find(command~role,command~name)
        if e==.nil then return .VirtualBrowserResult~new(browserRequest~id,"ELEMENT_NOT_FOUND",.nil,session)
        if \e~enabled then return .VirtualBrowserResult~new(browserRequest~id,"ELEMENT_DISABLED",.nil,session)
        r=session~activate(e)
        if \r~ok then return .VirtualBrowserResult~new(browserRequest~id,r~errorCode,.nil,session)
      end
      otherwise return .VirtualBrowserResult~new(browserRequest~id,"UNSUPPORTED_COMMAND:" || op,.nil,session)
    end
  end
  return .VirtualBrowserResult~new(browserRequest~id,"OK",out,session)

::requires "Observation.cls"
::requires "ApiClient.cls"
