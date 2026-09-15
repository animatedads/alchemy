/*
 * All Japan / Regulated Intermediary Adapter v0.1
 *
 * Narrow provider adapter between Federation Regulated Intermediary
 * Distribution and All Japan Insurance.  Distribution may submit an exact
 * application; underwriting, rating, policy and claim authority stay in AJI.
 */
::class AllJapanIntermediaryAdapterBuild public
::constant VERSION "0.1"
::constant API_VERSION "all.japan.intermediary.adapter/0.1"
::constant PROVIDER_LEGAL_ENTITY "ALL_JAPAN_INSURANCE_CO_LTD"
::constant PROVIDER_SYSTEM "ALL_JAPAN_POLICY_ADMIN"
::constant DISTRIBUTION_PRINCIPAL "FEDERATION_INTERMEDIARY_DISTRIBUTION"

::class AllJapanIntermediaryAdapterResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg; code = codeArg~string; detail = detailArg~string; value = valueArg
::method success class
  use arg valueArg = .nil, detailArg = ""
  return self~new(.true,"OK",detailArg,valueArg)
::method failure class
  use arg codeArg, detailArg = "", valueArg = .nil
  return self~new(.false,codeArg,detailArg,valueArg)

::class AllJapanIntermediaryAdapter public
::method init
  expose distributionActor
  distributionActor = .AllJapanInsuranceActor~new(.AllJapanIntermediaryAdapterBuild~DISTRIBUTION_PRINCIPAL, .array~of(.AllJapanInsuranceBuild~ROLE_DISTRIBUTION))
::method distributionActor
  expose distributionActor
  return distributionActor
::method validateCase private
  use arg distributionService, caseId, expectedState = ""
  if distributionService == .nil then return .AllJapanIntermediaryAdapterResult~failure("DISTRIBUTION_SERVICE_REQUIRED")
  c = distributionService~integrationCase(caseId)
  if c == .nil then return .AllJapanIntermediaryAdapterResult~failure("UNKNOWN_DISTRIBUTION_CASE")
  p = distributionService~integrationProduct(c~productRefId)
  if p == .nil then return .AllJapanIntermediaryAdapterResult~failure("UNKNOWN_DISTRIBUTION_PRODUCT")
  if p~productFamily <> "INSURANCE" then return .AllJapanIntermediaryAdapterResult~failure("NOT_INSURANCE_PRODUCT")
  if p~providerIdentity~legalEntityId <> .AllJapanIntermediaryAdapterBuild~PROVIDER_LEGAL_ENTITY then return .AllJapanIntermediaryAdapterResult~failure("PROVIDER_IDENTITY_MISMATCH",p~providerIdentity~legalEntityId)
  if p~providerIdentity~providerSystem <> .AllJapanIntermediaryAdapterBuild~PROVIDER_SYSTEM then return .AllJapanIntermediaryAdapterResult~failure("PROVIDER_SYSTEM_MISMATCH",p~providerIdentity~providerSystem)
  if expectedState <> "" then if c~state <> expectedState then return .AllJapanIntermediaryAdapterResult~failure("DISTRIBUTION_STATE_INVALID",c~state)
  out=.table~new; out["case"]=c; out["product"]=p
  return .AllJapanIntermediaryAdapterResult~success(out)
::method verifyProviderProduct private
  use arg providerAuthority, ridProduct
  if providerAuthority == .nil then return .AllJapanIntermediaryAdapterResult~failure("INSURER_AUTHORITY_REQUIRED")
  ajp = providerAuthority~catalogue~product(ridProduct~productId)
  if ajp == .nil then return .AllJapanIntermediaryAdapterResult~failure("AJI_PRODUCT_NOT_FOUND",ridProduct~productId)
  if ajp~semanticIdentity <> ridProduct~productSemanticIdentity then return .AllJapanIntermediaryAdapterResult~failure("PRODUCT_SEMANTIC_IDENTITY_MISMATCH")
  return .AllJapanIntermediaryAdapterResult~success(ajp)
::method recordStatus private
  use arg distributionService, caseId, eventId, providerCaseRef, productSemanticIdentity, sequence, status, occurredAt, sourceRef
  p=.directory~new
  p["caseId"]=caseId; p["eventId"]=eventId; p["providerEntityId"]=.AllJapanIntermediaryAdapterBuild~PROVIDER_LEGAL_ENTITY; p["providerSystem"]=.AllJapanIntermediaryAdapterBuild~PROVIDER_SYSTEM; p["providerCaseRef"]=providerCaseRef; p["productSemanticIdentity"]=productSemanticIdentity; p["sequence"]=sequence; p["status"]=status; p["occurredAt"]=occurredAt~string; p["sourceRef"]=sourceRef
  env=.RIDServiceEnvelope~new("AJI-RID-" || eventId,"DISTRIBUTION.PROVIDER.STATUS_RECORD","AJI-PROVIDER-ADAPTER","SYSTEM",p,caseId,"",occurredAt)
  r=distributionService~handle(env)
  if \r~ok then return .AllJapanIntermediaryAdapterResult~failure(r~code,r~detail,r)
  return .AllJapanIntermediaryAdapterResult~success(r~value)
::method submitRisk
  expose distributionActor
  use arg distributionService, providerAuthority, caseId, submissionId, riskRef, facts = .nil, submittedAt = .nil
  if submittedAt == .nil then submittedAt=.DateTime~new
  vr=self~validateCase(distributionService,caseId,"SUBMISSION_REQUESTED"); if \vr~ok then return vr
  c=vr~value["case"]; rp=vr~value["product"]
  pr=self~verifyProviderProduct(providerAuthority,rp); if \pr~ok then return pr
  if riskRef == .nil | riskRef~string = "" then return .AllJapanIntermediaryAdapterResult~failure("RISK_REFERENCE_REQUIRED")
  submission=.AllJapanInsuranceRiskSubmission~new(submissionId,rp~productId,c~subjectRef,riskRef,c~jurisdiction,submittedAt~string,facts)
  sr=providerAuthority~submitRisk(distributionActor,submission)
  if \sr~ok then return .AllJapanIntermediaryAdapterResult~failure(sr~code,sr~detail,sr)
  status=self~recordStatus(distributionService,c~caseId,"AJI-SUBMIT-"||submissionId,submissionId,c~productSemanticIdentity,1,"RECEIVED",submittedAt,"AJI:SUBMISSION:"||submissionId)
  if \status~ok then return status
  out=.table~new; out["submission"]=submission; out["distributionCase"]=status~value
  return .AllJapanIntermediaryAdapterResult~success(out)
::method projectUnderwritingDecision
  use arg distributionService, providerAuthority, caseId, decisionId, sequence = 2, occurredAt = .nil
  if occurredAt == .nil then occurredAt=.DateTime~new
  vr=self~validateCase(distributionService,caseId); if \vr~ok then return vr
  c=vr~value["case"]; rp=vr~value["product"]
  pr=self~verifyProviderProduct(providerAuthority,rp); if \pr~ok then return pr
  d=providerAuthority~decision(decisionId)
  if d == .nil then return .AllJapanIntermediaryAdapterResult~failure("AJI_DECISION_NOT_FOUND",decisionId)
  if d~productCode <> rp~productId then return .AllJapanIntermediaryAdapterResult~failure("AJI_DECISION_PRODUCT_MISMATCH")
  if c~providerCaseRef <> "" then if d~submissionId <> c~providerCaseRef then return .AllJapanIntermediaryAdapterResult~failure("AJI_DECISION_CASE_MISMATCH")
  select
    when d~outcome = .AllJapanInsuranceBuild~DECISION_ACCEPT then status="APPROVED"
    when d~outcome = .AllJapanInsuranceBuild~DECISION_DECLINE then status="DECLINED"
    when d~outcome = .AllJapanInsuranceBuild~DECISION_REFER then status="UNDERWRITING"
    otherwise return .AllJapanIntermediaryAdapterResult~failure("AJI_DECISION_OUTCOME_INVALID",d~outcome)
  end
  return self~recordStatus(distributionService,c~caseId,"AJI-DECISION-"||d~decisionId,d~submissionId,c~productSemanticIdentity,sequence,status,occurredAt,"AJI:DECISION:"||d~decisionId)
::method projectQuote
  use arg distributionService, providerAuthority, caseId, quoteId, sequence = 3, occurredAt = .nil
  if occurredAt == .nil then occurredAt=.DateTime~new
  vr=self~validateCase(distributionService,caseId); if \vr~ok then return vr
  c=vr~value["case"]; rp=vr~value["product"]
  q=providerAuthority~quote(quoteId)
  if q == .nil then return .AllJapanIntermediaryAdapterResult~failure("AJI_QUOTE_NOT_FOUND",quoteId)
  if q~productCode <> rp~productId then return .AllJapanIntermediaryAdapterResult~failure("AJI_QUOTE_PRODUCT_MISMATCH")
  if c~providerCaseRef <> "" then if q~submissionId <> c~providerCaseRef then return .AllJapanIntermediaryAdapterResult~failure("AJI_QUOTE_CASE_MISMATCH")
  return self~recordStatus(distributionService,c~caseId,"AJI-QUOTE-"||q~quoteId,q~submissionId,c~productSemanticIdentity,sequence,"OFFERED",occurredAt,"AJI:QUOTE:"||q~quoteId)
::method projectBoundPolicy
  use arg distributionService, providerAuthority, caseId, policyId, sequence = 4, occurredAt = .nil
  if occurredAt == .nil then occurredAt=.DateTime~new
  vr=self~validateCase(distributionService,caseId); if \vr~ok then return vr
  c=vr~value["case"]; rp=vr~value["product"]
  pol=providerAuthority~policy(policyId)
  if pol == .nil then return .AllJapanIntermediaryAdapterResult~failure("AJI_POLICY_NOT_FOUND",policyId)
  if pol~productCode <> rp~productId then return .AllJapanIntermediaryAdapterResult~failure("AJI_POLICY_PRODUCT_MISMATCH")
  sub=providerAuthority~submission(c~providerCaseRef)
  if sub == .nil then return .AllJapanIntermediaryAdapterResult~failure("AJI_SUBMISSION_NOT_FOUND",c~providerCaseRef)
  if pol~partyRef <> sub~partyRef | pol~riskRef <> sub~riskRef then return .AllJapanIntermediaryAdapterResult~failure("AJI_POLICY_RISK_MISMATCH")
  return self~recordStatus(distributionService,c~caseId,"AJI-POLICY-"||pol~policyId,c~providerCaseRef,c~productSemanticIdentity,sequence,"BOUND",occurredAt,"AJI:POLICY:"||pol~policyId)

::requires "RegulatedIntermediaryDistributionService.cls"
::requires "AllJapanInsurance.cls"
