/* Generalized Compute Intentions v0.1-dev6
 * Separate convenience layer. It plans admissible routes and bridges those
 * object-rich plans into Intention Service without owning compute, allocation,
 * WLU, router, model, quota, lease, or execution state.
 */

::class GeneralizedComputeIntentionRelationship public
::method init
  expose subject predicate object authority
  use strict arg subject, predicate, object, authority=''
::attribute subject get
::attribute predicate get
::attribute object get
::attribute authority get

::class PlannedAdmittanceRoute public
::method init
  use arg workload, context=.nil
  self~workload = workload
  self~context = context
  self~candidates = .array~new
  self~state = 'PLANNED'
  self~reason = ''
  self~discoveryEvidence = .nil

::attribute workload
::attribute context
::attribute candidates
::attribute state
::attribute reason
::attribute discoveryEvidence

::method addCandidate
  use arg candidate
  self~candidates~append(candidate)
  return candidate

::method admissibleCandidates
  out = .array~new
  do c over self~candidates
    if c~isAdmissible then out~append(c)
  end
  return out

::method preferredCandidate
  admissible = self~admissibleCandidates
  if admissible~items = 0 then return .nil
  best = admissible[1]
  do i = 2 to admissible~items
    c = admissible[i]
    if c~preferenceRank < best~preferenceRank then best = c
  end
  return best

::method handoff
  preferred = self~preferredCandidate
  if preferred == .nil then return .nil
  return .PlannedAdmittanceHandoff~new(self, preferred)

::class PlannedAdmittanceHandoff public
::method init
  expose route candidate workload resource revalidationRequired revalidationAuthorities
  use arg route, candidate
  if route == .nil then raise syntax 93.900 array('Planned route is required')
  if candidate == .nil then raise syntax 93.900 array('Admittance candidate is required')
  if route~state \= 'READY' then raise syntax 93.900 array('Only READY planned routes can be handed off')
  if \candidate~isAdmissible then raise syntax 93.900 array('Only admissible candidates can be handed off')
  workload = route~workload
  resource = candidate~resource
  /* A plan is not an entitlement.  The authoritative admission path MUST
   * revalidate the current compute, allocation, WLU and router state before
   * it mutates anything.  This is explicit on the handoff so callers cannot
   * mistake a READY plan for a durable reservation or placement lease. */
  revalidationRequired = .true
  revalidationAuthorities = .array~of('COMPUTE', 'ALLOCATION', 'WLU', 'ROUTER')

::attribute route get
::attribute candidate get
::attribute workload get
::attribute resource get
::attribute revalidationRequired get
::attribute revalidationAuthorities get

::class AdmittanceCandidate public
::method init
  use arg resource, preferenceRank=1000
  self~resource = resource
  self~preferenceRank = preferenceRank
  self~computeAssessment = .nil
  self~allocationAssessment = .nil
  self~wluAssessment = .nil
  self~routerAssessment = .nil
  self~observationAssessment = .nil
  self~evidence = .array~new

::attribute resource
::attribute preferenceRank
::attribute computeAssessment
::attribute allocationAssessment
::attribute wluAssessment
::attribute routerAssessment
::attribute observationAssessment
::attribute evidence

::method addEvidence
  use arg item
  self~evidence~append(item)
  return item

::method isAdmissible
  if \self~assessmentAllows(self~computeAssessment) then return .false
  if \self~assessmentAllows(self~allocationAssessment) then return .false
  if \self~assessmentAllows(self~wluAssessment) then return .false
  if \self~assessmentAllows(self~routerAssessment) then return .false
  return .true

::method assessmentAllows private
  use arg assessment
  if assessment == .nil then return .true
  if assessment~hasMethod('allows') then return assessment~allows
  return .false

::class IntentionAssessment public
::method init
  use arg allows, authority, reason='', evidence=.nil
  self~allows = allows
  self~authority = authority
  self~reason = reason
  self~evidence = evidence

::attribute allows
::attribute authority
::attribute reason
::attribute evidence

/* Adapter contracts are deliberately tiny. Production bindings adapt the
 * actual compute/router/WLU/allocation packages without changing them.
 */
::class ComputeIntentionAdapter public
::method discoverCandidates abstract
::method assess abstract

::class AllocationIntentionAdapter public
::method assess abstract

::class WLUIntentionsAdapter public
::method assess abstract

::class RouterIntentionAdapter public
::method assess abstract

::class GeneralizedComputeIntentionProvider public
::method init
  use arg computeAdapter, allocationAdapter, wluAdapter, routerAdapter, observationAdapter=.nil
  if computeAdapter == .nil then raise syntax 93.900 array('Compute adapter is required')
  if allocationAdapter == .nil then raise syntax 93.900 array('Allocation adapter is required')
  if wluAdapter == .nil then raise syntax 93.900 array('WLU adapter is required')
  if routerAdapter == .nil then raise syntax 93.900 array('Router adapter is required')
  self~computeAdapter = computeAdapter
  self~allocationAdapter = allocationAdapter
  self~wluAdapter = wluAdapter
  self~routerAdapter = routerAdapter
  self~observationAdapter = observationAdapter

::attribute computeAdapter
::attribute allocationAdapter
::attribute wluAdapter
::attribute routerAdapter
::attribute observationAdapter

::method providerId
  return 'generalized.compute.intentions/0.1'

::method discover
  use arg context=.nil
  surface = .directory~new
  surface['provider'] = self~providerId
  surface['operations'] = .array~of('PLAN_ADMITTANCE', 'EXPLAIN_ADMITTANCE', 'PREFERRED_ROUTE', 'PREPARE_ADMISSION')
  surface['relationships'] = self~relationships
  surface['mutating'] = .false
  surface['context'] = context
  return surface

::method operationDescriptor
  use arg operation, workload, context=.nil
  op = translate(strip(operation))
  descriptor = .directory~new
  descriptor['operation'] = op
  descriptor['mutating'] = .false
  descriptor['available'] = .true
  descriptor['state'] = 'AVAILABLE'
  descriptor['reason'] = 'PLANNING_OPERATION'
  if workload == .nil then return descriptor
  route = self~planAdmittance(workload, context)
  descriptor['state'] = route~state
  descriptor['reason'] = route~reason
  if op = 'PREFERRED_ROUTE' | op = 'PREPARE_ADMISSION' then -
      descriptor['available'] = route~state = 'READY'
  return descriptor

::method discoverFor
  use arg workload, context=.nil
  surface = self~discover(context)
  descriptors = .array~new
  do op over surface['operations']
    descriptors~append(self~operationDescriptor(op, workload, context))
  end
  surface['operation_descriptors'] = descriptors
  return surface

::method relationships
  relationships = .array~new
  relationships~append(.GeneralizedComputeIntentionRelationship~new('WORKLOAD', 'requires', 'COMPUTE_REQUIREMENTS', 'semantic'))
  relationships~append(.GeneralizedComputeIntentionRelationship~new('COMPUTE_REQUIREMENTS', 'satisfied_by', 'COMPUTE_RESOURCE', 'compute authority'))
  relationships~append(.GeneralizedComputeIntentionRelationship~new('WORKLOAD', 'admitted_by', 'WLU', 'WLU authority'))
  relationships~append(.GeneralizedComputeIntentionRelationship~new('WORKLOAD', 'placed_by', 'ALLOCATION', 'allocator authority'))
  relationships~append(.GeneralizedComputeIntentionRelationship~new('WORKLOAD', 'routed_by', 'ROUTER', 'router authority'))
  relationships~append(.GeneralizedComputeIntentionRelationship~new('COMPUTE_RESOURCE', 'observed_by', 'INSTRUMENTATION_MESH', 'observation only'))
  return relationships

/* PLAN only. This method MUST NOT reserve WLU, create an allocation, acquire
 * a lease, dispatch a job, invoke an LLM, or entitle a caller to a route.
 * Each authority contributes an advisory assessment; original objects survive.
 */
::method planAdmittance
  use arg workload, context=.nil
  route = .PlannedAdmittanceRoute~new(workload, context)
  discovered = self~computeAdapter~discoverCandidates(workload, context)
  if discovered == .nil then discovered = .array~new

  if self~computeAdapter~hasMethod('discoveryEvidence') then -
      route~discoveryEvidence = self~computeAdapter~discoveryEvidence(workload, context)

  /* Some router authorities make one decision over the complete candidate set
   * (AI Model Router is the first concrete example).  Give such adapters a
   * per-plan state object instead of forcing them to rerun or cache a global
   * decision for every candidate.  The state is evidence only and is scoped to
   * this planning call. */
  routerPlanState = .nil
  if self~routerAdapter~hasMethod('beginPlan') then -
      routerPlanState = self~routerAdapter~beginPlan(workload, discovered, context)

  rank = 0
  do resource over discovered
    rank += 1
    candidate = .AdmittanceCandidate~new(resource, rank)

    candidate~computeAssessment = self~computeAdapter~assess(workload, resource, context)
    candidate~allocationAssessment = self~allocationAdapter~assess(workload, resource, context)
    candidate~wluAssessment = self~wluAdapter~assess(workload, resource, context)
    if self~routerAdapter~hasMethod('assessForPlan') then -
        candidate~routerAssessment = self~routerAdapter~assessForPlan(workload, resource, context, routerPlanState)
    else candidate~routerAssessment = self~routerAdapter~assess(workload, resource, context)

    /* Instrumentation is advisory evidence only. It may alter preference order,
     * but it cannot make an otherwise inadmissible route admissible and cannot
     * grant mutation authority. Authoritative eligibility remains compute,
     * allocation, WLU and router-owned. */
    if self~observationAdapter \== .nil then do
      candidate~observationAssessment = self~observationAdapter~observe(workload, resource, context)
      observation = candidate~observationAssessment
      if observation \== .nil then do
        if observation~hasMethod('preferencePenalty') then candidate~preferenceRank += observation~preferencePenalty
      end
    end

    self~collectEvidence(candidate, candidate~computeAssessment)
    self~collectEvidence(candidate, candidate~allocationAssessment)
    self~collectEvidence(candidate, candidate~wluAssessment)
    self~collectEvidence(candidate, candidate~routerAssessment)
    self~collectEvidence(candidate, candidate~observationAssessment)
    route~addCandidate(candidate)
  end

  if route~candidates~items = 0 then do
    route~state = 'INFEASIBLE'
    route~reason = 'NO_CANDIDATES'
  end
  else if route~admissibleCandidates~items = 0 then do
    route~state = 'INFEASIBLE'
    route~reason = 'NO_ADMISSIBLE_ROUTE'
  end
  else do
    route~state = 'READY'
    route~reason = 'PLANNED_ADMISSIBLE_ROUTE'
  end
  return route

::method explainAdmittance
  use arg route
  out = .array~new
  do c over route~candidates
    row = .directory~new
    row['resource'] = c~resource
    row['admissible'] = c~isAdmissible
    row['compute'] = c~computeAssessment
    row['allocation'] = c~allocationAssessment
    row['wlu'] = c~wluAssessment
    row['router'] = c~routerAssessment
    row['observation'] = c~observationAssessment
    row['evidence'] = c~evidence
    out~append(row)
  end
  return out

::method preferredRoute
  use arg workload, context=.nil
  return self~planAdmittance(workload, context)~preferredCandidate

/* PREPARE_ADMISSION is still non-mutating. It creates a handoff object for the
 * authoritative router/admission path. The consumer must revalidate/admit it.
 */
::method prepareAdmission
  use arg workload, context=.nil
  route = self~planAdmittance(workload, context)
  return route~handoff

::method collectEvidence private
  use arg candidate, assessment
  if assessment == .nil then return
  if assessment~hasMethod('evidence') then do
    e = assessment~evidence
    if e \== .nil then candidate~addEvidence(e)
  end

/* Structured bridge to Intention Service.
 * It mirrors the Workbench pattern: the rich request is staged, Intention
 * Service sees an opaque token, and the proposal carries the same request
 * object as a slot. There is no serialize/reconstruct boundary.
 */
::class GeneralizedComputeStructuredIntentionProvider public
::method init
  expose planner staged nextId proposalFactory
  use arg planner, proposalFactory=.nil
  if planner == .nil then raise syntax 93.900 array('Generalized compute intention planner is required')
  staged = .directory~new
  nextId = 0

::attribute planner get

::method name
  return 'GENERALIZED_COMPUTE_STRUCTURED'

::method stage
  expose staged nextId
  use arg operation, workload, context=.nil
  op = translate(strip(operation))
  if \self~isOperation(op) then raise syntax 93.900 array('Unknown generalized compute intention operation:' op)
  nextId += 1
  id = 'GCI' || nextId
  request = .GeneralizedComputeIntentionRequest~new(id, op, workload, context)
  staged[id] = request
  return 'COMPUTE_INTENTION ' || id

::method stagedRequest
  expose staged
  use arg id
  key = translate(strip(id))
  if staged~hasIndex(key) = 0 then return .nil
  return staged[key]

::method propose
  expose proposalFactory
  use arg service, text
  parse upper value strip(text) with prefix id extra
  if prefix \= 'COMPUTE_INTENTION' then return .array~new
  if id == '' | extra \= '' then return .array~new
  request = self~stagedRequest(id)
  if request == .nil then return .array~new
  intentionId = self~intentionIdFor(request~operation)
  registration = service~registration(intentionId)
  if registration == .nil then return .array~new
  if proposalFactory == .nil then -
      proposal = .IntentionProposal~new(registration~id, 100, self~name, .true, 'staged object-preserving compute intention')
  else proposal = proposalFactory~newProposal(registration~id, 100, self~name, .true, 'staged object-preserving compute intention')
  proposal~putSlot('REQUEST', request, .true)
  proposal~putSlot('WORKLOAD', request~workload, .true)
  proposal~putSlot('CONTEXT', request~context, .true)
  return .array~of(proposal)

::method executeRequest
  use arg request
  if request == .nil then raise syntax 93.900 array('Generalized compute intention request is required')
  select
    when request~operation = 'PLAN_ADMITTANCE' then return self~planner~planAdmittance(request~workload, request~context)
    when request~operation = 'EXPLAIN_ADMITTANCE' then do
      route = self~planner~planAdmittance(request~workload, request~context)
      return self~planner~explainAdmittance(route)
    end
    when request~operation = 'PREFERRED_ROUTE' then return self~planner~preferredRoute(request~workload, request~context)
    when request~operation = 'PREPARE_ADMISSION' then return self~planner~prepareAdmission(request~workload, request~context)
    otherwise raise syntax 93.900 array('Unsupported generalized compute intention operation:' request~operation)
  end

::method intentionIdFor private
  use arg operation
  return 'COMPUTE_' || operation

::method isOperation private
  use arg operation
  if operation = 'PLAN_ADMITTANCE' then return .true
  if operation = 'EXPLAIN_ADMITTANCE' then return .true
  if operation = 'PREFERRED_ROUTE' then return .true
  if operation = 'PREPARE_ADMISSION' then return .true
  return .false

::class GeneralizedComputeIntentionRequest public
::method init
  expose id operation workload context
  use arg id, operation, workload, context=.nil

::attribute id get
::attribute operation get
::attribute workload get
::attribute context get

/* Event adapter for ordinary IntentionService dispatch. Dispatching this event
 * performs only the selected planning operation. PREPARE_ADMISSION returns a
 * handoff object; it still does not reserve/allocate/dispatch.
 */
::class GeneralizedComputeIntentionEvent public
::method init
  expose structuredProvider
  use arg structuredProvider
  if structuredProvider == .nil then raise syntax 93.900 array('Structured compute intention provider is required')

::method invoke
  expose structuredProvider
  use arg decision
  if decision == .nil then raise syntax 93.900 array('Intention decision is required')
  if decision~hasMethod('status') then do
    if decision~status \== 'READY' then raise syntax 93.900 array('COMPUTE_INTENTION_NOT_READY')
  end
  slots = decision~slots
  if slots == .nil then raise syntax 93.900 array('Intention decision has no slots')
  if slots~hasIndex('REQUEST') = 0 then raise syntax 93.900 array('Intention decision has no REQUEST slot')
  request = slots['REQUEST']
  return structuredProvider~executeRequest(request)
