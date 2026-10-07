/* PCBIntentions.cls - Intention Service dev11 discovery surface for PCB Planner.
 *
 * PCB Planner retains PCB objects. Intention Service owns discovery freshness,
 * evidence generations, meaning selection and READY dispatch.  No flattened
 * shadow catalogue is maintained by PCB Planner.
 */

::class PCBIntentionDiscovery public
::method init
  expose board circuit
  use strict arg board, circuit
::method discover
  expose board circuit
  use arg service
  revision = board~placements~items || ':' || board~endpoints~items || ':' || board~tracks~items || ':' || board~vias~items
  if board~manufacturingRules == .nil then revision = revision || ':NO-MFG'
  else revision = revision || ':MFG:' || board~manufacturingRules~sourceAuthority
  snapshot = .IntentionDiscoverySnapshot~new('PCB:' || board~id, revision)

  snapshot~addEvidenceFact(.IntentionEvidenceFact~new(board~id,'PCB_BOARD_PRESENT',board,100,'PCB_DISCOVERY','OBSERVED',revision))
  snapshot~addEvidenceFact(.IntentionEvidenceFact~new(board~id,'PCB_ENDPOINT_COUNT',board~endpoints~items,100,'PCB_DISCOVERY','OBSERVED',revision))
  snapshot~addSurfaceAdvertisement(.IntentionSurfaceAdvertisement~new('PCB_BOARD', .PCBBoardSurface~new(board,circuit), board, 'PLANNING_TARGET', board~id, 'DISCOVERY', 'OBSERVED'))

  if board~manufacturingRules \== .nil then do
    rules = board~manufacturingRules
    snapshot~addEvidenceFact(.IntentionEvidenceFact~new(board~id,'MANUFACTURING_RULES',rules,100,rules~sourceAuthority,'OBSERVED',revision))
    if board~endpoints~items >= 2 then
      snapshot~addSurfaceAdvertisement(.IntentionSurfaceAdvertisement~new('PCB_ROUTING', .PCBRouteSurface~new(board), board, 'ROUTABLE_BOARD', board~id, 'DISCOVERY', 'OBSERVED'))
  end

  if board~tracks~items > 0 then do
    snapshot~addEvidenceFact(.IntentionEvidenceFact~new(board~id,'PCB_TRACK_COUNT',board~tracks~items,100,'PCB_DISCOVERY','OBSERVED',revision))
    snapshot~addSurfaceAdvertisement(.IntentionSurfaceAdvertisement~new('PCB_ROUTING_VERIFICATION', .PCBVerifyRoutingSurface~new(board,circuit), board, 'ROUTED_BOARD', board~id, 'DISCOVERY', 'OBSERVED'))
  end
  return snapshot

::class PCBBoardSurface public
::method init; expose board circuit; use strict arg board,circuit
::method propose
  use arg service,text
  t=translate(strip(text)); out=.Array~new
  if t='INSPECT BOARD' | t='SHOW BOARD' then out~append(.IntentionProposal~new('PCB_INSPECT_BOARD',100,'PCB_BOARD_SURFACE',.true,'live PCB board surface'))
  if t='VERIFY BOARD' | t='CHECK BOARD' then out~append(.IntentionProposal~new('PCB_VERIFY_BOARD',100,'PCB_BOARD_SURFACE',.true,'live PCB board surface'))
  return out

::class PCBRouteSurface public
::method init; expose board; use strict arg board
::method propose
  use arg service,text
  t=translate(strip(text))
  if t='ROUTE NETS' | t='ROUTE BOARD' then return .Array~of(.IntentionProposal~new('PCB_ROUTE_NETS',100,'PCB_ROUTING_SURFACE',.true,'manufacturing-qualified routing surface'))
  return .Array~new

::class PCBVerifyRoutingSurface public
::method init; expose board circuit; use strict arg board,circuit
::method propose
  use arg service,text
  t=translate(strip(text))
  if t='VERIFY ROUTING' | t='CHECK ROUTING' then return .Array~of(.IntentionProposal~new('PCB_VERIFY_ROUTING',100,'PCB_ROUTING_VERIFY_SURFACE',.true,'routed-board verification surface'))
  return .Array~new

::class PCBIntentionSession public
::attribute board get
::attribute circuit get
::attribute service get
::method init
  expose board circuit service discovery
  use strict arg boardArg, circuitArg
  board=boardArg; circuit=circuitArg
  service=.IntentionService~new
  service~registerBucket('PCB', .IntentionBucketPolicy~new('FLEXIBLE',60,12,.false,.false))
  /* Internal registration phrases are deliberately not the human phrases.
   * Human-facing availability comes only from current discovery surfaces. */
  service~register('PCB_INSPECT_BOARD', .PCBInspectBoardEvent~new(board),'PCB')
  service~register('PCB_VERIFY_BOARD', .PCBVerifyBoardEvent~new(board,circuit),'PCB')
  service~register('PCB_ROUTE_NETS', .PCBRouteNetsEvent~new(board),'PCB')
  service~register('PCB_VERIFY_ROUTING', .PCBVerifyBoardEvent~new(board,circuit),'PCB')
  discovery=.PCBIntentionDiscovery~new(board,circuit)
  service~registerDiscoveryProvider(discovery)
  service~refreshDiscovery
::method refresh
  expose service
  service~refreshDiscovery
  return self
::method generation
  expose service
  return service~discoveryGeneration
::method capabilities
  expose service
  a=.Array~new
  do ad over service~discoverySurfaces
    a~append(ad~surfaceId)
  end
  return a
::method hasCapability
  expose service
  use strict arg wanted
  wanted=translate(strip(wanted))
  /* Compatibility vocabulary maps old operation names to native surfaces. */
  select
    when wanted='INSPECT_BOARD' | wanted='VERIFY_BOARD' then wanted='PCB_BOARD'
    when wanted='ROUTE_NETS' then wanted='PCB_ROUTING'
    when wanted='VERIFY_ROUTING' then wanted='PCB_ROUTING_VERIFICATION'
    otherwise nop
  end
  do ad over service~discoverySurfaces
    if ad~surfaceId=wanted then return .true
  end
  return .false
::method input
  expose service
  use strict arg text
  return service~input(text)
::method dispatch
  expose service
  use strict arg decision
  return service~dispatch(decision)

::class PCBInspectBoardEvent public
::method init; expose board; use strict arg board
::method invoke
  expose board
  use arg decision
  d=.Directory~new
  d['BOARD_ID']=board~id; d['PLACEMENTS']=board~placements~items
  d['ENDPOINTS']=board~endpoints~items; d['TRACKS']=board~tracks~items; d['VIAS']=board~vias~items
  return d

::class PCBVerifyBoardEvent public
::method init; expose board circuit; use strict arg board, circuit
::method invoke
  expose board circuit
  use arg decision
  return .PCBBoardVerifier~verify(board,circuit)

::class PCBRouteNetsEvent public
::method init; expose board; use strict arg board
::method invoke
  expose board
  use arg decision
  nets=.Array~new; seen=.Directory~new
  do key over board~endpoints
    e=board~endpoints[key]
    nk=e~net~name~upper
    if \seen~hasIndex(nk) then do; seen[nk]=e~net; nets~append(e~net); end
  end
  made=.Array~new
  do net over nets
    routed=.PCBDeterministicRouter~routeNet(board,net)
    do track over routed; made~append(track); end
  end
  return made

::requires 'PCBPlanner.cls'
::requires 'IntentionService.cls'
::requires 'IntentionProviders.cls'
