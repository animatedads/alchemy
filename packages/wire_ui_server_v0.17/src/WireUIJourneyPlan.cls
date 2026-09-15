/* Server-owned journey plan with explicit ACTIVE/PREFETCH/ON_DEMAND capability mapping. */
::class WireUIJourneyPlan subclass AlchemyObject public
::method init
  expose states transitions currentState history requestedOnDemand sequence planSequence
  self~init:super(.WireUIAlchemy~metadata("Server-owned Wire UI customer journey plan"))
  states = .table~new
  transitions = .table~new
  currentState = ""
  history = .array~new
  requestedOnDemand = .set~new
  sequence = 0
  planSequence = 0
  self~registerStateVariable("currentState", "CUSTOMER", "current semantic journey state")

::method defineState
  expose states
  use arg stateId, active = .nil, prefetch = .nil, onDemand = .nil
  s=.table~new
  s["ACTIVE"]=self~arrayOrEmpty(active)
  s["PREFETCH"]=self~arrayOrEmpty(prefetch)
  s["ON_DEMAND"]=self~arrayOrEmpty(onDemand)
  states[stateId]=s
  return self

/* Add an explicit capability -> subscription mapping to ON_DEMAND. */
::method addOnDemand
  expose states
  use arg stateId, capability, subscriptionId
  if \states~hasIndex(stateId) then return .WireUIResult~failure("JOURNEY_STATE_NOT_FOUND",stateId)
  e=.table~new; e["capability"]=capability; e["subscription"]=subscriptionId
  states[stateId]["ON_DEMAND"]~append(e)
  return .WireUIResult~success(e)

::method allowTransition
  expose transitions
  use arg fromState, toState, trigger = "", purpose = ""
  key = fromState"|"toState
  t=.table~new; t["fromState"]=fromState; t["toState"]=toState; t["trigger"]=trigger; t["purpose"]=purpose
  transitions[key]=t
  return self

::method enter
  expose states transitions currentState history requestedOnDemand sequence planSequence
  use arg stateId, trigger = "", evidence = .nil
  if \states~hasIndex(stateId) then return .WireUIResult~failure("JOURNEY_STATE_NOT_FOUND", stateId)
  previous = currentState
  purpose = ""
  if previous \= "" then do
    key = previous"|"stateId
    if transitions~items > 0 & \transitions~hasIndex(key) then return .WireUIResult~failure("JOURNEY_TRANSITION_NOT_ALLOWED", key)
    if transitions~hasIndex(key) then do
      spec=transitions[key]
      purpose=spec["purpose"]
      if spec["trigger"] \= "" & trigger \= spec["trigger"] then return .WireUIResult~failure("JOURNEY_TRIGGER_MISMATCH", trigger)
    end
  end
  currentState=stateId
  requestedOnDemand=.set~new
  planSequence += 1
  if previous \= "" then do
    sequence += 1
    transition=.WireUIJourneyTransition~new(previous,stateId,trigger,purpose,evidence,sequence)
    history~append(transition)
  end
  return .WireUIResult~success(currentState)

::method currentState
  expose currentState
  return currentState

::method planRevision
  expose planSequence
  return planSequence

::method transitionRef
  expose history
  if history~items=0 then return .nil
  t=history[history~items]
  return "TRANSITION-"t~sequence

::method tier
  expose states currentState
  use arg name
  if currentState="" then return .array~new
  return states[currentState][name]

::method subscriptionIdOf private
  use arg entry
  if entry~isA(.string) then return entry
  if entry~hasMethod("HASINDEX") then do
    if entry~hasIndex("subscription") then return entry["subscription"]
    if entry~hasIndex("name") then return entry["name"]
  end
  return entry~string

::method capabilityOf private
  use arg entry
  if entry~isA(.string) then return entry
  if entry~hasMethod("HASINDEX") & entry~hasIndex("capability") then return entry["capability"]
  return self~subscriptionIdOf(entry)

::method requestOnDemand
  expose requestedOnDemand
  use arg capability, subscriptionId = ""
  allowed=self~tier("ON_DEMAND")
  matched=""
  do entry over allowed
    cap=self~capabilityOf(entry)
    sid=self~subscriptionIdOf(entry)
    if cap=capability then do
      if subscriptionId \= "" & sid \= subscriptionId then return .WireUIResult~failure("ON_DEMAND_SUBSCRIPTION_MISMATCH",subscriptionId)
      matched=sid
      leave
    end
  end
  if matched="" then return .WireUIResult~failure("ON_DEMAND_NOT_AVAILABLE", capability)
  requestedOnDemand~put(matched)
  return .WireUIResult~success(matched)

::method requestedOnDemand
  expose requestedOnDemand
  return requestedOnDemand~makeArray

::method transitionHistory
  expose history
  copy=.array~new
  do t over history; copy~append(t); end
  return copy

::method arrayOrEmpty private
  use arg a
  if a == .nil then return .array~new
  return a
::requires "WireUIJourneyTransition.cls"
::requires "WireUIProtocol.cls"
::requires "WireUIAlchemy.cls"
