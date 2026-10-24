/* Architecture Intentions — architecture.plan/0.1
 * Semantic planning only. No execution, deployment, price lookup or dependency
 * resolution is performed by these objects. See docs/ARCHITECTURE.md.
 */
::requires 'json.cls'
::requires 'ArchitectureDomainModel.cls'
::requires 'ArchitectureGroundRules.cls'
::requires 'ArchitectureInterconnects.cls'
::requires 'ArchitectureCapabilityPlacement.cls'
::requires 'ArchitectureCapabilityRelationships.cls'

/* Catalog is a provider-supplied, reviewable question/component description.
 * The JSON loader is the only serialization boundary; domain objects remain
 * normal ooRexx objects, not a collection of UI controls.
 */
::class ArchitectureCatalog public
::attribute definition get
::method init
  expose definition
  use strict arg definition
  if definition~isA(.Directory) == .false then -
    raise syntax 93.900 array('ARCH_CATALOG_NOT_OBJECT')
  if definition['schema'] \== 'alchemy.architecture.catalog/0.1' then -
    raise syntax 93.900 array('ARCH_CATALOG_SCHEMA_MISMATCH')
  if definition~hasIndex('questions') == .false then -
    raise syntax 93.900 array('ARCH_CATALOG_QUESTIONS_MISSING')
  if definition~hasIndex('components') == .false then -
    raise syntax 93.900 array('ARCH_CATALOG_COMPONENTS_MISSING')

::method fromFile class
  use strict arg path
  if stream(path, 'C', 'QUERY EXISTS') == '' then -
    raise syntax 93.900 array('ARCH_CATALOG_FILE_NOT_FOUND', path)
  jsonText = charin(path, 1, chars(path))
  call stream path, 'C', 'CLOSE'
  return self~new(.JSON~fromJSON(jsonText))

::method questions
  return self~definition['questions']

::method foundation
  return self~definition['foundation']

::method componentAt
  use strict arg componentId
  components = self~definition['components']
  if components~hasIndex(componentId) then return components[componentId]
  return .nil

::method questionAt
  use strict arg questionId
  do q over self~questions
    if q['id'] == questionId then return q
  end
  return .nil

/* A project retains all recorded decisions, including those hidden when a
 * parent answer changes. Only answers reachable in the current question graph
 * participate in the snapshot and dependency proposal.
 */
::class ArchitectureProject public
::attribute projectId get
::attribute projectName get
::attribute catalog get
::attribute decisions get
::attribute history get
::attribute quotes get
::attribute features get
::attribute domain get
::attribute groundRules get
::attribute links get
::attribute scopes get
::attribute connectSelectorAdapter
::attribute capabilities get
::attribute capabilityRelationships get

::method init
  expose projectId projectName catalog decisions history quotes features domain groundRules links scopes connectSelectorAdapter capabilities capabilityRelationships
  use strict arg projectId, projectName, catalog
  decisions = .Directory~new
  history = .Array~new
  quotes = .Directory~new
  features = .Directory~new
  domain = .ArchitectureDomainModel~new
  groundRules = .ArchitectureGroundRules~new
  links = .ArchitectureInterconnects~new
  scopes = .Directory~new
  connectSelectorAdapter = .nil
  defs = .Directory~new
  if catalog~definition~hasIndex('businessCapabilities') then -
    defs = catalog~definition['businessCapabilities']
  capabilities = .ArchitectureCapabilityPlacement~new(defs)
  capabilityRelationships = .ArchitectureCapabilityRelationships~new

/* Attach explicit scope memberships. A customer policy only applies if
 * its scope is declared for this project; no inference from project name.
 */
::method includeScope
  use strict arg kind, identity
  if pos('|'kind'|','|ORGANISATION|CUSTOMER|') == 0 | identity~strip == '' then -
    raise syntax 93.900 array('ARCH_PROJECT_SCOPE_INVALID')
  self~scopes[kind'|'identity] = .true

::method hasScope
  use strict arg kind, identity
  return self~scopes~hasIndex(kind'|'identity)

/* Record a selected architecture option, its rationale and stated evidence.
 * Unknown questions or choices fail without altering previous truth.
 */
::method answer
  use strict arg questionId, choiceId, rationale, authority, evidence = ''
  q = self~catalog~questionAt(questionId)
  if q == .nil then raise syntax 93.900 array('ARCH_UNKNOWN_QUESTION', questionId)
  selected = .nil
  do option over q['options']
    if option['id'] == choiceId then selected = option
  end
  if selected == .nil then -
    raise syntax 93.900 array('ARCH_UNKNOWN_CHOICE', questionId, choiceId)
  if rationale~strip == '' then raise syntax 93.900 array('ARCH_RATIONALE_REQUIRED')
  if authority~strip == '' then raise syntax 93.900 array('ARCH_AUTHORITY_REQUIRED')
  record = .Directory~new
  record['questionId'] = questionId
  record['choiceId'] = choiceId
  record['choiceLabel'] = selected['label']
  record['rationale'] = rationale
  record['authority'] = authority
  record['evidence'] = evidence
  record['status'] = 'DECIDED'
  self~decisions[questionId] = record
  self~history~append(record~copy)
  return record

/* Functional requirements are first-class objects, distinct from decisions.
 * A feature can explicitly require known semantic components. Requested
 * components remain unresolved until SSC and Deployment validate them.
 */
::method feature
  use strict arg featureId, summary, priority, acceptance, authority, components = .nil
  if featureId~strip == '' | summary~strip == '' | acceptance~strip == '' then -
    raise syntax 93.900 array('ARCH_FEATURE_INCOMPLETE')
  if components == .nil then components = .Array~new
  do item over components
    if self~catalog~componentAt(item) == .nil then -
      raise syntax 93.900 array('ARCH_FEATURE_COMPONENT_UNKNOWN', item)
  end
  row = .Directory~new
  row['id'] = featureId
  row['summary'] = summary
  row['priority'] = priority
  row['acceptanceCriterion'] = acceptance
  row['authority'] = authority
  row['requiredComponents'] = components~copy
  self~features[featureId] = row
  return row

/* Cost assumptions require an explicit rate, quantity and provenance.
 * Units/currency stay with each quote; no online provider prices are invented.
 */
::method quote
  use strict arg resource, rate, quantity, currency, basis, evidence
  if datatype(rate, 'N') == .false | datatype(quantity, 'N') == .false then -
    raise syntax 93.900 array('ARCH_QUOTE_NOT_NUMERIC')
  if rate < 0 | quantity < 0 then raise syntax 93.900 array('ARCH_NEGATIVE_QUOTE')
  if currency~strip == '' | basis~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_QUOTE_PROVENANCE_REQUIRED')
  record = .Directory~new
  record['resource'] = resource
  record['unitRate'] = rate
  record['monthlyQuantity'] = quantity
  record['currency'] = currency
  record['basis'] = basis
  record['source'] = evidence
  record['estimatedMonthly'] = rate * quantity
  self~quotes[resource] = record
  return record

::method value
  use strict arg questionId
  if self~decisions~hasIndex(questionId) then -
    return self~decisions[questionId]['choiceId']
  return ''

/* The planner validates policy and computes dependency requirements but does
 * not resolve semantic versions or assert that artifacts are loadable.
 */
::class ArchitecturePlanner public
::attribute catalog get
::method init
  expose catalog
  use strict arg catalog

::method project
  use strict arg projectId, projectName
  return .ArchitectureProject~new(projectId, projectName, self~catalog)

::method active
  use strict arg q, project
  if q~hasIndex('when') == .false then return .true
  conditions = q['when']
  do key over conditions~allIndexes
    value = project~value(key)
    if value == '' then return .false
    matched = .false
    do permitted over conditions[key]
      if permitted == value then matched = .true
    end
    if matched == .false then return .false
  end
  return .true

::method issue private
  use strict arg issues, code, message
  row = .Directory~new
  row['code'] = code
  row['message'] = message
  issues~append(row)

/* Collect dependency requirements post-order, with cycle and missing-component
 * diagnostics. This is a semantic requirement closure, NOT an SSC resolution.
 */
::method collectComponent private
  use strict arg componentId, seen, visiting, ordered, issues
  if seen~hasIndex(componentId) then return
  if visiting~hasIndex(componentId) then do
    self~issue(issues, 'ARCH_DEP_CYCLE', 'Cycle at 'componentId)
    return
  end
  component = self~catalog~componentAt(componentId)
  if component == .nil then do
    self~issue(issues, 'ARCH_COMPONENT_UNKNOWN', 'No provider catalog record for 'componentId)
    return
  end
  visiting[componentId] = .true
  if component~hasIndex('requires') then do dep over component['requires']
    self~collectComponent(dep, seen, visiting, ordered, issues)
  end
  visiting~remove(componentId)
  seen[componentId] = .true
  item = .Directory~new
  item['componentId'] = componentId
  item['name'] = component['name']
  item['layer'] = component['layer']
  item['contract'] = component['contract']
  item['candidateVersion'] = component['candidateVersion']
  item['candidateEvidence'] = component['candidateEvidence']
  item['resolutionStatus'] = 'UNRESOLVED'
  item['artifactDigest'] = .nil
  item['requiresSSCAndTargetProbe'] = .JSON~true
  ordered~append(item)

/* The MU/MI semantic boundary is XTP-only. Carrier selection is a separate
 * question: pure L2 and native IP36 are not aliases for ordinary UDP/TCP.
 * A carrier proposal does not prove host capability or reachability.
 */
::method validateNetwork private
  use strict arg project, issues
  model = project~value('deployment_model')
  if model == 'rexxos_mu_mi' then do
    if project~value('deployment_target') \== '' & project~value('deployment_target') \== 'rexxos' then -
      self~issue(issues,'ARCH_MU_TARGET','MU/MI deployment requires RexxOS target')
    carrier = project~value('xtp_carrier')
    scope = project~value('network_scope')
    if carrier == 'l2' & scope \== '' & scope \== 'same_l2' then -
      self~issue(issues,'ARCH_L2_SCOPE','L2 XTP cannot cross routed/external boundaries')
    if carrier == 'udp_outer' then -
      self~issue(issues,'ARCH_XTP_UDP_POLICY','UDP-encapsulated XTP requires explicit carrier policy approval and target qualification; not allowed for internal MU/MI by default')
    if project~value('multicast') == 'ip_ssm' then -
      self~issue(issues,'ARCH_MI_MULTICAST','Direct IP SSM is not the internal MU/MI semantic multicast; use XTP multicast')
  end
  else if project~value('deployment_target') == 'rexxos' then -
    self~issue(issues,'ARCH_REXXOS_TARGET','RexxOS target requires a matching MU/MI topology decision')
  if project~value('cloud_purchase') == 'spot' & project~value('workload') \== 'batch' then -
    self~issue(issues,'ARCH_SPOT_RECOVERY','Interruptible cloud nodes require an explicit safe-to-retry batch workload and a qualified checkpoint/recovery contract')

/* Dynamic resource requirements are prompts for cost discovery, not fees. */
::method costResources private
  use strict arg project
  resources = .Array~new
  if project~value('deployment_model') \== '' & project~value('deployment_model') \== 'local' then resources~append('compute')
  if project~value('storage') \== '' & project~value('storage') \== 'filesystem' then resources~append('storage')
  if project~value('frontend') == 'web' | project~value('deployment_model') == 'hybrid' then -
    resources~append('network_egress')
  if project~value('deployment_model') == 'rexxos_mu_mi' then resources~append('fabric_operations')
  return resources

::method costProjection private
  use strict arg project
  cost = .Directory~new
  rows = .Array~new
  missing = .Array~new
  total = 0
  currency = ''
  do resource over self~costResources(project)
    if project~quotes~hasIndex(resource) == .false then do
      missing~append(resource)
      iterate
    end
    row = project~quotes[resource]~copy
    if currency == '' then currency = row['currency']
    if currency \== row['currency'] then do
      missing~append('currency_conflict:'resource)
      iterate
    end
    total = total + row['estimatedMonthly']
    rows~append(row)
  end
  cost['schema'] = 'alchemy.architecture.cost/0.1'
  cost['priceAuthority'] = 'User-provided quotes; no provider pricing verification'
  cost['quotedResources'] = rows
  cost['missingQuotes'] = missing
  cost['currency'] = currency
  if missing~items > 0 then do
    cost['status'] = 'INCOMPLETE'
    cost['estimatedMonthly'] = .nil
  end
  else do
    cost['status'] = 'ASSUMPTION_ONLY'
    cost['estimatedMonthly'] = total
  end
  return cost

/* Cost optimisation questions are hypotheses only. Providers must later supply
 * priced regions, capacity, licences, reservations and egress assumptions.
 */
::method costOpportunities private
  use strict arg project
  rows = .Array~new
  if project~value('deployment_model') == 'cloud' | project~value('deployment_model') == 'hybrid' then do
    rows~append(self~opportunity('CAPACITY_PURCHASE', -
      'Compare on-demand, reserved, and interruptible eligible capacity', -
      'Target utilization, interruption recovery, term length and current provider quote'))
    rows~append(self~opportunity('REGION_EGRESS', -
      'Compare region placement and cross-provider/network egress', -
      'Legal residency constraints, forecast transfer GB and per-route published tariffs'))
  end
  if project~value('deployment_model') == 'rexxos_mu_mi' then -
    rows~append(self~opportunity('MI_REUSE', -
      'Compare reusing qualified MI capacity with commissioning a new MI', -
      'Grid admission, Memory/Storage capacity receipts and costed host profiles'))
  if project~value('storage') == 'fabric' | project~value('storage') == 'hybrid' then -
    rows~append(self~opportunity('STORAGE_TIERS', -
      'Evaluate workspace, warm/cold tiers, replica counts and lifecycle', -
      'Access pattern, recovery objective, capacity domains and qualified provider prices'))
  return rows

::method opportunity private
  use strict arg code, suggestedComparison, evidenceRequired
  record = .Directory~new
  record['code'] = code
  record['comparison'] = suggestedComparison
  record['evidenceRequired'] = evidenceRequired
  record['savingsClaim'] = .nil
  return record

/* One pure projection recomputes questions, selected components, violations,
 * a handoff request, and cost assumptions from recorded project decisions.
 */
::method plan
  use strict arg project
  questions = .Array~new
  register = .Array~new
  effective = .Directory~new
  issues = .Array~new
  selected = .Array~new
  do q over self~catalog~questions
    if self~active(q, project) == .false then iterate
    key = q['id']
    if project~decisions~hasIndex(key) then do
      decision = project~decisions[key]~copy
      register~append(decision)
      effective[key] = decision['choiceId']
      do option over q['options']
        if option['id'] == effective[key] then do componentId over option['adds']
          selected~append(componentId)
        end
      end
    end
    else if q['required'] then do
      out = .Directory~new
      out['id'] = key
      out['section'] = q['section']
      out['question'] = q['prompt']
      out['options'] = q['options']
      out['purpose'] = 'Required architectural choice before resolution'
      questions~append(out)
    end
  end
  /* Discovery and integration questions sit before infrastructure questions;
   * a noun in a user statement cannot imply a principal or DB backend. */
  scopeQuestions = project~domain~openQuestions
  do q over scopeQuestions
    questions~append(q)
  end
  do q over project~links~questions
    questions~append(q)
  end
  rulesSnapshot = project~groundRules~check(project,effective,issues,questions)
  capabilityReview = project~capabilities~evaluate(self~catalog,issues,questions,project~links)
  relationshipReview = project~capabilityRelationships~evaluate(project~capabilities,project~links,issues,questions)
  connectReviews = project~links~qualification(project~connectSelectorAdapter,issues,questions)
  self~validateNetwork(project, issues)
  ordered = .Array~new
  seen = .Directory~new
  visiting = .Directory~new
  /* Catalog foundation is DESIGN-TIME tooling, not a mandatory set of
   * runtime dependencies for every customer application. */
  do componentId over selected
    self~collectComponent(componentId, seen, visiting, ordered, issues)
  end
  interconnectNeeds = project~links~requirements
  do componentId over interconnectNeeds['componentIds']
    self~collectComponent(componentId, seen, visiting, ordered, issues)
  end
  /* Domain service placement is explicitly chosen; mere catalog availability
   * cannot create runtime dependencies. */
  do componentId over capabilityReview['componentIds']
    self~collectComponent(componentId, seen, visiting, ordered, issues)
  end
  /* Feature demands join the same semantic closure, not an ad-hoc vendor tree. */
  featureRows = .Array~new
  do featureId over project~features~allIndexes
    feature = project~features[featureId]
    featureRows~append(feature~copy)
    do componentId over feature['requiredComponents']
      self~collectComponent(componentId, seen, visiting, ordered, issues)
    end
  end
  /* Preserve why a component was selected. */
  do item over ordered
    reasons = .Array~new
    key = item['componentId']
    do q over self~catalog~questions
      if effective~hasIndex(q['id']) then do option over q['options']
        if option['id'] == effective[q['id']] then do cid over option['adds']
          if cid == key then reasons~append('Decision 'q['id']'='option['id'])
        end
      end
    end
    do feat over featureRows
      do cid over feat['requiredComponents']
        if cid == key then reasons~append('Feature 'feat['id'])
      end
    end
    do edge over project~links~allLinks
      if edge['binding'] == 'queue_fabric' & key == 'queue_fabric' then -
        reasons~append('Interconnect 'edge['id']' uses Queue Fabric')
      if edge['binding'] == 'jms' & key == 'queue_fabric' then -
        reasons~append('JMS bridge 'edge['id']' requires Queue Fabric')
      if edge['binding'] \== '' & key == 'connect_selector' then -
        reasons~append('Interconnect 'edge['id']' uses ConnectSelector or its JMS bridge')
    end
    do capId over project~capabilities~placements~allIndexes
      placement = project~capabilities~placements[capId]
      if placement['ownerComponent'] == key then reasons~append('Capability 'capId' placed by 'placement['authority'])
    end
    if reasons~items == 0 then reasons~append('Transitive component dependency')
    item['selectedBecause'] = reasons
    raw = self~catalog~componentAt(key)
    item['dependsOn'] = raw['requires']
  end
  if issues~items > 0 then status = 'INCONSISTENT'
  else if scopeQuestions~items > 0 then status = 'NEEDS_DISCOVERY'
  else if questions~items > 0 then status = 'NEEDS_DECISIONS'
  else status = 'READY_FOR_DEPENDENCY_RESOLUTION'
  request = .Directory~new
  request['schema'] = 'alchemy.architecture.build-request/0.1'
  request['projectId'] = project~projectId
  request['state'] = status
  request['requirements'] = ordered
  request['externalIntegrationRequirements'] = interconnectNeeds['externalRequirements']
  request['businessCapabilityRequirements'] = capabilityReview['externalRequirements']
  request['connectSelectorReviews'] = connectReviews
  request['designTimeTooling'] = self~catalog~foundation
  request['buildLock'] = .nil
  request['nextAuthority'] = 'SSC component/source-level requirements + Deployment target/artifact qualification'
  request['executable'] = .JSON~false
  request['target'] = project~value('deployment_target')
  request['activationRequested'] = .JSON~false
  plan = .Directory~new
  plan['schema'] = 'alchemy.architecture.plan/0.1'
  plan['catalogRevision'] = self~catalog~definition['revision']
  plan['projectId'] = project~projectId
  plan['projectName'] = project~projectName
  plan['state'] = status
  plan['effectiveAnswers'] = effective
  plan['decisionRegister'] = register
  plan['featureRegister'] = featureRows
  plan['decisionHistory'] = project~history
  /* Business discovery / institutional ground rules precede technology
   * option picking regardless of catalog enumeration order. */
  orderedQuestions = .Array~new
  prioritySections = .Array~of('00-ground-rules','00-discovery', -
    '03-business-capabilities','03-capability-relationships')
  do section over prioritySections
    do pending over questions
      if pending['section'] == section then orderedQuestions~append(pending)
    end
  end
  do pending over questions
    priority = .false
    do section over prioritySections
      if pending['section'] == section then priority = .true
    end
    if \priority then orderedQuestions~append(pending)
  end
  plan['openQuestions'] = orderedQuestions
  plan['issues'] = issues
  plan['buildRequest'] = request
  plan['businessCapabilities'] = capabilityReview
  plan['capabilityRelationships'] = relationshipReview
  plan['scope'] = project~domain~snapshot
  plan['groundRules'] = rulesSnapshot
  plan['interconnectAlternatives'] = project~groundRules~bindingOptions(project)
  plan['interconnects'] = project~links~snapshot
  plan['connectSelectorReviews'] = connectReviews
  plan['cost'] = self~costProjection(project)
  plan['costOptimisation'] = self~costOpportunities(project)
  plan['deploymentAuthority'] = 'Planning only; no target mutation'
  plan['networkAuthority'] = 'Transport semantics and target capabilities require XTP/Socket Provider live evidence'
  return plan
