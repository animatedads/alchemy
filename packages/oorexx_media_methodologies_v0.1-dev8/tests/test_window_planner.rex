call testMain
exit 0

testMain: procedure
  methods=.MediaMethodologyCatalogue~new
  .MediaMethodologyBuiltins~populate(methods)
  shapes=.MediaWorkShapeCatalogue~new
  .MediaWorkShapeBuiltins~populate(shapes,methods)
  shape=shapes~shape("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
  plan=.MediaMethodologyExecutionPlanner~new~partition(shape,1,300,100,"FRAME")
  call assertEqual 3,plan~count,"three core windows"
  u=plan~units
  call checkUnit u[1],1,100,1,108,"window1"
  call checkUnit u[2],101,200,93,208,"window2"
  call checkUnit u[3],201,300,193,300,"window3"
  call assertEqual "TRACK_STATE",u[2]~stateModel,"state model carried into work unit"
  call assertEqual "TRACK_COORDINATE_SUPPORT_MERGE",u[2]~mergeMode,"merge contract carried"
  say "PASS methodology window planner with overlap halos"
  return

checkUnit: procedure
  use arg u,cf,cl,rf,rl,label
  call assertEqual cf,u~coreFirst,label "core first"
  call assertEqual cl,u~coreLast,label "core last"
  call assertEqual rf,u~readFirst,label "read first"
  call assertEqual rl,u~readLast,label "read last"
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaWorkShapeBuiltins.cls"
