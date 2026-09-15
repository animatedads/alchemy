packageRoot = arg(1)
if packageRoot = "" then packageRoot = "."
call main packageRoot
exit 0

main:
  procedure
  use arg packageRoot
  say "AI ACCESS V0.6 ALCHEMY OBJECT START"

  run = .AlchemyTestRun~new("AI Access v0.6 Alchemy base adoption")
  module = .DeterministicAIProviderModule~new
  provider = .DeterministicAIProvider~new

  ignore = run~assertTrue(module~isa(.AlchemyObject), "runtime capability inherits AlchemyObject")
  ignore = run~assertTrue(provider~isa(.AlchemyObject), "provider adapter inherits AlchemyObject")
  ignore = run~assertTrue(module~checkSurfaceContract~ok, "runtime capability surface contract")
  ignore = run~assertTrue(provider~checkSurfaceContract~ok, "provider adapter surface contract")

  moduleAdoption = .AlchemyAdoptionVerifier~verify(module, "STANDARD")
  providerAdoption = .AlchemyAdoptionVerifier~verify(provider, "STANDARD")
  ignore = run~assertTrue(moduleAdoption~ok, "runtime capability STANDARD adoption")
  ignore = run~assertTrue(providerAdoption~ok, "provider adapter STANDARD adoption")
  ignore = run~assertEquals(0, moduleAdoption~warnings~items, "runtime capability adoption warning count")
  ignore = run~assertEquals(0, providerAdoption~warnings~items, "provider adapter adoption warning count")
  ignore = run~assertEquals("INIT", module~alchemyConstructionProvenance["entrypoint"], "runtime capability preferred construction entrypoint")
  ignore = run~assertEquals("INIT", provider~alchemyConstructionProvenance["entrypoint"], "provider adapter preferred construction entrypoint")
  ignore = run~assertEquals(0, module~alchemyInheritanceIntegrity["reserved_override_count"], "runtime capability reserved-base override count")
  ignore = run~assertEquals(0, provider~alchemyInheritanceIntegrity["reserved_override_count"], "provider adapter reserved-base override count")
  ignore = run~assertTrue(module~alchemyObjectId~length > 0, "runtime capability has Alchemy identity")
  ignore = run~assertTrue(provider~alchemyObjectId~length > 0, "provider adapter has Alchemy identity")

  request = .AIProviderRequest~new("fixture-model", "SECRET-PROMPT-DO-NOT-LOG", 3)
  ignore = run~assertFalse(request~isa(.AlchemyObject), "narrow request deliberately does not inherit broad behavioral base")
  ignore = run~assertFalse(request~hasMethod("BODY"), "narrow request has no raw Ability body")
  ignore = run~assertFalse(request~hasMethod("METERFACT"), "narrow request has no WLU metering authority")
  ignore = run~assertFalse(request~hasMethod("SEALEDINTROSPECTION"), "narrow request does not gain Alchemy introspection surface")

  providerReply = provider~complete(request)
  ignore = run~assertTrue(providerReply~ok, "provider adapter completion")
  ignore = run~assertEquals(1, provider~alchemyMetrics["use_count"], "provider adapter lifecycle use count")
  providerEvidence = .AlchemyCanonical~encode(provider~instrumentationEvents)
  ignore = run~assertTrue(providerEvidence~pos("AI.PROVIDER.COMPLETE.BEFORE") > 0, "provider before instrumentation")
  ignore = run~assertTrue(providerEvidence~pos("AI.PROVIDER.COMPLETE.AFTER") > 0, "provider after instrumentation")
  ignore = run~assertEquals(0, providerEvidence~pos("SECRET-PROMPT-DO-NOT-LOG"), "provider instrumentation excludes prompt contents")

  body = .directory~new
  body["model"] = "fixture-model"
  body["prompt"] = "SECRET-PROMPT-DO-NOT-LOG"
  body["max_output_tokens"] = 3
  context = .AlchemyFakeAIContext~new(body, .false)
  invocation = module~runtimeInvokeAbility("model.complete", context)
  ignore = run~assertTrue(invocation~ok, "runtime capability completion")
  ignore = run~assertEquals(1, module~runtimeInvocationCount, "runtime capability invocation count")
  ignore = run~assertEquals(1, module~alchemyMetrics["use_count"], "runtime capability lifecycle use count")
  moduleEvidence = .AlchemyCanonical~encode(module~instrumentationEvents)
  ignore = run~assertTrue(moduleEvidence~pos("AI.INVOCATION.BEFORE") > 0, "runtime before instrumentation")
  ignore = run~assertTrue(moduleEvidence~pos("AI.INVOCATION.AFTER") > 0, "runtime after instrumentation")
  ignore = run~assertEquals(0, moduleEvidence~pos("SECRET-PROMPT-DO-NOT-LOG"), "runtime instrumentation excludes prompt contents")

  summary = run~complete
  if summary["failures"] > 0 then do
    do ev over run~instrumentationEvents
      if ev["point"] = "ALCHEMY.TEST.ASSERT" then do
        rec = ev["evidence"]
        if \rec["ok"] then say "FAILED:" rec["message"] "expected=" rec["expected"] "actual=" rec["actual"]
      end
    end
  end
  run~requirePass
  say "  assertions=" || summary["assertions"]
  say "  provider_events=" || provider~instrumentationEvents~items
  say "  runtime_events=" || module~instrumentationEvents~items
  say "AI ACCESS V0.6 ALCHEMY OBJECT: OK"
  return

::class AlchemyFakeAIResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg
  detail = detailArg
  value = valueArg
::method success class
  use arg value = .nil
  return self~new(.true, "OK", "", value)
::method failure class
  use arg code, detail = ""
  return self~new(.false, code, detail, .nil)

::class AlchemyFakeAIContext public
::method init
  expose requestBody managed facts
  use arg bodyArg, managedArg = .false
  requestBody = bodyArg
  managed = managedArg == .true
  facts = .array~new
::method body
  expose requestBody
  return requestBody
::method wluManaged
  expose managed
  return managed
::method meterFact
  expose facts
  use arg factType, quantity = 1, source = "", dimensions = .nil
  fact = .directory~new
  fact["type"] = factType
  fact["quantity"] = quantity
  fact["source"] = source
  facts~append(fact)
  return .AlchemyFakeAIResult~success(fact)
::method success
  use arg value = .nil
  return .AlchemyFakeAIResult~success(value)
::method failure
  use arg code, detail = ""
  return .AlchemyFakeAIResult~failure(code, detail)

::requires "AIProviderAccess.cls"
::requires "DeterministicAIProvider_v1.cls"
::requires "AlchemyTestSupport.cls"

::requires "AlchemyAdoption.cls"
