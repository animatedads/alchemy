/* Optional bridge: Reputation Feed -> Reputation Effect observation boundary.
 * Feed lineage remains acquisition evidence; it does not create ReputationEvent
 * or ReputationEffect decisions directly.
 */
::class ReputationFeedEffectBridge subclass ReputationFeedAlchemyObject public

::method observationFromArticle
  use arg observationId, eventId, article, family, observedGeographyId, affectedGeographyId, recordedAt = .nil, confidence = 50, observationState = "UNVERIFIED", detail = ""
  self~alchemyTouch("OBSERVATION_FROM_ARTICLE")
  if article == .nil then raise syntax 88.900 array("ReputationFeedEffectBridge requires article")
  if family == .nil then raise syntax 88.900 array("ReputationFeedEffectBridge requires lineage family")
  if recordedAt == .nil then recordedAt = .DateTime~new
  metadata = .table~new
  metadata["lineage_family"] = family~familyId
  metadata["family_article_count"] = family~articleCount
  metadata["family_surface_count"] = family~publicationSurfaceCount
  metadata["publisher_group"] = article~publisherGroup
  anchor = .ReputationEvidenceAnchor~new(article~sourceId, "PUBLICATION", article~title, article~publishedAt, confidence, article, metadata)
  return .ReputationObservation~new(observationId, eventId, observedGeographyId, affectedGeographyId, anchor, recordedAt, confidence, observationState, detail)


::method observationFromClaim
  use arg observationId, eventId, claim, affectedGeographyId = "", recordedAt = .nil, governanceMetadata = .nil
  self~alchemyTouch("OBSERVATION_FROM_CLAIM")
  if claim == .nil then raise syntax 88.900 array("ReputationFeedEffectBridge requires claim")
  if \claim~sealed then raise syntax 88.900 array("ReputationFeedEffectBridge requires sealed claim")
  if recordedAt == .nil then recordedAt = claim~observedAt
  affected = affectedGeographyId~string~upper
  if affected = "" then do
    geos = claim~affectedGeographies
    if geos~items > 0 then affected = geos[1]
    else affected = claim~observedGeographyId
  end
  metadata = .table~new
  metadata["claim_id"] = claim~claimId
  metadata["article_id"] = claim~articleId
  metadata["lineage_family"] = claim~familyId
  metadata["publication_lineage_family"] = claim~familyId
  metadata["assertion_origin_family"] = claim~assertionOriginFamilyId
  metadata["assertion_ancestry_resolved"] = claim~assertionAncestryResolved
  metadata["corroboration_family"] = claim~corroborationFamilyId
  metadata["stance"] = claim~stance
  metadata["event_type"] = claim~eventType
  metadata["source_authentication_state"] = claim~sourceAuthenticationState
  metadata["source_authentication_evidence"] = claim~sourceAuthenticationEvidenceId
  metadata["source_compromised"] = claim~sourceCompromised
  metadata["source_history_evidence"] = claim~sourceHistoryEvidenceId
  if governanceMetadata <> .nil then do key over governanceMetadata
    metadata[key~string] = governanceMetadata[key]
  end
  anchor = .ReputationEvidenceAnchor~new(claim~sourceId, "REPUTATION_FEED_CLAIM", claim~citation, claim~observedAt, claim~confidence, claim, metadata)
  return .ReputationObservation~new(observationId, eventId, claim~observedGeographyId, affected, anchor, recordedAt, claim~confidence, "UNVERIFIED", claim~title)

::method observationsFromHypothesis
  use arg observationPrefix, eventId, hypothesis, policy = .nil, requireCorroborated = .true, evidencePolicy = .nil, governanceMetadata = .nil
  self~alchemyTouch("OBSERVATIONS_FROM_HYPOTHESIS")
  if hypothesis == .nil then raise syntax 88.900 array("ReputationFeedEffectBridge requires sealed hypothesis")
  if \hypothesis~sealed then raise syntax 88.900 array("ReputationFeedEffectBridge requires sealed hypothesis")
  if policy == .nil then policy = .ReputationCorroborationPolicy~new
  if evidencePolicy == .nil then evidencePolicy = .ReputationCorroborationEvidencePolicy~new
  assessment = hypothesis~corroboration(policy, evidencePolicy)
  if requireCorroborated & assessment~status <> "CORROBORATED" then return .array~new
  representatives = .directory~new
  do claim over hypothesis~claims
    if \claim~isActive then iterate
    if claim~stance = "DENIES" | claim~stance = "DISPUTES" then iterate
    provenance = assessment~evidenceStatusForClaim(claim~claimId)
    if provenance == .nil | \provenance~eligible then iterate
    family = provenance~familyId
    if \representatives~hasIndex(family) then representatives[family] = claim
    else if claim~confidence > representatives[family]~confidence then representatives[family] = claim
  end
  families = .array~new
  do family over representatives; families~append(family); end
  families~sort
  observations = .array~new
  number = 0
  do family over families
    claim = representatives[family]
    geos = claim~affectedGeographies
    if geos~items = 0 then geos = .array~of(claim~observedGeographyId)
    do geography over geos
      number += 1
      observation = self~observationFromClaim(observationPrefix || "-" || number, eventId, claim, geography, claim~observedAt, governanceMetadata)
      observations~append(observation)
    end
  end
  return observations

::requires 'ReputationFeed.cls'
::requires 'ReputationEffect.cls'
