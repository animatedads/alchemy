/* Architecture Intentions — architecture.capability-placement/0.1
 * One business capability is a requested authority boundary, NOT a package.
 * Unknown/required/not-required are separately recorded. A selected service
 * is a proposed placement; SSC/Deployment never inherit a false qualification.
 */
::requires 'json.cls'

::class ArchitectureCapabilityPlacement public
::attribute definitions get
::attribute assessments get
::attribute placements get
::attribute answers get
::attribute guards get
::attribute exemptions get
::attribute discoveryRequested

::method init
  expose definitions assessments placements answers guards exemptions discoveryRequested
  use strict arg definitions
  if \definitions~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_CAPABILITY_CATALOG_REQUIRED')
  assessments = .Directory~new
  placements = .Directory~new
  answers = .Directory~new
  guards = .Directory~new
  exemptions = .Directory~new
  discoveryRequested = .false

::method discover
  expose discoveryRequested
  use strict arg authority, rationale
  if authority~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_CAP_DISCOVERY_PROVENANCE_REQUIRED')
  discoveryRequested = .true

::method assess
  use strict arg id, state, authority, rationale, evidence = ''
  if \self~definitions~hasIndex(id) then -
    raise syntax 93.900 array('ARCH_CAP_UNKNOWN',id)
  if pos('|'state'|','|REQUIRED|NOT_REQUIRED|UNDECIDED|') == 0 then -
    raise syntax 93.900 array('ARCH_CAP_STATE_INVALID',state)
  if authority~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_CAP_PROVENANCE_REQUIRED')
  row = .Directory~new
  row['id'] = id
  row['state'] = state
  row['authority'] = authority
  row['rationale'] = rationale
  row['evidence'] = evidence
  self~assessments[id] = row
  /* A revoked requirement cannot leave a stale component requirement. */
  if state \== 'REQUIRED' then do
    if self~placements~hasIndex(id) then self~placements~remove(id)
    if self~answers~hasIndex(id) then self~answers~remove(id)
  end
  return row

/* Ownership of a domain record is separate from where a process runs.  An
 * EXTERNAL owner records integration work, NOT an internal component ID.
 */
::method place
  use strict arg id, layer, owner, recordAuthority, boundary, authority, rationale, evidence
  if \self~definitions~hasIndex(id) then -
    raise syntax 93.900 array('ARCH_CAP_UNKNOWN',id)
  if \self~assessments~hasIndex(id) then -
    raise syntax 93.900 array('ARCH_CAP_REQUIREMENT_MISSING',id)
  if self~assessments[id]['state'] \== 'REQUIRED' then -
    raise syntax 93.900 array('ARCH_CAP_NOT_REQUIRED',id)
  allowed = '|GOVERNANCE|DOMAIN|KNOWLEDGE|SECURITY|PLATFORM|SERVICE|INTEGRATION|EDGE|DEVICE|'
  if pos('|'layer'|',allowed) == 0 then -
    raise syntax 93.900 array('ARCH_CAP_LAYER_INVALID',layer)
  permitted = .false
  do candidate over self~definitions[id]['candidates']
    if owner == candidate then permitted = .true
  end
  if \permitted then raise syntax 93.900 array('ARCH_CAP_OWNER_NOT_CANDIDATE',id,owner)
  if recordAuthority~strip == '' | boundary~strip == '' | -
      authority~strip == '' | rationale~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_CAP_PLACEMENT_EVIDENCE_REQUIRED',id)
  row = .Directory~new
  row['id'] = id
  row['layer'] = layer
  row['ownerComponent'] = owner
  row['recordAuthority'] = recordAuthority
  row['boundary'] = boundary
  row['authority'] = authority
  row['rationale'] = rationale
  row['evidence'] = evidence
  row['state'] = 'PROPOSED_NOT_QUALIFIED'
  self~placements[id] = row
  return row

::method clarify
  use strict arg id, questionId, answer, authority, evidence
  if \self~definitions~hasIndex(id) then -
    raise syntax 93.900 array('ARCH_CAP_UNKNOWN',id)
  if \self~assessments~hasIndex(id) then -
    raise syntax 93.900 array('ARCH_CAP_REQUIREMENT_MISSING',id)
  if self~assessments[id]['state'] \== 'REQUIRED' then -
    raise syntax 93.900 array('ARCH_CAP_NOT_REQUIRED',id)
  known = .false
  do question over self~definitions[id]['questions']
    if question['id'] == questionId then known = .true
  end
  if \known then raise syntax 93.900 array('ARCH_CAP_QUESTION_UNKNOWN',id,questionId)
  if answer~strip == '' | authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_CAP_ANSWER_EVIDENCE_REQUIRED')
  if \self~answers~hasIndex(id) then self~answers[id] = .Directory~new
  row = .Directory~new
  row['answer'] = answer
  row['authority'] = authority
  row['evidence'] = evidence
  self~answers[id][questionId] = row
  return row

/* Protect an *individual* trust boundary; do not infer that one login
 * authenticates every downstream service, device or delegated request. */
::method protect
  use strict arg boundaryId, actorId, principalId, resourceId, operation, point, authenticatingAuthority, authority, rationale, evidence
  if boundaryId~strip == '' | actorId~strip == '' | principalId~strip == '' | -
      resourceId~strip == '' | operation~strip == '' | -
      authenticatingAuthority~strip == '' | authority~strip == '' | -
      rationale~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_AUTH_BOUNDARY_INCOMPLETE')
  if pos('|'point'|','|EDGE|SERVICE|DEVICE|LOCAL|TRANSPORT|') == 0 then -
    raise syntax 93.900 array('ARCH_AUTH_POINT_INVALID',point)
  row = .Directory~new
  row['id'] = boundaryId
  row['actorId'] = actorId
  row['principalId'] = principalId
  row['resourceId'] = resourceId
  row['operation'] = operation
  row['enforcementPoint'] = point
  row['authenticatingAuthority'] = authenticatingAuthority
  row['authority'] = authority
  row['rationale'] = rationale
  row['evidence'] = evidence
  row['state'] = 'DESIGN_ASSERTION_NOT_TESTED'
  self~guards[boundaryId] = row
  if self~exemptions~hasIndex(boundaryId) then self~exemptions~remove(boundaryId)
  return row

/* Design-time trust exception, NEVER an authorization policy waiver. A link
 * that does not require fresh authentication must have an attributable reason.
 * Higher authority's scoped rules may still require authentication. */
::method exemptBoundary
  use strict arg boundaryId, rationale, authority, evidence
  if boundaryId~strip == '' | rationale~strip == '' | -
      authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_AUTH_EXEMPTION_INCOMPLETE')
  row = .Directory~new
  row['id'] = boundaryId
  row['rationale'] = rationale
  row['authority'] = authority
  row['evidence'] = evidence
  row['state'] = 'DESIGN_PROPOSAL_REQUIRES_POLICY_REVIEW'
  self~exemptions[boundaryId] = row
  if self~guards~hasIndex(boundaryId) then self~guards~remove(boundaryId)
  return row

::method question private
  use strict arg questions, id, detail, purpose
  row = .Directory~new
  row['id'] = id
  row['section'] = '03-business-capabilities'
  row['question'] = detail
  row['purpose'] = purpose
  row['options'] = .Array~new
  row['answerMechanism'] = 'ATTRIBUTED_CAPABILITY_ASSESSMENT'
  questions~append(row)

/* Pure projection: referenced service candidate can join the build request
 * only after an explicit REQUIRED + placed decision. External owners generate
 * a separate unresolved integration requirement, not a made-up ZIP. */
::method evaluate
  use strict arg catalog, issues, questions, links = .nil
  selected = .Array~new
  external = .Array~new
  inventory = .Array~new
  if self~discoveryRequested & self~assessments~items == 0 then -
    self~question(questions,'cap_inventory', -
      'Which business and institutional capabilities are actually in scope?', -
      'Select REQUIRED, NOT_REQUIRED or UNDECIDED with evidence; none is a default runtime dependency')
  do id over self~definitions~allIndexes
    def = self~definitions[id]
    row = .Directory~new
    row['id'] = id
    row['label'] = def['label']
    row['role'] = def['role']
    row['recommendedLayer'] = def['defaultLayer']
    row['candidates'] = def['candidates']
    row['limitations'] = def['limitations']
    row['state'] = 'UNASSESSED'
    if self~assessments~hasIndex(id) then row['state'] = self~assessments[id]['state']
    inventory~append(row)
    if row['state'] \== 'REQUIRED' then iterate
    if \self~placements~hasIndex(id) then -
      self~question(questions,'cap_'id'_placement', -
        'Where is 'def['label']' owned and which service has authority?', -
        'A capability request does not select the candidate package')
    else do
      owner = self~placements[id]['ownerComponent']
      if owner == 'EXTERNAL' then do
        need = .Directory~new
        need['capabilityId'] = id
        need['kind'] = 'EXTERNAL_DOMAIN_AUTHORITY'
        need['status'] = 'UNRESOLVED'
        need['placement'] = self~placements[id]
        external~append(need)
      end
      else if catalog~componentAt(owner) == .nil then do
        problem = .Directory~new
        problem['code'] = 'ARCH_CAP_COMPONENT_UNKNOWN'
        problem['message'] = id' selected unknown component 'owner
        issues~append(problem)
      end
      else selected~append(owner)
    end
    do q over def['questions']
      answered = .false
      if self~answers~hasIndex(id) then -
        answered = self~answers[id]~hasIndex(q['id'])
      if \answered then -
        self~question(questions,'cap_'id'_'q['id'],q['prompt'], -
          def['label']': 'def['limitations'])
    end
  end
  if self~assessments~hasIndex('authentication') then do
    if self~assessments['authentication']['state'] == 'REQUIRED' & links \== .nil then do
      do edge over links~allLinks
        id = edge['id']
        if \self~guards~hasIndex(id) & \self~exemptions~hasIndex(id) then -
          self~question(questions,'cap_auth_link_'id, -
            'Where and how is link 'id' authenticated, or why does it not require a new authentication boundary?', -
            'DirectCall, RPC, Queue Fabric and JMS have different trust assumptions; do not infer coverage')
      end
    end
  end
  if self~guards~items > 0 then do
    if \self~assessments~hasIndex('authentication') then -
      self~question(questions,'cap_authentication_required', -
        'Authentication protection points are declared: is authentication required?', -
        'Boundary declarations do not imply an authorised identity architecture')
    else if self~assessments['authentication']['state'] == 'NOT_REQUIRED' then do
      problem = .Directory~new
      problem['code'] = 'ARCH_AUTH_BOUNDARY_CONFLICT'
      problem['message'] = 'Authentication boundaries exist but authentication is excluded'
      issues~append(problem)
    end
  end
  out = .Directory~new
  out['schema'] = 'alchemy.architecture.capability-placement/0.1'
  out['inventory'] = inventory
  out['assessments'] = self~assessments
  out['placements'] = self~placements
  out['answers'] = self~answers
  out['trustBoundaries'] = self~guards
  out['authenticationExemptions'] = self~exemptions
  out['componentIds'] = selected
  out['externalRequirements'] = external
  out['authority'] = 'Architectural propositions only; no certification or deployment'
  return out

::method copyFrom
  use strict arg source
  self~discoveryRequested = source~discoveryRequested
  do id over source~assessments~allIndexes
    self~assessments[id] = source~assessments[id]~copy
  end
  do id over source~placements~allIndexes
    self~placements[id] = source~placements[id]~copy
  end
  do id over source~answers~allIndexes
    self~answers[id] = .Directory~new
    do key over source~answers[id]~allIndexes
      self~answers[id][key] = source~answers[id][key]~copy
    end
  end
  do id over source~exemptions~allIndexes
    self~exemptions[id] = source~exemptions[id]~copy
  end
  do id over source~guards~allIndexes
    self~guards[id] = source~guards[id]~copy
  end
