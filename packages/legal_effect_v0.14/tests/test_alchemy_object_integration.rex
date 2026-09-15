say "LEGAL EFFECT V0.14 ALCHEMY OBJECT INTEGRATION START"
assertions = 0

ring = .CryptoMacKeyRing~new
ring~addKey("le-alchemy-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
capAuthority = .AlchemyCapabilityAuthority~new(ring)

compiler = .LegalRuleCompiler~new(sealer, capAuthority)
call yes compiler~isA(.AlchemyObject), "rule compiler inherits AlchemyObject"
ci = compiler~legalComponentIdentity
call eq "0.14", ci["package_version"], "component package version"
call eq "legal.effect/0.10", ci["legal_api"], "legal API remains stable"
call eq "0.4.3", ci["alchemy_base_version"], "Alchemy base version"
call eq "LEGALRULECOMPILER", ci["class"]~string~translate, "compiler class identity"

publicEvidence = compiler~sealPublicIntrospection
call yes sealer~verify(publicEvidence), "public compiler introspection seal verifies"
call eq "PUBLIC", publicEvidence~payload["profile"], "public profile"
call eq "0.14", publicEvidence~payload["metadata"]["PACKAGE_VERSION"], "public metadata package version"
call eq "LEGAL_EFFECT", publicEvidence~payload["metadata"]["COMPONENT"], "public metadata component"
call yes hasContract(publicEvidence~payload["method_contracts"], "COMPILE"), "compiler contract visible"
call yes publicEvidence~payload["security_runtime_semantics"]["observed"], "runtime Security Manager semantics observed"
call no publicEvidence~payload~hasIndex("state"), "public introspection has no state values"

metricsBefore = compiler~alchemyMetrics
call eq 0, metricsBefore["use_count"], "compiler begins unused"
missing = compiler~compile(.nil)
call no missing~ok, "nil compilation rejected"
metricsAfter = compiler~alchemyMetrics
call eq 1, metricsAfter["use_count"], "compile touches operational telemetry"
call eq 1, metricsAfter["counters"]["COUNT:COMPILE"], "compile counter"

resolver = .LegalFrameworkResolver~new(sealer, capAuthority)
engine = .LegalEffectEngine~new(sealer, capAuthority)
runtimeResolver = .LegalRuntimeRuleResolver~new(sealer, capAuthority)
call yes resolver~isA(.AlchemyObject), "framework resolver inherits AlchemyObject"
call yes engine~isA(.AlchemyObject), "effect engine inherits AlchemyObject"
call yes runtimeResolver~isA(.AlchemyObject), "runtime resolver inherits AlchemyObject"
call yes hasContract(engine~sealPublicIntrospection~payload["method_contracts"], "EVALUATE"), "engine evaluate contract visible"
call yes hasContract(resolver~sealPublicIntrospection~payload["method_contracts"], "RESOLVE"), "resolver contract visible"
call yes hasContract(runtimeResolver~sealPublicIntrospection~payload["method_contracts"], "ACQUIRE"), "runtime acquire contract visible"
traceBuilder = .LegalDecisionTraceBuilder~new(sealer, capAuthority)
call yes traceBuilder~isA(.AlchemyObject), "decision trace builder inherits AlchemyObject"
call eq "LEGALDECISIONTRACEBUILDER", traceBuilder~legalComponentIdentity["class"]~string~translate, "decision trace builder class identity"
call yes hasContract(traceBuilder~sealPublicIntrospection~payload["method_contracts"], "BUILD"), "decision trace build contract visible"
traceQuery = .LegalDecisionTraceQuery~new(sealer, capAuthority)
call yes traceQuery~isA(.AlchemyObject), "decision trace query inherits AlchemyObject"
call eq "LEGALDECISIONTRACEQUERY", traceQuery~legalComponentIdentity["class"]~string~translate, "decision trace query class identity"
queryContracts = traceQuery~sealPublicIntrospection~payload["method_contracts"]
call yes hasContract(queryContracts, "CONTROLLINGNORMS"), "controlling norm query contract visible"
call yes hasContract(queryContracts, "REVIEWINPUTS"), "review input query contract visible"
counterfactualEvaluator = .LegalCounterfactualEvaluator~new(sealer, capAuthority)
call yes counterfactualEvaluator~isA(.AlchemyObject), "counterfactual evaluator inherits AlchemyObject"
call eq "LEGALCOUNTERFACTUALEVALUATOR", counterfactualEvaluator~legalComponentIdentity["class"]~string~translate, "counterfactual evaluator class identity"
counterfactualContracts = counterfactualEvaluator~sealPublicIntrospection~payload["method_contracts"]
call yes hasContract(counterfactualContracts, "EVALUATEFACT"), "counterfactual fact evaluation contract visible"
call yes hasContract(counterfactualContracts, "EVALUATEBOOLEAN"), "counterfactual boolean evaluation contract visible"

sha = .LegalSha512DigestProvider~new
sourceVerifier = .LegalSourceVerifier~new(sha, "alchemy-verifier", sealer, capAuthority)
call yes sourceVerifier~isA(.AlchemyObject), "source verifier inherits AlchemyObject"
call eq "LEGALSOURCEVERIFIER", sourceVerifier~legalComponentIdentity["class"]~string~translate, "source verifier class identity"
sourcePub = sourceVerifier~sealPublicIntrospection
call yes sealer~verify(sourcePub), "source verifier public evidence verifies"
call eq 0, sourcePub~payload["relationships"]~items, "internal digest provider relationship hidden publicly"

trust = .LegalSourceAuthorityTrustProfile~new("HOST-TRUST", sealer, capAuthority)
call yes trust~isA(.AlchemyObject), "trust profile inherits AlchemyObject"
cap = capAuthority~issue("customer-auditor", trust~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
customer = trust~sealedIntrospection("CUSTOMER", cap)
call yes sealer~verify(customer), "customer trust-profile evidence verifies"
call eq "HOST-TRUST", customer~payload["state"]["PROFILEID"], "customer sees bounded profile id"
call no customer~payload["state"]~hasIndex("SIGNERS"), "customer does not receive signer table"
call no customer~payload["state"]~hasIndex("POLICIES"), "customer does not receive policy table"
call no customer~payload["state"]~hasIndex("KEYOWNERS"), "customer does not receive key owner table"
call yes hasContract(customer~payload["method_contracts"], "LEGALCOMPONENTIDENTITY"), "common identity contract visible"

sigProvider = .AlchemyLegalDummySignatureProvider~new
authorityVerifier = .LegalSourceAuthorityVerifier~new(sigProvider, sealer, capAuthority)
call yes authorityVerifier~isA(.AlchemyObject), "authority verifier inherits AlchemyObject"
call yes hasContract(authorityVerifier~sealPublicIntrospection~payload["method_contracts"], "VERIFY"), "authority verify contract visible"

/* Semantic graph objects remain deliberately lightweight.  Alchemy operational
 * identity/telemetry must not become part of legal semantic identity. */
generation = .LegalRuleGeneration~new("ALCHEMY-SEMANTIC-CONTROL", "1")
call no generation~isA(.AlchemyObject), "rule generation is not operational AlchemyObject"
ignored = generation~seal
semanticBefore = generation~semanticIdentity
ignored = compiler~alchemyTouch("AUDIT_ONLY")
call eq semanticBefore, generation~semanticIdentity, "operational telemetry cannot alter legal semantic identity"

say "  assertions=" || assertions
say "LEGAL EFFECT V0.14 ALCHEMY OBJECT INTEGRATION: OK"
exit 0

yes: procedure expose assertions
  use arg value, label
  assertions = assertions + 1
  if value \== .true then raise syntax 88.900 array(label)
  return

no: procedure expose assertions
  use arg value, label
  assertions = assertions + 1
  if value \== .false then raise syntax 88.900 array(label)
  return

eq: procedure expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then raise syntax 88.900 array(label || " expected=" || expected || " actual=" || actual)
  return

hasContract: procedure
  use arg records, wanted
  wanted = wanted~string~translate
  do rec over records
    name = rec~at("name")
    if name \== .nil then if name~string~translate = wanted then return .true
  end
  return .false

::class AlchemyLegalDummySignatureProvider public
::method algorithm
  return "TEST-SIGNATURE"
::method verify
  use arg message, signatureValue, publicKey
  return .false

::requires "LegalRuntimeCryptoBridge.cls"
::requires "AlchemyObject.cls"
