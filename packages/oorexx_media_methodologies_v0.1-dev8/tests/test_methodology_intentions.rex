catalog=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalog)

profile=.MediaImplementationExecutionProfile~new("leading-native","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
context=.MediaMethodologyIntentionContext~new("VIDEO","RECONSTRUCTION",.nil,.Array~of("MOTION_BLUR"),.Array~of(profile))
provider=.MediaMethodologyIntentionProvider~new(catalog)
provider~registerApplicabilityProvider(.BlurApplicability~new)
surface=provider~surface("LIVE-VIDEO-EVIDENCE",context)

first=surface~discover
second=surface~discover
call assertTrue second~generation>first~generation, "discovery is re-run"
call assertTrue second~revision<>"", "discovery carries semantic revision"

proposal=provider~proposeMethodology(second,"VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
call assertEqual "READY", proposal~state, "leading-edge method applicable"

experimentProposal=provider~proposeExperiment(second,"blur-exp","compare blur reconstruction",.Array~of("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION"),.Array~of("storage://clip"))
call assertEqual "READY", experimentProposal~state, "plural experiment proposal ready"
call assertEqual 1, experimentProposal~plan~methodCount, "proposal carries experiment definition"

say "PASS dynamic methodology intentions"
exit 0

assertTrue: procedure
  use arg condition, message
  if \condition then do
    say "FAIL" message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, message
  if expected<>actual then do
    say "FAIL" message "expected="expected "actual="actual
    exit 1
  end
  return

::class BlurApplicability subclass MediaMethodologyApplicabilityProvider
::method assess
  use strict arg spec, target, context
  if spec~id="VIDEO.RECON.LEADING_EDGE_BACKPROJECTION" then return .MediaMethodologyApplicability~new(spec~id,"APPLICABLE","Motion-blur evidence supplied by current context",context~evidence)
  return .MediaMethodologyApplicability~new(spec~id,"UNKNOWN","No method-specific assessor",.nil)

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
::requires "MediaMethodologyIntentions.cls"
