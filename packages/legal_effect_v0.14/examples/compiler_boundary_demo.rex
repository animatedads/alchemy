say "LEGAL EFFECT V0.14 COMPILER BOUNDARY SYNTHETIC DEMO"
say

provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
verifier = .LegalSourceVerifier~new(provider, "compiler-boundary-demo-verifier")
sourceText = "Synthetic Delivery Act" || '0a'x || "Section 11(12). A platform must consult before imposing forced scheduling blocks."
text = "A platform must consult before imposing forced scheduling blocks."
sourceDoc = .directory~new
sourceDoc["content"] = sourceText

unit = .LegalCompilationUnit~new("DEMO-COMPILED-LAW", "1", "legal-effect-demo-compiler", "0.9")
sourceIdentity = .LegalSourceIdentity~new("DELIVERY-ACT", "LEGISLATION", "2026-expression", "urn:demo:delivery-act", "sha512:" || provider~digest(sourceText), "DEMO-AUTHORITY", "DEMO-LAND", "VERIFIED")
source = .NormativeSource~new("DELIVERY-ACT", "LEGISLATION", "Synthetic Delivery Act", "DEMO-AUTHORITY", "DEMO-LAND")
ignored = unit~addSource(sourceIdentity, source)
reference = .LegalProvisionReference~new("DELIVERY-ACT", "11.12", "2026-expression", "s.11(12)", "sha512:" || provider~digest(text), text, "VERIFIED")
provision = .LegalProvision~new("DELIVERY-ACT", "11.12", "ACTIVE", "BASE", text)
ignored = unit~addProvision(reference, provision)
ignored = unit~verifySource("DELIVERY-ACT", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:demo:delivery-act", "RAW_NORMATIVE_SOURCE"), verifier)
ignored = unit~verifyProvision("DELIVERY-ACT", "11.12", .LegalVerificationMaterial~fromText(sourceDoc, text, "s.11(12)", "PROVISION_LEXICAL_TEXT"), verifier)

norm = .LegalNorm~new("DELIVERY-11-12", "DELIVERY-ACT", "11.12", "OBLIGATION", "FORCE_BLOCKS", "REQUIRES_OBLIGATION", "WORK", "Synthetic rule only")
ignored = norm~addCondition(.LegalPredicate~new("FORCED_BLOCKS", "KNOWN_TRUE"))
proposal = .LegalCompileProposal~new("LLM-P-0001", "NORM", norm, "example-llm", "LLM", "0.93")
ignored = proposal~addEvidenceReference(unit~provisionReference("DELIVERY-ACT", "11.12"))
ignored = unit~addProposal(proposal)

report = .LegalRuleCompiler~new~compile(unit)
if \report~ok then raise syntax 88.900 array("valid demonstration compilation failed")
generation = report~generation
say "LLM proposal -> verifier -> compiler:"
say "  source_verified=" unit~sourceIdentity("DELIVERY-ACT")~verificationState "provision_verified=" unit~provisionReference("DELIVERY-ACT", "11.12")~verificationState
say "  compiled=" report~ok "sealed=" generation~sealed "publication_eligible=" generation~publicationEligible
say "  verification_snapshots=" generation~compilationCertificate~verificationEvidence~items
say "  producer=" generation~norms[1]~evidence[1]~metadata["producerKind"]
say

facts = .LegalFactSet~new
ignored = facts~putKnown("FORCED_BLOCKS", .true, "candidate action")
context = .LegalContext~new("DELIVERY-CHANGE", "2026-08-20", "2026-08-20", facts)
ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("DEMO-AUTHORITY", "DEMO-LAND", "WORK", "demo"))
evaluated = .LegalEffectEngine~new~evaluate(.LegalAction~new("FORCE_BLOCKS"), generation, context)
if \evaluated~ok then raise syntax 88.900 array(evaluated~code)
say "Deterministic evaluation after compilation:"
say "  status=" evaluated~value~status "dispositions=" evaluated~value~dispositions~items
say

badUnit = .LegalCompilationUnit~new("DEMO-BAD", "1", "legal-effect-demo-compiler", "0.9")
badText = "An asserted VERIFIED string must not become executable."
badIdentity = .LegalSourceIdentity~new("BAD-ACT", "LEGISLATION", "2026-expression", "urn:demo:bad-act", "sha512:" || provider~digest(badText), "DEMO-AUTHORITY", "DEMO-LAND", "VERIFIED")
badSource = .NormativeSource~new("BAD-ACT", "LEGISLATION", "Bad synthetic source", "DEMO-AUTHORITY", "DEMO-LAND")
ignored = badUnit~addSource(badIdentity, badSource)
badRef = .LegalProvisionReference~new("BAD-ACT", "4", "2026-expression", "s.4", "sha512:" || provider~digest(badText), badText, "VERIFIED")
badProvision = .LegalProvision~new("BAD-ACT", "4", "ACTIVE", "BASE", badText)
ignored = badUnit~addProvision(badRef, badProvision)
badNorm = .LegalNorm~new("BAD-NORM", "BAD-ACT", "4", "PROHIBITION", "ACTION-X", "PROHIBITED")
badProposal = .LegalCompileProposal~new("LLM-P-BAD", "NORM", badNorm, "example-llm", "LLM", "0.99")
ignored = badProposal~addEvidenceReference(badRef)
ignored = badUnit~addProposal(badProposal)
badReport = .LegalRuleCompiler~new~compile(badUnit)
say "Caller asserted VERIFIED but supplied no verifier evidence:"
say "  compiled=" badReport~ok "generation=" badReport~generation
if badReport~diagnostics~items > 0 then say "  diagnostic=" badReport~diagnostics[1]~code
say
say "The source verifier proves bytes. The compiler admits semantics. Runtime proves what executed."

::requires "LegalRuntimeCryptoBridge.cls"
