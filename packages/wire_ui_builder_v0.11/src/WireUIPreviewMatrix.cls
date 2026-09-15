/* Exact multi-user preview matrix over one immutable compiled release. */
::class WireUIPreviewMatrix subclass AlchemyObject public
::attribute matrixId get
::attribute version get
::attribute releaseRef get
::attribute contentAddress get
::method init
  expose matrixId version releaseRef scenarios sealed contentAddress
  use arg matrixId, version, releaseRef
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned multi-user Wire UI preview matrix"))
  matrixId=matrixId~string~strip; version=version~string~strip; scenarios=.table~new; sealed=.false; contentAddress=""
  if matrixId="" | version="" | \releaseRef~isA(.WireUIArtifactRef) then raise syntax 93.906 array("preview matrix",matrixId)
::method addScenario
  expose releaseRef scenarios sealed contentAddress
  use arg scenario
  if sealed then return .WireUIDesignResult~failure("PREVIEW_MATRIX_SEALED")
  if \scenario~isA(.WireUIPreviewScenario) then return .WireUIDesignResult~failure("INVALID_PREVIEW_SCENARIO")
  if scenario~releaseRef~contentAddress \= releaseRef~contentAddress then return .WireUIDesignResult~failure("PREVIEW_MATRIX_RELEASE_MISMATCH",scenario~scenarioId)
  key=scenario~scenarioId"@"scenario~version
  if scenarios~hasIndex(key) then do
    prior=scenarios[key]; if prior~ref~contentAddress \= scenario~ref~contentAddress then return .WireUIDesignResult~failure("PREVIEW_SCENARIO_CONFLICT",key)
    return .WireUIDesignResult~success(prior,"ALREADY_ADDED")
  end
  scenarios[key]=scenario; contentAddress=""; return .WireUIDesignResult~success(scenario)
::method scenarios
  expose scenarios
  a=.array~new; keys=scenarios~allIndexes; keys~sort; do k over keys; a~append(scenarios[k]); end; return a
::method seal
  expose scenarios sealed contentAddress
  if scenarios~items=0 then return .WireUIDesignResult~failure("EMPTY_PREVIEW_MATRIX")
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText); sealed=.true; return .WireUIDesignResult~success(self)
::method execute
  expose sealed
  use arg compiler, workspace, compiledPackage
  if \sealed then return .WireUIDesignResult~failure("PREVIEW_MATRIX_NOT_SEALED")
  out=.table~new
  do scenario over self~scenarios
    r=compiler~previewManifest(workspace,compiledPackage,scenario)
    if \r~ok then return .WireUIDesignResult~failure("PREVIEW_MATRIX_SCENARIO_FAILED",scenario~scenarioId"|"r~code)
    out[scenario~scenarioId]=r~value
  end
  return .WireUIDesignResult~success(out,"PREVIEW_MATRIX_COMPLETE")
::method canonicalText
  expose matrixId version releaseRef scenarios
  text=matrixId"|"version"|"releaseRef~canonicalText
  keys=scenarios~allIndexes; keys~sort; do k over keys; text ||= "|"scenarios[k]~ref~canonicalText; end
  return text
::method ref
  expose matrixId version contentAddress
  if contentAddress="" then return .nil
  return .WireUIArtifactRef~new("PREVIEW_MATRIX",matrixId,version,contentAddress)
::requires "WireUIPreviewScenario.cls"
