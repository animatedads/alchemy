/* Differential subscription reconciliation and canonical journey wire representation. */
::class WireUIDefinitionPlanner subclass AlchemyObject public
::method init
  self~init:super(.WireUIAlchemy~metadata("Differential Wire UI journey definition planner"))

::method subscriptionId private
  use arg entry
  if entry~isA(.string) then return entry
  if entry~hasMethod("HASINDEX") then do
    if entry~hasIndex("subscription") then return entry["subscription"]
    if entry~hasIndex("name") then return entry["name"]
  end
  return entry~string

::method plan
  use arg journey
  p=.table~new
  p["state"]=journey~currentState
  p["ACTIVE"]=journey~tier("ACTIVE")
  p["PREFETCH"]=journey~tier("PREFETCH")
  p["ON_DEMAND"]=journey~tier("ON_DEMAND")
  p["REQUESTED_ON_DEMAND"]=journey~requestedOnDemand
  return p

::method desiredSet private
  use arg p
  desired=.set~new
  do tier over .array~of("ACTIVE","PREFETCH","REQUESTED_ON_DEMAND")
    do entry over p[tier]
      desired~put(self~subscriptionId(entry))
    end
  end
  return desired

::method apply
  use arg app, journey
  p=self~plan(journey)
  desired=self~desiredSet(p)
  active=.set~new
  do sub over app~activeSubscriptions
    active~put(sub~subscriptionId)
  end
  activated=.array~new
  deactivated=.array~new
  do sid over active
    if \desired~hasIndex(sid) then do
      r=app~deactivateSubscription(sid)
      if \r~ok then return r
      deactivated~append(sid)
    end
  end
  do sid over desired
    if \active~hasIndex(sid) then do
      r=app~activateSubscription(sid)
      if \r~ok then return r
      activated~append(sid)
    end
  end
  p["activated"]=activated
  p["deactivated"]=deactivated
  return .WireUIResult~success(p)

::method requestOnDemand
  use arg app, journey, capability, subscriptionId = ""
  r=journey~requestOnDemand(capability, subscriptionId)
  if \r~ok then return r
  return self~apply(app, journey)

/* Canonical JS v0.3.1 journey-plan shape. */
::method asWire
  use arg app, journey, journeyRef = ""
  fields=.table~new
  fields["planId"]=app~applicationId":"journey~currentState":"journey~planRevision
  fields["revision"]=journey~planRevision
  if journeyRef="" then journeyRef=app~applicationId":"journey~currentState
  fields["journeyRef"]=journeyRef
  fields["transitionRef"]=journey~transitionRef
  fields["active"]=self~tierAsWire(app,journey~tier("ACTIVE"),.false)
  fields["prefetch"]=self~tierAsWire(app,journey~tier("PREFETCH"),.false)
  fields["onDemand"]=self~tierAsWire(app,journey~tier("ON_DEMAND"),.true)
  return .WireUIProtocol~message(.WireUIProtocol~UI_JOURNEY_PLAN,fields)

::method tierAsWire private
  use arg app, entries, includeCapability
  out=.array~new
  do entry over entries
    sid=self~subscriptionId(entry)
    sub=app~subscription(sid)
    if sub \== .nil then do
      w=sub~asPlanEntry
      if includeCapability then do
        capability=sid
        if \entry~isA(.string) & entry~hasMethod("HASINDEX") & entry~hasIndex("capability") then capability=entry["capability"]
        w["capability"]=capability
      end
      out~append(w)
    end
  end
  return out
::requires "WireUIJourneyPlan.cls"
::requires "WireUIAlchemy.cls"
