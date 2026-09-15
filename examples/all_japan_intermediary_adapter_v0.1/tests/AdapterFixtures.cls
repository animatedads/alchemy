::class AJIIntermediaryAdapterFixtures public
::method now class
  return .DateTime~fromIsoDate("2026-08-28T12:00:00.000000")
::method contractBook class
  payout=.AllJapanInsuranceClaimPayoutRule~new("AJI-HOME-IOM-PAYOUT/1","ASSESSED_COVERED_LOSS_MINOR",0,.AllJapanInsuranceRationalRate~new(1,1,"100%"),.false,0,"AJI.PAYOUT.DEDUCT_RATE_CAP/1")
  version=.AllJapanInsuranceContractVersion~new("AJI-CONTRACT-HOME-IOM/1","HOME","IOM","2026-01-01","","AJI-HOME-WORDING/1",payout,"","2025-12-01T00:00:00","AJI-PRODUCT-GOVERNANCE","")
  book=.AllJapanInsuranceContractBook~new
  r=book~addVersion(version)
  if \r~ok then raise syntax 88.900 array("contract book fixture failed "||r~code)
  return book
::method authority class
  return .AllJapanInsuranceAuthority~new(.nil,self~contractBook)
::method distributionService class
  svc=.RIDServiceFixtures~service
  semantic=.AllJapanInsuranceCatalogue~new~product("HOME")~semanticIdentity
  .RIDServiceFixtures~env(svc,"INSURANCE","ADVISED",semantic,.AllJapanIntermediaryAdapterBuild~PROVIDER_LEGAL_ENTITY,.AllJapanIntermediaryAdapterBuild~PROVIDER_SYSTEM,"HOME","0.1")
  return svc
::method readyCase class
  use arg svc, caseId="CASE-AJI"
  .RIDServiceFixtures~readyInsuranceSubmission(svc,caseId)
  return svc~integrationCase(caseId)
::method underwriter class
  return .AllJapanInsuranceActor~new("AJI-UW-1",.array~of(.AllJapanInsuranceBuild~ROLE_UNDERWRITER,.AllJapanInsuranceBuild~ROLE_RATE_OVERRIDE))
::method policyActor class
  return .AllJapanInsuranceActor~new("AJI-POLICY-1",.array~of(.AllJapanInsuranceBuild~ROLE_POLICY))
::requires "AllJapanIntermediaryAdapter.cls"
::requires "ServiceFixtures.cls"
::requires "AllJapanInsuranceRating.cls"
::requires "AllJapanInsuranceContract.cls"
