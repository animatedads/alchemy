/*
 * Reputation Feed v0.12 acquisition boundary.
 *
 * Source adapters normalise transport material only.  They do not assign
 * reputational direction, do not manufacture independent-source counts, and
 * do not promote material directly to ReputationEvent.  Librarian findings
 * are retained as explicit evidence before they can become Feed claims.
 */

::class ReputationSourceIdentity subclass ReputationFeedAlchemyObject public
::attribute sourceId get
::attribute sourceKind get
::attribute displayName get
::attribute publisherGroup get
::attribute ownershipGroup get
::attribute defaultGeographyId get
::attribute evidentialRole get
::attribute endpointId get
::attribute sealed get

::method init
  expose sourceId sourceKind displayName publisherGroup ownershipGroup defaultGeographyId evidentialRole endpointId sealed
  use arg sourceIdArg, sourceKindArg, displayNameArg = "", publisherGroupArg = "", ownershipGroupArg = "", defaultGeographyArg = "", evidentialRoleArg = "DISCOVERY", endpointIdArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceIdentity", alchemyContextArg)
  sourceId = sourceIdArg~string~upper~strip
  sourceKind = sourceKindArg~string~upper~strip
  displayName = displayNameArg~string
  publisherGroup = publisherGroupArg~string~upper~strip
  ownershipGroup = ownershipGroupArg~string~upper~strip
  defaultGeographyId = defaultGeographyArg~string~upper~strip
  evidentialRole = evidentialRoleArg~string~upper~strip
  endpointId = endpointIdArg~string
  sealed = .false

::method seal
  expose sourceId sourceKind sealed
  if sourceId = "" | sourceKind = "" then raise syntax 88.900 array("ReputationSourceIdentity requires sourceId and sourceKind")
  sealed = .true
  return self

::method canonicalText
  expose sourceId sourceKind displayName publisherGroup ownershipGroup defaultGeographyId evidentialRole endpointId sealed
  if \sealed then raise syntax 93.900 additional("ReputationSourceIdentity must be sealed before canonicalisation")
  return .ReputationFeedCanonical~field("SOURCE_ID", sourceId) || -
         .ReputationFeedCanonical~field("SOURCE_KIND", sourceKind) || -
         .ReputationFeedCanonical~field("DISPLAY_NAME", displayName) || -
         .ReputationFeedCanonical~field("PUBLISHER_GROUP", publisherGroup) || -
         .ReputationFeedCanonical~field("OWNERSHIP_GROUP", ownershipGroup) || -
         .ReputationFeedCanonical~field("DEFAULT_GEO", defaultGeographyId) || -
         .ReputationFeedCanonical~field("EVIDENTIAL_ROLE", evidentialRole) || -
         .ReputationFeedCanonical~field("ENDPOINT", endpointId)


::class ReputationAcquisitionField subclass ReputationFeedAlchemyObject public
::attribute fieldName get
::attribute fieldValue get

::method init
  expose fieldName fieldValue
  use arg nameArg, valueArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationAcquisitionField", alchemyContextArg)
  fieldName = nameArg~string~upper~strip
  fieldValue = valueArg~string

::method canonicalText
  expose fieldName fieldValue
  return .ReputationFeedCanonical~field("FIELD_NAME", fieldName) || -
         .ReputationFeedCanonical~field("FIELD_VALUE", fieldValue)


::class ReputationRawSegment subclass ReputationFeedAlchemyObject public
::attribute segmentIndex get
::attribute segmentRole get
::attribute text get

::method init
  expose segmentIndex segmentRole text
  use arg indexArg, roleArg, textArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationRawSegment", alchemyContextArg)
  segmentIndex = indexArg + 0
  segmentRole = roleArg~string~upper~strip
  text = textArg~string

::method canonicalText
  expose segmentIndex segmentRole text
  return .ReputationFeedCanonical~field("SEGMENT_INDEX", segmentIndex) || -
         .ReputationFeedCanonical~field("SEGMENT_ROLE", segmentRole) || -
         .ReputationFeedCanonical~field("TEXT", text)


::class ReputationRawEnvelope subclass ReputationFeedAlchemyObject public
::attribute envelopeId get
::attribute sourceIdentity get
::attribute receivedAt get
::attribute sourceObservedAt get
::attribute contentType get
::attribute locator get
::attribute language get
::attribute payloadDigest get
::attribute sealed get

::method init
  expose envelopeId sourceIdentity receivedAt sourceObservedAt contentType locator language payloadDigest segments fields sealed
  use arg envelopeIdArg, sourceIdentityArg, receivedAtArg = .nil, sourceObservedAtArg = .nil, contentTypeArg = "TEXT/PLAIN", locatorArg = "", languageArg = "", payloadDigestArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationRawEnvelope", alchemyContextArg)
  envelopeId = envelopeIdArg~string~upper~strip
  sourceIdentity = sourceIdentityArg
  if receivedAtArg == .nil then receivedAt = .DateTime~new; else receivedAt = receivedAtArg
  if sourceObservedAtArg == .nil then sourceObservedAt = receivedAt; else sourceObservedAt = sourceObservedAtArg
  contentType = contentTypeArg~string~upper~strip
  locator = locatorArg~string
  language = languageArg~string~upper~strip
  payloadDigest = payloadDigestArg~string~lower~strip
  segments = .array~new
  fields = .array~new
  sealed = .false

::method addSegment
  expose segments sealed
  use arg roleArg, textArg = ""
  if sealed then return .false
  segment = .ReputationRawSegment~new(segments~items + 1, roleArg, textArg, self~domainAlchemyContext)
  segments~append(segment)
  return .true

::method addField
  expose fields sealed
  use arg nameArg, valueArg = ""
  if sealed then return .false
  name = nameArg~string~upper~strip
  if name = "" then return .false
  do i = 1 to fields~items
    if fields[i]~fieldName == name then do
      fields~remove(i)
      leave
    end
  end
  fields~append(.ReputationAcquisitionField~new(name, valueArg, self~domainAlchemyContext))
  return .true

::method fieldValue
  expose fields
  use arg nameArg, defaultArg = ""
  wanted = nameArg~string~upper~strip
  do field over fields
    if field~fieldName == wanted then return field~fieldValue
  end
  return defaultArg

::method segments
  expose segments
  return .ReputationFeedCanonical~copyArray(segments)

::method fields
  expose fields
  return .ReputationFeedCanonical~copyArray(fields)

::method seal
  expose envelopeId sourceIdentity segments sealed
  if envelopeId = "" then raise syntax 88.900 array("ReputationRawEnvelope requires envelopeId")
  if sourceIdentity == .nil then raise syntax 88.900 array("ReputationRawEnvelope requires source identity")
  if \sourceIdentity~sealed then raise syntax 88.900 array("ReputationRawEnvelope source identity must be sealed")
  if segments~items = 0 then raise syntax 88.900 array("ReputationRawEnvelope requires at least one retained segment")
  sealed = .true
  return self

::method canonicalText
  expose envelopeId sourceIdentity receivedAt sourceObservedAt contentType locator language payloadDigest segments fields sealed
  if \sealed then raise syntax 93.900 additional("ReputationRawEnvelope must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("ENVELOPE", envelopeId)
  text ||= .ReputationFeedCanonical~field("SOURCE", sourceIdentity~canonicalText)
  text ||= .ReputationFeedCanonical~field("RECEIVED", receivedAt)
  text ||= .ReputationFeedCanonical~field("SOURCE_OBSERVED", sourceObservedAt)
  text ||= .ReputationFeedCanonical~field("CONTENT_TYPE", contentType)
  text ||= .ReputationFeedCanonical~field("LOCATOR", locator)
  text ||= .ReputationFeedCanonical~field("LANGUAGE", language)
  text ||= .ReputationFeedCanonical~field("PAYLOAD_DIGEST", payloadDigest)
  segmentTexts = .array~new
  do segment over segments; segmentTexts~append(segment~canonicalText); end
  fieldTexts = .array~new
  do field over fields; fieldTexts~append(field~canonicalText); end
  text ||= .ReputationFeedCanonical~join("RAW_SEGMENT", segmentTexts)
  text ||= .ReputationFeedCanonical~join("RAW_FIELD", fieldTexts)
  return text


::method queuePersistentType
  return "reputation.feed.raw-envelope/1"

::method queuePersistentState
  expose envelopeId sourceIdentity receivedAt sourceObservedAt contentType locator language payloadDigest segments fields sealed
  if \sealed then raise syntax 88.900 array("Unsealed ReputationRawEnvelope cannot cross the durable Queue Fabric boundary")
  state = .table~new
  state["envelopeId"] = envelopeId
  source = .table~new
  source["sourceId"] = sourceIdentity~sourceId
  source["sourceKind"] = sourceIdentity~sourceKind
  source["displayName"] = sourceIdentity~displayName
  source["publisherGroup"] = sourceIdentity~publisherGroup
  source["ownershipGroup"] = sourceIdentity~ownershipGroup
  source["defaultGeographyId"] = sourceIdentity~defaultGeographyId
  source["evidentialRole"] = sourceIdentity~evidentialRole
  source["endpointId"] = sourceIdentity~endpointId
  state["sourceIdentity"] = source
  state["receivedAt"] = .ReputationFeedQueuePersistenceValue~dateText(receivedAt)
  state["sourceObservedAt"] = .ReputationFeedQueuePersistenceValue~dateText(sourceObservedAt)
  state["contentType"] = contentType
  state["locator"] = locator
  state["language"] = language
  state["payloadDigest"] = payloadDigest
  segmentRows = .array~new
  do segment over segments
    row = .table~new
    row["segmentIndex"] = segment~segmentIndex~string
    row["segmentRole"] = segment~segmentRole
    row["text"] = segment~text
    segmentRows~append(row)
  end
  state["segments"] = segmentRows
  fieldRows = .array~new
  do field over fields
    row = .table~new
    row["fieldName"] = field~fieldName
    row["fieldValue"] = field~fieldValue
    fieldRows~append(row)
  end
  state["fields"] = fieldRows
  return state

::method queueRestoreState
  expose envelopeId sourceIdentity receivedAt sourceObservedAt contentType locator language payloadDigest segments fields sealed
  use arg state
  envelopeId = state["envelopeId"]~string
  source = state["sourceIdentity"]
  sourceIdentity = .ReputationSourceIdentity~new(source["sourceId"], source["sourceKind"], source["displayName"], source["publisherGroup"], source["ownershipGroup"], source["defaultGeographyId"], source["evidentialRole"], source["endpointId"], self~domainAlchemyContext)
  sourceIdentity~seal
  receivedAt = .ReputationFeedQueuePersistenceValue~dateValue(state["receivedAt"])
  sourceObservedAt = .ReputationFeedQueuePersistenceValue~dateValue(state["sourceObservedAt"])
  contentType = state["contentType"]~string
  locator = state["locator"]~string
  language = state["language"]~string
  payloadDigest = state["payloadDigest"]~string
  segments = .array~new
  do row over state["segments"]
    segments~append(.ReputationRawSegment~new(row["segmentIndex"], row["segmentRole"], row["text"], self~domainAlchemyContext))
  end
  fields = .array~new
  do row over state["fields"]
    fields~append(.ReputationAcquisitionField~new(row["fieldName"], row["fieldValue"], self~domainAlchemyContext))
  end
  sealed = .true
  return self


::class ReputationLibrarianParagraph subclass ReputationFeedAlchemyObject public
::attribute paragraphIndex get
::attribute paragraphRole get
::attribute text get
::attribute sourceEnvelopeId get
::attribute sourceLocator get

::method init
  expose paragraphIndex paragraphRole text sourceEnvelopeId sourceLocator
  use arg indexArg, roleArg, textArg, envelopeIdArg = "", locatorArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationLibrarianParagraph", alchemyContextArg)
  paragraphIndex = indexArg + 0
  paragraphRole = roleArg~string~upper~strip
  text = textArg~string
  sourceEnvelopeId = envelopeIdArg~string~upper~strip
  sourceLocator = locatorArg~string

::method canonicalText
  expose paragraphIndex paragraphRole text sourceEnvelopeId sourceLocator
  return .ReputationFeedCanonical~field("PARAGRAPH", paragraphIndex) || -
         .ReputationFeedCanonical~field("ROLE", paragraphRole) || -
         .ReputationFeedCanonical~field("TEXT", text) || -
         .ReputationFeedCanonical~field("SOURCE_ENVELOPE", sourceEnvelopeId) || -
         .ReputationFeedCanonical~field("SOURCE_LOCATOR", sourceLocator)


::class ReputationAcquiredDocument subclass ReputationFeedAlchemyObject public
::attribute documentId get
::attribute documentKind get
::attribute sourceIdentity get
::attribute sourceEnvelopeId get
::attribute title get
::attribute publishedAt get
::attribute observedGeographyId get
::attribute locator get
::attribute sealed get

::method init
  expose documentId documentKind sourceIdentity sourceEnvelopeId title publishedAt observedGeographyId locator paragraphs sealed
  use arg documentIdArg, documentKindArg, sourceIdentityArg, sourceEnvelopeIdArg, titleArg = "", publishedAtArg = .nil, observedGeographyArg = "", locatorArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationAcquiredDocument", alchemyContextArg)
  documentId = documentIdArg~string~upper~strip
  documentKind = documentKindArg~string~upper~strip
  sourceIdentity = sourceIdentityArg
  sourceEnvelopeId = sourceEnvelopeIdArg~string~upper~strip
  title = titleArg~string
  if publishedAtArg == .nil then publishedAt = .DateTime~new; else publishedAt = publishedAtArg
  observedGeographyId = observedGeographyArg~string~upper~strip
  locator = locatorArg~string
  paragraphs = .array~new
  sealed = .false

::method sourceId
  expose sourceIdentity
  if sourceIdentity == .nil then return ""
  return sourceIdentity~sourceId

::method publisherGroup
  expose sourceIdentity
  if sourceIdentity == .nil then return ""
  return sourceIdentity~publisherGroup

::method addParagraph
  expose paragraphs sourceEnvelopeId locator sealed
  use arg roleArg, textArg
  if sealed then return .false
  if textArg~string = "" then return .false
  paragraphs~append(.ReputationLibrarianParagraph~new(paragraphs~items + 1, roleArg, textArg, sourceEnvelopeId, locator, self~domainAlchemyContext))
  return .true

::method paragraphs
  expose paragraphs
  return .ReputationFeedCanonical~copyArray(paragraphs)

::method paragraphCount
  expose paragraphs
  return paragraphs~items

::method seal
  expose documentId documentKind sourceIdentity paragraphs sealed
  if documentId = "" | documentKind = "" then raise syntax 88.900 array("ReputationAcquiredDocument requires documentId and documentKind")
  if sourceIdentity == .nil then raise syntax 88.900 array("ReputationAcquiredDocument requires source identity")
  if \sourceIdentity~sealed then raise syntax 88.900 array("ReputationAcquiredDocument source identity must be sealed")
  if paragraphs~items = 0 then raise syntax 88.900 array("ReputationAcquiredDocument requires retained content")
  sealed = .true
  return self

::method canonicalText
  expose documentId documentKind sourceIdentity sourceEnvelopeId title publishedAt observedGeographyId locator paragraphs sealed
  if \sealed then raise syntax 93.900 additional("ReputationAcquiredDocument must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("DOCUMENT", documentId)
  text ||= .ReputationFeedCanonical~field("DOCUMENT_KIND", documentKind)
  text ||= .ReputationFeedCanonical~field("SOURCE", sourceIdentity~sourceId)
  text ||= .ReputationFeedCanonical~field("SOURCE_ENVELOPE", sourceEnvelopeId)
  text ||= .ReputationFeedCanonical~field("TITLE", title)
  text ||= .ReputationFeedCanonical~field("PUBLISHED", publishedAt)
  text ||= .ReputationFeedCanonical~field("OBSERVED_GEO", observedGeographyId)
  text ||= .ReputationFeedCanonical~field("LOCATOR", locator)
  paragraphTexts = .array~new
  do paragraph over paragraphs; paragraphTexts~append(paragraph~canonicalText); end
  text ||= .ReputationFeedCanonical~join("PARAGRAPH", paragraphTexts)
  return text


::class ReputationLibrarianHandoff subclass ReputationFeedAlchemyObject public
::attribute handoffId get
::attribute document get
::attribute sealed get

::method init
  expose handoffId document corpora sealed
  use arg handoffIdArg, documentArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationLibrarianHandoff", alchemyContextArg)
  handoffId = handoffIdArg~string~upper~strip
  document = documentArg
  corpora = .array~new
  sealed = .false

::method addCorpus
  expose corpora sealed
  use arg corpusArg
  if sealed then return .false
  corpus = corpusArg~string~upper~strip
  if corpus = "" then return .false
  if \.ReputationFeedCanonical~containsString(corpora, corpus) then corpora~append(corpus)
  return .true

::method corpora
  expose corpora
  return .ReputationFeedCanonical~copyArray(corpora)

::method paragraphs
  expose document
  if document == .nil then return .array~new
  return document~paragraphs

::method paragraphCount
  expose document
  if document == .nil then return 0
  return document~paragraphCount

::method seal
  expose handoffId document corpora sealed
  if handoffId = "" then raise syntax 88.900 array("ReputationLibrarianHandoff requires handoffId")
  if document == .nil | \document~sealed then raise syntax 88.900 array("ReputationLibrarianHandoff requires sealed document")
  if corpora~items = 0 then raise syntax 88.900 array("ReputationLibrarianHandoff requires at least one requested corpus")
  sealed = .true
  return self

::method canonicalText
  expose handoffId document corpora sealed
  if \sealed then raise syntax 93.900 additional("ReputationLibrarianHandoff must be sealed before canonicalisation")
  return .ReputationFeedCanonical~field("HANDOFF", handoffId) || -
         .ReputationFeedCanonical~field("DOCUMENT", document~documentId) || -
         .ReputationFeedCanonical~join("CORPUS", corpora) || -
         .ReputationFeedCanonical~field("DOCUMENT_CANONICAL", document~canonicalText)


::class ReputationAcquisitionResult subclass ReputationFeedAlchemyObject public
::attribute adapterId get
::attribute envelopeId get
::attribute accepted get
::attribute status get
::attribute reason get
::attribute document get
::attribute librarianHandoff get
::attribute feedArticle get

::method init
  expose adapterId envelopeId accepted status reason document librarianHandoff feedArticle
  use arg adapterIdArg, envelopeIdArg, acceptedArg, statusArg, reasonArg = "", documentArg = .nil, handoffArg = .nil, feedArticleArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationAcquisitionResult", alchemyContextArg)
  adapterId = adapterIdArg~string~upper~strip
  envelopeId = envelopeIdArg~string~upper~strip
  accepted = acceptedArg
  status = statusArg~string~upper~strip
  reason = reasonArg~string
  document = documentArg
  librarianHandoff = handoffArg
  feedArticle = feedArticleArg

::method canonicalText
  expose adapterId envelopeId accepted status reason document librarianHandoff feedArticle
  if document == .nil then documentId = ""; else documentId = document~documentId
  if librarianHandoff == .nil then handoffId = ""; else handoffId = librarianHandoff~handoffId
  if feedArticle == .nil then articleId = ""; else articleId = feedArticle~articleId
  return .ReputationFeedCanonical~field("ADAPTER", adapterId) || -
         .ReputationFeedCanonical~field("ENVELOPE", envelopeId) || -
         .ReputationFeedCanonical~field("ACCEPTED", accepted) || -
         .ReputationFeedCanonical~field("STATUS", status) || -
         .ReputationFeedCanonical~field("REASON", reason) || -
         .ReputationFeedCanonical~field("DOCUMENT", documentId) || -
         .ReputationFeedCanonical~field("HANDOFF", handoffId) || -
         .ReputationFeedCanonical~field("ARTICLE", articleId)


::class ReputationSourceAdapter subclass ReputationFeedAlchemyObject public
::attribute adapterId get
::attribute adapterKind get

::method init
  expose adapterId adapterKind
  use arg adapterIdArg, adapterKindArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceAdapter", alchemyContextArg)
  adapterId = adapterIdArg~string~upper~strip
  adapterKind = adapterKindArg~string~upper~strip

::method accepts
  use arg envelope
  return .false

::method adapt
  use arg envelope
  raise syntax 93.900 additional("ReputationSourceAdapter is a contract base; use a concrete source adapter")

::method buildDocument protected
  expose adapterId
  use arg envelope, documentKind, corpusId
  context = self~domainAlchemyContext
  if envelope == .nil | \envelope~sealed then raise syntax 88.900 array("Source adapter requires sealed raw envelope")
  source = envelope~sourceIdentity
  title = envelope~fieldValue("TITLE", "")
  geography = envelope~fieldValue("OBSERVED_GEOGRAPHY", source~defaultGeographyId)
  document = .ReputationAcquiredDocument~new("DOC-" || envelope~envelopeId, documentKind, source, envelope~envelopeId, title, envelope~sourceObservedAt, geography, envelope~locator, context)
  do segment over envelope~segments
    document~addParagraph(segment~segmentRole, segment~text)
  end
  document~seal
  handoff = .ReputationLibrarianHandoff~new("LIB-" || envelope~envelopeId, document, context)
  handoff~addCorpus(corpusId)
  extraCorpus = envelope~fieldValue("LIBRARIAN_CORPUS", "")
  if extraCorpus <> "" then handoff~addCorpus(extraCorpus)
  handoff~seal
  return .array~of(document, handoff)


::class ReputationNewsPublicationAdapter subclass ReputationFeedAlchemyObject public
::attribute adapterId get
::attribute adapterKind get

::method init
  expose adapterId adapterKind adapterAlchemyContext
  use arg alchemyContextArg = .nil
  adapterAlchemyContext = alchemyContextArg
  self~initDomainAlchemy("ReputationNewsPublicationAdapter", alchemyContextArg)
  adapterId = "NEWS-PUBLICATION"
  adapterKind = "NEWS_PUBLICATION"

::method accepts
  use arg envelope
  if envelope == .nil then return .false
  source = envelope~sourceIdentity
  if source == .nil then return .false
  kind = source~sourceKind
  return kind = "NEWS" | kind = "PUBLISHER"

::method adapt
  expose adapterId adapterAlchemyContext
  use arg envelope
  self~alchemyTouch("ADAPT")
  if \self~accepts(envelope) then return .ReputationAcquisitionResult~new(adapterId, envelope~envelopeId, .false, "REJECTED", "source kind not NEWS/PUBLISHER", .nil, .nil, .nil, adapterAlchemyContext)
  helper = .ReputationSourceAdapter~new(adapterId, "NEWS_PUBLICATION", adapterAlchemyContext)
  pair = helper~buildDocument(envelope, "NEWS_ARTICLE", "NEWS_LINEAGE")
  document = pair[1]
  handoff = pair[2]
  source = envelope~sourceIdentity
  article = .ReputationFeedArticle~new(document~documentId, source~sourceId, source~publisherGroup, document~title, document~publishedAt, adapterAlchemyContext)
  surfaceId = envelope~fieldValue("SURFACE_ID", source~sourceId || "::" || envelope~envelopeId)
  surface = .ReputationPublicationSurface~new(surfaceId, source~displayName, source~publisherGroup, document~observedGeographyId, document~publishedAt, adapterAlchemyContext)
  article~addSurface(surface)
  article~seal
  return .ReputationAcquisitionResult~new(adapterId, envelope~envelopeId, .true, "ACQUIRED", "", document, handoff, article, adapterAlchemyContext)


::class ReputationOfficialNoticeAdapter subclass ReputationFeedAlchemyObject public
::attribute adapterId get
::attribute adapterKind get

::method init
  expose adapterId adapterKind adapterAlchemyContext
  use arg alchemyContextArg = .nil
  adapterAlchemyContext = alchemyContextArg
  self~initDomainAlchemy("ReputationOfficialNoticeAdapter", alchemyContextArg)
  adapterId = "OFFICIAL-NOTICE"
  adapterKind = "OFFICIAL_NOTICE"

::method accepts
  use arg envelope
  if envelope == .nil then return .false
  source = envelope~sourceIdentity
  if source == .nil then return .false
  kind = source~sourceKind
  return kind = "OFFICIAL" | kind = "REGULATOR"

::method adapt
  expose adapterId adapterAlchemyContext
  use arg envelope
  self~alchemyTouch("ADAPT")
  if \self~accepts(envelope) then return .ReputationAcquisitionResult~new(adapterId, envelope~envelopeId, .false, "REJECTED", "source kind not OFFICIAL/REGULATOR", .nil, .nil, .nil, adapterAlchemyContext)
  helper = .ReputationSourceAdapter~new(adapterId, "OFFICIAL_NOTICE", adapterAlchemyContext)
  pair = helper~buildDocument(envelope, "OFFICIAL_NOTICE", "OFFICIAL_NOTICES")
  return .ReputationAcquisitionResult~new(adapterId, envelope~envelopeId, .true, "ACQUIRED", "", pair[1], pair[2], .nil, adapterAlchemyContext)


::class ReputationPublicStreamAdapter subclass ReputationFeedAlchemyObject public
::attribute adapterId get
::attribute adapterKind get

::method init
  expose adapterId adapterKind adapterAlchemyContext
  use arg alchemyContextArg = .nil
  adapterAlchemyContext = alchemyContextArg
  self~initDomainAlchemy("ReputationPublicStreamAdapter", alchemyContextArg)
  adapterId = "PUBLIC-STREAM"
  adapterKind = "PUBLIC_STREAM"

::method accepts
  use arg envelope
  if envelope == .nil then return .false
  source = envelope~sourceIdentity
  if source == .nil then return .false
  kind = source~sourceKind
  return kind = "PUBLIC_STREAM" | kind = "SOCIAL"

::method adapt
  expose adapterId adapterAlchemyContext
  use arg envelope
  self~alchemyTouch("ADAPT")
  if \self~accepts(envelope) then return .ReputationAcquisitionResult~new(adapterId, envelope~envelopeId, .false, "REJECTED", "source kind not PUBLIC_STREAM/SOCIAL", .nil, .nil, .nil, adapterAlchemyContext)
  helper = .ReputationSourceAdapter~new(adapterId, "PUBLIC_STREAM", adapterAlchemyContext)
  pair = helper~buildDocument(envelope, "PUBLIC_POST", "PUBLIC_STREAM")
  return .ReputationAcquisitionResult~new(adapterId, envelope~envelopeId, .true, "ACQUIRED", "", pair[1], pair[2], .nil, adapterAlchemyContext)


::class ReputationAcquisitionRouter subclass ReputationFeedAlchemyObject public

::method init
  expose adapters routerAlchemyContext
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationAcquisitionRouter", alchemyContextArg)
  routerAlchemyContext = alchemyContextArg
  adapters = .array~new

::method registerAdapter
  expose adapters
  use arg adapter
  if adapter == .nil then return .false
  adapters~append(adapter)
  return .true

::method adapterCount
  expose adapters
  return adapters~items

::method adapt
  expose adapters routerAlchemyContext
  use arg envelope
  self~alchemyTouch("ADAPT")
  if envelope == .nil then return .ReputationAcquisitionResult~new("ROUTER", "", .false, "REJECTED", "nil envelope", .nil, .nil, .nil, routerAlchemyContext)
  do adapter over adapters
    if adapter~accepts(envelope) then return adapter~adapt(envelope)
  end
  return .ReputationAcquisitionResult~new("ROUTER", envelope~envelopeId, .false, "NO_ADAPTER", "no registered adapter accepts source kind", .nil, .nil, .nil, routerAlchemyContext)


::class ReputationLibrarianFinding subclass ReputationFeedAlchemyObject public
::attribute findingId get
::attribute handoffId get
::attribute eventType get
::attribute title get
::attribute occurredAt get
::attribute confidence get
::attribute stance get
::attribute eventKey get
::attribute assertionOriginFamilyId get
::attribute sealed get

::method init
  expose findingId handoffId eventType title occurredAt confidence stance eventKey assertionOriginFamilyId assertionOrigins paragraphIndexes subjects concepts affectedGeographies sealed
  use arg findingIdArg, handoffIdArg, eventTypeArg, titleArg = "", occurredAtArg = .nil, confidenceArg = 50, stanceArg = "ASSERTS", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationLibrarianFinding", alchemyContextArg)
  findingId = findingIdArg~string~upper~strip
  handoffId = handoffIdArg~string~upper~strip
  eventType = eventTypeArg~string~upper~strip
  title = titleArg~string
  if occurredAtArg == .nil then occurredAt = .DateTime~new; else occurredAt = occurredAtArg
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  stance = stanceArg~string~upper~strip
  eventKey = ""
  assertionOriginFamilyId = ""
  assertionOrigins = .array~new
  paragraphIndexes = .array~new
  subjects = .array~new
  concepts = .array~new
  affectedGeographies = .array~new
  sealed = .false

::method setEventKey
  expose eventKey sealed
  use arg valueArg
  if sealed then return .false
  eventKey = valueArg~string~upper~strip
  return .true

::method addAssertionOrigin
  expose assertionOriginFamilyId assertionOrigins sealed
  use arg rootAssertionIdArg, sourceIdArg, relationshipArg = "DERIVED_FROM", evidenceIdArg = "", detailArg = ""
  if sealed then return .false
  root = rootAssertionIdArg~string~upper~strip
  if root = "" then return .false
  if assertionOriginFamilyId <> "" & assertionOriginFamilyId <> root then raise syntax 88.900 array("ReputationLibrarianFinding represents one atomic assertion and cannot carry multiple assertion roots")
  link = .ReputationAssertionOriginLink~new(root, sourceIdArg, relationshipArg, evidenceIdArg, detailArg, self~domainAlchemyContext)
  do existing over assertionOrigins
    if existing~canonicalText == link~canonicalText then return .false
  end
  assertionOrigins~append(link)
  assertionOriginFamilyId = root
  return .true

::method addParagraphIndex
  expose paragraphIndexes sealed
  use arg indexArg
  if sealed then return .false
  index = indexArg + 0
  if index < 1 then return .false
  do existing over paragraphIndexes
    if existing = index then return .false
  end
  paragraphIndexes~append(index)
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

::method paragraphIndexes
  expose paragraphIndexes
  return .ReputationFeedCanonical~copyArray(paragraphIndexes)

::method subjects
  expose subjects
  return .ReputationFeedCanonical~copyArray(subjects)

::method concepts
  expose concepts
  return .ReputationFeedCanonical~copyArray(concepts)

::method affectedGeographies
  expose affectedGeographies
  return .ReputationFeedCanonical~copyArray(affectedGeographies)

::method assertionOrigins
  expose assertionOrigins
  return .ReputationFeedCanonical~copyArray(assertionOrigins)

::method seal
  expose findingId handoffId eventType paragraphIndexes sealed
  if findingId = "" | handoffId = "" | eventType = "" then raise syntax 88.900 array("ReputationLibrarianFinding requires findingId, handoffId and eventType")
  if paragraphIndexes~items = 0 then raise syntax 88.900 array("ReputationLibrarianFinding requires paragraph evidence")
  sealed = .true
  return self

::method canonicalText
  expose findingId handoffId eventType title occurredAt confidence stance eventKey assertionOriginFamilyId assertionOrigins paragraphIndexes subjects concepts affectedGeographies sealed
  if \sealed then raise syntax 93.900 additional("ReputationLibrarianFinding must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("FINDING", findingId)
  text ||= .ReputationFeedCanonical~field("HANDOFF", handoffId)
  text ||= .ReputationFeedCanonical~field("EVENT_TYPE", eventType)
  text ||= .ReputationFeedCanonical~field("TITLE", title)
  text ||= .ReputationFeedCanonical~field("OCCURRED", occurredAt)
  text ||= .ReputationFeedCanonical~field("CONFIDENCE", confidence)
  text ||= .ReputationFeedCanonical~field("STANCE", stance)
  text ||= .ReputationFeedCanonical~field("EVENT_KEY", eventKey)
  text ||= .ReputationFeedCanonical~field("ASSERTION_ORIGIN_FAMILY", assertionOriginFamilyId)
  originTexts = .array~new
  do origin over assertionOrigins; originTexts~append(origin~canonicalText); end
  text ||= .ReputationFeedCanonical~join("ASSERTION_ORIGIN", originTexts)
  text ||= .ReputationFeedCanonical~join("PARAGRAPH_INDEX", paragraphIndexes)
  subjectTexts = .array~new
  do subject over subjects; subjectTexts~append(subject~canonicalText); end
  text ||= .ReputationFeedCanonical~join("SUBJECT", subjectTexts)
  text ||= .ReputationFeedCanonical~join("CONCEPT", concepts)
  text ||= .ReputationFeedCanonical~join("AFFECTED_GEO", affectedGeographies)
  return text


::class ReputationLibrarianClaimBridge subclass ReputationFeedAlchemyObject public

::method claimFromFinding
  use arg claimId, familyId, handoff, finding, claimState = "ACTIVE", sourceEvidencePacket = .nil
  self~alchemyTouch("CLAIM_FROM_FINDING")
  if handoff == .nil | \handoff~sealed then raise syntax 88.900 array("Librarian claim bridge requires sealed handoff")
  if finding == .nil | \finding~sealed then raise syntax 88.900 array("Librarian claim bridge requires sealed finding")
  if handoff~handoffId <> finding~handoffId then raise syntax 88.900 array("Librarian finding belongs to a different handoff")
  document = handoff~document
  claim = .ReputationFeedClaim~new(claimId, document~documentId, familyId, finding~eventType, finding~title, finding~occurredAt, document~publishedAt, document~observedGeographyId, finding~confidence, finding~stance, claimState, document~sourceId, document~locator, self~domainAlchemyContext)
  if finding~eventKey <> "" then claim~setEventKey(finding~eventKey)
  do origin over finding~assertionOrigins
    claim~addAssertionOrigin(origin~rootAssertionId, origin~sourceId, origin~relationship, origin~evidenceId, origin~detail)
  end
  if sourceEvidencePacket \== .nil then do
    if \sourceEvidencePacket~sealed then raise syntax 88.900 array("Source evidence packet must be sealed before claim attachment")
    if sourceEvidencePacket~sourceId \= document~sourceId then raise syntax 88.900 array("Source evidence packet belongs to a different source")
    claim~setSourceAuthentication(sourceEvidencePacket~authenticationState, sourceEvidencePacket~authenticationEvidenceId, sourceEvidencePacket~sourceCompromised, sourceEvidencePacket~historyEvidenceId)
  end
  do subject over finding~subjects; claim~addSubject(subject~subjectKind, subject~subjectId, subject~strength); end
  do concept over finding~concepts; claim~addConcept(concept); end
  do geography over finding~affectedGeographies; claim~addAffectedGeography(geography); end
  claim~seal
  return claim

::requires 'ReputationFeed.cls'
