/* Stateful serialised owner of application truth, semantic UI and journey wire authority. */
::requires "WireUIProtocol.cls"
::requires "WireUIExperimentAssignment.cls"
::requires "WireUIWorkspaceResultState.cls"

::class WireUIApplication subclass AlchemyObject public
::attribute applicationId get
::attribute sessionId get
::attribute accessPointId get
::attribute view get
::attribute projection get
::attribute interactionProfile get
::attribute siteReleaseBinding get
::attribute renderProfileId get

::method init
  expose applicationId sessionId accessPointId view projection subscriptions definitions businessState processedMessages outbound securityPolicy interactionProfile journey planner profileOffers offerSequence siteReleaseBinding siteCatalogue observationDefinitions acceptedObservations experimentAssignments renderProfilePolicy renderProfileId capabilityFingerprint definitionManifest sentDefinitionDeliveries timingClock timingRecords timingSequence workspaceQueries workspaceSelections workspaceResults
  use arg applicationId, sessionId, accessPointId, view, projection
  self~init:super(.WireUIAlchemy~metadata("Stateful authoritative Wire UI application interaction"))
  subscriptions = .table~new
  definitions = .table~new
  businessState = .table~new
  processedMessages = .table~new
  outbound = .array~new
  securityPolicy = .nil
  interactionProfile = .WireUIProtocol~PROFILE_HUMAN_VISUAL
  journey=.nil; planner=.nil
  profileOffers=.table~new; offerSequence=0
  siteReleaseBinding=.nil; siteCatalogue=.nil
  observationDefinitions=.table~new; acceptedObservations=.array~new; experimentAssignments=.table~new
  renderProfilePolicy=.WireUIRenderProfilePolicy~new("generic")
  renderProfileId=""
  capabilityFingerprint=""
  definitionManifest=.nil
  sentDefinitionDeliveries=.set~new
  timingClock=.WireUITimingClock~new
  timingRecords=.array~new
  timingSequence=0
  workspaceQueries=.table~new
  workspaceSelections=.table~new
  workspaceResults=.table~new
  self~registerStateVariable("applicationId", "CUSTOMER", "Wire UI application identity")
  self~registerStateVariable("interactionProfile", "CUSTOMER", "selected semantic interaction projection")

::method registerWorkspace
  expose workspaceQueries workspaceSelections workspaceResults
  use arg workspaceRef
  workspaceRef=workspaceRef~string~strip
  if workspaceRef="" then return .WireUIResult~failure("WORKSPACE_REF_REQUIRED")
  if workspaceQueries~hasIndex(workspaceRef) then return .WireUIResult~success(self~workspaceContext(workspaceRef),"ALREADY_REGISTERED")
  query=.WireUIWorkspaceQueryState~new(workspaceRef)
  selection=.WireUIWorkspaceSelection~new(workspaceRef,query~scopeRevision)
  resultState=.WireUIWorkspaceResultState~new(workspaceRef)
  workspaceQueries[workspaceRef]=query
  workspaceSelections[workspaceRef]=selection
  workspaceResults[workspaceRef]=resultState
  return .WireUIResult~success(self~workspaceContext(workspaceRef),"WORKSPACE_REGISTERED")

::method workspaceQuery
  expose workspaceQueries
  use arg workspaceRef
  if workspaceQueries~hasIndex(workspaceRef) then return workspaceQueries[workspaceRef]
  return .nil

::method workspaceSelection
  expose workspaceSelections
  use arg workspaceRef
  if workspaceSelections~hasIndex(workspaceRef) then return workspaceSelections[workspaceRef]
  return .nil

::method workspaceResult
  expose workspaceResults
  use arg workspaceRef
  if workspaceResults~hasIndex(workspaceRef) then return workspaceResults[workspaceRef]
  return .nil

::method publishWorkspaceResult
  expose workspaceQueries workspaceResults
  use arg workspaceRef, totalCount, aggregates=.nil, provenanceRef="", asOfRef=""
  if \workspaceQueries~hasIndex(workspaceRef) then return .WireUIResult~failure("WORKSPACE_NOT_FOUND",workspaceRef)
  r=workspaceResults[workspaceRef]~publish(workspaceQueries[workspaceRef],totalCount,aggregates,provenanceRef,asOfRef)
  if \r~ok then return r
  return .WireUIResult~success(self~workspaceContext(workspaceRef),r~code)

::method setWorkspaceFilter
  expose workspaceQueries workspaceSelections
  use arg workspaceRef, filterRef, value
  if \workspaceQueries~hasIndex(workspaceRef) then return .WireUIResult~failure("WORKSPACE_NOT_FOUND",workspaceRef)
  query=workspaceQueries[workspaceRef]
  beforeScope=query~scopeRevision
  r=query~setFilter(filterRef,value)
  if \r~ok then return r
  if query~scopeRevision<>beforeScope then do
    sr=workspaceSelections[workspaceRef]~invalidateForScope(query~scopeRevision)
    if \sr~ok then return sr
  end
  return .WireUIResult~success(self~workspaceContext(workspaceRef),r~code)

::method removeWorkspaceFilter
  expose workspaceQueries workspaceSelections
  use arg workspaceRef, filterRef
  if \workspaceQueries~hasIndex(workspaceRef) then return .WireUIResult~failure("WORKSPACE_NOT_FOUND",workspaceRef)
  query=workspaceQueries[workspaceRef]
  beforeScope=query~scopeRevision
  r=query~removeFilter(filterRef)
  if \r~ok then return r
  if query~scopeRevision<>beforeScope then do
    sr=workspaceSelections[workspaceRef]~invalidateForScope(query~scopeRevision)
    if \sr~ok then return sr
  end
  return .WireUIResult~success(self~workspaceContext(workspaceRef),r~code)

::method setWorkspaceSort
  expose workspaceQueries
  use arg workspaceRef, sortRef, direction="ASC"
  if \workspaceQueries~hasIndex(workspaceRef) then return .WireUIResult~failure("WORKSPACE_NOT_FOUND",workspaceRef)
  r=workspaceQueries[workspaceRef]~setSort(sortRef,direction)
  if \r~ok then return r
  return .WireUIResult~success(self~workspaceContext(workspaceRef),r~code)

::method setWorkspaceSelection
  expose workspaceQueries workspaceSelections
  use arg workspaceRef, scopeRevision, selectedIds
  if \workspaceQueries~hasIndex(workspaceRef) then return .WireUIResult~failure("WORKSPACE_NOT_FOUND",workspaceRef)
  r=workspaceSelections[workspaceRef]~replace(scopeRevision,selectedIds)
  if \r~ok then return r
  return .WireUIResult~success(self~workspaceContext(workspaceRef),r~code)

::method workspaceCommandContext
  expose workspaceQueries workspaceSelections workspaceResults
  use arg workspaceRef
  if \workspaceQueries~hasIndex(workspaceRef) then return .nil
  query=workspaceQueries[workspaceRef]
  selection=workspaceSelections[workspaceRef]
  resultState=workspaceResults[workspaceRef]
  if resultState~published then return .WireUIWorkspaceCommandContext~new(workspaceRef,query~queryRevision,query~scopeRevision,query~orderRevision,selection~selectionRevision,selection~selectedIds,resultState~resultRevision,resultState~queryRevision,resultState~scopeRevision,resultState~orderRevision,resultState~currentFor(query))
  return .WireUIWorkspaceCommandContext~new(workspaceRef,query~queryRevision,query~scopeRevision,query~orderRevision,selection~selectionRevision,selection~selectedIds)

::method workspaceContext
  use arg workspaceRef
  context=self~workspaceCommandContext(workspaceRef)
  if context==.nil then return .nil
  return context~asWire

::method validateWorkspaceContext private unguarded
  use arg workspaceRef, supplied
  current=self~workspaceCommandContext(workspaceRef)
  if current==.nil then return .WireUIResult~failure("WORKSPACE_NOT_FOUND",workspaceRef)
  if supplied==.nil | \supplied~hasMethod("HASINDEX") then return .WireUIResult~failure("WORKSPACE_CONTEXT_REQUIRED",workspaceRef)
  if self~field(supplied,"workspaceRef","")<>workspaceRef then return .WireUIResult~failure("WORKSPACE_CONTEXT_MISMATCH",self~field(supplied,"workspaceRef",""))
  if self~field(supplied,"queryRevision",-1)<>current~queryRevision then return .WireUIResult~failure("WORKSPACE_QUERY_REVISION_MISMATCH",self~field(supplied,"queryRevision",-1),current~queryRevision)
  if self~field(supplied,"scopeRevision",-1)<>current~scopeRevision then return .WireUIResult~failure("WORKSPACE_SCOPE_REVISION_MISMATCH",self~field(supplied,"scopeRevision",-1),current~scopeRevision)
  if self~field(supplied,"orderRevision",-1)<>current~orderRevision then return .WireUIResult~failure("WORKSPACE_ORDER_REVISION_MISMATCH",self~field(supplied,"orderRevision",-1),current~orderRevision)
  if self~field(supplied,"selectionRevision",-1)<>current~selectionRevision then return .WireUIResult~failure("WORKSPACE_SELECTION_REVISION_MISMATCH",self~field(supplied,"selectionRevision",-1),current~selectionRevision)
  if current~resultRevision\==.nil then do
    if \current~resultCurrent then return .WireUIResult~failure("WORKSPACE_RESULT_NOT_CURRENT",current~resultRevision)
    if self~field(supplied,"resultRevision",-1)<>current~resultRevision then return .WireUIResult~failure("WORKSPACE_RESULT_REVISION_MISMATCH",self~field(supplied,"resultRevision",-1),current~resultRevision)
    if self~field(supplied,"resultQueryRevision",-1)<>current~resultQueryRevision then return .WireUIResult~failure("WORKSPACE_RESULT_QUERY_REVISION_MISMATCH")
    if self~field(supplied,"resultScopeRevision",-1)<>current~resultScopeRevision then return .WireUIResult~failure("WORKSPACE_RESULT_SCOPE_REVISION_MISMATCH")
    if self~field(supplied,"resultOrderRevision",-1)<>current~resultOrderRevision then return .WireUIResult~failure("WORKSPACE_RESULT_ORDER_REVISION_MISMATCH")
  end
  suppliedIds=self~field(supplied,"selectedIds",.nil)
  if suppliedIds==.nil | \suppliedIds~isA(.Array) then return .WireUIResult~failure("WORKSPACE_SELECTION_CONTEXT_INVALID")
  if \self~sameStringArray(suppliedIds,current~selectedIds) then return .WireUIResult~failure("WORKSPACE_SELECTION_MISMATCH")
  return .WireUIResult~success(current,"WORKSPACE_CONTEXT_CURRENT")

::method sameStringArray private unguarded
  use arg left,right
  if left~items<>right~items then return .false
  do i=1 to left~items
    if left[i]<>right[i] then return .false
  end
  return .true

::method setTimingClock
  expose timingClock
  use arg clock
  if clock==.nil | \clock~hasMethod("NOWMICROS") | \clock~hasMethod("WALLSTAMP") then return .WireUIResult~failure("TIMING_CLOCK_INVALID")
  timingClock=clock
  return .WireUIResult~success(clock,"TIMING_CLOCK_SET")

::method recordJourneyTiming
  expose timingClock timingRecords timingSequence workspaceQueries workspaceSelections workspaceResults applicationId journey view siteReleaseBinding
  use arg eventId, correlationId="", detail=.nil
  eventId=eventId~string~strip
  if eventId="" then return .WireUIResult~failure("JOURNEY_TIMING_EVENT_REQUIRED")
  if detail==.nil then detail=.table~new
  if \detail~hasMethod("HASINDEX") then return .WireUIResult~failure("JOURNEY_TIMING_DETAIL_INVALID")
  timingSequence += 1
  state=""; journeyRevision=.nil; transitionRef=.nil
  if journey\==.nil then do
    state=journey~currentState
    journeyRevision=journey~planRevision
    transitionRef=journey~transitionRef
  end
  releaseAddress=""
  if siteReleaseBinding\==.nil then releaseAddress=siteReleaseBinding~contentAddress
  record=.WireUIJourneyTimingRecord~new(timingSequence,eventId,applicationId,state,journeyRevision,transitionRef,view~viewRef,view~revision,correlationId,timingClock~nowMicros,timingClock~wallStamp,detail,releaseAddress)
  timingRecords~append(record)
  return .WireUIResult~success(record,"JOURNEY_TIMING_RECORDED")

::method journeyTimingRecords
  expose timingRecords
  copy=.array~new
  do record over timingRecords; copy~append(record); end
  return copy

::method drainJourneyTimings
  expose timingRecords
  guard on
  result=timingRecords
  timingRecords=.array~new
  guard off
  return result

::method setRenderProfilePolicy
  expose renderProfilePolicy
  use arg policy
  if policy==.nil then return .WireUIResult~failure("RENDER_PROFILE_POLICY_REQUIRED")
  renderProfilePolicy=policy
  return .WireUIResult~success(policy,"RENDER_PROFILE_POLICY_SET")

::method capabilityFingerprint
  expose capabilityFingerprint
  return capabilityFingerprint

::method currentDefinitionManifest
  expose definitionManifest
  return definitionManifest

::method definitionManifestMessage
  expose definitionManifest siteReleaseBinding experimentAssignments
  if definitionManifest==.nil then return .WireUIResult~failure("DEFINITION_MANIFEST_NOT_READY")
  fields=definitionManifest~asWire
  if siteReleaseBinding\==.nil then fields["siteRelease"]=siteReleaseBinding~asWire
  if experimentAssignments~items>0 then fields["experimentAssignments"]=self~experimentAssignmentsWire
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION_MANIFEST,fields))

::method refreshDefinitionManifest
  expose renderProfileId definitionManifest
  use arg emit=.false
  if renderProfileId="" then return .WireUIResult~failure("RENDER_PROFILE_NOT_SELECTED")
  siteId=self~manifestSiteId
  defs=self~authorisedDefinitionObjects
  definitionManifest=.WireUIDefinitionManifest~new(siteId,renderProfileId,defs)
  if emit then do
    r=self~definitionManifestMessage
    if \r~ok then return r
    self~appendOutbound(r~value)
  end
  return .WireUIResult~success(definitionManifest,"DEFINITION_MANIFEST_REFRESHED")

::method renderProfileMessage
  expose definitionManifest renderProfileId siteReleaseBinding
  if definitionManifest==.nil then return .WireUIResult~failure("DEFINITION_MANIFEST_NOT_READY")
  fields=definitionManifest~asWire
  if siteReleaseBinding\==.nil then fields["siteRelease"]=siteReleaseBinding~asWire
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_RENDER_PROFILE,fields))

::method manifestSiteId private
  expose siteReleaseBinding applicationId
  if siteReleaseBinding\==.nil then return siteReleaseBinding~releaseId
  return applicationId

::method authorisedDefinitionObjects private
  expose definitions
  out=.array~new
  emitted=.set~new
  do sub over self~activeSubscriptions
    do key over sub~definitionKeys
      if emitted~hasIndex(key) then iterate
      if definitions~hasIndex(key) then do
        out~append(definitions[key])
        emitted~put(key)
      end
    end
  end
  return out

::method appendOutbound private
  expose outbound
  use arg message
  outbound~append(message)
  return message

::method setSecurityPolicy
  expose securityPolicy
  use arg policy
  securityPolicy = policy
  return self

::method registerObservationDefinition
  expose observationDefinitions
  use arg definition
  key=definition~exactKey
  if observationDefinitions~hasIndex(key) then do
    prior=observationDefinitions[key]
    if prior~contentAddress<>definition~contentAddress then return .WireUIResult~failure("OBSERVATION_DEFINITION_IMMUTABLE",key)
    return .WireUIResult~success(prior,"ALREADY_REGISTERED")
  end
  observationDefinitions[key]=definition
  return .WireUIResult~success(definition)

::method observationDefinition
  expose observationDefinitions
  use arg exactKey
  if observationDefinitions~hasIndex(exactKey) then return observationDefinitions[exactKey]
  return .nil

::method observationPlanMessage
  expose observationDefinitions siteReleaseBinding
  use arg subscriptionId
  sub=self~subscription(subscriptionId)
  if sub==.nil then return .WireUIResult~failure("SUBSCRIPTION_NOT_FOUND",subscriptionId)
  if \sub~active then return .WireUIResult~failure("SUBSCRIPTION_NOT_ACTIVE",subscriptionId)
  fields=.table~new
  fields["subscription"]=sub~subscriptionId
  fields["revision"]=sub~version
  fields["purpose"]=sub~purpose
  fields["policyRef"]=sub~policyRef
  points=.array~new
  do key over sub~observationIds
    if \observationDefinitions~hasIndex(key) then return .WireUIResult~failure("OBSERVATION_DEFINITION_NOT_FOUND",key)
    points~append(observationDefinitions[key]~asPlanPoint)
  end
  fields["points"]=points
  if siteReleaseBinding\==.nil then fields["siteRelease"]=siteReleaseBinding~asWire
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~OBSERVATION_PLAN,fields))

::method emitObservationPlan
  expose outbound
  use arg subscriptionId
  r=self~observationPlanMessage(subscriptionId)
  if \r~ok then return r
  outbound~append(r~value)
  return r

::method drainObservations
  expose acceptedObservations
  guard on
  result=acceptedObservations
  acceptedObservations=.array~new
  guard off
  return result

::method setSiteReleaseBinding
  expose siteReleaseBinding siteCatalogue
  use arg binding, catalogue=.nil
  siteReleaseBinding=binding; siteCatalogue=catalogue
  return self

::method bindCompiledRelease
  use arg catalogue, profile=.nil, desiredState=""
  if profile==.nil then profile=self~interactionProfile
  return catalogue~bindApplication(self,profile,desiredState)

::method siteReleaseContext
  expose siteReleaseBinding
  if siteReleaseBinding==.nil then return .nil
  return siteReleaseBinding~asWire


::method materialSetMessages
  expose siteCatalogue
  if siteCatalogue==.nil then return .WireUIResult~failure("SITE_RELEASE_NOT_BOUND")
  return .WireUIResult~success(siteCatalogue~materialMessages,"MATERIAL_SETS_READY")

::method experimentAssignment
  expose experimentAssignments
  use arg experimentId
  if experimentAssignments~hasIndex(experimentId) then return experimentAssignments[experimentId]
  return .nil

::method experimentAssignments
  expose experimentAssignments
  copy=.table~new
  do k over experimentAssignments~allIndexes; copy[k]=experimentAssignments[k]; end
  return copy

::method experimentAssignmentsWire
  expose experimentAssignments
  copy=.table~new
  do k over experimentAssignments~allIndexes; copy[k]=experimentAssignments[k]~asWire; end
  return copy

::method setExperimentAssignment
  expose experimentAssignments
  use arg assignment
  if assignment==.nil | \assignment~isA(.WireUIExperimentAssignment) then return .WireUIResult~failure("INVALID_EXPERIMENT_ASSIGNMENT")
  experimentAssignments[assignment~experimentId]=assignment
  return .WireUIResult~success(assignment,"EXPERIMENT_ASSIGNED")

::method assignExperiment
  expose siteCatalogue
  use arg experimentId, variantId, subjectRef=""
  if siteCatalogue==.nil then return .WireUIResult~failure("SITE_RELEASE_NOT_BOUND")
  return siteCatalogue~assignExperiment(self,experimentId,variantId,subjectRef)

::method snapshot
  expose view siteReleaseBinding experimentAssignments
  message=view~snapshot
  if siteReleaseBinding\==.nil then message["siteRelease"]=siteReleaseBinding~asWire
  if experimentAssignments~items>0 then message["experimentAssignments"]=self~experimentAssignmentsWire
  return message

::method attachJourney
  expose journey planner
  use arg journeyObject, plannerObject
  journey=journeyObject; planner=plannerObject
  return self


::method advanceJourney
  expose journey planner
  use arg stateId, trigger="", evidence=.nil, correlationId=""
  if journey==.nil | planner==.nil then return .WireUIResult~failure("JOURNEY_NOT_ATTACHED")
  r=journey~enter(stateId,trigger,evidence)
  if \r~ok then return r
  r=planner~apply(self,journey)
  if \r~ok then return r
  r=self~emitJourneyPlan
  if \r~ok then return r
  detail=.table~new; detail["trigger"]=trigger
  tr=self~recordJourneyTiming("JOURNEY_STATE_ENTERED",correlationId,detail)
  if \tr~ok then return tr
  return .WireUIResult~success(journey~currentState,"JOURNEY_ADVANCED")

::method createViewInstance
  expose view
  use arg instanceId, definitionKey, slots=.nil, parentId=""
  if self~definition(definitionKey)==.nil then return .WireUIResult~failure("DEFINITION_NOT_REGISTERED",definitionKey)
  authorised=.false
  do sub over self~activeSubscriptions
    if sub~containsDefinition(definitionKey) then do
      authorised=.true
      leave
    end
  end
  if \authorised then return .WireUIResult~failure("DEFINITION_NOT_AUTHORISED_FOR_ACTIVE_PLAN",definitionKey)
  r=view~createInstancePatch(instanceId,definitionKey,slots,parentId)
  if \r~ok then return r
  self~appendOutbound(r~value)
  return r

::method registerDefinition
  expose definitions
  use arg definition
  key = definition~definitionKey
  if definitions~hasIndex(key) then do
    prior = definitions[key]
    if prior~contentAddress \= definition~contentAddress then return .WireUIResult~failure("DEFINITION_IMMUTABLE", key)
    return .WireUIResult~success(prior, "ALREADY_REGISTERED")
  end
  definitions[key] = definition
  return .WireUIResult~success(definition)

::method definition
  expose definitions
  use arg definitionKey
  if definitions~hasIndex(definitionKey) then return definitions[definitionKey]
  return .nil

::method addSubscription
  expose subscriptions
  use arg subscription
  subscriptions[subscription~subscriptionId] = subscription
  return self

::method subscription
  expose subscriptions
  use arg subscriptionId
  if subscriptions~hasIndex(subscriptionId) then return subscriptions[subscriptionId]
  return .nil

::method activateSubscription
  expose subscriptions
  use arg subscriptionId
  if \subscriptions~hasIndex(subscriptionId) then return .WireUIResult~failure("SUBSCRIPTION_NOT_FOUND", subscriptionId)
  sub=subscriptions[subscriptionId]
  wasActive=sub~active
  sub~activate
  if \wasActive & sub~observationIds~items>0 then do
    or=self~emitObservationPlan(subscriptionId)
    if \or~ok then do; sub~deactivate; return or; end
  end
  return .WireUIResult~success(sub)

::method deactivateSubscription
  expose subscriptions
  use arg subscriptionId
  if \subscriptions~hasIndex(subscriptionId) then return .WireUIResult~failure("SUBSCRIPTION_NOT_FOUND", subscriptionId)
  subscriptions[subscriptionId]~deactivate
  return .WireUIResult~success(subscriptions[subscriptionId])

::method subscriptionIds
  expose subscriptions
  return subscriptions~allIndexes

::method activeSubscriptions
  expose subscriptions
  resultSet = .array~new
  do sid over subscriptions
    if subscriptions[sid]~active then resultSet~append(subscriptions[sid])
  end
  return resultSet

::method requiredDefinitions
  expose subscriptions definitions
  use arg cachedManifest = .nil
  if cachedManifest == .nil then cachedManifest = .table~new
  required = .array~new
  emitted = .set~new
  do sid over subscriptions
    sub = subscriptions[sid]
    if sub~active then do key over sub~definitionKeys
      if \emitted~hasIndex(key) & definitions~hasIndex(key) then do
        def = definitions[key]
        cached = ""
        if cachedManifest~hasIndex(key) then cached = cachedManifest[key]
        if cached \= def~contentAddress then do
          required~append(def~asWire)
          emitted~put(key)
        end
      end
    end
  end
  return required

::method journeyPlanMessage
  expose journey planner siteReleaseBinding experimentAssignments
  if journey==.nil | planner==.nil then return .WireUIResult~failure("JOURNEY_NOT_ATTACHED")
  message=planner~asWire(self,journey)
  if siteReleaseBinding\==.nil then message["siteRelease"]=siteReleaseBinding~asWire
  if experimentAssignments~items>0 then message["experimentAssignments"]=self~experimentAssignmentsWire
  return .WireUIResult~success(message)

::method emitJourneyPlan
  expose outbound renderProfileId
  if renderProfileId<>"" then do
    mr=self~refreshDefinitionManifest(.true)
    if \mr~ok then return mr
  end
  r=self~journeyPlanMessage
  if \r~ok then return r
  outbound~append(r~value)
  return r

::method state
  expose businessState
  use arg key
  if businessState~hasIndex(key) then return businessState[key]
  return .nil

::method mutateState
  expose businessState projection view outbound
  use arg key, value
  guard on
  businessState[key] = value
  patches = projection~projectChange(view, key, value)
  do patch over patches
    outbound~append(patch)
  end
  guard off
  return .WireUIResult~success(patches)



/* Atomically change several authoritative state keys and then recompute any
   cross-object derived UI projection against the complete new state snapshot.
   The derived renderer-visible consequences are emitted as one view revision. */
::method mutateStateGroup
  expose businessState projection view outbound
  use arg updates
  if updates==.nil | \updates~hasMethod("HASINDEX") then return .WireUIResult~failure("STATE_GROUP_INVALID")
  guard on
  changed=.array~new
  keys=updates~allIndexes
  keys~sort
  do key over keys
    newValue=updates[key]
    oldValue=.nil
    if businessState~hasIndex(key) then oldValue=businessState[key]
    if oldValue==newValue then iterate
    businessState[key]=newValue
    changed~append(key)
  end
  if changed~items=0 then do
    guard off
    return .WireUIResult~success(.nil,"NO_CHANGE")
  end
  snapshot=.table~new
  do key over businessState~allIndexes; snapshot[key]=businessState[key]; end
  r=projection~projectDerivedGroup(view,snapshot,changed)
  if \r~ok then do
    guard off
    return r
  end
  if r~value \== .nil then outbound~append(r~value)
  guard off
  return .WireUIResult~success(r~value,"STATE_GROUP_MUTATED")

/* Publish one authoritative large-collection window as a single revision. */
::method reconcileCollectionWindow
  expose view outbound
  use arg parentId, rows, window
  guard on
  r=view~reconcileCollectionWindow(parentId,rows,window)
  if r~ok & r~value\==.nil then outbound~append(r~value)
  guard off
  return r

/* Append factual operational evidence to a semantic evidence stream. */
::method appendEvidence
  expose view outbound
  use arg parentId, entry, instanceId="", definitionKey="EVIDENCE_EVENT@1"
  guard on
  r=view~appendEvidence(parentId,entry,instanceId,definitionKey)
  if r~ok & r~value\==.nil then outbound~append(r~value)
  guard off
  return r

::method offerInteractionProfile
  expose view outbound profileOffers offerSequence applicationId siteReleaseBinding
  use arg elementInstance, profile = .nil, purpose="AUTHORISED_MACHINE_INTERACTION", expiresAt=.nil
  if profile == .nil then profile = .WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED
  instance=view~instance(elementInstance)
  if instance == .nil then return .WireUIResult~failure("INSTANCE_NOT_FOUND", elementInstance)
  if self~field(instance["slots"], "action", "") \= .WireUIProtocol~INTERACTION_PROFILE_SELECT then return .WireUIResult~failure("PROFILE_OFFER_ACTION_MISMATCH", elementInstance)
  instance["slots"]["profile"] = profile
  view~setActionAvailable(elementInstance, .WireUIProtocol~INTERACTION_PROFILE_SELECT, .true)
  patch=view~setVisible(elementInstance, .true)
  if patch~ok & patch~value \== .nil then outbound~append(patch~value)
  offerSequence += 1
  offerId=applicationId":PROFILE-OFFER:"offerSequence
  offer=.table~new
  offer["offerId"]=offerId
  offer["profiles"]=.array~of(.WireUIProtocol~PROFILE_HUMAN_VISUAL,profile)
  offer["elementInstance"]=elementInstance
  offer["viewRef"]=view~viewRef
  offer["revision"]=view~revision
  offer["purpose"]=purpose
  offer["expiresAt"]=expiresAt
  if siteReleaseBinding\==.nil then offer["siteRelease"]=siteReleaseBinding~asWire
  profileOffers[offerId]=offer
  outbound~append(.WireUIProtocol~message(.WireUIProtocol~INTERACTION_PROFILE_OFFER,offer))
  return .WireUIResult~success(offer)

::method selectInteractionProfile private unguarded
  expose interactionProfile profileOffers siteCatalogue journey
  use arg message
  detail=self~field(message,"detail",.nil)
  profile=self~field(message, "profile", "")
  offerId=""
  if detail \== .nil then do
    if profile="" then profile=self~field(detail,"profileId","")
    offerId=self~field(detail,"offerId","")
  end
  if profile \= .WireUIProtocol~PROFILE_HUMAN_VISUAL & profile \= .WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED then return .WireUIResult~failure("INTERACTION_PROFILE_UNSUPPORTED", profile)
  if offerId \= "" then do
    if \profileOffers~hasIndex(offerId) then return .WireUIResult~failure("INTERACTION_PROFILE_OFFER_UNKNOWN",offerId)
    offer=profileOffers[offerId]
    offered=.false
    do p over offer["profiles"]; if p=profile then offered=.true; end
    if \offered then return .WireUIResult~failure("INTERACTION_PROFILE_NOT_OFFERED",profile)
    if offer["viewRef"] \= self~field(message,"viewRef","") then return .WireUIResult~failure("INTERACTION_PROFILE_OFFER_VIEW_MISMATCH",offerId)
  end
  previous=interactionProfile
  previousState=""
  if journey\==.nil then previousState=journey~currentState
  interactionProfile=profile
  if siteCatalogue\==.nil then do
    cr=siteCatalogue~activateProfile(self,profile,previousState)
    if \cr~ok then do; interactionProfile=previous; return cr; end
  end
  r=self~onInteractionProfileChanged(previous, profile, message)
  if r~isA(.WireUIResult) then do
    if \r~ok then interactionProfile=previous
    return r
  end
  return .WireUIResult~success(profile, "INTERACTION_PROFILE_SELECTED")

::method onInteractionProfileChanged
  use arg previousProfile, newProfile, message
  return .WireUIResult~success(newProfile, "INTERACTION_PROFILE_SELECTED")

::method drainOutbound
  expose outbound
  guard on
  result = outbound
  outbound = .array~new
  guard off
  return result

::method receive
  expose processedMessages view securityPolicy journey planner
  use arg message
  guard on
  msgId = self~field(message, "messageId", "")
  if msgId \= "" & processedMessages~hasIndex(msgId) then do
    prior = processedMessages[msgId]
    guard off
    return .WireUIResult~success(prior, "DUPLICATE")
  end
  type = self~field(message, "type", "")
  select
    when type = .WireUIProtocol~UI_HELLO then response = self~handleHello(message)
    when type = .WireUIProtocol~UI_DEFINITION_REQUIRED then response = self~handleDefinitionRequired(message)
    when type = .WireUIProtocol~UI_ACTION then response = self~handleAction(message, securityPolicy)
    when type = .WireUIProtocol~UI_RESYNC_REQUEST then response = .WireUIResult~success(self~snapshot, "RESYNC_SNAPSHOT")
    when type = .WireUIProtocol~UI_ON_DEMAND_REQUEST then response = self~handleOnDemand(message,journey,planner)
    when type = .WireUIProtocol~SUBSCRIPTION_ACTIVATE then response = self~handleSubscriptionControl(message,.true,journey,planner)
    when type = .WireUIProtocol~SUBSCRIPTION_DEACTIVATE then response = self~handleSubscriptionControl(message,.false,journey,planner)
    when type = .WireUIProtocol~INTERACTION_OBSERVATION then response = self~handleInteractionObservation(message)
    otherwise response = .WireUIResult~failure("UNSUPPORTED_MESSAGE", type)
  end
  if msgId \= "" then processedMessages[msgId] = response
  guard off
  return response

::method handleHello private unguarded
  expose applicationId sessionId accessPointId renderProfilePolicy renderProfileId capabilityFingerprint definitionManifest outbound journey planner
  use arg message
  supplied=self~field(message,"applicationId","")
  if supplied<>"" & supplied<>applicationId then return .WireUIResult~failure("APPLICATION_OWNERSHIP_MISMATCH")
  supplied=self~field(message,"sessionId","")
  if supplied<>"" & supplied<>sessionId then return .WireUIResult~failure("SESSION_OWNERSHIP_MISMATCH")
  supplied=self~field(message,"accessPointId","")
  if supplied<>"" & supplied<>accessPointId then return .WireUIResult~failure("ACCESS_POINT_OWNERSHIP_MISMATCH")

  capabilities=self~field(message,"renderCapabilities",.nil)
  capabilityFingerprint=self~field(message,"capabilityFingerprint","")
  renderProfileId=renderProfilePolicy~resolve(capabilities,capabilityFingerprint)
  rr=self~refreshDefinitionManifest(.false)
  if \rr~ok then return rr
  rp=self~renderProfileMessage
  if \rp~ok then return rp
  outbound~append(rp~value)

  if journey\==.nil & planner\==.nil then do
    jp=self~journeyPlanMessage
    if jp~ok then outbound~append(jp~value)
  end

  do sub over self~activeSubscriptions
    if sub~observationIds~items>0 then do
      op=self~observationPlanMessage(sub~subscriptionId)
      if \op~ok then return op
      outbound~append(op~value)
    end
  end

  outbound~append(self~snapshot)
  return .WireUIResult~success(renderProfileId,"UI_HELLO_ACCEPTED")

::method handleDefinitionRequired private unguarded
  expose definitionManifest definitions outbound sentDefinitionDeliveries renderProfileId
  use arg message
  if definitionManifest==.nil | renderProfileId="" then return .WireUIResult~failure("DEFINITION_MANIFEST_NOT_READY")
  suppliedManifest=self~field(message,"manifestId","")
  if suppliedManifest<>"" & suppliedManifest<>definitionManifest~manifestId then return .WireUIResult~failure("DEFINITION_MANIFEST_MISMATCH",suppliedManifest)
  suppliedProfile=self~field(message,"profileId","")
  if suppliedProfile<>"" & suppliedProfile<>renderProfileId then return .WireUIResult~failure("RENDER_PROFILE_MISMATCH",suppliedProfile)

  requested=self~field(message,"definitions",.nil)
  if requested==.nil | \requested~isA(.Array) then return .WireUIResult~failure("DEFINITION_REQUEST_REQUIRED")
  delivered=.array~new
  do ref over requested
    if ref==.nil | \ref~hasMethod("HASINDEX") then return .WireUIResult~failure("DEFINITION_REQUEST_INVALID")
    id=self~field(ref,"id",self~field(ref,"definitionId",""))
    version=self~field(ref,"version",self~field(ref,"definitionVersion",""))
    address=self~field(ref,"contentAddress","")
    if id="" | version="" then return .WireUIResult~failure("DEFINITION_REQUEST_INVALID")
    if \definitionManifest~contains(id,version,address) then return .WireUIResult~failure("DEFINITION_NOT_AUTHORISED_BY_MANIFEST",id"@"version)
    key=id"@"version
    if \definitions~hasIndex(key) then return .WireUIResult~failure("DEFINITION_NOT_FOUND",key)
    deliveryKey=definitionManifest~manifestId"|"key
    if sentDefinitionDeliveries~hasIndex(deliveryKey) then iterate
    def=definitions[key]~asWire
    def["profileId"]=renderProfileId
    outbound~append(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION,def))
    sentDefinitionDeliveries~put(deliveryKey)
    delivered~append(key)
  end
  if delivered~items=0 then return .WireUIResult~success(delivered,"DEFINITION_ALREADY_QUEUED")
  return .WireUIResult~success(delivered,"DEFINITION_DELIVERY_QUEUED")

::method handleInteractionObservation private unguarded
  expose observationDefinitions acceptedObservations applicationId view siteReleaseBinding
  use arg message
  subscriptionId=self~field(message,"subscription","")
  if subscriptionId="" then return .WireUIResult~failure("OBSERVATION_SUBSCRIPTION_REQUIRED")
  sub=self~subscription(subscriptionId)
  if sub==.nil then return .WireUIResult~failure("OBSERVATION_SUBSCRIPTION_NOT_FOUND",subscriptionId)
  if \sub~active then return .WireUIResult~failure("OBSERVATION_SUBSCRIPTION_NOT_ACTIVE",subscriptionId)
  suppliedRevision=self~field(message,"subscriptionRevision",.nil)
  if suppliedRevision==.nil | suppliedRevision<>sub~version then return .WireUIResult~failure("OBSERVATION_SUBSCRIPTION_REVISION_MISMATCH",suppliedRevision)
  pointId=self~field(message,"point","")
  if pointId="" then return .WireUIResult~failure("OBSERVATION_POINT_REQUIRED")
  matched=.nil
  do key over sub~observationIds
    if observationDefinitions~hasIndex(key) then do
      candidate=observationDefinitions[key]
      if candidate~observationId=pointId then do
        if matched\==.nil then return .WireUIResult~failure("OBSERVATION_POINT_AMBIGUOUS",pointId)
        matched=candidate
      end
    end
  end
  if matched==.nil then return .WireUIResult~failure("OBSERVATION_POINT_NOT_AUTHORISED",pointId)
  suppliedPurpose=self~field(message,"purpose","")
  if suppliedPurpose<>matched~purpose then return .WireUIResult~failure("OBSERVATION_PURPOSE_MISMATCH",suppliedPurpose)
  suppliedStrength=self~field(message,"evidenceStrength","")
  if suppliedStrength<>matched~evidenceStrength then return .WireUIResult~failure("OBSERVATION_EVIDENCE_STRENGTH_MISMATCH",suppliedStrength)
  observation=self~field(message,"observation",.nil)
  if observation==.nil | \observation~hasMethod("HASINDEX") then return .WireUIResult~failure("OBSERVATION_PAYLOAD_REQUIRED")
  canonical=.table~new
  do field over observation~allIndexes
    if \matched~allowsField(field) then return .WireUIResult~failure("OBSERVATION_FIELD_NOT_AUTHORISED",field)
    canonical[field]=observation[field]
  end
  if siteReleaseBinding\==.nil then do
    suppliedRelease=self~field(message,"siteReleaseContentAddress","")
    if suppliedRelease<>"" & suppliedRelease<>siteReleaseBinding~contentAddress then return .WireUIResult~failure("SITE_RELEASE_MISMATCH",suppliedRelease)
    releaseAddress=siteReleaseBinding~contentAddress
  end
  else releaseAddress=""
  record=.WireUIObservationRecord~new(applicationId,subscriptionId,sub~version,pointId,matched~purpose,matched~evidenceStrength,canonical,self~field(message,"viewRef",view~viewRef),self~field(message,"renderedRevision",.nil),self~field(message,"messageId",""),releaseAddress)
  acceptedObservations~append(record)
  timingDetail=.table~new; timingDetail["point"]=pointId; timingDetail["subscription"]=subscriptionId
  ignoreTiming=self~recordJourneyTiming("CLIENT_OBSERVATION_ACCEPTED",self~field(message,"messageId",""),timingDetail)
  return .WireUIResult~success(record,"INTERACTION_OBSERVATION_ACCEPTED")

::method handleOnDemand private unguarded
  expose applicationId
  use arg message,journey,planner
  if journey==.nil | planner==.nil then return .WireUIResult~failure("JOURNEY_NOT_ATTACHED")
  planId=self~field(message,"planId","")
  expected=applicationId":"journey~currentState":"journey~planRevision
  if planId \= expected then return .WireUIResult~failure("JOURNEY_PLAN_MISMATCH",planId)
  if self~field(message,"planRevision",-1) \= journey~planRevision then return .WireUIResult~failure("JOURNEY_PLAN_REVISION_MISMATCH",self~field(message,"planRevision",-1))
  capability=self~field(message,"capability","")
  subscriptionId=self~field(message,"subscription","")
  r=planner~requestOnDemand(self,journey,capability,subscriptionId)
  if \r~ok then return r
  ignore=self~emitJourneyPlan
  return .WireUIResult~success(subscriptionId,"ON_DEMAND_ACTIVATED")

::method handleSubscriptionControl private unguarded
  use arg message,wantActive,journey,planner
  if journey==.nil | planner==.nil then return .WireUIResult~failure("JOURNEY_NOT_ATTACHED")
  name=self~field(message,"name","")
  p=planner~plan(journey)
  allowed=.false
  do tier over .array~of("ACTIVE","PREFETCH","REQUESTED_ON_DEMAND")
    do entry over p[tier]
      sid=entry
      if \entry~isA(.string) & entry~hasMethod("HASINDEX") then do
        if entry~hasIndex("subscription") then sid=entry["subscription"]
        else if entry~hasIndex("name") then sid=entry["name"]
      end
      if sid=name then allowed=.true
    end
  end
  if wantActive then do
    if \allowed then return .WireUIResult~failure("SUBSCRIPTION_NOT_AUTHORISED_BY_PLAN",name)
    return self~activateSubscription(name)
  end
  /* Browser deactivation is accepted only when the server plan no longer requires it. */
  if allowed then return .WireUIResult~failure("SUBSCRIPTION_STILL_REQUIRED",name)
  return self~deactivateSubscription(name)

::method handleAction private unguarded
  expose view applicationId sessionId accessPointId siteReleaseBinding
  use arg message, securityPolicy
  if self~field(message, "applicationId", "") \= applicationId then return .WireUIResult~failure("APPLICATION_OWNERSHIP_MISMATCH")
  if self~field(message, "sessionId", "") \= sessionId then return .WireUIResult~failure("SESSION_OWNERSHIP_MISMATCH")
  if self~field(message, "accessPointId", "") \= accessPointId then return .WireUIResult~failure("ACCESS_POINT_OWNERSHIP_MISMATCH")
  if self~field(message, "viewRef", "") \= view~viewRef then return .WireUIResult~failure("VIEW_MISMATCH")
  if siteReleaseBinding\==.nil then do
    supplied=self~field(message,"siteReleaseContentAddress","")
    if supplied\="" & supplied\=siteReleaseBinding~contentAddress then return .WireUIResult~failure("SITE_RELEASE_MISMATCH",supplied)
  end
  instanceId = self~field(message, "elementInstance", "")
  instance = view~instance(instanceId)
  if instance == .nil then return .WireUIResult~failure("INSTANCE_NOT_FOUND", instanceId)
  action = self~field(message, "action", "")
  renderedRevision = self~field(message, "renderedRevision", -1)
  defAction = self~field(instance["slots"], "action", "")
  actionBound = defAction = action
  boundActions = self~field(instance["slots"], "actions", .nil)
  if \actionBound & boundActions \== .nil then do boundAction over boundActions
    if boundAction = action then do
      actionBound = .true
      leave
    end
  end
  if \actionBound then return .WireUIResult~failure("ACTION_NOT_BOUND_TO_ELEMENT", action)
  if \view~actionWasAvailableAt(instanceId, action, renderedRevision) then return .WireUIResult~failure("ACTION_NOT_AVAILABLE_AT_REVISION", renderedRevision)
  if renderedRevision \= view~revision then return .WireUIResult~failure("STALE_UI_ACTION", renderedRevision, view~revision)
  if securityPolicy \== .nil then do
    allowed = securityPolicy~allows(self, message)
    if \allowed then return .WireUIResult~failure("ACTION_GUARD_REJECTED", action)
  end
  workspaceRef=self~field(instance["slots"],"workspaceRef","")
  if workspaceRef<>"" then do
    detail=self~field(message,"detail",.nil)
    suppliedContext=.nil
    if detail\==.nil & detail~hasMethod("HASINDEX") then suppliedContext=self~field(detail,"workspaceContext",.nil)
    wr=self~validateWorkspaceContext(workspaceRef,suppliedContext)
    if \wr~ok then return wr
  end
  correlationId=self~field(message,"messageId","")
  timingDetail=.table~new; timingDetail["action"]=action; timingDetail["elementInstance"]=instanceId; timingDetail["renderedRevision"]=renderedRevision
  validatedTiming=self~recordJourneyTiming("SEMANTIC_ACTION_VALIDATED",correlationId,timingDetail)
  if \validatedTiming~ok then return validatedTiming
  if action = .WireUIProtocol~INTERACTION_PROFILE_SELECT then response=self~selectInteractionProfile(message)
  else response=self~dispatchSemanticAction(action, message)
  if response~ok then do
    completedTiming=self~recordJourneyTiming("SEMANTIC_ACTION_COMPLETED",correlationId,timingDetail)
    if \completedTiming~ok then return completedTiming
  end
  return response

::method dispatchSemanticAction
  use arg action, message
  return .WireUIResult~failure("ACTION_NOT_IMPLEMENTED", action)

::method field private unguarded
  use arg table, key, default = .nil
  if table==.nil then return default
  if table~hasIndex(key) then return table[key]
  return default
::requires "WireUICompiledCatalogue.cls"
::requires "WireUIObservationDefinition.cls"
::requires "WireUIObservationRecord.cls"
::requires "WireUIAlchemy.cls"

::requires "WireUIRenderProfilePolicy.cls"

::requires "WireUIDefinitionManifest.cls"

::requires "WireUITimingClock.cls"
::requires "WireUIJourneyTimingRecord.cls"

::requires "WireUIWorkspaceQueryState.cls"
::requires "WireUIWorkspaceSelection.cls"
::requires "WireUIWorkspaceCommandContext.cls"
