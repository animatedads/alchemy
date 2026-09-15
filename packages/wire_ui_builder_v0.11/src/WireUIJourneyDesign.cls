/* Journey authoring uses semantic element identities, not pages or DOM nodes.
   A journey may contain named flows. Flows group journey states; they are not
   independent applications or detached flow artifacts. State ids remain
   journey-unique so the existing WIRE-UI/0.1 runtime can flatten safely.

   v0.11 also makes conditional journey edges first-class. Conditions are exact
   semantic CONDITION artifact ids evaluated authoritatively by a capable
   runtime (or explicitly by an authoring preview scenario). The browser never
   owns transition predicates. */
::class WireUIJourneyDesign subclass AlchemyObject public
::attribute journeyId get
::attribute version get
::attribute initialState get
::attribute initialFlowId get
::attribute contentAddress get
::method init
  expose journeyId version initialState initialFlowId states transitions flows contentAddress sealed
  use arg journeyId, version, initialState, initialFlowId=""
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned semantic customer journey design"))
  journeyId=journeyId~string~strip; version=version~string~strip; initialState=initialState~string~strip; initialFlowId=initialFlowId~string~strip
  states=.table~new; transitions=.table~new; flows=.table~new; sealed=.false; contentAddress=""
  if journeyId="" | version="" | initialState="" then raise syntax 93.906 array("journey", journeyId)
::method defineFlow
  expose flows sealed
  use arg flowId, flowInitialState, metadata=.nil
  if sealed then return .WireUIDesignResult~failure("JOURNEY_SEALED")
  flowId=flowId~string~strip; flowInitialState=flowInitialState~string~strip
  if flowId="" | flowInitialState="" then return .WireUIDesignResult~failure("JOURNEY_FLOW_ID_INITIAL_REQUIRED")
  f=.table~new; f["flowId"]=flowId; f["initialState"]=flowInitialState; f["metadata"]=.WireUIDesignUtil~copyTable(metadata); flows[flowId]=f
  return .WireUIDesignResult~success(self)
::method defineState
  expose states sealed flows
  use arg stateId, active=.nil, prefetch=.nil, onDemand=.nil, flowId=""
  if sealed then return .WireUIDesignResult~failure("JOURNEY_SEALED")
  stateId=stateId~string~strip; flowId=flowId~string~strip
  if stateId="" then return .WireUIDesignResult~failure("JOURNEY_STATE_ID_REQUIRED")
  if flowId<>"" & flows~items>0 & \flows~hasIndex(flowId) then return .WireUIDesignResult~failure("JOURNEY_STATE_FLOW_UNDEFINED",flowId)
  s=.table~new; s["ACTIVE"]=.WireUIDesignUtil~copyArray(active); s["PREFETCH"]=.WireUIDesignUtil~copyArray(prefetch); s["ON_DEMAND"]=.WireUIDesignUtil~copyArray(onDemand); s["flowId"]=flowId
  states[stateId]=s
  return .WireUIDesignResult~success(self)
::method allowTransition
  expose transitions sealed
  use arg fromState,toState,trigger="",purpose="",whenConditionIds=.nil,suppressConditionIds=.nil,whenMode="ALL"
  if sealed then return .WireUIDesignResult~failure("JOURNEY_SEALED")
  fromState=fromState~string~strip; toState=toState~string~strip; trigger=trigger~string~strip; purpose=purpose~string~strip
  whenMode=whenMode~string~strip~translate
  if fromState="" | toState="" then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_STATES_REQUIRED")
  if whenMode<>"ALL" & whenMode<>"ANY" then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_WHEN_MODE_INVALID",whenMode)
  whenConditionIds=.WireUIDesignUtil~copyArray(whenConditionIds); suppressConditionIds=.WireUIDesignUtil~copyArray(suppressConditionIds)
  do ids over .array~of(whenConditionIds,suppressConditionIds)
    do cid over ids
      if cid~string~strip="" then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_CONDITION_ID_REQUIRED")
    end
  end
  t=.table~new; t["fromState"]=fromState; t["toState"]=toState; t["trigger"]=trigger; t["purpose"]=purpose
  t["whenMode"]=whenMode; t["whenConditionIds"]=whenConditionIds; t["suppressConditionIds"]=suppressConditionIds
  /* Trigger participates in identity so a journey may expose more than one
     semantic route between the same state pair without accidental overwrite. */
  transitions[fromState"|"toState"|"trigger]=t
  return .WireUIDesignResult~success(self)
::method seal
  expose states initialState initialFlowId flows transitions sealed contentAddress
  if \states~hasIndex(initialState) then return .WireUIDesignResult~failure("INITIAL_STATE_UNDEFINED",initialState)
  if flows~items>0 then do
    if initialFlowId="" | \flows~hasIndex(initialFlowId) then return .WireUIDesignResult~failure("JOURNEY_INITIAL_FLOW_UNDEFINED",initialFlowId)
    do fid over flows~allIndexes
      f=flows[fid]; sid=f["initialState"]
      if \states~hasIndex(sid) then return .WireUIDesignResult~failure("JOURNEY_FLOW_INITIAL_STATE_UNDEFINED",fid"|"sid)
      if states[sid]["flowId"]<>fid then return .WireUIDesignResult~failure("JOURNEY_FLOW_INITIAL_STATE_MISMATCH",fid"|"sid)
    end
    do sid over states~allIndexes
      fid=states[sid]["flowId"]
      if fid="" | \flows~hasIndex(fid) then return .WireUIDesignResult~failure("JOURNEY_STATE_FLOW_REQUIRED",sid)
    end
  end
  do tk over transitions~allIndexes
    t=transitions[tk]
    if \states~hasIndex(t["fromState"]) then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_FROM_STATE_UNDEFINED",t["fromState"])
    if \states~hasIndex(t["toState"]) then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_TO_STATE_UNDEFINED",t["toState"])
  end
  contentAddress=.WireUIDesignUtil~token(self~canonicalText); sealed=.true
  return .WireUIDesignResult~success(self)
::method isSealed
  expose sealed; return sealed
::method state
  expose states; use arg stateId; if states~hasIndex(stateId) then return states[stateId]; return .nil
::method stateIds
  expose states; a=states~allIndexes; a~sort; return a
::method flow
  expose flows; use arg flowId; if flows~hasIndex(flowId) then return .WireUIDesignUtil~copyTable(flows[flowId]); return .nil
::method flowIds
  expose flows; a=flows~allIndexes; a~sort; return a
::method flows
  expose flows; a=.array~new; keys=flows~allIndexes; keys~sort; do k over keys; a~append(.WireUIDesignUtil~copyTable(flows[k])); end; return a
::method transitions
  expose transitions; a=.array~new; keys=transitions~allIndexes; keys~sort; do k over keys; a~append(.WireUIDesignUtil~copyTable(transitions[k])); end; return a
::method canonicalText
  expose journeyId version initialState initialFlowId states transitions flows
  text=journeyId"|"version"|"initialState"|"initialFlowId"|"
  fkeys=flows~allIndexes; fkeys~sort; do k over fkeys; text ||= "F:"k":".WireUIDesignUtil~canonicalTable(flows[k])"|"; end
  keys=states~allIndexes; keys~sort
  do k over keys
    s=states[k]; text ||= "S:"k":"s["flowId"]":".WireUIDesignUtil~canonicalArray(s["ACTIVE"] )":".WireUIDesignUtil~canonicalArray(s["PREFETCH"] )":".WireUIDesignUtil~canonicalArray(s["ON_DEMAND"] )"|"
  end
  tkeys=transitions~allIndexes; tkeys~sort; do k over tkeys; text ||= "T:"k":".WireUIDesignUtil~canonicalTable(transitions[k])"|"; end
  return text
::method ref
  expose journeyId version contentAddress sealed
  if \sealed then return .nil
  return .WireUIArtifactRef~new("JOURNEY",journeyId,version,contentAddress)
::method asWire
  expose journeyId version initialState initialFlowId states contentAddress sealed
  d=.table~new; d["journeyId"]=journeyId; d["version"]=version; d["initialState"]=initialState; d["initialFlowId"]=initialFlowId; d["flows"]=self~flows; d["contentAddress"]=contentAddress; d["sealed"]=sealed
  ss=.array~new; keys=states~allIndexes; keys~sort; do k over keys; r=.table~new; r["stateId"]=k; r["flowId"]=states[k]["flowId"]; r["ACTIVE"]=.WireUIDesignUtil~copyArray(states[k]["ACTIVE"]); r["PREFETCH"]=.WireUIDesignUtil~copyArray(states[k]["PREFETCH"]); r["ON_DEMAND"]=.WireUIDesignUtil~copyArray(states[k]["ON_DEMAND"]); ss~append(r); end
  d["states"]=ss; d["transitions"]=self~transitions; return d
::requires "WireUIDesignSupport.cls"
