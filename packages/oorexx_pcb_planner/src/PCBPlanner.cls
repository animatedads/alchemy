/* ooRexx PCB Planner v0.1-dev2
 * Exact package/pad identity and placement transforms.  Electrical truth
 * remains in Circuit/Pin; this layer only binds that truth to physical pads.
 */

::class PCBPadDefinition public
::attribute number get
::attribute xMm get
::attribute yMm get
::attribute pinName get
::method init
  expose number xMm yMm pinName
  use strict arg numberArg, pinNameArg, xArg=0, yArg=0
  number=numberArg~string; pinName=pinNameArg~string~upper; xMm=xArg+0; yMm=yArg+0

::class PCBFootprintDefinition public
::attribute id get
::attribute pads get
::method init
  expose id pads
  use strict arg idArg
  id=idArg~string; pads=.directory~new
::method addPad
  expose pads
  use strict arg pad
  key=pad~number~upper
  if pads~hasIndex(key) then raise syntax 93.900 array('duplicate footprint pad ' || pad~number)
  pads[key]=pad; return self
::method pad
  expose pads
  use strict arg number
  key=number~string~upper
  if \pads~hasIndex(key) then return .nil
  return pads[key]

::class PCBPinPadBinding public
::attribute pin get
::attribute padNumber get
::method init
  expose pin padNumber
  use strict arg pinArg, padArg
  if pinArg == .nil then raise syntax 93.900 array('PCB pin binding requires circuit pin')
  pin=pinArg; padNumber=padArg~string

::class PCBPlacement public
::attribute component get
::attribute footprint get
::attribute bindings get
::attribute xMm get
::attribute yMm get
::attribute rotationDeg get
::attribute side get
::method init
  expose component footprint bindings xMm yMm rotationDeg side
  use strict arg componentArg, footprintArg, xArg=0, yArg=0, rotationArg=0, sideArg='TOP'
  component=componentArg; footprint=footprintArg; bindings=.array~new
  xMm=xArg+0; yMm=yArg+0; rotationDeg=rotationArg+0; side=sideArg~string~upper
  if side <> 'TOP' & side <> 'BOTTOM' then raise syntax 93.900 array('PCB side must be TOP or BOTTOM')
::method bind
  expose bindings
  use strict arg pin, padNumber
  bindings~append(.PCBPinPadBinding~new(pin,padNumber)); return self
::method transformedPad
  expose footprint xMm yMm rotationDeg side
  use strict arg padNumber
  p=footprint~pad(padNumber)
  if p == .nil then return .nil
  x=p~xMm; y=p~yMm
  if side='BOTTOM' then x=-x
  angle=rotationDeg // 360
  select
    when angle=0 then do; tx=x; ty=y; end
    when angle=90 then do; tx=-y; ty=x; end
    when angle=180 then do; tx=-x; ty=-y; end
    when angle=270 then do; tx=y; ty=-x; end
    otherwise raise syntax 93.900 array('dev22 placement supports orthogonal rotation only')
  end
  d=.directory~new; d['X_MM']=xMm+tx; d['Y_MM']=yMm+ty; return d

::class PCBIdentityIssue public
::attribute code get
::attribute text get
::method init
  expose code text
  use strict arg codeArg,textArg
  code=codeArg~string~upper; text=textArg~string

::class PCBIdentityReport public
::attribute issues get
::method init
  expose issues
  issues=.array~new
::method add
  expose issues
  use strict arg code,text
  issues~append(.PCBIdentityIssue~new(code,text)); return self
::method ok
  expose issues
  return issues~items=0
::method errorCount
  expose issues
  return issues~items

::class PCBIdentityVerifier public
::method verify class
  use strict arg placement
  report=.PCBIdentityReport~new
  seen=.directory~new
  do binding over placement~bindings
    pin=binding~pin; pad=placement~footprint~pad(binding~padNumber)
    if pin~owner <> placement~component then report~add('FOREIGN_PIN','pin ' || pin~qualifiedName || ' does not belong to placed component')
    if pad == .nil then do
      report~add('MISSING_PAD','footprint has no pad ' || binding~padNumber)
      iterate
    end
    if seen~hasIndex(binding~padNumber~upper) then report~add('DUPLICATE_PAD_BINDING','pad ' || binding~padNumber || ' is bound more than once')
    seen[binding~padNumber~upper]=1
    if pad~pinName <> pin~name~upper then report~add('PIN_PAD_MISMATCH','pin ' || pin~qualifiedName || ' maps to pad ' || pad~number || ' declared for ' || pad~pinName)
  end
  return report

/* dev23 board graph: physical endpoints and copper connectivity. */
::class PCBLayerDefinition public
::attribute name get
::attribute kind get
::method init
  expose name kind
  use strict arg nameArg, kindArg='COPPER'
  name=nameArg~string~upper; kind=kindArg~string~upper

::class PCBNetEndpoint public
::attribute net get
::attribute pin get
::attribute placement get
::attribute padNumber get
::method init
  expose net pin placement padNumber
  use strict arg netArg,pinArg,placementArg,padArg
  net=netArg; pin=pinArg; placement=placementArg; padNumber=padArg~string
::method key
  expose pin placement padNumber
  return pin~qualifiedName~upper || '@' || placement~side || ':' || padNumber~upper
::method position
  expose placement padNumber
  return placement~transformedPad(padNumber)

::class PCBTrack public
::attribute net get
::attribute layer get
::attribute fromEndpoint get
::attribute toEndpoint get
::attribute widthMm get
::attribute routePoints get
::method init
  expose net layer fromEndpoint toEndpoint widthMm routePoints
  use strict arg netArg,layerArg,fromArg,toArg,widthArg=0.25
  net=netArg; layer=layerArg~string~upper; fromEndpoint=fromArg; toEndpoint=toArg; widthMm=widthArg+0; routePoints=.array~new

::method setRoutePoints
  expose routePoints
  use strict arg points
  routePoints=points; return self

::class PCBVia public
::attribute net get
::attribute xMm get
::attribute yMm get
::attribute fromLayer get
::attribute toLayer get
::attribute drillMm get
::method init
  expose net xMm yMm fromLayer toLayer drillMm
  use strict arg netArg,xArg,yArg,fromArg='F.CU',toArg='B.CU',drillArg=0.3
  net=netArg; xMm=xArg+0; yMm=yArg+0; fromLayer=fromArg~string~upper; toLayer=toArg~string~upper; drillMm=drillArg+0

::class PCBBoard public
::attribute id get
::attribute widthMm get
::attribute heightMm get
::attribute layers get
::attribute placements get
::attribute endpoints get
::attribute tracks get
::attribute vias get
::attribute manufacturingRules get
::method init
  expose id widthMm heightMm layers placements endpoints tracks vias manufacturingRules
  use strict arg idArg,widthArg,heightArg
  id=idArg~string; widthMm=widthArg+0; heightMm=heightArg+0
  layers=.directory~new; placements=.array~new; endpoints=.directory~new; tracks=.array~new; vias=.array~new; manufacturingRules=.nil
  self~addLayer(.PCBLayerDefinition~new('F.Cu'))
  self~addLayer(.PCBLayerDefinition~new('B.Cu'))
::method qualifyForManufacturing
  expose manufacturingRules
  use strict arg rules
  manufacturingRules=rules; return self
::method addLayer
  expose layers
  use strict arg layer
  layers[layer~name]=layer; return self
::method addPlacement
  expose placements endpoints
  use strict arg placement
  placements~append(placement)
  do b over placement~bindings
    if b~pin~net == .nil then iterate
    e=.PCBNetEndpoint~new(b~pin~net,b~pin,placement,b~padNumber)
    if endpoints~hasIndex(e~key) then raise syntax 93.900 array('duplicate PCB endpoint ' || e~key)
    endpoints[e~key]=e
  end
  return self
::method endpointForPin
  expose endpoints
  use strict arg pin
  do key over endpoints
    e=endpoints[key]
    if e~pin == pin then return e
  end
  return .nil
::method route
  expose tracks layers
  use strict arg net,fromEndpoint,toEndpoint,layer='F.CU',widthMm=0.25
  lk=layer~string~upper
  if \layers~hasIndex(lk) then raise syntax 93.900 array('unknown PCB layer ' || layer)
  t=.PCBTrack~new(net,lk,fromEndpoint,toEndpoint,widthMm); tracks~append(t); return t
::method addVia
  expose vias
  use strict arg via
  vias~append(via); return via

::class PCBManufacturingRules public
/* Consumer-side projection of an external manufacturing authority.  The
 * sourceAuthority field is mandatory so these values are never anonymous
 * planner-owned fabrication truth. */
::attribute sourceAuthority get
::attribute minTraceWidthMm get
::attribute minClearanceMm get
::attribute minViaDrillMm get
::attribute maxViaDrillMm get
::method init
  expose sourceAuthority minTraceWidthMm minClearanceMm minViaDrillMm maxViaDrillMm
  use strict arg sourceArg,minTraceArg,clearanceArg,minDrillArg,maxDrillArg=99
  sourceAuthority=sourceArg~string
  if sourceAuthority~strip='' then raise syntax 93.900 array('manufacturing rules require external source authority')
  minTraceWidthMm=minTraceArg+0; minClearanceMm=clearanceArg+0; minViaDrillMm=minDrillArg+0; maxViaDrillMm=maxDrillArg+0
  if minTraceWidthMm<=0 | minClearanceMm<0 | minViaDrillMm<=0 | maxViaDrillMm<minViaDrillMm then -
    raise syntax 93.900 array('invalid manufacturing capability projection')

::class PCBRoutePoint public
::attribute xMm get
::attribute yMm get
::method init
  expose xMm yMm
  use strict arg xArg,yArg
  xMm=xArg+0; yMm=yArg+0

::class PCBDeterministicRouter public
/* Deliberately simple first router: stable endpoint order and orthogonal
 * X-then-Y doglegs.  It creates candidates; PCBBoardVerifier remains the
 * acceptance authority for board/manufacturing constraints. */
::method routeNet class
  use strict arg board,net,layer='F.CU',widthMm=.nil
  rules=board~manufacturingRules
  if widthMm==.nil then do
    if rules==.nil then raise syntax 93.900 array('router requires explicit width or manufacturing rules')
    width=rules~minTraceWidthMm
  end
  else width=widthMm+0
  eps=.array~new
  do key over board~endpoints
    e=board~endpoints[key]
    if e~net==net then eps~append(e)
  end
  if eps~items<2 then return .array~new
  /* stable lexical endpoint ordering makes the same board reproduce copper */
  do i=1 to eps~items-1
    do j=i+1 to eps~items
      if eps[j]~key < eps[i]~key then do; tmp=eps[i]; eps[i]=eps[j]; eps[j]=tmp; end
    end
  end
  made=.array~new
  do i=2 to eps~items
    a=eps[i-1]; b=eps[i]
    t=board~route(net,a,b,layer,width)
    pa=a~position; pb=b~position
    pts=.array~new
    pts~append(.PCBRoutePoint~new(pa['X_MM'],pa['Y_MM']))
    if pa['X_MM']<>pb['X_MM'] & pa['Y_MM']<>pb['Y_MM'] then pts~append(.PCBRoutePoint~new(pb['X_MM'],pa['Y_MM']))
    pts~append(.PCBRoutePoint~new(pb['X_MM'],pb['Y_MM']))
    t~setRoutePoints(pts)
    made~append(t)
  end
  return made

::class PCBBoardReport subclass PCBIdentityReport public

::class PCBBoardVerifier public
::method verify class
  use strict arg board,circuit
  report=.PCBBoardReport~new
  /* Placement identity remains a hard prerequisite. */
  do p over board~placements
    ir=.PCBIdentityVerifier~verify(p)
    do issue over ir~issues
      report~add(issue~code,issue~text)
    end
    do b over p~bindings
      pos=p~transformedPad(b~padNumber)
      if pos == .nil then iterate
      if pos['X_MM'] < 0 | pos['X_MM'] > board~widthMm | pos['Y_MM'] < 0 | pos['Y_MM'] > board~heightMm then -
        report~add('OUTSIDE_BOARD','pad ' || b~pin~qualifiedName || ' lies outside board outline')
    end
  end
  /* Every electrically connected circuit pin must have one physical endpoint. */
  do netKey over circuit~nets
    n=circuit~nets[netKey]
    do pin over n~participants
      if board~endpointForPin(pin) == .nil then report~add('UNPLACED_NET_PIN','net ' || n~name || ' pin ' || pin~qualifiedName || ' has no PCB endpoint')
    end
  end
  /* Copper may only join endpoints belonging to its authoritative electrical net. */
  do t over board~tracks
    if t~fromEndpoint == .nil | t~toEndpoint == .nil then do
      report~add('TRACK_ENDPOINT_MISSING','track has missing endpoint'); iterate
    end
    if t~fromEndpoint~net <> t~net | t~toEndpoint~net <> t~net then -
      report~add('TRACK_NET_MISMATCH','track copper crosses authoritative net identity')
    if t~widthMm <= 0 then report~add('INVALID_TRACE_WIDTH','trace width must be positive')
    rules=board~manufacturingRules
    if rules <> .nil then if t~widthMm < rules~minTraceWidthMm then report~add('TRACE_BELOW_PROCESS_MIN','trace width ' || t~widthMm || ' mm below ' || rules~minTraceWidthMm || ' mm from ' || rules~sourceAuthority)
    do rp over t~routePoints
      if rp~xMm < 0 | rp~xMm > board~widthMm | rp~yMm < 0 | rp~yMm > board~heightMm then report~add('ROUTE_OUTSIDE_BOARD','routed copper point lies outside board outline')
    end
  end
  rules=board~manufacturingRules
  if rules <> .nil then do v over board~vias
    if v~drillMm < rules~minViaDrillMm | v~drillMm > rules~maxViaDrillMm then report~add('VIA_DRILL_OUTSIDE_PROCESS','via drill ' || v~drillMm || ' mm outside manufacturing capability from ' || rules~sourceAuthority)
  end
  /* For the foundation router, a multi-pin net is accepted only if its endpoint graph is connected. */
  do netKey over circuit~nets
    n=circuit~nets[netKey]
    if n~participants~items <= 1 then iterate
    first=board~endpointForPin(n~participants[1])
    if first == .nil then iterate
    reached=.directory~new; reached[first~key]=1
    changed=.true
    do while changed
      changed=.false
      do t over board~tracks
        if t~net <> n then iterate
        a=t~fromEndpoint~key; b=t~toEndpoint~key
        if reached~hasIndex(a) & \reached~hasIndex(b) then do; reached[b]=1; changed=.true; end
        if reached~hasIndex(b) & \reached~hasIndex(a) then do; reached[a]=1; changed=.true; end
      end
    end
    do pin over n~participants
      e=board~endpointForPin(pin)
      if e <> .nil & \reached~hasIndex(e~key) then report~add('NET_NOT_ROUTED','net ' || n~name || ' does not physically connect ' || pin~qualifiedName)
    end
  end
  return report
