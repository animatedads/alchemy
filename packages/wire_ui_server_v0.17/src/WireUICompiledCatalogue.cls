/* Runtime-neutral consumer for Builder compiled interaction packages.
   This class deliberately uses the compiled package public contract rather than Builder classes. */
::class WireUICompiledCatalogue subclass AlchemyObject public
::attribute releaseBinding get
::method init
  expose releaseBinding definitions journeyPlans materials experiments package
  use arg package
  self~init:super(.WireUIAlchemy~metadata("Immutable compiled Wire UI interaction catalogue"))
  definitions=.array~new; journeyPlans=.array~new; materials=.array~new; experiments=.array~new
  if package==.nil then raise syntax 93.906 array("compiled package","nil")
  if package~isA(.Table) | package~isA(.Directory) then do
    rw=self~field(package,"releaseRef",.nil)
    packageAddress=self~field(package,"contentAddress","")
    sourceDefinitions=self~field(package,"definitions",.array~new)
    sourcePlans=self~field(package,"journeyPlans",.array~new)
    sourceMaterials=self~field(package,"materials",.array~new)
    sourceExperiments=self~field(package,"experiments",.array~new)
  end
  else do
    if \package~hasMethod("DEFINITIONS") | \package~hasMethod("JOURNEYPLANS") | \package~hasMethod("RELEASEREF") | \package~hasMethod("CONTENTADDRESS") then raise syntax 93.906 array("compiled package","unsupported contract")
    pref=package~releaseRef
    if pref==.nil | \pref~hasMethod("ASWIRE") then raise syntax 93.906 array("compiled package","missing release ref")
    rw=pref~asWire
    packageAddress=package~contentAddress
    sourceDefinitions=package~definitions; sourcePlans=package~journeyPlans; sourceMaterials=package~materials; sourceExperiments=package~experiments
  end
  if rw==.nil then raise syntax 93.906 array("compiled package","missing release ref")
  if self~field(rw,"contentAddress","")="" | packageAddress="" then raise syntax 93.906 array("compiled package","unsealed")
  releaseBinding=.WireUISiteReleaseBinding~new(self~field(rw,"id",self~field(rw,"releaseId","")),self~field(rw,"version",""),self~field(rw,"contentAddress",""),packageAddress)
  do d over sourceDefinitions; definitions~append(self~copyTable(d)); end
  do p over sourcePlans; journeyPlans~append(self~copyTableDeep(p)); end
  do m over sourceMaterials; materials~append(self~copyTableDeep(m)); end
  do e over sourceExperiments; experiments~append(self~copyTableDeep(e)); end
  self~registerStateVariable("releaseBinding","PUBLIC","exact compiled site release provenance")

::method definitions
  expose definitions
  return self~copyArrayDeep(definitions)
::method journeyPlans
  expose journeyPlans
  return self~copyArrayDeep(journeyPlans)
::method materials
  expose materials
  return self~copyArrayDeep(materials)
::method experiments
  expose experiments
  return self~copyArrayDeep(experiments)

::method materialMessages
  expose materials releaseBinding
  messages=.array~new
  do material over materials
    fields=self~copyTableDeep(material)
    fields["siteRelease"]=releaseBinding~asWire
    messages~append(.WireUIProtocol~message(.WireUIProtocol~UI_MATERIAL_SET,fields))
  end
  return messages

::method profiles
  expose journeyPlans
  s=.set~new; do p over journeyPlans; s~put(p["profile"]); end; a=s~makeArray; a~sort; return a

::method experiment
  expose experiments
  use arg experimentId
  do e over experiments
    if self~field(e,"experimentId","")=experimentId then return self~copyTableDeep(e)
  end
  return .nil

::method assignExperiment
  expose releaseBinding
  use arg app, experimentId, variantId, subjectRef=""
  e=self~experiment(experimentId)
  if e==.nil then return .WireUIResult~failure("EXPERIMENT_NOT_FOUND",experimentId)
  selected=.nil
  do v over e["variants"]
    if self~field(v,"variantId","")=variantId then do; selected=v; leave; end
  end
  if selected==.nil then return .WireUIResult~failure("EXPERIMENT_VARIANT_NOT_FOUND",experimentId":"variantId)
  profile=app~interactionProfile
  definitionKey=self~definitionKeyForProjection(profile,self~field(selected,"projectionRef",.nil))
  if definitionKey="" then return .WireUIResult~failure("EXPERIMENT_VARIANT_DEFINITION_NOT_FOUND",experimentId":"variantId)
  assignmentUnit=self~field(e,"assignmentUnit","")
  if (assignmentUnit="USER" | assignmentUnit="SESSION") & subjectRef="" then return .WireUIResult~failure("EXPERIMENT_SUBJECT_REQUIRED",experimentId)
  assignment=.WireUIExperimentAssignment~new(experimentId,variantId,self~field(e,"targetElementId",""),assignmentUnit,definitionKey,subjectRef,releaseBinding~contentAddress)
  r=app~setExperimentAssignment(assignment); if \r~ok then return r
  state=""
  if app~journeyPlanMessage~ok then state=app~journeyPlanMessage~value["journeyRef"]
  /* Re-materialise the current profile/state so exact subscription definitions follow the assignment. */
  desiredState=""
  currentJourney=app~journeyPlanMessage
  if currentJourney~ok then do
    jr=currentJourney~value["journeyRef"]
    parse var jr . ":" desiredState
  end
  r=self~activateProfile(app,profile,desiredState)
  if \r~ok then return r
  return .WireUIResult~success(assignment,"EXPERIMENT_ASSIGNED")

::method definitionKeyForProjection private
  expose definitions
  use arg profile, projectionRef
  if projectionRef==.nil then return ""
  pr=self~refWire(projectionRef)
  pid=self~field(pr,"id",self~field(pr,"artifactId",""))
  pv=self~field(pr,"version","")
  do d over definitions
    if self~field(d,"profile","")<>profile then iterate
    dr=self~refWire(self~field(d,"projectionRef",.nil))
    if dr==.nil then iterate
    did=self~field(dr,"id",self~field(dr,"artifactId",""))
    dv=self~field(dr,"version","")
    if did=pid & dv=pv then return d["definitionKey"]
  end
  return ""

::method refWire private
  use arg ref
  if ref==.nil then return .nil
  if ref~isA(.Table) | ref~isA(.Directory) then return ref
  if ref~hasMethod("ASWIRE") then return ref~asWire
  return .nil

::method registerDefinitions
  expose definitions releaseBinding
  use arg app
  do d over definitions
    md=.table~new
    md["profile"]=self~field(d,"profile","")
    md["materialRole"]=self~field(d,"materialRole","")
    md["componentRef"]=self~field(d,"componentRef",.nil)
    md["projectionRef"]=self~field(d,"projectionRef",.nil)
    md["semanticElementRef"]=self~field(d,"semanticElementRef",.nil)
    md["bindings"]=self~field(d,"bindings",.nil)
    md["siteRelease"]=releaseBinding~asWire
    def=.WireUIElementDefinition~new(d["definitionId"],d["definitionVersion"],d["primitive"],self~field(d,"action",""),"",self~field(d,"styleRole",""),md,d["contentAddress"])
    r=app~registerDefinition(def)
    if \r~ok then return r
  end
  return .WireUIResult~success(definitions~items,"COMPILED_DEFINITIONS_REGISTERED")

::method bindApplication
  expose releaseBinding
  use arg app, profile, desiredState=""
  r=self~registerDefinitions(app); if \r~ok then return r
  r=self~activateProfile(app,profile,desiredState); if \r~ok then return r
  app~setSiteReleaseBinding(releaseBinding,self)
  return .WireUIResult~success(releaseBinding,"SITE_RELEASE_BOUND")

::method activateProfile
  expose journeyPlans releaseBinding
  use arg app, profile, desiredState=""
  selected=.nil
  do p over journeyPlans
    if p["profile"]=profile then do; selected=p; leave; end
  end
  if selected==.nil then return .WireUIResult~failure("RELEASE_PROFILE_NOT_COMPILED",profile)
  /* Old release-managed subscriptions may remain registered for provenance, but never active. */
  do sub over app~activeSubscriptions
    if sub~subscriptionId~left(7)="WUIREL." then do
      r=app~deactivateSubscription(sub~subscriptionId); if \r~ok then return r
    end
  end
  journey=.WireUIJourneyPlan~new
  prefix="WUIREL."releaseBinding~releaseId"."releaseBinding~version"."profile"."
  do row over selected["states"]
    state=row["stateId"]
    active=.array~new; prefetch=.array~new; ondemand=.array~new
    do tier over .array~of("ACTIVE","PREFETCH")
      defs=self~definitionKeysForTier(app,profile,row,tier)
      if defs~items>0 then do
        sid=prefix||state"."tier||self~assignmentSuffix(app)
        sub=app~subscription(sid)
        if sub==.nil then do
          sub=.WireUISubscription~new(sid,releaseBinding~version,"compiled "tier" for "state,releaseBinding~exactKey)
          do key over defs; ignore=sub~addDefinition(key); end
          app~addSubscription(sub)
        end
        if tier="ACTIVE" then active~append(sid); else prefetch~append(sid)
      end
    end
    /* ON_DEMAND is capability-oriented: one semantic element -> one exact subscription. */
    elements=self~field(row,"ON_DEMAND_ELEMENTS",.array~new)
    do elementId over elements
      keys=self~definitionKeysForElement(profile,elementId,app)
      if keys~items=0 then iterate
      sid=prefix||state".ON_DEMAND."elementId||self~assignmentSuffix(app)
      sub=app~subscription(sid)
      if sub==.nil then do
        sub=.WireUISubscription~new(sid,releaseBinding~version,"compiled on-demand capability "elementId,releaseBinding~exactKey)
        do key over keys; ignore=sub~addDefinition(key); end
        app~addSubscription(sub)
      end
      e=.table~new; e["capability"]=elementId; e["subscription"]=sid; ondemand~append(e)
    end
    journey~defineState(state,active,prefetch,ondemand)
  end
  do t over selected["transitions"]
    journey~allowTransition(t["fromState"],t["toState"],self~field(t,"trigger",""),self~field(t,"purpose",""))
  end
  initial=selected["initialState"]
  if desiredState<>"" then do
    found=.false
    do row over selected["states"]; if row["stateId"]=desiredState then found=.true; end
    if found then initial=desiredState
  end
  r=journey~enter(initial,"RELEASE_BIND"); if \r~ok then return r
  planner=.WireUIDefinitionPlanner~new
  app~attachJourney(journey,planner)
  r=planner~apply(app,journey); if \r~ok then return r
  return .WireUIResult~success(journey,"RELEASE_PROFILE_ACTIVATED")

::method definitionKeysForTier private
  use arg app, profile, row, tier
  elementField=tier || "_ELEMENTS"
  elements=self~field(row,elementField,.array~new)
  if elements~items=0 then return self~copyArrayDeep(self~field(row,tier,.array~new))
  keys=.array~new
  do elementId over elements
    ek=self~definitionKeysForElement(profile,elementId,app)
    do key over ek; keys~append(key); end
  end
  return keys

::method definitionKeysForElement private
  expose definitions experiments
  use arg profile, elementId, app=.nil
  if app\==.nil then do e over experiments
    if self~field(e,"targetElementId","")<>elementId then iterate
    assignment=app~experimentAssignment(self~field(e,"experimentId",""))
    if assignment\==.nil then do
      key=assignment~definitionKey
      if key<>"" & self~definitionKeyHasProfile(key,profile) then return .array~of(key)
    end
  end
  a=.array~new
  do d over definitions
    if d["profile"]<>profile then iterate
    er=self~field(d,"semanticElementRef",.nil)
    if er<>.nil & self~field(er,"id","")=elementId then a~append(d["definitionKey"])
  end
  return a

::method definitionKeyHasProfile private
  expose definitions
  use arg key, profile
  do d over definitions
    if d["definitionKey"]=key then return self~field(d,"profile","")=profile
  end
  return .false

::method assignmentSuffix private
  use arg app
  assignments=app~experimentAssignments
  if assignments~items=0 then return ""
  keys=assignments~allIndexes; keys~sort
  text=""
  do k over keys
    a=assignments[k]
    text ||= ".EXP-" || k || "-" || a~variantId
  end
  return text

::method field private
  use arg t,k,default=.nil
  if t==.nil then return default
  if t~hasIndex(k) then return t[k]
  return default
::method copyTable private
  use arg source
  t=.table~new; do k over source~allIndexes; t[k]=source[k]; end; return t
::method copyTableDeep private
  use arg source
  t=.table~new
  do k over source~allIndexes; t[k]=self~copyValue(source[k]); end
  return t
::method copyArrayDeep private
  use arg source
  a=.array~new; do v over source; a~append(self~copyValue(v)); end; return a
::method copyValue private
  use arg v
  if v==.nil then return .nil
  if v~isA(.Table) | v~isA(.Directory) then return self~copyTableDeep(v)
  if v~isA(.Array) then return self~copyArrayDeep(v)
  return v
::requires "WireUISiteReleaseBinding.cls"
::requires "WireUIExperimentAssignment.cls"
::requires "WireUIElementDefinition.cls"
::requires "WireUISubscription.cls"
::requires "WireUIJourneyPlan.cls"
::requires "WireUIDefinitionPlanner.cls"
::requires "WireUIAlchemy.cls"
