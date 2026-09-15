/*
 * Reputation Effect v0.2
 *
 * Independent, geographic, temporal and evidence-bearing reputation model.
 * It does not assign a universal reputation score to a person or organisation.
 * It evaluates a proposed action against a frozen world/reputation snapshot in
 * one or more geographic/audience contexts.
 */

::class ReputationEffectBuild public
::constant VERSION "0.2"
::constant API_VERSION "reputation.effect/0.2"
::constant PRODUCT "ooRexx Reputation Effect"

::class ReputationConstant public
::constant DISP_CLEAR "CLEAR"
::constant DISP_WARN "WARN"
::constant DISP_REVIEW "REVIEW"
::constant DISP_HOLD "HOLD"
::constant DISP_HOLD_REFRESH "HOLD_REFRESH_REQUIRED"
::constant DISP_CONFLICTED "GEOGRAPHICALLY_CONFLICTED"

::constant ITEM_CONCERN "CONCERN"
::constant ITEM_SUPPORT "SUPPORT"
::constant ITEM_INFORMATION "INFORMATION"

::constant PROP_NONE "NONE"
::constant PROP_DESCENDANTS "DESCENDANTS"
::constant PROP_ANCESTORS "ANCESTORS"
::constant PROP_BOTH "BOTH"

::class ReputationResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  value = valueArg

::method success class
  use arg valueArg = .nil, detailArg = ""
  return self~new(.true, "OK", detailArg, valueArg)

::method failure class
  use arg codeArg, detailArg = "", valueArg = .nil
  return self~new(.false, codeArg, detailArg, valueArg)


::class ReputationCanonical public
::method field class
  use arg tag, value = ""
  if value == .nil then rendered = "<NIL>"
  else rendered = value~string
  return tag~string || ":" || rendered~length || ":" || rendered

::method sortedStrings class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item~string)
  end
  out~sort
  return out

::method join class
  use arg tag, source
  sorted = self~sortedStrings(source)
  text = self~field(tag || "_COUNT", sorted~items)
  do item over sorted
    text ||= self~field(tag, item)
  end
  return text

::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out

::method containsString class
  use arg source, wanted
  wanted = wanted~string~upper
  if source == .nil then return .false
  do item over source
    if item~string~upper == wanted then return .true
  end
  return .false

::method clamp class
  use arg value, low = 0, high = 100
  numericValue = value + 0
  if numericValue < low then return low
  if numericValue > high then return high
  return numericValue


::class ReputationGeography public
::attribute geographyId get
::attribute geographyKind get
::attribute parentId get
::attribute label get

::method init
  expose geographyId geographyKind parentId label aliases marketRegions
  use arg geographyIdArg, geographyKindArg = "TERRITORY", parentIdArg = "", labelArg = ""
  geographyId = geographyIdArg~string~upper~strip
  geographyKind = geographyKindArg~string~upper~strip
  parentId = parentIdArg~string~upper~strip
  label = labelArg~string
  if geographyId = "" then raise syntax 88.900 array("ReputationGeography geographyId must not be empty")
  aliases = .array~new
  marketRegions = .array~new

::method addAlias
  expose aliases
  use arg value
  if value~string~strip <> "" then aliases~append(value~string)
  return self

::method addMarketRegion
  expose marketRegions
  use arg value
  if value~string~strip <> "" then marketRegions~append(value~string~upper)
  return self

::method aliases
  expose aliases
  return .ReputationCanonical~copyArray(aliases)

::method marketRegions
  expose marketRegions
  return .ReputationCanonical~copyArray(marketRegions)

::method canonicalText
  expose geographyId geographyKind parentId label aliases marketRegions
  text = .ReputationCanonical~field("GEO_ID", geographyId)
  text ||= .ReputationCanonical~field("GEO_KIND", geographyKind)
  text ||= .ReputationCanonical~field("PARENT", parentId)
  text ||= .ReputationCanonical~field("LABEL", label)
  text ||= .ReputationCanonical~join("ALIAS", aliases)
  text ||= .ReputationCanonical~join("MARKET", marketRegions)
  return text


::class ReputationGeographyCatalog public
::method init
  expose geographies
  geographies = .directory~new

::method add
  expose geographies
  use arg geography
  if geography == .nil then return .false
  id = geography~geographyId
  if geographies~hasIndex(id) then return .false
  geographies[id] = geography
  return .true

::method geography
  expose geographies
  use arg geographyId
  id = geographyId~string~upper
  if geographies~hasIndex(id) then return geographies[id]
  return .nil

::method has
  expose geographies
  use arg geographyId
  return geographies~hasIndex(geographyId~string~upper)

::method isDescendantOf
  expose geographies
  use arg childIdArg, ancestorIdArg
  childId = childIdArg~string~upper
  ancestorId = ancestorIdArg~string~upper
  if childId == ancestorId then return .true
  if \geographies~hasIndex(childId) then return .false
  seen = .directory~new
  current = geographies[childId]
  do while current \== .nil
    parent = current~parentId
    if parent = "" then return .false
    if parent == ancestorId then return .true
    if seen~hasIndex(parent) then return .false
    seen[parent] = .true
    if \geographies~hasIndex(parent) then return .false
    current = geographies[parent]
  end
  return .false

::method relationshipMatches
  use arg effectGeographyId, requestedGeographyId, propagation = "NONE"
  effectId = effectGeographyId~string~upper
  requestedId = requestedGeographyId~string~upper
  mode = propagation~string~upper
  if effectId == requestedId then return .true
  if mode = .ReputationConstant~PROP_DESCENDANTS then return self~isDescendantOf(requestedId, effectId)
  if mode = .ReputationConstant~PROP_ANCESTORS then return self~isDescendantOf(effectId, requestedId)
  if mode = .ReputationConstant~PROP_BOTH then return self~isDescendantOf(requestedId, effectId) | self~isDescendantOf(effectId, requestedId)
  return .false


::class ReputationEvidenceAnchor public
::attribute sourceId get
::attribute sourceKind get
::attribute citation get
::attribute observedAt get
::attribute confidence get
::attribute sourceObject get

::method init
  expose sourceId sourceKind citation observedAt confidence sourceObject metadata
  use arg sourceIdArg, sourceKindArg, citationArg = "", observedAtArg = .nil, confidenceArg = 100, sourceObjectArg = .nil, metadataArg = .nil
  sourceId = sourceIdArg~string
  sourceKind = sourceKindArg~string~upper
  citation = citationArg~string
  if observedAtArg == .nil then observedAt = .DateTime~new
  else observedAt = observedAtArg
  confidence = .ReputationCanonical~clamp(confidenceArg)
  sourceObject = sourceObjectArg
  if metadataArg == .nil then metadata = .table~new
  else metadata = metadataArg

::method metadata
  expose metadata
  copy = .table~new
  do key over metadata
    copy[key] = metadata[key]
  end
  return copy

::method canonicalText
  expose sourceId sourceKind citation observedAt confidence metadata
  text = .ReputationCanonical~field("SOURCE_ID", sourceId)
  text ||= .ReputationCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .ReputationCanonical~field("CITATION", citation)
  text ||= .ReputationCanonical~field("OBSERVED_AT", observedAt)
  text ||= .ReputationCanonical~field("CONFIDENCE", confidence)
  pairs = .array~new
  do key over metadata
    pairs~append(key~string || "=" || metadata[key]~string)
  end
  text ||= .ReputationCanonical~join("META", pairs)
  return text


::class ReputationObservation public
::attribute observationId get
::attribute reportedEventId get
::attribute observedGeographyId get
::attribute affectedGeographyId get
::attribute recordedAt get
::attribute confidence get
::attribute observationState get
::attribute sourceAnchor get
::attribute detail get

::method init
  expose observationId reportedEventId observedGeographyId affectedGeographyId recordedAt confidence observationState sourceAnchor detail
  use arg observationIdArg, reportedEventIdArg, observedGeographyArg, affectedGeographyArg, sourceAnchorArg, recordedAtArg = .nil, confidenceArg = 50, observationStateArg = "UNVERIFIED", detailArg = ""
  observationId = observationIdArg~string
  reportedEventId = reportedEventIdArg~string
  observedGeographyId = observedGeographyArg~string~upper
  affectedGeographyId = affectedGeographyArg~string~upper
  sourceAnchor = sourceAnchorArg
  if recordedAtArg == .nil then recordedAt = .DateTime~new
  else recordedAt = recordedAtArg
  confidence = .ReputationCanonical~clamp(confidenceArg)
  observationState = observationStateArg~string~upper
  detail = detailArg~string

::method canonicalText
  expose observationId reportedEventId observedGeographyId affectedGeographyId recordedAt confidence observationState sourceAnchor detail
  text = .ReputationCanonical~field("OBSERVATION_ID", observationId)
  text ||= .ReputationCanonical~field("EVENT_ID", reportedEventId)
  text ||= .ReputationCanonical~field("OBSERVED_GEO", observedGeographyId)
  text ||= .ReputationCanonical~field("AFFECTED_GEO", affectedGeographyId)
  text ||= .ReputationCanonical~field("RECORDED_AT", recordedAt)
  text ||= .ReputationCanonical~field("CONFIDENCE", confidence)
  text ||= .ReputationCanonical~field("STATE", observationState)
  text ||= .ReputationCanonical~field("DETAIL", detail)
  if sourceAnchor == .nil then sourceText = "NONE"
  else sourceText = sourceAnchor~canonicalText
  text ||= .ReputationCanonical~field("SOURCE", sourceText)
  return text


::class ReputationGeographicEffect public
::attribute eventId get
::attribute geographyId get
::attribute audienceId get
::attribute salience get
::attribute direction get
::attribute confidence get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute propagation get

::method init
  expose eventId geographyId audienceId salience direction confidence effectiveFrom effectiveUntil propagation
  use arg eventIdArg, geographyIdArg, audienceIdArg = "*", salienceArg = 50, directionArg = "ADVERSE", confidenceArg = 100, effectiveFromArg = .nil, effectiveUntilArg = .nil, propagationArg = "NONE"
  eventId = eventIdArg~string
  geographyId = geographyIdArg~string~upper
  audienceId = audienceIdArg~string~upper
  salience = .ReputationCanonical~clamp(salienceArg)
  direction = directionArg~string~upper
  confidence = .ReputationCanonical~clamp(confidenceArg)
  effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  propagation = propagationArg~string~upper

::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if effectiveFrom \== .nil then if moment < effectiveFrom then return .false
  if effectiveUntil \== .nil then if moment > effectiveUntil then return .false
  return .true

::method appliesToAudience
  expose audienceId
  use arg audiences
  if audienceId = "*" then return .true
  return .ReputationCanonical~containsString(audiences, audienceId)

::method canonicalText
  expose eventId geographyId audienceId salience direction confidence effectiveFrom effectiveUntil propagation
  return .ReputationCanonical~field("EVENT", eventId) || -
         .ReputationCanonical~field("GEO", geographyId) || -
         .ReputationCanonical~field("AUD", audienceId) || -
         .ReputationCanonical~field("SALIENCE", salience) || -
         .ReputationCanonical~field("DIRECTION", direction) || -
         .ReputationCanonical~field("CONFIDENCE", confidence) || -
         .ReputationCanonical~field("FROM", effectiveFrom) || -
         .ReputationCanonical~field("UNTIL", effectiveUntil) || -
         .ReputationCanonical~field("PROP", propagation)


::class ReputationSubjectLink public
::attribute subjectKind get
::attribute subjectId get
::attribute strength get

::method init
  expose subjectKind subjectId strength
  use arg subjectKindArg, subjectIdArg, strengthArg = 100
  subjectKind = subjectKindArg~string~upper
  subjectId = subjectIdArg~string~upper
  strength = .ReputationCanonical~clamp(strengthArg)

::method key
  expose subjectKind subjectId
  return subjectKind || "|" || subjectId

::method canonicalText
  return self~key || "|" || self~strength


::class ReputationEvent public
::attribute eventId get
::attribute eventType get
::attribute title get
::attribute occurredAt get
::attribute firstObservedAt get
::attribute severity get
::attribute humanHarm get
::attribute sector get
::attribute sealed get

::method init
  expose eventId eventType title occurredAt firstObservedAt severity humanHarm sector subjects concepts effects evidence sealed
  use arg eventIdArg, eventTypeArg, titleArg = "", occurredAtArg = .nil, firstObservedAtArg = .nil, severityArg = 50, humanHarmArg = "NONE", sectorArg = ""
  eventId = eventIdArg~string
  eventType = eventTypeArg~string~upper
  title = titleArg~string
  if occurredAtArg == .nil then occurredAt = .DateTime~new
  else occurredAt = occurredAtArg
  if firstObservedAtArg == .nil then firstObservedAt = occurredAt
  else firstObservedAt = firstObservedAtArg
  severity = .ReputationCanonical~clamp(severityArg)
  humanHarm = humanHarmArg~string~upper
  sector = sectorArg~string~upper
  subjects = .array~new
  concepts = .array~new
  effects = .array~new
  evidence = .array~new
  sealed = .false

::method addSubject
  expose subjects sealed
  use arg kindArg, idArg, strengthArg = 100
  if sealed then return .false
  subjects~append(.ReputationSubjectLink~new(kindArg, idArg, strengthArg))
  return .true

::method addConcept
  expose concepts sealed
  use arg concept
  if sealed then return .false
  value = concept~string~upper~strip
  if value = "" then return .false
  if \.ReputationCanonical~containsString(concepts, value) then concepts~append(value)
  return .true

::method addGeographicEffect
  expose effects sealed eventId
  use arg effect
  if sealed then return .false
  if effect == .nil then return .false
  if effect~eventId <> eventId then return .false
  effects~append(effect)
  return .true

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  evidence~append(anchor)
  return .true

::method subjects
  expose subjects
  return .ReputationCanonical~copyArray(subjects)

::method concepts
  expose concepts
  return .ReputationCanonical~copyArray(concepts)

::method geographicEffects
  expose effects
  return .ReputationCanonical~copyArray(effects)

::method evidence
  expose evidence
  return .ReputationCanonical~copyArray(evidence)

::method hasSubject
  expose subjects
  use arg kindArg, idArg
  wanted = kindArg~string~upper || "|" || idArg~string~upper
  do link over subjects
    if link~key == wanted then return .true
  end
  return .false

::method subjectStrength
  expose subjects
  use arg kindArg, idArg
  wanted = kindArg~string~upper || "|" || idArg~string~upper
  best = 0
  do link over subjects
    if link~key == wanted then if link~strength > best then best = link~strength
  end
  return best

::method seal
  expose sealed
  sealed = .true
  return self

::method canonicalText
  expose eventId eventType title occurredAt firstObservedAt severity humanHarm sector subjects concepts effects evidence sealed
  if \sealed then raise syntax 93.900 additional("ReputationEvent must be sealed before canonicalisation")
  text = .ReputationCanonical~field("EVENT_ID", eventId)
  text ||= .ReputationCanonical~field("EVENT_TYPE", eventType)
  text ||= .ReputationCanonical~field("TITLE", title)
  text ||= .ReputationCanonical~field("OCCURRED_AT", occurredAt)
  text ||= .ReputationCanonical~field("FIRST_OBSERVED_AT", firstObservedAt)
  text ||= .ReputationCanonical~field("SEVERITY", severity)
  text ||= .ReputationCanonical~field("HUMAN_HARM", humanHarm)
  text ||= .ReputationCanonical~field("SECTOR", sector)
  subjectTexts = .array~new
  do subject over subjects; subjectTexts~append(subject~canonicalText); end
  effectTexts = .array~new
  do effect over effects; effectTexts~append(effect~canonicalText); end
  evidenceTexts = .array~new
  do anchor over evidence; evidenceTexts~append(anchor~canonicalText); end
  text ||= .ReputationCanonical~join("SUBJECT", subjectTexts)
  text ||= .ReputationCanonical~join("CONCEPT", concepts)
  text ||= .ReputationCanonical~join("EFFECT", effectTexts)
  text ||= .ReputationCanonical~join("EVIDENCE", evidenceTexts)
  return text


::class ReputationBrandNorm public
::attribute normId get
::attribute actorId get
::attribute geographyId get
::attribute audienceId get
::attribute behaviorClass get
::attribute expectedness get
::attribute tolerance get
::attribute effectiveFrom get
::attribute effectiveUntil get

::method init
  expose normId actorId geographyId audienceId behaviorClass expectedness tolerance effectiveFrom effectiveUntil evidence
  use arg normIdArg, actorIdArg, geographyIdArg, audienceIdArg, behaviorClassArg, expectednessArg = 50, toleranceArg = 50, effectiveFromArg = .nil, effectiveUntilArg = .nil
  normId = normIdArg~string
  actorId = actorIdArg~string~upper
  geographyId = geographyIdArg~string~upper
  audienceId = audienceIdArg~string~upper
  behaviorClass = behaviorClassArg~string~upper
  expectedness = .ReputationCanonical~clamp(expectednessArg)
  tolerance = .ReputationCanonical~clamp(toleranceArg)
  effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  evidence = .array~new

::method addEvidence
  expose evidence
  use arg anchor
  if anchor \== .nil then evidence~append(anchor)
  return self

::method evidence
  expose evidence
  return .ReputationCanonical~copyArray(evidence)

::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if effectiveFrom \== .nil then if moment < effectiveFrom then return .false
  if effectiveUntil \== .nil then if moment > effectiveUntil then return .false
  return .true


::method canonicalText
  expose normId actorId geographyId audienceId behaviorClass expectedness tolerance effectiveFrom effectiveUntil evidence
  text = .ReputationCanonical~field("NORM_ID", normId)
  text ||= .ReputationCanonical~field("ACTOR", actorId)
  text ||= .ReputationCanonical~field("GEO", geographyId)
  text ||= .ReputationCanonical~field("AUDIENCE", audienceId)
  text ||= .ReputationCanonical~field("BEHAVIOR", behaviorClass)
  text ||= .ReputationCanonical~field("EXPECTEDNESS", expectedness)
  text ||= .ReputationCanonical~field("TOLERANCE", tolerance)
  text ||= .ReputationCanonical~field("FROM", effectiveFrom)
  text ||= .ReputationCanonical~field("UNTIL", effectiveUntil)
  evidenceTexts = .array~new
  do anchor over evidence
    evidenceTexts~append(anchor~canonicalText)
  end
  text ||= .ReputationCanonical~join("EVIDENCE", evidenceTexts)
  return text

::class ReputationRelationship public
::attribute relationshipId get
::attribute fromActorId get
::attribute relationType get
::attribute toActorId get
::attribute geographyId get
::attribute strength get
::attribute effectiveFrom get
::attribute effectiveUntil get

::method init
  expose relationshipId fromActorId relationType toActorId geographyId strength effectiveFrom effectiveUntil evidence
  use arg relationshipIdArg, fromActorArg, relationTypeArg, toActorArg, geographyArg = "*", strengthArg = 100, effectiveFromArg = .nil, effectiveUntilArg = .nil
  relationshipId = relationshipIdArg~string
  fromActorId = fromActorArg~string~upper
  relationType = relationTypeArg~string~upper
  toActorId = toActorArg~string~upper
  geographyId = geographyArg~string~upper
  strength = .ReputationCanonical~clamp(strengthArg)
  effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  evidence = .array~new

::method addEvidence
  expose evidence
  use arg anchor
  if anchor \== .nil then evidence~append(anchor)
  return self

::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if effectiveFrom \== .nil then if moment < effectiveFrom then return .false
  if effectiveUntil \== .nil then if moment > effectiveUntil then return .false
  return .true


::method canonicalText
  expose relationshipId fromActorId relationType toActorId geographyId strength effectiveFrom effectiveUntil evidence
  text = .ReputationCanonical~field("REL_ID", relationshipId)
  text ||= .ReputationCanonical~field("FROM_ACTOR", fromActorId)
  text ||= .ReputationCanonical~field("TYPE", relationType)
  text ||= .ReputationCanonical~field("TO_ACTOR", toActorId)
  text ||= .ReputationCanonical~field("GEO", geographyId)
  text ||= .ReputationCanonical~field("STRENGTH", strength)
  text ||= .ReputationCanonical~field("FROM", effectiveFrom)
  text ||= .ReputationCanonical~field("UNTIL", effectiveUntil)
  evidenceTexts = .array~new
  do anchor over evidence
    evidenceTexts~append(anchor~canonicalText)
  end
  text ||= .ReputationCanonical~join("EVIDENCE", evidenceTexts)
  return text

::class ReputationAssociation public
::attribute associationKind get
::attribute associationId get
::attribute strength get

::method init
  expose associationKind associationId strength
  use arg associationKindArg, associationIdArg, strengthArg = 100
  associationKind = associationKindArg~string~upper
  associationId = associationIdArg~string~upper
  strength = .ReputationCanonical~clamp(strengthArg)

::method key
  expose associationKind associationId
  return associationKind || "|" || associationId




::class ReputationCommunicationFailure public
::attribute failureId get
::attribute failureKind get
::attribute routeId get
::attribute failureState get
::attribute severity get
::attribute detail get

::method init
  expose failureId failureKind routeId failureState severity detail
  use arg failureIdArg, failureKindArg, routeIdArg = "", failureStateArg = "OPEN", severityArg = 70, detailArg = ""
  failureId = failureIdArg~string
  failureKind = failureKindArg~string~upper
  routeId = routeIdArg~string~upper
  failureState = failureStateArg~string~upper
  severity = .ReputationCanonical~clamp(severityArg)
  detail = detailArg~string

::method isOpen
  expose failureState
  return failureState = "OPEN" | failureState = "UNRESOLVED"

::method canonicalText
  expose failureId failureKind routeId failureState severity detail
  return .ReputationCanonical~field("FAILURE_ID", failureId) || -
         .ReputationCanonical~field("FAILURE_KIND", failureKind) || -
         .ReputationCanonical~field("ROUTE", routeId) || -
         .ReputationCanonical~field("STATE", failureState) || -
         .ReputationCanonical~field("SEVERITY", severity) || -
         .ReputationCanonical~field("DETAIL", detail)


::class ReputationCommunicationAct public
::attribute actKind get
::attribute target get
::attribute value get
::attribute strength get
::attribute detail get

::method init
  expose actKind target value strength detail
  use arg actKindArg, targetArg = "", valueArg = "", strengthArg = 100, detailArg = ""
  actKind = actKindArg~string~upper
  target = targetArg~string~upper
  value = valueArg~string
  strength = .ReputationCanonical~clamp(strengthArg)
  detail = detailArg~string

::method canonicalText
  expose actKind target value strength detail
  return .ReputationCanonical~field("ACT_KIND", actKind) || -
         .ReputationCanonical~field("TARGET", target) || -
         .ReputationCanonical~field("VALUE", value) || -
         .ReputationCanonical~field("STRENGTH", strength) || -
         .ReputationCanonical~field("DETAIL", detail)


::class ReputationCommunicationSurface public
::attribute surfaceId get
::attribute recipientRelationship get
::attribute institutionalContext get
::attribute priorResponseId get
::attribute sealed get

::method init
  expose surfaceId recipientRelationship institutionalContext priorResponseId acts failures evidence sealed
  use arg surfaceIdArg, recipientRelationshipArg = "CUSTOMER", institutionalContextArg = "", priorResponseIdArg = ""
  surfaceId = surfaceIdArg~string
  recipientRelationship = recipientRelationshipArg~string~upper
  institutionalContext = institutionalContextArg~string~upper
  priorResponseId = priorResponseIdArg~string
  acts = .array~new
  failures = .array~new
  evidence = .array~new
  sealed = .false

::method addAct
  expose acts sealed
  use arg actKind, target = "", value = "", strength = 100, detail = ""
  if sealed then return .false
  acts~append(.ReputationCommunicationAct~new(actKind, target, value, strength, detail))
  return .true

::method addFailure
  expose failures sealed
  use arg failure
  if sealed then return .false
  if failure == .nil then return .false
  failures~append(failure)
  return .true

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  evidence~append(anchor)
  return .true

::method acts
  expose acts
  return .ReputationCanonical~copyArray(acts)

::method failures
  expose failures
  return .ReputationCanonical~copyArray(failures)

::method evidence
  expose evidence
  return .ReputationCanonical~copyArray(evidence)

::method hasAct
  expose acts
  use arg kindArg, targetArg = "", valueArg = ""
  kind = kindArg~string~upper
  target = targetArg~string~upper
  value = valueArg~string~upper
  do act over acts
    if act~actKind <> kind then iterate
    if target <> "" & act~target <> target then iterate
    if value <> "" & act~value~string~upper <> value then iterate
    return .true
  end
  return .false

::method maximumOpenFailureSeverity
  expose failures
  best = 0
  do failure over failures
    if failure~isOpen & failure~severity > best then best = failure~severity
  end
  return best

::method hasOpenFailureKind
  expose failures
  use arg kindArg
  wanted = kindArg~string~upper
  do failure over failures
    if failure~isOpen & failure~failureKind == wanted then return .true
  end
  return .false

::method redirectedFailedRouteSeverity
  expose failures acts
  best = 0
  do failure over failures
    if \failure~isOpen then iterate
    if failure~routeId = "" then iterate
    do act over acts
      if act~actKind = "REDIRECT" & act~target == failure~routeId then do
        if failure~severity > best then best = failure~severity
      end
    end
  end
  return best

::method seal
  expose sealed
  sealed = .true
  return self

::method canonicalText
  expose surfaceId recipientRelationship institutionalContext priorResponseId acts failures evidence sealed
  if \sealed then raise syntax 93.900 additional("ReputationCommunicationSurface must be sealed before canonicalisation")
  text = .ReputationCanonical~field("COMM_ID", surfaceId)
  text ||= .ReputationCanonical~field("RECIPIENT_REL", recipientRelationship)
  text ||= .ReputationCanonical~field("INSTITUTION", institutionalContext)
  text ||= .ReputationCanonical~field("PRIOR_RESPONSE", priorResponseId)
  actTexts = .array~new
  do act over acts; actTexts~append(act~canonicalText); end
  failTexts = .array~new
  do failure over failures; failTexts~append(failure~canonicalText); end
  evidenceTexts = .array~new
  do anchor over evidence; evidenceTexts~append(anchor~canonicalText); end
  text ||= .ReputationCanonical~join("COMM_ACT", actTexts)
  text ||= .ReputationCanonical~join("COMM_FAILURE", failTexts)
  text ||= .ReputationCanonical~join("COMM_EVIDENCE", evidenceTexts)
  return text


::class ReputationActionSurface public
::attribute actionId get
::attribute actorId get
::attribute actionType get
::attribute intendedAt get
::attribute reachClass get
::attribute targetActorId get
::attribute sealed get
::attribute communicationSurface get

::method init
  expose actionId actorId actionType intendedAt reachClass targetActorId geographies audiences concepts associations behaviors evidence communicationSurface sealed
  use arg actionIdArg, actorIdArg, actionTypeArg = "PUBLICATION", intendedAtArg = .nil, reachClassArg = "NORMAL", targetActorArg = ""
  actionId = actionIdArg~string
  actorId = actorIdArg~string~upper
  actionType = actionTypeArg~string~upper
  if intendedAtArg == .nil then intendedAt = .DateTime~new
  else intendedAt = intendedAtArg
  reachClass = reachClassArg~string~upper
  targetActorId = targetActorArg~string~upper
  geographies = .array~new
  audiences = .array~new
  concepts = .array~new
  associations = .array~new
  behaviors = .array~new
  evidence = .array~new
  communicationSurface = .nil
  sealed = .false

::method addGeography
  expose geographies sealed
  use arg geographyId
  if sealed then return .false
  id = geographyId~string~upper
  if \.ReputationCanonical~containsString(geographies, id) then geographies~append(id)
  return .true

::method addAudience
  expose audiences sealed
  use arg audienceId
  if sealed then return .false
  id = audienceId~string~upper
  if \.ReputationCanonical~containsString(audiences, id) then audiences~append(id)
  return .true

::method addConcept
  expose concepts sealed
  use arg concept
  if sealed then return .false
  value = concept~string~upper
  if \.ReputationCanonical~containsString(concepts, value) then concepts~append(value)
  return .true

::method addAssociation
  expose associations sealed
  use arg kindArg, idArg, strengthArg = 100
  if sealed then return .false
  associations~append(.ReputationAssociation~new(kindArg, idArg, strengthArg))
  return .true

::method addBehaviorClass
  expose behaviors sealed
  use arg behaviorClass
  if sealed then return .false
  value = behaviorClass~string~upper
  if \.ReputationCanonical~containsString(behaviors, value) then behaviors~append(value)
  return .true

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  evidence~append(anchor)
  return .true

::method setCommunicationSurface
  expose communicationSurface sealed
  use arg surface
  if sealed then return .false
  if surface == .nil then return .false
  communicationSurface = surface
  return .true

::method geographies
  expose geographies
  return .ReputationCanonical~copyArray(geographies)

::method audiences
  expose audiences
  return .ReputationCanonical~copyArray(audiences)

::method concepts
  expose concepts
  return .ReputationCanonical~copyArray(concepts)

::method associations
  expose associations
  return .ReputationCanonical~copyArray(associations)

::method behaviorClasses
  expose behaviors
  return .ReputationCanonical~copyArray(behaviors)

::method evidence
  expose evidence
  return .ReputationCanonical~copyArray(evidence)

::method hasBehaviorClass
  expose behaviors
  use arg behaviorClass
  return .ReputationCanonical~containsString(behaviors, behaviorClass)

::method seal
  expose sealed geographies communicationSurface
  if geographies~items = 0 then raise syntax 88.900 array("ReputationActionSurface requires at least one geography")
  if communicationSurface \== .nil then if \communicationSurface~sealed then raise syntax 88.900 array("ReputationActionSurface communication surface must be sealed")
  sealed = .true
  return self


::method canonicalText
  expose actionId actorId actionType intendedAt reachClass targetActorId geographies audiences concepts associations behaviors evidence communicationSurface sealed
  if \sealed then raise syntax 93.900 additional("ReputationActionSurface must be sealed before canonicalisation")
  text = .ReputationCanonical~field("ACTION_ID", actionId)
  text ||= .ReputationCanonical~field("ACTOR", actorId)
  text ||= .ReputationCanonical~field("ACTION_TYPE", actionType)
  text ||= .ReputationCanonical~field("INTENDED_AT", intendedAt)
  text ||= .ReputationCanonical~field("REACH", reachClass)
  text ||= .ReputationCanonical~field("TARGET_ACTOR", targetActorId)
  text ||= .ReputationCanonical~join("GEO", geographies)
  text ||= .ReputationCanonical~join("AUDIENCE", audiences)
  text ||= .ReputationCanonical~join("CONCEPT", concepts)
  assocTexts = .array~new
  do association over associations
    assocTexts~append(association~key || "|" || association~strength)
  end
  text ||= .ReputationCanonical~join("ASSOC", assocTexts)
  text ||= .ReputationCanonical~join("BEHAVIOR", behaviors)
  evidenceTexts = .array~new
  do anchor over evidence
    evidenceTexts~append(anchor~canonicalText)
  end
  text ||= .ReputationCanonical~join("EVIDENCE", evidenceTexts)
  if communicationSurface == .nil then commText = "NONE"
  else commText = communicationSurface~canonicalText
  text ||= .ReputationCanonical~field("COMMUNICATION", commText)
  return text

::class ReputationConceptGraph public
::method init
  expose edges
  edges = .directory~new

::method link
  expose edges
  use arg leftArg, rightArg
  left = leftArg~string~upper
  right = rightArg~string~upper
  self~addOneWay(left, right)
  self~addOneWay(right, left)
  return self

::method addOneWay private
  expose edges
  use arg left, right
  if \edges~hasIndex(left) then edges[left] = .array~new
  neighbours = edges[left]
  if \.ReputationCanonical~containsString(neighbours, right) then neighbours~append(right)

::method distance
  expose edges
  use arg leftArg, rightArg, maxDistance = 2
  left = leftArg~string~upper
  right = rightArg~string~upper
  if left == right then return 0
  if maxDistance < 1 then return -1
  frontier = .array~of(left)
  seen = .directory~new
  seen[left] = .true
  depth = 0
  do while frontier~items > 0 & depth < maxDistance
    depth += 1
    nextFrontier = .array~new
    do node over frontier
      if \edges~hasIndex(node) then iterate
      do neighbour over edges[node]
        if neighbour == right then return depth
        if \seen~hasIndex(neighbour) then do
          seen[neighbour] = .true
          nextFrontier~append(neighbour)
        end
      end
    end
    frontier = nextFrontier
  end
  return -1

::method bestCollision
  use arg actionConcepts, eventConcepts, maxDistance = 2
  bestScore = 0
  bestDetail = ""
  do actionConcept over actionConcepts
    do eventConcept over eventConcepts
      distanceValue = self~distance(actionConcept, eventConcept, maxDistance)
      if distanceValue < 0 then iterate
      if distanceValue = 0 then score = 100
      else if distanceValue = 1 then score = 80
      else score = 60
      if score > bestScore then do
        bestScore = score
        bestDetail = actionConcept~string~upper || "~" || eventConcept~string~upper || "@" || distanceValue
      end
    end
  end
  return .array~of(bestScore, bestDetail)


::class ReputationSnapshot public
::attribute snapshotId get
::attribute capturedAt get
::attribute lastSuccessfulRefresh get
::attribute sealed get

::method init
  expose snapshotId capturedAt lastSuccessfulRefresh coverageGeographies events norms relationships evidence sealed
  use arg snapshotIdArg, capturedAtArg = .nil, lastRefreshArg = .nil
  snapshotId = snapshotIdArg~string
  if capturedAtArg == .nil then capturedAt = .DateTime~new
  else capturedAt = capturedAtArg
  if lastRefreshArg == .nil then lastSuccessfulRefresh = capturedAt
  else lastSuccessfulRefresh = lastRefreshArg
  coverageGeographies = .array~new
  events = .array~new
  norms = .array~new
  relationships = .array~new
  evidence = .array~new
  sealed = .false

::method addCoverageGeography
  expose coverageGeographies sealed
  use arg geographyId
  if sealed then return .false
  id = geographyId~string~upper
  if \.ReputationCanonical~containsString(coverageGeographies, id) then coverageGeographies~append(id)
  return .true

::method addEvent
  expose events sealed
  use arg event
  if sealed then return .false
  if event == .nil then return .false
  events~append(event)
  return .true

::method addBrandNorm
  expose norms sealed
  use arg norm
  if sealed then return .false
  if norm == .nil then return .false
  norms~append(norm)
  return .true

::method addRelationship
  expose relationships sealed
  use arg relationship
  if sealed then return .false
  if relationship == .nil then return .false
  relationships~append(relationship)
  return .true

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .false
  if anchor == .nil then return .false
  evidence~append(anchor)
  return .true

::method events
  expose events
  return .ReputationCanonical~copyArray(events)

::method brandNorms
  expose norms
  return .ReputationCanonical~copyArray(norms)

::method relationships
  expose relationships
  return .ReputationCanonical~copyArray(relationships)

::method coverageGeographies
  expose coverageGeographies
  return .ReputationCanonical~copyArray(coverageGeographies)

::method coversGeography
  expose coverageGeographies
  use arg requestedGeographyId, geographyCatalog
  requested = requestedGeographyId~string~upper
  do covered over coverageGeographies
    if covered~string~upper == requested then return .true
    if geographyCatalog \== .nil then if geographyCatalog~isDescendantOf(requested, covered) then return .true
  end
  return .false

::method matchingBrandNorm
  expose norms
  use arg actorIdArg, geographyIdArg, audienceIds, behaviorClassArg, moment, geographyCatalog
  actorId = actorIdArg~string~upper
  geographyId = geographyIdArg~string~upper
  behaviorClass = behaviorClassArg~string~upper
  best = .nil
  bestExpectedness = -1
  do norm over norms
    if norm~actorId <> actorId then iterate
    if norm~behaviorClass <> behaviorClass then iterate
    if \norm~activeAt(moment) then iterate
    geoMatch = norm~geographyId = "*" | norm~geographyId == geographyId
    if \geoMatch & geographyCatalog \== .nil then geoMatch = geographyCatalog~isDescendantOf(geographyId, norm~geographyId)
    if \geoMatch then iterate
    audMatch = norm~audienceId = "*" | .ReputationCanonical~containsString(audienceIds, norm~audienceId)
    if \audMatch then iterate
    if norm~expectedness > bestExpectedness then do
      best = norm
      bestExpectedness = norm~expectedness
    end
  end
  return best

::method relationshipExists
  expose relationships
  use arg fromActorArg, relationTypeArg, toActorArg, geographyIdArg, moment, geographyCatalog
  fromActor = fromActorArg~string~upper
  relationType = relationTypeArg~string~upper
  toActor = toActorArg~string~upper
  geographyId = geographyIdArg~string~upper
  do relationship over relationships
    if relationship~fromActorId <> fromActor then iterate
    if relationship~relationType <> relationType then iterate
    if relationship~toActorId <> toActor then iterate
    if \relationship~activeAt(moment) then iterate
    if relationship~geographyId = "*" | relationship~geographyId == geographyId then return .true
    if geographyCatalog \== .nil then if geographyCatalog~isDescendantOf(geographyId, relationship~geographyId) then return .true
  end
  return .false

::method seal
  expose sealed events
  do event over events
    if \event~sealed then raise syntax 88.900 array("Snapshot contains unsealed reputation event " || event~eventId)
  end
  sealed = .true
  return self


::method canonicalText
  expose snapshotId capturedAt lastSuccessfulRefresh coverageGeographies events norms relationships evidence sealed
  if \sealed then raise syntax 93.900 additional("ReputationSnapshot must be sealed before canonicalisation")
  text = .ReputationCanonical~field("SNAPSHOT_ID", snapshotId)
  text ||= .ReputationCanonical~field("CAPTURED_AT", capturedAt)
  text ||= .ReputationCanonical~field("LAST_REFRESH", lastSuccessfulRefresh)
  text ||= .ReputationCanonical~join("COVERAGE", coverageGeographies)
  eventTexts = .array~new
  do event over events; eventTexts~append(event~canonicalText); end
  normTexts = .array~new
  do norm over norms; normTexts~append(norm~canonicalText); end
  relationTexts = .array~new
  do relationship over relationships; relationTexts~append(relationship~canonicalText); end
  evidenceTexts = .array~new
  do anchor over evidence; evidenceTexts~append(anchor~canonicalText); end
  text ||= .ReputationCanonical~join("EVENT", eventTexts)
  text ||= .ReputationCanonical~join("NORM", normTexts)
  text ||= .ReputationCanonical~join("REL", relationTexts)
  text ||= .ReputationCanonical~join("EVIDENCE", evidenceTexts)
  return text

::method semanticIdentity
  return self~canonicalText

::class ReputationPolicy public
::method init
  expose maxAgeByReach warnThreshold reviewThreshold holdThreshold associationThreshold semanticThreshold
  maxAgeByReach = .directory~new
  maxAgeByReach["NORMAL"] = 120
  maxAgeByReach["HIGH_REACH"] = 30
  maxAgeByReach["LIVE_MAJOR_EVENT"] = 15
  maxAgeByReach["CRITICAL"] = 5
  warnThreshold = 40
  reviewThreshold = 65
  holdThreshold = 85
  associationThreshold = 35
  semanticThreshold = 60

::method setMaxContextAgeMinutes
  expose maxAgeByReach
  use arg reachClass, minutes
  maxAgeByReach[reachClass~string~upper] = minutes + 0
  return self

::method maxContextAgeMinutes
  expose maxAgeByReach
  use arg reachClass
  key = reachClass~string~upper
  if maxAgeByReach~hasIndex(key) then return maxAgeByReach[key]
  return maxAgeByReach["NORMAL"]

::method warnThreshold
  expose warnThreshold
  return warnThreshold
::method reviewThreshold
  expose reviewThreshold
  return reviewThreshold
::method holdThreshold
  expose holdThreshold
  return holdThreshold
::method associationThreshold
  expose associationThreshold
  return associationThreshold
::method semanticThreshold
  expose semanticThreshold
  return semanticThreshold

::method dispositionForSeverity
  expose warnThreshold reviewThreshold holdThreshold
  use arg severity
  if severity >= holdThreshold then return .ReputationConstant~DISP_HOLD
  if severity >= reviewThreshold then return .ReputationConstant~DISP_REVIEW
  if severity >= warnThreshold then return .ReputationConstant~DISP_WARN
  return .ReputationConstant~DISP_CLEAR


::class ReputationAssessmentItem public
::attribute itemKind get
::attribute code get
::attribute severity get
::attribute confidence get
::attribute geographyId get
::attribute eventId get
::attribute detail get
::attribute evidence get

::method init
  expose itemKind code severity confidence geographyId eventId detail evidence
  use arg itemKindArg, codeArg, severityArg, confidenceArg, geographyArg, eventIdArg = "", detailArg = "", evidenceArg = .nil
  itemKind = itemKindArg~string~upper
  code = codeArg~string~upper
  severity = .ReputationCanonical~clamp(severityArg)
  confidence = .ReputationCanonical~clamp(confidenceArg)
  geographyId = geographyArg~string~upper
  eventId = eventIdArg~string
  detail = detailArg~string
  evidence = evidenceArg


::class ReputationGeographicDecision public
::attribute geographyId get
::attribute disposition get
::attribute maximumConcernSeverity get

::method init
  expose geographyId items disposition maximumConcernSeverity
  use arg geographyIdArg
  geographyId = geographyIdArg~string~upper
  items = .array~new
  disposition = .ReputationConstant~DISP_CLEAR
  maximumConcernSeverity = 0

::method addItem
  expose items maximumConcernSeverity
  use arg item
  items~append(item)
  if item~itemKind = .ReputationConstant~ITEM_CONCERN then do
    if item~severity > maximumConcernSeverity then maximumConcernSeverity = item~severity
  end
  return self

::method items
  expose items
  return .ReputationCanonical~copyArray(items)

::method containsCode
  expose items
  use arg wantedCode
  wanted = wantedCode~string~upper
  do item over items
    if item~code == wanted then return .true
  end
  return .false

::method finalize
  expose disposition maximumConcernSeverity
  use arg policy, forcedDisposition = ""
  if forcedDisposition <> "" then disposition = forcedDisposition~string~upper
  else disposition = policy~dispositionForSeverity(maximumConcernSeverity)
  return self


::class ReputationDecision public
::attribute action get
::attribute snapshot get
::attribute overallDisposition get

::method init
  expose action snapshot geographicDecisions overallDisposition
  use arg actionArg, snapshotArg
  action = actionArg
  snapshot = snapshotArg
  geographicDecisions = .directory~new
  overallDisposition = .ReputationConstant~DISP_CLEAR

::method putGeographicDecision
  expose geographicDecisions
  use arg decision
  geographicDecisions[decision~geographyId] = decision
  return self

::method geographicDecision
  expose geographicDecisions
  use arg geographyId
  id = geographyId~string~upper
  if geographicDecisions~hasIndex(id) then return geographicDecisions[id]
  return .nil

::method geographicDecisions
  expose geographicDecisions
  out = .array~new
  ids = geographicDecisions~allIndexes
  ids~sort
  do id over ids
    out~append(geographicDecisions[id])
  end
  return out

::method finalize
  expose geographicDecisions overallDisposition
  if geographicDecisions~items = 0 then do
    overallDisposition = .ReputationConstant~DISP_HOLD
    return self
  end
  first = ""
  mixed = .false
  worstRank = -1
  worst = .ReputationConstant~DISP_CLEAR
  ids = geographicDecisions~allIndexes
  do id over ids
    current = geographicDecisions[id]~disposition
    if first = "" then first = current
    else if current <> first then mixed = .true
    rank = self~rank(current)
    if rank > worstRank then do
      worstRank = rank
      worst = current
    end
  end
  if mixed then overallDisposition = .ReputationConstant~DISP_CONFLICTED
  else overallDisposition = worst
  return self

::method rank private
  use arg disposition
  select
    when disposition = .ReputationConstant~DISP_CLEAR then return 0
    when disposition = .ReputationConstant~DISP_WARN then return 1
    when disposition = .ReputationConstant~DISP_REVIEW then return 2
    when disposition = .ReputationConstant~DISP_HOLD then return 3
    when disposition = .ReputationConstant~DISP_HOLD_REFRESH then return 4
    otherwise return 5
  end


::class ReputationEngine public
::method evaluate
  use arg action, snapshot, geographyCatalog, conceptGraph, policy = .nil
  if policy == .nil then policy = .ReputationPolicy~new
  if action == .nil then return .ReputationResult~failure("ACTION_REQUIRED")
  if snapshot == .nil then return .ReputationResult~failure("SNAPSHOT_REQUIRED")
  if \action~sealed then return .ReputationResult~failure("ACTION_NOT_SEALED")
  if \snapshot~sealed then return .ReputationResult~failure("SNAPSHOT_NOT_SEALED")
  if geographyCatalog == .nil then return .ReputationResult~failure("GEOGRAPHY_CATALOG_REQUIRED")
  if conceptGraph == .nil then conceptGraph = .ReputationConceptGraph~new

  decision = .ReputationDecision~new(action, snapshot)
  do geographyId over action~geographies
    geoDecision = .ReputationGeographicDecision~new(geographyId)

    if \snapshot~coversGeography(geographyId, geographyCatalog) then do
      item = .ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "WORLD_CONTEXT_UNKNOWN", 100, 100, geographyId, "", "Snapshot does not cover requested geography", snapshot)
      geoDecision~addItem(item)
      geoDecision~finalize(policy, .ReputationConstant~DISP_HOLD_REFRESH)
      decision~putGeographicDecision(geoDecision)
      iterate
    end

    ageMinutes = self~contextAgeMinutes(action~intendedAt, snapshot~lastSuccessfulRefresh)
    if ageMinutes > policy~maxContextAgeMinutes(action~reachClass) then do
      detail = "World context age " || ageMinutes || " minutes exceeds policy for " || action~reachClass
      item = .ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "WORLD_CONTEXT_STALE", 100, 100, geographyId, "", detail, snapshot)
      geoDecision~addItem(item)
      geoDecision~finalize(policy, .ReputationConstant~DISP_HOLD_REFRESH)
      decision~putGeographicDecision(geoDecision)
      iterate
    end

    do event over snapshot~events
      self~evaluateEventForGeography(action, event, snapshot, geographyId, geographyCatalog, conceptGraph, policy, geoDecision)
    end

    self~evaluateCommunication(action, geographyId, geoDecision)
    self~evaluateBrandNorms(action, snapshot, geographyId, geographyCatalog, geoDecision)
    geoDecision~finalize(policy)
    decision~putGeographicDecision(geoDecision)
  end
  decision~finalize
  return .ReputationResult~success(decision)

::method contextAgeMinutes private
  use arg intendedAt, refreshedAt
  span = intendedAt - refreshedAt
  seconds = span~totalSeconds
  if seconds < 0 then return 0
  return trunc(seconds / 60)

::method matchingEffect private
  use arg event, action, geographyId, geographyCatalog
  best = .nil
  bestSalience = -1
  do effect over event~geographicEffects
    if \effect~activeAt(action~intendedAt) then iterate
    if \effect~appliesToAudience(action~audiences) then iterate
    if \geographyCatalog~relationshipMatches(effect~geographyId, geographyId, effect~propagation) then iterate
    if effect~salience > bestSalience then do
      best = effect
      bestSalience = effect~salience
    end
  end
  return best

::method associationStrength private
  use arg action, event
  best = 0
  if event~hasSubject("ACTOR", action~actorId) then best = 100
  do association over action~associations
    eventStrength = event~subjectStrength(association~associationKind, association~associationId)
    if eventStrength > 0 then do
      combined = trunc((association~strength * eventStrength) / 100)
      if combined > best then best = combined
    end
    if association~associationKind = "SECTOR" & event~sector <> "" then do
      if association~associationId == event~sector then do
        combined = trunc(association~strength * 0.7)
        if combined > best then best = combined
      end
    end
  end
  return best

::method eventTargetsActionTarget private
  use arg action, event
  if action~targetActorId = "" then return .false
  return event~hasSubject("ACTOR", action~targetActorId)

::method harmSeverity private
  use arg humanHarm
  select
    when humanHarm = "FATAL" then return 100
    when humanHarm = "SERIOUS" then return 90
    when humanHarm = "INJURY" then return 75
    when humanHarm = "MINOR" then return 50
    otherwise return 0
  end

::method evaluateEventForGeography private
  use arg action, event, snapshot, geographyId, geographyCatalog, conceptGraph, policy, geoDecision
  effect = self~matchingEffect(event, action, geographyId, geographyCatalog)
  if effect == .nil then return
  if effect~salience < 1 then return

  association = self~associationStrength(action, event)
  collision = conceptGraph~bestCollision(action~concepts, event~concepts, 2)
  semanticScore = collision[1]
  targetHit = self~eventTargetsActionTarget(action, event)
  isMockery = action~hasBehaviorClass("COMPETITIVE_MOCKERY")

  if isMockery & targetHit then do
    if event~humanHarm <> "NONE" then do
      harm = self~harmSeverity(event~humanHarm)
      severityValue = trunc((harm * effect~salience) / 100)
      if severityValue < 65 then severityValue = 65
      detail = "Competitive mockery targets actor in recent event with human harm=" || event~humanHarm
      geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "EXPLOITATION_OF_HUMAN_HARM", severityValue, effect~confidence, geographyId, event~eventId, detail, event))
    end
    else do
      norm = snapshot~matchingBrandNorm(action~actorId, geographyId, action~audiences, "COMPETITIVE_MOCKERY", action~intendedAt, geographyCatalog)
      hasCompetition = snapshot~relationshipExists(action~actorId, "COMPETITOR", action~targetActorId, geographyId, action~intendedAt, geographyCatalog)
      if norm \== .nil & hasCompetition & norm~expectedness >= 70 then do
        supportStrength = trunc((norm~expectedness + norm~tolerance) / 2)
        detail = "Competitive mockery is historically expected for this actor/audience relationship"
        geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_SUPPORT, "BRAND_NORM_COHERENCE", supportStrength, effect~confidence, geographyId, event~eventId, detail, norm))
      end
      else do
        severityValue = trunc((event~severity * effect~salience) / 130)
        if severityValue >= policy~warnThreshold then do
          detail = "Competitor-directed newsjacking lacks a strong established brand/relationship norm"
          geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "OPPORTUNISTIC_NEWSJACKING", severityValue, effect~confidence, geographyId, event~eventId, detail, event))
        end
      end
    end
  end

  if association < policy~associationThreshold & semanticScore < policy~semanticThreshold then return

  if semanticScore >= policy~semanticThreshold then do
    base = event~severity
    if association > 0 then base = trunc((base + association) / 2)
    severityValue = trunc((base * effect~salience * semanticScore) / 10000)
    harm = self~harmSeverity(event~humanHarm)
    if harm > 0 then severityValue = trunc((severityValue + harm) / 2)
    if severityValue > 100 then severityValue = 100
    if severityValue >= policy~warnThreshold then do
      detail = "Creative/event semantic collision " || collision[2] || "; association=" || association || "; salience=" || effect~salience
      geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "CONTEXTUAL_SEMANTIC_COLLISION", severityValue, effect~confidence, geographyId, event~eventId, detail, event))
    end
  end

  if association >= 70 & effect~salience >= 70 & event~severity >= 70 then do
    severityValue = trunc((association + effect~salience + event~severity) / 3)
    detail = "Strong direct association to highly salient current event"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "DIRECT_EVENT_ASSOCIATION", severityValue, effect~confidence, geographyId, event~eventId, detail, event))
  end

::method evaluateCommunication private
  use arg action, geographyId, geoDecision
  comm = action~communicationSurface
  if comm == .nil then return

  openSeverity = comm~maximumOpenFailureSeverity
  hasSalesPrompt = comm~hasAct("SALES_PROMPT")
  hasProcurement = comm~hasAct("PROCUREMENT_INFO")
  declaredStop = comm~hasAct("DECLARED_INTENT", "", "STOP_SELLING")

  if openSeverity > 0 & hasSalesPrompt then do
    severityValue = openSeverity + 5
    if severityValue > 100 then severityValue = 100
    detail = "Sales prompt issued while material customer/process failure remains unresolved"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "COMMERCIAL_PRESSURE_COLLISION", severityValue, 95, geographyId, "", detail, comm))
  end

  redirectedSeverity = comm~redirectedFailedRouteSeverity
  if redirectedSeverity > 0 then do
    severityValue = redirectedSeverity
    if severityValue < 65 then severityValue = 65
    detail = "Response redirects recipient to a route already represented as failed/unresolved"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "PROCESS_CIRCULARITY", severityValue, 90, geographyId, "", detail, comm))
  end

  if declaredStop & (hasSalesPrompt | hasProcurement) then do
    if hasSalesPrompt then severityValue = 80
    else severityValue = 50
    detail = "Declared STOP_SELLING intent conflicts with commercial continuation in the same communication"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "DECLARED_INTENT_ACTION_MISMATCH", severityValue, 95, geographyId, "", detail, comm))
  end

  if comm~hasAct("RETRACTION") & comm~hasAct("CORRECTIVE_STATEMENT") then do
    strength = 70
    if comm~hasAct("EVIDENCE_LIMIT") then strength += 10
    if comm~hasAct("PROCESS_OWNERSHIP") then strength += 10
    if strength > 100 then strength = 100
    detail = "Response explicitly retracts/corrects a prior claim and states evidential/process limits"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_SUPPORT, "REPUTATIONAL_RECOVERY", strength, 95, geographyId, "", detail, comm))
  end

  if declaredStop & \hasSalesPrompt & \hasProcurement & openSeverity > 0 then do
    detail = "Commercial activity is deliberately suppressed while unresolved failures remain"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_SUPPORT, "COMMERCIAL_RESTRAINT", 85, 95, geographyId, "", detail, comm))
  end

  if comm~hasAct("EVIDENCE_LIMIT") & comm~hasAct("ACKNOWLEDGEMENT") then do
    detail = "Communication acknowledges recipient evidence while limiting claims to what is actually known"
    geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_SUPPORT, "EVIDENTIAL_DISCIPLINE", 80, 95, geographyId, "", detail, comm))
  end

::method evaluateBrandNorms private
  use arg action, snapshot, geographyId, geographyCatalog, geoDecision
  do behavior over action~behaviorClasses
    norm = snapshot~matchingBrandNorm(action~actorId, geographyId, action~audiences, behavior, action~intendedAt, geographyCatalog)
    if norm == .nil then iterate
    if norm~expectedness <= 25 & norm~tolerance <= 25 then do
      severityValue = 70 - trunc((norm~expectedness + norm~tolerance) / 4)
      detail = "Action behavior " || behavior || " conflicts with established actor norm"
      geoDecision~addItem(.ReputationAssessmentItem~new(.ReputationConstant~ITEM_CONCERN, "BRAND_NORM_MISMATCH", severityValue, 90, geographyId, "", detail, norm))
    end
  end
