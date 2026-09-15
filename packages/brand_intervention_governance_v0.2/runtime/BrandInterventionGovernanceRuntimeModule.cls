::class BrandInterventionGovernanceRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops
  starts=0; quiesces=0; stops=0
::method runtimeStart
  expose starts; starts+=1; return .true
::method runtimeQuiesce
  expose quiesces; quiesces+=1; return .true
::method runtimeStop
  expose stops; stops+=1; return .true
::method generationLabel
  return "BRAND-INTERVENTION-GOVERNANCE-V0.2"
::method apiVersion
  return .BrandInterventionGovernanceBuild~API_VERSION
::method newEngine
  return .BrandInterventionGovernanceEngine~new
::method newLibrary
  return .BrandInterventionGovernanceLibrary~new
::method newBridge
  return .BrandInterventionGovernanceBridge~new
::method newRuleSet
  r=.BrandInterventionGovernanceRuleSet~new; r~seal; return r
::method resolvePolicySelection
  use arg catalog, policyId="BRAND-INTERVENTION-GOVERNANCE", atTime=.nil, point=.nil, selectionId=""
  return .BrandInterventionGovernancePolicySelection~fromCatalog(catalog,policyId,atTime,point,selectionId)
::requires "BrandInterventionGovernance.cls"
::requires "BrandInterventionGovernanceBridge.cls"
