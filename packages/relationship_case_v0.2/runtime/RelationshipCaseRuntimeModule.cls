/* Runtime Registry entry point.  This is a module boundary, not yet a network service. */
::class RelationshipCaseRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops policyCatalog repository policyId
  use arg policyCatalogArg, repositoryArg = .nil, policyIdArg = .nil
  starts = 0; quiesces = 0; stops = 0
  policyCatalog = policyCatalogArg
  if repositoryArg == .nil then repository = .RelationshipCaseRepository~new
  else repository = repositoryArg
  policyId = policyIdArg
::method runtimeStart
  expose starts policyCatalog
  if policyCatalog == .nil then return .RelationshipCaseResult~failure("POLICY_CATALOG_REQUIRED")
  starts += 1
  return .RelationshipCaseResult~success(self)
::method runtimeQuiesce
  expose quiesces
  quiesces += 1
  return .RelationshipCaseResult~success(self)
::method runtimeStop
  expose stops
  stops += 1
  return .RelationshipCaseResult~success(self)
::method generationLabel
  return "RELATIONSHIP-CASE-V0.2"
::method apiVersion
  return .RelationshipCaseBuild~API_VERSION
::method newEngine
  expose policyCatalog repository policyId
  return .RelationshipCaseEngine~new(policyCatalog, policyId, repository)
::requires "RelationshipCase.cls"
