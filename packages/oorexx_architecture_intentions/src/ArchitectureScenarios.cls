/* Architecture Intentions — architecture.scenarios/0.1
 * Explicit counterfactual architecture projections. Scenario generation must
 * never change the project of record, decide unanswered business requirements,
 * quote external prices, resolve artifacts, or approve deployment.
 */
::requires 'ArchitecturePlanner.cls'

/* A scenario describes explicitly authorized departures from one project.
 * Technical choices and connector choices remain independently attributable.
 * Scenario-specific quotations deliberately do NOT inherit unqualified
 * prices from the reference topology.
 */
::class ArchitectureScenario public
::attribute id get
::attribute label get
::attribute rationale get
::attribute authority get
::attribute choices get
::attribute bindings get
::attribute placements get
::attribute intents get
::attribute bridges get
::attribute quotes get
::attribute capabilityPlacements get

::method init
  expose id label rationale authority choices bindings placements intents bridges quotes capabilityPlacements
  use strict arg id, label, rationale, authority
  permitted = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'
  if id~strip == '' | id~length > 64 | verify(id,permitted) \== 0 then -
    raise syntax 93.900 array('ARCH_SCENARIO_ID_INVALID',id)
  if label~strip == '' | rationale~strip == '' | authority~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_PROVENANCE_REQUIRED')
  choices = .Directory~new
  bindings = .Directory~new
  placements = .Directory~new
  intents = .Directory~new
  bridges = .Directory~new
  quotes = .Directory~new
  capabilityPlacements = .Directory~new

/* The planner validates that the question/choice exists at projection time. */
::method choose
  use strict arg questionId, choiceId, rationale, evidence = ''
  if questionId~strip == '' | choiceId~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_CHOICE_INCOMPLETE')
  item = .Directory~new
  item['questionId'] = questionId
  item['choiceId'] = choiceId
  item['rationale'] = rationale
  item['evidence'] = evidence
  self~choices[questionId] = item
  return item

/* A scenario may change the connector while retaining the original service
 * intention; the old connector's guarantees must NOT carry across. */
::method bind
  use strict arg linkId, binding, rationale, evidence = ''
  if linkId~strip == '' | binding~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_BINDING_INCOMPLETE')
  item = .Directory~new
  item['linkId'] = linkId
  item['binding'] = binding
  item['rationale'] = rationale
  item['evidence'] = evidence
  self~bindings[linkId] = item
  return item

::method place
  use strict arg linkId, locality, evidence
  if linkId~strip == '' | locality~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_PLACEMENT_INCOMPLETE')
  item = .Directory~new
  item['linkId'] = linkId
  item['locality'] = locality
  item['evidence'] = evidence
  self~placements[linkId] = item
  return item

/* Explicit semantic mode changes: e.g. EVENT NOTIFY -> EVENT ENQUEUE.
 * These are deliberate scenario choices, not auto-mapped transport aliases.
 */
::method intent
  use strict arg linkId, operation, mode, requirement, destination, rationale
  if linkId~strip == '' | operation~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_INTENT_INCOMPLETE')
  item = .Directory~new
  item['linkId'] = linkId
  item['operation'] = operation
  item['mode'] = mode
  item['requirement'] = requirement
  item['destination'] = destination
  item['rationale'] = rationale
  self~intents[linkId] = item
  return item

/* JMS is an external bridge boundary, not a ConnectSelector provider.
 * Every direction must be declared explicitly per scenario.
 */
::method bridge
  use strict arg linkId, direction, source, target, rationale
  if linkId~strip == '' | source~strip == '' | target~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_BRIDGE_INCOMPLETE')
  item = .Directory~new
  item['linkId'] = linkId
  item['direction'] = direction
  item['source'] = source
  item['target'] = target
  item['rationale'] = rationale
  self~bridges[linkId] = item
  return item

::method price
  use strict arg resource, rate, monthlyQuantity, currency, basis, evidence
  if resource~strip == '' then raise syntax 93.900 array('ARCH_SCENARIO_RESOURCE_REQUIRED')
  item = .Directory~new
  item['resource'] = resource
  item['rate'] = rate
  item['monthlyQuantity'] = monthlyQuantity
  item['currency'] = currency
  item['basis'] = basis
  item['evidence'] = evidence
  self~quotes[resource] = item
  return item

/* A scenario may propose a different owner for an already REQUIRED domain
 * capability. The underlying business need and answers remain unchanged. */
::method placeCapability
  use strict arg id, layer, owner, recordAuthority, boundary, rationale, evidence
  if id~strip == '' | rationale~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_SCENARIO_CAPABILITY_INCOMPLETE')
  row = .Directory~new
  row['id'] = id
  row['layer'] = layer
  row['owner'] = owner
  row['recordAuthority'] = recordAuthority
  row['boundary'] = boundary
  row['rationale'] = rationale
  row['evidence'] = evidence
  self~capabilityPlacements[id] = row
  return row

::class ArchitectureScenarioComparison public
::attribute planner get
::attribute scenarios get

::method init
  expose planner scenarios
  use strict arg planner
  if \planner~isA(.ArchitecturePlanner) then -
    raise syntax 93.900 array('ARCH_SCENARIO_PLANNER_REQUIRED')
  scenarios = .Array~new

::method register
  use strict arg scenario
  if \scenario~isA(.ArchitectureScenario) then -
    raise syntax 93.900 array('ARCH_SCENARIO_OBJECT_REQUIRED')
  do existing over self~scenarios
    if existing~id == scenario~id then -
      raise syntax 93.900 array('ARCH_SCENARIO_DUPLICATE',scenario~id)
  end
  self~scenarios~append(scenario)
  return scenario

/* All candidate records are rebuilt without mutating the project of record.
 * The project id remains unchanged so PROJECT-scoped rules still apply.
 * Domain facts, policies and previous decisions are copied as snapshots.
 */
::method cloneProject private
  use strict arg original
  copy = self~planner~project(original~projectId,original~projectName)
  do id over original~scopes~allIndexes
    copy~scopes[id] = original~scopes[id]
  end
  do id over original~decisions~allIndexes
    copy~decisions[id] = original~decisions[id]~copy
  end
  do row over original~history
    copy~history~append(row~copy)
  end
  do id over original~features~allIndexes
    feature = original~features[id]~copy
    feature['requiredComponents'] = feature['requiredComponents']~copy
    copy~features[id] = feature
  end
  /* No inherited price: locality, size, SLA and purchased capacity may change. */
  do id over original~domain~entities~allIndexes
    copy~domain~entities[id] = original~domain~entities[id]~copy
  end
  do rel over original~domain~relationships
    copy~domain~relationships~append(rel~copy)
  end
  do stmt over original~domain~statements
    copy~domain~statements~append(stmt~copy)
  end
  do id over original~domain~facts~allIndexes
    copy~domain~facts[id] = original~domain~facts[id]~copy
  end
  do id over original~groundRules~rules~allIndexes
    rule = original~groundRules~rules[id]~copy
    rule['values'] = rule['values']~copy
    copy~groundRules~rules[id] = rule
  end
  do id over original~groundRules~evaluations~allIndexes
    copy~groundRules~evaluations[id] = original~groundRules~evaluations[id]~copy
  end
  do id over original~links~links~allIndexes
    old = original~links~links[id]
    link = old~copy
    link['guarantees'] = old['guarantees']~copy
    if old['serviceIntent'] \== .nil then link['serviceIntent'] = old['serviceIntent']~copy
    if old['jmsBridge'] \== .nil then link['jmsBridge'] = old['jmsBridge']~copy
    copy~links~links[id] = link
  end
  copy~capabilities~copyFrom(original~capabilities)
  copy~capabilityRelationships~copyFrom(original~capabilityRelationships)
  copy~connectSelectorAdapter = original~connectSelectorAdapter
  return copy

::method projectScenario private
  use strict arg original, scenario
  projected = self~cloneProject(original)
  alteredTopology = .false
  do id over scenario~choices~allIndexes
    choice = scenario~choices[id]
    projected~answer(id,choice['choiceId'],choice['rationale'], -
      scenario~authority,choice['evidence'])
    if id == 'deployment_model' | id == 'deployment_target' then alteredTopology = .true
  end
  /* Old placement evidence is not transferable to a different topology. */
  if alteredTopology then do id over projected~links~links~allIndexes
    row = projected~links~links[id]
    row['placement'] = 'UNKNOWN'
    row['placementEvidence'] = ''
    row['placementAuthority'] = ''
  end
  do id over scenario~bindings~allIndexes
    requested = scenario~bindings[id]
    if \projected~links~hasLink(id) then -
      raise syntax 93.900 array('ARCH_SCENARIO_LINK_UNKNOWN',id)
    old = projected~links~links[id]
    intent = old['serviceIntent']
    /* Every changed binding must reacquire transport-dependent guarantees. */
    if old['binding'] \== requested['binding'] then do
      projected~links~bind(id,requested['binding'],requested['rationale'], -
        scenario~authority,requested['evidence'])
      if intent \== .nil & requested['binding'] \== 'jms' then do
        projected~links~serviceIntent(id,intent['operation'],intent['mode'], -
          intent['requirement'],intent['destination'],intent['authority'], -
          intent['rationale'])
      end
    end
  end
  do id over scenario~bridges~allIndexes
    requested = scenario~bridges[id]
    projected~links~jmsBridge(id,requested['direction'],requested['source'], -
      requested['target'],scenario~authority,requested['rationale'])
  end
  do id over scenario~intents~allIndexes
    requested = scenario~intents[id]
    projected~links~serviceIntent(id,requested['operation'],requested['mode'], -
      requested['requirement'],requested['destination'],scenario~authority, -
      requested['rationale'])
  end
  do id over scenario~placements~allIndexes
    requested = scenario~placements[id]
    projected~links~placement(id,requested['locality'],scenario~authority, -
      requested['evidence'])
  end
  do id over scenario~capabilityPlacements~allIndexes
    row = scenario~capabilityPlacements[id]
    projected~capabilities~place(id,row['layer'],row['owner'], -
      row['recordAuthority'],row['boundary'],scenario~authority, -
      row['rationale'],row['evidence'])
  end
  do id over scenario~quotes~allIndexes
    q = scenario~quotes[id]
    projected~quote(q['resource'],q['rate'],q['monthlyQuantity'], -
      q['currency'],q['basis'],q['evidence'])
  end
  return projected

::method appendUnique private
  use strict arg list, member
  do existing over list
    if existing == member then return
  end
  list~append(member)

/* Side-by-side matrices are factual, not a fabricated optimisation score.
 * Complete but externally supplied quotes are still assumptions only.
 * Never designate a winner before compliance, target and SSC validation.
 */
::method compare
  use strict arg project
  if \project~isA(.ArchitectureProject) then -
    raise syntax 93.900 array('ARCH_SCENARIO_PROJECT_REQUIRED')
  if self~scenarios~items == 0 then -
    raise syntax 93.900 array('ARCH_SCENARIOS_REQUIRED')
  rows = .Array~new
  unionComponents = .Array~new
  forChoices = .Array~new
  forLinks = .Array~new
  do scenario over self~scenarios
    projected = self~projectScenario(project,scenario)
    plan = self~planner~plan(projected)
    item = .Directory~new
    item['id'] = scenario~id
    item['label'] = scenario~label
    item['rationale'] = scenario~rationale
    item['authority'] = scenario~authority
    item['state'] = plan['state']
    item['issueCount'] = plan['issues']~items
    item['openQuestionCount'] = plan['openQuestions']~items
    item['plan'] = plan
    rows~append(item)
    do dep over plan['buildRequest']['requirements']
      self~appendUnique(unionComponents,dep['componentId'])
    end
    do q over self~planner~catalog~questions
      self~appendUnique(forChoices,q['id'])
    end
    do edge over plan['interconnects']['edges']
      self~appendUnique(forLinks,edge['id'])
    end
  end
  dependencyMatrix = .Array~new
  do componentId over unionComponents
    record = .Directory~new
    record['componentId'] = componentId
    record['selectionByScenario'] = .Directory~new
    do item over rows
      present = .JSON~false
      do dep over item['plan']['buildRequest']['requirements']
        if dep['componentId'] == componentId then present = .JSON~true
      end
      record['selectionByScenario'][item['id']] = present
    end
    dependencyMatrix~append(record)
  end
  decisionMatrix = .Array~new
  do questionId over forChoices
    record = .Directory~new
    record['questionId'] = questionId
    record['choiceByScenario'] = .Directory~new
    do item over rows
      value = ''
      answers = item['plan']['effectiveAnswers']
      if answers~hasIndex(questionId) then value = answers[questionId]
      record['choiceByScenario'][item['id']] = value
    end
    decisionMatrix~append(record)
  end
  /* Business capabilities are invariant requirements, but their responsible
   * runtime owner/placement may differ by scenario. */
  capabilityMatrix = .Array~new
  do capId over self~planner~catalog~definition['businessCapabilities']~allIndexes
    row = .Directory~new
    row['capabilityId'] = capId
    row['scopeByScenario'] = .Directory~new
    row['ownerByScenario'] = .Directory~new
    row['layerByScenario'] = .Directory~new
    do item over rows
      projection = item['plan']['businessCapabilities']
      scope = 'UNASSESSED'
      owner = 'UNASSIGNED'
      layer = ''
      if projection['assessments']~hasIndex(capId) then -
        scope = projection['assessments'][capId]['state']
      if projection['placements']~hasIndex(capId) then do
        owner = projection['placements'][capId]['ownerComponent']
        layer = projection['placements'][capId]['layer']
      end
      row['scopeByScenario'][item['id']] = scope
      row['ownerByScenario'][item['id']] = owner
      row['layerByScenario'][item['id']] = layer
    end
    capabilityMatrix~append(row)
  end
  linkMatrix = .Array~new
  do linkId over forLinks
    record = .Directory~new
    record['linkId'] = linkId
    record['bindingByScenario'] = .Directory~new
    record['placementByScenario'] = .Directory~new
    record['qualificationByScenario'] = .Directory~new
    do item over rows
      binding = ''
      placement = 'UNKNOWN'
      qualification = 'NOT_PROBED'
      do edge over item['plan']['interconnects']['edges']
        if edge['id'] == linkId then do
          binding = edge['binding']
          placement = edge['placement']
        end
      end
      do review over item['plan']['connectSelectorReviews']
        if review['edgeId'] == linkId then qualification = review['status']
      end
      record['bindingByScenario'][item['id']] = binding
      record['placementByScenario'][item['id']] = placement
      record['qualificationByScenario'][item['id']] = qualification
    end
    linkMatrix~append(record)
  end
  operationalMatrix = .Array~new
  do item over rows
    plan = item['plan']
    oper = .Directory~new
    oper['scenarioId'] = item['id']
    answers = plan['effectiveAnswers']
    oper['deploymentModel'] = ''
    oper['deploymentTarget'] = ''
    oper['storageModel'] = ''
    oper['identityBoundary'] = ''
    if answers~hasIndex('deployment_model') then oper['deploymentModel'] = answers['deployment_model']
    if answers~hasIndex('deployment_target') then oper['deploymentTarget'] = answers['deployment_target']
    if answers~hasIndex('storage') then oper['storageModel'] = answers['storage']
    if answers~hasIndex('identity_boundary') then oper['identityBoundary'] = answers['identity_boundary']
    oper['unresolvedQuestionCount'] = plan['openQuestions']~items
    oper['policyAndValidationIssueCount'] = plan['issues']~items
    oper['unqualifiedIntegrationCount'] = plan['buildRequest']['externalIntegrationRequirements']~items
    oper['costOptimisationHypotheses'] = plan['costOptimisation']
    oper['runtimeComponentsAwaitingSSCResolution'] = plan['buildRequest']['requirements']~items
    oper['deploymentVerified'] = .JSON~false
    oper['recoveryVerified'] = .JSON~false
    oper['operatingCostComplete'] = .JSON~false
    operationalMatrix~append(oper)
  end
  costMatrix = .Array~new
  do item over rows
    row = .Directory~new
    row['scenarioId'] = item['id']
    projection = item['plan']['cost']
    row['status'] = projection['status']
    row['estimatedMonthly'] = projection['estimatedMonthly']
    if projection['quotedResources']~items == 0 & projection['missingQuotes']~items == 0 then do
      row['status'] = 'NO_COST_DRIVERS_MODELED'
      row['estimatedMonthly'] = .nil
    end
    row['currency'] = projection['currency']
    row['missingQuotes'] = projection['missingQuotes']
    row['source'] = 'EXPLICIT_SCENARIO_QUOTE_ASSUMPTIONS_NOT_VERIFIED_PRICES'
    costMatrix~append(row)
  end
  comparison = .Directory~new
  comparison['schema'] = 'alchemy.architecture.scenario-comparison/0.1'
  comparison['projectId'] = project~projectId
  comparison['projectName'] = project~projectName
  comparison['scenarioCount'] = rows~items
  comparison['scenarios'] = rows
  comparison['decisionMatrix'] = decisionMatrix
  comparison['dependencyMatrix'] = dependencyMatrix
  comparison['businessCapabilityMatrix'] = capabilityMatrix
  relationshipMatrix = .Array~new
  do relId over project~capabilityRelationships~relations~allIndexes
    record = .Directory~new
    record['relationId'] = relId
    record['statusByScenario'] = .Directory~new
    record['ownerByScenario'] = .Directory~new
    do item over rows
      do rel over item['plan']['capabilityRelationships']['relationships']
        if rel['id'] == relId then do
          record['statusByScenario'][item['id']] = rel['status']
          record['ownerByScenario'][item['id']] = -
            rel['sourceOwner']' -> 'rel['targetOwner']
        end
      end
    end
    relationshipMatrix~append(record)
  end
  comparison['capabilityRelationshipMatrix'] = relationshipMatrix
  comparison['interconnectMatrix'] = linkMatrix
  comparison['costMatrix'] = costMatrix
  comparison['operationalMatrix'] = operationalMatrix
  comparison['businessBaseline'] = 'Same scope, features, scoped ground rules, compliance and interconnect intentions'
  comparison['priceAuthority'] = 'No inherited price, no price lookup; explicit scenario-sourced assumptions only'
  comparison['recommendation'] = .nil
  comparison['rankingStatus'] = 'NOT_QUALIFIED_FOR_AUTOMATIC_RECOMMENDATION'
  comparison['remainingAuthorities'] = .Array~of( -
    'Business scope and option acceptance by project owner', -
    'Policy control evidence and approval by policy authority', -
    'ConnectSelector and carrier/target qualification', -
    'SSC immutable semantic dependency resolution and content locking', -
    'Deployment capacity, loadability, recovery and target verification', -
    'Comparable verified prices, taxes, licences and operational assumptions')
  comparison['executable'] = .JSON~false
  return comparison
