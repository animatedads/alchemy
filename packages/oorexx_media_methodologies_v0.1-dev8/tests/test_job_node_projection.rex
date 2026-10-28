call testMain
exit 0

testMain: procedure
  shape=.MediaWorkShape~new("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","FRAME_RANGE","TRACK_STATE","SEQUENTIAL_WINDOW",8,8,"TRACK_COORDINATE_SUPPORT_MERGE","STATE_HANDOFF_REQUIRED","REFERENCE_FIRST")
  plan=.MediaMethodologyExecutionPlanner~new~partition(shape,1,300,100,"FRAME")
  work=plan~units[1]
  profile=.MediaImplementationExecutionProfile~new("impl.edge.native/1",shape~methodologyId,"OOREXX",.Array~of("MEDIA.FFMPEG","MEDIA.VISION"),.Array~of("MEDIA.RESEARCH"),"X86_64",512,2048,2,256,1024,1,500,250000,.true,"RECONSTRUCTABLE")
  p=.MediaMethodologyJobNodeProjection~new
  request=p~request(work,profile,"architect-node",0,.Array~of("EXPERIMENTAL_MEDIA"),.Array~of("GB"),.Array~of("EVIDENCE"),.Array~of("LOCAL_TRUST"),.Array~of("MEDIA_RESEARCH"))
  req=request~requirement
  call assertEqual "X86_64",req~architecture,"architecture projected"
  call assertEqual 512,req~minimumMemoryMiB,"memory requirement projected"
  call assertEqual 2,req~minimumCpuUnits,"cpu requirement projected"
  call assertTrue req~abilities~at("MEDIA.FFMPEG")<>.nil,"provider ability projected as hard requirement"
  call assertTrue req~runtimes~at("OOREXX")<>.nil,"provider runtime projected"
  call assertTrue pos("media:VIDEO.RECON.LEADING_EDGE_BACKPROJECTION#1:impl.edge.native/1",request~jobId)=1,"stable media work job id"
  say "PASS provider execution profile projects into Job-to-Node request without allocating"
  return

assertEqual: procedure
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return
assertTrue: procedure
  use arg value,label
  if \value then do; say "FAIL" label; exit 1; end
  return

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyJobNode.cls"
