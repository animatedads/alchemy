::class BrandInterventionGovernanceBridge public
::method bindEffectiveness
  use arg idArg, source, asOfAt, evidenceAgeDays, temporalAuthorityId="UNSPECIFIED"
  if source==.nil then return .BrandInterventionGovernanceResult~failure("EFFECTIVENESS_SOURCE_REQUIRED")
  b=.BrandInterventionGovernanceEvidenceBinding~new(idArg,source,asOfAt,evidenceAgeDays,temporalAuthorityId)
  r=b~seal
  if \r~ok then return r
  return .BrandInterventionGovernanceResult~success(b)
::method resolvePolicySelection
  use arg catalog, policyId="BRAND-INTERVENTION-GOVERNANCE", atTime=.nil, point=.nil, selectionId=""
  return .BrandInterventionGovernancePolicySelection~fromCatalog(catalog,policyId,atTime,point,selectionId)
::requires "BrandInterventionGovernance.cls"
