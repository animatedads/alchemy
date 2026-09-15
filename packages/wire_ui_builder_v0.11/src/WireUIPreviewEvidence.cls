/* Browser-produced evidence that lets a human/AI inspect what was actually rendered. */
::class WireUIPreviewEvidence subclass AlchemyObject public
::attribute evidenceId get
::attribute version get
::attribute releaseRef get
::attribute scenarioRef get
::attribute manifestContentAddress get
::attribute screenshotContentAddress get
::attribute semanticCaptureContentAddress get
::attribute contentAddress get
::method init
  expose evidenceId version releaseRef scenarioRef manifestContentAddress screenshotContentAddress semanticCaptureContentAddress viewport elementGeometry materialObservation contentAddress
  use arg evidenceId, version, releaseRef, scenarioRef, manifestContentAddress, screenshotContentAddress, semanticCaptureContentAddress, viewport=.nil, elementGeometry=.nil, materialObservation=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Rendered preview evidence bound to exact Wire UI release and scenario"))
  evidenceId=evidenceId~string~strip; version=version~string~strip
  manifestContentAddress=manifestContentAddress~string~strip; screenshotContentAddress=screenshotContentAddress~string~strip; semanticCaptureContentAddress=semanticCaptureContentAddress~string~strip
  if evidenceId="" | version="" | manifestContentAddress="" | screenshotContentAddress="" | semanticCaptureContentAddress="" then raise syntax 93.906 array("preview evidence",evidenceId)
  if \releaseRef~isA(.WireUIArtifactRef) | \scenarioRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("preview evidence refs")
  viewport=.WireUIDesignUtil~copyTable(viewport); elementGeometry=.WireUIDesignUtil~copyTable(elementGeometry); materialObservation=.WireUIDesignUtil~copyTable(materialObservation)
  contentAddress=.WireUIDesignUtil~token(self~canonicalText)
  self~registerStateVariable("releaseRef","PUBLIC","exact site release observed by renderer")
  self~registerStateVariable("scenarioRef","PUBLIC","exact multi-user preview scenario observed by renderer")
  self~registerStateVariable("screenshotContentAddress","PUBLIC","content address of rendered raster capture")
::method canonicalText
  expose evidenceId version releaseRef scenarioRef manifestContentAddress screenshotContentAddress semanticCaptureContentAddress viewport elementGeometry materialObservation
  return evidenceId"|"version"|"releaseRef~canonicalText"|"scenarioRef~canonicalText"|"manifestContentAddress"|"screenshotContentAddress"|"semanticCaptureContentAddress"|".WireUIDesignUtil~canonicalTable(viewport)"|".WireUIDesignUtil~canonicalTable(elementGeometry)"|".WireUIDesignUtil~canonicalTable(materialObservation)
::method verifyBinding
  expose releaseRef scenarioRef manifestContentAddress
  use arg compiledPackage, scenario, previewManifest
  if releaseRef~contentAddress \= compiledPackage~releaseRef~contentAddress then return .WireUIDesignResult~failure("EVIDENCE_RELEASE_MISMATCH")
  if scenarioRef~contentAddress \= scenario~ref~contentAddress then return .WireUIDesignResult~failure("EVIDENCE_SCENARIO_MISMATCH")
  if \previewManifest~hasIndex("manifestContentAddress") then return .WireUIDesignResult~failure("EVIDENCE_MANIFEST_ADDRESS_MISSING")
  if manifestContentAddress \= previewManifest["manifestContentAddress"] then return .WireUIDesignResult~failure("EVIDENCE_MANIFEST_MISMATCH")
  return .WireUIDesignResult~success(self,"EVIDENCE_BOUND")
::method ref
  expose evidenceId version contentAddress
  return .WireUIArtifactRef~new("PREVIEW_EVIDENCE",evidenceId,version,contentAddress)
::method asWire
  expose evidenceId version releaseRef scenarioRef manifestContentAddress screenshotContentAddress semanticCaptureContentAddress viewport elementGeometry materialObservation contentAddress
  d=.table~new; d["evidenceId"]=evidenceId; d["version"]=version; d["releaseRef"]=releaseRef~asWire; d["scenarioRef"]=scenarioRef~asWire; d["manifestContentAddress"]=manifestContentAddress; d["screenshotContentAddress"]=screenshotContentAddress; d["semanticCaptureContentAddress"]=semanticCaptureContentAddress; d["viewport"]=.WireUIDesignUtil~copyTable(viewport); d["elementGeometry"]=.WireUIDesignUtil~copyTable(elementGeometry); d["materialObservation"]=.WireUIDesignUtil~copyTable(materialObservation); d["contentAddress"]=contentAddress
  return d
::requires "WireUIPreviewScenario.cls"
