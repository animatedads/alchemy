/* Dynamic Story v0.1-dev1: transport-independent narrative decision core.
 * All authority-bearing input is supplied by the caller; this package never
 * grants consent, approves claims, or authenticates an intention itself.
 */
::class 'StoryIntention' public
::method init
  expose identifier priority objective revision
  use strict arg identifier, priority, objective, revision
  if identifier = '' | objective = '' then raise syntax 93.900 array ('empty intention id/objective')
  if \datatype(priority, 'W') then raise syntax 93.900 array ('priority must be integer')
::attribute identifier get
::attribute priority get
::attribute objective get
::attribute revision get

::class 'StoryNarrative' public
::method init
  expose identifier intentionId headline body action claimIds revision
  use strict arg identifier, intentionId, headline, body, action, claimIds, revision
  if identifier = '' | intentionId = '' then raise syntax 93.900 array ('missing narrative identity')
  if \claimIds~isA(.Array) then raise syntax 93.900 array ('claimIds must be Array')
::attribute identifier get
::attribute intentionId get
::attribute headline get
::attribute body get
::attribute action get
::attribute claimIds get
::attribute revision get

::class 'StoryDecisionEngine' public
::method init
  expose intentions narratives approvals revocations policyRevision
  intentions = .Directory~new
  narratives = .Directory~new
  approvals = .Directory~new
  revocations = .Directory~new
  policyRevision = 'unset'
::method policyRevision
  expose policyRevision
  use strict arg value
  policyRevision = value
::method registerIntention
  expose intentions
  use strict arg obj
  if \obj~isA(.StoryIntention) then raise syntax 93.900 array ('expected StoryIntention')
  intentions[obj~identifier] = obj
::method registerNarrative
  expose narratives
  use strict arg obj
  if \obj~isA(.StoryNarrative) then raise syntax 93.900 array ('expected StoryNarrative')
  narratives[obj~intentionId] = obj
::method approveClaim
  expose approvals revocations
  use strict arg claimId, revision
  if claimId = '' then raise syntax 93.900 array ('empty claim id')
  approvals[claimId] = revision
  revocations~remove(claimId)
::method revokeClaim
  expose approvals revocations
  use strict arg claimId
  approvals~remove(claimId)
  revocations[claimId] = 1
::method decide
  expose intentions narratives approvals revocations policyRevision
  use strict arg candidateIds, country, channel
  if \candidateIds~isA(.Array) then raise syntax 93.900 array ('candidateIds must be Array')
  chosen = .nil
  do candidate over candidateIds
    intent = intentions~at(candidate)
    if intent == .nil then iterate
    narrative = narratives~at(intent~identifier)
    if narrative == .nil then iterate
    if chosen == .nil then chosen = intent
    else if intent~priority > chosen~priority then chosen = intent
  end
  output = .Directory~new
  output['schema'] = 'alchemy.dynamic_story.decision.v1'
  output['country'] = country
  output['channel'] = channel
  output['policy_revision'] = policyRevision
  if chosen == .nil then do
    output['status'] = 'NO_ELIGIBLE_INTENTION'
    return output
  end
  narrative = narratives[chosen~identifier]
  do claim over narrative~claimIds
    if revocations~hasIndex(claim) then do
      output['status'] = 'BLOCKED_REVOKED_CLAIM'
      output['reason'] = claim
      return output
    end
    if \approvals~hasIndex(claim) then do
      output['status'] = 'BLOCKED_UNAPPROVED_CLAIM'
      output['reason'] = claim
      return output
    end
  end
  output['status'] = 'APPROVED'
  output['intention_id'] = chosen~identifier
  output['intention_revision'] = chosen~revision
  output['objective'] = chosen~objective
  output['narrative_id'] = narrative~identifier
  output['narrative_revision'] = narrative~revision
  output['headline'] = narrative~headline
  output['body'] = narrative~body
  output['action'] = narrative~action
  return output
