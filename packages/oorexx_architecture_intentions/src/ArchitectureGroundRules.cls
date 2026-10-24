/* Architecture ground rules — architecture.groundrules/0.1
 * Policy is an attributed, scoped constraint, never a default architecture.
 * All applicable hard rules intersect; a lower-level rule cannot bypass an
 * organisational/global prohibition just because it is more specific.
 * Conformance evidence is a human assertion awaiting external audit.
 */
::requires 'json.cls'

::class ArchitectureGroundRules public
::attribute rules get
::attribute evaluations get

::method init
  expose rules evaluations
  rules = .Directory~new
  evaluations = .Directory~new

/* Scope: GLOBAL/all, ORGANISATION/id, CUSTOMER/id, PROJECT/id,
 * SUBSYSTEM/id or LINK/id. Kinds:
 * REQUIRE_CHOICE: one required option (first value)
 * ALLOW_CHOICE: exact permitted options (intersection across active rules)
 * DENY_CHOICE: forbidden options
 * REQUIRE_BINDING, ALLOW_BINDING, DENY_BINDING: the same for link bindings
 * CONTROL: a named compliance control with explicit review/evidence gate.
 */
::method addRule
  use strict arg id, policy, revision, scopeKind, scopeId, kind, subject, values, authority, source, rationale = ''
  if id~strip == '' | policy~strip == '' | revision~strip == '' | authority~strip == '' | source~strip == '' then -
    raise syntax 93.900 array('ARCH_POLICY_PROVENANCE_REQUIRED')
  if self~rules~hasIndex(id) then raise syntax 93.900 array('ARCH_POLICY_DUPLICATE',id)
  if pos('|'scopeKind'|','|GLOBAL|ORGANISATION|CUSTOMER|PROJECT|SUBSYSTEM|LINK|') == 0 then -
    raise syntax 93.900 array('ARCH_POLICY_SCOPE_UNKNOWN',scopeKind)
  if scopeId~strip == '' then raise syntax 93.900 array('ARCH_POLICY_SCOPE_ID_REQUIRED')
  if scopeKind == 'GLOBAL' & scopeId \== '*' then -
    raise syntax 93.900 array('ARCH_POLICY_GLOBAL_SCOPE_MUST_BE_STAR')
  permitted = '|REQUIRE_CHOICE|ALLOW_CHOICE|DENY_CHOICE|REQUIRE_BINDING|ALLOW_BINDING|DENY_BINDING|REQUIRE_CAPABILITY|DENY_CAPABILITY|REQUIRE_CAPABILITY_OWNER|DENY_CAPABILITY_OWNER|REQUIRE_AUTH_BOUNDARY|DENY_AUTH_EXEMPTION|CONTROL|'
  if pos('|'kind'|',permitted) == 0 then -
    raise syntax 93.900 array('ARCH_POLICY_KIND_UNKNOWN',kind)
  if subject~strip == '' | values~isA(.Array) == .false then -
    raise syntax 93.900 array('ARCH_POLICY_SUBJECT_OR_VALUES_INVALID')
  if kind \== 'CONTROL' & values~items == 0 then -
    raise syntax 93.900 array('ARCH_POLICY_VALUES_REQUIRED')
  if (kind == 'REQUIRE_CHOICE' | kind == 'REQUIRE_BINDING') & values~items \== 1 then -
    raise syntax 93.900 array('ARCH_POLICY_REQUIRED_SINGLE_VALUE')
  if kind~right(6) == 'CHOICE' & (scopeKind == 'LINK' | scopeKind == 'SUBSYSTEM') then -
    raise syntax 93.900 array('ARCH_POLICY_CHOICE_SCOPE_INVALID')
  if kind == 'REQUIRE_AUTH_BOUNDARY' | kind == 'DENY_AUTH_EXEMPTION' then do
    if values~items \== 1 then -
      raise syntax 93.900 array('ARCH_POLICY_AUTH_RULE_VALUE_REQUIRED')
    if kind == 'REQUIRE_AUTH_BOUNDARY' & values[1] \== 'PROTECTED' then -
      raise syntax 93.900 array('ARCH_POLICY_AUTH_VALUE_INVALID')
    if kind == 'DENY_AUTH_EXEMPTION' & values[1] \== 'EXEMPT' then -
      raise syntax 93.900 array('ARCH_POLICY_AUTH_VALUE_INVALID')
  end
  if kind == 'REQUIRE_CAPABILITY' | kind == 'DENY_CAPABILITY' then do
    if values~items \== 1 | values[1] \== 'REQUIRED' then -
      raise syntax 93.900 array('ARCH_POLICY_CAPABILITY_VALUE_INVALID')
  end
  if kind == 'REQUIRE_CAPABILITY_OWNER' | kind == 'DENY_CAPABILITY_OWNER' then do
    if values~items \== 1 then -
      raise syntax 93.900 array('ARCH_POLICY_CAPABILITY_OWNER_INVALID')
  end
  if kind~right(7) == 'BINDING' then do
    do proposed over values
      if pos('|'proposed'|','|direct_call|json_rpc|queue_fabric|jms|') == 0 then -
        raise syntax 93.900 array('ARCH_POLICY_BINDING_VALUE_UNKNOWN', proposed)
    end
  end
  row = .Directory~new
  row['id'] = id
  row['policy'] = policy
  row['revision'] = revision
  row['scopeKind'] = scopeKind
  row['scopeId'] = scopeId
  row['kind'] = kind
  row['subject'] = subject
  row['values'] = values~copy
  row['authority'] = authority
  row['source'] = source
  row['rationale'] = rationale
  self~rules[id] = row
  return row

/* A reviewer assertion is retained as an assertion, not a certification.
 * Independent compliance qualification remains external to the planner.
 */
::method evaluateControl
  use strict arg ruleId, finding, reviewer, evidenceRef, rationale
  if self~rules~hasIndex(ruleId) == .false then -
    raise syntax 93.900 array('ARCH_CONTROL_UNKNOWN', ruleId)
  if self~rules[ruleId]['kind'] \== 'CONTROL' then -
    raise syntax 93.900 array('ARCH_NOT_A_CONTROL',ruleId)
  if pos('|'finding'|','|PASS|FAIL|UNKNOWN|') == 0 then -
    raise syntax 93.900 array('ARCH_CONTROL_FINDING_INVALID',finding)
  if reviewer~strip == '' | evidenceRef~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_CONTROL_EVIDENCE_REQUIRED')
  record = .Directory~new
  record['ruleId'] = ruleId
  record['finding'] = finding
  record['reviewer'] = reviewer
  record['evidenceReference'] = evidenceRef
  record['rationale'] = rationale
  record['status'] = 'REVIEWER_ATTESTATION_NOT_INDEPENDENT_CERTIFICATION'
  self~evaluations[ruleId] = record
  return record

::method applicable private
  use strict arg rule, project
  if rule['scopeKind'] == 'GLOBAL' then return .true
  if rule['scopeKind'] == 'PROJECT' & rule['scopeId'] == project~projectId then return .true
  if rule['scopeKind'] == 'LINK' then return project~links~hasLink(rule['scopeId'])
  if rule['scopeKind'] == 'SUBSYSTEM' then return project~links~hasSubsystem(rule['scopeId'])
  return project~hasScope(rule['scopeKind'],rule['scopeId'])

::method match private
  use strict arg needle, options
  do candidate over options
    if needle == candidate then return .true
  end
  return .false

::method issue private
  use strict arg issues, code, rule, detail
  row = .Directory~new
  row['code'] = code
  row['ruleId'] = rule['id']
  row['policy'] = rule['policy']
  row['revision'] = rule['revision']
  row['message'] = detail
  issues~append(row)

::method question private
  use strict arg questions, rule, detail
  row = .Directory~new
  row['id'] = 'policy_'rule['id']
  row['section'] = '00-ground-rules'
  row['question'] = detail
  row['purpose'] = rule['policy']' version 'rule['revision']' ('rule['source']')'
  row['options'] = rule['values']
  row['answerMechanism'] = 'POLICY_DECISION_OR_EVIDENCE'
  questions~append(row)

/* Returns a publication snapshot; mutates only caller-supplied output lists.
 * Answers are the current *effective* choice graph, not hidden old answers.
 */
::method check
  use strict arg project, effective, issues, questions
  active = .Array~new
  do id over self~rules~allIndexes
    rule = self~rules[id]
    if rule['scopeKind'] == 'LINK' & \project~links~hasLink(rule['scopeId']) then do
      self~issue(issues,'ARCH_POLICY_SCOPE_UNRESOLVED',rule, -
        'Required link scope 'rule['scopeId']' is not declared in this project')
      iterate
    end
    if \self~applicable(rule,project) then iterate
    active~append(rule)
    kind = rule['kind']
    subject = rule['subject']
    if kind == 'CONTROL' then do
      if rule['values']~items == 0 then -
        self~question(questions,rule,'Define the revisioned control inventory and assessment authority for 'subject)
      if self~evaluations~hasIndex(id) then do
        finding = self~evaluations[id]['finding']
        if finding == 'FAIL' then -
          self~issue(issues,'ARCH_CONTROL_FAILED',rule,'Failed control 'subject' has no compliant architecture')
        else if finding == 'UNKNOWN' then -
          self~question(questions,rule,'What evidence and independent review satisfy control 'subject'?')
      end
      else self~question(questions,rule,'What evidence and review satisfy control 'subject'?')
      iterate
    end
    if kind == 'REQUIRE_AUTH_BOUNDARY' | kind == 'DENY_AUTH_EXEMPTION' then do
      if \project~links~hasLink(subject) then do
        self~issue(issues,'ARCH_POLICY_AUTH_LINK_UNKNOWN',rule, -
          'Authentication rule targets missing component link 'subject)
        iterate
      end
      guarded = project~capabilities~guards~hasIndex(subject)
      exempt = project~capabilities~exemptions~hasIndex(subject)
      if kind == 'REQUIRE_AUTH_BOUNDARY' then do
        if exempt then self~issue(issues,'ARCH_POLICY_AUTH_EXEMPTION_DENIED',rule, -
          'Mandatory authentication on link 'subject' cannot be exempted')
        else if \guarded then self~question(questions,rule, -
          'Specify a verified authentication enforcement boundary for 'subject)
      end
      if kind == 'DENY_AUTH_EXEMPTION' & exempt then -
        self~issue(issues,'ARCH_POLICY_AUTH_EXEMPTION_DENIED',rule, -
          'Authentication exemption forbidden for 'subject)
      iterate
    end
    if kind == 'REQUIRE_CAPABILITY' | kind == 'DENY_CAPABILITY' | -
       kind == 'REQUIRE_CAPABILITY_OWNER' | kind == 'DENY_CAPABILITY_OWNER' then do
      if \project~capabilities~definitions~hasIndex(subject) then do
        self~issue(issues,'ARCH_POLICY_CAPABILITY_UNKNOWN',rule, -
          'Unknown business capability 'subject)
        iterate
      end
      capabilityState = ''
      if project~capabilities~assessments~hasIndex(subject) then -
        capabilityState = project~capabilities~assessments[subject]['state']
      owner = ''
      if project~capabilities~placements~hasIndex(subject) then -
        owner = project~capabilities~placements[subject]['ownerComponent']
      if kind == 'REQUIRE_CAPABILITY' then do
        if capabilityState == '' | capabilityState == 'UNDECIDED' then -
          self~question(questions,rule,'Confirm mandatory capability 'subject)
        else if capabilityState \== 'REQUIRED' then -
          self~issue(issues,'ARCH_POLICY_REQUIRES',rule, -
            'Business capability 'subject' is mandatory')
      end
      if kind == 'DENY_CAPABILITY' & capabilityState == 'REQUIRED' then -
        self~issue(issues,'ARCH_POLICY_DENIED',rule, -
          'Business capability 'subject' is forbidden')
      if kind == 'REQUIRE_CAPABILITY_OWNER' then do
        if owner == '' then self~question(questions,rule, -
          'Select required owner 'rule['values'][1]' for 'subject)
        else if owner \== rule['values'][1] then -
          self~issue(issues,'ARCH_POLICY_REQUIRES',rule, -
            'Capability 'subject' must use owner 'rule['values'][1])
      end
      if kind == 'DENY_CAPABILITY_OWNER' & owner == rule['values'][1] then -
        self~issue(issues,'ARCH_POLICY_DENIED',rule, -
          'Capability 'subject' owner 'owner' is forbidden')
      iterate
    end
    if kind~right(7) == 'BINDING' then do
      /* A LINK-scoped rule checks that link only; project-wide binding
       * policies apply to *every* declared link, including future ones. */
      do link over project~links~allLinks
        if rule['scopeKind'] == 'LINK' & rule['scopeId'] \== link['id'] then iterate
        if rule['scopeKind'] == 'SUBSYSTEM' & rule['scopeId'] \== link['subsystem'] then iterate
        choice = link['binding']
        self~checkChoice(kind,choice,rule,issues,questions,link['id'])
      end
    end
    else do
      catalogQuestion = project~catalog~questionAt(subject)
      if catalogQuestion == .nil then do
        self~issue(issues,'ARCH_POLICY_QUESTION_UNKNOWN',rule,'No catalog question 'subject)
        iterate
      end
      do candidate over rule['values']
        known = .false
        do option over catalogQuestion['options']
          if candidate == option['id'] then known = .true
        end
        if \known then -
          self~issue(issues,'ARCH_POLICY_VALUE_UNKNOWN',rule, -
            'No catalog option 'candidate' for 'subject)
      end
      /* A stale choice on an inactive branch is not effective policy state. */
      choice = ''
      if effective~hasIndex(subject) then choice = effective[subject]
      self~checkChoice(kind,choice,rule,issues,questions,subject)
    end
  end
  /* A mandatory capability and a prohibition on the same capability are
   * contradictory regardless of whether a designer has entered an answer. */
  do first over active
    if first['kind'] \== 'REQUIRE_CAPABILITY' & -
       first['kind'] \== 'REQUIRE_CAPABILITY_OWNER' then iterate
    do second over active
      collision = .false
      if first['kind'] == 'REQUIRE_CAPABILITY' & -
         second['kind'] == 'DENY_CAPABILITY' then collision = .true
      if first['kind'] == 'REQUIRE_CAPABILITY_OWNER' & -
         second['kind'] == 'DENY_CAPABILITY_OWNER' & -
         first['values'][1] == second['values'][1] then collision = .true
      if collision & first['subject'] == second['subject'] then do
        synthetic = .Directory~new
        synthetic['id'] = first['id']'+'second['id']
        synthetic['policy'] = first['policy']' and 'second['policy']
        synthetic['revision'] = first['revision']'/'second['revision']
        self~issue(issues,'ARCH_POLICY_CONFLICT',synthetic, -
          'Conflicting capability constraints for 'first['subject'])
      end
    end
  end
  /* Check whether any link admits *any* binding under the intersection of
   * applicable ALLOW/REQUIRE/DENY rules: incompatible ground rules are
   * contradictions even before the designer has selected a binding. */
  do link over project~links~allLinks
    possible = .Array~of('direct_call','queue_fabric','json_rpc','jms')
    remaining = 0
    do option over possible
      valid = .true
      do rule over active
        if rule['kind']~right(7) \== 'BINDING' then iterate
        if rule['scopeKind'] == 'LINK' & rule['scopeId'] \== link['id'] then iterate
        if rule['scopeKind'] == 'SUBSYSTEM' & rule['scopeId'] \== link['subsystem'] then iterate
        kind = rule['kind']
        if kind == 'REQUIRE_BINDING' & option \== rule['values'][1] then valid = .false
        if kind == 'ALLOW_BINDING' & \self~match(option,rule['values']) then valid = .false
        if kind == 'DENY_BINDING' & self~match(option,rule['values']) then valid = .false
      end
      if valid then remaining = remaining + 1
    end
    if remaining == 0 then do
      synthetic = .Directory~new
      synthetic['id'] = 'binding:'link['id']
      synthetic['policy'] = 'Intersection of active ground rules'
      synthetic['revision'] = 'current'
      self~issue(issues,'ARCH_POLICY_CONFLICT',synthetic, -
        'No admissible interconnect binding for link 'link['id'])
    end
  end
  return self~snapshot(active)

::method checkChoice private
  use strict arg kind, choice, rule, issues, questions, target
  selected = rule['values']
  if kind == 'REQUIRE_CHOICE' | kind == 'REQUIRE_BINDING' then do
    if choice == '' then self~question(questions,rule,'Choose required 'target' = 'selected[1])
    else if choice \== selected[1] then -
      self~issue(issues,'ARCH_POLICY_REQUIRES',rule,target' must be 'selected[1]', not 'choice)
  end
  else if kind == 'ALLOW_CHOICE' | kind == 'ALLOW_BINDING' then do
    if choice \== '' & \self~match(choice,selected) then -
      self~issue(issues,'ARCH_POLICY_NOT_ALLOWED',rule,choice' is not allowed for 'target)
  end
  else if kind == 'DENY_CHOICE' | kind == 'DENY_BINDING' then do
    if choice \== '' & self~match(choice,selected) then -
      self~issue(issues,'ARCH_POLICY_DENIED',rule,choice' is forbidden for 'target)
  end

/* Website-ready, non-operative candidate matrix. Policy permission is not
 * technical support: ConnectSelector still owns per-adapter eligibility.
 * A more specific scope cannot override an organisational prohibition.
 */
::method bindingOptions
  use strict arg project
  rows = .Array~new
  do edge over project~links~allLinks
    do candidate over .Array~of('direct_call','json_rpc','queue_fabric','jms')
      record = .Directory~new
      record['edgeId'] = edge['id']
      record['binding'] = candidate
      record['scope'] = edge['subsystem']
      record['basis'] = 'SCOPED_GROUND_RULE_INTERSECTION'
      record['technicalQualification'] = 'NOT_ASSESSED_BY_POLICY'
      blockers = .Array~new
      governing = .Array~new
      do ruleId over self~rules~allIndexes
        rule = self~rules[ruleId]
        if \self~applicable(rule,project) then iterate
        kind = rule['kind']
        if kind~right(7) \== 'BINDING' then iterate
        if rule['scopeKind'] == 'LINK' & rule['scopeId'] \== edge['id'] then iterate
        if rule['scopeKind'] == 'SUBSYSTEM' & rule['scopeId'] \== edge['subsystem'] then iterate
        governing~append(ruleId)
        reason = ''
        if kind == 'DENY_BINDING' & self~match(candidate,rule['values']) then -
          reason = 'Forbidden by 'rule['policy']' rev 'rule['revision']
        if kind == 'ALLOW_BINDING' & \self~match(candidate,rule['values']) then -
          reason = 'Not in approved choices of 'rule['policy']' rev 'rule['revision']
        if kind == 'REQUIRE_BINDING' & candidate \== rule['values'][1] then -
          reason = 'Mandated alternative 'rule['values'][1]' by 'rule['policy']' rev 'rule['revision']
        if reason \== '' then do
          block = .Directory~new
          block['ruleId'] = ruleId
          block['authority'] = rule['authority']
          block['reason'] = reason
          blockers~append(block)
        end
      end
      record['governingRuleIds'] = governing
      record['exclusionReasons'] = blockers
      if blockers~items == 0 then record['status'] = 'POLICY_PERMITTED_NOT_QUALIFIED'
      else record['status'] = 'POLICY_EXCLUDED'
      rows~append(record)
    end
  end
  return rows

::method snapshot
  use strict arg active = .nil
  if active == .nil then do
    active = .Array~new
    do id over self~rules~allIndexes
      active~append(self~rules[id])
    end
  end
  row = .Directory~new
  row['schema'] = 'alchemy.architecture.ground-rules/0.1'
  row['applicableRules'] = active
  evidences = .Array~new
  do id over self~evaluations~allIndexes
    evidences~append(self~evaluations[id])
  end
  row['controlEvaluations'] = evidences
  row['complianceStatus'] = 'REVIEW_ONLY_NOT_CERTIFIED'
  row['authority'] = 'Attributed design constraints; all hard rules are cumulative'
  return row
