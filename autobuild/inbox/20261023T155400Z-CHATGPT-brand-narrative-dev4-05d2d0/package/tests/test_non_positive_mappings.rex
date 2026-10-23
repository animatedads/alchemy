intervention = .TestNarrativeFixture~intervention
codes = .Array~of("COLLECT_MORE_EVIDENCE", "NO_CHANGE", "PAUSE", "WITHDRAW")
kinds = .Array~of("EVIDENCE_ONLY", "PRESERVE_BASELINE", "PAUSE_ADAPTATION", "WITHDRAW_ADAPTATION")
effects = .Array~of("NONE", "NONE", "PAUSE", "WITHDRAW")
do i = 1 to codes~items
  governance = .TestNarrativeFixture~governance(codes[i], .false)
  projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-" || i)
  if \projected~ok then signal fail
  if projected~value~directiveKind \== kinds[i] then signal fail
  if projected~value~runtimeEffect \== effects[i] then signal fail
  if projected~value~status \== "PROPOSED_NOT_ACTIVE" then signal fail
end
say "PASS non-positive governance mappings remain non-activating directives"
exit 0
fail:
say "FAIL non-positive mappings"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
