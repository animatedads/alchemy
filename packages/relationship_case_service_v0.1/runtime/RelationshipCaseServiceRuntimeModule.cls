/* Runtime Registry lifecycle entry point for Relationship Case Service v0.1. */
::class RelationshipCaseServiceRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops policyCatalog policyId storeRoot sink service
  use arg policyCatalogArg, policyIdArg = .nil, storeRootArg = "", sinkArg = .nil
  starts = 0; quiesces = 0; stops = 0
  policyCatalog = policyCatalogArg; policyId = policyIdArg; storeRoot = storeRootArg~string; sink = sinkArg; service = .nil
::method runtimePrepare
  expose policyCatalog
  use arg context = .nil
  return policyCatalog <> .nil
::method runtimeSelfTest
  expose policyCatalog
  return policyCatalog <> .nil
::method runtimeStart
  expose starts policyCatalog policyId storeRoot sink service
  if policyCatalog == .nil then return .false
  if storeRoot = "" then store = .nil
  else store = .RelationshipCaseServiceStore~new(storeRoot)
  service = .RelationshipCaseService~new(policyCatalog, policyId, store, sink)
  if service~faulted then return .false
  starts += 1
  ignore = service~resume
  return .true
::method runtimeQuiesce
  expose quiesces service
  if service <> .nil then ignore = service~quiesce
  quiesces += 1; return .true
::method runtimeStop
  expose stops service
  if service <> .nil then ignore = service~quiesce
  stops += 1; return .true
::method generationLabel
  return "RELATIONSHIP-CASE-SERVICE-V0.1"
::method apiVersion
  return .RelationshipCaseServiceBuild~API_VERSION
::method packageVersion
  return .RelationshipCaseServiceBuild~VERSION
::method service
  expose service
  return service

::requires "RelationshipCaseServicePersistence.cls"
