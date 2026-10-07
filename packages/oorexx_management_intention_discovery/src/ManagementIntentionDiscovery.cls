/* Management Intention Discovery v0.1-dev7
 *
 * Discovery/router layer for management intention surfaces.
 *
 * This package owns no machine, service, network, cloud, MVS, GPU, LLM,
 * RexxOS, compute, policy, credential or execution state.  Domain adapters
 * discover their own current surfaces and assess their own relevance.
 */

::class ManagementIntentionDirectory public
::method init
  self~sources = .array~new
  self~generation = 0

::attribute sources
::attribute generation

::method registerSource
  use arg source
  if source == .nil then raise syntax 93.900 array('Management intention source must not be NIL')
  self~sources~append(source)
  return source

::method discover
  use arg context=.nil
  self~generation += 1
  snapshot = .ManagementSurfaceSnapshot~new(self~generation, context)
  do source over self~sources
    discovered = source~discover(context)
    if discovered == .nil then iterate
    entry = .ManagementSurfaceEntry~new(source, discovered)
    snapshot~add(entry)
  end
  return snapshot

/*
 * Resolve does fresh discovery every time.  It does not classify domains
 * itself: each registered source owns its relevance assessment.
 * Multiple sources may be selected because management questions often cross
 * machine/service/network/guest/resource authority boundaries.
 */
::method resolve
  use arg request, context=.nil
  snapshot = self~discover(context)
  resolution = .ManagementSurfaceResolution~new(request, context, snapshot)
  do entry over snapshot~entries
    assessment = entry~source~assessRelevance(request, entry~surface, context)
    if assessment == .nil then iterate
    candidate = .ManagementSurfaceCandidate~new(entry, assessment)
    resolution~addCandidate(candidate)
  end
  return resolution

::class ManagementSurfaceSnapshot public
::method init
  use arg generation, context=.nil
  self~generation = generation
  self~context = context
  self~entries = .array~new

::attribute generation
::attribute context
::attribute entries

::method add
  use arg entry
  self~entries~append(entry)
  return entry

::class ManagementSurfaceEntry public
::method init
  use arg source, surface
  self~source = source
  self~surface = surface

::attribute source
::attribute surface

::method sourceId
  return self~source~sourceId

::class ManagementSurfaceResolution public
::method init
  use arg request, context, snapshot
  self~request = request
  self~context = context
  self~snapshot = snapshot
  self~candidates = .array~new

::attribute request
::attribute context
::attribute snapshot
::attribute candidates

::method addCandidate
  use arg candidate
  self~candidates~append(candidate)
  return candidate

::method relevantCandidates
  out = .array~new
  do candidate over self~candidates
    if candidate~isRelevant then out~append(candidate)
  end
  return out

::method relevantSurfaces
  out = .array~new
  do candidate over self~relevantCandidates
    out~append(candidate~entry~surface)
  end
  return out

::method preferredCandidate
  relevant = self~relevantCandidates
  if relevant~items = 0 then return .nil
  best = relevant[1]
  do i = 2 to relevant~items
    candidate = relevant[i]
    if candidate~score > best~score then best = candidate
  end
  return best

::class ManagementSurfaceCandidate public
::method init
  use arg entry, assessment
  self~entry = entry
  self~assessment = assessment

::attribute entry
::attribute assessment

::method isRelevant
  return self~assessment~relevant

::method score
  return self~assessment~score

::class ManagementRelevanceAssessment public
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

/*
 * Domain bridge contract.  The bridge does not become authoritative for the
 * domain; it merely calls the existing provider and a domain-owned relevance
 * assessor.  Returned surface objects are preserved intact.
 */
::class ManagementIntentionSurfaceSource public
::method init
  use arg sourceId, provider, relevanceAssessor
  if sourceId == '' then raise syntax 93.900 array('Management intention source id must not be empty')
  if provider == .nil then raise syntax 93.900 array('Management intention provider must not be NIL')
  if relevanceAssessor == .nil then raise syntax 93.900 array('Management relevance assessor must not be NIL')
  self~sourceIdValue = sourceId
  self~provider = provider
  self~relevanceAssessor = relevanceAssessor

::attribute sourceIdValue
::attribute provider
::attribute relevanceAssessor

::method sourceId
  return self~sourceIdValue

::method discover
  use arg context=.nil
  return self~provider~discover(context)

::method assessRelevance
  use arg request, surface, context=.nil
  return self~relevanceAssessor~assess(request, surface, context)


/* Generic source for domain intention providers that own both their discovery
 * projection and their relevance semantics.  Management remains a caller of
 * that contract; it does not copy the provider's vocabulary or object model. */
::class ManagementSelfAssessingIntentionSurfaceSource public
::method init
  use arg sourceId, provider
  if sourceId == '' then raise syntax 93.900 array('Management intention source id must not be empty')
  if provider == .nil then raise syntax 93.900 array('Management intention provider must not be NIL')
  self~sourceIdValue = sourceId
  self~provider = provider

::attribute sourceIdValue
::attribute provider

::method sourceId
  return self~sourceIdValue

::method discover
  use arg context=.nil
  return self~provider~discover(context)

::method assessRelevance
  use arg request, surface, context=.nil
  return self~provider~assessRelevance(request, surface, context)

::class ManagementRelevanceAssessor public
::method assess abstract

/* ---- Generic relationship-discovery extension (dev4) ---- */
::class ManagementRelationshipDirectory public
::method init
  self~sources = .Array~new
  self~generation = 0
::attribute sources
::attribute generation
::method registerSource
  use arg source
  if source == .nil then raise syntax 93.900 array('Management relationship source must not be NIL')
  self~sources~append(source)
  return source
::method discover
  use arg context=.nil
  self~generation += 1
  snapshot = .ManagementRelationshipSnapshot~new(self~generation, context)
  do source over self~sources
    relationships = source~discoverRelationships(context)
    if relationships == .nil then iterate
    do relationship over relationships
      snapshot~add(.ManagementRelationshipEntry~new(source, relationship))
    end
  end
  return snapshot

/* Bounded undirected reachability over published directed edges.  Direction is
 * retained on each edge; traversal does not infer or manufacture inverse edges. */
::method expand
  use arg seeds, context=.nil, maxDepth=3
  if seeds == .nil then seeds = .Array~new
  if \datatype(maxDepth, 'W') | maxDepth < 0 then raise syntax 93.900 array('Relationship traversal depth must be a non-negative whole number')
  snapshot = self~discover(context)
  expansion = .ManagementRelationshipExpansion~new(snapshot, seeds, maxDepth)
  frontier = .Array~new
  do seed over seeds
    if expansion~addObject(seed, 0) then frontier~append(seed)
  end
  depth = 0
  do while depth < maxDepth & frontier~items > 0
    nextFrontier = .Array~new
    do object over frontier
      do entry over snapshot~entries
        relation = entry~relationship
        adjacent = .nil
        if relation~fromObject == object then adjacent = relation~toObject
        else if relation~toObject == object then adjacent = relation~fromObject
        if adjacent == .nil then iterate
        expansion~addEdge(entry)
        if expansion~addObject(adjacent, depth + 1) then nextFrontier~append(adjacent)
      end
    end
    frontier = nextFrontier
    depth += 1
  end
  return expansion

::requires 'ManagementRelationships.cls'
