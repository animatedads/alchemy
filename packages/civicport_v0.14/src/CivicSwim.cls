/*
 * CivicSwim.cls - CivicPort v0.12 SWIM evidence projection.
 *
 * This file consumes already-journalled Queue Fabric evidence.  It contains no
 * JMS provider, Java bridge, queue acknowledgement, or credential code.
 */

::class CivicSwimBuild public
::constant RELEASE "0.12"
::constant STRUCTURED_RELATION_VERSION "0.9"


::class CivicSwimPolicy subclass CivicAlchemyObject public
::constant SOURCE_ID "faa.swim.scds.aim-fns"
::constant SEMANTIC_KIND "FAA_SWIM_AIM_FNS"
::constant USE_CLASSIFICATION "NOT_FOR_OPERATIONAL_USE"
::constant RELEASE_CLASSIFICATION "PUBLIC_RELEASE_PREAPPROVED_NDRB"
::constant EXPECTED_PROVIDER "SOLACE"
::constant DEFAULT_LOCAL_QUEUE "FAA.SWIM.AIM_FNS"
::constant XML_GENERATION "faa.swim.scds.xml/0.1"
::constant SIMPLE_TEXT_GENERATION "faa.swim.aim-fns.simple-text/0.1"


::class CivicSwimParseResult subclass CivicAlchemyObject public
::attribute ok get
::attribute document get
::attribute errorCode get
::attribute message get

::method success class
  use arg document
  return self~new(.true, document, "", "")

::method failure class
  use arg code, message = ""
  return self~new(.false, .nil, code, message)

::method init
  expose ok document errorCode message
  use arg okArg, documentArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  document = documentArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicSwimXmlDocument subclass CivicAlchemyObject public
::attribute queueDocument get
::attribute generation get
::attribute parserName get
::attribute rootQName get
::attribute parsedAt get
::attribute sourceIdentity get
::attribute useClassification get
::attribute releaseClassification get

::method init
  expose queueDocument generation parserName rootQName parsedAt sourceIdentity useClassification releaseClassification
  use arg queueDocumentArg, generationArg, parserNameArg, rootQNameArg, parsedAtArg = ""
  ignore = self~initCivicAlchemy
  queueDocument = queueDocumentArg
  generation = generationArg~string
  parserName = parserNameArg~string
  rootQName = rootQNameArg~string
  if parsedAtArg~string = "" then parsedAt = .DateTime~new~utcIsoDate
  else parsedAt = parsedAtArg~string
  sourceIdentity = queueDocument~sourceIdentity
  useClassification = queueDocument~useClassification
  releaseClassification = .CivicSwimPolicy~RELEASE_CLASSIFICATION
  self~registerExternalRequirement("library", "structured_relation_plugin", .CivicSwimBuild~STRUCTURED_RELATION_VERSION, .true)

::method nativeDocument
  expose queueDocument sourceIdentity
  /* Return a new rich tree so callers cannot mutate the frozen queue evidence. */
  return .XmlDocumentContext~fromText(queueDocument~bodyText, "civic-queue:" || sourceIdentity)

::method provenance
  d = .directory~new
  d["kind"] = "CIVIC_SWIM_XML_DOCUMENT"
  d["generation"] = self~generation
  d["sourceIdentity"] = self~sourceIdentity
  d["queueEvidenceIdentity"] = self~queueDocument~evidenceIdentity
  d["parser"] = self~parserName
  d["rootQName"] = self~rootQName
  d["useClassification"] = self~useClassification
  d["releaseClassification"] = self~releaseClassification
  return d


::class CivicSwimXmlAdapter subclass CivicAlchemyObject public
::method init
  ignore = self~initCivicAlchemy
  self~registerExternalRequirement("library", "structured_relation_plugin", .CivicSwimBuild~STRUCTURED_RELATION_VERSION, .true)

::method parse
  use arg queueDocument
  if queueDocument == .nil then return .CivicSwimParseResult~failure("QUEUE_DOCUMENT_REQUIRED")
  if \queueDocument~bodyType~caselessEquals("TEXT") then -
    return .CivicSwimParseResult~failure("SWIM_TEXT_REQUIRED", queueDocument~bodyType)
  if queueDocument~bodyText~string = "" then return .CivicSwimParseResult~failure("SWIM_XML_EMPTY")
  if queueDocument~useClassification \= "" & -
     \queueDocument~useClassification~caselessEquals(.CivicSwimPolicy~USE_CLASSIFICATION) then -
    return .CivicSwimParseResult~failure("SWIM_USE_CLASSIFICATION_MISMATCH", queueDocument~useClassification)

  signal on syntax name xmlFailure
  native = .XmlDocumentContext~fromText(queueDocument~bodyText, "civic-queue:" || queueDocument~sourceIdentity)
  signal off syntax
  if native~root == .nil then return .CivicSwimParseResult~failure("SWIM_XML_ROOT_MISSING")
  document = .CivicSwimXmlDocument~new(queueDocument, .CivicSwimPolicy~XML_GENERATION, native~parserName, native~root~qName)
  return .CivicSwimParseResult~success(document)

xmlFailure:
  signal off syntax
  return .CivicSwimParseResult~failure("SWIM_XML_INVALID", condition("D"))


::class CivicAimFnsProjectionResult subclass CivicAlchemyObject public
::attribute ok get
::attribute projection get
::attribute errorCode get
::attribute message get

::method success class
  use arg projection
  return self~new(.true, projection, "", "")

::method failure class
  use arg code, message = ""
  return self~new(.false, .nil, code, message)

::method init
  expose ok projection errorCode message
  use arg okArg, projectionArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  projection = projectionArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicAimFnsSimpleTextProjection subclass CivicAlchemyObject public
::attribute swimDocument get
::attribute generation get
::attribute simpleText get
::attribute sourcePath get
::attribute sourceLine get
::attribute identity get

::method init
  expose swimDocument generation simpleText sourcePath sourceLine identity
  use arg swimDocumentArg, simpleTextArg, sourcePathArg, sourceLineArg = 0
  ignore = self~initCivicAlchemy
  swimDocument = swimDocumentArg
  generation = .CivicSwimPolicy~SIMPLE_TEXT_GENERATION
  simpleText = simpleTextArg
  sourcePath = sourcePathArg~string
  sourceLine = sourceLineArg
  identity = "CIVIC-SWIM-SIMPLE-TEXT-V1:" || c2x(swimDocument~sourceIdentity) || ":" || c2x(sourcePath) || ":" || swimDocument~queueDocument~bodyDigest

::method provenance
  d = .directory~new
  d["kind"] = "CIVIC_SWIM_AIM_FNS_SIMPLE_TEXT"
  d["generation"] = self~generation
  d["identity"] = self~identity
  d["sourceIdentity"] = self~swimDocument~sourceIdentity
  d["sourcePath"] = self~sourcePath
  d["sourceLine"] = self~sourceLine
  d["queueEvidenceIdentity"] = self~swimDocument~queueDocument~evidenceIdentity
  d["useClassification"] = self~swimDocument~useClassification
  return d


::class CivicAimFnsSimpleTextAdapter subclass CivicAlchemyObject public
::method init
  ignore = self~initCivicAlchemy
  self~registerExternalRequirement("library", "structured_relation_plugin", .CivicSwimBuild~STRUCTURED_RELATION_VERSION, .true)

::method project
  use arg swimDocument
  if swimDocument == .nil then return .CivicAimFnsProjectionResult~failure("SWIM_DOCUMENT_REQUIRED")
  signal on syntax name xmlFailure
  native = swimDocument~nativeDocument
  matches = .array~new
  do node over native~allNodes
    if node~kind = "ELEMENT" & node~localName = "simpleText" then matches~append(node)
  end
  signal off syntax
  if matches~items = 0 then return .CivicAimFnsProjectionResult~failure("AIM_FNS_SIMPLE_TEXT_ABSENT")
  if matches~items > 1 then return .CivicAimFnsProjectionResult~failure("AIM_FNS_SIMPLE_TEXT_AMBIGUOUS", matches~items~string)
  node = matches[1]
  text = node~text
  if text = "" then return .CivicAimFnsProjectionResult~failure("AIM_FNS_SIMPLE_TEXT_EMPTY")
  projection = .CivicAimFnsSimpleTextProjection~new(swimDocument, text, node~path, node~line)
  return .CivicAimFnsProjectionResult~success(projection)

xmlFailure:
  signal off syntax
  return .CivicAimFnsProjectionResult~failure("SWIM_XML_REPARSE_FAILED", condition("D"))


::requires "CivicQueueEvidence.cls"
::requires "XmlNativeSource.cls"
