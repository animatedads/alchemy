/* Architecture Intentions — capability.relationships/0.1
 * The relationship between services is NOT ownership of the other's facts.
 * A case can reference a CRM observation, document or counsel decision,
 * but does not become the authoritative CRM, document, or legal record.
 * Every projection is read-only; connecting a path does not send an event.
 */
::requires 'json.cls'

::class ArchitectureCapabilityRelationships public
::attribute relations get
::attribute routes get
::attribute controls get
::attribute references get

::method init
  expose relations routes controls references
  relations = .Directory~new
  routes = .Directory~new
  controls = .Directory~new
  references = .Directory~new

/* Record a proposed cross-domain obligation, not an event delivery. The
 * reference type is an identifier contract, NEVER embedded source data. */
::method relate
  use strict arg id, source, target, interaction, subjectReference, authority, rationale, evidence
  if id~strip == '' | source~strip == '' | target~strip == '' | -
      subjectReference~strip == '' | authority~strip == '' | -
      rationale~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_REL_PROVENANCE_REQUIRED')
  if source == target then raise syntax 93.900 array('ARCH_REL_SELF_OWNERSHIP_UNCLEAR',id)
  if self~relations~hasIndex(id) then raise syntax 93.900 array('ARCH_REL_DUPLICATE',id)
  if pos('|'interaction'|', -
    '|OBSERVATION|REFERENCE|WORK_REQUEST|REVIEW_REQUEST|PUBLICATION|CONTROL_CHECK|') == 0 then -
    raise syntax 93.900 array('ARCH_REL_KIND_UNKNOWN',interaction)
  row = .Directory~new
  row['id'] = id
  row['sourceCapability'] = source
  row['targetCapability'] = target
  row['interaction'] = interaction
  row['subjectReferenceType'] = subjectReference
  row['authority'] = authority
  row['rationale'] = rationale
  row['evidence'] = evidence
  row['status'] = 'DESIGN_PROPOSAL_NOT_EXECUTED'
  self~relations[id] = row
  return row

/* Bind an independently declared component link; its semantics and policy
 * remain governed by ArchitectureInterconnects and ConnectSelector. */
::method bind
  use strict arg id, linkId, authority, evidence
  if \self~relations~hasIndex(id) then raise syntax 93.900 array('ARCH_REL_UNKNOWN',id)
  if linkId~strip == '' | authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_REL_LINK_EVIDENCE_REQUIRED',id)
  row = .Directory~new
  row['linkId'] = linkId
  row['authority'] = authority
  row['evidence'] = evidence
  self~routes[id] = row
  return row

/* Access and records controls must be attributed to an owner. This is not
 * legal certification and does not grant access, hold or disposition rights. */
::method govern
  use strict arg id, accessAuthority, classification, usePurpose, retentionBoundary, failureHandling, authority, evidence
  if \self~relations~hasIndex(id) then raise syntax 93.900 array('ARCH_REL_UNKNOWN',id)
  if accessAuthority~strip == '' | classification~strip == '' | -
      usePurpose~strip == '' | retentionBoundary~strip == '' | -
      failureHandling~strip == '' | authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_REL_GOVERNANCE_INCOMPLETE',id)
  row = .Directory~new
  row['accessAuthority'] = accessAuthority
  row['classification'] = classification
  row['usePurpose'] = usePurpose
  row['retentionBoundary'] = retentionBoundary
  row['failureHandling'] = failureHandling
  row['authority'] = authority
  row['evidence'] = evidence
  row['qualification'] = 'CONTROL_DESIGN_NOT_VERIFIED'
  self~controls[id] = row
  return row

/* The source retains data authority; a consumer holds a typed reference.
 * A remote copy or exported document is a separate design decision. */
::method reference
  use strict arg id, identityIssuer, referenceContract, visibilityRule, authority, evidence
  if \self~relations~hasIndex(id) then raise syntax 93.900 array('ARCH_REL_UNKNOWN',id)
  if identityIssuer~strip == '' | referenceContract~strip == '' | -
      visibilityRule~strip == '' | authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_REL_REFERENCE_INCOMPLETE',id)
  row = .Directory~new
  row['identityIssuer'] = identityIssuer
  row['referenceContract'] = referenceContract
  row['visibilityRule'] = visibilityRule
  row['authority'] = authority
  row['evidence'] = evidence
  row['status'] = 'REFERENCE_CONTRACT_NOT_PROBED'
  self~references[id] = row
  return row

::method query private
  use strict arg questions, identity, words, purpose
  row = .Directory~new
  row['id'] = identity
  row['section'] = '03-capability-relationships'
  row['question'] = words
  row['purpose'] = purpose
  row['answerMechanism'] = 'ATTRIBUTED_RELATIONSHIP_DECISION'
  row['options'] = .Array~new
  questions~append(row)

::method problem private
  use strict arg issues, code, words
  row = .Directory~new
  row['code'] = code
  row['message'] = words
  issues~append(row)

/* A relationship is valid only as a proposal. Missing scope is an open
 * question, contradictory NOT_REQUIRED scope is a blocking inconsistency.
 * No relationship automatically selects a component or an interconnect. */
::method evaluate
  use strict arg capabilities, links, issues, questions
  rows = .Array~new
  do id over self~relations~allIndexes
    proposed = self~relations[id]
    projected = proposed~copy
    source = proposed['sourceCapability']
    target = proposed['targetCapability']
    projected['sourceOwner'] = 'UNPLACED'
    projected['targetOwner'] = 'UNPLACED'
    projected['sourceRecordAuthority'] = 'UNRESOLVED'
    projected['targetRecordAuthority'] = 'UNRESOLVED'
    projected['route'] = .nil
    projected['governance'] = .nil
    projected['referenceContract'] = .nil
    projected['status'] = 'NEEDS_DESIGN'
    blocked = .false
    pending = .false
    do cap over .Array~of(source,target)
      if \capabilities~definitions~hasIndex(cap) then do
        self~problem(issues,'ARCH_REL_CAPABILITY_UNKNOWN',id' references unknown capability 'cap)
        blocked = .true
        iterate
      end
      state = 'UNASSESSED'
      if capabilities~assessments~hasIndex(cap) then state = capabilities~assessments[cap]['state']
      if state == 'NOT_REQUIRED' then do
        self~problem(issues,'ARCH_REL_CAPABILITY_EXCLUDED', -
          id' needs 'cap' but the customer excluded it')
        blocked = .true
      end
      else if state \== 'REQUIRED' then do
        self~query(questions,'rel_'id'_'cap'_scope', -
          'Is 'cap' actually required for relationship 'id'?', -
          'No runtime component is selected until the capability is confirmed and placed')
        pending = .true
      end
      else if \capabilities~placements~hasIndex(cap) then do
        self~query(questions,'rel_'id'_'cap'_owner', -
          'Which service owns 'cap' in relationship 'id'?', -
          'A relationship must not invent a domain record owner')
        pending = .true
      end
      else if cap == source then do
        projected['sourceOwner'] = capabilities~placements[cap]['ownerComponent']
        projected['sourceRecordAuthority'] = capabilities~placements[cap]['recordAuthority']
      end
      else do
        projected['targetOwner'] = capabilities~placements[cap]['ownerComponent']
        projected['targetRecordAuthority'] = capabilities~placements[cap]['recordAuthority']
      end
    end
    if self~routes~hasIndex(id) then do
      route = self~routes[id]
      projected['route'] = route~copy
      edgeId = route['linkId']
      if \links~hasLink(edgeId) then do
        self~problem(issues,'ARCH_REL_LINK_UNKNOWN',id' references nonexistent link 'edgeId)
        blocked = .true
      end
      else do
        edge = links~links[edgeId]
        pattern = edge['pattern']
        kind = proposed['interaction']
        allowed = .true
        if kind == 'CONTROL_CHECK' & pattern \== 'REQUEST_REPLY' then allowed = .false
        if (kind == 'WORK_REQUEST' | kind == 'REVIEW_REQUEST') & -
            pattern \== 'COMMAND' & pattern \== 'REQUEST_REPLY' then allowed = .false
        if (kind == 'OBSERVATION' | kind == 'PUBLICATION') & -
            pattern \== 'EVENT' & pattern \== 'COMMAND' then allowed = .false
        if \allowed then do
          self~problem(issues,'ARCH_REL_PATTERN_MISMATCH', -
            id' 'kind' cannot use 'pattern' link 'edgeId)
          blocked = .true
        end
        if edge['binding'] == '' then do
          self~query(questions,'rel_'id'_connector', -
            'Which eligible ConnectSelector/JMS binding carries 'id'?', -
            'The planner cannot assume one transport from a business relationship')
          pending = .true
        end
      end
    end
    else do
      self~query(questions,'rel_'id'_transport', -
        'Does 'id' need a component interconnect, or is it an internal reference?', -
        'Choose DirectCall, RPC, Queue Fabric or a separate JMS bridge only if needed')
      pending = .true
    end
    if self~controls~hasIndex(id) then projected['governance'] = self~controls[id]~copy
    else do
      self~query(questions,'rel_'id'_governance', -
        'Which access, privacy, retention and failure rules govern 'id'?', -
        "No case or communications workflow may inherit another service's authority")
      pending = .true
    end
    if self~references~hasIndex(id) then projected['referenceContract'] = self~references[id]~copy
    else do
      self~query(questions,'rel_'id'_reference', -
        'Which source-issued identifier may 'id' refer to, and who can read it?', -
        'Use typed references; do not copy privileged case, legal or document truth')
      pending = .true
    end
    if blocked then projected['status'] = 'INCONSISTENT'
    else if pending then projected['status'] = 'NEEDS_DESIGN'
    else projected['status'] = 'PROPOSED_REQUIRES_QUALIFICATION'
    rows~append(projected)
  end
  out = .Directory~new
  out['schema'] = 'alchemy.architecture.capability-relationships/0.1'
  out['relationships'] = rows
  out['count'] = rows~items
  out['ownershipRule'] = 'Cross-domain reference and coordination, never transfer of authoritative record ownership'
  out['executable'] = .JSON~false
  out['qualification'] = 'Architecture proposal; no real service called and no legal/retention/security control certified'
  return out

/* Scenario copies must own their own records, not shallowly alias mutable
 * relation evidence or qualification rows in the project of record. */
::method copyFrom
  use strict arg original
  do id over original~relations~allIndexes
    self~relations[id] = original~relations[id]~copy
  end
  do id over original~routes~allIndexes
    self~routes[id] = original~routes[id]~copy
  end
  do id over original~controls~allIndexes
    self~controls[id] = original~controls[id]~copy
  end
  do id over original~references~allIndexes
    self~references[id] = original~references[id]~copy
  end
