/* Renderer-correlated structural evidence: exact semantic meaning -> exact rendered instance. */
::class WireUIRenderElementObservation subclass AlchemyObject public
::attribute renderInstanceId get
::attribute semanticRef get
::attribute semanticInstanceId get
::attribute projectionRef get
::attribute componentRef get
::attribute contentAddress get
::method init
  expose renderInstanceId semanticRef semanticInstanceId projectionRef componentRef materialRef bounds visible clipped enabled focused role accessibleName diagnostics contentAddress
  use arg renderInstanceId, semanticRef, semanticInstanceId, projectionRef, componentRef, materialRef=.nil, bounds=.nil, visible=.true, clipped=.false, enabled=.true, focused=.false, role="", accessibleName="", diagnostics=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Exact rendered Wire UI element observation"))
  renderInstanceId=renderInstanceId~string~strip; semanticInstanceId=semanticInstanceId~string~strip; role=role~string; accessibleName=accessibleName~string
  if renderInstanceId="" | semanticInstanceId="" then raise syntax 93.906 array("render observation instance",renderInstanceId)
  if \semanticRef~isA(.WireUIArtifactRef) | \projectionRef~isA(.WireUIArtifactRef) | \componentRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("render observation refs")
  if materialRef<>.nil then if \materialRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("materialRef")
  bounds=.WireUIDesignUtil~copyTable(bounds); diagnostics=.WireUIDesignUtil~copyArray(diagnostics)
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText)
::method canonicalText
  expose renderInstanceId semanticRef semanticInstanceId projectionRef componentRef materialRef bounds visible clipped enabled focused role accessibleName diagnostics
  mr=""; if materialRef<>.nil then mr=materialRef~canonicalText
  return renderInstanceId"|"semanticRef~canonicalText"|"semanticInstanceId"|"projectionRef~canonicalText"|"componentRef~canonicalText"|"mr"|".WireUIDesignUtil~canonicalTable(bounds)"|"visible"|"clipped"|"enabled"|"focused"|"role"|"accessibleName"|".WireUIDesignUtil~canonicalArray(diagnostics)
::method asWire
  expose renderInstanceId semanticRef semanticInstanceId projectionRef componentRef materialRef bounds visible clipped enabled focused role accessibleName diagnostics contentAddress
  d=.table~new; d["renderInstanceId"]=renderInstanceId; d["semanticRef"]=semanticRef~asWire; d["semanticInstanceId"]=semanticInstanceId; d["projectionRef"]=projectionRef~asWire; d["componentRef"]=componentRef~asWire
  if materialRef==.nil then d["materialRef"]=.nil; else d["materialRef"]=materialRef~asWire
  d["bounds"]=.WireUIDesignUtil~copyTable(bounds); d["visible"]=visible; d["clipped"]=clipped; d["enabled"]=enabled; d["focused"]=focused; d["role"]=role; d["accessibleName"]=accessibleName; d["diagnostics"]=.WireUIDesignUtil~copyArray(diagnostics); d["contentAddress"]=contentAddress; return d

::class WireUIRenderObservation subclass AlchemyObject public
::attribute observationId get
::attribute version get
::attribute releaseRef get
::attribute scenarioRef get
::attribute rendererRef get
::attribute manifestContentAddress get
::attribute contentAddress get
::method init
  expose observationId version releaseRef scenarioRef rendererRef manifestContentAddress viewport elements sealed contentAddress
  use arg observationId, version, releaseRef, scenarioRef, rendererRef, manifestContentAddress, viewport=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Renderer/version-correlated Wire UI structural observation"))
  observationId=observationId~string~strip; version=version~string~strip; manifestContentAddress=manifestContentAddress~string~strip
  if observationId="" | version="" | manifestContentAddress="" then raise syntax 93.906 array("render observation",observationId)
  if \releaseRef~isA(.WireUIArtifactRef) | \scenarioRef~isA(.WireUIArtifactRef) | \rendererRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("render observation refs")
  if releaseRef~contentAddress="" | scenarioRef~contentAddress="" | rendererRef~contentAddress="" then raise syntax 93.906 array("render observation unsealed ref",observationId)
  viewport=.WireUIDesignUtil~copyTable(viewport); elements=.array~new; sealed=.false; contentAddress=""
  self~registerStateVariable("releaseRef","PUBLIC","exact site release rendered")
  self~registerStateVariable("scenarioRef","PUBLIC","exact preview subject/scenario rendered")
  self~registerStateVariable("rendererRef","PUBLIC","exact renderer implementation/build observed")
::method addElement
  expose elements sealed contentAddress
  use arg element
  if sealed then return .WireUIDesignResult~failure("RENDER_OBSERVATION_SEALED")
  if \element~isA(.WireUIRenderElementObservation) then return .WireUIDesignResult~failure("INVALID_RENDER_ELEMENT_OBSERVATION")
  elements~append(element); contentAddress=""; return .WireUIDesignResult~success(element)
::method elements
  expose elements
  return .WireUIDesignUtil~copyArray(elements)
::method seal
  expose contentAddress sealed
  contentAddress=.WireUIDesignUtil~strongToken(self~canonicalText); sealed=.true; return .WireUIDesignResult~success(self)
::method canonicalText
  expose observationId version releaseRef scenarioRef rendererRef manifestContentAddress viewport elements
  text=observationId"|"version"|"releaseRef~canonicalText"|"scenarioRef~canonicalText"|"rendererRef~canonicalText"|"manifestContentAddress"|".WireUIDesignUtil~canonicalTable(viewport)
  do e over elements; text ||= "|"e~canonicalText; end
  return text
::method ref
  expose observationId version contentAddress
  if contentAddress="" then return .nil
  return .WireUIArtifactRef~new("RENDER_OBSERVATION",observationId,version,contentAddress)
::method asWire
  expose observationId version releaseRef scenarioRef rendererRef manifestContentAddress viewport elements contentAddress
  d=.table~new; d["observationId"]=observationId; d["version"]=version; d["releaseRef"]=releaseRef~asWire; d["scenarioRef"]=scenarioRef~asWire; d["rendererRef"]=rendererRef~asWire; d["manifestContentAddress"]=manifestContentAddress; d["viewport"]=.WireUIDesignUtil~copyTable(viewport)
  a=.array~new; do e over elements; a~append(e~asWire); end; d["elements"]=a; d["contentAddress"]=contentAddress; return d
::requires "WireUIDesignSupport.cls"
