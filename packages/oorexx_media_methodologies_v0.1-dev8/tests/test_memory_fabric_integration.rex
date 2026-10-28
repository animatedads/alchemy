call testMain
exit 0

testMain: procedure
  methods=.MediaMethodologyCatalogue~new
  .MediaMethodologyBuiltins~populate(methods)
  shapes=.MediaWorkShapeCatalogue~new
  .MediaWorkShapeBuiltins~populate(shapes,methods)
  shape=shapes~shape("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
  plan=.MediaMethodologyExecutionPlanner~new~partition(shape,1,300,100,"FRAME")
  u=plan~units[2]

  session=.MediaMethodologyMemoryFabricSession~new(u,"video:sha256:example",7,"storage://media/source.mp4")
  c=session~open("task-edge-2","reader-edge",1,"FORWARD")
  call assertTrue c<>.nil,"Memory Fabric cursor opened"
  call assertEqual "REFERENCE",session~backingMap~stateAt(100),"source remains reference backed"
  transfer=session~transferPlan
  call assertEqual 1,transfer~items,"one source reference transfer segment"
  call assertEqual "RESOLVE_REFERENCE",transfer[1]~action,"reference is resolved, not fabricated data"

  /* 50 frames/s * 100ms * safety 2 -> 10 frame warning distance. */
  d=session~adaptHorizon(50,100,2,1,100)
  call assertEqual 10,d,"adaptive media event horizon"
  threshold=session~horizonThreshold
  call assertEqual 198,threshold~value,"window2 horizon threshold"
  ignored=session~observeRead(198)
  call assertEqual 1,session~demands~items,"threshold read raises one Memory Fabric demand"
  demand=session~demands[1]
  call assertEqual "TRIGGERED",demand~state,"media layer observes unsatisfied demand"
  call assertEqual "209",demand~requestedRange~first~value,"next window begins after resident range"

  say "PASS media work unit uses Memory Fabric sparse reference + adaptive horizon without satisfying demand"
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
::requires "MediaMethodologyMemoryFabric.cls"
