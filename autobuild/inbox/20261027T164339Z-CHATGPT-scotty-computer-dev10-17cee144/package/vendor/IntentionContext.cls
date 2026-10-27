/* IntentionContext.cls
 * Session implication, path learning, language/domain spheres and structured
 * observability helpers for IntentionService.
 */



::class IntentionDiscoverySnapshot public
::method init
  expose source revision evidenceFacts metadata surfaceAdvertisements
  use arg source, revision, metadata = .nil
  source = translate(strip(source))
  revision = strip(revision)
  if source == "" then raise syntax 93.900 array("Discovery snapshot source must not be empty")
  if revision == "" then raise syntax 93.900 array("Discovery snapshot revision must not be empty")
  evidenceFacts = .Array~new
  surfaceAdvertisements = .Array~new
  if metadata == .nil then metadata = .Directory~new
::attribute source get
::attribute revision get
::method addEvidenceFact
  expose evidenceFacts
  use arg fact
  if fact == .nil then return self
  if \fact~isA(.IntentionEvidenceFact) then raise syntax 93.900 array("Discovery evidence must be an IntentionEvidenceFact")
  evidenceFacts~append(fact)
  return self
::method evidenceFacts
  expose evidenceFacts
  return evidenceFacts~copy
::method addSurfaceAdvertisement
  expose surfaceAdvertisements
  use arg advertisement
  if advertisement == .nil then return self
  if \advertisement~isA(.IntentionSurfaceAdvertisement) then raise syntax 93.900 array("Discovery surface must be an IntentionSurfaceAdvertisement")
  surfaceAdvertisements~append(advertisement)
  return self
::method surfaceAdvertisements
  expose surfaceAdvertisements
  return surfaceAdvertisements~copy
::method metadata
  expose metadata
  return metadata

::class IntentionProposal public
::method init
  expose intentionId score providerName slots explicitEvidence evidence plan evidenceFacts discoveryGeneration
  use arg intentionId, score, providerName = "", explicitEvidence = .false, evidence = ""
  intentionId = translate(strip(intentionId))
  slots = .Directory~new
  plan = .nil
  evidenceFacts = .Array~new
  discoveryGeneration = 0
::attribute intentionId get
::attribute score get
::attribute providerName get
::attribute plan get
::attribute explicitEvidence get
::attribute evidence get
::method discoveryGeneration
  expose discoveryGeneration
  use arg value
  if arg(1, "O") = 0 then do
    discoveryGeneration = value
    return self
  end
  return discoveryGeneration
::method addEvidenceFact
  expose evidenceFacts
  use arg fact
  if fact == .nil then return self
  if \fact~isA(.IntentionEvidenceFact) then raise syntax 93.900 array("Proposal evidence must be an IntentionEvidenceFact")
  evidenceFacts~append(fact)
  return self
::method evidenceFacts
  expose evidenceFacts
  return evidenceFacts~copy
::method proposedPlan
  expose plan
  use arg value
  if arg(1, "O") = 0 then do
    plan = value
    return self
  end
  return plan
::method putSlot
  expose slots
  use arg name, value, explicit = .true
  slots~put(.IntentionSlotValue~new(value, explicit), translate(strip(name)))
  return self
::method slot
  expose slots
  use arg name
  key = translate(strip(name))
  if slots~hasIndex(key) = 0 then return .nil
  return slots~at(key)
::method slots
  expose slots
  return slots
::method copy
  expose intentionId score providerName slots explicitEvidence evidence plan evidenceFacts discoveryGeneration
  other = .IntentionProposal~new(intentionId, score, providerName, explicitEvidence, evidence)
  other~discoveryGeneration(discoveryGeneration)
  supplier = slots~supplier
  do while supplier~available
    slot = supplier~item
    other~putSlot(supplier~index, slot~value, slot~explicit)
    supplier~next
  end
  do i = 1 to evidenceFacts~items
    other~addEvidenceFact(evidenceFacts~at(i)~copy)
  end
  if plan \== .nil then do
    if plan~isA(.IntentionPlan) then other~proposedPlan(plan~copy)
    else other~proposedPlan(plan)
  end
  return other

/* A plan is conditional evidence attached to a proposed meaning.  It is never
 * dispatch authority.  Domain code may attach a plan directly to a proposal or
 * register a plan builder that materialises one from current canonical slots. */
::class IntentionPlan public
::method init
  expose intentionId summary sideEffectClass evidence steps requiredBindings expectedOutputs authorityRequirements metadata assessment evidenceFacts evidenceRequirements
  use arg intentionId = "", summary = ""
  intentionId = translate(strip(intentionId))
  sideEffectClass = "NONE"
  evidence = ""
  steps = .Array~new
  requiredBindings = .Array~new
  expectedOutputs = .Array~new
  authorityRequirements = .Array~new
  metadata = .Directory~new
  assessment = .nil
  evidenceFacts = .Array~new
  evidenceRequirements = .Array~new
::attribute intentionId get
::attribute summary get
::attribute summary set
::attribute sideEffectClass get
::attribute sideEffectClass set
::attribute evidence get
::attribute evidence set
::method addEvidenceFact
  expose evidenceFacts
  use arg fact
  if fact == .nil then return self
  if \fact~isA(.IntentionEvidenceFact) then raise syntax 93.900 array("Plan evidence must be an IntentionEvidenceFact")
  evidenceFacts~append(fact)
  return self
::method evidenceFacts
  expose evidenceFacts
  return evidenceFacts~copy
::method requireEvidence
  expose evidenceRequirements
  use arg subject, predicate, expectedValue = "", minConfidence = 0, minAuthority = "ADVISORY", description = "", clarificationQuestion = "", requiredSource = "", contradictionPolicy = "ALLOW", consensusCount = 1
  requirement = .IntentionEvidenceRequirement~new(subject, predicate, expectedValue, minConfidence, minAuthority, description, clarificationQuestion, requiredSource, contradictionPolicy, consensusCount)
  evidenceRequirements~append(requirement)
  return requirement
::method addEvidenceRequirement
  expose evidenceRequirements
  use arg requirement
  if requirement == .nil then return self
  if \requirement~isA(.IntentionEvidenceRequirement) then raise syntax 93.900 array("Plan evidence requirement must be an IntentionEvidenceRequirement")
  evidenceRequirements~append(requirement)
  return self
::method evidenceRequirements
  expose evidenceRequirements
  return evidenceRequirements~copy
::method addStep
  expose steps
  use arg kind, description = "", target = "", arguments = .nil
  steps~append(.IntentionPlanStep~new(kind, description, target, arguments))
  return self
::method steps
  expose steps
  return steps~copy
::method requireBinding
  expose requiredBindings
  use arg name
  requiredBindings~append(translate(strip(name)))
  return self
::method requiredBindings
  expose requiredBindings
  return requiredBindings~copy
::method expectOutput
  expose expectedOutputs
  use arg name
  expectedOutputs~append(strip(name))
  return self
::method expectedOutputs
  expose expectedOutputs
  return expectedOutputs~copy
::method requireAuthority
  expose authorityRequirements
  use arg name
  authorityRequirements~append(strip(name))
  return self
::method authorityRequirements
  expose authorityRequirements
  return authorityRequirements~copy
::method tag
  expose metadata
  use arg name, value
  metadata~put(value, translate(strip(name)))
  return self
::method removeTag
  expose metadata
  use arg name
  key = translate(strip(name))
  if metadata~hasIndex(key) then metadata~remove(key)
  return self
::method metadata
  expose metadata
  return metadata
::method assessment
  expose assessment
  use arg value
  if arg(1, "O") = 0 then do
    assessment = value
    return self
  end
  return assessment

::method appendStep
  expose steps
  use arg step
  if step == .nil then return self
  if \step~isA(.IntentionPlanStep) then raise syntax 93.900 array("Plan step must be an IntentionPlanStep")
  steps~append(step)
  return self
::method containsEquivalentStep
  expose steps
  use arg candidate
  if candidate == .nil then return .false
  do i = 1 to steps~items
    step = steps~at(i)
    if step~equivalent(candidate) then return .true
  end
  return .false
::method requireBindingUnique
  expose requiredBindings
  use arg name
  value = translate(strip(name))
  if value == "" then return self
  do i = 1 to requiredBindings~items
    if requiredBindings~at(i) == value then return self
  end
  requiredBindings~append(value)
  return self
::method expectOutputUnique
  expose expectedOutputs
  use arg name
  value = strip(name)
  if value == "" then return self
  do i = 1 to expectedOutputs~items
    if expectedOutputs~at(i) == value then return self
  end
  expectedOutputs~append(value)
  return self
::method requireAuthorityUnique
  expose authorityRequirements
  use arg name
  value = strip(name)
  if value == "" then return self
  do i = 1 to authorityRequirements~items
    if authorityRequirements~at(i) == value then return self
  end
  authorityRequirements~append(value)
  return self
::method validate
  expose steps
  validationResult = .IntentionPlanValidation~new
  ids = .Directory~new
  do i = 1 to steps~items
    step = steps~at(i)
    id = step~id
    if id == "" then iterate
    if ids~hasIndex(id) then validationResult~addProblem("duplicate step id: " || id)
    else ids~put(i, id)
  end
  do i = 1 to steps~items
    step = steps~at(i)
    deps = step~dependsOn
    do j = 1 to deps~items
      dep = deps~at(j)
      if ids~hasIndex(dep) = 0 then validationResult~addProblem("missing dependency target: " || dep)
    end
  end
  if validationResult~problems~items > 0 then return validationResult
  ordered = self~executionSteps
  if ordered == .nil then validationResult~addProblem("plan dependency cycle")
  return validationResult
::method executionSteps
  expose steps
  if steps~items == 0 then return .Array~new
  ids = .Directory~new
  indegree = .Directory~new
  outgoing = .Directory~new
  do i = 1 to steps~items
    step = steps~at(i)
    id = step~id
    if id == "" then id = "__STEP_" || i
    if ids~hasIndex(id) then return .nil
    ids~put(i, id)
    indegree~put(0, id)
    outgoing~put(.Array~new, id)
  end
  do i = 1 to steps~items
    step = steps~at(i)
    id = step~id
    if id == "" then id = "__STEP_" || i
    deps = step~dependsOn
    do j = 1 to deps~items
      dep = deps~at(j)
      if ids~hasIndex(dep) = 0 then return .nil
      indegree~put(indegree~at(id) + 1, id)
      outgoing~at(dep)~append(id)
    end
  end
  orderedSteps = .Array~new
  emitted = .Directory~new
  do while orderedSteps~items < steps~items
    progressed = .false
    do i = 1 to steps~items
      id = steps~at(i)~id
      if id == "" then id = "__STEP_" || i
      if emitted~hasIndex(id) then iterate
      if indegree~at(id) == 0 then do
        orderedSteps~append(steps~at(i))
        emitted~put(.true, id)
        children = outgoing~at(id)
        do j = 1 to children~items
          child = children~at(j)
          indegree~put(indegree~at(child) - 1, child)
        end
        progressed = .true
      end
    end
    if \progressed then return .nil
  end
  return orderedSteps

::method copy
  expose intentionId summary sideEffectClass evidence steps requiredBindings expectedOutputs authorityRequirements metadata assessment evidenceFacts evidenceRequirements
  other = .IntentionPlan~new(intentionId, summary)
  other~sideEffectClass = sideEffectClass
  other~evidence = evidence
  do i = 1 to steps~items
    otherSteps = steps~at(i)
    other~appendStep(otherSteps~copy)
  end
  do i = 1 to requiredBindings~items
    other~requireBinding(requiredBindings~at(i))
  end
  do i = 1 to expectedOutputs~items
    other~expectOutput(expectedOutputs~at(i))
  end
  do i = 1 to authorityRequirements~items
    other~requireAuthority(authorityRequirements~at(i))
  end
  do i = 1 to evidenceFacts~items
    other~addEvidenceFact(evidenceFacts~at(i)~copy)
  end
  do i = 1 to evidenceRequirements~items
    other~addEvidenceRequirement(evidenceRequirements~at(i)~copy)
  end
  supplier = metadata~supplier
  do while supplier~available
    other~tag(supplier~index, supplier~item)
    supplier~next
  end
  if assessment \== .nil then other~assessment(assessment~copy)
  return other
::method render
  expose summary steps
  text = strip(summary)
  do i = 1 to steps~items
    step = steps~at(i)
    if text \== "" then text = text || .endOfLine
    text = text || "[" || i || "] " || step~description
    if strip(step~description) == "" then text = text || step~kind
  end
  return text


/* Structured evidence is deliberately separate from hints and authority.  A fact
 * records what is claimed/observed, how confident that record is, where it came
 * from, and the evidential authority of the source. */
::class IntentionEvidenceFact public
::method init
  expose subject predicate value confidence source authority provenance observedAt metadata
  use arg subject, predicate, value, confidence = 50, source = "", authority = "ADVISORY", provenance = "", observedAt = "", metadata = .nil
  subject = translate(strip(subject))
  predicate = translate(strip(predicate))
  if subject == "" then raise syntax 93.900 array("Evidence subject must not be empty")
  if predicate == "" then raise syntax 93.900 array("Evidence predicate must not be empty")
  if \datatype(confidence, "N") then raise syntax 93.900 array("Evidence confidence must be numeric")
  if confidence < 0 then confidence = 0
  if confidence > 100 then confidence = 100
  source = strip(source)
  authority = translate(strip(authority))
  if authority == "" then authority = "ADVISORY"
  provenance = strip(provenance)
  observedAt = strip(observedAt)
  if metadata == .nil then metadata = .Directory~new
::attribute subject get
::attribute predicate get
::attribute value get
::attribute confidence get
::attribute source get
::attribute authority get
::attribute provenance get
::attribute observedAt get
::method authorityRank
  expose authority
  select
    when authority == "AUTHORITATIVE" then return 100
    when authority == "OBSERVED" then return 80
    when authority == "CONTRACT" then return 60
    when authority == "ASSERTED" then return 40
    when authority == "INFERRED" then return 20
    when authority == "ADVISORY" then return 10
    otherwise return 0
  end
::method tag
  expose metadata
  use arg name, item
  metadata~put(item, translate(strip(name)))
  return self
::method metadata
  expose metadata
  return metadata
::method copy
  expose subject predicate value confidence source authority provenance observedAt metadata
  copiedMetadata = .Directory~new
  supplier = metadata~supplier
  do while supplier~available
    copiedMetadata~put(supplier~item, supplier~index)
    supplier~next
  end
  return .IntentionEvidenceFact~new(subject, predicate, value, confidence, source, authority, provenance, observedAt, copiedMetadata)

::class IntentionEvidenceSet public
::method init
  expose allFacts
  use arg facts = .nil
  if facts == .nil then facts = .Array~new
  allFacts = facts~copy
::method all
  expose allFacts
  return allFacts~copy
::method facts
  expose allFacts
  use arg subject = "", predicate = ""
  subject = translate(strip(subject)); predicate = translate(strip(predicate))
  out = .Array~new
  do i = 1 to allFacts~items
    fact = allFacts~at(i)
    if subject \== "" then if fact~subject \== subject then iterate
    if predicate \== "" then if fact~predicate \== predicate then iterate
    out~append(fact)
  end
  return out
::method values
  use arg subject, predicate
  facts = self~facts(subject, predicate)
  seen = .Directory~new; out = .Array~new
  do i = 1 to facts~items
    key = facts~at(i)~value~string
    if seen~hasIndex(key) then iterate
    seen~put(.true, key); out~append(facts~at(i)~value)
  end
  return out
::method hasContradiction
  use arg subject, predicate
  return self~values(subject, predicate)~items > 1
::method contradictions
  expose allFacts
  grouped = .Directory~new
  order = .Array~new
  do i = 1 to allFacts~items
    fact = allFacts~at(i); key = fact~subject || "|" || fact~predicate
    if grouped~hasIndex(key) = 0 then do; grouped~put(.Array~new, key); order~append(key); end
    grouped~at(key)~append(fact)
  end
  out = .Array~new
  do i = 1 to order~items
    group = grouped~at(order~at(i)); values = .Directory~new
    do j = 1 to group~items; values~put(.true, group~at(j)~value~string); end
    if values~items > 1 then out~append(.IntentionEvidenceContradiction~new(group))
  end
  return out

::class IntentionEvidenceContradiction public
::method init
  expose facts
  use arg facts
::method facts
  expose facts
  return facts~copy
::method subject
  expose facts
  if facts~items = 0 then return ""
  return facts~at(1)~subject
::method predicate
  expose facts
  if facts~items = 0 then return ""
  return facts~at(1)~predicate

/* A requirement is a feasibility predicate over evidence.  Empty expectedValue
 * means any value for subject/predicate is acceptable.  Confidence and evidence
 * authority are independent thresholds. */
::class IntentionEvidenceRequirement public
::method init
  expose subject predicate expectedValue minConfidence minAuthority description clarificationQuestion requiredSource contradictionPolicy consensusCount
  use arg subject, predicate, expectedValue = "", minConfidence = 0, minAuthority = "ADVISORY", description = "", clarificationQuestion = "", requiredSource = "", contradictionPolicy = "ALLOW", consensusCount = 1
  subject = translate(strip(subject))
  predicate = translate(strip(predicate))
  if subject == "" then raise syntax 93.900 array("Evidence requirement subject must not be empty")
  if predicate == "" then raise syntax 93.900 array("Evidence requirement predicate must not be empty")
  if \datatype(minConfidence, "N") then raise syntax 93.900 array("Evidence minimum confidence must be numeric")
  if minConfidence < 0 then minConfidence = 0
  if minConfidence > 100 then minConfidence = 100
  minAuthority = translate(strip(minAuthority))
  if minAuthority == "" then minAuthority = "ADVISORY"
  description = strip(description)
  clarificationQuestion = strip(clarificationQuestion)
  requiredSource = strip(requiredSource)
  contradictionPolicy = translate(strip(contradictionPolicy))
  if contradictionPolicy == "" then contradictionPolicy = "ALLOW"
  if contradictionPolicy \== "ALLOW" then do
    if contradictionPolicy \== "NO_CONTRADICTION" then raise syntax 93.900 array("Evidence contradiction policy must be ALLOW or NO_CONTRADICTION")
  end
  if \datatype(consensusCount, "W") then consensusCount = 1
  if consensusCount < 1 then consensusCount = 1
::attribute subject get
::attribute predicate get
::attribute expectedValue get
::attribute minConfidence get
::attribute minAuthority get
::attribute description get
::attribute clarificationQuestion get
::attribute requiredSource get
::attribute contradictionPolicy get
::attribute consensusCount get
::method minimumAuthorityRank private
  expose minAuthority
  select
    when minAuthority == "AUTHORITATIVE" then return 100
    when minAuthority == "OBSERVED" then return 80
    when minAuthority == "CONTRACT" then return 60
    when minAuthority == "ASSERTED" then return 40
    when minAuthority == "INFERRED" then return 20
    when minAuthority == "ADVISORY" then return 10
    otherwise return 0
  end
::method satisfiedBy
  use arg facts
  return self~satisfiedBySet(.IntentionEvidenceSet~new(facts))
::method satisfiedBySet
  expose subject predicate expectedValue minConfidence requiredSource contradictionPolicy consensusCount
  use arg evidenceSet
  if evidenceSet == .nil then return .false
  facts = evidenceSet~facts(subject, predicate)
  requiredAuthority = self~minimumAuthorityRank
  accepted = 0
  do i = 1 to facts~items
    fact = facts~at(i)
    if expectedValue \== "" then do
      if fact~value \== expectedValue then iterate
    end
    if requiredSource \== "" then do
      if translate(fact~source) \== translate(requiredSource) then iterate
    end
    if fact~confidence < minConfidence then iterate
    if fact~authorityRank < requiredAuthority then iterate
    accepted = accepted + 1
  end
  if accepted < consensusCount then return .false
  if contradictionPolicy == "NO_CONTRADICTION" then do
    if evidenceSet~hasContradiction(subject, predicate) then return .false
  end
  return .true
::method describe
  expose subject predicate expectedValue minConfidence minAuthority description requiredSource contradictionPolicy consensusCount
  if description \== "" then return description
  text = "evidence required: " || subject || " " || predicate
  if expectedValue \== "" then text = text || "=" || expectedValue
  text = text || " confidence>=" || minConfidence || " authority>=" || minAuthority
  if requiredSource \== "" then text = text || " source=" || requiredSource
  if consensusCount > 1 then text = text || " consensus>=" || consensusCount
  if contradictionPolicy == "NO_CONTRADICTION" then text = text || " no-contradiction"
  return text
::method copy
  expose subject predicate expectedValue minConfidence minAuthority description clarificationQuestion requiredSource contradictionPolicy consensusCount
  return .IntentionEvidenceRequirement~new(subject, predicate, expectedValue, minConfidence, minAuthority, description, clarificationQuestion, requiredSource, contradictionPolicy, consensusCount)

/* A plan assessment states whether the proposed plan is presently feasible under
 * evidence supplied by the application/domain.  It is not execution authority.
 * Required authorities listed on IntentionPlan are requirements, not evidence that
 * the caller currently holds them.  A domain assessor must report missing authority
 * explicitly when that fact is known. */
::class IntentionPlanAssessment public
::method init
  expose status reason missingBindings unavailableResources missingAuthority violatedPreconditions evidence metadata clarificationQuestion
  use arg status = "UNKNOWN", reason = ""
  status = translate(strip(status))
  if status == "" then status = "UNKNOWN"
  if status \== "UNKNOWN" then do
    if status \== "FEASIBLE" then do
      if status \== "INFEASIBLE" then raise syntax 93.900 array("Plan assessment status must be UNKNOWN, FEASIBLE or INFEASIBLE")
    end
  end
  reason = strip(reason)
  missingBindings = .Array~new
  unavailableResources = .Array~new
  missingAuthority = .Array~new
  violatedPreconditions = .Array~new
  evidence = .Array~new
  metadata = .Directory~new
  clarificationQuestion = ""
::attribute status get
::attribute reason get
::method requestClarification
  expose clarificationQuestion
  use arg question
  clarificationQuestion = strip(question)
  return self
::attribute clarificationQuestion get
::method needsClarification
  expose clarificationQuestion
  return clarificationQuestion \== ""
::method feasible
  expose status
  return status == "FEASIBLE"
::method known
  expose status
  return status \== "UNKNOWN"
::method markFeasible
  expose status reason
  use arg newReason = ""
  status = "FEASIBLE"
  reason = strip(newReason)
  return self~normalise
::method markUnknown
  expose status reason
  use arg newReason = ""
  status = "UNKNOWN"
  reason = strip(newReason)
  return self~normalise
::method markInfeasible
  expose status reason
  use arg newReason = ""
  status = "INFEASIBLE"
  reason = strip(newReason)
  return self
::method addMissingBinding
  expose missingBindings
  use arg name
  value = translate(strip(name))
  if value \== "" then missingBindings~append(value)
  return self~normalise
::method missingBindings
  expose missingBindings
  return missingBindings~copy
::method addUnavailableResource
  expose unavailableResources
  use arg resource
  value = strip(resource)
  if value \== "" then unavailableResources~append(value)
  return self~normalise
::method unavailableResources
  expose unavailableResources
  return unavailableResources~copy
::method addMissingAuthority
  expose missingAuthority
  use arg authority
  value = strip(authority)
  if value \== "" then missingAuthority~append(value)
  return self~normalise
::method missingAuthority
  expose missingAuthority
  return missingAuthority~copy
::method addViolatedPrecondition
  expose violatedPreconditions
  use arg precondition
  value = strip(precondition)
  if value \== "" then violatedPreconditions~append(value)
  return self~normalise
::method violatedPreconditions
  expose violatedPreconditions
  return violatedPreconditions~copy
::method addEvidence
  expose evidence
  use arg item
  value = strip(item)
  if value \== "" then evidence~append(value)
  return self
::method evidence
  expose evidence
  return evidence~copy
::method tag
  expose metadata
  use arg name, value
  metadata~put(value, translate(strip(name)))
  return self
::method metadata
  expose metadata
  return metadata
::method blockerCount
  expose missingBindings unavailableResources missingAuthority violatedPreconditions
  return missingBindings~items + unavailableResources~items + missingAuthority~items + violatedPreconditions~items
::method normalise
  expose status
  if self~blockerCount > 0 then status = "INFEASIBLE"
  return self
::method copy
  expose status reason missingBindings unavailableResources missingAuthority violatedPreconditions evidence metadata clarificationQuestion
  other = .IntentionPlanAssessment~new(status, reason)
  do i = 1 to missingBindings~items
    other~addMissingBinding(missingBindings~at(i))
  end
  do i = 1 to unavailableResources~items
    other~addUnavailableResource(unavailableResources~at(i))
  end
  do i = 1 to missingAuthority~items
    other~addMissingAuthority(missingAuthority~at(i))
  end
  do i = 1 to violatedPreconditions~items
    other~addViolatedPrecondition(violatedPreconditions~at(i))
  end
  do i = 1 to evidence~items
    other~addEvidence(evidence~at(i))
  end
  supplier = metadata~supplier
  do while supplier~available
    other~tag(supplier~index, supplier~item)
    supplier~next
  end
  if clarificationQuestion \== "" then other~requestClarification(clarificationQuestion)
  return other~normalise

::class IntentionPlanStep public
::method init
  expose kind description target arguments id dependencies metadata
  use arg kind, description = "", target = "", arguments = .nil
  kind = translate(strip(kind))
  description = strip(description)
  target = strip(target)
  if arguments == .nil then arguments = .Directory~new
  id = ""
  dependencies = .Array~new
  metadata = .Directory~new
::attribute kind get
::attribute description get
::attribute target get
::attribute arguments get
::method id
  expose id
  use arg value
  if arg(1, "O") = 0 then do
    id = translate(strip(value))
    return self
  end
  return id
::method dependsOn
  expose dependencies
  use arg stepId
  if arg(1, "O") = 0 then do
    value = translate(strip(stepId))
    if value \== "" then dependencies~append(value)
    return self
  end
  return dependencies~copy
::method tag
  expose metadata
  use arg name, value
  metadata~put(value, translate(strip(name)))
  return self
::method metadata
  expose metadata
  return metadata
::method equivalent
  expose kind description target
  use arg other
  if other == .nil then return .false
  if kind \== other~kind then return .false
  if target \== other~target then return .false
  return description == other~description
::method copy
  expose kind description target arguments id dependencies metadata
  other = .IntentionPlanStep~new(kind, description, target, arguments)
  if id \== "" then other~id(id)
  do i = 1 to dependencies~items
    other~dependsOn(dependencies~at(i))
  end
  supplier = metadata~supplier
  do while supplier~available
    other~tag(supplier~index, supplier~item)
    supplier~next
  end
  return other

::class IntentionPlanValidation public
::method init
  expose problems
  problems = .Array~new
::method addProblem
  expose problems
  use arg problem
  value = strip(problem)
  if value \== "" then problems~append(value)
  return self
::method problems
  expose problems
  return problems~copy
::method valid
  expose problems
  return problems~items == 0


/* Hint libraries provide bounded, advisory recognition and planning evidence.
 * They never grant authority and never replace bucket policy or domain planning. */
::class IntentionHintLibrary public
::method init
  expose name hints
  use arg name = "DEFAULT"
  name = translate(strip(name))
  if name == "" then name = "DEFAULT"
  hints = .Array~new
::attribute name get
::method add
  expose hints
  use arg hint
  if hint == .nil then raise syntax 93.900 array("Intention hint must not be NIL")
  if \hint~isA(.IntentionHint) then raise syntax 93.900 array("Hint must be an IntentionHint")
  hints~append(hint)
  return hint
::method hint
  expose hints
  use arg intentionId
  hint = .IntentionHint~new(intentionId)
  hints~append(hint)
  return hint
::method hints
  expose hints
  return hints~copy
::method matches
  expose hints
  use arg text, sphereName = ""
  out = .Array~new
  do i = 1 to hints~items
    match = hints~at(i)~match(text, sphereName)
    if match \== .nil then out~append(match)
  end
  return out

::class IntentionHint public
::method init
  expose intentionId phraseHints plan sphereName evidence planOnly
  use arg intentionId
  intentionId = translate(strip(intentionId))
  if intentionId == "" then raise syntax 93.900 array("Hint intention id must not be empty")
  phraseHints = .Array~new
  plan = .nil
  sphereName = ""
  evidence = ""
  planOnly = .false
::attribute intentionId get
::method sphere
  expose sphereName
  use arg value
  if arg(1, "O") = 0 then do
    sphereName = translate(strip(value))
    return self
  end
  return sphereName
::method evidence
  expose evidence
  use arg value
  if arg(1, "O") = 0 then do
    evidence = strip(value)
    return self
  end
  return evidence
::method phrase
  expose phraseHints
  use arg pattern, mode = "CONTAINS", weight = 5
  phraseHints~append(.IntentionPhraseHint~new(pattern, mode, weight))
  return self
::method plan
  expose plan
  use arg value
  if arg(1, "O") = 0 then do
    if value \== .nil then do
      if \value~isA(.IntentionPlan) then raise syntax 93.900 array("Hint plan must be an IntentionPlan")
    end
    plan = value
    return self
  end
  return plan
::method planAlways
  expose planOnly
  use arg value = .true
  planOnly = value
  return self
::method planApplicable
  expose planOnly
  use arg phraseMatched
  return planOnly | phraseMatched
::method match
  expose phraseHints sphereName evidence
  use arg text, activeSphere = ""
  if sphereName \== "" then do
    if translate(strip(activeSphere)) \== sphereName then return .nil
  end
  if phraseHints~items == 0 then return .IntentionHintMatch~new(self, .false, 0, evidence)
  bestWeight = -1
  matchedEvidence = evidence
  do i = 1 to phraseHints~items
    phraseHint = phraseHints~at(i)
    if phraseHint~matches(text) then do
      if phraseHint~weight > bestWeight then do
        bestWeight = phraseHint~weight
        matchedEvidence = "phrase hint: " || phraseHint~pattern
        if evidence \== "" then matchedEvidence = matchedEvidence || "; " || evidence
      end
    end
  end
  if bestWeight < 0 then return .nil
  return .IntentionHintMatch~new(self, .true, bestWeight, matchedEvidence)

::class IntentionPhraseHint public
::method init
  expose pattern mode weight
  use arg pattern, mode = "CONTAINS", weight = 5
  pattern = strip(pattern)
  mode = translate(strip(mode))
  if pattern == "" then raise syntax 93.900 array("Hint phrase must not be empty")
  if mode \== "CONTAINS" then do
    if mode \== "EXACT" then raise syntax 93.900 array("Hint phrase mode must be CONTAINS or EXACT")
  end
  if \datatype(weight, "W") then raise syntax 93.900 array("Hint weight must be a whole number")
  if weight < 0 then weight = 0
  if weight > 25 then weight = 25
::attribute pattern get
::attribute mode get
::attribute weight get
::method matches
  expose pattern mode
  use arg text
  candidate = translate(strip(text))
  wanted = translate(pattern)
  if mode == "EXACT" then return candidate == wanted
  return pos(wanted, candidate) > 0

::class IntentionHintMatch public
::method init
  expose hint phraseMatched phraseWeight evidence
  use arg hint, phraseMatched = .false, phraseWeight = 0, evidence = ""
::attribute hint get
::attribute phraseMatched get
::attribute phraseWeight get
::attribute evidence get

::class IntentionSlotValue public
::method init
  expose value explicit
  use arg value, explicit = .true
::attribute value get
::attribute explicit get


::class IntentionSlotResolutionCandidate public
::method init
  expose label bindings score evidence
  use arg label = "", score = 100, evidence = ""
  bindings = .Directory~new
::attribute label get
::attribute score get
::attribute evidence get
::method putBinding
  expose bindings
  use arg name, value, explicit = .true
  bindings~put(.IntentionSlotValue~new(value, explicit), translate(strip(name)))
  return self
::method bindings
  expose bindings
  return bindings

::class IntentionSlotResolution public
::method init
  expose candidates question
  use arg candidates = .nil, question = ""
  if candidates == .nil then candidates = .Array~new
::attribute question get
::method candidates
  expose candidates
  return candidates~copy
::method none class
  use arg question = ""
  return self~new(.Array~new, question)
::method one class
  use arg candidate
  return self~new(.Array~of(candidate), "")
::method many class
  use arg candidates, question = ""
  return self~new(candidates, question)

::class IntentionHistoryEntry public
::method init
  expose intentionId phrase input slots providerName plan
  use arg intentionId, phrase, input, slots, providerName = "", plan = .nil
  if slots == .nil then slots = .Directory~new
::attribute intentionId get
::attribute phrase get
::attribute input get
::attribute slots get
::attribute providerName get
::attribute plan get

::class IntentionPlanTransformation public
::method init
  expose operations score evidence
  use arg score = 96, evidence = ""
  operations = .Array~new
::attribute score get
::attribute evidence get
::method operationCount
  expose operations
  return operations~items
::method setSlot
  expose operations
  use arg name, value, explicit = .true
  operations~append(.IntentionPlanTransformationOperation~new("SET_SLOT", name, value, explicit))
  return self
::method setPlanTag
  expose operations
  use arg name, value
  operations~append(.IntentionPlanTransformationOperation~new("SET_PLAN_TAG", name, value, .true))
  return self
::method removePlanTag
  expose operations
  use arg name
  operations~append(.IntentionPlanTransformationOperation~new("REMOVE_PLAN_TAG", name, "", .true))
  return self
::method setSummary
  expose operations
  use arg value
  operations~append(.IntentionPlanTransformationOperation~new("SET_SUMMARY", "", value, .true))
  return self
::method appendStep
  expose operations
  use arg step
  operations~append(.IntentionPlanTransformationOperation~new("APPEND_STEP", "", step, .true))
  return self
::method apply
  expose operations
  use arg proposal
  if proposal == .nil then return proposal
  plan = proposal~proposedPlan
  do i = 1 to operations~items
    op = operations~at(i)
    select
      when op~kind == "SET_SLOT" then proposal~putSlot(op~key, op~value, op~explicit)
      when op~kind == "SET_PLAN_TAG" then if plan \== .nil then plan~tag(op~key, op~value)
      when op~kind == "REMOVE_PLAN_TAG" then if plan \== .nil then plan~removeTag(op~key)
      when op~kind == "SET_SUMMARY" then if plan \== .nil then plan~summary = op~value
      when op~kind == "APPEND_STEP" then if plan \== .nil then plan~appendStep(op~value~copy)
      otherwise raise syntax 93.900 array("Unknown plan transformation operation: " || op~kind)
    end
  end
  return proposal

::class IntentionPlanTransformationOperation public
::method init
  expose kind key value explicit
  use arg kind, key = "", value = "", explicit = .true
  kind = translate(strip(kind)); key = translate(strip(key))
::attribute kind get
::attribute key get
::attribute value get
::attribute explicit get

::class IntentionSurfaceAdvertisement public
::method init
  expose surfaceId provider sourceObject relationship scope lifetime authority generation metadata
  use arg surfaceId, provider, sourceObject = "", relationship = "", scope = "", lifetime = "DISCOVERY", authority = "ADVISORY", metadata = .nil
  surfaceId = translate(strip(surfaceId))
  if surfaceId == "" then raise syntax 93.900 array("Intention surface id must not be empty")
  if provider == .nil then raise syntax 93.900 array("Intention surface provider must not be NIL")
  relationship = translate(strip(relationship)); lifetime = translate(strip(lifetime)); authority = translate(strip(authority))
  if lifetime == "" then lifetime = "DISCOVERY"
  generation = 0
  if metadata == .nil then metadata = .Directory~new
::attribute surfaceId get
::attribute provider get
::attribute sourceObject get
::attribute relationship get
::attribute scope get
::attribute lifetime get
::attribute authority get
::method discoveryGeneration
  expose generation
  use arg value
  if arg(1, "O") = 0 then do; generation = value; return self; end
  return generation
::method metadata
  expose metadata
  return metadata
::method propose
  expose provider
  use arg service, text
  return provider~propose(service, text)
::method copy
  expose surfaceId provider sourceObject relationship scope lifetime authority generation metadata
  copied = .IntentionSurfaceAdvertisement~new(surfaceId, provider, sourceObject, relationship, scope, lifetime, authority, metadata)
  copied~discoveryGeneration(generation)
  return copied

::class IntentionPathLearner public
::method init
  expose episodes minPrefix
  episodes = .Array~new
  minPrefix = 2
::attribute minPrefix get
::attribute minPrefix set
::method episodes
  expose episodes
  return episodes~copy
::method learn
  expose episodes
  use arg intentionIds
  if intentionIds == .nil then return self
  if intentionIds~items < 2 then return self
  copy = .Array~new
  do i = 1 to intentionIds~items
    copy~append(translate(strip(intentionIds~at(i))))
  end
  episodes~append(copy)
  return self
::method predict
  expose episodes minPrefix
  use arg currentPath
  predictions = .Directory~new
  if currentPath == .nil then return .Array~new
  if currentPath~items < minPrefix then return .Array~new

  do episodeIndex = 1 to episodes~items
    episode = episodes~at(episodeIndex)
    maxPrefix = min(currentPath~items, episode~items - 1)
    do prefixLength = maxPrefix to minPrefix by -1
      if self~suffixMatchesPrefix(currentPath, episode, prefixLength) then do
        nextId = episode~at(prefixLength + 1)
        key = prefixLength || "|" || nextId
        count = 0
        if predictions~hasIndex(key) then count = predictions~at(key)
        predictions~put(count + 1, key)
        leave
      end
    end
  end

  rows = .Array~new
  supplier = predictions~supplier
  do while supplier~available
    predictionKey = supplier~index
    parse var predictionKey prefixText '|' intentionId
    rows~append(.IntentionPathPrediction~new(intentionId, prefixText, supplier~item))
    supplier~next
  end
  return rows

::method suffixMatchesPrefix
  use arg currentPath, episode, lengthWanted
  if lengthWanted <= 0 then return .false
  currentStart = currentPath~items - lengthWanted + 1
  do offset = 0 to lengthWanted - 1
    leftId = translate(strip(currentPath~at(currentStart + offset)))
    rightId = translate(strip(episode~at(offset + 1)))
    if leftId \== rightId then return .false
  end
  return .true

::class IntentionPathPrediction public
::method init
  expose intentionId prefixLength support
  use arg intentionId, prefixLength, support
::attribute intentionId get
::attribute prefixLength get
::attribute support get
::method score
  expose prefixLength support
  value = 50 + prefixLength * 10 + (support - 1) * 5
  if value > 95 then value = 95
  return value

::class IntentionSphere public
::method init
  expose name spec interrogator aliases
  use arg name, spec, interrogator
  name = translate(strip(name))
  aliases = .Array~new
  aliases~append(name)
::attribute name get
::attribute spec get
::attribute interrogator get
::method alias
  expose aliases
  use arg value
  value = translate(strip(value))
  if value \== "" then aliases~append(value)
  return self
::method aliases
  expose aliases
  return aliases~copy
::method matches
  expose aliases
  use arg value
  value = translate(strip(value))
  do i = 1 to aliases~items
    if value == aliases~at(i) then return .true
  end
  return .false

::class IntentionSituation public
::method init
  expose input body sphere spec records history registrations
  use arg input, body, sphere, spec, records, history, registrations
  if records == .nil then records = .Array~new
  if history == .nil then history = .Array~new
::attribute input get
::attribute body get
::attribute sphere get
::attribute spec get
::attribute records get
::attribute history get
::attribute registrations get

::class IntentionInterrogationResult public
::method init
  expose proposals purpose evidence
  use arg proposals = .nil, purpose = "", evidence = ""
  if proposals == .nil then proposals = .Array~new
::attribute proposals get
::attribute purpose get
::attribute evidence get

::class ImpliedIntentionProvider public
::method name
  return "IMPLIED_SESSION"
::method propose
  use arg service, text
  normalized = translate(strip(text))
  if normalized \== "DO IT AGAIN" then do
    if normalized \== "AGAIN" then do
      if normalized \== "SAME AGAIN" then return .Array~new
    end
  end
  previous = service~lastHistoryEntry
  if previous == .nil then return .Array~new
  proposal = .IntentionProposal~new(previous~intentionId, 99, self~name, .false, "session intention stack")
  slots = previous~slots
  supplier = slots~supplier
  do while supplier~available
    slot = supplier~item
    proposal~putSlot(supplier~index, slot~value, slot~explicit)
    supplier~next
  end
  return .Array~of(proposal)

::class PathLearningIntentionProvider public
::method name
  return "PATH_LEARNER"
::method propose
  use arg service, text
  predictions = service~pathLearner~predict(service~currentPath)
  if predictions~items = 0 then return .Array~new
  out = .Array~new
  do i = 1 to predictions~items
    prediction = predictions~at(i)
    registration = service~registration(prediction~intentionId)
    if registration == .nil then iterate
    evidence = "matched_prefix=" || prediction~prefixLength || ";support=" || prediction~support
    out~append(.IntentionProposal~new(prediction~intentionId, prediction~score, self~name, .false, evidence))
  end
  return out
