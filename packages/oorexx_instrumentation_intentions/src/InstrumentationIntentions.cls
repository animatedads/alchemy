/* InstrumentationIntentions.cls
 * Read-only specialist intentions over instrumentation.mesh/0.1.
 *
 * Instrumentation Mesh owns operational evidence, history and time-series.
 * This package owns only the language by which Management can discover that
 * evidence.  It does not publish instrumentation, execute service commands or
 * acquire transport authority.
 */

::class InstrumentationIntentionsBuild public
::constant VERSION '0.1-dev2'
::constant PROVIDER_API 'instrumentation.intentions/0.1'

/* Associates stable Instrumentation semantic references with the original
 * authoritative estate objects.  The binding does not own either object. */
::class InstrumentationSemanticBindingRegistry public
::method init
  self~objects = .Directory~new
  self~aliases = .Directory~new
::attribute objects
::attribute aliases

::method register
  use arg object, semanticRef, aliases=.nil
  if object == .nil then raise syntax 93.900 array('Instrumentation binding object must not be NIL')
  ref = strip(semanticRef)
  if ref == '' then raise syntax 93.900 array('Instrumentation semantic_ref must not be empty')
  self~objects[ref] = object
  if aliases == .nil then aliases = .Array~new
  self~aliases[ref] = aliases
  return object

::method objectFor
  use arg semanticRef
  return self~objects[semanticRef]

::method aliasesFor
  use arg semanticRef
  a = self~aliases[semanticRef]
  if a == .nil then return .Array~new
  return a

/* Read-only frontage over the current collector.  It deliberately exposes no
 * command method even though Instrumentation Mesh itself supports separately
 * authorised management command envelopes. */
::class InstrumentationReadAuthority public
::method init
  use arg collector
  if collector == .nil then raise syntax 93.900 array('Instrumentation collector must not be NIL')
  self~collector = collector
::attribute collector

::method latest
  use arg selector=.nil
  return self~collector~latest(selector)
::method latestBySemanticRef
  use arg semanticRef
  return self~collector~latestBySemanticRef(semanticRef)
::method historyBySemanticRef
  use arg semanticRef, limit=0
  return self~collector~historyBySemanticRef(semanticRef, limit)
::method series
  use arg semanticRef, metricName, dimensions=.nil, limit=0
  return self~collector~series(semanticRef, metricName, dimensions, limit)
::method events
  use arg selector=.nil, limit=0
  return self~collector~eventsHistory(selector, limit)
::method relationships
  use arg selector=.nil
  return self~collector~latestRelationships(selector)
::method relationshipSets
  use arg selector=.nil
  return self~collector~latestRelationshipSets(selector)
::method relationshipHistory
  use arg selector=.nil, limit=0
  return self~collector~relationshipSetHistory(selector, limit)
::method correlations
  use arg selector=.nil, limit=0
  return .InstrumentationCorrelationView~new(self~collector)~groups(selector, limit)
::method correlationById
  use arg correlationId, limit=0
  return .InstrumentationCorrelationView~new(self~collector)~byId(correlationId, limit)
::method correlationsForRefs
  use arg refs, limit=0
  return .InstrumentationCorrelationView~new(self~collector)~forRefs(refs, limit)
::method freshness
  use arg semanticRef, nowPosixSeconds, freshWithinSeconds=30, staleAfterSeconds=120
  return .InstrumentationFreshnessAssessor~new(self~collector)~assess(semanticRef, nowPosixSeconds, freshWithinSeconds, staleAfterSeconds)

::class InstrumentationIntentionProvider public
::method init
  use arg collectorOrReadAuthority, bindingRegistry=.nil
  if collectorOrReadAuthority == .nil then raise syntax 93.900 array('Instrumentation read authority must not be NIL')
  if collectorOrReadAuthority~isA(.InstrumentationReadAuthority) then self~readAuthority = collectorOrReadAuthority
  else self~readAuthority = .InstrumentationReadAuthority~new(collectorOrReadAuthority)
  if bindingRegistry == .nil then bindingRegistry = .InstrumentationSemanticBindingRegistry~new
  self~bindings = bindingRegistry
  self~generation = 0
::attribute readAuthority
::attribute bindings
::attribute generation

::method providerId
  return 'instrumentation.intentions/0.1'

::method discover
  use arg context=.nil
  self~generation += 1
  selector = .nil
  eventSelector = .nil
  nowPosix = .nil
  freshWithin = 30
  staleAfter = 120
  if context <> .nil then do
    if context~isA(.Directory) then do
      if context~hasIndex('instrumentationSelector') then selector = context['instrumentationSelector']
      if context~hasIndex('instrumentationEventSelector') then eventSelector = context['instrumentationEventSelector']
      if context~hasIndex('nowPosixSeconds') then nowPosix = context['nowPosixSeconds']
      if context~hasIndex('freshWithinSeconds') then freshWithin = context['freshWithinSeconds']
      if context~hasIndex('staleAfterSeconds') then staleAfter = context['staleAfterSeconds']
    end
  end
  snapshots = self~readAuthority~latest(selector)
  events = self~readAuthority~events(eventSelector, 0)
  relationships = self~readAuthority~relationships(selector)
  correlations = self~readAuthority~correlations(eventSelector, 0)
  freshness = .Directory~new
  if nowPosix <> .nil then do snapshot over snapshots
    ref = snapshot['semantic_ref']
    freshness[ref] = self~readAuthority~freshness(ref, nowPosix, freshWithin, staleAfter)
  end
  surface = .Directory~new
  surface['provider'] = self~providerId
  surface['authority'] = 'INSTRUMENTATION'
  surface['subjectKinds'] = .Array~of('INSTRUMENTED_SERVICE', 'INSTRUMENTATION_SNAPSHOT', 'METRIC_SERIES', 'OPERATION_PROGRESS', 'OPERATIONAL_EVENT', 'OBSERVED_RELATIONSHIP', 'CORRELATION_GROUP', 'PUBLICATION_FRESHNESS')
  surface['operations'] = .Array~of('LIST_INSTRUMENTED_SERVICES', 'GET_LATEST_HEALTH', 'GET_LATEST_METRICS', 'GET_METRIC_HISTORY', 'GET_METRIC_SERIES', 'GET_OPERATION_PROGRESS', 'LIST_OPERATIONAL_EVENTS', 'EXPLAIN_OPERATIONAL_EVENT', 'LIST_OBSERVED_RELATIONSHIPS', 'GET_CORRELATION', 'LIST_CORRELATIONS', 'GET_PUBLICATION_FRESHNESS', 'EXPLAIN_INSTRUMENTATION')
  surface['mutating'] = .false
  surface['generation'] = self~generation
  surface['snapshots'] = snapshots
  surface['events'] = events
  surface['relationships'] = relationships
  surface['correlations'] = correlations
  surface['freshness'] = freshness
  surface['readAuthority'] = self~readAuthority
  surface['context'] = context
  return surface

::method assessRelevance
  use arg request, surface, context=.nil
  text = self~normalize(request)
  matchedSnapshots = .Array~new
  matchedObjects = .Array~new
  matchedEvents = .Array~new
  matchedRelationships = .Array~new
  matchedCorrelations = .Array~new
  score = self~domainScore(text)
  do snapshot over surface['snapshots']
    if self~snapshotMatches(text, snapshot) then do
      matchedSnapshots~append(snapshot)
      ref = snapshot['semantic_ref']
      object = self~bindings~objectFor(ref)
      if object <> .nil then self~appendUnique(matchedObjects, object)
      score = max(score, 94)
    end
  end
  do event over surface['events']
    if self~eventMatches(text, event) then do
      matchedEvents~append(event)
      object = self~bindings~objectFor(event['subject_ref'])
      if object <> .nil then self~appendUnique(matchedObjects, object)
      score = max(score, 94)
    end
  end
  do relation over surface['relationships']
    if self~relationshipMatches(text, relation) then do
      matchedRelationships~append(relation)
      score = max(score, 90)
    end
  end
  do group over surface['correlations']
    if self~correlationMatches(text, group) then do
      matchedCorrelations~append(group)
      score = max(score, 95)
    end
  end
  evidence = .Directory~new
  evidence['surface'] = surface
  evidence['objects'] = matchedObjects
  evidence['snapshots'] = matchedSnapshots
  evidence['events'] = matchedEvents
  evidence['relationships'] = matchedRelationships
  evidence['correlations'] = matchedCorrelations
  if score = 0 then return .InstrumentationRelevanceAssessment~new(.false, 0, 'INSTRUMENTATION', 'INSTRUMENTATION_INTENTION_UNKNOWN', evidence)
  return .InstrumentationRelevanceAssessment~new(.true, score, 'INSTRUMENTATION', 'INSTRUMENTATION_INTENTION_MATCH', evidence)

::method snapshotMatches private
  use arg text, snapshot
  if snapshot == .nil then return .false
  ref = self~normalize(snapshot['semantic_ref'])
  if ref <> '' & pos(ref, text) > 0 then return .true
  identity = snapshot['identity']
  if identity == .nil then return .false
  do key over .Array~of('service_id','instance_id','node_id','mi_id','service_kind')
    value = identity[key]
    if value <> .nil then do
      v = self~normalize(value)
      if v <> '' & pos(v, text) > 0 then return .true
    end
  end
  aliases = self~bindings~aliasesFor(snapshot['semantic_ref'])
  do alias over aliases
    a = self~normalize(alias)
    if a <> '' & pos(a, text) > 0 then return .true
  end
  return .false

::method eventMatches private
  use arg text, event
  do key over .Array~of('event_id','kind','subject_ref','authority','correlation_id','causation_id','operation_id')
    value = event[key]
    if value <> .nil then do
      v = self~normalize(value)
      if v <> '' & pos(v, text) > 0 then return .true
    end
  end
  subject = event['subject_ref']
  if subject <> .nil then do alias over self~bindings~aliasesFor(subject)
    a = self~normalize(alias)
    if a <> '' & pos(a, text) > 0 then return .true
  end
  return .false

::method relationshipMatches private
  use arg text, relation
  do key over .Array~of('relationship_id','kind','from_ref','to_ref','authority')
    value = relation[key]
    if value <> .nil then do
      v = self~normalize(value)
      if v <> '' & pos(v, text) > 0 then return .true
    end
  end
  return .false

::method correlationMatches private
  use arg text, group
  value = group['correlation_id']
  if value <> .nil then do
    v = self~normalize(value)
    if v <> '' & pos(v, text) > 0 then return .true
  end
  do key over .Array~of('subject_refs','related_refs','context_refs','authorities','kinds')
    values = group[key]
    if values <> .nil then do item over values
      v = self~normalize(item)
      if v <> '' & pos(v, text) > 0 then return .true
    end
  end
  return .false

::method domainScore private
  use arg text
  score = 0
  if self~hasWord(text, 'TELEMETRY') then score = max(score, 92)
  if self~hasWord(text, 'INSTRUMENTATION') then score = max(score, 94)
  if self~hasWord(text, 'METRIC') | self~hasWord(text, 'METRICS') then score = max(score, 90)
  if self~hasWord(text, 'HEALTH') then score = max(score, 82)
  if self~hasWord(text, 'EVENT') | self~hasWord(text, 'EVENTS') then score = max(score, 90)
  if self~hasWord(text, 'CORRELATION') | self~hasWord(text, 'CORRELATED') then score = max(score, 94)
  if self~hasWord(text, 'CAUSATION') | self~hasWord(text, 'CAUSE') then score = max(score, 88)
  if self~hasWord(text, 'RELATIONSHIP') | self~hasWord(text, 'RELATIONSHIPS') then score = max(score, 88)
  if self~hasWord(text, 'FRESH') | self~hasWord(text, 'FRESHNESS') | self~hasWord(text, 'STALE') then score = max(score, 90)
  if self~hasWord(text, 'COUNTER') | self~hasWord(text, 'COUNTERS') then score = max(score, 88)
  if self~hasWord(text, 'GAUGE') | self~hasWord(text, 'GAUGES') then score = max(score, 88)
  if self~hasWord(text, 'PROGRESS') then score = max(score, 88)
  if self~hasWord(text, 'HISTORY') then score = max(score, 86)
  if self~hasWord(text, 'SERIES') then score = max(score, 86)
  if self~hasPhrase(text, 'HOW MUCH WORK') then score = max(score, 84)
  if self~hasPhrase(text, 'HOW IS') & self~hasWord(text, 'DOING') then score = max(score, 82)
  return score

::method appendUnique private
  use arg array, object
  do existing over array
    if existing == object then return object
  end
  array~append(object)
  return object

::method normalize private
  use arg value
  if value == .nil then return ''
  return translate(strip(value~string))
::method hasWord private
  use arg text, word
  return pos(' ' || word || ' ', ' ' || text || ' ') > 0
::method hasPhrase private
  use arg text, phrase
  return pos(phrase, text) > 0

/* Assessment is intentionally duck-compatible with Management's relevance
 * candidate contract, avoiding a dependency from this specialist back upward
 * into Management Intention Discovery. */
::class InstrumentationRelevanceAssessment public
::method init
  use arg relevant, score=0, authority='', reason='', evidence=.nil
  self~relevant = relevant
  self~score = score
  self~authority = authority
  self~reason = reason
  self~evidence = evidence
::attribute relevant
::attribute score
::attribute authority
::attribute reason
::attribute evidence

/* Read-only relationship projection from an authoritative service object to
 * the collector's detached latest snapshot.  Snapshot remains evidence, not a
 * service-control object. */
::class InstrumentationRelationshipProvider public
::method init
  use arg intentionProvider
  if intentionProvider == .nil then raise syntax 93.900 array('Instrumentation relationship provider requires intention provider')
  self~intentionProvider = intentionProvider
::attribute intentionProvider

::method discoverRelationships
  use arg context=.nil
  surface = self~intentionProvider~discover(context)
  out = .Array~new
  serial = 0
  do snapshot over surface['snapshots']
    ref = snapshot['semantic_ref']
    object = self~intentionProvider~bindings~objectFor(ref)
    if object == .nil then iterate
    serial += 1
    evidence = .Directory~new
    evidence['semantic_ref'] = ref
    evidence['observed_at'] = snapshot['observed_at']
    evidence['health'] = snapshot['health']
    out~append(.InstrumentationPublishedRelationship~new('instrumentation-' || serial, 'HAS_INSTRUMENTATION_SNAPSHOT', object, snapshot, 'INSTRUMENTATION_MESH', evidence))
  end
  return out

/* Relationship object is shaped like ManagementRelationship but deliberately
 * defined here so the instrumentation specialist has no upward dependency. */
::class InstrumentationPublishedRelationship public
::method init
  use arg id, kind, fromObject, toObject, authority='', evidence=.nil
  self~id=id; self~kind=kind; self~fromObject=fromObject; self~toObject=toObject; self~authority=authority; self~evidence=evidence
::attribute id
::attribute kind
::attribute fromObject
::attribute toObject
::attribute authority
::attribute evidence

/* Adapter from socket.telemetry/0.1 events into an InstrumentationEmitter.
 * Only generic transport dimensions are retained.  Endpoint identity, logical
 * service names, security profiles and payloads never cross this adapter. */
::class SocketTelemetryInstrumentationObserver public
::method init
  use arg emitter
  if emitter == .nil then raise syntax 93.900 array('Socket telemetry instrumentation adapter requires emitter')
  self~emitter = emitter
::attribute emitter

::method record
  use arg event
  if event == .nil then return .false
  facts = event~facts
  if facts == .nil then facts = .Directory~new
  dimensions = self~safeDimensions(facts)
  name = event~name
  self~emitter~counterAdd(name || '.total', 1, 'events', dimensions)

  metric = facts['metric']
  if metric <> .nil then do
    value = facts['value']; if value == .nil then value = 0
    select
      when metric == 'socket.io.bytes.in' then self~emitter~counterAdd(.InstrumentationVocabulary~BYTES_IN_TOTAL, value, 'bytes', dimensions)
      when metric == 'socket.io.bytes.out' then self~emitter~counterAdd(.InstrumentationVocabulary~BYTES_OUT_TOTAL, value, 'bytes', dimensions)
      otherwise self~emitter~counterAdd(metric, value, 'count', dimensions)
    end
  end

  gauge = facts['gauge']
  if gauge <> .nil then do
    delta = facts['delta']; if delta == .nil then delta = 0
    current = self~emitter~gaugeValue(gauge)
    self~emitter~gaugeSet(gauge, current + delta, 'count', dimensions)
  end
  return .true

::method safeDimensions private
  use arg facts
  out = .Directory~new
  do key over .Array~of('transport','scheme','addressFamily','multicast','role')
    value = facts[key]
    if value <> .nil then out[key] = value
  end
  return out

::requires 'InstrumentationMesh.cls'
::requires 'InstrumentationAnalysis.cls'
::requires 'InstrumentationCorrelation.cls'
