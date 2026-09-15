/* Multi-user/version/profile preview input. Identity is test context, not authority.
   v0.11 adds explicit CONDITION outcomes for authoring-time simulation. These are
   preview facts only: they do not make the browser authoritative and are never
   substituted for a production fact/decision service. */
::class WireUIPreviewScenario subclass AlchemyObject public
::attribute scenarioId get
::attribute version get
::attribute subjectId get
::attribute authenticated get
::attribute profile get
::attribute journeyState get
::attribute releaseRef get
::attribute contentAddress get
::method init
  expose scenarioId version subjectId authenticated profile journeyState releaseRef experimentAssignments conditionOutcomeMap attributes contentAddress
  use arg scenarioId, version, subjectId, authenticated, profile, journeyState, releaseRef, attributes=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Exact multi-user Wire UI preview/test scenario"))
  scenarioId=scenarioId~string~strip; version=version~string~strip; subjectId=subjectId~string~strip; profile=profile~string~strip~translate; journeyState=journeyState~string~strip
  experimentAssignments=.table~new; conditionOutcomeMap=.table~new; attributes=.WireUIDesignUtil~copyTable(attributes)
  if scenarioId="" | version="" | subjectId="" | profile="" | journeyState="" then raise syntax 93.906 array("preview scenario",scenarioId)
  if \releaseRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("releaseRef")
  contentAddress=""
::method assignExperiment
  expose experimentAssignments contentAddress
  use arg experimentId, variantId
  experimentAssignments[experimentId]=variantId; contentAddress=""; return self
::method assignments
  expose experimentAssignments
  return .WireUIDesignUtil~copyTable(experimentAssignments)
::method setConditionOutcome
  expose conditionOutcomeMap contentAddress
  use arg conditionId, outcome
  conditionId=conditionId~string~strip
  if conditionId="" then raise syntax 93.906 array("conditionId",conditionId)
  normalized=self~normalizeConditionOutcome(outcome)
  if normalized="" then raise syntax 93.914 array("conditionOutcome",outcome)
  conditionOutcomeMap[conditionId]=normalized; contentAddress=""; return self
::method conditionOutcome
  expose conditionOutcomeMap
  use arg conditionId
  conditionId=conditionId~string~strip
  if conditionOutcomeMap~hasIndex(conditionId) then return conditionOutcomeMap[conditionId]
  return "UNKNOWN"
::method conditionOutcomes
  expose conditionOutcomeMap
  return .WireUIDesignUtil~copyTable(conditionOutcomeMap)
::method normalizeConditionOutcome private
  use arg outcome
  if outcome==.true then return "TRUE"
  if outcome==.false then return "FALSE"
  s=outcome~string~strip~translate
  if s="TRUE" | s="FALSE" | s="UNKNOWN" then return s
  return ""
::method seal
  expose contentAddress
  contentAddress=.WireUIDesignUtil~token(self~canonicalText); return self
::method canonicalText
  expose scenarioId version subjectId authenticated profile journeyState releaseRef experimentAssignments conditionOutcomeMap attributes
  return scenarioId"|"version"|"subjectId"|"authenticated"|"profile"|"journeyState"|"releaseRef~canonicalText"|".WireUIDesignUtil~canonicalTable(experimentAssignments)"|".WireUIDesignUtil~canonicalTable(conditionOutcomeMap)"|".WireUIDesignUtil~canonicalTable(attributes)
::method ref
  expose scenarioId version contentAddress
  if contentAddress="" then self~seal
  return .WireUIArtifactRef~new("PREVIEW_SCENARIO",scenarioId,version,contentAddress)
::requires "WireUIDesignSupport.cls"
