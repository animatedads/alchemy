::class RIDTestFixtures public
::method environment class
  use arg family = "MORTGAGE", adviceMode = "ADVISED", providerEntity = "FEDERATIONBANK_PLC", providerSystem = "FEDERATION_MORTGAGE", productId = "HOME-1", productVersion = "2026.08", semanticIdentity = "HOME-1|2026.08|A"
  now = .DateTime~new
  ir = .RIDIntermediaryRegistry~new
  ar = .RIDAuthorityRegistry~new
  cat = .RIDDistributionCatalog~new
  policy = .FederationBankIntermediaryPolicyFixtures~standardPolicy
  .RIDTestSupport~ok(ir~registerFirm(.RIDIntermediaryFirm~new("FIRM-1", "LEGAL:FIRM-1", "REG:FIRM-1")))
  .RIDTestSupport~ok(ir~registerRepresentative(.RIDIntermediaryRepresentative~new("REP-1", "FIRM-1", "PERSON:REP-1")))
  provider = .RIDProviderIdentity~new(providerEntity, providerSystem, "FEDERATION_GROUP", "PROVIDER:EVIDENCE:1")
  p = .RIDProductReference~new("PROD-1", provider, productId, productVersion, semanticIdentity, family, "GB", family || "_PRODUCT", "PRODUCT:EVIDENCE:1")
  .RIDTestSupport~ok(cat~addProduct(p))
  a = .RIDProductDistributionApproval~new("APPROVAL-1", p~productRefId, p~productSemanticIdentity, now - .TimeSpan~new(0,0,0,0,60), .nil, "FEDERATION-PRODUCT-GOVERNANCE", "1", "POLICY|1", "APPROVAL:EVIDENCE:1")
  do activity over .array~of("INTRODUCE", "ADVISE", "ARRANGE")
    a~allowActivity(activity)
  end
  a~allowAdviceMode(adviceMode)
  .RIDTestSupport~ok(cat~approveProduct(a))
  engine = .RIDDistributionEngine~new(ir, ar, cat, policy)
  d = .directory~new
  d["NOW"] = now; d["INTERMEDIARIES"] = ir; d["AUTHORITIES"] = ar; d["CATALOG"] = cat; d["POLICY"] = policy; d["ENGINE"] = engine; d["PRODUCT"] = p
  return d
::method grantStandard class
  use arg env, family, activity
  now = env["NOW"]
  ar = env["AUTHORITIES"]
  before = now - .TimeSpan~new(0,0,0,0,60)
  id = family || "-" || activity
  .RIDTestSupport~ok(ar~addGrant(.RIDAuthorityGrant~new("G-REG-" || id, "REGULATORY_PERMISSION", "FIRM", "FIRM-1", "FIRM-1", "GB", family, activity, before, .nil, "REGULATOR", "REG:" || id)))
  .RIDTestSupport~ok(ar~addGrant(.RIDAuthorityGrant~new("G-APT-" || id, "FEDERATION_APPOINTMENT", "FIRM", "FIRM-1", "FIRM-1", "GB", family, activity, before, .nil, "FEDERATION_DISTRIBUTION_GOVERNANCE", "APT:" || id)))
  .RIDTestSupport~ok(ar~addGrant(.RIDAuthorityGrant~new("G-CMP-" || id, "REPRESENTATIVE_COMPETENCE", "REPRESENTATIVE", "REP-1", "FIRM-1", "GB", family, activity, before, .nil, "FIRM_COMPETENCE", "CMP:" || id)))
  return env
::method addEvidence class
  use arg env, caseId, evidenceType, id
  p = env["PRODUCT"]
  e = .RIDEvidenceReference~new(id, evidenceType, evidenceType, "EVIDENCE_SYSTEM", "REF:" || id, "EVIDENCE", env["NOW"], "INTERNAL", p~productSemanticIdentity)
  return .RIDTestSupport~ok(env["ENGINE"]~attachEvidence(caseId, e, "REP-1", "INTERMEDIARY_REPRESENTATIVE"))

::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
