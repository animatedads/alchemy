intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("NO_CHANGE", .false)
/* Create a second intervention with a different proposal kind. */
context = intervention~context
binding = intervention~binding
policy = intervention~policy
proposal = .BrandInterventionProposal~new("PROP-OTHER", .BrandInterventionConstant~KIND_JOURNEY, "CONTEXT_LOSS", 50)
proposal~addObjective("RESTORE_RELEVANT_CONTEXT")
proposal~addObligation("PRESERVE_TRUTHFULNESS")
proposal~seal
other = .BrandInterventionDecision~new("INT-DEC-OTHER", .BrandInterventionConstant~MODE_REASONING_GUIDANCE, "SUPPORTED", context, binding, policy, proposal)
projected = .BrandNarrativeProjectionEngine~new~project(other, governance, "DIR-MISMATCH")
if projected~ok then signal fail
if projected~code \== "INTERVENTION_KIND_MISMATCH" then signal fail
say "PASS intervention/governance kind mismatch fails closed"
exit 0
fail:
say "FAIL kind mismatch"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
