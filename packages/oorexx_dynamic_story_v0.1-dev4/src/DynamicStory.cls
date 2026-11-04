/* Dynamic Story 0.1-dev4 -- transport-neutral runtime narrative selection.
 * A story is a candidate until the host-supplied authority gateway reviews the
 * exact request, intention revision, narrative revision and claims. This file
 * never creates publication permission or treats Brand evidence as permission.
 */
::class 'StoryContext' public
::method init
  expose tenantId country channel locale requestId
  use strict arg tenantId, country, channel, locale, requestId
  if tenantId == '' | country == '' | channel == '' | requestId == '' then -
    raise syntax 93.900 array ('context requires tenant, country, channel, request id')
::attribute tenantId get
::attribute country get
::attribute channel get
::attribute locale get
::attribute requestId get

::class 'StoryIntention' public
::method init
  expose identifier priority objective revision
  use strict arg identifier, priority, objective, revision
  if identifier == '' | objective == '' | revision == '' then -
    raise syntax 93.900 array ('intention id/objective/revision required')
  if \datatype(priority, 'W') then raise syntax 93.900 array ('priority must be integer')
::attribute identifier get
::attribute priority get
::attribute objective get
::attribute revision get

::class 'StoryNarrative' public
::method init
  expose identifier intentionId headline body action claimIds revision
  use strict arg identifier, intentionId, headline, body, action, requiredClaims, revision
  if identifier == '' | intentionId == '' | revision == '' then -
    raise syntax 93.900 array ('narrative id/intention/revision required')
  if \requiredClaims~isA(.Array) then raise syntax 93.900 array ('claims must be an Array')
  claimIds = .Array~new
  seenClaims = .Directory~new
  do claim over requiredClaims
    if claim~string~strip == '' then raise syntax 93.900 array ('empty claim id')
    if seenClaims~hasIndex(claim) then raise syntax 93.900 array ('duplicate claim id')
    seenClaims[claim] = 1
    claimIds~append(claim)
  end
::attribute identifier get
::attribute intentionId get
::attribute headline get
::attribute body get
::attribute action get
::attribute revision get
::method claimIds
  expose claimIds
  result = .Array~new
  do claim over claimIds
    result~append(claim)
  end
  return result

/* A binding gives a narrative an explicit market/channel and relative rank.
 * Wildcards are deliberate; a country or locale is not proof of user intent.
 */
::class 'StoryNarrativeBinding' public
::method init
  expose narrative country channel rank
  use strict arg narrative, country, channel, rank
  if \narrative~isA(.StoryNarrative) then raise syntax 93.900 array ('narrative required')
  if country == '' | channel == '' | \datatype(rank, 'W') then -
    raise syntax 93.900 array ('invalid narrative binding')
::attribute narrative get
::attribute country get
::attribute channel get
::attribute rank get
::method matches
  expose country channel
  use strict arg context
  if country \== '*' & country \== context~country then return .false
  if channel \== '*' & channel \== context~channel then return .false
  return .true

/* Only the injected, trusted host gateway may produce an ALLOW review.
 * The result is a response to one review call, not a transferable credential.
 */
/* A host decision about one exact request and reviewed claims, not a token. */
::class 'StoryAuthorityResult' public
::method init
  expose status proofRef policyRevision policySelectionRef intentionId intentionRevision narrativeId narrativeRevision reason tenantId requestId country channel locale reviewedClaims catalogueRevision
  use strict arg status, proofRef, policyRevision, policySelectionRef, intentionId, intentionRevision, narrativeId, narrativeRevision, reason, tenantId, requestId, country, channel, locale, claims, catalogueRevision
  if status \== 'ALLOW' & status \== 'DENY' & status \== 'HOLD' & status \== 'STALE' then -
    raise syntax 93.900 array ('unknown authority status')
  if \claims~isA(.Array) then raise syntax 93.900 array ('reviewed claims must be Array')
  reviewedClaims = .Array~new
  do claim over claims
    reviewedClaims~append(claim)
  end
::attribute status get
::attribute proofRef get
::attribute policyRevision get
::attribute policySelectionRef get
::attribute intentionId get
::attribute intentionRevision get
::attribute narrativeId get
::attribute narrativeRevision get
::attribute reason get
::attribute tenantId get
::attribute requestId get
::attribute country get
::attribute channel get
::attribute locale get
::attribute catalogueRevision get
::method reviewedClaimIds
  expose reviewedClaims
  copy = .Array~new
  do claim over reviewedClaims
    copy~append(claim)
  end
  return copy

/* A detached host catalogue snapshot: its status is not a publication grant.
 * Caller must obtain a fresh snapshot for every decideLive request. Any
 * explicit HOLD must stop selection without exposing content.
 */
::class 'StoryCatalogueSnapshot' public
::method init
  expose revision status intentions bindings
  use strict arg revision, status, suppliedIntentions, suppliedBindings
  if revision~string~strip == '' then raise syntax 93.900 array ('catalogue revision required')
  if status \== 'ACTIVE' & status \== 'HOLD' then raise syntax 93.900 array ('catalogue status invalid')
  if \suppliedIntentions~isA(.Array) | \suppliedBindings~isA(.Array) then -
    raise syntax 93.900 array ('catalogue arrays required')
  intentions = .Directory~new
  do item over suppliedIntentions
    if \item~isA(.StoryIntention) then raise syntax 93.900 array ('invalid catalogue intention')
    if intentions~hasIndex(item~identifier) then raise syntax 93.900 array ('duplicate catalogue intention')
    intentions[item~identifier] = item
  end
  bindings = .Array~new
  do item over suppliedBindings
    if \item~isA(.StoryNarrativeBinding) then raise syntax 93.900 array ('invalid catalogue binding')
    if \intentions~hasIndex(item~narrative~intentionId) then -
      raise syntax 93.900 array ('binding references unknown intention')
    bindings~append(item)
  end
::attribute revision get
::attribute status get
::method intentionIndex
  expose intentions
  result = .Directory~new
  do key over intentions~allIndexes
    result[key] = intentions[key]
  end
  return result
::method narrativeBindings
  expose bindings
  result = .Array~new
  do binding over bindings
    result~append(binding)
  end
  return result

::class 'StoryDecisionEngine' public
::method init
  expose intentions bindings authorityGateway intentionSource catalogueSource
  catalogueSource = .nil
  intentions = .Directory~new
  bindings = .Array~new
  authorityGateway = .nil
  intentionSource = .nil
::method registerIntention
  expose intentions
  use strict arg intention
  if \intention~isA(.StoryIntention) then raise syntax 93.900 array ('expected StoryIntention')
  intentions[intention~identifier] = intention
::method registerNarrative
  use strict arg narrative
  self~registerScopedNarrative(narrative, '*', '*', 0)
::method registerScopedNarrative
  expose bindings
  use strict arg narrative, country, channel, rank
  bindings~append(.StoryNarrativeBinding~new(narrative, country, channel, rank))
::method setAuthorityGateway
  expose authorityGateway
  use strict arg gateway
  if gateway == .nil then raise syntax 93.900 array ('authority gateway required')
  if \gateway~hasMethod('REVIEW') then raise syntax 93.900 array ('gateway must implement review')
  authorityGateway = gateway
::method setCatalogueSource
  expose catalogueSource
  use strict arg source
  if source == .nil then raise syntax 93.900 array ('catalogue source required')
  if \source~hasMethod('SNAPSHOT') then raise syntax 93.900 array ('source must implement snapshot')
  catalogueSource = source
::method setIntentionSource
  expose intentionSource
  use strict arg source
  if source == .nil then raise syntax 93.900 array ('intention source required')
  if \source~hasMethod('CANDIDATES') then raise syntax 93.900 array ('source must implement candidates')
  intentionSource = source
::method decideLive
  expose intentionSource catalogueSource intentions bindings
  use strict arg context
  if \context~isA(.StoryContext) then raise syntax 93.900 array ('StoryContext required')
  if intentionSource == .nil then return self~blocked('BLOCKED_NO_INTENTION_SOURCE', context)
  if catalogueSource == .nil then return self~blocked('BLOCKED_NO_CATALOGUE_SOURCE', context)
  snapshot = catalogueSource~snapshot(context)
  if snapshot == .nil then return self~blocked('BLOCKED_NO_CATALOGUE_SNAPSHOT', context)
  if \snapshot~isA(.StoryCatalogueSnapshot) then return self~blocked('BLOCKED_INVALID_CATALOGUE_SNAPSHOT', context)
  if snapshot~status \== 'ACTIVE' then return self~blocked('BLOCKED_CATALOGUE_HOLD', context)
  candidates = intentionSource~candidates(context)
  if \candidates~isA(.Array) then return self~blocked('BLOCKED_INVALID_INTENTION_SOURCE', context)
  return self~selectCandidates(candidates, context, snapshot~intentionIndex, snapshot~narrativeBindings, snapshot~revision)
::method blocked private
  use strict arg status, context
  output = .Directory~new
  output['schema'] = 'alchemy.dynamic_story.decision.v1'
  output['status'] = status
  output['tenant_id'] = context~tenantId
  output['request_id'] = context~requestId
  output['publication_authority'] = 'NONE'
  output['dispatch_authority'] = 'NONE'
  return output
/* Legacy local registration remains a test/development surface only.
 * Live operation MUST call decideLive with fresh host catalogue + intentions.
 */
::method decide
  expose intentions bindings
  use strict arg candidateIds, context
  return self~selectCandidates(candidateIds, context, intentions, bindings, 'LOCAL-UNVERSIONED')
::method selectCandidates private
  expose authorityGateway
  use strict arg candidateIds, context, intentions, bindings, catalogueRevision
  if \context~isA(.StoryContext) then raise syntax 93.900 array ('StoryContext required')
  if \candidateIds~isA(.Array) then raise syntax 93.900 array ('candidate Array required')
  if authorityGateway == .nil then return self~blocked('BLOCKED_NO_AUTHORITY', context)
  selected = .nil
  ambiguous = .false
  seen = .Directory~new
  do id over candidateIds
    if seen~hasIndex(id) then iterate
    seen[id] = 1
    candidate = intentions~at(id)
    if candidate == .nil then iterate
    if selected == .nil then do
      selected = candidate
      ambiguous = .false
    end
    else if candidate~priority > selected~priority then do
      selected = candidate
      ambiguous = .false
    end
    else if candidate~priority = selected~priority then ambiguous = .true
  end
  if selected == .nil then return self~blocked('NO_ELIGIBLE_INTENTION', context)
  if ambiguous then return self~blocked('BLOCKED_AMBIGUOUS_INTENTION', context)
  chosen = .nil
  rank = 0
  ambiguous = .false
  do binding over bindings
    candidate = binding~narrative
    if candidate~intentionId \== selected~identifier then iterate
    if \binding~matches(context) then iterate
    if chosen == .nil then do
      chosen = candidate
      rank = binding~rank
      ambiguous = .false
    end
    else if binding~rank > rank then do
      chosen = candidate
      rank = binding~rank
      ambiguous = .false
    end
    else if binding~rank = rank then ambiguous = .true
  end
  if chosen == .nil then return self~blocked('NO_MATCHING_NARRATIVE', context)
  if ambiguous then return self~blocked('BLOCKED_AMBIGUOUS_NARRATIVE', context)
  /* REVIEW must check live activation, tenant, consent, claim and asset status,
   * revision consistency, withdrawal and current operative Institutional Policy.
   */
  review = authorityGateway~review(context, selected, chosen, catalogueRevision)
  if review == .nil then return self~blocked('BLOCKED_INVALID_AUTHORITY', context)
  if \review~isA(.StoryAuthorityResult) then return self~blocked('BLOCKED_INVALID_AUTHORITY', context)
  if review~status \== 'ALLOW' then do
    result = self~blocked('BLOCKED_' || review~status, context)
    result['reason'] = review~reason
    return result
  end
  if review~proofRef~string~strip == '' | review~policyRevision~string~strip == '' | -
     review~policySelectionRef~string~strip == '' then -
    return self~blocked('BLOCKED_MISSING_AUTHORITY_PROOF', context)
  if review~catalogueRevision \== catalogueRevision then -
    return self~blocked('BLOCKED_AUTHORITY_CATALOGUE_MISMATCH', context)
  if review~tenantId \== context~tenantId | review~requestId \== context~requestId | -
     review~country \== context~country | review~channel \== context~channel | -
     review~locale \== context~locale then -
    return self~blocked('BLOCKED_AUTHORITY_CONTEXT_MISMATCH', context)
  if review~intentionId \== selected~identifier | -
     review~intentionRevision \== selected~revision | -
     review~narrativeId \== chosen~identifier | -
     review~narrativeRevision \== chosen~revision then -
    return self~blocked('BLOCKED_AUTHORITY_REVISION_MISMATCH', context)
  wanted = chosen~claimIds
  reviewed = review~reviewedClaimIds
  if wanted~items \== reviewed~items then -
    return self~blocked('BLOCKED_AUTHORITY_CLAIMS_MISMATCH', context)
  do i = 1 to wanted~items
    if wanted[i] \== reviewed[i] then -
      return self~blocked('BLOCKED_AUTHORITY_CLAIMS_MISMATCH', context)
  end
  result = self~blocked('APPROVED', context)
  result['decision_kind'] = 'NARRATIVE_SELECTION_ONLY'
  result['catalogue_revision'] = catalogueRevision
  result['policy_revision'] = review~policyRevision
  result['policy_selection_ref'] = review~policySelectionRef
  result['authority_proof_ref'] = review~proofRef
  result['intention_id'] = selected~identifier
  result['intention_revision'] = selected~revision
  result['objective'] = selected~objective
  result['narrative_id'] = chosen~identifier
  result['narrative_revision'] = chosen~revision
  result['headline'] = chosen~headline
  result['body'] = chosen~body
  result['action'] = chosen~action
  result['claim_ids'] = chosen~claimIds
  return result

/* LLM-facing candidate context without proof, request identity or execution. */
::class 'StoryAgentProjection' public
::method project
  use strict arg decision
  if \decision~isA(.Directory) then raise syntax 93.900 array ('decision Directory required')
  packet = .Directory~new
  packet['schema'] = 'alchemy.dynamic_story.agent_packet.v1'
  packet['status'] = 'BLOCKED'
  packet['publication_authority'] = 'NONE'
  packet['dispatch_authority'] = 'NONE'
  if decision~at('status') \== 'APPROVED' then return packet
  if decision~at('decision_kind') \== 'NARRATIVE_SELECTION_ONLY' then return packet
  claims = decision~at('claim_ids')
  if claims == .nil then return packet
  outputClaims = .Array~new
  do claim over claims
    outputClaims~append(claim)
  end
  packet['status'] = 'CANDIDATE'
  packet['intention_id'] = decision~at('intention_id')
  packet['intention_revision'] = decision~at('intention_revision')
  packet['narrative_id'] = decision~at('narrative_id')
  packet['narrative_revision'] = decision~at('narrative_revision')
  packet['catalogue_revision'] = decision~at('catalogue_revision')
  packet['headline'] = decision~at('headline')
  packet['body'] = decision~at('body')
  packet['action'] = decision~at('action')
  packet['claim_ids'] = outputClaims
  return packet

/* Candidate-only view model for the Rasen Falcon CMS/Wire site renderer.
 * This is NOT HTML, a Wire resource reference, an approval or dispatch.
 * The resource editor must publish independently approved exact assets.
 */
::class 'StorySiteProjection' public
::method project
  use strict arg decision, slotId
  if \decision~isA(.Directory) then raise syntax 93.900 array ('decision Directory required')
  if slotId~string~strip == '' then raise syntax 93.900 array ('slot id required')
  out = .Directory~new
  out['schema'] = 'alchemy.dynamic_story.site_candidate.v1'
  out['status'] = 'BLOCKED'
  out['slot_id'] = slotId
  out['publication_authority'] = 'NONE'
  out['dispatch_authority'] = 'NONE'
  if decision~at('status') \== 'APPROVED' then return out
  if decision~at('decision_kind') \== 'NARRATIVE_SELECTION_ONLY' then return out
  if decision~at('claim_ids') == .nil then return out
  out['status'] = 'CANDIDATE'
  out['narrative_id'] = decision~at('narrative_id')
  out['narrative_revision'] = decision~at('narrative_revision')
  out['catalogue_revision'] = decision~at('catalogue_revision')
  out['headline'] = decision~at('headline')
  out['body'] = decision~at('body')
  out['action'] = decision~at('action')
  claims = .Array~new
  do claim over decision~at('claim_ids')
    claims~append(claim)
  end
  out['claim_ids'] = claims
  return out
