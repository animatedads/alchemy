/* Dynamic Story 0.1-dev3 -- transport-neutral runtime narrative selection.
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
  expose status proofRef policyRevision policySelectionRef intentionId intentionRevision narrativeId narrativeRevision reason tenantId requestId country channel locale reviewedClaims
  use strict arg status, proofRef, policyRevision, policySelectionRef, intentionId, intentionRevision, narrativeId, narrativeRevision, reason, tenantId, requestId, country, channel, locale, claims
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
::method reviewedClaimIds
  expose reviewedClaims
  copy = .Array~new
  do claim over reviewedClaims
    copy~append(claim)
  end
  return copy

::class 'StoryDecisionEngine' public
::method init
  expose intentions bindings authorityGateway intentionSource
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
::method setIntentionSource
  expose intentionSource
  use strict arg source
  if source == .nil then raise syntax 93.900 array ('intention source required')
  if \source~hasMethod('CANDIDATES') then raise syntax 93.900 array ('source must implement candidates')
  intentionSource = source
::method decideLive
  expose intentionSource
  use strict arg context
  if intentionSource == .nil then return self~blocked('BLOCKED_NO_INTENTION_SOURCE', context)
  candidates = intentionSource~candidates(context)
  if \candidates~isA(.Array) then return self~blocked('BLOCKED_INVALID_INTENTION_SOURCE', context)
  return self~decide(candidates, context)
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
::method decide
  expose intentions bindings authorityGateway
  use strict arg candidateIds, context
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
  review = authorityGateway~review(context, selected, chosen)
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
  packet['headline'] = decision~at('headline')
  packet['body'] = decision~at('body')
  packet['action'] = decision~at('action')
  packet['claim_ids'] = outputClaims
  return packet
