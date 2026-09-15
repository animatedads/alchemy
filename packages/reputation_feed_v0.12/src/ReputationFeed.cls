/*
 * Reputation Feed v0.12
 *
 * Independent acquisition/lineage primitives for Reputation Effect.
 * Librarian (or another content analyser) supplies paragraph-level comparison
 * evidence; this package deterministically groups derived variants without
 * confusing publication surface count, audience reach, geographic range, or
 * independent source lineage.
 */

::class ReputationFeedBuild public
::constant VERSION "0.12"
::constant API_VERSION "reputation.feed/0.12"
::constant PRODUCT "ooRexx Reputation Feed"

::class ReputationFeedCanonical public
::method clamp class
  use arg value, low = 0, high = 100
  n = value + 0
  if n < low then return low
  if n > high then return high
  return n

::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source; out~append(item); end
  return out

::method containsString class
  use arg source, wanted
  wanted = wanted~string~upper
  if source == .nil then return .false
  do item over source
    if item~string~upper == wanted then return .true
  end
  return .false

::method field class
  use arg tag, value = ""
  if value == .nil then rendered = "<NIL>"
  else rendered = value~string
  return tag~string || ":" || rendered~length || ":" || rendered

::method join class
  use arg tag, source
  values = .array~new
  if source \== .nil then do item over source; values~append(item~string); end
  values~sort
  text = self~field(tag || "_COUNT", values~items)
  do value over values; text ||= self~field(tag, value); end
  return text


::class ReputationFeedAlchemyContext public
::attribute sealer get
::attribute authority get
::method init
  expose sealer authority
  use arg sealerArg = .nil, authorityArg = .nil
  sealer = sealerArg
  authority = authorityArg


::class ReputationFeedAlchemyObject subclass AlchemyObject public
::attribute domainObjectKind get

::method init
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy(self~class~id, alchemyContextArg)

::method initDomainAlchemy protected
  expose domainObjectKind domainAlchemyContextValue
  use arg kindArg, contextArg = .nil
  domainAlchemyContextValue = contextArg
  kind = kindArg~string~upper
  sealer = .nil
  authority = .nil
  if contextArg \== .nil then do
    if \contextArg~isA(.ReputationFeedAlchemyContext) then raise syntax 88.900 array("reputation_feed Alchemy context must be ReputationFeedAlchemyContext")
    sealer = contextArg~sealer
    authority = contextArg~authority
  end
  meta = .directory~new
  meta["PURPOSE"] = "reputation_feed domain object: " || kind
  meta["PACKAGE"] = "reputation_feed"
  meta["PACKAGE_VERSION"] = "0.12"
  meta["AUTHORSHIP"] = "Alchemy ooRexx project / The Architect"
  meta["STANDARDS"] = "ALCHEMY-HOUSE-OBJECT-0.8; evidence-bearing reputation acquisition"
  meta["DESIGN_LIMITATIONS"] = "Source authentication and assertion ancestry are provenance evidence only; neither establishes assertion truth or a universal source trust score."
  meta["COMPONENT"] = "reputation_feed"
  meta["DOMAIN_OBJECT_KIND"] = kind
  self~init:super(meta, sealer, authority)
  domainObjectKind = kind
  self~registerExternalRequirement("library", "alchemy_objects", "0.8", .true)
  if self~hasMethod("CANONICALTEXT") then self~registerMethodContract("CANONICALTEXT", "Deterministic domain canonical representation", .array~new, "STRING", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  if self~hasMethod("SEAL") then self~registerMethodContract("SEAL", "Freeze mutable domain object for deterministic evaluation", .array~new, "ANY", .false, "FALSE", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerDomainStateProfile(kind)
  return self

::method domainAlchemyContext protected
  expose domainAlchemyContextValue
  return domainAlchemyContextValue

::method registerDomainStateProfile private
  use arg kind
  select
    when kind = "REPUTATIONREACHEVIDENCE" then do
      self~registerStateVariable("estimatedAudience", "CUSTOMER", "Measured audience estimate")
      self~registerStateVariable("unit", "PUBLIC", "Reach measurement unit")
      self~registerStateVariable("sourceId", "PUBLIC", "Reach source identity")
      self~registerStateVariable("confidence", "PUBLIC", "Reach confidence")
    end
    when kind = "REPUTATIONRANGEEVIDENCE" then do
      self~registerStateVariable("sourceId", "PUBLIC", "Range source identity")
      self~registerStateVariable("confidence", "PUBLIC", "Range confidence")
    end
    when kind = "REPUTATIONPUBLICATIONSURFACE" then do
      self~registerStateVariable("surfaceId", "PUBLIC", "Publication surface identity")
      self~registerStateVariable("masthead", "CUSTOMER", "Publication masthead")
      self~registerStateVariable("publisherGroup", "CUSTOMER", "Publisher ownership/group")
      self~registerStateVariable("publicationGeographyId", "PUBLIC", "Publication geography")
    end
    when kind = "REPUTATIONFEEDARTICLE" then do
      self~registerStateVariable("articleId", "PUBLIC", "Article identity")
      self~registerStateVariable("sourceId", "PUBLIC", "Declared source identity")
      self~registerStateVariable("publisherGroup", "CUSTOMER", "Publisher group")
      self~registerStateVariable("title", "CUSTOMER", "Article title")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONPARAGRAPHCOMPARISON" then do
      self~registerStateVariable("leftIndex", "PUBLIC", "Left paragraph index")
      self~registerStateVariable("rightIndex", "PUBLIC", "Right paragraph index")
      self~registerStateVariable("corpusId", "PUBLIC", "Librarian corpus identity")
      self~registerStateVariable("confidence", "PUBLIC", "Comparison confidence")
    end
    when kind = "REPUTATIONARTICLECOMPARISON" then do
      self~registerStateVariable("comparisonId", "PUBLIC", "Article comparison identity")
      self~registerStateVariable("leftArticleId", "PUBLIC", "Left article identity")
      self~registerStateVariable("rightArticleId", "PUBLIC", "Right article identity")
      self~registerStateVariable("corpusId", "PUBLIC", "Librarian corpus identity")
      self~registerStateVariable("sequenceAlignment", "PUBLIC", "Paragraph sequence alignment")
      self~registerStateVariable("rareFactOverlap", "PUBLIC", "Rare-fact overlap")
      self~registerStateVariable("claimedOriginId", "CUSTOMER", "Claimed common origin")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONLINEAGEPOLICY" then do
      self~registerStateVariable("articleSimilarityThreshold", "PUBLIC", "Deterministic article similarity cut")
      self~registerStateVariable("minimumAlignedParagraphs", "PUBLIC", "Minimum aligned paragraph count")
    end
    when kind = "REPUTATIONARTICLEFAMILY" then do
      self~registerStateVariable("familyId", "PUBLIC", "Lineage family identity")
      self~registerStateVariable("probableRootArticleId", "PUBLIC", "Probable root article identity")
    end
    when kind = "REPUTATIONLINEAGERESULT" then do
    end
    when kind = "REPUTATIONLINEAGEENGINE" then do
    end
    when kind = "REPUTATIONREACHRANGESUMMARY" then do
      self~registerStateVariable("publicationSurfaceCount", "PUBLIC", "Publication surface count")
      self~registerStateVariable("lineageFamilyCount", "PUBLIC", "Independent lineage family count")
      self~registerStateVariable("validatedReachSurfaceCount", "PUBLIC", "Surfaces with validated reach")
      self~registerStateVariable("grossValidatedReach", "CUSTOMER", "Gross validated reach")
      self~registerStateVariable("reachComplete", "PUBLIC", "Reach evidence completeness")
      self~registerStateVariable("rangeComplete", "PUBLIC", "Range evidence completeness")
    end
    when kind = "REPUTATIONFEEDCLAIM" then do
      self~registerStateVariable("claimId", "PUBLIC", "Normalized claim identity")
      self~registerStateVariable("familyId", "PUBLIC", "Publication/article lineage family identity")
      self~registerStateVariable("assertionOriginFamilyId", "PUBLIC", "Claim-level assertion ancestry root identity when resolved")
      self~registerStateVariable("assertionAncestryResolved", "PUBLIC", "Whether claim-level assertion ancestry is explicitly resolved")
      self~registerStateVariable("eventType", "PUBLIC", "Claimed event type")
      self~registerStateVariable("confidence", "PUBLIC", "Claim confidence")
      self~registerStateVariable("stance", "PUBLIC", "Assertion or denial stance")
      self~registerStateVariable("claimState", "PUBLIC", "Current claim state")
      self~registerStateVariable("eventKey", "PUBLIC", "Optional normalized event identity key")
      self~registerStateVariable("sourceAuthenticationState", "PUBLIC", "Origin-authentication state retained independently from content confidence")
      self~registerStateVariable("sourceAuthenticationEvidenceId", "PUBLIC", "Origin-authentication evidence identity")
      self~registerStateVariable("sourceCompromised", "PUBLIC", "Source-history compromise state attached to this claim")
      self~registerStateVariable("sourceHistoryEvidenceId", "PUBLIC", "Source-history evidence identity")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONCORROBORATIONPOLICY" then do
      self~registerStateVariable("minimumIndependentFamilies", "PUBLIC", "Independent effective assertion-family threshold")
      self~registerStateVariable("minimumWeightedConfidence", "PUBLIC", "Corroboration confidence threshold")
      self~registerStateVariable("minimumContestFamilies", "PUBLIC", "Independent denial-family threshold")
      self~registerStateVariable("maximumTimeGapMinutes", "PUBLIC", "Maximum event clustering time gap")
    end
    when kind = "REPUTATIONCORROBORATIONEVIDENCEPOLICY" then do
      self~registerStateVariable("allowUnverifiedOrigin", "PUBLIC", "Whether unverified origin may count as corroboration evidence")
      self~registerStateVariable("allowUnassessedOrigin", "PUBLIC", "Whether legacy/unassessed origin may count as corroboration evidence")
      self~registerStateVariable("allowFailedAuthentication", "PUBLIC", "Explicit override permitting failed-authentication evidence to corroborate")
      self~registerStateVariable("allowCompromisedSource", "PUBLIC", "Explicit override permitting compromised-source evidence to corroborate")
    end
    when kind = "REPUTATIONCORROBORATIONEVIDENCESTATUS" then do
      self~registerStateVariable("claimId", "PUBLIC", "Claim identity whose provenance was assessed")
      self~registerStateVariable("familyId", "PUBLIC", "Effective corroboration family identity")
      self~registerStateVariable("publicationFamilyId", "PUBLIC", "Publication/article lineage family identity")
      self~registerStateVariable("assertionOriginFamilyId", "PUBLIC", "Explicit assertion ancestry root when resolved")
      self~registerStateVariable("assertionAncestryResolved", "PUBLIC", "Whether assertion ancestry is explicit or publication-lineage fallback")
      self~registerStateVariable("disposition", "PUBLIC", "ELIGIBLE or DISCOVERY_ONLY provenance disposition")
      self~registerStateVariable("reasonCode", "PUBLIC", "Deterministic provenance eligibility reason")
      self~registerStateVariable("authenticationState", "PUBLIC", "Retained origin-authentication state")
      self~registerStateVariable("compromised", "PUBLIC", "Retained source-history compromise state")
    end
    when kind = "REPUTATIONCORROBORATIONELIGIBILITYRESOLVER" then do
    end
    when kind = "REPUTATIONCORROBORATIONASSESSMENT" then do
      self~registerStateVariable("independentFamilyCount", "PUBLIC", "Observed effective corroboration-family count")
      self~registerStateVariable("publicationFamilyCount", "PUBLIC", "Observed publication/article lineage family count")
      self~registerStateVariable("explicitAssertionOriginFamilyCount", "PUBLIC", "Observed explicit assertion ancestry family count")
      self~registerStateVariable("ancestryResolvedClaimCount", "PUBLIC", "Active claims with explicit assertion ancestry")
      self~registerStateVariable("ancestryFallbackClaimCount", "PUBLIC", "Active claims using publication-lineage fallback")
      self~registerStateVariable("requiredIndependentFamilies", "PUBLIC", "Required independent evidence family count")
      self~registerStateVariable("weightedConfidence", "PUBLIC", "Family-normalised confidence")
      self~registerStateVariable("requiredWeightedConfidence", "PUBLIC", "Required confidence")
      self~registerStateVariable("status", "PUBLIC", "Corroboration status")
      self~registerStateVariable("thresholdSatisfied", "PUBLIC", "Corroboration threshold result")
      self~registerStateVariable("contested", "PUBLIC", "Independent contradiction state")
      self~registerStateVariable("eligibleClaimCount", "PUBLIC", "Claims admitted as corroboration evidence")
      self~registerStateVariable("discoveryOnlyClaimCount", "PUBLIC", "Claims retained but excluded from corroboration")
      self~registerStateVariable("eligibleIndependentFamilyCount", "PUBLIC", "Independent families admitted by provenance policy")
      self~registerStateVariable("discoveryOnlyFamilyCount", "PUBLIC", "Independent families present only as discovery evidence")
    end
    when kind = "REPUTATIONEVENTHYPOTHESIS" then do
      self~registerStateVariable("hypothesisId", "PUBLIC", "Event hypothesis identity")
      self~registerStateVariable("eventType", "PUBLIC", "Hypothesis event type")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONFEEDCORRECTION" then do
      self~registerStateVariable("correctionId", "PUBLIC", "Correction identity")
      self~registerStateVariable("targetClaimId", "PUBLIC", "Corrected claim identity")
      self~registerStateVariable("correctionType", "PUBLIC", "Correction relation")
      self~registerStateVariable("replacementClaimId", "PUBLIC", "Replacement claim identity")
      self~registerStateVariable("confidence", "PUBLIC", "Correction confidence")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONGEOGRAPHICSALIENCEEVIDENCE" then do
      self~registerStateVariable("hypothesisId", "PUBLIC", "Hypothesis identity")
      self~registerStateVariable("geographyId", "PUBLIC", "Measured geography")
      self~registerStateVariable("independentFamilyCount", "PUBLIC", "Independent evidence families in geography")
      self~registerStateVariable("publicationSurfaceCount", "PUBLIC", "Distribution surfaces in geography")
      self~registerStateVariable("publicationVelocityPerHour", "PUBLIC", "Observed publication velocity")
      self~registerStateVariable("officialAttention", "PUBLIC", "Official attention signal")
      self~registerStateVariable("confidence", "PUBLIC", "Salience evidence confidence")
    end
    when kind = "REPUTATIONWATCHSET" then do
      self~registerStateVariable("watchSetId", "PUBLIC", "Watchset identity")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONWATCHMATCH" then do
      self~registerStateVariable("watchSetId", "PUBLIC", "Watchset identity")
      self~registerStateVariable("hypothesisId", "PUBLIC", "Matched hypothesis identity")
      self~registerStateVariable("matched", "PUBLIC", "Watch match result")
      self~registerStateVariable("score", "PUBLIC", "Deterministic watch match score")
    end
    when kind = "REPUTATIONSOURCEIDENTITY" then do
      self~registerStateVariable("sourceId", "PUBLIC", "Stable feed source identity")
      self~registerStateVariable("sourceKind", "PUBLIC", "Source class")
      self~registerStateVariable("publisherGroup", "CUSTOMER", "Publisher group metadata, not lineage authority")
      self~registerStateVariable("ownershipGroup", "CUSTOMER", "Ownership metadata, not lineage authority")
      self~registerStateVariable("defaultGeographyId", "PUBLIC", "Default source geography")
      self~registerStateVariable("evidentialRole", "PUBLIC", "Descriptive evidential role, not trust score")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONRAWENVELOPE" then do
      self~registerStateVariable("envelopeId", "PUBLIC", "Raw transport envelope identity")
      self~registerStateVariable("contentType", "PUBLIC", "Retained transport content type")
      self~registerStateVariable("locator", "CUSTOMER", "Original source locator")
      self~registerStateVariable("payloadDigest", "PUBLIC", "Caller supplied transport digest")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONACQUIREDDOCUMENT" then do
      self~registerStateVariable("documentId", "PUBLIC", "Normalized document identity")
      self~registerStateVariable("documentKind", "PUBLIC", "Normalized document class")
      self~registerStateVariable("sourceEnvelopeId", "PUBLIC", "Originating raw envelope")
      self~registerStateVariable("title", "CUSTOMER", "Retained source title")
      self~registerStateVariable("observedGeographyId", "PUBLIC", "Observed/source geography")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONLIBRARIANHANDOFF" then do
      self~registerStateVariable("handoffId", "PUBLIC", "Librarian handoff identity")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONACQUISITIONRESULT" then do
      self~registerStateVariable("adapterId", "PUBLIC", "Adapter identity")
      self~registerStateVariable("envelopeId", "PUBLIC", "Source envelope identity")
      self~registerStateVariable("accepted", "PUBLIC", "Adapter acceptance result")
      self~registerStateVariable("status", "PUBLIC", "Adapter result status")
    end
    when kind = "REPUTATIONNEWSPUBLICATIONADAPTER" | kind = "REPUTATIONOFFICIALNOTICEADAPTER" | kind = "REPUTATIONPUBLICSTREAMADAPTER" | kind = "REPUTATIONSOURCEADAPTER" then do
      self~registerStateVariable("adapterId", "PUBLIC", "Source adapter identity")
      self~registerStateVariable("adapterKind", "PUBLIC", "Source adapter class")
    end
    when kind = "REPUTATIONLIBRARIANFINDING" then do
      self~registerStateVariable("findingId", "PUBLIC", "Librarian finding identity")
      self~registerStateVariable("handoffId", "PUBLIC", "Source handoff identity")
      self~registerStateVariable("eventType", "PUBLIC", "Extracted event type")
      self~registerStateVariable("confidence", "PUBLIC", "Librarian finding confidence")
      self~registerStateVariable("stance", "PUBLIC", "Extracted assertion stance")
      self~registerStateVariable("eventKey", "PUBLIC", "Provider-normalized event key")
      self~registerStateVariable("assertionOriginFamilyId", "PUBLIC", "Librarian-resolved claim-level assertion ancestry root")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONASSERTIONORIGINLINK" then do
      self~registerStateVariable("rootAssertionId", "PUBLIC", "Root assertion lineage identity")
      self~registerStateVariable("sourceId", "PUBLIC", "Source participating in assertion ancestry")
      self~registerStateVariable("relationship", "PUBLIC", "Relationship to root assertion")
      self~registerStateVariable("evidenceId", "PUBLIC", "Evidence supporting ancestry relation")
    end
    when kind = "REPUTATIONSOURCEKEYBINDING" then do
      self~registerStateVariable("bindingId", "PUBLIC", "Source authentication binding identity")
      self~registerStateVariable("sourceId", "PUBLIC", "Bound source identity")
      self~registerStateVariable("endpointId", "PUBLIC", "Bound source endpoint")
      self~registerStateVariable("algorithm", "PUBLIC", "Authentication algorithm")
      self~registerStateVariable("keyId", "PUBLIC", "Authentication key identity")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONSOURCEAUTHPROOF" then do
      self~registerStateVariable("proofId", "PUBLIC", "Detached source proof identity")
      self~registerStateVariable("sourceId", "PUBLIC", "Claimed source identity")
      self~registerStateVariable("bindingId", "PUBLIC", "Claimed source binding")
      self~registerStateVariable("algorithm", "PUBLIC", "Proof algorithm")
      self~registerStateVariable("keyId", "PUBLIC", "Proof key identity")
      self~registerStateVariable("payloadDigest", "CUSTOMER", "Digest bound by proof")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONSOURCEAUTHENTICATIONRESULT" then do
      self~registerStateVariable("resultId", "PUBLIC", "Source authentication result identity")
      self~registerStateVariable("sourceId", "PUBLIC", "Authenticated source identity")
      self~registerStateVariable("verified", "PUBLIC", "Whether origin proof verified")
      self~registerStateVariable("state", "PUBLIC", "Origin-authentication state")
      self~registerStateVariable("reasonCode", "PUBLIC", "Authentication result reason")
    end
    when kind = "REPUTATIONSOURCEAUTHENTICATOR" then do
    end
    when kind = "REPUTATIONSOURCEHISTORYEVENT" then do
      self~registerStateVariable("eventId", "PUBLIC", "Source-history event identity")
      self~registerStateVariable("sourceId", "PUBLIC", "Source identity")
      self~registerStateVariable("eventKind", "PUBLIC", "Source-history event kind")
      self~registerStateVariable("authenticationState", "PUBLIC", "Authentication state carried by event")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONSOURCEHISTORYVIEW" then do
      self~registerStateVariable("sourceId", "PUBLIC", "Source identity")
      self~registerStateVariable("authenticationState", "PUBLIC", "Latest authentication state as-of view")
      self~registerStateVariable("compromised", "PUBLIC", "Explicit compromise state as-of view")
      self~registerStateVariable("verifiedAuthenticationCount", "PUBLIC", "Historical verified-origin event count")
      self~registerStateVariable("failedAuthenticationCount", "PUBLIC", "Historical failed/unverified-origin event count")
      self~registerStateVariable("correctionCount", "PUBLIC", "Historical correction count")
      self~registerStateVariable("retractionCount", "PUBLIC", "Historical retraction count")
    end
    when kind = "REPUTATIONSOURCEHISTORYLEDGER" then do
    end
    when kind = "REPUTATIONSOURCEEVIDENCEPACKET" then do
      self~registerStateVariable("packetId", "PUBLIC", "Source-evidence packet identity")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONINTERACTIONEVIDENCEITEM" then do
      self~registerStateVariable("itemId", "PUBLIC", "Interaction evidence item identity")
      self~registerStateVariable("itemKind", "PUBLIC", "Projected interaction evidence kind")
      self~registerStateVariable("value", "CUSTOMER", "Privacy-projected interaction value")
      self~registerStateVariable("sourcePrivacyClass", "INTERNAL", "Source-domain privacy class retained as evidence")
      self~registerStateVariable("projectionKind", "PUBLIC", "Projection/abstraction mode")
      self~registerStateVariable("confidence", "PUBLIC", "Source evidence confidence")
      self~registerStateVariable("sourcePointId", "INTERNAL", "Stable source-domain evidence point")
    end
    when kind = "REPUTATIONINTERACTIONASSESSMENTEVIDENCE" then do
      self~registerStateVariable("assessmentId", "PUBLIC", "Source assessment identity")
      self~registerStateVariable("assessmentType", "PUBLIC", "Assessment class retained as assessment, not fact")
      self~registerStateVariable("value", "PUBLIC", "Controlled assessment value")
      self~registerStateVariable("assessorKind", "PUBLIC", "Assessment producer class")
      self~registerStateVariable("assessorId", "INTERNAL", "Assessment producer identity")
      self~registerStateVariable("modelId", "INTERNAL", "Optional model identity")
      self~registerStateVariable("confidence", "PUBLIC", "Assessment confidence, not Feed claim confidence")
    end
    when kind = "REPUTATIONINTERACTIONRELATIONSHIPEVIDENCE" then do
      self~registerStateVariable("relationshipId", "PUBLIC", "Source relationship identity")
      self~registerStateVariable("relationshipKind", "PUBLIC", "Relationship kind")
      self~registerStateVariable("fromPointId", "INTERNAL", "Source point")
      self~registerStateVariable("toPointId", "INTERNAL", "Target point")
      self~registerStateVariable("causalStatus", "PUBLIC", "Explicit source causal epistemic status")
      self~registerStateVariable("confidence", "PUBLIC", "Relationship confidence")
    end
    when kind = "REPUTATIONINTERACTIONEVIDENCEPACKET" then do
      self~registerStateVariable("packetId", "PUBLIC", "Interaction evidence packet identity")
      self~registerStateVariable("sourceKind", "PUBLIC", "Source domain class")
      self~registerStateVariable("sourceId", "PUBLIC", "Caller-supplied source identity")
      self~registerStateVariable("sourceObjectId", "INTERNAL", "Source-domain object identity")
      self~registerStateVariable("sourcePointId", "INTERNAL", "Stable source-domain point")
      self~registerStateVariable("surface", "PUBLIC", "Interaction surface")
      self~registerStateVariable("accessPointId", "INTERNAL", "External instrumentation access point")
      self~registerStateVariable("privacyProjectionMode", "PUBLIC", "Privacy projection boundary")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    when kind = "REPUTATIONINTERACTIONCLAIMSPEC" then do
      self~registerStateVariable("claimId", "PUBLIC", "Caller-assigned claim identity")
      self~registerStateVariable("familyId", "PUBLIC", "Representation/source family identity")
      self~registerStateVariable("eventType", "PUBLIC", "Caller-supplied event type")
      self~registerStateVariable("assertionRootId", "PUBLIC", "Explicit underlying interaction assertion root")
      self~registerStateVariable("confidence", "PUBLIC", "Caller-supplied claim confidence independent of source assessments")
      self~registerStateVariable("sealed", "PUBLIC", "Domain sealing state")
    end
    otherwise nop
  end
  return self


::class ReputationReachEvidence subclass ReputationFeedAlchemyObject public
::attribute estimatedAudience get
::attribute unit get
::attribute sourceId get
::attribute measuredAt get
::attribute confidence get
::attribute expiresAt get

::method init
  expose estimatedAudience unit sourceId measuredAt confidence expiresAt
  use arg estimatedAudienceArg, unitArg = "PERSONS", sourceIdArg = "", measuredAtArg = .nil, confidenceArg = 50, expiresAtArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationReachEvidence", alchemyContextArg)
  estimatedAudience = estimatedAudienceArg + 0
  if estimatedAudience < 0 then estimatedAudience = 0
  unit = unitArg~string~upper
  sourceId = sourceIdArg~string
  if measuredAtArg == .nil then measuredAt = .DateTime~new
  else measuredAt = measuredAtArg
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  expiresAt = expiresAtArg

::method isValidAt
  expose sourceId estimatedAudience expiresAt
  use arg moment = .nil
  if moment == .nil then moment = .DateTime~new
  if sourceId = "" then return .false
  if estimatedAudience < 0 then return .false
  if expiresAt \== .nil then if moment > expiresAt then return .false
  return .true

::method canonicalText
  expose estimatedAudience unit sourceId measuredAt confidence expiresAt
  return .ReputationFeedCanonical~field("REACH", estimatedAudience) || -
         .ReputationFeedCanonical~field("UNIT", unit) || -
         .ReputationFeedCanonical~field("SOURCE", sourceId) || -
         .ReputationFeedCanonical~field("MEASURED", measuredAt) || -
         .ReputationFeedCanonical~field("CONFIDENCE", confidence) || -
         .ReputationFeedCanonical~field("EXPIRES", expiresAt)


::class ReputationRangeEvidence subclass ReputationFeedAlchemyObject public
::attribute sourceId get
::attribute confidence get
::attribute measuredAt get

::method init
  expose geographies sourceId confidence measuredAt
  use arg sourceIdArg = "", confidenceArg = 50, measuredAtArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationRangeEvidence", alchemyContextArg)
  sourceId = sourceIdArg~string
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  if measuredAtArg == .nil then measuredAt = .DateTime~new
  else measuredAt = measuredAtArg
  geographies = .array~new

::method addGeography
  expose geographies
  use arg geographyId
  id = geographyId~string~upper
  if id <> "" & \.ReputationFeedCanonical~containsString(geographies, id) then geographies~append(id)
  return self

::method geographies
  expose geographies
  return .ReputationFeedCanonical~copyArray(geographies)

::method isValid
  expose sourceId geographies
  return sourceId <> "" & geographies~items > 0

::method canonicalText
  expose sourceId confidence measuredAt geographies
  return .ReputationFeedCanonical~field("RANGE_SOURCE", sourceId) || -
         .ReputationFeedCanonical~field("RANGE_CONFIDENCE", confidence) || -
         .ReputationFeedCanonical~field("RANGE_MEASURED", measuredAt) || -
         .ReputationFeedCanonical~join("RANGE_GEO", geographies)


::class ReputationPublicationSurface subclass ReputationFeedAlchemyObject public
::attribute surfaceId get
::attribute masthead get
::attribute publisherGroup get
::attribute publicationGeographyId get
::attribute publishedAt get
::attribute reachEvidence get
::attribute rangeEvidence get

::method init
  expose surfaceId masthead publisherGroup publicationGeographyId publishedAt reachEvidence rangeEvidence
  use arg surfaceIdArg, mastheadArg = "", publisherGroupArg = "", publicationGeographyArg = "", publishedAtArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationPublicationSurface", alchemyContextArg)
  surfaceId = surfaceIdArg~string
  masthead = mastheadArg~string
  publisherGroup = publisherGroupArg~string~upper
  publicationGeographyId = publicationGeographyArg~string~upper
  if publishedAtArg == .nil then publishedAt = .DateTime~new
  else publishedAt = publishedAtArg
  reachEvidence = .nil
  rangeEvidence = .nil

::method setReachEvidence
  expose reachEvidence
  use arg evidence
  reachEvidence = evidence
  return self

::method setRangeEvidence
  expose rangeEvidence
  use arg evidence
  rangeEvidence = evidence
  return self

::method canonicalText
  expose surfaceId masthead publisherGroup publicationGeographyId publishedAt reachEvidence rangeEvidence
  text = .ReputationFeedCanonical~field("SURFACE", surfaceId)
  text ||= .ReputationFeedCanonical~field("MASTHEAD", masthead)
  text ||= .ReputationFeedCanonical~field("PUBLISHER_GROUP", publisherGroup)
  text ||= .ReputationFeedCanonical~field("PUBLICATION_GEO", publicationGeographyId)
  text ||= .ReputationFeedCanonical~field("PUBLISHED", publishedAt)
  if reachEvidence == .nil then reachText = "NONE"; else reachText = reachEvidence~canonicalText
  if rangeEvidence == .nil then rangeText = "NONE"; else rangeText = rangeEvidence~canonicalText
  text ||= .ReputationFeedCanonical~field("REACH_EVIDENCE", reachText)
  text ||= .ReputationFeedCanonical~field("RANGE_EVIDENCE", rangeText)
  return text


::class ReputationFeedArticle subclass ReputationFeedAlchemyObject public
::attribute articleId get
::attribute sourceId get
::attribute publisherGroup get
::attribute title get
::attribute publishedAt get
::attribute sealed get

::method init
  expose articleId sourceId publisherGroup title publishedAt surfaces sealed
  use arg articleIdArg, sourceIdArg, publisherGroupArg = "", titleArg = "", publishedAtArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedArticle", alchemyContextArg)
  articleId = articleIdArg~string~upper
  sourceId = sourceIdArg~string~upper
  publisherGroup = publisherGroupArg~string~upper
  title = titleArg~string
  if publishedAtArg == .nil then publishedAt = .DateTime~new
  else publishedAt = publishedAtArg
  surfaces = .array~new
  sealed = .false

::method addSurface
  expose surfaces sealed
  use arg surface
  if sealed | surface == .nil then return .false
  surfaces~append(surface)
  return .true

::method surfaces
  expose surfaces
  return .ReputationFeedCanonical~copyArray(surfaces)

::method seal
  expose sealed
  sealed = .true
  return self

::method canonicalText
  expose articleId sourceId publisherGroup title publishedAt surfaces sealed
  if \sealed then raise syntax 93.900 additional("ReputationFeedArticle must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("ARTICLE", articleId)
  text ||= .ReputationFeedCanonical~field("SOURCE", sourceId)
  text ||= .ReputationFeedCanonical~field("PUBLISHER_GROUP", publisherGroup)
  text ||= .ReputationFeedCanonical~field("TITLE", title)
  text ||= .ReputationFeedCanonical~field("PUBLISHED", publishedAt)
  surfaceTexts = .array~new
  do surface over surfaces; surfaceTexts~append(surface~canonicalText); end
  text ||= .ReputationFeedCanonical~join("SURFACE", surfaceTexts)
  return text


::class ReputationParagraphComparison subclass ReputationFeedAlchemyObject public
::attribute leftIndex get
::attribute rightIndex get
::attribute corpusId get
::attribute lexicalSimilarity get
::attribute semanticSimilarity get
::attribute claimOverlap get
::attribute entityOverlap get
::attribute numericFactOverlap get
::attribute temporalFactOverlap get
::attribute roleSimilarity get
::attribute confidence get

::method init
  expose leftIndex rightIndex corpusId lexicalSimilarity semanticSimilarity claimOverlap entityOverlap numericFactOverlap temporalFactOverlap roleSimilarity confidence
  use arg leftIndexArg, rightIndexArg, corpusIdArg, lexicalArg = 0, semanticArg = 0, claimArg = 0, entityArg = 0, numericArg = 0, temporalArg = 0, roleArg = 0, confidenceArg = 100, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationParagraphComparison", alchemyContextArg)
  leftIndex = leftIndexArg + 0
  rightIndex = rightIndexArg + 0
  corpusId = corpusIdArg~string~upper
  lexicalSimilarity = .ReputationFeedCanonical~clamp(lexicalArg)
  semanticSimilarity = .ReputationFeedCanonical~clamp(semanticArg)
  claimOverlap = .ReputationFeedCanonical~clamp(claimArg)
  entityOverlap = .ReputationFeedCanonical~clamp(entityArg)
  numericFactOverlap = .ReputationFeedCanonical~clamp(numericArg)
  temporalFactOverlap = .ReputationFeedCanonical~clamp(temporalArg)
  roleSimilarity = .ReputationFeedCanonical~clamp(roleArg)
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)

::method combinedScore
  expose lexicalSimilarity semanticSimilarity claimOverlap entityOverlap numericFactOverlap temporalFactOverlap roleSimilarity confidence
  raw = lexicalSimilarity * 5 + semanticSimilarity * 30 + claimOverlap * 25 + entityOverlap * 15 + numericFactOverlap * 10 + temporalFactOverlap * 10 + roleSimilarity * 5
  raw = raw / 100
  return trunc(raw * confidence / 100)

::method canonicalText
  return .ReputationFeedCanonical~field("LEFT_P", self~leftIndex) || -
         .ReputationFeedCanonical~field("RIGHT_P", self~rightIndex) || -
         .ReputationFeedCanonical~field("CORPUS", self~corpusId) || -
         .ReputationFeedCanonical~field("SCORE", self~combinedScore)


::class ReputationArticleComparison subclass ReputationFeedAlchemyObject public
::attribute comparisonId get
::attribute leftArticleId get
::attribute rightArticleId get
::attribute corpusId get
::attribute sequenceAlignment get
::attribute rareFactOverlap get
::attribute claimedOriginId get
::attribute sealed get

::method init
  expose comparisonId leftArticleId rightArticleId corpusId sequenceAlignment rareFactOverlap claimedOriginId paragraphs sealed
  use arg comparisonIdArg, leftArticleIdArg, rightArticleIdArg, corpusIdArg, sequenceAlignmentArg = 0, rareFactOverlapArg = 0, claimedOriginArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationArticleComparison", alchemyContextArg)
  comparisonId = comparisonIdArg~string
  leftArticleId = leftArticleIdArg~string~upper
  rightArticleId = rightArticleIdArg~string~upper
  corpusId = corpusIdArg~string~upper
  sequenceAlignment = .ReputationFeedCanonical~clamp(sequenceAlignmentArg)
  rareFactOverlap = .ReputationFeedCanonical~clamp(rareFactOverlapArg)
  claimedOriginId = claimedOriginArg~string~upper
  paragraphs = .array~new
  sealed = .false

::method addParagraphComparison
  expose paragraphs sealed corpusId
  use arg comparison
  if sealed | comparison == .nil then return .false
  if corpusId <> "" & comparison~corpusId <> corpusId then return .false
  paragraphs~append(comparison)
  return .true

::method paragraphComparisons
  expose paragraphs
  return .ReputationFeedCanonical~copyArray(paragraphs)

::method alignedParagraphCount
  expose paragraphs
  return paragraphs~items

::method articleScore
  expose paragraphs sequenceAlignment rareFactOverlap
  if paragraphs~items = 0 then return 0
  total = 0
  do comparison over paragraphs; total += comparison~combinedScore; end
  paragraphMean = total / paragraphs~items
  return trunc(paragraphMean * 0.75 + sequenceAlignment * 0.15 + rareFactOverlap * 0.10)

::method seal
  expose sealed
  sealed = .true
  return self

::method canonicalText
  expose comparisonId leftArticleId rightArticleId corpusId sequenceAlignment rareFactOverlap claimedOriginId paragraphs sealed
  if \sealed then raise syntax 93.900 additional("ReputationArticleComparison must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("COMPARISON", comparisonId)
  text ||= .ReputationFeedCanonical~field("LEFT", leftArticleId)
  text ||= .ReputationFeedCanonical~field("RIGHT", rightArticleId)
  text ||= .ReputationFeedCanonical~field("CORPUS", corpusId)
  text ||= .ReputationFeedCanonical~field("SEQUENCE", sequenceAlignment)
  text ||= .ReputationFeedCanonical~field("RARE_FACT", rareFactOverlap)
  text ||= .ReputationFeedCanonical~field("CLAIMED_ORIGIN", claimedOriginId)
  paragraphTexts = .array~new
  do paragraph over paragraphs; paragraphTexts~append(paragraph~canonicalText); end
  text ||= .ReputationFeedCanonical~join("PARAGRAPH", paragraphTexts)
  return text


::class ReputationLineagePolicy subclass ReputationFeedAlchemyObject public
::attribute articleSimilarityThreshold get
::attribute minimumAlignedParagraphs get

::method init
  expose articleSimilarityThreshold minimumAlignedParagraphs
  use arg thresholdArg = 78, minimumAlignedArg = 2, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationLineagePolicy", alchemyContextArg)
  articleSimilarityThreshold = .ReputationFeedCanonical~clamp(thresholdArg)
  minimumAlignedParagraphs = minimumAlignedArg + 0
  if minimumAlignedParagraphs < 1 then minimumAlignedParagraphs = 1

::method sameLineage
  expose articleSimilarityThreshold minimumAlignedParagraphs
  use arg comparison
  if comparison == .nil then return .false
  if \comparison~sealed then return .false
  return comparison~alignedParagraphCount >= minimumAlignedParagraphs & comparison~articleScore >= articleSimilarityThreshold


::class ReputationArticleFamily subclass ReputationFeedAlchemyObject public
::attribute familyId get
::attribute probableRootArticleId get

::method init
  expose familyId probableRootArticleId articles
  use arg familyIdArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationArticleFamily", alchemyContextArg)
  familyId = familyIdArg~string~upper
  probableRootArticleId = ""
  articles = .array~new

::method addArticle
  expose articles probableRootArticleId
  use arg article
  if article == .nil then return .false
  do existing over articles
    if existing~articleId == article~articleId then return .false
  end
  articles~append(article)
  if probableRootArticleId = "" | article~articleId < probableRootArticleId then probableRootArticleId = article~articleId
  return .true

::method articles
  expose articles
  return .ReputationFeedCanonical~copyArray(articles)

::method articleCount
  expose articles
  return articles~items

::method publicationSurfaceCount
  expose articles
  total = 0
  do article over articles; total += article~surfaces~items; end
  return total

::method publisherGroups
  expose articles
  groups = .array~new
  do article over articles
    if article~publisherGroup <> "" & \.ReputationFeedCanonical~containsString(groups, article~publisherGroup) then groups~append(article~publisherGroup)
  end
  groups~sort
  return groups


::class ReputationLineageResult subclass ReputationFeedAlchemyObject public
::method init
  expose families articleFamily
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationLineageResult", alchemyContextArg)
  families = .array~new
  articleFamily = .directory~new

::method addFamily
  expose families articleFamily
  use arg family
  families~append(family)
  do article over family~articles; articleFamily[article~articleId] = family; end
  return self

::method families
  expose families
  return .ReputationFeedCanonical~copyArray(families)

::method familyForArticle
  expose articleFamily
  use arg articleId
  id = articleId~string~upper
  if articleFamily~hasIndex(id) then return articleFamily[id]
  return .nil

::method independentSourceCount
  expose families
  return families~items

::method canonicalText
  expose families
  familyTexts = .array~new
  do family over families
    articleIds = .array~new
    do article over family~articles; articleIds~append(article~articleId); end
    articleIds~sort
    text = .ReputationFeedCanonical~field("FAMILY", family~familyId)
    text ||= .ReputationFeedCanonical~field("ROOT", family~probableRootArticleId)
    text ||= .ReputationFeedCanonical~join("ARTICLE", articleIds)
    familyTexts~append(text)
  end
  return .ReputationFeedCanonical~join("LINEAGE_FAMILY", familyTexts)


::class ReputationLineageEngine subclass ReputationFeedAlchemyObject public
::method group
  use arg articles, comparisons, policy = .nil
  self~alchemyTouch("GROUP")
  if policy == .nil then policy = .ReputationLineagePolicy~new
  byId = .directory~new
  adjacency = .directory~new
  ids = .array~new
  do article over articles
    if \article~sealed then raise syntax 88.900 array("Lineage input article must be sealed")
    id = article~articleId
    byId[id] = article
    adjacency[id] = .array~new
    ids~append(id)
  end
  do comparison over comparisons
    if \policy~sameLineage(comparison) then iterate
    left = comparison~leftArticleId
    right = comparison~rightArticleId
    if \byId~hasIndex(left) | \byId~hasIndex(right) then iterate
    if \.ReputationFeedCanonical~containsString(adjacency[left], right) then adjacency[left]~append(right)
    if \.ReputationFeedCanonical~containsString(adjacency[right], left) then adjacency[right]~append(left)
  end
  ids~sort
  seen = .directory~new
  lineageResult = .ReputationLineageResult~new
  familyNumber = 0
  do start over ids
    if seen~hasIndex(start) then iterate
    familyNumber += 1
    family = .ReputationArticleFamily~new("FAMILY-" || familyNumber)
    queue = .array~of(start)
    seen[start] = .true
    do while queue~items > 0
      queueIndex = queue~first
      currentId = queue[queueIndex]
      queue~remove(queueIndex)
      family~addArticle(byId[currentId])
      do neighbour over adjacency[currentId]
        if seen~hasIndex(neighbour) then iterate
        seen[neighbour] = .true
        queue~append(neighbour)
      end
    end
    lineageResult~addFamily(family)
  end
  return lineageResult


::class ReputationReachRangeSummary subclass ReputationFeedAlchemyObject public
::attribute publicationSurfaceCount get
::attribute lineageFamilyCount get
::attribute validatedReachSurfaceCount get
::attribute grossValidatedReach get
::attribute reachComplete get
::attribute rangeComplete get

::method init
  expose publicationSurfaceCount lineageFamilyCount validatedReachSurfaceCount grossValidatedReach reachComplete rangeComplete rangeGeographies
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationReachRangeSummary", alchemyContextArg)
  publicationSurfaceCount = 0
  lineageFamilyCount = 0
  validatedReachSurfaceCount = 0
  grossValidatedReach = 0
  reachComplete = .true
  rangeComplete = .true
  rangeGeographies = .array~new

::method rangeGeographies
  expose rangeGeographies
  return .ReputationFeedCanonical~copyArray(rangeGeographies)

::method build class
  use arg articles, lineageResult, moment = .nil
  if moment == .nil then moment = .DateTime~new
  summary = self~new
  summary~populate(articles, lineageResult, moment)
  return summary

::method populate private
  expose publicationSurfaceCount lineageFamilyCount validatedReachSurfaceCount grossValidatedReach reachComplete rangeComplete rangeGeographies
  use arg articles, lineageResult, moment
  lineageFamilyCount = lineageResult~independentSourceCount
  do article over articles
    do surface over article~surfaces
      publicationSurfaceCount += 1
      reach = surface~reachEvidence
      if reach == .nil then reachComplete = .false
      else if \reach~isValidAt(moment) then reachComplete = .false
      else do
        validatedReachSurfaceCount += 1
        grossValidatedReach += reach~estimatedAudience
      end
      range = surface~rangeEvidence
      if range == .nil then rangeComplete = .false
      else if \range~isValid then rangeComplete = .false
      else do geography over range~geographies
        if \.ReputationFeedCanonical~containsString(rangeGeographies, geography) then rangeGeographies~append(geography)
      end
    end
  end
  rangeGeographies~sort



::class ReputationFeedQueuePersistenceValue public
::method truth class
  use arg value
  if value == .true then return .true
  if value == .false | value == .nil then return .false
  text = value~string~upper
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"

::method boolText class
  use arg value
  if self~truth(value) then return "1"
  return "0"

::method dateText class
  use arg value
  if value == .nil then return ""
  return value~string

::method dateValue class
  use arg value
  text = value~string~strip
  if text = "" then return .nil
  return .DateTime~fromIsoDate(text)


/* -------------------------------------------------------------------------
 * Event-hypothesis / corroboration layer.
 *
 * These objects remain acquisition evidence.  They do not create a
 * ReputationEvent and do not assign reputational direction.
 * ------------------------------------------------------------------------- */

::class ReputationFeedSubjectLink subclass ReputationFeedAlchemyObject public
::attribute subjectKind get
::attribute subjectId get
::attribute strength get

::method init
  expose subjectKind subjectId strength
  use arg kindArg, idArg, strengthArg = 100, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedSubjectLink", alchemyContextArg)
  subjectKind = kindArg~string~upper
  subjectId = idArg~string~upper
  strength = .ReputationFeedCanonical~clamp(strengthArg)

::method key
  expose subjectKind subjectId
  return subjectKind || "|" || subjectId

::method canonicalText
  return .ReputationFeedCanonical~field("SUBJECT", self~key) || -
         .ReputationFeedCanonical~field("STRENGTH", self~strength)


::class ReputationAssertionOriginLink subclass ReputationFeedAlchemyObject public
::attribute rootAssertionId get
::attribute sourceId get
::attribute relationship get
::attribute evidenceId get
::attribute detail get

::method init
  expose rootAssertionId sourceId relationship evidenceId detail
  use arg rootAssertionIdArg, sourceIdArg, relationshipArg = "DERIVED_FROM", evidenceIdArg = "", detailArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationAssertionOriginLink", alchemyContextArg)
  rootAssertionId = rootAssertionIdArg~string~upper~strip
  sourceId = sourceIdArg~string~upper~strip
  relationship = relationshipArg~string~upper~strip
  evidenceId = evidenceIdArg~string~upper~strip
  detail = detailArg~string
  if rootAssertionId = "" then raise syntax 88.900 array("ReputationAssertionOriginLink requires rootAssertionId")
  if sourceId = "" then raise syntax 88.900 array("ReputationAssertionOriginLink requires sourceId")
  if relationship = "" then relationship = "DERIVED_FROM"

::method canonicalText
  return .ReputationFeedCanonical~field("ROOT_ASSERTION", self~rootAssertionId) || -
         .ReputationFeedCanonical~field("SOURCE", self~sourceId) || -
         .ReputationFeedCanonical~field("RELATIONSHIP", self~relationship) || -
         .ReputationFeedCanonical~field("EVIDENCE", self~evidenceId) || -
         .ReputationFeedCanonical~field("DETAIL", self~detail)


::class ReputationFeedClaim subclass ReputationFeedAlchemyObject public
::attribute claimId get
::attribute articleId get
::attribute familyId get
::attribute assertionOriginFamilyId get
::attribute assertionAncestryResolved get
::attribute eventType get
::attribute title get
::attribute occurredAt get
::attribute observedAt get
::attribute observedGeographyId get
::attribute confidence get
::attribute stance get
::attribute claimState get
::attribute sourceId get
::attribute citation get
::attribute eventKey get
::attribute sourceAuthenticationState get
::attribute sourceAuthenticationEvidenceId get
::attribute sourceCompromised get
::attribute sourceHistoryEvidenceId get
::attribute sealed get

::method init
  expose claimId articleId familyId assertionOriginFamilyId assertionAncestryResolved eventType title occurredAt observedAt observedGeographyId confidence stance claimState sourceId citation eventKey sourceAuthenticationState sourceAuthenticationEvidenceId sourceCompromised sourceHistoryEvidenceId assertionOrigins subjects concepts affectedGeographies sealed
  use arg claimIdArg, articleIdArg, familyIdArg, eventTypeArg, titleArg = "", occurredAtArg = .nil, observedAtArg = .nil, observedGeographyArg = "", confidenceArg = 50, stanceArg = "ASSERTS", claimStateArg = "ACTIVE", sourceIdArg = "", citationArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedClaim", alchemyContextArg)
  claimId = claimIdArg~string~upper
  articleId = articleIdArg~string~upper
  familyId = familyIdArg~string~upper
  assertionOriginFamilyId = ""
  assertionAncestryResolved = .false
  eventType = eventTypeArg~string~upper
  title = titleArg~string
  if occurredAtArg == .nil then occurredAt = .DateTime~new; else occurredAt = occurredAtArg
  if observedAtArg == .nil then observedAt = .DateTime~new; else observedAt = observedAtArg
  observedGeographyId = observedGeographyArg~string~upper
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  stance = stanceArg~string~upper
  claimState = claimStateArg~string~upper
  sourceId = sourceIdArg~string
  citation = citationArg~string
  eventKey = ""
  sourceAuthenticationState = "UNASSESSED"
  sourceAuthenticationEvidenceId = ""
  sourceCompromised = .false
  sourceHistoryEvidenceId = ""
  assertionOrigins = .array~new
  subjects = .array~new
  concepts = .array~new
  affectedGeographies = .array~new
  sealed = .false

::method setEventKey
  expose eventKey sealed
  use arg eventKeyArg
  if sealed then return .false
  eventKey = eventKeyArg~string~upper~strip
  return .true

::method addAssertionOrigin
  expose assertionOrigins assertionOriginFamilyId assertionAncestryResolved sealed
  use arg rootAssertionIdArg, sourceIdArg, relationshipArg = "DERIVED_FROM", evidenceIdArg = "", detailArg = ""
  if sealed then return .false
  root = rootAssertionIdArg~string~upper~strip
  if root = "" then return .false
  if assertionOriginFamilyId <> "" & assertionOriginFamilyId <> root then raise syntax 88.900 array("ReputationFeedClaim represents one atomic assertion and cannot carry multiple assertion roots")
  link = .ReputationAssertionOriginLink~new(root, sourceIdArg, relationshipArg, evidenceIdArg, detailArg, self~domainAlchemyContext)
  do existing over assertionOrigins
    if existing~canonicalText == link~canonicalText then return .false
  end
  assertionOrigins~append(link)
  assertionOriginFamilyId = root
  assertionAncestryResolved = .true
  return .true

::method setSourceAuthentication
  expose sourceAuthenticationState sourceAuthenticationEvidenceId sourceCompromised sourceHistoryEvidenceId sealed
  use arg stateArg, evidenceIdArg = "", compromisedArg = .false, historyEvidenceIdArg = ""
  if sealed then return .false
  sourceAuthenticationState = stateArg~string~upper~strip
  sourceAuthenticationEvidenceId = evidenceIdArg~string~upper~strip
  sourceCompromised = compromisedArg
  sourceHistoryEvidenceId = historyEvidenceIdArg~string~upper~strip
  return .true

::method addSubject
  expose subjects sealed
  use arg kindArg, idArg, strengthArg = 100
  if sealed then return .false
  link = .ReputationFeedSubjectLink~new(kindArg, idArg, strengthArg, self~domainAlchemyContext)
  do existing over subjects
    if existing~key == link~key then return .false
  end
  subjects~append(link)
  return .true

::method addConcept
  expose concepts sealed
  use arg conceptArg
  if sealed then return .false
  concept = conceptArg~string~upper~strip
  if concept = "" then return .false
  if \.ReputationFeedCanonical~containsString(concepts, concept) then concepts~append(concept)
  return .true

::method addAffectedGeography
  expose affectedGeographies sealed
  use arg geographyArg
  if sealed then return .false
  geography = geographyArg~string~upper~strip
  if geography = "" then return .false
  if \.ReputationFeedCanonical~containsString(affectedGeographies, geography) then affectedGeographies~append(geography)
  return .true

::method subjects
  expose subjects
  return .ReputationFeedCanonical~copyArray(subjects)

::method subjectKeys
  expose subjects
  keys = .array~new
  do link over subjects; keys~append(link~key); end
  keys~sort
  return keys

::method concepts
  expose concepts
  return .ReputationFeedCanonical~copyArray(concepts)

::method affectedGeographies
  expose affectedGeographies
  return .ReputationFeedCanonical~copyArray(affectedGeographies)

::method assertionOrigins
  expose assertionOrigins
  return .ReputationFeedCanonical~copyArray(assertionOrigins)

::method corroborationFamilyId
  expose assertionOriginFamilyId familyId claimId
  if assertionOriginFamilyId <> "" then return "ASSERTION:" || assertionOriginFamilyId
  if familyId <> "" then return "PUBLICATION:" || familyId
  return "CLAIM:" || claimId

::method isActive
  expose claimState
  return claimState = "ACTIVE" | claimState = "UNVERIFIED" | claimState = "CORROBORATED"

::method seal
  expose sealed
  sealed = .true
  return self

::method canonicalText
  expose claimId articleId familyId assertionOriginFamilyId assertionAncestryResolved eventType title occurredAt observedAt observedGeographyId confidence stance claimState sourceId citation eventKey sourceAuthenticationState sourceAuthenticationEvidenceId sourceCompromised sourceHistoryEvidenceId assertionOrigins subjects concepts affectedGeographies sealed
  if \sealed then raise syntax 93.900 additional("ReputationFeedClaim must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("CLAIM", claimId)
  text ||= .ReputationFeedCanonical~field("ARTICLE", articleId)
  text ||= .ReputationFeedCanonical~field("FAMILY", familyId)
  text ||= .ReputationFeedCanonical~field("ASSERTION_ORIGIN_FAMILY", assertionOriginFamilyId)
  text ||= .ReputationFeedCanonical~field("ASSERTION_ANCESTRY_RESOLVED", assertionAncestryResolved)
  text ||= .ReputationFeedCanonical~field("EVENT_TYPE", eventType)
  text ||= .ReputationFeedCanonical~field("TITLE", title)
  text ||= .ReputationFeedCanonical~field("OCCURRED", occurredAt)
  text ||= .ReputationFeedCanonical~field("OBSERVED", observedAt)
  text ||= .ReputationFeedCanonical~field("OBSERVED_GEO", observedGeographyId)
  text ||= .ReputationFeedCanonical~field("CONFIDENCE", confidence)
  text ||= .ReputationFeedCanonical~field("STANCE", stance)
  text ||= .ReputationFeedCanonical~field("STATE", claimState)
  text ||= .ReputationFeedCanonical~field("SOURCE", sourceId)
  text ||= .ReputationFeedCanonical~field("CITATION", citation)
  text ||= .ReputationFeedCanonical~field("EVENT_KEY", eventKey)
  text ||= .ReputationFeedCanonical~field("SOURCE_AUTH_STATE", sourceAuthenticationState)
  text ||= .ReputationFeedCanonical~field("SOURCE_AUTH_EVIDENCE", sourceAuthenticationEvidenceId)
  text ||= .ReputationFeedCanonical~field("SOURCE_COMPROMISED", sourceCompromised)
  text ||= .ReputationFeedCanonical~field("SOURCE_HISTORY_EVIDENCE", sourceHistoryEvidenceId)
  originTexts = .array~new
  do origin over assertionOrigins; originTexts~append(origin~canonicalText); end
  text ||= .ReputationFeedCanonical~join("ASSERTION_ORIGIN", originTexts)
  subjectTexts = .array~new
  do link over subjects; subjectTexts~append(link~canonicalText); end
  text ||= .ReputationFeedCanonical~join("SUBJECT", subjectTexts)
  text ||= .ReputationFeedCanonical~join("CONCEPT", concepts)
  text ||= .ReputationFeedCanonical~join("AFFECTED_GEO", affectedGeographies)
  return text


::method queuePersistentType
  return "reputation.feed.claim/1"

::method queuePersistentState
  expose claimId articleId familyId assertionOriginFamilyId assertionAncestryResolved eventType title occurredAt observedAt observedGeographyId confidence stance claimState sourceId citation eventKey sourceAuthenticationState sourceAuthenticationEvidenceId sourceCompromised sourceHistoryEvidenceId assertionOrigins subjects concepts affectedGeographies sealed
  if \sealed then raise syntax 88.900 array("Unsealed ReputationFeedClaim cannot cross the durable Queue Fabric boundary")
  state = .table~new
  state["claimId"] = claimId
  state["articleId"] = articleId
  state["familyId"] = familyId
  state["assertionOriginFamilyId"] = assertionOriginFamilyId
  state["assertionAncestryResolved"] = .ReputationFeedQueuePersistenceValue~boolText(assertionAncestryResolved)
  state["eventType"] = eventType
  state["title"] = title
  state["occurredAt"] = .ReputationFeedQueuePersistenceValue~dateText(occurredAt)
  state["observedAt"] = .ReputationFeedQueuePersistenceValue~dateText(observedAt)
  state["observedGeographyId"] = observedGeographyId
  state["confidence"] = confidence~string
  state["stance"] = stance
  state["claimState"] = claimState
  state["sourceId"] = sourceId
  state["citation"] = citation
  state["eventKey"] = eventKey
  state["sourceAuthenticationState"] = sourceAuthenticationState
  state["sourceAuthenticationEvidenceId"] = sourceAuthenticationEvidenceId
  state["sourceCompromised"] = .ReputationFeedQueuePersistenceValue~boolText(sourceCompromised)
  state["sourceHistoryEvidenceId"] = sourceHistoryEvidenceId
  originRows = .array~new
  do origin over assertionOrigins
    row = .table~new
    row["rootAssertionId"] = origin~rootAssertionId
    row["sourceId"] = origin~sourceId
    row["relationship"] = origin~relationship
    row["evidenceId"] = origin~evidenceId
    row["detail"] = origin~detail
    originRows~append(row)
  end
  state["assertionOrigins"] = originRows
  subjectRows = .array~new
  do subject over subjects
    row = .table~new
    row["subjectKind"] = subject~subjectKind
    row["subjectId"] = subject~subjectId
    row["strength"] = subject~strength~string
    subjectRows~append(row)
  end
  state["subjects"] = subjectRows
  state["concepts"] = .ReputationFeedCanonical~copyArray(concepts)
  state["affectedGeographies"] = .ReputationFeedCanonical~copyArray(affectedGeographies)
  return state

::method queueRestoreState
  expose claimId articleId familyId assertionOriginFamilyId assertionAncestryResolved eventType title occurredAt observedAt observedGeographyId confidence stance claimState sourceId citation eventKey sourceAuthenticationState sourceAuthenticationEvidenceId sourceCompromised sourceHistoryEvidenceId assertionOrigins subjects concepts affectedGeographies sealed
  use arg state
  claimId = state["claimId"]~string
  articleId = state["articleId"]~string
  familyId = state["familyId"]~string
  assertionOriginFamilyId = state["assertionOriginFamilyId"]~string
  assertionAncestryResolved = .ReputationFeedQueuePersistenceValue~truth(state["assertionAncestryResolved"])
  eventType = state["eventType"]~string
  title = state["title"]~string
  occurredAt = .ReputationFeedQueuePersistenceValue~dateValue(state["occurredAt"])
  observedAt = .ReputationFeedQueuePersistenceValue~dateValue(state["observedAt"])
  observedGeographyId = state["observedGeographyId"]~string
  confidence = state["confidence"] + 0
  stance = state["stance"]~string
  claimState = state["claimState"]~string
  sourceId = state["sourceId"]~string
  citation = state["citation"]~string
  eventKey = state["eventKey"]~string
  sourceAuthenticationState = state["sourceAuthenticationState"]~string
  sourceAuthenticationEvidenceId = state["sourceAuthenticationEvidenceId"]~string
  sourceCompromised = .ReputationFeedQueuePersistenceValue~truth(state["sourceCompromised"])
  sourceHistoryEvidenceId = state["sourceHistoryEvidenceId"]~string
  assertionOrigins = .array~new
  do row over state["assertionOrigins"]
    assertionOrigins~append(.ReputationAssertionOriginLink~new(row["rootAssertionId"], row["sourceId"], row["relationship"], row["evidenceId"], row["detail"], self~domainAlchemyContext))
  end
  subjects = .array~new
  do row over state["subjects"]
    subjects~append(.ReputationFeedSubjectLink~new(row["subjectKind"], row["subjectId"], row["strength"], self~domainAlchemyContext))
  end
  concepts = .ReputationFeedCanonical~copyArray(state["concepts"])
  affectedGeographies = .ReputationFeedCanonical~copyArray(state["affectedGeographies"])
  sealed = .true
  return self


::class ReputationCorroborationPolicy subclass ReputationFeedAlchemyObject public
::attribute minimumIndependentFamilies get
::attribute minimumWeightedConfidence get
::attribute minimumContestFamilies get
::attribute maximumTimeGapMinutes get
::attribute requireSubjectOrConceptOverlap get

::method init
  expose minimumIndependentFamilies minimumWeightedConfidence minimumContestFamilies maximumTimeGapMinutes requireSubjectOrConceptOverlap
  use arg familiesArg = 2, confidenceArg = 70, contestArg = 1, gapMinutesArg = 180, requireOverlapArg = .true, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationCorroborationPolicy", alchemyContextArg)
  minimumIndependentFamilies = familiesArg + 0
  if minimumIndependentFamilies < 1 then minimumIndependentFamilies = 1
  minimumWeightedConfidence = .ReputationFeedCanonical~clamp(confidenceArg)
  minimumContestFamilies = contestArg + 0
  if minimumContestFamilies < 1 then minimumContestFamilies = 1
  maximumTimeGapMinutes = gapMinutesArg + 0
  if maximumTimeGapMinutes < 0 then maximumTimeGapMinutes = 0
  requireSubjectOrConceptOverlap = requireOverlapArg


::class ReputationCorroborationEvidencePolicy subclass ReputationFeedAlchemyObject public
::attribute allowUnverifiedOrigin get
::attribute allowUnassessedOrigin get
::attribute allowFailedAuthentication get
::attribute allowCompromisedSource get

::method init
  expose allowUnverifiedOrigin allowUnassessedOrigin allowFailedAuthentication allowCompromisedSource
  use arg allowUnverifiedArg = .true, allowUnassessedArg = .true, allowFailedArg = .false, allowCompromisedArg = .false, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationCorroborationEvidencePolicy", alchemyContextArg)
  allowUnverifiedOrigin = allowUnverifiedArg
  allowUnassessedOrigin = allowUnassessedArg
  allowFailedAuthentication = allowFailedArg
  allowCompromisedSource = allowCompromisedArg


::class ReputationCorroborationEvidenceStatus subclass ReputationFeedAlchemyObject public
::attribute claimId get
::attribute familyId get
::attribute publicationFamilyId get
::attribute assertionOriginFamilyId get
::attribute assertionAncestryResolved get
::attribute disposition get
::attribute reasonCode get
::attribute authenticationState get
::attribute compromised get
::attribute authenticationEvidenceId get
::attribute historyEvidenceId get

::method init
  expose claimId familyId publicationFamilyId assertionOriginFamilyId assertionAncestryResolved disposition reasonCode authenticationState compromised authenticationEvidenceId historyEvidenceId
  use arg claimIdArg, familyIdArg, dispositionArg, reasonArg, authStateArg, compromisedArg, authEvidenceArg = "", historyEvidenceArg = "", publicationFamilyArg = "", assertionOriginFamilyArg = "", ancestryResolvedArg = .false, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationCorroborationEvidenceStatus", alchemyContextArg)
  claimId = claimIdArg~string~upper~strip
  familyId = familyIdArg~string~upper~strip
  publicationFamilyId = publicationFamilyArg~string~upper~strip
  assertionOriginFamilyId = assertionOriginFamilyArg~string~upper~strip
  assertionAncestryResolved = ancestryResolvedArg
  disposition = dispositionArg~string~upper~strip
  reasonCode = reasonArg~string~upper~strip
  authenticationState = authStateArg~string~upper~strip
  compromised = compromisedArg
  authenticationEvidenceId = authEvidenceArg~string~upper~strip
  historyEvidenceId = historyEvidenceArg~string~upper~strip

::method eligible
  return self~disposition = "ELIGIBLE"

::method canonicalText
  return .ReputationFeedCanonical~field("CLAIM", self~claimId) || -
         .ReputationFeedCanonical~field("FAMILY", self~familyId) || -
         .ReputationFeedCanonical~field("PUBLICATION_FAMILY", self~publicationFamilyId) || -
         .ReputationFeedCanonical~field("ASSERTION_ORIGIN_FAMILY", self~assertionOriginFamilyId) || -
         .ReputationFeedCanonical~field("ASSERTION_ANCESTRY_RESOLVED", self~assertionAncestryResolved) || -
         .ReputationFeedCanonical~field("DISPOSITION", self~disposition) || -
         .ReputationFeedCanonical~field("REASON", self~reasonCode) || -
         .ReputationFeedCanonical~field("AUTH_STATE", self~authenticationState) || -
         .ReputationFeedCanonical~field("COMPROMISED", self~compromised) || -
         .ReputationFeedCanonical~field("AUTH_EVIDENCE", self~authenticationEvidenceId) || -
         .ReputationFeedCanonical~field("HISTORY_EVIDENCE", self~historyEvidenceId)


::class ReputationCorroborationEligibilityResolver subclass ReputationFeedAlchemyObject public

::method assess
  use arg claim, policy = .nil
  if policy == .nil then policy = .ReputationCorroborationEvidencePolicy~new
  if claim == .nil then return .ReputationCorroborationEvidenceStatus~new("", "", "DISCOVERY_ONLY", "CLAIM_MISSING", "UNASSESSED", .false)
  family = claim~corroborationFamilyId
  publicationFamily = claim~familyId
  assertionOriginFamily = claim~assertionOriginFamilyId
  ancestryResolved = claim~assertionAncestryResolved
  authState = claim~sourceAuthenticationState
  compromised = claim~sourceCompromised
  if compromised & \policy~allowCompromisedSource then
    return .ReputationCorroborationEvidenceStatus~new(claim~claimId, family, "DISCOVERY_ONLY", "SOURCE_COMPROMISED", authState, compromised, claim~sourceAuthenticationEvidenceId, claim~sourceHistoryEvidenceId, publicationFamily, assertionOriginFamily, ancestryResolved, self~domainAlchemyContext)
  if authState = "FAILED" & \policy~allowFailedAuthentication then
    return .ReputationCorroborationEvidenceStatus~new(claim~claimId, family, "DISCOVERY_ONLY", "AUTHENTICATION_FAILED", authState, compromised, claim~sourceAuthenticationEvidenceId, claim~sourceHistoryEvidenceId, publicationFamily, assertionOriginFamily, ancestryResolved, self~domainAlchemyContext)
  if authState = "UNVERIFIED" & \policy~allowUnverifiedOrigin then
    return .ReputationCorroborationEvidenceStatus~new(claim~claimId, family, "DISCOVERY_ONLY", "ORIGIN_UNVERIFIED", authState, compromised, claim~sourceAuthenticationEvidenceId, claim~sourceHistoryEvidenceId, publicationFamily, assertionOriginFamily, ancestryResolved, self~domainAlchemyContext)
  if authState = "UNASSESSED" & \policy~allowUnassessedOrigin then
    return .ReputationCorroborationEvidenceStatus~new(claim~claimId, family, "DISCOVERY_ONLY", "ORIGIN_UNASSESSED", authState, compromised, claim~sourceAuthenticationEvidenceId, claim~sourceHistoryEvidenceId, publicationFamily, assertionOriginFamily, ancestryResolved, self~domainAlchemyContext)
  reason = "PROVENANCE_ELIGIBLE"
  if compromised then reason = "COMPROMISED_ALLOWED_BY_POLICY"
  else if authState = "FAILED" then reason = "FAILED_AUTH_ALLOWED_BY_POLICY"
  else if authState = "UNVERIFIED" then reason = "UNVERIFIED_ALLOWED_BY_POLICY"
  else if authState = "UNASSESSED" then reason = "UNASSESSED_ALLOWED_BY_POLICY"
  else if authState = "VERIFIED" then reason = "ORIGIN_VERIFIED"
  return .ReputationCorroborationEvidenceStatus~new(claim~claimId, family, "ELIGIBLE", reason, authState, compromised, claim~sourceAuthenticationEvidenceId, claim~sourceHistoryEvidenceId, publicationFamily, assertionOriginFamily, ancestryResolved, self~domainAlchemyContext)


::class ReputationCorroborationAssessment subclass ReputationFeedAlchemyObject public
::attribute claimCount get
::attribute assertionClaimCount get
::attribute denialClaimCount get
::attribute independentFamilyCount get
::attribute assertionFamilyCount get
::attribute denialFamilyCount get
::attribute requiredIndependentFamilies get
::attribute weightedConfidence get
::attribute requiredWeightedConfidence get
::attribute status get
::attribute thresholdSatisfied get
::attribute contested get
::attribute eligibleClaimCount get
::attribute eligibleAssertionClaimCount get
::attribute eligibleDenialClaimCount get
::attribute discoveryOnlyClaimCount get
::attribute eligibleIndependentFamilyCount get
::attribute discoveryOnlyFamilyCount get
::attribute publicationFamilyCount get
::attribute explicitAssertionOriginFamilyCount get
::attribute ancestryResolvedClaimCount get
::attribute ancestryFallbackClaimCount get

::method init
  expose claimCount assertionClaimCount denialClaimCount independentFamilyCount assertionFamilyCount denialFamilyCount requiredIndependentFamilies weightedConfidence requiredWeightedConfidence status thresholdSatisfied contested eligibleClaimCount eligibleAssertionClaimCount eligibleDenialClaimCount discoveryOnlyClaimCount eligibleIndependentFamilyCount discoveryOnlyFamilyCount publicationFamilyCount explicitAssertionOriginFamilyCount ancestryResolvedClaimCount ancestryFallbackClaimCount evidenceStatuses
  use arg claimCountArg, assertionClaimArg, denialClaimArg, familyCountArg, assertionFamilyArg, denialFamilyArg, requiredFamiliesArg, weightedConfidenceArg, requiredConfidenceArg, statusArg, thresholdArg, contestedArg, eligibleClaimArg = .nil, eligibleAssertionArg = .nil, eligibleDenialArg = .nil, discoveryOnlyArg = 0, eligibleFamilyArg = .nil, discoveryFamilyArg = 0, evidenceStatusesArg = .nil, publicationFamilyCountArg = 0, explicitAssertionOriginFamilyCountArg = 0, ancestryResolvedClaimCountArg = 0, ancestryFallbackClaimCountArg = 0, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationCorroborationAssessment", alchemyContextArg)
  claimCount = claimCountArg + 0
  assertionClaimCount = assertionClaimArg + 0
  denialClaimCount = denialClaimArg + 0
  independentFamilyCount = familyCountArg + 0
  assertionFamilyCount = assertionFamilyArg + 0
  denialFamilyCount = denialFamilyArg + 0
  requiredIndependentFamilies = requiredFamiliesArg + 0
  weightedConfidence = .ReputationFeedCanonical~clamp(weightedConfidenceArg)
  requiredWeightedConfidence = .ReputationFeedCanonical~clamp(requiredConfidenceArg)
  status = statusArg~string~upper
  thresholdSatisfied = thresholdArg
  contested = contestedArg
  if eligibleClaimArg == .nil then eligibleClaimCount = claimCount; else eligibleClaimCount = eligibleClaimArg + 0
  if eligibleAssertionArg == .nil then eligibleAssertionClaimCount = assertionClaimCount; else eligibleAssertionClaimCount = eligibleAssertionArg + 0
  if eligibleDenialArg == .nil then eligibleDenialClaimCount = denialClaimCount; else eligibleDenialClaimCount = eligibleDenialArg + 0
  discoveryOnlyClaimCount = discoveryOnlyArg + 0
  if eligibleFamilyArg == .nil then eligibleIndependentFamilyCount = independentFamilyCount; else eligibleIndependentFamilyCount = eligibleFamilyArg + 0
  discoveryOnlyFamilyCount = discoveryFamilyArg + 0
  publicationFamilyCount = publicationFamilyCountArg + 0
  explicitAssertionOriginFamilyCount = explicitAssertionOriginFamilyCountArg + 0
  ancestryResolvedClaimCount = ancestryResolvedClaimCountArg + 0
  ancestryFallbackClaimCount = ancestryFallbackClaimCountArg + 0
  if evidenceStatusesArg == .nil then evidenceStatuses = .array~new; else evidenceStatuses = .ReputationFeedCanonical~copyArray(evidenceStatusesArg)

::method evidenceStatuses
  expose evidenceStatuses
  return .ReputationFeedCanonical~copyArray(evidenceStatuses)

::method evidenceStatusForClaim
  expose evidenceStatuses
  use arg claimIdArg
  wanted = claimIdArg~string~upper~strip
  do item over evidenceStatuses
    if item~claimId = wanted then return item
  end
  return .nil

::method canonicalText
  expose evidenceStatuses
  provenanceTexts = .array~new
  do item over evidenceStatuses; provenanceTexts~append(item~canonicalText); end
  return .ReputationFeedCanonical~field("STATUS", self~status) || -
         .ReputationFeedCanonical~field("CLAIMS", self~claimCount) || -
         .ReputationFeedCanonical~field("ASSERT_CLAIMS", self~assertionClaimCount) || -
         .ReputationFeedCanonical~field("DENY_CLAIMS", self~denialClaimCount) || -
         .ReputationFeedCanonical~field("FAMILIES", self~independentFamilyCount) || -
         .ReputationFeedCanonical~field("ASSERT_FAMILIES", self~assertionFamilyCount) || -
         .ReputationFeedCanonical~field("DENY_FAMILIES", self~denialFamilyCount) || -
         .ReputationFeedCanonical~field("ELIGIBLE_CLAIMS", self~eligibleClaimCount) || -
         .ReputationFeedCanonical~field("DISCOVERY_ONLY_CLAIMS", self~discoveryOnlyClaimCount) || -
         .ReputationFeedCanonical~field("ELIGIBLE_FAMILIES", self~eligibleIndependentFamilyCount) || -
         .ReputationFeedCanonical~field("DISCOVERY_ONLY_FAMILIES", self~discoveryOnlyFamilyCount) || -
         .ReputationFeedCanonical~field("PUBLICATION_FAMILIES", self~publicationFamilyCount) || -
         .ReputationFeedCanonical~field("EXPLICIT_ASSERTION_ORIGIN_FAMILIES", self~explicitAssertionOriginFamilyCount) || -
         .ReputationFeedCanonical~field("ANCESTRY_RESOLVED_CLAIMS", self~ancestryResolvedClaimCount) || -
         .ReputationFeedCanonical~field("ANCESTRY_FALLBACK_CLAIMS", self~ancestryFallbackClaimCount) || -
         .ReputationFeedCanonical~field("REQUIRED_FAMILIES", self~requiredIndependentFamilies) || -
         .ReputationFeedCanonical~field("CONFIDENCE", self~weightedConfidence) || -
         .ReputationFeedCanonical~field("REQUIRED_CONFIDENCE", self~requiredWeightedConfidence) || -
         .ReputationFeedCanonical~join("PROVENANCE", provenanceTexts)


::class ReputationEventHypothesis subclass ReputationFeedAlchemyObject public
::attribute hypothesisId get
::attribute eventType get
::attribute sealed get

::method init
  expose hypothesisId eventType claims sealed
  use arg hypothesisIdArg, eventTypeArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationEventHypothesis", alchemyContextArg)
  hypothesisId = hypothesisIdArg~string~upper
  eventType = eventTypeArg~string~upper
  claims = .array~new
  sealed = .false

::method addClaim
  expose claims sealed eventType
  use arg claim
  if sealed then return .false
  if claim == .nil then return .false
  if \claim~sealed then return .false
  if eventType <> "" & claim~eventType <> eventType then return .false
  do existing over claims
    if existing~claimId == claim~claimId then return .false
  end
  claims~append(claim)
  return .true

::method claims
  expose claims
  return .ReputationFeedCanonical~copyArray(claims)

::method claimCount
  expose claims
  return claims~items

::method firstObservedAt
  expose claims
  first = .nil
  do claim over claims
    if first == .nil then first = claim~observedAt
    else if claim~observedAt < first then first = claim~observedAt
  end
  return first

::method lastObservedAt
  expose claims
  last = .nil
  do claim over claims
    if last == .nil then last = claim~observedAt
    else if claim~observedAt > last then last = claim~observedAt
  end
  return last

::method subjectKeys
  expose claims
  keys = .array~new
  do claim over claims
    do key over claim~subjectKeys
      if \.ReputationFeedCanonical~containsString(keys, key) then keys~append(key)
    end
  end
  keys~sort
  return keys

::method concepts
  expose claims
  values = .array~new
  do claim over claims
    do concept over claim~concepts
      if \.ReputationFeedCanonical~containsString(values, concept) then values~append(concept)
    end
  end
  values~sort
  return values

::method affectedGeographies
  expose claims
  values = .array~new
  do claim over claims
    do geography over claim~affectedGeographies
      if \.ReputationFeedCanonical~containsString(values, geography) then values~append(geography)
    end
  end
  values~sort
  return values

::method corroboration
  expose claims
  use arg policy = .nil, evidencePolicy = .nil
  context = self~domainAlchemyContext
  if policy == .nil then policy = .ReputationCorroborationPolicy~new(2, 70, 1, 180, .true, context)
  if evidencePolicy == .nil then evidencePolicy = .ReputationCorroborationEvidencePolicy~new(.true, .true, .false, .false, context)
  resolver = .ReputationCorroborationEligibilityResolver~new(context)
  assertionFamilies = .directory~new
  denialFamilies = .directory~new
  allFamilies = .directory~new
  publicationFamilies = .directory~new
  explicitAssertionOriginFamilies = .directory~new
  eligibleFamilies = .directory~new
  discoveryFamilies = .directory~new
  evidenceStatuses = .array~new
  assertionClaims = 0
  denialClaims = 0
  activeClaims = 0
  eligibleClaims = 0
  eligibleAssertionClaims = 0
  eligibleDenialClaims = 0
  discoveryOnlyClaims = 0
  ancestryResolvedClaims = 0
  ancestryFallbackClaims = 0
  do claim over claims
    if \claim~isActive then iterate
    activeClaims += 1
    publicationFamily = claim~familyId
    if publicationFamily = "" then publicationFamily = "CLAIM:" || claim~claimId
    publicationFamilies[publicationFamily] = .true
    if claim~assertionAncestryResolved then do
      ancestryResolvedClaims += 1
      explicitAssertionOriginFamilies[claim~assertionOriginFamilyId] = .true
    end
    else ancestryFallbackClaims += 1
    family = claim~corroborationFamilyId
    allFamilies[family] = .true
    if claim~stance = "DENIES" | claim~stance = "DISPUTES" then denialClaims += 1
    else assertionClaims += 1
    provenance = resolver~assess(claim, evidencePolicy)
    evidenceStatuses~append(provenance)
    if \provenance~eligible then do
      discoveryOnlyClaims += 1
      if \eligibleFamilies~hasIndex(family) then discoveryFamilies[family] = .true
      iterate
    end
    eligibleClaims += 1
    eligibleFamilies[family] = .true
    if discoveryFamilies~hasIndex(family) then ignored = discoveryFamilies~remove(family)
    if claim~stance = "DENIES" | claim~stance = "DISPUTES" then do
      eligibleDenialClaims += 1
      if \denialFamilies~hasIndex(family) then denialFamilies[family] = claim~confidence
      else if claim~confidence > denialFamilies[family] then denialFamilies[family] = claim~confidence
    end
    else do
      eligibleAssertionClaims += 1
      if \assertionFamilies~hasIndex(family) then assertionFamilies[family] = claim~confidence
      else if claim~confidence > assertionFamilies[family] then assertionFamilies[family] = claim~confidence
    end
  end
  weighted = 0
  if assertionFamilies~items > 0 then do
    total = 0
    do family over assertionFamilies; total += assertionFamilies[family]; end
    weighted = trunc(total / assertionFamilies~items)
  end
  isContested = assertionFamilies~items > 0 & denialFamilies~items >= policy~minimumContestFamilies
  threshold = assertionFamilies~items >= policy~minimumIndependentFamilies & weighted >= policy~minimumWeightedConfidence
  if isContested then status = "CONTESTED"
  else if threshold then status = "CORROBORATED"
  else if eligibleAssertionClaims > 0 then status = "CORROBORATING"
  else if assertionClaims > 0 then status = "DISCOVERY_ONLY"
  else status = "UNSUPPORTED"
  return .ReputationCorroborationAssessment~new(activeClaims, assertionClaims, denialClaims, allFamilies~items, assertionFamilies~items, denialFamilies~items, policy~minimumIndependentFamilies, weighted, policy~minimumWeightedConfidence, status, threshold, isContested, eligibleClaims, eligibleAssertionClaims, eligibleDenialClaims, discoveryOnlyClaims, eligibleFamilies~items, discoveryFamilies~items, evidenceStatuses, publicationFamilies~items, explicitAssertionOriginFamilies~items, ancestryResolvedClaims, ancestryFallbackClaims, self~domainAlchemyContext)

::method seal
  expose sealed claims
  if claims~items = 0 then raise syntax 88.900 array("ReputationEventHypothesis requires at least one claim")
  sealed = .true
  return self

::method canonicalText
  expose hypothesisId eventType claims sealed
  if \sealed then raise syntax 93.900 additional("ReputationEventHypothesis must be sealed before canonicalisation")
  texts = .array~new
  do claim over claims; texts~append(claim~canonicalText); end
  return .ReputationFeedCanonical~field("HYPOTHESIS", hypothesisId) || -
         .ReputationFeedCanonical~field("EVENT_TYPE", eventType) || -
         .ReputationFeedCanonical~join("CLAIM", texts)


::method queuePersistentType
  return "reputation.feed.event-hypothesis/1"

::method queuePersistentState
  expose hypothesisId eventType claims sealed
  if \sealed then raise syntax 88.900 array("Unsealed ReputationEventHypothesis cannot cross the durable Queue Fabric boundary")
  state = .table~new
  state["hypothesisId"] = hypothesisId
  state["eventType"] = eventType
  state["claims"] = .ReputationFeedCanonical~copyArray(claims)
  return state

::method queueRestoreState
  expose hypothesisId eventType claims sealed
  use arg state
  hypothesisId = state["hypothesisId"]~string
  eventType = state["eventType"]~string
  claims = .ReputationFeedCanonical~copyArray(state["claims"])
  sealed = .true
  return self


::class ReputationEventClusterResult subclass ReputationFeedAlchemyObject public
::method init
  expose hypotheses claimHypothesis
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationEventClusterResult", alchemyContextArg)
  hypotheses = .array~new
  claimHypothesis = .directory~new

::method addHypothesis
  expose hypotheses claimHypothesis
  use arg hypothesis
  hypotheses~append(hypothesis)
  do claim over hypothesis~claims; claimHypothesis[claim~claimId] = hypothesis; end
  return self

::method hypotheses
  expose hypotheses
  return .ReputationFeedCanonical~copyArray(hypotheses)

::method hypothesisForClaim
  expose claimHypothesis
  use arg claimId
  id = claimId~string~upper
  if claimHypothesis~hasIndex(id) then return claimHypothesis[id]
  return .nil

::method hypothesisCount
  expose hypotheses
  return hypotheses~items

::method canonicalText
  expose hypotheses
  texts = .array~new
  do hypothesis over hypotheses; texts~append(hypothesis~canonicalText); end
  return .ReputationFeedCanonical~join("HYPOTHESIS", texts)


::class ReputationEventClusterEngine subclass ReputationFeedAlchemyObject public
::method cluster
  use arg claims, policy = .nil
  self~alchemyTouch("CLUSTER")
  if policy == .nil then policy = .ReputationCorroborationPolicy~new
  byId = .directory~new
  adjacency = .directory~new
  ids = .array~new
  do claim over claims
    if \claim~sealed then raise syntax 88.900 array("Event cluster input claim must be sealed")
    id = claim~claimId
    byId[id] = claim
    adjacency[id] = .array~new
    ids~append(id)
  end
  do i = 1 to ids~items
    do j = i + 1 to ids~items
      leftId = ids[i]; rightId = ids[j]
      if self~compatible(byId[leftId], byId[rightId], policy) then do
        adjacency[leftId]~append(rightId)
        adjacency[rightId]~append(leftId)
      end
    end
  end
  ids~sort
  seen = .directory~new
  clusterResult = .ReputationEventClusterResult~new
  number = 0
  do start over ids
    if seen~hasIndex(start) then iterate
    number += 1
    hypothesis = .ReputationEventHypothesis~new("HYPOTHESIS-" || number, byId[start]~eventType)
    queue = .array~of(start)
    seen[start] = .true
    do while queue~items > 0
      queueIndex = queue~first
      currentId = queue[queueIndex]
      queue~remove(queueIndex)
      hypothesis~addClaim(byId[currentId])
      do neighbour over adjacency[currentId]
        if seen~hasIndex(neighbour) then iterate
        seen[neighbour] = .true
        queue~append(neighbour)
      end
    end
    hypothesis~seal
    clusterResult~addHypothesis(hypothesis)
  end
  return clusterResult

::method compatible private
  use arg left, right, policy
  if left~eventType <> right~eventType then return .false
  if left~eventKey <> "" & right~eventKey <> "" then if left~eventKey <> right~eventKey then return .false
  span = left~occurredAt - right~occurredAt
  minutes = abs(span~totalSeconds) / 60
  if minutes > policy~maximumTimeGapMinutes then return .false
  if \policy~requireSubjectOrConceptOverlap then return .true
  subjectOverlap = self~stringOverlap(left~subjectKeys, right~subjectKeys)
  conceptOverlap = self~stringOverlap(left~concepts, right~concepts)
  return subjectOverlap > 0 | conceptOverlap > 0

::method stringOverlap private
  use arg left, right
  count = 0
  do item over left
    if .ReputationFeedCanonical~containsString(right, item) then count += 1
  end
  return count


::class ReputationFeedCorrection subclass ReputationFeedAlchemyObject public
::attribute correctionId get
::attribute targetClaimId get
::attribute correctionType get
::attribute replacementClaimId get
::attribute recordedAt get
::attribute sourceId get
::attribute confidence get
::attribute detail get
::attribute sealed get

::method init
  expose correctionId targetClaimId correctionType replacementClaimId recordedAt sourceId confidence detail sealed
  use arg correctionIdArg, targetClaimArg, correctionTypeArg = "RETRACTION", replacementClaimArg = "", recordedAtArg = .nil, sourceIdArg = "", confidenceArg = 100, detailArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedCorrection", alchemyContextArg)
  correctionId = correctionIdArg~string~upper
  targetClaimId = targetClaimArg~string~upper
  correctionType = correctionTypeArg~string~upper
  replacementClaimId = replacementClaimArg~string~upper
  if recordedAtArg == .nil then recordedAt = .DateTime~new; else recordedAt = recordedAtArg
  sourceId = sourceIdArg~string
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  detail = detailArg~string
  sealed = .false

::method seal
  expose sealed targetClaimId correctionType
  if targetClaimId = "" then raise syntax 88.900 array("ReputationFeedCorrection requires target claim")
  if correctionType <> "RETRACTION" & correctionType <> "SUPERSESSION" & correctionType <> "CORRECTION" then raise syntax 88.900 array("Unsupported correction type")
  sealed = .true
  return self

::method canonicalText
  expose correctionId targetClaimId correctionType replacementClaimId recordedAt sourceId confidence detail sealed
  if \sealed then raise syntax 93.900 additional("ReputationFeedCorrection must be sealed before canonicalisation")
  return .ReputationFeedCanonical~field("CORRECTION", correctionId) || -
         .ReputationFeedCanonical~field("TARGET", targetClaimId) || -
         .ReputationFeedCanonical~field("TYPE", correctionType) || -
         .ReputationFeedCanonical~field("REPLACEMENT", replacementClaimId) || -
         .ReputationFeedCanonical~field("RECORDED", recordedAt) || -
         .ReputationFeedCanonical~field("SOURCE", sourceId) || -
         .ReputationFeedCanonical~field("CONFIDENCE", confidence) || -
         .ReputationFeedCanonical~field("DETAIL", detail)


::method queuePersistentType
  return "reputation.feed.correction/1"

::method queuePersistentState
  expose correctionId targetClaimId correctionType replacementClaimId recordedAt sourceId confidence detail sealed
  if \sealed then raise syntax 88.900 array("Unsealed ReputationFeedCorrection cannot cross the durable Queue Fabric boundary")
  state = .table~new
  state["correctionId"] = correctionId
  state["targetClaimId"] = targetClaimId
  state["correctionType"] = correctionType
  state["replacementClaimId"] = replacementClaimId
  state["recordedAt"] = .ReputationFeedQueuePersistenceValue~dateText(recordedAt)
  state["sourceId"] = sourceId
  state["confidence"] = confidence~string
  state["detail"] = detail
  return state

::method queueRestoreState
  expose correctionId targetClaimId correctionType replacementClaimId recordedAt sourceId confidence detail sealed
  use arg state
  correctionId = state["correctionId"]~string
  targetClaimId = state["targetClaimId"]~string
  correctionType = state["correctionType"]~string
  replacementClaimId = state["replacementClaimId"]~string
  recordedAt = .ReputationFeedQueuePersistenceValue~dateValue(state["recordedAt"])
  sourceId = state["sourceId"]~string
  confidence = state["confidence"] + 0
  detail = state["detail"]~string
  sealed = .true
  return self


::class ReputationHypothesisLedger subclass ReputationFeedAlchemyObject public
::method init
  expose claims corrections
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationHypothesisLedger", alchemyContextArg)
  claims = .directory~new
  corrections = .array~new

::method addClaim
  expose claims
  use arg claim
  if claim == .nil then return .false
  if \claim~sealed then return .false
  claims[claim~claimId] = claim
  return .true

::method addCorrection
  expose corrections
  use arg correction
  if correction == .nil then return .false
  if \correction~sealed then return .false
  corrections~append(correction)
  return .true

::method activeClaimsAt
  expose claims corrections
  use arg moment = .nil
  if moment == .nil then moment = .DateTime~new
  inactive = .directory~new
  do correction over corrections
    if correction~recordedAt > moment then iterate
    inactive[correction~targetClaimId] = .true
  end
  ids = .array~new
  do id over claims
    claim = claims[id]
    if claim~observedAt <= moment & \inactive~hasIndex(id) & claim~isActive then ids~append(id)
  end
  ids~sort
  active = .array~new
  do id over ids; active~append(claims[id]); end
  return active

::method clusterAt
  use arg moment = .nil, policy = .nil
  self~alchemyTouch("CLUSTER_AT")
  return .ReputationEventClusterEngine~new~cluster(self~activeClaimsAt(moment), policy)


::class ReputationGeographicSalienceEvidence subclass ReputationFeedAlchemyObject public
::attribute hypothesisId get
::attribute geographyId get
::attribute measuredAt get
::attribute independentFamilyCount get
::attribute publicationSurfaceCount get
::attribute localFamilyCount get
::attribute publicationVelocityPerHour get
::attribute officialAttention get
::attribute confidence get

::method init
  expose hypothesisId geographyId measuredAt independentFamilyCount publicationSurfaceCount localFamilyCount publicationVelocityPerHour officialAttention confidence
  use arg hypothesisArg, geographyArg, measuredAtArg = .nil, familyCountArg = 0, surfaceCountArg = 0, localFamilyCountArg = 0, velocityArg = 0, officialAttentionArg = .false, confidenceArg = 50, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationGeographicSalienceEvidence", alchemyContextArg)
  hypothesisId = hypothesisArg~string~upper
  geographyId = geographyArg~string~upper
  if measuredAtArg == .nil then measuredAt = .DateTime~new; else measuredAt = measuredAtArg
  independentFamilyCount = familyCountArg + 0
  publicationSurfaceCount = surfaceCountArg + 0
  localFamilyCount = localFamilyCountArg + 0
  publicationVelocityPerHour = velocityArg + 0
  officialAttention = officialAttentionArg
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)


::class ReputationGeographicSaliencePolicy subclass ReputationFeedAlchemyObject public
::attribute mediumFamilyThreshold get
::attribute highFamilyThreshold get
::attribute mediumVelocityThreshold get
::attribute highVelocityThreshold get

::method init
  expose mediumFamilyThreshold highFamilyThreshold mediumVelocityThreshold highVelocityThreshold
  use arg mediumFamiliesArg = 2, highFamiliesArg = 5, mediumVelocityArg = 3, highVelocityArg = 10, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationGeographicSaliencePolicy", alchemyContextArg)
  mediumFamilyThreshold = mediumFamiliesArg + 0
  highFamilyThreshold = highFamiliesArg + 0
  mediumVelocityThreshold = mediumVelocityArg + 0
  highVelocityThreshold = highVelocityArg + 0

::method assess
  use arg evidence
  families = evidence~independentFamilyCount
  velocity = evidence~publicationVelocityPerHour
  if families >= self~highFamilyThreshold | velocity >= self~highVelocityThreshold | (evidence~officialAttention & families >= self~mediumFamilyThreshold) then band = "HIGH"
  else if families >= self~mediumFamilyThreshold | velocity >= self~mediumVelocityThreshold | evidence~officialAttention then band = "MEDIUM"
  else band = "LOW"
  return .ReputationGeographicSalienceAssessment~new(evidence, band, self)


::class ReputationGeographicSalienceAssessment subclass ReputationFeedAlchemyObject public
::attribute evidence get
::attribute band get
::attribute familyThreshold get
::attribute velocityThreshold get

::method init
  expose evidence band familyThreshold velocityThreshold
  use arg evidenceArg, bandArg, policyArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationGeographicSalienceAssessment", alchemyContextArg)
  evidence = evidenceArg
  band = bandArg~string~upper
  if band = "HIGH" then do
    familyThreshold = policyArg~highFamilyThreshold
    velocityThreshold = policyArg~highVelocityThreshold
  end
  else do
    familyThreshold = policyArg~mediumFamilyThreshold
    velocityThreshold = policyArg~mediumVelocityThreshold
  end

::method canonicalText
  return .ReputationFeedCanonical~field("GEO", self~evidence~geographyId) || -
         .ReputationFeedCanonical~field("BAND", self~band) || -
         .ReputationFeedCanonical~field("FAMILIES", self~evidence~independentFamilyCount) || -
         .ReputationFeedCanonical~field("FAMILY_THRESHOLD", self~familyThreshold) || -
         .ReputationFeedCanonical~field("VELOCITY", self~evidence~publicationVelocityPerHour) || -
         .ReputationFeedCanonical~field("VELOCITY_THRESHOLD", self~velocityThreshold)


::class ReputationWatchSet subclass ReputationFeedAlchemyObject public
::attribute watchSetId get
::attribute activeFrom get
::attribute activeUntil get
::attribute sealed get

::method init
  expose watchSetId activeFrom activeUntil eventTypes subjects concepts geographies sealed
  use arg watchSetIdArg, activeFromArg = .nil, activeUntilArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationWatchSet", alchemyContextArg)
  watchSetId = watchSetIdArg~string~upper
  activeFrom = activeFromArg
  activeUntil = activeUntilArg
  eventTypes = .array~new
  subjects = .array~new
  concepts = .array~new
  geographies = .array~new
  sealed = .false

::method addEventType
  expose eventTypes sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string~upper
  if value <> "" & \.ReputationFeedCanonical~containsString(eventTypes, value) then eventTypes~append(value)
  return .true

::method addSubject
  expose subjects sealed
  use arg kindArg, idArg
  if sealed then return .false
  key = kindArg~string~upper || "|" || idArg~string~upper
  if \.ReputationFeedCanonical~containsString(subjects, key) then subjects~append(key)
  return .true

::method addConcept
  expose concepts sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string~upper
  if value <> "" & \.ReputationFeedCanonical~containsString(concepts, value) then concepts~append(value)
  return .true

::method addGeography
  expose geographies sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string~upper
  if value <> "" & \.ReputationFeedCanonical~containsString(geographies, value) then geographies~append(value)
  return .true

::method eventTypes; expose eventTypes; return .ReputationFeedCanonical~copyArray(eventTypes)
::method subjectKeys; expose subjects; return .ReputationFeedCanonical~copyArray(subjects)
::method concepts; expose concepts; return .ReputationFeedCanonical~copyArray(concepts)
::method geographies; expose geographies; return .ReputationFeedCanonical~copyArray(geographies)

::method activeAt
  expose activeFrom activeUntil
  use arg moment
  if activeFrom \== .nil then if moment < activeFrom then return .false
  if activeUntil \== .nil then if moment > activeUntil then return .false
  return .true

::method seal
  expose sealed
  sealed = .true
  return self


::class ReputationWatchMatch subclass ReputationFeedAlchemyObject public
::attribute watchSetId get
::attribute hypothesisId get
::attribute matched get
::attribute score get
::attribute eventTypeMatch get
::attribute subjectMatchCount get
::attribute conceptMatchCount get
::attribute geographyMatchCount get

::method init
  expose watchSetId hypothesisId matched score eventTypeMatch subjectMatchCount conceptMatchCount geographyMatchCount
  use arg watchSetArg, hypothesisArg, matchedArg, scoreArg, eventTypeArg, subjectCountArg, conceptCountArg, geographyCountArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationWatchMatch", alchemyContextArg)
  watchSetId = watchSetArg~string~upper
  hypothesisId = hypothesisArg~string~upper
  matched = matchedArg
  score = .ReputationFeedCanonical~clamp(scoreArg)
  eventTypeMatch = eventTypeArg
  subjectMatchCount = subjectCountArg + 0
  conceptMatchCount = conceptCountArg + 0
  geographyMatchCount = geographyCountArg + 0


::method queuePersistentType
  return "reputation.feed.watch-match/1"

::method queuePersistentState
  expose watchSetId hypothesisId matched score eventTypeMatch subjectMatchCount conceptMatchCount geographyMatchCount
  state = .table~new
  state["watchSetId"] = watchSetId
  state["hypothesisId"] = hypothesisId
  state["matched"] = .ReputationFeedQueuePersistenceValue~boolText(matched)
  state["score"] = score~string
  state["eventTypeMatch"] = .ReputationFeedQueuePersistenceValue~boolText(eventTypeMatch)
  state["subjectMatchCount"] = subjectMatchCount~string
  state["conceptMatchCount"] = conceptMatchCount~string
  state["geographyMatchCount"] = geographyMatchCount~string
  return state

::method queueRestoreState
  expose watchSetId hypothesisId matched score eventTypeMatch subjectMatchCount conceptMatchCount geographyMatchCount
  use arg state
  watchSetId = state["watchSetId"]~string
  hypothesisId = state["hypothesisId"]~string
  matched = .ReputationFeedQueuePersistenceValue~truth(state["matched"])
  score = state["score"] + 0
  eventTypeMatch = .ReputationFeedQueuePersistenceValue~truth(state["eventTypeMatch"])
  subjectMatchCount = state["subjectMatchCount"] + 0
  conceptMatchCount = state["conceptMatchCount"] + 0
  geographyMatchCount = state["geographyMatchCount"] + 0
  return self


::class ReputationWatchEngine subclass ReputationFeedAlchemyObject public
::method match
  use arg watchSet, hypothesis, moment = .nil
  self~alchemyTouch("MATCH")
  if moment == .nil then moment = .DateTime~new
  if watchSet == .nil then return .ReputationWatchMatch~new("", "", .false, 0, .false, 0, 0, 0)
  if hypothesis == .nil then return .ReputationWatchMatch~new(watchSet~watchSetId, "", .false, 0, .false, 0, 0, 0)
  if \watchSet~sealed then return .ReputationWatchMatch~new(watchSet~watchSetId, hypothesis~hypothesisId, .false, 0, .false, 0, 0, 0)
  if \hypothesis~sealed then return .ReputationWatchMatch~new(watchSet~watchSetId, hypothesis~hypothesisId, .false, 0, .false, 0, 0, 0)
  if \watchSet~activeAt(moment) then return .ReputationWatchMatch~new(watchSet~watchSetId, hypothesis~hypothesisId, .false, 0, .false, 0, 0, 0)
  eventMatch = watchSet~eventTypes~items = 0 | .ReputationFeedCanonical~containsString(watchSet~eventTypes, hypothesis~eventType)
  subjectCount = self~overlap(watchSet~subjectKeys, hypothesis~subjectKeys)
  conceptCount = self~overlap(watchSet~concepts, hypothesis~concepts)
  geographyCount = self~overlap(watchSet~geographies, hypothesis~affectedGeographies)
  constrained = watchSet~subjectKeys~items + watchSet~concepts~items + watchSet~geographies~items + watchSet~eventTypes~items
  if constrained = 0 then return .ReputationWatchMatch~new(watchSet~watchSetId, hypothesis~hypothesisId, .false, 0, eventMatch, subjectCount, conceptCount, geographyCount)
  score = 0
  if eventMatch & watchSet~eventTypes~items > 0 then score += 40
  if subjectCount > 0 then score += 30
  if conceptCount > 0 then score += 20
  if geographyCount > 0 then score += 10
  matched = score > 0 & eventMatch
  return .ReputationWatchMatch~new(watchSet~watchSetId, hypothesis~hypothesisId, matched, score, eventMatch, subjectCount, conceptCount, geographyCount)

::method overlap private
  use arg left, right
  count = 0
  do item over left
    if .ReputationFeedCanonical~containsString(right, item) then count += 1
  end
  return count


/* A sealed, domain-owned bundle of deterministic Feed policies. Institutional
   Policy may govern which bundle is operative, but the meaning of each rule
   remains here in Reputation Feed. */
::class ReputationFeedPolicySet subclass ReputationFeedAlchemyObject public
::attribute policySetId get
::attribute lineagePolicy get
::attribute corroborationPolicy get
::attribute evidencePolicy get
::attribute geographicSaliencePolicy get
::attribute sealed get

::method init
  expose policySetId lineagePolicy corroborationPolicy evidencePolicy geographicSaliencePolicy sealed
  use arg policySetIdArg = "DEFAULT", lineagePolicyArg = .nil, corroborationPolicyArg = .nil, evidencePolicyArg = .nil, saliencePolicyArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedPolicySet", alchemyContextArg)
  policySetId = policySetIdArg~string~upper~strip
  if policySetId = "" then policySetId = "DEFAULT"
  if lineagePolicyArg == .nil then lineagePolicy = .ReputationLineagePolicy~new(78, 2, self~domainAlchemyContext)
  else lineagePolicy = lineagePolicyArg
  if corroborationPolicyArg == .nil then corroborationPolicy = .ReputationCorroborationPolicy~new(2, 70, 1, 180, .true, self~domainAlchemyContext)
  else corroborationPolicy = corroborationPolicyArg
  if evidencePolicyArg == .nil then evidencePolicy = .ReputationCorroborationEvidencePolicy~new(.true, .true, .false, .false, self~domainAlchemyContext)
  else evidencePolicy = evidencePolicyArg
  if saliencePolicyArg == .nil then geographicSaliencePolicy = .ReputationGeographicSaliencePolicy~new(2, 5, 3, 10, self~domainAlchemyContext)
  else geographicSaliencePolicy = saliencePolicyArg
  sealed = .false
  self~registerStateVariable("policySetId", "PUBLIC", "Reputation Feed policy-set identity")
  self~registerStateVariable("sealed", "PUBLIC", "Policy set immutable publication state")
  self~registerMethodContract("SEAL", "Seal deterministic Feed policy bundle", .array~new, "REPUTATIONFEEDPOLICYSET", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")

::method validatePolicy private
  use arg value, requiredMethods
  if value == .nil then return .false
  do methodName over requiredMethods
    if value~hasMethod(methodName) = .false then return .false
  end
  return .true

::method publicationEligible
  expose sealed
  return sealed

::method seal
  expose sealed lineagePolicy corroborationPolicy evidencePolicy geographicSaliencePolicy
  if sealed then return self
  if \self~validatePolicy(lineagePolicy, .array~of("ARTICLESIMILARITYTHRESHOLD", "MINIMUMALIGNEDPARAGRAPHS")) then raise syntax 88.900 array("Invalid ReputationLineagePolicy in policy set")
  if \self~validatePolicy(corroborationPolicy, .array~of("MINIMUMINDEPENDENTFAMILIES", "MINIMUMWEIGHTEDCONFIDENCE", "MINIMUMCONTESTFAMILIES", "MAXIMUMTIMEGAPMINUTES", "REQUIRESUBJECTORCONCEPTOVERLAP")) then raise syntax 88.900 array("Invalid ReputationCorroborationPolicy in policy set")
  if \self~validatePolicy(evidencePolicy, .array~of("ALLOWUNVERIFIEDORIGIN", "ALLOWUNASSESSEDORIGIN", "ALLOWFAILEDAUTHENTICATION", "ALLOWCOMPROMISEDSOURCE")) then raise syntax 88.900 array("Invalid ReputationCorroborationEvidencePolicy in policy set")
  if \self~validatePolicy(geographicSaliencePolicy, .array~of("MEDIUMFAMILYTHRESHOLD", "HIGHFAMILYTHRESHOLD", "MEDIUMVELOCITYTHRESHOLD", "HIGHVELOCITYTHRESHOLD")) then raise syntax 88.900 array("Invalid ReputationGeographicSaliencePolicy in policy set")
  sealed = .true
  return self

::method canonicalText
  expose policySetId lineagePolicy corroborationPolicy evidencePolicy geographicSaliencePolicy sealed
  if \sealed then raise syntax 93.900 additional("ReputationFeedPolicySet must be sealed before canonicalisation")
  text = "REPUTATION-FEED-POLICY-SET/1" || '0a'x
  text ||= .ReputationFeedCanonical~field("POLICY_SET", policySetId)
  text ||= .ReputationFeedCanonical~field("LINEAGE_SIMILARITY", lineagePolicy~articleSimilarityThreshold)
  text ||= .ReputationFeedCanonical~field("LINEAGE_MIN_ALIGNED", lineagePolicy~minimumAlignedParagraphs)
  text ||= .ReputationFeedCanonical~field("CORROBORATION_MIN_FAMILIES", corroborationPolicy~minimumIndependentFamilies)
  text ||= .ReputationFeedCanonical~field("CORROBORATION_MIN_CONFIDENCE", corroborationPolicy~minimumWeightedConfidence)
  text ||= .ReputationFeedCanonical~field("CONTEST_MIN_FAMILIES", corroborationPolicy~minimumContestFamilies)
  text ||= .ReputationFeedCanonical~field("CLUSTER_MAX_GAP_MINUTES", corroborationPolicy~maximumTimeGapMinutes)
  text ||= .ReputationFeedCanonical~field("CLUSTER_REQUIRE_OVERLAP", corroborationPolicy~requireSubjectOrConceptOverlap)
  text ||= .ReputationFeedCanonical~field("ALLOW_UNVERIFIED", evidencePolicy~allowUnverifiedOrigin)
  text ||= .ReputationFeedCanonical~field("ALLOW_UNASSESSED", evidencePolicy~allowUnassessedOrigin)
  text ||= .ReputationFeedCanonical~field("ALLOW_FAILED_AUTH", evidencePolicy~allowFailedAuthentication)
  text ||= .ReputationFeedCanonical~field("ALLOW_COMPROMISED", evidencePolicy~allowCompromisedSource)
  text ||= .ReputationFeedCanonical~field("SALIENCE_MEDIUM_FAMILIES", geographicSaliencePolicy~mediumFamilyThreshold)
  text ||= .ReputationFeedCanonical~field("SALIENCE_HIGH_FAMILIES", geographicSaliencePolicy~highFamilyThreshold)
  text ||= .ReputationFeedCanonical~field("SALIENCE_MEDIUM_VELOCITY", geographicSaliencePolicy~mediumVelocityThreshold)
  text ||= .ReputationFeedCanonical~field("SALIENCE_HIGH_VELOCITY", geographicSaliencePolicy~highVelocityThreshold)
  return text

::method semanticIdentity
  return self~canonicalText

::requires "AlchemyObject.cls"
