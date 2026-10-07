/* ManagementRelationships.cls
 * Generic relationship discovery/traversal for Management Intention Discovery.
 *
 * Management does not assign domain meaning to relationship kinds.  Domain
 * authorities publish edges between the original authoritative objects.  This
 * layer preserves those object references, provenance and direction and can
 * perform bounded graph expansion without knowing what HOSTS, RUNS_ON, GUEST_OF,
 * USES_NETWORK or any future relationship means.
 */

::class ManagementRelationship public
::method init
  use arg id, kind, fromObject, toObject, authority='', evidence=.nil
  if id == '' then raise syntax 93.900 array('Management relationship id must not be empty')
  if kind == '' then raise syntax 93.900 array('Management relationship kind must not be empty')
  if fromObject == .nil | toObject == .nil then raise syntax 93.900 array('Management relationship endpoints must not be NIL')
  self~id = id
  self~kind = kind
  self~fromObject = fromObject
  self~toObject = toObject
  self~authority = authority
  self~evidence = evidence
::attribute id
::attribute kind
::attribute fromObject
::attribute toObject
::attribute authority
::attribute evidence

::class ManagementRelationshipSource public
::method sourceId abstract
::method discoverRelationships abstract

/* Adapter for a domain-owned relationship provider. */
::class ManagementRelationshipProviderSource public subclass ManagementRelationshipSource
::method init
  use arg sourceId, provider
  if sourceId == '' then raise syntax 93.900 array('Management relationship source id must not be empty')
  if provider == .nil then raise syntax 93.900 array('Management relationship provider must not be NIL')
  self~sourceIdValue = sourceId
  self~provider = provider
::attribute sourceIdValue
::attribute provider
::method sourceId
  return self~sourceIdValue
::method discoverRelationships
  use arg context=.nil
  return self~provider~discoverRelationships(context)

::class ManagementRelationshipEntry public
::method init
  use arg source, relationship
  self~source = source
  self~relationship = relationship
::attribute source
::attribute relationship

::class ManagementRelationshipSnapshot public
::method init
  use arg generation, context=.nil
  self~generation = generation
  self~context = context
  self~entries = .Array~new
::attribute generation
::attribute context
::attribute entries
::method add
  use arg entry
  self~entries~append(entry)
  return entry

::class ManagementRelationshipExpansion public
::method init
  use arg snapshot, seeds, maxDepth
  self~snapshot = snapshot
  self~seeds = seeds
  self~maxDepth = maxDepth
  self~objects = .Array~new
  self~objectDepths = .Array~new
  self~edges = .Array~new
::attribute snapshot
::attribute seeds
::attribute maxDepth
::attribute objects
::attribute objectDepths
::attribute edges

::method addObject
  use arg object, depth
  do existing over self~objects
    if existing == object then return .false
  end
  self~objects~append(object)
  self~objectDepths~append(depth)
  return .true

::method addEdge
  use arg entry
  do existing over self~edges
    if existing~source == entry~source & existing~relationship == entry~relationship then return existing
  end
  self~edges~append(entry)
  return entry

::method contains
  use arg object
  do existing over self~objects
    if existing == object then return .true
  end
  return .false

::method depthOf
  use arg object
  do i = 1 to self~objects~items
    if self~objects[i] == object then return self~objectDepths[i]
  end
  return .nil

/* Generic publisher adapter for domain objects that themselves expose their
 * current relationship edges.  The provider does not interpret relationship
 * kinds and does not synthesize missing edges. */
::class ObjectPublishedRelationshipProvider public
::method init
  use arg objectDiscoverer
  if objectDiscoverer == .nil then raise syntax 93.900 array('Relationship object discoverer must not be NIL')
  self~objectDiscoverer = objectDiscoverer
::attribute objectDiscoverer
::method discoverRelationships
  use arg context=.nil
  objects = self~objectDiscoverer~discoverObjects(context)
  if objects == .nil then objects = .Array~new
  out = .Array~new
  do object over objects
    if \object~hasMethod('managementRelationships') then iterate
    relationships = object~managementRelationships(context)
    if relationships == .nil then iterate
    do relationship over relationships
      out~append(relationship)
    end
  end
  return out

/* Combines intention relevance and generic relationship expansion. */
::class ManagementIntentionExplorer public
::method init
  use arg intentionDirectory, relationshipDirectory, relatedSurfaceDiscovery=.nil
  if intentionDirectory == .nil | relationshipDirectory == .nil then -
    raise syntax 93.900 array('Management explorer requires intention and relationship directories')
  if relatedSurfaceDiscovery == .nil then relatedSurfaceDiscovery = .ManagementRelatedSurfaceDiscovery~new
  self~intentionDirectory = intentionDirectory
  self~relationshipDirectory = relationshipDirectory
  self~relatedSurfaceDiscovery = relatedSurfaceDiscovery
::attribute intentionDirectory
::attribute relationshipDirectory
::attribute relatedSurfaceDiscovery

::method explore
  use arg request, context=.nil, maxDepth=3
  baseResolution = self~intentionDirectory~resolve(request, context)
  seeds = self~matchedObjects(baseResolution)
  expansion = self~relationshipDirectory~expand(seeds, context, maxDepth)
  advertised = self~relatedSurfaceDiscovery~discover(request, expansion~objects, context)
  return .ManagementExploration~new(baseResolution, expansion, advertised)

::method matchedObjects private
  use arg resolution
  out = .Array~new
  do candidate over resolution~relevantCandidates
    evidence = candidate~assessment~evidence
    if evidence == .nil then iterate
    if \evidence~isA(.Directory) then iterate
    if \evidence~hasIndex('objects') then iterate
    objects = evidence['objects']
    if objects == .nil then iterate
    do object over objects
      duplicate = .false
      do existing over out
        if existing == object then do; duplicate = .true; leave; end
      end
      if \duplicate then out~append(object)
    end
  end
  return out

::class ManagementExploration public
::method init
  use arg resolution, relationshipExpansion, advertisedCandidates=.nil
  if advertisedCandidates == .nil then advertisedCandidates = .Array~new
  self~resolution = resolution
  self~relationshipExpansion = relationshipExpansion
  self~advertisedCandidates = advertisedCandidates
::attribute resolution
::attribute relationshipExpansion
::attribute advertisedCandidates
::method matchedObjects
  return self~relationshipExpansion~seeds
::method relatedObjects
  return self~relationshipExpansion~objects
::method relationships
  return self~relationshipExpansion~edges
::method relevantAdvertisedCandidates
  out = .Array~new
  do candidate over self~advertisedCandidates
    if candidate~relevant then out~append(candidate)
  end
  return out
::method relevantAdvertisedSurfaces
  out = .Array~new
  do candidate over self~relevantAdvertisedCandidates
    out~append(candidate~surface)
  end
  return out

/* A related authoritative object may advertise zero or more intention-surface
 * sources which are valid for the current discovery context.  Management does
 * not register these globally and does not interpret their domain. */
::class ObjectPublishedIntentionSourceProvider public
::method discoverSources
  use arg objects, context=.nil
  out = .Array~new
  if objects == .nil then return out
  do object over objects
    if \object~hasMethod('managementIntentionSources') then iterate
    sources = object~managementIntentionSources(context)
    if sources == .nil then iterate
    do source over sources
      if source == .nil then iterate
      duplicate = .false
      do existing over out
        if existing == source then do; duplicate = .true; leave; end
      end
      if \duplicate then out~append(source)
    end
  end
  return out

::class ManagementRelatedSurfaceCandidate public
::method init
  use arg object, source, surface, assessment
  self~object = object
  self~source = source
  self~surface = surface
  self~assessment = assessment
::attribute object
::attribute source
::attribute surface
::attribute assessment
::method sourceId
  return self~source~sourceId
::method relevant
  return self~assessment~relevant
::method score
  return self~assessment~score

::class ManagementRelatedSurfaceDiscovery public
::method init
  use arg sourceProvider=.nil
  if sourceProvider == .nil then sourceProvider = .ObjectPublishedIntentionSourceProvider~new
  self~sourceProvider = sourceProvider
::attribute sourceProvider

/* Discover and assess surfaces advertised by the objects reached during this
 * exploration only.  Nothing is added to ManagementIntentionDirectory. */
::method discover
  use arg request, objects, context=.nil
  out = .Array~new
  if objects == .nil then return out
  do object over objects
    one = .Array~of(object)
    sources = self~sourceProvider~discoverSources(one, context)
    do source over sources
      surface = source~discover(context)
      if surface == .nil then iterate
      assessment = source~assessRelevance(request, surface, context)
      if assessment == .nil then iterate
      out~append(.ManagementRelatedSurfaceCandidate~new(object, source, surface, assessment))
    end
  end
  return out
