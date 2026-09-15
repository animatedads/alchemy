say "LEGAL EFFECT V0.14 COMPILER SEMANTIC KINDS START"
a = .CompilerKindsAcceptance~new
exit a~run

::class CompilerKindsAcceptance
::method init
  expose assertions
  assertions = 0

::method addSourceWithProvisions private
  use arg unit, sourceId, sourceKind, expressionId, provisionIds
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "compiler-kinds-verifier")
  sourceText = sourceId || " source"
  do provisionId over provisionIds
    sourceText ||= '0a'x || sourceId || " provision " || provisionId
  end
  sourceDoc = .directory~new
  sourceDoc["content"] = sourceText
  identity = .LegalSourceIdentity~new(sourceId, sourceKind, expressionId, "urn:test:" || sourceId, "sha512:" || provider~digest(sourceText), "AUTH", "TEST-LAND", "VERIFIED")
  source = .NormativeSource~new(sourceId, sourceKind, sourceId, "AUTH", "TEST-LAND")
  ignored = unit~addSource(identity, source)
  ignored = unit~verifySource(sourceId, .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:" || sourceId, "RAW_NORMATIVE_SOURCE"), verifier)
  do provisionId over provisionIds
    text = sourceId || " provision " || provisionId
    reference = .LegalProvisionReference~new(sourceId, provisionId, expressionId, "p." || provisionId, "sha512:" || provider~digest(text), text, "VERIFIED")
    provision = .LegalProvision~new(sourceId, provisionId, "ACTIVE", "BASE", text)
    ignored = unit~addProvision(reference, provision)
    ignored = unit~verifyProvision(sourceId, provisionId, .LegalVerificationMaterial~fromText(sourceDoc, text, "p." || provisionId, "PROVISION_LEXICAL_TEXT"), verifier)
  end
  return source

::method buildGood private
  unit = .LegalCompilationUnit~new("KINDS-G1", "1", "compiler-kinds", "1")
  act = self~addSourceWithProvisions(unit, "ACT", "LEGISLATION", "act-expr", .array~of("2", "3", "11"))
  contract = self~addSourceWithProvisions(unit, "CONTRACT", "CONTRACT", "contract-expr", .array~of("7"))

  actNorm = .LegalNorm~new("ACT-N", "ACT", "11", "PROHIBITION", "ACTION-Z", "PROHIBITED", "TEST", "act norm", .nil, "BASE", "Z-CONFLICT")
  actProposal = .LegalCompileProposal~new("P-ACT-N", "NORM", actNorm, "extractor-a", "LLM")
  ignored = actProposal~addEvidenceReference(unit~provisionReference("ACT", "11"))
  ignored = unit~addProposal(actProposal)

  contractNorm = .LegalNorm~new("CT-N", "CONTRACT", "7", "CONTRACT_TERM", "ACTION-Z", "PERMITTED", "TEST", "contract norm", .nil, "BASE", "Z-CONFLICT")
  contractProposal = .LegalCompileProposal~new("P-CT-N", "NORM", contractNorm, "parser-a", "DETERMINISTIC")
  ignored = contractProposal~addEvidenceReference(unit~provisionReference("CONTRACT", "7"))
  ignored = unit~addProposal(contractProposal)

  modification = .LegalModificationEffect~new("MOD-11", "ACT", "2", "SUBSTITUTE", "ACT", "11", .nil, 10, "V2", "replacement")
  modProposal = .LegalCompileProposal~new("P-MOD-11", "MODIFICATION", modification, "extractor-a", "LLM")
  ignored = modProposal~addEvidenceReference(unit~provisionReference("ACT", "2"))
  ignored = unit~addProposal(modProposal)

  authority = .LegalAuthorityRule~new("AUTH-3", "ACT", "3", "ACT", "CONTRACT", "NON_DEROGATION", "TEST", "ACTION-Z", .nil, "ACT-N", "CT-N", "synthetic precedence")
  authProposal = .LegalCompileProposal~new("P-AUTH-3", "AUTHORITY_RULE", authority, "review-tool", "DETERMINISTIC")
  ignored = authProposal~addEvidenceReference(unit~provisionReference("ACT", "3"))
  ignored = unit~addProposal(authProposal)
  return unit

::method run
  expose assertions
  compiler = .LegalRuleCompiler~new
  report = compiler~compile(self~buildGood)
  ok = self~assertTrue(report~ok, "norm/modification/authority graph compiles")
  generation = report~generation
  ok = self~assertEqual(2, generation~normCount, "two norms compiled")
  ok = self~assertEqual(1, generation~modificationCount, "modification compiled")
  ok = self~assertEqual(1, generation~authorityRuleCount, "authority relation compiled")
  modifications = generation~modifications
  authorities = generation~authorityRules
  ok = self~assertEqual(1, modifications[1]~evidence~items, "modification exact source evidence attached")
  ok = self~assertEqual("ACT", modifications[1]~evidence[1]~sourceId, "modification evidence source retained")
  ok = self~assertEqual(1, authorities[1]~evidence~items, "authority exact source evidence attached")
  ok = self~assertEqual("3", authorities[1]~authorityProvisionId, "authority provision selector retained")

  badAuthorityUnit = self~buildGood
  badAuthority = .LegalAuthorityRule~new("AUTH-BAD", "ACT", "3", "ACT", "CONTRACT", "PREVAILS_OVER", "TEST", "ACTION-Z", .nil, "MISSING-NORM", "CT-N", "bad selector")
  badAuthorityProposal = .LegalCompileProposal~new("P-AUTH-BAD", "AUTHORITY_RULE", badAuthority, "extractor", "LLM")
  ignored = badAuthorityProposal~addEvidenceReference(badAuthorityUnit~provisionReference("ACT", "3"))
  ignored = badAuthorityUnit~addProposal(badAuthorityProposal)
  badAuthorityReport = compiler~compile(badAuthorityUnit)
  ok = self~assertTrue(\badAuthorityReport~ok, "authority selector cannot reference absent norm")
  ok = self~assertTrue(self~hasDiagnostic(badAuthorityReport, "AUTHORITY_WINNER_NORM_MISSING"), "missing winner norm diagnostic emitted")

  badTargetUnit = .LegalCompilationUnit~new("BAD-TARGET", "1", "compiler-kinds", "1")
  ignored = self~addSourceWithProvisions(badTargetUnit, "ACT2", "LEGISLATION", "act2-expr", .array~of("2"))
  badMod = .LegalModificationEffect~new("MOD-BAD", "ACT2", "2", "SUBSTITUTE", "ACT2", "999", .nil, 10, "V2", "replacement")
  badModProposal = .LegalCompileProposal~new("P-MOD-BAD", "MODIFICATION", badMod, "extractor", "LLM")
  ignored = badModProposal~addEvidenceReference(badTargetUnit~provisionReference("ACT2", "2"))
  ignored = badTargetUnit~addProposal(badModProposal)
  badModReport = compiler~compile(badTargetUnit)
  ok = self~assertTrue(\badModReport~ok, "modification cannot target absent provision")
  ok = self~assertTrue(self~hasDiagnostic(badModReport, "MODIFICATION_TARGET_MISSING"), "missing target diagnostic emitted")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 COMPILER SEMANTIC KINDS: OK"
  return 0

::method hasDiagnostic private
  use arg report, code
  do diagnostic over report~diagnostics
    if diagnostic~code = code then return .true
  end
  return .false

::method assertTrue private
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then raise syntax 88.900 array(label)
  return .true

::requires "LegalRuntimeCryptoBridge.cls"
