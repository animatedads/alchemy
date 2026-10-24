/* IntentionService.cls
 * Provider-neutral intention resolution, clarification and dispatch for ooRexx.
 *
 * Recognition and operational permission are deliberately separate.  Providers
 * propose meaning; bucket policy decides whether enough explicit information is
 * present to confirm and dispatch that meaning.
 */

::class IntentionService public

::method init
  expose buckets registrations providers activeDecision defaultBucket logService history currentPath pathLearner spheres fixedFormProvider impliedProvider pathProvider maxClarificationOptions slotResolvers hintLibraries evidenceFacts discoveryProviders discoverySnapshots discoveryEvidenceFacts discoveryGeneration discoverySignature discoverySurfaces planTransformers
  buckets = .Directory~new
  registrations = .Directory~new
  providers = .Array~new
  activeDecision = .nil
  defaultBucket = "DEFAULT"
  logService = .nil
  history = .Array~new
  currentPath = .Array~new
  pathLearner = .IntentionPathLearner~new
  spheres = .Directory~new
  fixedFormProvider = .NLPIntentionProvider~new("FST")
  impliedProvider = .ImpliedIntentionProvider~new
  pathProvider = .PathLearningIntentionProvider~new
  maxClarificationOptions = 7
  slotResolvers = .Directory~new
  hintLibraries = .Array~new
  evidenceFacts = .Array~new
  discoveryProviders = .Array~new
  discoverySnapshots = .Array~new
  discoveryEvidenceFacts = .Array~new
  discoveryGeneration = 0
  discoverySignature = ""
  discoverySurfaces = .Array~new
  planTransformers = .Array~new
  self~registerBucket(defaultBucket, .IntentionBucketPolicy~new("FLEXIBLE", 60, 12, .true, .false))

::method version
  return "0.1-dev11"


::method maxClarificationOptions
  expose maxClarificationOptions
  return maxClarificationOptions

::method setMaxClarificationOptions
  expose maxClarificationOptions
  use arg value
  if \datatype(value, "W") then raise syntax 93.900 array("Clarification option bound must be a whole number")
  if value < 2 then raise syntax 93.900 array("Clarification option bound must be at least 2")
  maxClarificationOptions = value
  return self

::method registerBucket
  expose buckets
  use arg name, policy
  key = translate(strip(name))
  if key == "" then raise syntax 93.900 array("Bucket name must not be empty")
  if policy == .nil then policy = .IntentionBucketPolicy~new
  buckets~put(.IntentionBucket~new(key, policy), key)
  return buckets~at(key)

::method bucket
  expose buckets
  use arg name
  key = translate(strip(name))
  if buckets~hasIndex(key) = 0 then return .nil
  return buckets~at(key)

::method registerProvider
  expose providers
  use arg provider
  if provider == .nil then raise syntax 93.900 array("Provider must not be NIL")
  providers~append(provider)
  return self

/* Select an NLP strategy owned by IntentionService.  META is the default
 * ensemble and individual engines remain available for qualification/A-B use. */
::method useNlp
  use arg engineName = "META"
  self~registerProvider(.NLPIntentionProvider~new(engineName))
  return self

::method availableNlpEngines
  return .IntentionNLPRegistry~available

::method logger
  expose logService
  use arg service
  logService = service
  return self

::method registerPlanTransformer
  expose planTransformers
  use arg transformer
  if transformer == .nil then raise syntax 93.900 array("Plan transformer must not be NIL")
  planTransformers~append(transformer)
  return self

::method planTransformers
  expose planTransformers
  return planTransformers~copy

::method currentPlanContext
  expose history
  if history~items = 0 then return .nil
  entry = history~at(history~items)
  if entry~plan == .nil then return .nil
  return entry

::method transformedProposal
  expose planTransformers history
  use arg text
  if history~items = 0 then return .nil
  prior = history~at(history~items)
  if prior~plan == .nil then return .nil
  do transformerIndex = 1 to planTransformers~items
    transformer = planTransformers~at(transformerIndex)
    transformation = transformer~transform(self, text, prior)
    if transformation == .nil then iterate
    if \transformation~isA(.IntentionPlanTransformation) then raise syntax 93.900 array("Plan transformer must return IntentionPlanTransformation or NIL")
    registration = self~registration(prior~intentionId)
    if registration == .nil then return .nil
    proposal = .IntentionProposal~new(prior~intentionId, transformation~score, "PLAN_TRANSFORMATION", .true, transformation~evidence)
    slots = prior~slots
    supplier = slots~supplier
    do while supplier~available
      slot = supplier~item
      proposal~putSlot(supplier~index, slot~value, slot~explicit)
      supplier~next
    end
    proposal~proposedPlan(prior~plan~copy)
    proposal = transformation~apply(proposal)
    proposal = self~assessProposalPlan(proposal, registration)
    payload = .Directory~new
    payload~put(prior~intentionId, "INTENTION")
    payload~put(transformation~operationCount, "OPERATION_COUNT")
    payload~put(transformation~evidence, "EVIDENCE")
    self~logEvent("INTENTION.PLAN.TRANSFORM", "DEBUG", payload)
    return proposal
  end
  return .nil

/* Discovery providers own observation of their domain.  IntentionService owns
 * freshness: every refresh replaces the previous discovery evidence set rather
 * than accumulating stale operational facts.  A provider implements
 * discover(service) and returns IntentionDiscoverySnapshot. */
::method registerDiscoveryProvider
  expose discoveryProviders
  use arg provider
  if provider == .nil then raise syntax 93.900 array("Discovery provider must not be NIL")
  discoveryProviders~append(provider)
  return self

::method discoveryProviders
  expose discoveryProviders
  return discoveryProviders~copy

::method discoveryGeneration
  expose discoveryGeneration
  return discoveryGeneration

::method discoverySnapshots
  expose discoverySnapshots
  return discoverySnapshots~copy

::method discoverySurfaces
  expose discoverySurfaces
  return discoverySurfaces~copy

::method activeSurfaceProposals
  expose discoverySurfaces
  use arg text
  proposals = .Array~new
  do i = 1 to discoverySurfaces~items
    advertisement = discoverySurfaces~at(i)
    offered = advertisement~propose(self, text)
    if offered == .nil then iterate
    if offered~isA(.Array) then do j = 1 to offered~items; proposals~append(offered~at(j)); end
    else proposals~append(offered)
  end
  return proposals

::method hasDiscoveryProviders
  expose discoveryProviders
  return discoveryProviders~items > 0

::method refreshDiscovery
  expose discoveryProviders discoverySnapshots discoveryEvidenceFacts discoveryGeneration discoverySignature discoverySurfaces
  if discoveryProviders~items = 0 then return discoveryGeneration

  nextSnapshots = .Array~new
  nextFacts = .Array~new
  nextSurfaces = .Array~new
  signature = ""
  do providerIndex = 1 to discoveryProviders~items
    provider = discoveryProviders~at(providerIndex)
    snapshot = provider~discover(self)
    if snapshot == .nil then iterate
    if \snapshot~isA(.IntentionDiscoverySnapshot) then raise syntax 93.900 array("Discovery provider must return IntentionDiscoverySnapshot")
    nextSnapshots~append(snapshot)
    if signature \== "" then signature = signature || "|"
    signature = signature || snapshot~source || "=" || snapshot~revision
    facts = snapshot~evidenceFacts
    do factIndex = 1 to facts~items
      nextFacts~append(facts~at(factIndex))
    end
    surfaces = snapshot~surfaceAdvertisements
    do surfaceIndex = 1 to surfaces~items
      advertisement = surfaces~at(surfaceIndex)~copy
      nextSurfaces~append(advertisement)
    end
  end

  changed = signature \== discoverySignature
  discoverySnapshots = nextSnapshots
  discoveryEvidenceFacts = nextFacts
  discoverySurfaces = nextSurfaces
  if changed then do
    discoveryGeneration = discoveryGeneration + 1
    discoverySignature = signature
  end
  do surfaceIndex = 1 to discoverySurfaces~items
    discoverySurfaces~at(surfaceIndex)~discoveryGeneration(discoveryGeneration)
  end

  payload = .Directory~new
  payload~put(discoveryGeneration, "GENERATION")
  payload~put(discoveryProviders~items, "PROVIDERS")
  payload~put(discoverySnapshots~items, "SNAPSHOTS")
  payload~put(discoveryEvidenceFacts~items, "FACTS")
  payload~put(discoverySurfaces~items, "SURFACES")
  payload~put(changed, "CHANGED")
  payload~put(discoverySignature, "SIGNATURE")
  self~logEvent("INTENTION.DISCOVERY.REFRESH", "DEBUG", payload)
  if changed then self~logEvent("INTENTION.DISCOVERY.CHANGED", "INFO", payload)
  return discoveryGeneration

::method stampDiscoveryGeneration
  expose discoveryGeneration
  use arg proposals
  if proposals == .nil then return proposals
  do proposalIndex = 1 to proposals~items
    proposal = proposals~at(proposalIndex)
    if proposal \== .nil then proposal~discoveryGeneration(discoveryGeneration)
  end
  return proposals

::method cancelActiveDecision
  expose activeDecision
  use arg reason = ""
  if activeDecision \== .nil then do
    payload = .Directory~new
    payload~put(activeDecision~status, "STATUS")
    payload~put(activeDecision~input, "INPUT")
    payload~put(reason, "REASON")
    self~logEvent("INTENTION.ACTIVE.CANCEL", "INFO", payload)
  end
  activeDecision = .nil
  return self

::method inputNew
  use arg text
  self~cancelActiveDecision("NEW_INTENT")
  return self~input(text)

::method isCancelCue
  use arg text
  normalized = translate(strip(text))
  return normalized == "CANCEL" | normalized == "CANCEL THAT" | normalized == "NEVER MIND" | normalized == "NEVERMIND"

::method stripNewIntentCue
  use arg text
  stripped = strip(text)
  upper = translate(stripped)
  prefixes = .Array~of("NEW INTENT ", "NEW REQUEST ", "START OVER ")
  do i = 1 to prefixes~items
    prefix = prefixes~at(i)
    if left(upper, length(prefix)) == prefix then return strip(substr(stripped, length(prefix) + 1))
  end
  return ""

/* Shared evidence ledger.  Domain/application code may publish structured facts
 * here so resolvers, interrogators, plan builders and plan assessors can consume
 * one common evidence shape rather than inventing parallel confidence/source
 * records.  Recording a fact never grants dispatch authority. */
::method addEvidenceFact
  expose evidenceFacts
  use arg fact
  if fact == .nil then raise syntax 93.900 array("Evidence fact must not be NIL")
  if \fact~isA(.IntentionEvidenceFact) then raise syntax 93.900 array("Evidence fact must be an IntentionEvidenceFact")
  evidenceFacts~append(fact)
  payload = .Directory~new
  payload~put(fact~subject, "SUBJECT")
  payload~put(fact~predicate, "PREDICATE")
  payload~put(fact~value, "VALUE")
  payload~put(fact~confidence, "CONFIDENCE")
  payload~put(fact~source, "SOURCE")
  payload~put(fact~authority, "AUTHORITY")
  self~logEvent("INTENTION.EVIDENCE.ADD", "DEBUG", payload)
  return fact

::method evidenceFacts
  expose evidenceFacts discoveryEvidenceFacts
  use arg subject = "", predicate = ""
  subject = translate(strip(subject))
  predicate = translate(strip(predicate))
  out = .Array~new
  sets = .Array~of(evidenceFacts, discoveryEvidenceFacts)
  do setIndex = 1 to sets~items
    facts = sets~at(setIndex)
    do i = 1 to facts~items
      fact = facts~at(i)
      if subject \== "" then do
        if fact~subject \== subject then iterate
      end
      if predicate \== "" then do
        if fact~predicate \== predicate then iterate
      end
      out~append(fact)
    end
  end
  return out

::method evidenceSet
  use arg subject = "", predicate = ""
  return .IntentionEvidenceSet~new(self~evidenceFacts(subject, predicate))

::method bestEvidence
  use arg subject, predicate, expectedValue = ""
  facts = self~evidenceFacts(subject, predicate)
  best = .nil
  do i = 1 to facts~items
    fact = facts~at(i)
    if expectedValue \== "" then do
      if fact~value \== expectedValue then iterate
    end
    if best == .nil then best = fact
    else do
      if fact~authorityRank > best~authorityRank then best = fact
      else do
        if fact~authorityRank == best~authorityRank then do
          if fact~confidence > best~confidence then best = fact
        end
      end
    end
  end
  return best

::method clearEvidenceFacts
  expose evidenceFacts discoveryEvidenceFacts discoverySnapshots discoverySignature discoveryGeneration discoverySurfaces
  evidenceFacts = .Array~new
  discoveryEvidenceFacts = .Array~new
  discoverySnapshots = .Array~new
  discoverySurfaces = .Array~new
  discoverySignature = ""
  discoveryGeneration = 0
  return self

::method logEvent
  expose logService
  use arg point, level = "DEBUG", payload = .nil
  if logService == .nil then return self
  if payload == .nil then payload = .Directory~new
  payload~put("intention.service.event/0.1", "SCHEMA")
  logService~log(level, payload, point)
  return self

::method history
  expose history
  return history~copy

::method lastHistoryEntry
  expose history
  if history~items = 0 then return .nil
  return history~at(history~items)

::method currentPath
  expose currentPath
  return currentPath~copy

::method pathLearner
  expose pathLearner
  return pathLearner

::method beginPath
  expose currentPath
  currentPath = .Array~new
  self~logEvent("INTENTION.PATH.BEGIN", "DEBUG", .Directory~new)
  return self

::method sealPath
  expose currentPath pathLearner
  if currentPath~items >= 2 then pathLearner~learn(currentPath)
  payload = .Directory~new
  payload~put(currentPath~items, "PATH_LENGTH")
  self~logEvent("INTENTION.PATH.LEARN", "INFO", payload)
  currentPath = .Array~new
  return self

::method learnPath
  expose pathLearner
  use arg intentionIds
  pathLearner~learn(intentionIds)
  return self

::method predictNext
  expose pathProvider
  proposals = pathProvider~propose(self, "")
  do i = 1 to proposals~items
    proposal = proposals~at(i)
    payload = .Directory~new
    payload~put(proposal~intentionId, "INTENTION")
    payload~put(proposal~score, "SCORE")
    payload~put(proposal~evidence, "EVIDENCE")
    self~logEvent("INTENTION.PATH.PREDICT", "DEBUG", payload)
  end
  return proposals

::method registerSphere
  expose spheres
  use arg name, spec, interrogator
  sphere = .IntentionSphere~new(name, spec, interrogator)
  spheres~put(sphere, sphere~name)
  return sphere

::method sphere
  expose spheres
  use arg name
  key = translate(strip(name))
  if spheres~hasIndex(key) then return spheres~at(key)
  supplier = spheres~supplier
  do while supplier~available
    candidate = supplier~item
    if candidate~matches(key) then return candidate
    supplier~next
  end
  return .nil

::method spheres
  expose spheres
  return spheres~copy

::method providers
  expose providers
  return providers~copy

::method buckets
  expose buckets
  return buckets~copy

::method feed
  use arg bucketName, content, source = "", metadata = .nil
  bucket = self~bucket(bucketName)
  if bucket == .nil then raise syntax 93.900 array("Unknown intention bucket:" translate(strip(bucketName)))
  bucket~feed(.IntentionEvidence~new(content, source, metadata))
  return self

/* Minimal ergonomic surface requested by the caller.
 * register("have dinner", event) returns the registration so aliases, slots,
 * bucket and policy metadata can be added fluently.
 */
::method register
  expose registrations defaultBucket buckets
  use arg phrase, event, bucketName
  if arg(3, "O") = 1 then bucketName = defaultBucket
  key = translate(strip(bucketName))
  if buckets~hasIndex(key) = 0 then raise syntax 93.900 array("Unknown intention bucket:" key)
  registration = .IntentionRegistration~new(phrase, event, key)
  registrations~put(registration, registration~id)
  buckets~at(key)~add(registration)
  return registration

::method registration
  expose registrations
  use arg intentionId
  key = translate(strip(intentionId))
  if registrations~hasIndex(key) = 0 then return .nil
  return registrations~at(key)

::method registrations
  expose registrations
  return registrations

::method loadCorpus
  use arg corpus
  if corpus == .nil then return self
  supplier = corpus~entries~supplier
  do while supplier~available
    material = supplier~item
    bucket = self~bucket(material~bucketName)
    if bucket == .nil then self~registerBucket(material~bucketName, material~policy)
    registration = self~register(material~phrase, material~event, material~bucketName)
    aliases = material~aliases
    aliasIndex = 1
    do while aliasIndex <= aliases~items
      registration~alias(aliases~at(aliasIndex))
      aliasIndex = aliasIndex + 1
    end
    requirements = material~requirements
    requirementIndex = 1
    do while requirementIndex <= requirements~items
      requirement = requirements~at(requirementIndex)
      registration~requireSlot(requirement~name, requirement~prompt, requirement~explicitRequired)
      requirementIndex = requirementIndex + 1
    end
    rules = material~slotRules
    ruleIndex = 1
    do while ruleIndex <= rules~items
      rule = rules~at(ruleIndex)
      registration~slotRule(rule~slotName, rule~markers, rule~mode)
      ruleIndex = ruleIndex + 1
    end
    supplier~next
  end

  evidenceSupplier = corpus~evidence~supplier
  do while evidenceSupplier~available
    evidence = evidenceSupplier~item
    bucket = self~bucket(evidence~bucketName)
    if bucket == .nil then self~registerBucket(evidence~bucketName, evidence~policy)
    self~feed(evidence~bucketName, evidence~content, evidence~source, evidence~metadata)
    evidenceSupplier~next
  end
  return self


::method registerHintLibrary
  expose hintLibraries
  use arg library
  if library == .nil then raise syntax 93.900 array("Hint library must not be NIL")
  if \library~isA(.IntentionHintLibrary) then raise syntax 93.900 array("Hint library must be an IntentionHintLibrary")
  hintLibraries~append(library)
  return self

::method hintLibraries
  expose hintLibraries
  return hintLibraries~copy

::method matchingHints
  expose hintLibraries
  use arg text, sphereName = ""
  out = .Array~new
  do libraryIndex = 1 to hintLibraries~items
    library = hintLibraries~at(libraryIndex)
    matches = library~matches(text, sphereName)
    do matchIndex = 1 to matches~items
      out~append(matches~at(matchIndex))
    end
  end
  return out

::method hintProposals
  use arg text, sphereName = ""
  proposals = .Array~new
  matches = self~matchingHints(text, sphereName)
  do i = 1 to matches~items
    match = matches~at(i)
    hint = match~hint
    if match~phraseMatched then do
      score = 70 + match~phraseWeight
      if score > 95 then score = 95
      proposal = .IntentionProposal~new(hint~intentionId, score, "HINT", .false, match~evidence)
      proposals~append(proposal)
      payload = .Directory~new
      payload~put(hint~intentionId, "INTENTION")
      payload~put(match~phraseWeight, "WEIGHT")
      payload~put(match~evidence, "EVIDENCE")
      self~logEvent("INTENTION.HINT.PHRASE", "DEBUG", payload)
    end
  end
  return proposals

::method applyPlanHints
  use arg proposals, text, sphereName = ""
  matches = self~matchingHints(text, sphereName)
  do proposalIndex = 1 to proposals~items
    proposal = proposals~at(proposalIndex)
    changed = .false
    do matchIndex = 1 to matches~items
      match = matches~at(matchIndex)
      hint = match~hint
      if hint~intentionId == proposal~intentionId then do
        if hint~planApplicable(match~phraseMatched) then do
          proposal = self~mergeHintPlan(proposal, hint)
          proposals~put(proposal, proposalIndex)
          changed = .true
          payload = .Directory~new
          payload~put(proposal~intentionId, "INTENTION")
          if hint~plan \== .nil then payload~put(hint~plan~steps~items, "HINT_STEP_COUNT")
          self~logEvent("INTENTION.HINT.PLAN.APPLY", "DEBUG", payload)
        end
      end
    end
    if changed then proposals~put(self~assessProposalPlan(proposal), proposalIndex)
  end
  return proposals

::method mergeHintPlan
  use arg proposal, hint
  hintPlan = hint~plan
  if hintPlan == .nil then return proposal
  current = proposal~proposedPlan
  if current == .nil then do
    proposal~proposedPlan(hintPlan~copy)
    return proposal
  end
  if \current~isA(.IntentionPlan) then return proposal

  hintSteps = hintPlan~steps
  do i = 1 to hintSteps~items
    step = hintSteps~at(i)
    if \current~containsEquivalentStep(step) then current~appendStep(step~copy)
  end
  required = hintPlan~requiredBindings
  do i = 1 to required~items
    current~requireBindingUnique(required~at(i))
  end
  expected = hintPlan~expectedOutputs
  do i = 1 to expected~items
    current~expectOutputUnique(expected~at(i))
  end
  auth = hintPlan~authorityRequirements
  do i = 1 to auth~items
    current~requireAuthorityUnique(auth~at(i))
  end
  if current~sideEffectClass == "NONE" then do
    if hintPlan~sideEffectClass \== "NONE" then current~sideEffectClass = hintPlan~sideEffectClass
  end
  proposal~proposedPlan(current)
  return proposal

::method registerSlotResolver
  expose slotResolvers
  use arg semanticType, resolver
  key = translate(strip(semanticType))
  if key == "" then raise syntax 93.900 array("Slot resolver semantic type must not be empty")
  if resolver == .nil then raise syntax 93.900 array("Slot resolver object is required")
  slotResolvers~put(resolver, key)
  return self

::method slotResolver
  expose slotResolvers
  use arg semanticType
  key = translate(strip(semanticType))
  if key == "" then return .nil
  if slotResolvers~hasIndex(key) = 0 then return .nil
  return slotResolvers~at(key)

::method unmetRequirement
  use arg registration, proposal
  requirements = registration~requirements
  do i = 1 to requirements~items
    requirement = requirements~at(i)
    slot = proposal~slot(requirement~name)
    if slot == .nil then return requirement
    if strip(slot~value) == "" then return requirement
    bucket = self~bucket(registration~bucketName)
    if requirement~explicitRequired then do
      if bucket~policy~allowInferredRequiredSlots = .false then do
        if slot~explicit = .false then return requirement
      end
    end
  end
  return .nil

::method applyResolutionCandidate
  use arg proposal, candidate
  bound = proposal~copy
  bindings = candidate~bindings
  supplier = bindings~supplier
  do while supplier~available
    slot = supplier~item
    bound~putSlot(supplier~index, slot~value, slot~explicit)
    supplier~next
  end
  return self~materializeProposalPlan(bound)

/* Materialise the conditional plan for the proposal from the registration's
 * domain-owned builder, when one is registered.  Builders are advisory only:
 * policy and READY remain authoritative.  Re-materialising after canonical
 * slot resolution prevents stale plans from surviving clarification. */
::method materializeProposalPlan
  use arg proposal
  if proposal == .nil then return .nil
  registration = self~registration(proposal~intentionId)
  if registration == .nil then return proposal
  builder = registration~planBuilder
  if builder \== .nil then do
    plan = builder~build(self, registration, proposal)
    proposal~proposedPlan(plan)
  end
  return self~assessProposalPlan(proposal, registration)

/* Assess the plan independently from meaning selection.  The built-in baseline
 * checks only structural required bindings.  Domain-owned assessors may add
 * resource, precondition and authority evidence.  FEASIBLE never grants authority
 * and INFEASIBLE does not rewrite the recognised intention. */
::method assessProposalPlan
  use arg proposal, registration = .nil
  if proposal == .nil then return .nil
  if registration == .nil then registration = self~registration(proposal~intentionId)
  plan = proposal~proposedPlan
  if plan == .nil then return proposal
  if \plan~isA(.IntentionPlan) then return proposal

  assessment = .IntentionPlanAssessment~new("UNKNOWN", "No domain feasibility assessment has been supplied.")
  required = plan~requiredBindings
  do i = 1 to required~items
    name = required~at(i)
    slot = proposal~slot(name)
    if slot == .nil then assessment~addMissingBinding(name)
    else do
      if strip(slot~value) == "" then assessment~addMissingBinding(name)
    end
  end

  validation = plan~validate
  if \validation~valid then do
    problems = validation~problems
    do i = 1 to problems~items
      assessment~addViolatedPrecondition(problems~at(i))
    end
  end

  /* Evidence requirements are generic feasibility constraints.  Facts can come
   * from the shared service ledger, the recognition proposal, or the plan itself.
   * Confidence and authority are independent thresholds. */
  facts = .Array~new
  serviceFacts = self~evidenceFacts
  do i = 1 to serviceFacts~items; facts~append(serviceFacts~at(i)); end
  proposalFacts = proposal~evidenceFacts
  do i = 1 to proposalFacts~items; facts~append(proposalFacts~at(i)); end
  planFacts = plan~evidenceFacts
  do i = 1 to planFacts~items; facts~append(planFacts~at(i)); end
  requirements = plan~evidenceRequirements
  do i = 1 to requirements~items
    requirement = requirements~at(i)
    evidenceSet = .IntentionEvidenceSet~new(facts)
    satisfied = requirement~satisfiedBySet(evidenceSet)
    evidencePayload = .Directory~new
    evidencePayload~put(proposal~intentionId, "INTENTION")
    evidencePayload~put(requirement~subject, "SUBJECT")
    evidencePayload~put(requirement~predicate, "PREDICATE")
    evidencePayload~put(requirement~expectedValue, "EXPECTED_VALUE")
    evidencePayload~put(requirement~minConfidence, "MIN_CONFIDENCE")
    evidencePayload~put(requirement~minAuthority, "MIN_AUTHORITY")
    evidencePayload~put(satisfied, "SATISFIED")
    self~logEvent("INTENTION.EVIDENCE.REQUIREMENT", "DEBUG", evidencePayload)
    if \satisfied then do
      assessment~addViolatedPrecondition(requirement~describe)
      if \assessment~needsClarification then do
        if requirement~clarificationQuestion \== "" then assessment~requestClarification(requirement~clarificationQuestion)
      end
    end
  end
  if requirements~items > 0 then do
    if assessment~blockerCount == 0 then assessment~markFeasible("All declared evidence requirements are satisfied.")
  end

  if registration \== .nil then do
    assessor = registration~planAssessor
    if assessor \== .nil then do
      assessed = assessor~assess(self, registration, proposal, plan, assessment)
      if assessed \== .nil then assessment = assessed
    end
  end
  assessment~normalise
  plan~assessment(assessment)

  payload = .Directory~new
  payload~put(proposal~intentionId, "INTENTION")
  payload~put(assessment~status, "STATUS")
  payload~put(assessment~blockerCount, "BLOCKER_COUNT")
  payload~put(assessment~missingBindings~items, "MISSING_BINDING_COUNT")
  payload~put(assessment~unavailableResources~items, "UNAVAILABLE_RESOURCE_COUNT")
  payload~put(assessment~missingAuthority~items, "MISSING_AUTHORITY_COUNT")
  payload~put(assessment~violatedPreconditions~items, "VIOLATED_PRECONDITION_COUNT")
  self~logEvent("INTENTION.PLAN.ASSESS", "DEBUG", payload)
  return proposal

/* A feasibility blocker becomes interaction state only when the plan/domain has
 * explicitly supplied a clarification question.  This keeps impossible plans
 * distinguishable from missing information while preventing application-owned
 * post-READY clarification gates. */
::method planClarificationDecision
  use arg input, registration, proposal
  if proposal == .nil then return .nil
  plan = proposal~proposedPlan
  if plan == .nil then return .nil
  if \plan~isA(.IntentionPlan) then return .nil
  assessment = plan~assessment
  if assessment == .nil then return .nil
  if assessment~status \== "INFEASIBLE" then return .nil
  if \assessment~needsClarification then return .nil
  return .IntentionDecision~clarify(input, registration, proposal, assessment~clarificationQuestion)

::method resolvePendingSlot
  use arg decision, answer
  registration = decision~registration
  proposal = decision~proposal
  if registration == .nil then return .nil
  if proposal == .nil then return .nil
  requirement = self~unmetRequirement(registration, proposal)
  if requirement == .nil then return .nil
  semanticType = registration~slotType(requirement~name)
  if semanticType == "" then return .nil
  resolver = self~slotResolver(semanticType)
  if resolver == .nil then return .nil

  payload = .Directory~new
  payload~put(registration~id, "INTENTION")
  payload~put(requirement~name, "SLOT")
  payload~put(semanticType, "SEMANTIC_TYPE")
  payload~put(answer, "ANSWER")
  self~logEvent("INTENTION.SLOT.RESOLVE.START", "DEBUG", payload)

  resolution = resolver~resolve(self, registration, proposal, requirement, answer)
  if resolution == .nil then return decision
  candidates = resolution~candidates
  payload~put(candidates~items, "MATCH_COUNT")
  self~logEvent("INTENTION.SLOT.RESOLVE.RESULT", "DEBUG", payload)
  if candidates~items = 0 then do
    question = resolution~question
    if strip(question) == "" then question = requirement~prompt
    unresolved = .IntentionDecision~clarify(decision~input, registration, proposal, question)
    self~logDecision("INTENTION.SLOT.RESOLVE.NONE", unresolved)
    return unresolved
  end

  if candidates~items = 1 then do
    candidate = candidates~at(1)
    boundProposal = self~applyResolutionCandidate(proposal, candidate)
    bucket = self~bucket(registration~bucketName)
    policyDecision = bucket~policy~evaluate(registration, boundProposal)
    if policyDecision~status == "CLARIFY" then do
      nextDecision = .IntentionDecision~clarify(decision~input, registration, boundProposal, policyDecision~question)
      self~logDecision("INTENTION.SLOT.RESOLVE.BOUND", nextDecision)
      return nextDecision
    end
    if policyDecision~status == "REJECT" then return .IntentionDecision~unknown(decision~input, policyDecision~question)
    planDecision = self~planClarificationDecision(decision~input, registration, boundProposal)
    if planDecision \== .nil then do
      self~logDecision("INTENTION.PLAN.CLARIFY", planDecision)
      return planDecision
    end
    if bucket~policy~confirmIntent then do
      question = "Do you mean '" || registration~phrase || "'?"
      nextDecision = .IntentionDecision~confirm(decision~input, registration, boundProposal, question)
      self~logDecision("INTENTION.SLOT.RESOLVE.BOUND", nextDecision)
      return nextDecision
    end
    nextDecision = .IntentionDecision~ready(decision~input, registration, boundProposal)
    self~logDecision("INTENTION.SLOT.RESOLVE.BOUND", nextDecision)
    return nextDecision
  end

  choices = .Array~new
  limit = min(candidates~items, self~maxClarificationOptions)
  do i = 1 to limit
    candidate = candidates~at(i)
    boundProposal = self~applyResolutionCandidate(proposal, candidate)
    label = candidate~label
    if strip(label) == "" then label = requirement~name || " = " || boundProposal~slot(requirement~name)~value
    choices~append(.IntentionClarificationChoice~new(i, boundProposal, label))
  end
  question = resolution~question
  if strip(question) == "" then question = self~ambiguityQuestion(choices)
  else question = question || .endOfLine || self~ambiguityQuestion(choices)
  nextDecision = .IntentionDecision~clarify(decision~input, registration, proposal, question, choices)
  self~logDecision("INTENTION.SLOT.RESOLVE.AMBIGUOUS", nextDecision)
  return nextDecision

/* input() is the conversational state machine.
 * UNKNOWN          no credible proposal
 * CLARIFY          more operational detail is required
 * CONFIRM          ask whether the proposed intention is correct
 * READY            confirmed and dispatchable
 */
::method input
  expose activeDecision providers fixedFormProvider impliedProvider pathProvider
  use arg text
  text = strip(text)
  inputPayload = .Directory~new
  inputPayload~put(text, "INPUT")
  self~logEvent("INTENTION.INPUT", "DEBUG", inputPayload)
  if text == "" then return .IntentionDecision~unknown(text, "Please say what you want to do.")

  if activeDecision \== .nil then do
    if self~isCancelCue(text) then do
      self~cancelActiveDecision("USER_CANCEL")
      return .IntentionDecision~unknown(text, "Pending clarification cancelled. Please describe the new intention.")
    end
    replacement = self~stripNewIntentCue(text)
    if replacement \== "" then do
      self~cancelActiveDecision("USER_NEW_INTENT")
      text = replacement
    end
  end

  /* Refresh discovered operational truth before any fresh proposal cycle.  A
   * clarification answer keeps its retained proposal; callers can explicitly
   * refresh/reassess it with refreshActiveDecision when external state changes. */
  if activeDecision == .nil then self~refreshDiscovery

  if activeDecision \== .nil then do
    if activeDecision~status == "CLARIFY" then do
      activeDecisionInput = activeDecision~input
      choices = activeDecision~choices
      if choices~items = 0 then do
        resolvedDecision = self~resolvePendingSlot(activeDecision, text)
        if resolvedDecision \== .nil then do
          activeDecision = .nil
          if resolvedDecision~status == "CLARIFY" then activeDecision = resolvedDecision
          if resolvedDecision~status == "CONFIRM" then activeDecision = resolvedDecision
          return resolvedDecision
        end
      end
      if choices~items > 0 then do
        selectedIndex = self~clarificationSelection(text, choices~items)
        if selectedIndex > 0 then do
          selectedChoice = choices~at(selectedIndex)
          selectedProposal = selectedChoice~proposal
          selectedRegistration = self~registration(selectedProposal~intentionId)
          selectedBucket = self~bucket(selectedRegistration~bucketName)
          selectedPolicyDecision = selectedBucket~policy~evaluate(selectedRegistration, selectedProposal)
          selectionPayload = .Directory~new
          selectionPayload~put(selectedIndex, "SELECTION")
          selectionPayload~put(selectedProposal~intentionId, "INTENTION")
          selectionPayload~put(choices~items, "OPTION_COUNT")
          self~logEvent("INTENTION.AMBIGUOUS.SELECT", "INFO", selectionPayload)
          activeDecision = .nil
          if selectedPolicyDecision~status == "REJECT" then do
            self~logEvent("INTENTION.POLICY.BLOCK", "INFO", selectionPayload)
            return .IntentionDecision~unknown(text, selectedPolicyDecision~question)
          end
          if selectedPolicyDecision~status == "CLARIFY" then do
            decision = .IntentionDecision~clarify(activeDecisionInput, selectedRegistration, selectedProposal, selectedPolicyDecision~question)
            activeDecision = decision
            self~logDecision("INTENTION.CLARIFY", decision)
            return decision
          end
          planDecision = self~planClarificationDecision(activeDecisionInput, selectedRegistration, selectedProposal)
          if planDecision \== .nil then do
            activeDecision = planDecision
            self~logDecision("INTENTION.PLAN.CLARIFY", planDecision)
            return planDecision
          end
          if selectedBucket~policy~confirmIntent then do
            question = "Do you mean '" || selectedRegistration~phrase || "'?"
            decision = .IntentionDecision~confirm(activeDecisionInput, selectedRegistration, selectedProposal, question)
            activeDecision = decision
            self~logDecision("INTENTION.CONFIRM", decision)
            return decision
          end
          decision = .IntentionDecision~ready(activeDecisionInput, selectedRegistration, selectedProposal)
          self~logDecision("INTENTION.READY", decision)
          return decision
        end
        if datatype(text, "W") then do
          self~logDecision("INTENTION.AMBIGUOUS.INVALID_SELECTION", activeDecision)
          return activeDecision
        end
      end
      text = activeDecisionInput || " " || text
      activeDecision = .nil
    end
    if activeDecision \== .nil then do
      if activeDecision~status == "CONFIRM" then do
        answer = self~confirmationAnswer(text)
        if answer == "YES" then do
          activeDecision~markReady
          ready = activeDecision
          activeDecision = .nil
          self~logDecision("INTENTION.CONFIRM.ACCEPT", ready)
          return ready
        end
        if answer == "NO" then do
          self~logDecision("INTENTION.CONFIRM.REJECT", activeDecision)
          activeDecision = .nil
          return .IntentionDecision~unknown(text, "Okay. Please describe what you intended instead.")
        end
        return .IntentionDecision~clarify(text, activeDecision~registration, activeDecision~proposal, -
            "Please answer yes or no: " || activeDecision~confirmationQuestion)
      end
    end
  end

  proposals = .Array~new
  sphereInfo = self~detectSphere(text)
  effectiveText = text
  sphereName = ""
  if sphereInfo \== .nil then do
    effectiveText = sphereInfo~at("BODY")
    sphereName = sphereInfo~at("SPHERE")~name
    self~appendOffered(proposals, self~interrogateSphere(sphereInfo, text, effectiveText))
  end

  self~appendOffered(proposals, self~hintProposals(effectiveText, sphereName))
  self~appendOffered(proposals, self~activeSurfaceProposals(effectiveText))
  transformed = self~transformedProposal(text)
  if transformed \== .nil then proposals~append(transformed)
  self~appendOffered(proposals, impliedProvider~propose(self, text))
  self~appendOffered(proposals, fixedFormProvider~propose(self, effectiveText))

  providerIndex = 1
  do while providerIndex <= providers~items
    provider = providers~at(providerIndex)
    offered = provider~propose(self, effectiveText)
    self~appendOffered(proposals, offered)
    providerIndex = providerIndex + 1
  end

  if proposals~items = 0 | self~isPathCue(text) then self~appendOffered(proposals, pathProvider~propose(self, text))
  self~stampDiscoveryGeneration(proposals)
  proposals = self~consolidate(proposals)
  proposals = self~applyPlanHints(proposals, effectiveText, sphereName)

  if proposals~items = 0 then do
    self~logEvent("INTENTION.UNKNOWN", "INFO", .Directory~new)
    return .IntentionDecision~unknown(text, "I could not determine the intention.")
  end
  ranking = self~rank(proposals)
  best = ranking~at(1)
  registration = self~registration(best~intentionId)
  if registration == .nil then return .IntentionDecision~unknown(text, "The proposed intention is not registered.")
  bucket = self~bucket(registration~bucketName)
  policyDecision = bucket~policy~evaluate(registration, best)

  candidatePayload = .Directory~new
  candidatePayload~put(best~intentionId, "INTENTION")
  candidatePayload~put(best~score, "SCORE")
  candidatePayload~put(best~providerName, "PROVIDER")
  candidatePayload~put(best~evidence, "EVIDENCE")
  self~logEvent("INTENTION.SELECT", "DEBUG", candidatePayload)

  if policyDecision~status == "REJECT" then do
    self~logEvent("INTENTION.POLICY.BLOCK", "INFO", candidatePayload)
    return .IntentionDecision~unknown(text, policyDecision~question)
  end
  if policyDecision~status == "CLARIFY" then do
    decision = .IntentionDecision~clarify(text, registration, best, policyDecision~question)
    activeDecision = decision
    self~logDecision("INTENTION.CLARIFY", decision)
    return decision
  end

  ambiguityChoices = self~ambiguityChoices(ranking, bucket~policy~ambiguityMargin)
  if ambiguityChoices~items > 1 then do
    question = self~ambiguityQuestion(ambiguityChoices)
    decision = .IntentionDecision~clarify(text, registration, best, question, ambiguityChoices)
    activeDecision = decision
    ambiguityPayload = .Directory~new
    ambiguityPayload~put(ambiguityChoices~items, "OPTION_COUNT")
    ambiguityPayload~put(question, "QUESTION")
    optionRecords = .Array~new
    do optionIndex = 1 to ambiguityChoices~items
      choice = ambiguityChoices~at(optionIndex)
      optionRecord = .Directory~new
      optionRecord~put(choice~index, "INDEX")
      optionRecord~put(choice~intentionId, "INTENTION")
      optionRecord~put(choice~label, "LABEL")
      optionRecord~put(choice~score, "SCORE")
      optionRecord~put(choice~providerName, "PROVIDER")
      plan = choice~proposedPlan
      if plan \== .nil then do
        if plan~isA(.IntentionPlan) then do
          optionRecord~put(plan~summary, "PLAN_SUMMARY")
          optionRecord~put(plan~steps~items, "PLAN_STEP_COUNT")
          optionRecord~put(plan~sideEffectClass, "PLAN_SIDE_EFFECT_CLASS")
          assessment = plan~assessment
          if assessment \== .nil then do
            optionRecord~put(assessment~status, "PLAN_ASSESSMENT_STATUS")
            optionRecord~put(assessment~blockerCount, "PLAN_BLOCKER_COUNT")
          end
        end
      end
      optionRecords~append(optionRecord)
    end
    ambiguityPayload~put(optionRecords, "OPTIONS")
    self~logEvent("INTENTION.AMBIGUOUS", "DEBUG", ambiguityPayload)
    return decision
  end

  planDecision = self~planClarificationDecision(text, registration, best)
  if planDecision \== .nil then do
    activeDecision = planDecision
    self~logDecision("INTENTION.PLAN.CLARIFY", planDecision)
    return planDecision
  end

  if bucket~policy~confirmIntent then do
    question = "Do you mean '" || registration~phrase || "'?"
    decision = .IntentionDecision~confirm(text, registration, best, question)
    activeDecision = decision
    self~logDecision("INTENTION.CONFIRM", decision)
    return decision
  end

  decision = .IntentionDecision~ready(text, registration, best)
  self~logDecision("INTENTION.READY", decision)
  return decision

/* Re-evaluate the currently retained clarification against changed external
 * evidence/state without consuming another user utterance.  This is especially
 * useful after runtime/database/domain interrogation has published stronger facts.
 * It keeps clarification ownership in IntentionService rather than in controllers. */
::method refreshActiveDecision
  expose activeDecision
  if activeDecision == .nil then return .nil
  originalGeneration = activeDecision~discoveryGeneration
  originalInput = activeDecision~input
  self~refreshDiscovery
  if originalGeneration > 0 then do
    if originalGeneration \== self~discoveryGeneration then do
      self~cancelActiveDecision("DISCOVERY_GENERATION_CHANGED")
      return self~input(originalInput)
    end
  end
  if activeDecision~status \== "CLARIFY" then return activeDecision
  if activeDecision~choices~items > 0 then return activeDecision
  registration = activeDecision~registration
  proposal = activeDecision~proposal
  if registration == .nil then return activeDecision
  if proposal == .nil then return activeDecision

  proposal = self~materializeProposalPlan(proposal~copy)
  bucket = self~bucket(registration~bucketName)
  policyDecision = bucket~policy~evaluate(registration, proposal)
  if policyDecision~status == "REJECT" then do
    originalInput = activeDecision~input
    activeDecision = .nil
    return .IntentionDecision~unknown(originalInput, policyDecision~question)
  end
  if policyDecision~status == "CLARIFY" then do
    refreshed = .IntentionDecision~clarify(activeDecision~input, registration, proposal, policyDecision~question)
    activeDecision = refreshed
    self~logDecision("INTENTION.REFRESH.CLARIFY", refreshed)
    return refreshed
  end
  planDecision = self~planClarificationDecision(activeDecision~input, registration, proposal)
  if planDecision \== .nil then do
    activeDecision = planDecision
    self~logDecision("INTENTION.REFRESH.PLAN.CLARIFY", planDecision)
    return planDecision
  end
  if bucket~policy~confirmIntent then do
    question = "Do you mean '" || registration~phrase || "'?"
    refreshed = .IntentionDecision~confirm(activeDecision~input, registration, proposal, question)
    activeDecision = refreshed
    self~logDecision("INTENTION.REFRESH.CONFIRM", refreshed)
    return refreshed
  end
  refreshed = .IntentionDecision~ready(activeDecision~input, registration, proposal)
  activeDecision = .nil
  self~logDecision("INTENTION.REFRESH.READY", refreshed)
  return refreshed

::method appendOffered
  use arg proposals, offered
  if offered == .nil then return proposals
  if offered~isA(.Array) then do
    do i = 1 to offered~items
      proposal = offered~at(i)
      if proposal \== .nil then proposals~append(self~materializeProposalPlan(proposal))
    end
  end
  else proposals~append(self~materializeProposalPlan(offered))
  return proposals

::method consolidate
  use arg proposals
  bestByIntent = .Directory~new
  intentOrder = .Array~new
  do i = 1 to proposals~items
    proposal = proposals~at(i)
    id = proposal~intentionId
    if bestByIntent~hasIndex(id) = 0 then do
      bestByIntent~put(proposal, id)
      intentOrder~append(id)
    end
    else do
      existing = bestByIntent~at(id)
      if proposal~score > existing~score then bestByIntent~put(proposal, id)
    end
  end
  out = .Array~new
  do i = 1 to intentOrder~items
    out~append(bestByIntent~at(intentOrder~at(i)))
  end
  return out

::method isPathCue
  use arg text
  value = translate(strip(text))
  if value == "NEXT" then return .true
  if value == "CONTINUE" then return .true
  if value == "WHAT NEXT" then return .true
  if value == "THEN" then return .true
  return .false

::method detectSphere
  expose spheres
  use arg text
  if words(text) < 2 then return .nil
  lead = translate(word(text, 1))
  if lead \== "FROM" then do
    if lead \== "IN" then do
      if lead \== "USING" then return .nil
    end
  end
  requested = word(text, 2)
  sphere = self~sphere(requested)
  if sphere == .nil then return .nil
  info = .Directory~new
  info~put(sphere, "SPHERE")
  info~put(subword(text, 3), "BODY")
  payload = .Directory~new
  payload~put(sphere~name, "SPHERE")
  self~logEvent("INTENTION.SPHERE.SELECT", "DEBUG", payload)
  return info

::method sphereRecords
  use arg sphereName
  sphereName = translate(strip(sphereName))
  records = .Array~new
  allBuckets = self~buckets
  supplier = allBuckets~supplier
  do while supplier~available
    bucket = supplier~item
    evidence = bucket~evidence
    do i = 1 to evidence~items
      item = evidence~at(i)
      include = bucket~name == sphereName
      metadata = item~metadata
      if metadata \== .nil then do
        if metadata~hasIndex("SPHERE") then include = include | translate(strip(metadata~at("SPHERE"))) == sphereName
        if metadata~hasIndex("LANGUAGE") then include = include | translate(strip(metadata~at("LANGUAGE"))) == sphereName
      end
      if include then records~append(item)
    end
    supplier~next
  end
  return records

::method interrogateSphere
  use arg sphereInfo, originalText, body
  sphere = sphereInfo~at("SPHERE")
  interrogator = sphere~interrogator
  if interrogator == .nil then return .Array~new
  records = self~sphereRecords(sphere~name)
  situation = .IntentionSituation~new(originalText, body, sphere~name, sphere~spec, records, self~history, self~registrations)
  payload = .Directory~new
  payload~put(sphere~name, "SPHERE")
  payload~put(records~items, "RECORD_COUNT")
  self~logEvent("INTENTION.INTERROGATOR.START", "DEBUG", payload)
  answer = interrogator~interrogate(situation)
  if answer == .nil then return .Array~new
  if answer~isA(.IntentionInterrogationResult) then do
    payload~put(answer~purpose, "PURPOSE")
    payload~put(answer~evidence, "EVIDENCE")
    self~logEvent("INTENTION.INTERROGATOR.EVIDENCE", "DEBUG", payload)
    return answer~proposals
  end
  return answer

::method logDecision
  use arg point, decision
  payload = .Directory~new
  payload~put(decision~status, "STATUS")
  if decision~registration \== .nil then payload~put(decision~registration~id, "INTENTION")
  if decision~proposal \== .nil then do
    payload~put(decision~proposal~providerName, "PROVIDER")
    payload~put(decision~proposal~score, "SCORE")
    payload~put(decision~proposal~evidence, "EVIDENCE")
    plan = decision~proposal~proposedPlan
    if plan \== .nil then do
      if plan~isA(.IntentionPlan) then do
        payload~put(plan~summary, "PLAN_SUMMARY")
        payload~put(plan~steps~items, "PLAN_STEP_COUNT")
        payload~put(plan~sideEffectClass, "PLAN_SIDE_EFFECT_CLASS")
        assessment = plan~assessment
        if assessment \== .nil then do
          payload~put(assessment~status, "PLAN_ASSESSMENT_STATUS")
          payload~put(assessment~blockerCount, "PLAN_BLOCKER_COUNT")
        end
      end
    end
  end
  payload~put(decision~question, "QUESTION")
  self~logEvent(point, "DEBUG", payload)
  return self

::method dispatch
  expose history currentPath
  use arg decision
  if decision == .nil then raise syntax 93.900 array("Decision is required")
  if decision~status \== "READY" then raise syntax 93.900 array("Only READY intentions may be dispatched")
  event = decision~registration~event
  dispatchValue = .nil
  if event \== .nil then dispatchValue = event~invoke(decision)
  entry = .IntentionHistoryEntry~new(decision~registration~id, decision~registration~phrase, -
      decision~input, decision~slots, decision~proposal~providerName, decision~proposedPlan)
  history~append(entry)
  currentPath~append(decision~registration~id)
  payload = .Directory~new
  payload~put(decision~registration~id, "INTENTION")
  payload~put(currentPath~items, "PATH_LENGTH")
  self~logEvent("INTENTION.DISPATCH", "INFO", payload)
  return dispatchValue

::method reset
  expose activeDecision
  activeDecision = .nil
  return self

::method rank
  use arg proposals
  ranked = proposals~copy
  count = ranked~items
  i = 1
  do while i <= count
    j = i + 1
    do while j <= count
      if ranked~at(j)~score > ranked~at(i)~score then do
        swap = ranked~at(i)
        ranked~put(ranked~at(j), i)
        ranked~put(swap, j)
      end
      j = j + 1
    end
    i = i + 1
  end
  return ranked

::method ambiguityChoices
  expose maxClarificationOptions
  use arg ranking, ambiguityMargin
  choices = .Array~new
  if ranking == .nil then return choices
  if ranking~items = 0 then return choices
  bestScore = ranking~at(1)~score
  do i = 1 to ranking~items
    proposal = ranking~at(i)
    margin = bestScore - proposal~score
    if margin >= ambiguityMargin then leave
    registration = self~registration(proposal~intentionId)
    label = proposal~intentionId
    if registration \== .nil then label = registration~clarificationLabel
    choices~append(.IntentionClarificationChoice~new(choices~items + 1, proposal, label))
    if choices~items >= maxClarificationOptions then leave
  end
  return choices

::method ambiguityQuestion
  use arg choices
  question = "Did you mean:" || "0a"x
  do i = 1 to choices~items
    choice = choices~at(i)
    question = question || "0a"x || "[" || choice~index || "] " || choice~label
  end
  return question

::method clarificationSelection
  use arg text, optionCount
  value = strip(text)
  if \datatype(value, "W") then return 0
  selected = value
  if selected < 1 then return 0
  if selected > optionCount then return 0
  return selected

::method confirmationAnswer
  use arg text
  value = translate(strip(text))
  if value == "YES" then return "YES"
  if value == "Y" then return "YES"
  if value == "CORRECT" then return "YES"
  if value == "THAT'S RIGHT" then return "YES"
  if value == "THATS RIGHT" then return "YES"
  if value == "NO" then return "NO"
  if value == "N" then return "NO"
  if value == "WRONG" then return "NO"
  return "UNKNOWN"

::class IntentionBucket public
::method init
  expose name policy entries evidence
  use arg name, policy
  entries = .Array~new
  evidence = .Array~new
::attribute name get
::attribute policy get
::method add
  expose entries
  use arg registration
  entries~append(registration)
  return self
::method entries
  expose entries
  return entries~copy
::method feed
  expose evidence
  use arg material
  evidence~append(material)
  return self
::method evidence
  expose evidence
  return evidence~copy

::class IntentionBucketPolicy public
::method init
  expose specificity minConfidence ambiguityMargin confirmIntent allowInferredRequiredSlots
  use arg specificity = "FLEXIBLE", minConfidence = 60, ambiguityMargin = 12, confirmIntent = .true, allowInferredRequiredSlots = .false
  specificity = translate(strip(specificity))
  if specificity == "" then specificity = "FLEXIBLE"
  if specificity \== "FLEXIBLE" then do
    if specificity \== "EXPLICIT" then do
      if specificity \== "EXACT" then raise syntax 93.900 array("Specificity must be FLEXIBLE, EXPLICIT or EXACT")
    end
  end
::attribute specificity get
::attribute minConfidence get
::attribute ambiguityMargin get
::attribute confirmIntent get
::attribute allowInferredRequiredSlots get

::method evaluate
  expose specificity minConfidence allowInferredRequiredSlots
  use arg registration, proposal
  if proposal~score < minConfidence then return .IntentionPolicyDecision~reject("The match is not strong enough yet.")

  requirements = registration~requirements
  requirementIndex = 1
  do while requirementIndex <= requirements~items
    requirement = requirements~at(requirementIndex)
    slot = proposal~slot(requirement~name)
    if slot == .nil then return .IntentionPolicyDecision~clarify(requirement~prompt)
    if strip(slot~value) == "" then return .IntentionPolicyDecision~clarify(requirement~prompt)
    if requirement~explicitRequired then do
      if allowInferredRequiredSlots = .false then do
        if slot~explicit = .false then return .IntentionPolicyDecision~clarify(requirement~prompt)
      end
    end
    requirementIndex = requirementIndex + 1
  end

  if specificity == "EXACT" then do
    if proposal~explicitEvidence = .false then return .IntentionPolicyDecision~clarify("Please state the intended operation explicitly and provide every required detail.")
    if proposal~score < 90 then return .IntentionPolicyDecision~clarify("Please specify this intention more precisely before it can proceed.")
  end
  if specificity == "EXPLICIT" then do
    if proposal~explicitEvidence = .false then return .IntentionPolicyDecision~clarify("Please state the intended operation explicitly.")
  end
  return .IntentionPolicyDecision~allow

::class IntentionPolicyDecision public
::method init
  expose status question
  use arg status, question = ""
::attribute status get
::attribute question get
::method allow class
  return self~new("ALLOW", "")
::method clarify class
  use arg question
  return self~new("CLARIFY", question)
::method reject class
  use arg question
  return self~new("REJECT", question)

::class IntentionRegistration public
::method init
  expose id phrase event bucketName aliases requirements slotRules metadata verbTerms nounTerms slotTypes planBuilder planAssessor
  use arg phrase, event, bucketName
  phrase = strip(phrase)
  if phrase == "" then raise syntax 93.900 array("Intention phrase must not be empty")
  id = self~makeId(phrase)
  aliases = .Array~new
  aliases~append(phrase)
  requirements = .Array~new
  slotRules = .Array~new
  metadata = .Directory~new
  slotTypes = .Directory~new
  planBuilder = .nil
  planAssessor = .nil
  parse var phrase firstWord remainder
  verbTerms = strip(firstWord)
  nounTerms = strip(remainder)
  if nounTerms == "" then nounTerms = verbTerms
::attribute id get
::attribute phrase get
::attribute event get
::attribute bucketName get
::attribute verbTerms get
::attribute nounTerms get
::method semantics
  expose verbTerms nounTerms
  use arg verbs, nouns
  verbs = strip(verbs)
  nouns = strip(nouns)
  if verbs == "" then raise syntax 93.900 array("Semantic verb terms must not be empty")
  if nouns == "" then raise syntax 93.900 array("Semantic noun terms must not be empty")
  verbTerms = verbs
  nounTerms = nouns
  return self
::method aliases
  expose aliases
  return aliases~copy
::method requirements
  expose requirements
  return requirements~copy
::method slotRules
  expose slotRules
  return slotRules~copy
::method metadata
  expose metadata
  return metadata
::method alias
  expose aliases
  use arg phrase
  value = strip(phrase)
  if value \== "" then aliases~append(value)
  return self
::method requireSlot
  expose requirements
  use arg name, prompt, explicitRequired = .true
  requirements~append(.IntentionRequirement~new(name, prompt, explicitRequired))
  return self
::method slotRule
  expose slotRules
  use arg slotName, markers, mode = "NEXT"
  slotRules~append(.IntentionSlotRule~new(slotName, markers, mode))
  return self
::method slotType
  expose slotTypes
  use arg slotName, semanticType
  key = translate(strip(slotName))
  if arg(2, "O") = 1 then do
    if slotTypes~hasIndex(key) = 0 then return ""
    return slotTypes~at(key)
  end
  value = translate(strip(semanticType))
  if key == "" then raise syntax 93.900 array("Slot type name must not be empty")
  if value == "" then raise syntax 93.900 array("Slot semantic type must not be empty")
  slotTypes~put(value, key)
  return self
::method planBuilder
  expose planBuilder
  use arg builder
  if arg(1, "O") = 0 then do
    planBuilder = builder
    return self
  end
  return planBuilder
::method planAssessor
  expose planAssessor
  use arg assessor
  if arg(1, "O") = 0 then do
    planAssessor = assessor
    return self
  end
  return planAssessor
::method tag
  expose metadata
  use arg name, value
  metadata~put(value, translate(strip(name)))
  return self
::method clarificationLabel
  expose metadata phrase
  if metadata~hasIndex("CLARIFICATION_LABEL") then do
    value = strip(metadata~at("CLARIFICATION_LABEL"))
    if value \== "" then return value
  end
  label = ""
  fields = .Array~of("SPHERE", "LANGUAGE", "CLASS", "METHOD", "ATTRIBUTE", "OPERATION", "OBJECT", "ROLE")
  do i = 1 to fields~items
    key = fields~at(i)
    if metadata~hasIndex(key) then do
      value = strip(metadata~at(key))
      if value \== "" then do
        if label \== "" then label = label || " "
        label = label || key || ": " || value
      end
    end
  end
  if label \== "" then return label
  return phrase

::method makeId
  use arg phrase
  value = translate(strip(phrase))
  value = changestr(" ", value, "_")
  return value

::class IntentionRequirement public
::method init
  expose name prompt explicitRequired
  use arg name, prompt, explicitRequired = .true
  name = translate(strip(name))
  if name == "" then raise syntax 93.900 array("Requirement name must not be empty")
  if strip(prompt) == "" then prompt = "Please specify " || name || "."
::attribute name get
::attribute prompt get
::attribute explicitRequired get

::class IntentionSlotRule public
::method init
  expose slotName markers mode
  use arg slotName, markers, mode = "NEXT"
  slotName = translate(strip(slotName))
  markers = translate(strip(markers))
  mode = translate(strip(mode))
  if slotName == "" then raise syntax 93.900 array("Slot rule name must not be empty")
  if markers == "" then raise syntax 93.900 array("Slot rule markers must not be empty")
  if mode \== "NEXT" then do
    if mode \== "REST" then raise syntax 93.900 array("Slot rule mode must be NEXT or REST")
  end
::attribute slotName get
::attribute markers get
::attribute mode get

::class IntentionClarificationChoice public
::method init
  expose index proposal label
  use arg index, proposal, label
::attribute index get
::attribute proposal get
::attribute label get
::method intentionId
  expose proposal
  return proposal~intentionId
::method score
  expose proposal
  return proposal~score
::method providerName
  expose proposal
  return proposal~providerName
::method evidence
  expose proposal
  return proposal~evidence
::method proposedPlan
  expose proposal
  if proposal == .nil then return .nil
  return proposal~proposedPlan
::method planAssessment
  plan = self~proposedPlan
  if plan == .nil then return .nil
  if \plan~isA(.IntentionPlan) then return .nil
  return plan~assessment

::class IntentionDecision public
::method init
  expose status input registration proposal question choices
  use arg status, input, registration = .nil, proposal = .nil, question = "", choices = .nil
  if choices == .nil then choices = .Array~new
::attribute status get
::attribute input get
::attribute registration get
::attribute proposal get
::attribute question get
::method choices
  expose choices
  return choices~copy
::method confirmationQuestion
  expose question
  return question
::method markReady
  expose status
  status = "READY"
  return self
::method event
  expose registration
  if registration == .nil then return .nil
  return registration~event
::method slots
  expose proposal
  if proposal == .nil then return .Directory~new
  return proposal~slots
::method proposedPlan
  expose proposal
  if proposal == .nil then return .nil
  return proposal~proposedPlan
::method planAssessment
  plan = self~proposedPlan
  if plan == .nil then return .nil
  if \plan~isA(.IntentionPlan) then return .nil
  return plan~assessment
::method planExecutable
  assessment = self~planAssessment
  if assessment == .nil then return .false
  return assessment~feasible
::method discoveryGeneration
  expose proposal
  if proposal == .nil then return 0
  return proposal~discoveryGeneration
::method unknown class
  use arg input, question
  return self~new("UNKNOWN", input, .nil, .nil, question)
::method clarify class
  use arg input, registration, proposal, question, choices = .nil
  return self~new("CLARIFY", input, registration, proposal, question, choices)
::method confirm class
  use arg input, registration, proposal, question
  return self~new("CONFIRM", input, registration, proposal, question)
::method ready class
  use arg input, registration, proposal
  return self~new("READY", input, registration, proposal, "")

::class IntentionCorpus public
::method init
  expose entries evidence
  entries = .Array~new
  evidence = .Array~new
::method add
  expose entries
  use arg material
  entries~append(material)
  return self
::method addEvidence
  expose evidence
  use arg material
  evidence~append(material)
  return self
::method entries
  expose entries
  return entries~copy
::method evidence
  expose evidence
  return evidence~copy

::class IntentionCorpusEvidence public
::method init
  expose bucketName content source metadata policy
  use arg bucketName, content, source = "", metadata = .nil, policy = .nil
  bucketName = translate(strip(bucketName))
  if bucketName == "" then raise syntax 93.900 array("Evidence bucket name must not be empty")
  if metadata == .nil then metadata = .Directory~new
  if policy == .nil then policy = .IntentionBucketPolicy~new
::attribute bucketName get
::attribute content get
::attribute source get
::attribute metadata get
::attribute policy get

::class IntentionEvidence public
::method init
  expose content source metadata
  use arg content, source = "", metadata = .nil
  if metadata == .nil then metadata = .Directory~new
::attribute content get
::attribute source get
::attribute metadata get

::class IntentionCorpusMaterial public
::method init
  expose phrase event bucketName policy aliases requirements slotRules
  use arg phrase, event, bucketName = "DEFAULT", policy = .nil
  aliases = .Array~new
  requirements = .Array~new
  slotRules = .Array~new
  if policy == .nil then policy = .IntentionBucketPolicy~new
::attribute phrase get
::attribute event get
::attribute bucketName get
::attribute policy get
::method aliases
  expose aliases
  return aliases~copy
::method requirements
  expose requirements
  return requirements~copy
::method slotRules
  expose slotRules
  return slotRules~copy
::method alias
  expose aliases
  use arg phrase
  aliases~append(phrase)
  return self
::method requireSlot
  expose requirements
  use arg name, prompt, explicitRequired = .true
  requirements~append(.IntentionRequirement~new(name, prompt, explicitRequired))
  return self
::method slotRule
  expose slotRules
  use arg name, markers, mode = "NEXT"
  slotRules~append(.IntentionSlotRule~new(name, markers, mode))
  return self

::requires "IntentionContext.cls"
::requires "IntentionNLP.cls"
