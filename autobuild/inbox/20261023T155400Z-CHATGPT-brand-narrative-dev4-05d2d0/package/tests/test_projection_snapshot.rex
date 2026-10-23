intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("NO_CHANGE", .false)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-SNAPSHOT")
if \projected~ok then signal fail
packet = projected~value
before = packet~reasoningMaterial
intervention~addRationale("MUTATED_AFTER_PROJECTION")
after = packet~reasoningMaterial
if before \== after then signal fail
if after~pos("MUTATED_AFTER_PROJECTION") > 0 then signal fail
say "PASS projection snapshot is immutable against later source rationale mutation"
exit 0
fail:
say "FAIL projection snapshot"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
