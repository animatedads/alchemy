/*
 * CivicPort v0.7 HardWorld bridge.
 *
 * This file does not fetch network data and does not infer authority from an
 * HTTP source.  It freezes an already-materialized CivicCacheResult into a
 * CivicObservation, exposes rich evidence for named mapping fields, and only
 * changes HardWorld state through an explicit CivicPromotionGrant followed by
 * CivicPromotionApplier~apply().
 */

::class CivicObservationField subclass CivicAlchemyObject public
::attribute name get
::attribute pointer get
::attribute required get
::attribute expectedType get
::attribute nullable get

::method init
  expose name pointer required expectedType nullable
  use arg field
  ignore = self~initCivicAlchemy
  if field == .nil then raise syntax 93.900 additional("CivicObservationField requires a mapping field")
  name = field~name~string
  pointer = field~pointer~string
  required = field~required
  expectedType = field~expectedType~string~translate
  nullable = field~nullable

::method algorithmCanonicalText
  text = "CIVIC_OBSERVATION_FIELD_V1" || '0a'x
  text = text || self~fieldText("NAME", self~name)
  text = text || self~fieldText("POINTER", self~pointer)
  text = text || self~fieldText("REQUIRED", self~boolText(self~required))
  text = text || self~fieldText("EXPECTED_TYPE", self~expectedType)
  text = text || self~fieldText("NULLABLE", self~boolText(self~nullable))
  return text

::method boolText private
  use arg value
  if value then return "TRUE"
  return "FALSE"

::method fieldText private
  use arg name, value
  rendered = value~string
  return name || "=" || rendered~length || ":" || rendered || '0a'x


::class CivicObservationResult subclass CivicAlchemyObject public
::attribute ok get
::attribute observation get
::attribute errorCode get
::attribute message get

::method success class
  use arg observation
  return .CivicObservationResult~new(.true, observation, "", "")

::method failure class
  use arg code, message
  return .CivicObservationResult~new(.false, .nil, code, message)

::method init
  expose ok observation errorCode message
  use arg okArg, observationArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  observation = observationArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicObservation subclass CivicAlchemyObject public
::attribute document get
::attribute httpObservation get
::attribute mappingResult get
::attribute cacheResult get
::attribute mappingId get
::attribute bodyDigest get
::attribute bodyRecordId get
::attribute observationRecordId get
::attribute cacheState get
::attribute identity get
::attribute accessState get
::attribute sourcePointer get

::method init
  expose document httpObservation mappingResult cacheResult mappingId bodyDigest bodyRecordId observationRecordId cacheState identity accessState sourcePointer storedFields storedValues
  use arg cacheOutcome, mapped, mappingFields
  ignore = self~initCivicAlchemy
  if cacheOutcome == .nil | \cacheOutcome~ok then raise syntax 93.900 additional("CivicObservation requires a successful CivicCacheResult")
  if mapped == .nil | \mapped~ok then raise syntax 93.900 additional("CivicObservation requires a successful CivicJsonMappingResult")
  document = cacheOutcome~document
  httpObservation = cacheOutcome~observation
  mappingResult = mapped
  cacheResult = cacheOutcome
  mappingId = mapped~mappingId
  bodyDigest = document~bodyDigest
  bodyRecordId = cacheOutcome~bodyRecordId
  observationRecordId = cacheOutcome~observationRecordId
  cacheState = cacheOutcome~cacheState
  accessState = cacheOutcome~accessState
  sourcePointer = mapped~sourcePointer

  storedFields = .directory~new
  storedValues = .directory~new
  do field over mappingFields
    snapshot = .CivicObservationField~new(field)
    key = snapshot~name~translate
    if storedFields~hasIndex(key) then raise syntax 93.900 additional("CivicObservation duplicate mapped field: " || snapshot~name)
    storedFields[key] = snapshot
    storedValues[key] = self~copyJsonValue(mapped~row[snapshot~name])
  end

  if storedFields~items = 0 then raise syntax 93.900 additional("CivicObservation requires at least one mapped field")
  identity = "CIVICOBS-V2:" || mappingId || ":" || bodyDigest || ":" || bodyRecordId || ":" || observationRecordId || ":" || accessState~identity
  if sourcePointer \= "" then identity = identity || ":SOURCE:" || sourcePointer

::method fieldNames
  expose storedFields
  names = .array~new
  do key over storedFields~allIndexes
    names~append(storedFields[key]~name)
  end
  names~sort
  return names

::method fieldDefinition
  expose storedFields
  use arg name
  return storedFields[name~string~translate]

::method hasField
  expose storedFields
  use arg name
  return storedFields~hasIndex(name~string~translate)

::method field
  expose storedFields storedValues
  use arg name
  key = name~string~translate
  definition = storedFields[key]
  if definition == .nil then return .nil
  return self~copyJsonValue(storedValues[key])


::method copyJsonValue private
  use arg value
  if value == .nil then return .nil
  if value~isA(.Directory) then do
    copiedObject = .directory~new
    do key over value~allIndexes
      copiedObject[key] = self~copyJsonValue(value[key])
    end
    return copiedObject
  end
  if value~isA(.Array) then do
    copiedArray = .array~new
    do item over value
      copiedArray~append(self~copyJsonValue(item))
    end
    return copiedArray
  end
  return value

::method fieldState
  expose document storedFields
  use arg name
  key = name~string~translate
  definition = storedFields[key]
  if definition == .nil then return "UNMAPPED"
  tree = document~parsed
  if tree == .nil then return "INVALID"
  pointerOutcome = .CivicJsonPointer~evaluate(tree, self~fullPointer(definition~pointer))
  if \pointerOutcome~present then return "ABSENT"
  if pointerOutcome~value == .nil then return "PRESENT_NULL"
  return "PRESENT"

::method fullPointer private
  expose sourcePointer
  use arg fieldPointer
  if sourcePointer = "" then return fieldPointer~string
  if fieldPointer~string = "" then return sourcePointer
  return sourcePointer || fieldPointer~string

::method fieldPromotable
  use arg name
  state = self~fieldState(name)
  if state = "UNMAPPED" | state = "INVALID" then return .false
  if state = "ABSENT" | state = "PRESENT_NULL" then return .true
  value = self~field(name)
  if value == .nil then return .true
  if value~isA(.Directory) | value~isA(.Array) then return .false
  if value~isA(.String) | value~isA(.JsonBoolean) then return .true
  return .false

::method promotionValue
  use arg name
  state = self~fieldState(name)
  if state = "ABSENT" | state = "PRESENT_NULL" then return .nil
  if state \= "PRESENT" then raise syntax 93.900 additional("Civic field is not promotable: " || name || " state=" || state)
  value = self~field(name)
  if value == .nil then return .nil
  if value~isA(.JsonBoolean) then do
    if value~value then return .true
    return .false
  end
  if value~isA(.String) then return value~string
  raise syntax 93.900 additional("Civic field requires an explicit projection before promotion: " || name)

::method richValue
  use arg name, semanticRole = ""
  definition = self~fieldDefinition(name)
  if definition == .nil then raise syntax 93.900 additional("Civic observation field is not mapped: " || name)
  if semanticRole~string = "" then semanticRole = definition~name
  state = self~fieldState(name)
  raw = self~field(name)

  evidenceState = state
  projectionState = .RichEvidenceProjectionState~SCALAR_REFUSED
  presentation = .nil
  lexical = .nil
  typed = .nil

  select
    when state = "ABSENT" then projectionState = .RichEvidenceProjectionState~ABSENT
    when state = "PRESENT_NULL" then projectionState = .RichEvidenceProjectionState~SCALAR_REFUSED
    when state = "PRESENT" then do
      if raw~isA(.JsonBoolean) then do
        if raw~value then do
          lexical = "true"
          typed = .true
          presentation = .true
        end
        else do
          lexical = "false"
          typed = .false
          presentation = .false
        end
        projectionState = .RichEvidenceProjectionState~SCALAR_AVAILABLE
      end
      else if raw~isA(.String) then do
        /* ooRexx JSON numbers are parser-native Strings.  Keep them exactly. */
        lexical = raw
        typed = raw
        presentation = raw
        projectionState = .RichEvidenceProjectionState~SCALAR_AVAILABLE
      end
      else projectionState = .RichEvidenceProjectionState~SCALAR_REFUSED
    end
    otherwise projectionState = .RichEvidenceProjectionState~INVALID_SOURCE
  end

  sourceIdentity = self~identity || ":FIELD:" || definition~name
  documentIdentity = "SHA512:" || self~bodyDigest
  fullPointer = self~fullPointer(definition~pointer)
  sourceRef = .RichEvidenceSourceRef~new(self~document, sourceIdentity, "JSON", "CIVIC_HTTP", fullPointer, lexical, typed, self~mappingResult~status, documentIdentity, .nil, .nil, "CIVIC_MAPPING:" || self~mappingId)
  canonicalIdentity = "CIVIC_FIELD_V1:" || self~identity || ":" || definition~name || ":" || fullPointer || ":" || state
  consistencyHash = "CIVIC_OBSERVATION:" || self~identity
  return .RichEvidenceValue~new(self, canonicalIdentity, semanticRole, evidenceState, projectionState, presentation, .array~of(sourceRef), .array~new, "FROZEN_OBSERVATION", consistencyHash, .array~new, .array~of(self))

::method algorithmCanonicalText
  expose document httpObservation mappingResult mappingId bodyDigest bodyRecordId observationRecordId cacheState accessState sourcePointer storedFields
  text = "CIVIC_OBSERVATION_V1" || '0a'x
  text = text || self~fieldText("IDENTITY", self~identity)
  text = text || self~fieldText("MAPPING", mappingId)
  if sourcePointer \= "" then text = text || self~fieldText("SOURCE_POINTER", sourcePointer)
  text = text || self~fieldText("URL", document~request~url)
  text = text || self~fieldText("METHOD", document~request~method)
  text = text || self~fieldText("CREDENTIAL_REF", document~request~credentialRef)
  text = text || self~fieldText("HTTP_STATUS", document~status)
  text = text || self~fieldText("BODY_SHA512", bodyDigest)
  text = text || self~fieldText("BODY_FETCHED_AT", document~fetchedAt)
  text = text || self~fieldText("BODY_RECORD_ID", bodyRecordId)
  text = text || self~fieldText("OBSERVATION_RECORD_ID", observationRecordId)
  text = text || self~fieldText("CACHE_STATE", cacheState)
  text = text || self~fieldText("ACCESS_STATE", accessState~state)
  text = text || self~fieldText("DEGRADATION_CAUSE", accessState~cause)
  text = text || self~fieldText("RETRY_AFTER", accessState~retryAfter)
  text = text || self~fieldText("STALE_REASON_CODE", accessState~staleReasonCode)

  if httpObservation == .nil then text = text || "HTTP_OBSERVATION=NULL" || '0a'x
  else do
    text = text || self~fieldText("OBS_STATUS", httpObservation~status)
    text = text || self~fieldText("OBS_FETCHED_AT", httpObservation~fetchedAt)
    text = text || self~fieldText("OBS_BODY_SHA512", httpObservation~bodyDigest)
    rawHeaders = httpObservation~rawHeaderBytes
    text = text || "OBS_HEADERS=" || rawHeaders~length || ":" || rawHeaders || '0a'x
  end

  keys = storedFields~allIndexes
  keys~sort
  text = text || "FIELD_COUNT=" || keys~items || '0a'x
  do key over keys
    fieldText = storedFields[key]~algorithmCanonicalText
    text = text || fieldText~length || ":" || fieldText || '0a'x
  end
  return text

::method fieldText private
  use arg name, value
  rendered = value~string
  return name || "=" || rendered~length || ":" || rendered || '0a'x


::class CivicObservationFactory subclass CivicAlchemyObject public
::method observe class
  use arg cacheOutcome, adapter
  if cacheOutcome == .nil then return .CivicObservationResult~failure("CACHE_RESULT_MISSING", "CivicCacheResult is required")
  if \cacheOutcome~ok then return .CivicObservationResult~failure("CACHE_RESULT_FAILED", cacheOutcome~errorCode || " " || cacheOutcome~message)
  if adapter == .nil then return .CivicObservationResult~failure("ADAPTER_MISSING", "Civic adapter is required")
  if \adapter~hasMethod("MAP") | \adapter~hasMethod("MAPPING") then -
    return .CivicObservationResult~failure("ADAPTER_CONTRACT", "Civic adapter must expose MAP and MAPPING")
  mapped = adapter~map(cacheOutcome~document)
  mapping = adapter~mapping
  return self~observeMapped(cacheOutcome, mapped, mapping)

::method observeMapped class
  use arg cacheOutcome, mapped, mapping
  if cacheOutcome == .nil then return .CivicObservationResult~failure("CACHE_RESULT_MISSING", "CivicCacheResult is required")
  if \cacheOutcome~ok then return .CivicObservationResult~failure("CACHE_RESULT_FAILED", cacheOutcome~errorCode || " " || cacheOutcome~message)
  if mapped == .nil | \mapped~ok then do
    if mapped == .nil then return .CivicObservationResult~failure("MAPPING_FAILED", "Adapter returned no mapping result")
    return .CivicObservationResult~failure("MAPPING_INVALID", mapped~mappingId || " " || mapped~errorCode || " " || mapped~message)
  end
  if mapping == .nil then return .CivicObservationResult~failure("MAPPING_CONTRACT", "Adapter mapping is absent")
  if mapping~mappingId \== mapped~mappingId then -
    return .CivicObservationResult~failure("MAPPING_ID_DRIFT", "Adapter mapping id changed during observation")
  observation = .CivicObservation~new(cacheOutcome, mapped, mapping~fields)
  return .CivicObservationResult~success(observation)


::class CivicPromotionGrant subclass CivicAlchemyObject public
::attribute promotionId get
::attribute observation get
::attribute observationIdentity get
::attribute mappingId get
::attribute bodyDigest get
::attribute fieldName get
::attribute targetFactName get
::attribute authority get
::attribute policyId get
::attribute ruleId get
::attribute allowStale get

::method init
  expose promotionId observation observationIdentity mappingId bodyDigest fieldName targetFactName authority policyId ruleId allowStale
  use arg promotionIdArg, observationArg, fieldNameArg, targetFactArg, authorityArg, policyIdArg, ruleIdArg, allowStaleArg = .false
  ignore = self~initCivicAlchemy
  if observationArg == .nil then raise syntax 93.900 additional("CivicPromotionGrant requires a CivicObservation")
  promotionId = promotionIdArg~string
  if promotionId = "" then raise syntax 93.900 additional("CivicPromotionGrant requires a promotion id")
  observation = observationArg
  observationIdentity = observation~identity
  mappingId = observation~mappingId
  bodyDigest = observation~bodyDigest
  fieldName = fieldNameArg~string
  if \observation~hasField(fieldName) then raise syntax 93.900 additional("CivicPromotionGrant field is not mapped: " || fieldName)
  if \observation~fieldPromotable(fieldName) then raise syntax 93.900 additional("CivicPromotionGrant field requires explicit projection: " || fieldName)
  targetFactName = targetFactArg~string~translate
  if targetFactName = "" then raise syntax 93.900 additional("CivicPromotionGrant requires a target HardWorld fact")
  authority = authorityArg~string
  policyId = policyIdArg~string
  ruleId = ruleIdArg~string
  if authority = "" then raise syntax 93.900 additional("CivicPromotionGrant requires explicit authority")
  if policyId = "" then raise syntax 93.900 additional("CivicPromotionGrant requires explicit policy id")
  if ruleId = "" then raise syntax 93.900 additional("CivicPromotionGrant requires explicit rule id")
  allowStale = allowStaleArg
  if observation~cacheState == "STALE" & \allowStale then -
    raise syntax 93.900 additional("CivicPromotionGrant refuses STALE evidence unless allowStale is explicit")

::method toEvidencePromotion
  expose promotionId observation observationIdentity mappingId bodyDigest fieldName targetFactName authority policyId ruleId allowStale
  if observation~identity \== observationIdentity then raise syntax 93.900 additional("CivicPromotionGrant observation identity drift")
  if observation~mappingId \== mappingId then raise syntax 93.900 additional("CivicPromotionGrant mapping generation drift")
  if observation~bodyDigest \== bodyDigest then raise syntax 93.900 additional("CivicPromotionGrant body identity drift")
  if observation~cacheState == "STALE" & \allowStale then raise syntax 93.900 additional("CivicPromotionGrant stale evidence no longer eligible")

  state = observation~fieldState(fieldName)
  if state = "PRESENT" then do
    knowledgeState = "KNOWN"
    proposedValue = observation~promotionValue(fieldName)
  end
  else if state = "ABSENT" | state = "PRESENT_NULL" then do
    knowledgeState = "UNKNOWN"
    proposedValue = .nil
  end
  else raise syntax 93.900 additional("CivicPromotionGrant field became invalid: " || fieldName || " state=" || state)

  evidence = observation~richValue(fieldName, targetFactName)
  basis = .array~new
  basis~append(.EvidencePromotionBasis~new("CIVIC_GRANT", promotionId, "Explicit CivicPort promotion grant", self))
  basis~append(.EvidencePromotionBasis~new("CIVIC_MAPPING_GENERATION", mappingId, fieldName || " -> " || targetFactName, observation~mappingResult))
  basis~append(.EvidencePromotionBasis~new("CIVIC_BODY_SHA512", bodyDigest, observation~document~request~url, observation~document))
  basis~append(.EvidencePromotionBasis~new("CIVIC_BODY_RECORD", observation~bodyRecordId, observation~cacheState, observation~cacheResult))
  access = observation~accessState
  basis~append(.EvidencePromotionBasis~new("CIVIC_ACCESS_STATE", access~state, access~cause || " retry-after=" || access~retryAfter, access))
  if observation~observationRecordId \= "" then -
    basis~append(.EvidencePromotionBasis~new("CIVIC_OBSERVATION_RECORD", observation~observationRecordId, observation~cacheState, observation~httpObservation))
  definition = observation~fieldDefinition(fieldName)
  basis~append(.EvidencePromotionBasis~new("CIVIC_JSON_POINTER", definition~pointer, definition~expectedType, observation~document))

  return .EvidencePromotion~new(promotionId, "CIVIC_OBSERVATION", observationIdentity, targetFactName, knowledgeState, proposedValue, -
    authority, policyId, ruleId, "CIVIC_PROMOTION", .EvidencePromotionConstant~STATUS_AUTHORIZED, "Explicit CivicPromotionGrant", -
    evidence, observation, "FROZEN_OBSERVATION", "FROZEN_OBSERVATION", basis)

::method algorithmCanonicalText
  text = "CIVIC_PROMOTION_GRANT_V1" || '0a'x
  text = text || self~fieldText("PROMOTION_ID", self~promotionId)
  text = text || self~fieldText("OBSERVATION_ID", self~observationIdentity)
  text = text || self~fieldText("MAPPING", self~mappingId)
  text = text || self~fieldText("BODY_SHA512", self~bodyDigest)
  text = text || self~fieldText("FIELD", self~fieldName)
  text = text || self~fieldText("TARGET_FACT", self~targetFactName)
  text = text || self~fieldText("AUTHORITY", self~authority)
  text = text || self~fieldText("POLICY", self~policyId)
  text = text || self~fieldText("RULE", self~ruleId)
  if self~allowStale then staleText = "TRUE"
  else staleText = "FALSE"
  text = text || self~fieldText("ALLOW_STALE", staleText)
  return text

::method fieldText private
  use arg name, value
  rendered = value~string
  return name || "=" || rendered~length || ":" || rendered || '0a'x


::class CivicPromotionApplyResult subclass CivicAlchemyObject public
::attribute applied get
::attribute conflicts get
::attribute skipped get
::attribute promotionSet get
::attribute hardWorldApply get

::method init
  expose applied conflicts skipped promotionSet hardWorldApply
  use arg promotionSetArg, hardWorldApplyArg
  ignore = self~initCivicAlchemy
  promotionSet = promotionSetArg
  hardWorldApply = hardWorldApplyArg
  applied = hardWorldApply~applied
  conflicts = hardWorldApply~conflicts
  skipped = hardWorldApply~skipped


::class CivicPromotionApplier subclass CivicAlchemyObject public
::method apply class
  use arg grants, world
  if grants == .nil then raise syntax 93.900 additional("CivicPromotionApplier requires explicit grants")
  if world == .nil then raise syntax 93.900 additional("CivicPromotionApplier requires a HardWorld world")
  promotionSet = .EvidencePromotionSet~new
  do grant over grants
    if grant == .nil | \grant~isA(.CivicPromotionGrant) then raise syntax 93.900 additional("CivicPromotionApplier accepts CivicPromotionGrant objects only")
    promotion = grant~toEvidencePromotion
    if \promotionSet~add(promotion) then raise syntax 93.900 additional("CivicPromotionApplier duplicate promotion id: " || promotion~promotionId)
  end
  promotionSet~seal
  hardWorldApply = .EvidencePromotionApplier~apply(promotionSet, world)
  return .CivicPromotionApplyResult~new(promotionSet, hardWorldApply)

::requires "CivicPostcode.cls"
::requires "CivicCache.cls"
::requires "RichEvidence.cls"
::requires "EvidencePromotion.cls"
::requires "HardWorld.cls"

::requires "CivicAlchemy.cls"
