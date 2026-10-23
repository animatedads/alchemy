/* Authoritative-document intake seam for Legal Interrogation.
 *
 * This layer does not verify legal authority and does not parse document semantics itself.
 * It retains the original source object and delegates source-native clause extraction to a
 * host adapter so Structured Relation/XML/Git/native document objects do not get flattened.
 */

::class LegalInterrogationDocumentRequest public
::attribute sessionId
::attribute sourceIdentity
::attribute sourceObject
::attribute documentKind
::attribute sourceLocator
::attribute sourceEvidence

::method init
  use strict arg sessionId, sourceIdentity, sourceObject, documentKind = "UNKNOWN", sourceLocator = "", sourceEvidence = .nil
  if sourceEvidence == .nil then sourceEvidence = .array~new
  self~sessionId = sessionId
  self~sourceIdentity = sourceIdentity
  self~sourceObject = sourceObject
  self~documentKind = documentKind~upper
  self~sourceLocator = sourceLocator
  self~sourceEvidence = sourceEvidence


::class LegalInterrogationDocumentPort public
::method begin
  use strict arg request
  if request == .nil | \request~isA(.LegalInterrogationDocumentRequest) then return .LegalInterrogationResult~failure("BAD_DOCUMENT_REQUEST", "LegalInterrogationDocumentRequest required")
  if request~sessionId == "" then return .LegalInterrogationResult~failure("MISSING_SESSION_ID", "Document intake requires a session id")
  if request~sourceIdentity == "" then return .LegalInterrogationResult~failure("MISSING_SOURCE_IDENTITY", request~sessionId)
  if request~sourceObject == .nil then return .LegalInterrogationResult~failure("MISSING_SOURCE_OBJECT", request~sourceIdentity)
  session = .LegalInterrogationSession~new(request~sessionId, request~sourceIdentity, request~sourceObject, request~documentKind, request~sourceLocator, request~sourceEvidence)
  return .LegalInterrogationResult~success(session, "DOCUMENT_ADMITTED_FOR_INTERROGATION", "Source retained for authoring; Legal Effect source verification remains a separate authority boundary")

::method ingestClauses
  use strict arg session, sourceAdapter, intentionPort, actor = "SOURCE_ADAPTER"
  if session == .nil | \session~isA(.LegalInterrogationSession) then return .LegalInterrogationResult~failure("BAD_SESSION", "LegalInterrogationSession required")
  if intentionPort == .nil | \intentionPort~isA(.LegalInterrogationIntentionPort) then return .LegalInterrogationResult~failure("BAD_INTENTION_PORT", "LegalInterrogationIntentionPort required")
  if \sourceAdapter~hasMethod("EXTRACTLEGALINTERROGATIONCLAUSES") then return .LegalInterrogationResult~failure("BAD_SOURCE_ADAPTER", "Adapter must implement extractLegalInterrogationClauses(sourceObject, sourceIdentity, sourceLocator)")
  clauses = sourceAdapter~extractLegalInterrogationClauses(session~sourceObject, session~sourceIdentity, session~sourceLocator)
  if clauses == .nil | \clauses~isA(.Array) then return .LegalInterrogationResult~failure("BAD_CLAUSE_SET", "Source adapter must return an Array")
  admitted = .array~new
  do clause over clauses
    r = intentionPort~execute(session, "INGEST_CLAUSE", clause, actor, session~id)
    if \r~ok then return r
    admitted~append(clause)
  end
  return .LegalInterrogationResult~success(admitted, "DOCUMENT_CLAUSES_ADMITTED", "Clauses entered through the same intention-governed intake path")

::requires "LegalInterrogationIntentionPort.cls"
