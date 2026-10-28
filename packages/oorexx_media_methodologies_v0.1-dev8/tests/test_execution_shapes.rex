call testMain
exit 0

testMain: procedure
  methods=.MediaMethodologyCatalogue~new
  .MediaMethodologyBuiltins~populate(methods)
  shapes=.MediaWorkShapeCatalogue~new
  .MediaWorkShapeBuiltins~populate(shapes,methods)
  call assertEqual 180,shapes~count,"one work shape per built-in methodology"

  leading=shapes~shape("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
  call assertEqual "FRAME_RANGE",leading~shardAxis,"leading-edge shard axis"
  call assertEqual "TRACK_STATE",leading~stateModel,"leading-edge state model"
  call assertEqual 8,leading~haloBefore,"leading-edge before halo"
  call assertEqual 8,leading~haloAfter,"leading-edge after halo"
  call assertEqual "STATE_HANDOFF_REQUIRED",leading~continuity,"leading-edge continuity"
  call assertEqual "TRACK_COORDINATE_SUPPORT_MERGE",leading~mergeMode,"leading-edge merge mode"

  audio=shapes~shape("AUDIO.DECLIP")
  call assertTrue audio<>.nil,"audio reconstructive shape exists"
  call assertEqual "SAMPLE_RANGE",audio~shardAxis,"audio reconstruction sample sharding"

  profile=.MediaImplementationExecutionProfile~new("impl.ffmpeg.edge/1","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","OOREXX",.Array~of("MEDIA.FFMPEG"),.Array~of("MEDIA.RESEARCH"),"X86_64",512,1024,2,256,512,1,1000,500000,.true,"RECONSTRUCTABLE")
  call assertEqual "impl.ffmpeg.edge/1",profile~implementationId,"implementation identity"
  call assertEqual 1,profile~requiredAbilities~items,"provider hard abilities retained"
  call assertEqual "RECONSTRUCTABLE",profile~recoveryClass,"provider recovery class retained"

  say "PASS media work-shape and implementation-profile contract"
  return

assertEqual: procedure
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return
assertTrue: procedure
  use arg value,label
  if \value then do; say "FAIL" label; exit 1; end
  return

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaWorkShapeBuiltins.cls"
