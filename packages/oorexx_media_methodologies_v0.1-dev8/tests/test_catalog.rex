call testMain
exit 0

testMain: procedure
  catalogue = .MediaMethodologyCatalogue~new
  .MediaMethodologyBuiltins~populate(catalogue)

  call assertEqual 180, catalogue~count, "built-in methodology count"
  call assertEqual 84, catalogue~byDomain("VIDEO")~items, "video count"
  call assertEqual 70, catalogue~byDomain("AUDIO")~items, "audio count"
  call assertEqual 10, catalogue~byDomain("CROSS_MODAL")~items, "cross-modal count"
  call assertEqual 16, catalogue~byDomain("VALIDATION")~items, "validation count"
  call assertEqual 30, catalogue~experimental~items, "experimental count"
  call assertEqual 62, catalogue~reconstructive~items, "reconstructive count"

  leading = catalogue~methodology("video.recon.leading_edge_backprojection")
  call assertTrue leading \== .nil, "leading-edge methodology exists"
  call assertTrue leading~experimental, "leading-edge methodology is experimental"
  call assertTrue leading~reconstructive, "leading-edge methodology is reconstructive"
  call assertEqual "RECONSTRUCT", leading~authorityEffect, "leading-edge authority boundary"

  policy = .MediaMethodologyPolicy~new(.false, .true)
  call assertTrue \policy~accepts(leading), "policy can exclude experimental methods"
  policy2 = .MediaMethodologyPolicy~new(.true, .true)
  call assertTrue policy2~accepts(leading), "default research policy can include experimental methods"

  plan = .MediaMethodologyPlan~new("recover moving blurred subject")
  plan~add(.MediaMethodologyStep~new("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION"))
  plan~add(.MediaMethodologyStep~new("QUAL.FORWARD_MODEL.REPROJECTION"))
  call assertEqual 2, plan~steps~items, "plan allows composed methodologies"

  refs = .Array~of("source:video:1", "frame:100", "frame:101")
  candidate = .MediaReconstructionCandidate~new("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION", refs, "material:reconstruction:1", 1.0, 1.2, "uncertainty:1", "support:1")
  call assertEqual "CANDIDATE", candidate~status, "reconstruction remains candidate"
  call assertEqual "RECONSTRUCT", candidate~authorityEffect, "candidate authority remains reconstructive"
  call assertEqual 3, candidate~sourceRefs~items, "candidate retains source references"

  provider = .TestProvider~new
  catalogue~registerProvider(provider)
  catalogue~refreshProviders
  call assertEqual 181, catalogue~count, "dynamic provider refresh"
  call assertTrue catalogue~methodology("VIDEO.EXPERIMENTAL.TEST_PROVIDER") \== .nil, "provider methodology registered"

  say "PASS media methodology catalogue contract"
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value, label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return

::class TestProvider subclass MediaMethodologyProvider
::method methodologies
  items = .Array~new
  items~append(.MediaMethodologySpec~new("VIDEO.EXPERIMENTAL.TEST_PROVIDER", "Provider test methodology", "VIDEO", "RECONSTRUCTION", "EXPERIMENTAL", "RECONSTRUCT", .true, .true, "Proves dynamic provider discovery."))
  return items

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
