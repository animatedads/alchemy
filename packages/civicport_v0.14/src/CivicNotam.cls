/*
 * CivicNotam.cls - CivicPort v0.14 narrow FAA domestic NOTAM evidence projection.
 *
 * This layer consumes the already-preserved AIM FNS simpleText projection.
 * It does not connect to JMS, does not acknowledge queues, does not mutate
 * HardWorld, and does not claim to implement the complete FAA NOTAM grammar.
 *
 * Generation 0.1 accepts only one deliberately narrow shape:
 *
 *   !<accountable> <NN/NNN> <location> RWY <designator> CLSD <start>-<end>
 *
 * where start/end retain the FAA NOTAM YYMMDDHHMM lexical form.  End may
 * additionally carry EST or be PERM.  Values remain exact source strings.
 */

::class CivicNotamBuild public
::constant RELEASE "0.14"


::class CivicNotamPolicy subclass CivicAlchemyObject public
::constant SOURCE_ID "faa.swim.scds.aim-fns.notam-runway-closure"
::constant SEMANTIC_KIND "FAA_DOMESTIC_NOTAM_RUNWAY_CLOSURE"
::constant GENERATION "faa.swim.aim-fns.notam-runway-closure/0.1"
::constant REQUIRED_USE_CLASSIFICATION "NOT_FOR_OPERATIONAL_USE"
::constant OPERATIONAL_DISPOSITION "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE"
::constant TIME_LEXICAL_FORM "YYMMDDHHMM"


::class CivicNotamProjectionResult subclass CivicAlchemyObject public
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


::class CivicNotamRunwayClosureProjection subclass CivicAlchemyObject public
::attribute simpleTextProjection get
::attribute generation get
::attribute rawText get
::attribute accountableLocation get
::attribute notamNumber get
::attribute affectedLocation get
::attribute keyword get
::attribute runwayDesignator get
::attribute condition get
::attribute effectiveStartToken get
::attribute effectiveEndToken get
::attribute endQualifier get
::attribute rawTimeRange get
::attribute sourcePath get
::attribute sourceLine get
::attribute useClassification get
::attribute releaseClassification get
::attribute operationalDisposition get
::attribute identity get

::method init
  expose simpleTextProjection generation rawText accountableLocation notamNumber affectedLocation keyword runwayDesignator condition -
    effectiveStartToken effectiveEndToken endQualifier rawTimeRange sourcePath sourceLine useClassification releaseClassification -
    operationalDisposition identity
  use arg projectionArg, accountableArg, numberArg, affectedArg, runwayArg, startArg, endArg, qualifierArg, rangeArg
  ignore = self~initCivicAlchemy
  if projectionArg == .nil then raise syntax 93.900 additional("Civic NOTAM projection requires AIM FNS simpleText evidence")
  simpleTextProjection = projectionArg
  generation = .CivicNotamPolicy~GENERATION
  rawText = projectionArg~simpleText
  accountableLocation = accountableArg~string
  notamNumber = numberArg~string
  affectedLocation = affectedArg~string
  keyword = "RWY"
  runwayDesignator = runwayArg~string
  condition = "CLSD"
  effectiveStartToken = startArg~string
  effectiveEndToken = endArg~string
  endQualifier = qualifierArg~string
  rawTimeRange = rangeArg~string
  sourcePath = projectionArg~sourcePath
  sourceLine = projectionArg~sourceLine
  useClassification = projectionArg~swimDocument~useClassification
  releaseClassification = projectionArg~swimDocument~releaseClassification
  operationalDisposition = .CivicNotamPolicy~OPERATIONAL_DISPOSITION
  identity = "CIVIC-NOTAM-RWY-CLSD-V1:" || c2x(projectionArg~identity) || ":" || c2x(rawText)

  self~registerStateVariable("rawText", "EVIDENCE", "Exact AIM FNS simpleText retained by the NOTAM projection")
  self~registerStateVariable("operationalDisposition", "PUBLIC", "Explicit non-operational-use disposition inherited from the SCDS source")
  self~registerMethodContract("PROVENANCE", "Return bounded NOTAM evidence provenance", .array~new, "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method provenance
  d = .directory~new
  d["kind"] = "CIVIC_NOTAM_RUNWAY_CLOSURE"
  d["generation"] = self~generation
  d["identity"] = self~identity
  d["sourceIdentity"] = self~simpleTextProjection~swimDocument~sourceIdentity
  d["queueEvidenceIdentity"] = self~simpleTextProjection~swimDocument~queueDocument~evidenceIdentity
  d["simpleTextIdentity"] = self~simpleTextProjection~identity
  d["sourcePath"] = self~sourcePath
  d["sourceLine"] = self~sourceLine
  d["useClassification"] = self~useClassification
  d["releaseClassification"] = self~releaseClassification
  d["operationalDisposition"] = self~operationalDisposition
  return d


::class CivicNotamRunwayClosureAdapter subclass CivicAlchemyObject public
::method init
  ignore = self~initCivicAlchemy
  self~registerMethodContract("PROJECT", "Project one narrow FAA domestic runway-closure NOTAM from AIM FNS simpleText", -
    .array~of("CivicAimFnsSimpleTextProjection"), "CIVICNOTAMPROJECTIONRESULT", .true, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method project
  use arg simpleProjection
  if simpleProjection == .nil then return .CivicNotamProjectionResult~failure("AIM_FNS_SIMPLE_TEXT_REQUIRED")
  if \simpleProjection~hasMethod("SIMPLETEXT") | \simpleProjection~hasMethod("SWIMDOCUMENT") then -
    return .CivicNotamProjectionResult~failure("AIM_FNS_SIMPLE_TEXT_REQUIRED")
  if \simpleProjection~swimDocument~useClassification~caselessEquals(.CivicNotamPolicy~REQUIRED_USE_CLASSIFICATION) then -
    return .CivicNotamProjectionResult~failure("NOTAM_USE_CLASSIFICATION_MISMATCH", simpleProjection~swimDocument~useClassification)

  rawText = simpleProjection~simpleText
  text = rawText~string~strip
  if text = "" then return .CivicNotamProjectionResult~failure("NOTAM_TEXT_EMPTY")
  tokenCount = text~words
  if tokenCount \= 7 then return .CivicNotamProjectionResult~failure("NOTAM_RUNWAY_CLOSURE_SHAPE_UNSUPPORTED", tokenCount~string)

  accountableToken = text~word(1)
  if accountableToken~left(1) \= "!" then return .CivicNotamProjectionResult~failure("NOTAM_ACCOUNTABLE_LOCATION_INVALID", accountableToken)
  accountable = accountableToken~substr(2)
  if \self~validLocation(accountable) then return .CivicNotamProjectionResult~failure("NOTAM_ACCOUNTABLE_LOCATION_INVALID", accountableToken)

  numberToken = text~word(2)
  if \self~validNotamNumber(numberToken) then return .CivicNotamProjectionResult~failure("NOTAM_NUMBER_INVALID", numberToken)

  affected = text~word(3)
  if \self~validLocation(affected) then return .CivicNotamProjectionResult~failure("NOTAM_AFFECTED_LOCATION_INVALID", affected)

  keywordToken = text~word(4)~translate
  if keywordToken \= "RWY" then return .CivicNotamProjectionResult~failure("NOTAM_KEYWORD_UNSUPPORTED", keywordToken)

  runwayToken = text~word(5)~translate
  if \self~validRunwayDesignator(runwayToken) then return .CivicNotamProjectionResult~failure("NOTAM_RUNWAY_DESIGNATOR_INVALID", runwayToken)

  conditionToken = text~word(6)~translate
  if conditionToken \= "CLSD" then return .CivicNotamProjectionResult~failure("NOTAM_CONDITION_UNSUPPORTED", conditionToken)

  rangeToken = text~word(7)~translate
  timeParts = self~parseTimeRange(rangeToken)
  if timeParts == .nil then return .CivicNotamProjectionResult~failure("NOTAM_TIME_RANGE_INVALID", rangeToken)

  projection = .CivicNotamRunwayClosureProjection~new(simpleProjection, accountable, numberToken, affected, runwayToken, -
    timeParts["START"], timeParts["END"], timeParts["QUALIFIER"], rangeToken)
  return .CivicNotamProjectionResult~success(projection)

::method validLocation private
  use arg token
  value = token~string~translate
  if value~length < 3 | value~length > 4 then return .false
  return value~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") = 0

::method validNotamNumber private
  use arg token
  value = token~string
  if value~length \= 6 then return .false
  if value~substr(3, 1) \= "/" then return .false
  if value~substr(1, 2)~verify("0123456789") \= 0 then return .false
  if value~substr(4, 3)~verify("0123456789") \= 0 then return .false
  return .true

::method validRunwayDesignator private
  use arg token
  value = token~string~translate
  slash = value~pos("/")
  if slash = 0 then return self~validRunwayEnd(value)
  if value~pos("/", slash + 1) > 0 then return .false
  leftEnd = value~left(slash - 1)
  rightEnd = value~substr(slash + 1)
  return self~validRunwayEnd(leftEnd) & self~validRunwayEnd(rightEnd)

::method validRunwayEnd private
  use arg token
  value = token~string~translate
  if value~length < 1 | value~length > 3 then return .false
  last = value~right(1)
  if last = "L" | last = "R" | last = "C" then digits = value~left(value~length - 1)
  else digits = value
  if digits~length < 1 | digits~length > 2 then return .false
  return digits~verify("0123456789") = 0

::method parseTimeRange private
  use arg token
  value = token~string~translate
  dash = value~pos("-")
  if dash \= 11 then return .nil
  if value~pos("-", dash + 1) > 0 then return .nil
  startToken = value~left(10)
  endPart = value~substr(12)
  if \self~validDateTimeToken(startToken) then return .nil

  qualifier = "EXACT"
  endToken = endPart
  if endPart = "PERM" then do
    qualifier = "PERMANENT"
    endToken = "PERM"
  end
  else do
    if endPart~length = 13 & endPart~right(3) = "EST" then do
      qualifier = "ESTIMATED"
      endToken = endPart~left(10)
    end
    if \self~validDateTimeToken(endToken) then return .nil
  end

  d = .directory~new
  d["START"] = startToken
  d["END"] = endToken
  d["QUALIFIER"] = qualifier
  return d

::method validDateTimeToken private
  use arg token
  value = token~string
  if value~length \= 10 then return .false
  return value~verify("0123456789") = 0


::requires "CivicSwim.cls"
