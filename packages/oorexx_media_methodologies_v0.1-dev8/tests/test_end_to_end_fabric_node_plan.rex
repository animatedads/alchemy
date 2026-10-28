call testMain
exit 0

testMain: procedure
  /* Method semantics -> work unit. */
  methods=.MediaMethodologyCatalogue~new
  .MediaMethodologyBuiltins~populate(methods)
  shapes=.MediaWorkShapeCatalogue~new
  .MediaWorkShapeBuiltins~populate(shapes,methods)
  shape=shapes~shape("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
  work=.MediaMethodologyExecutionPlanner~new~partition(shape,1,300,100,"FRAME")~units[2]

  /* RexxOS membership supplies stable current MI identities only. */
  p=.Directory~new; p["declared_role"]="media-worker"
  miA=.RexxOSGridEstateMember~new("GRID-MEDIA","MI-A","MI","MU-1","inc-9","ACTIVE",p)
  miB=.RexxOSGridEstateMember~new("GRID-MEDIA","MI-B","MI","MU-2","inc-4","ACTIVE",p)
  eA=.MediaRexxOSNodeEvidence~new(miA)
  eB=.MediaRexxOSNodeEvidence~new(miB)

  /* Provider declares hard execution needs; media planner does not guess them. */
  impl=.MediaImplementationExecutionProfile~new("impl.edge.native/1",shape~methodologyId,"OOREXX",.Array~of("MEDIA.FFMPEG","MEDIA.VISION"),.Array~of("MEDIA.RESEARCH"),"X86_64",512,1024,2,256,512,1,500,250000,.true,"RECONSTRUCTABLE")
  req=.MediaMethodologyJobNodeProjection~new~request(work,impl,"architect-node",0,.Array~of("EXPERIMENTAL_MEDIA"),.Array~of("GB"),.Array~of("EVIDENCE"),.Array~of("LOCAL_TRUST"),.Array~of("MEDIA_RESEARCH"))

  /* Job-to-Node remains authority. MI-A lacks MEDIA.VISION, MI-B has it. */
  reg=.NodeCapabilityRegistry~new
  cA=.NodeCapabilityStatement~new(eA~semanticRef,1,"",.Array~of("GB"),.Array~of("EVIDENCE"),.Array~of("LOCAL_TRUST"),.Array~of("MEDIA_RESEARCH"),.Array~of("MEDIA.FFMPEG"),.Array~of("OOREXX"),.Array~of("MEDIA.RESEARCH"),"X86_64",4096,8192,4,"r13196")
  cB=.NodeCapabilityStatement~new(eB~semanticRef,1,"",.Array~of("GB"),.Array~of("EVIDENCE"),.Array~of("LOCAL_TRUST"),.Array~of("MEDIA_RESEARCH"),.Array~of("MEDIA.FFMPEG","MEDIA.VISION"),.Array~of("OOREXX"),.Array~of("MEDIA.RESEARCH"),"X86_64",8192,16384,8,"r13196")
  call assertTrue reg~advertiseCapability(cA),"MI-A capability accepted"
  call assertTrue reg~advertiseCapability(cB),"MI-B capability accepted"
  call assertTrue reg~observeCapacity(.NodeCapacityObservation~new(eA~semanticRef,1,1,1000,100000,3000,7000,3,5000,0,0)),"MI-A capacity accepted"
  call assertTrue reg~observeCapacity(.NodeCapacityObservation~new(eB~semanticRef,1,1,1000,100000,7000,15000,7,12000,1,0)),"MI-B capacity accepted"
  decision=.JobNodeAllocator~new(reg)~allocate(req,1000,30000)
  call assertTrue decision~placed,"Job-to-Node placed media work"
  call assertEqual eB~semanticRef,decision~lease~nodeId,"hard ability constraint selects MI-B"
  call assertEqual 1,decision~exclusionCount("REQUIRED_ABILITY_UNAVAILABLE"),"ineligible MI-A retained in assessment evidence"

  /* Memory Fabric represents only the work unit's source window, reference-first. */
  mem=.MediaMethodologyMemoryFabricSession~new(work,"video:source:sha256",3,"storage://evidence/source.mp4")
  call assertTrue mem~open("task-2","worker-B",1,"FORWARD")<>.nil,"Memory Fabric cursor opened"
  call assertEqual "REFERENCE",mem~backingMap~stateAt(work~coreFirst),"source remains external reference"

  sources=.Array~of("storage://evidence/source.mp4")
  prov=.MediaExecutionProvenance~new(work~workId,work~methodologyId,impl~implementationId,eB~semanticRef,eB~incarnation,decision~lease~placementId,mem~sparseObject~objectId,mem~sparseObject~objectEpoch,sources,"material://candidate/window2","COMPLETED")
  call assertEqual "inc-4",prov~nodeIncarnation,"RexxOS incarnation retained in provenance"
  call assertEqual decision~lease~placementId,prov~placementRef,"authoritative lease reference retained"
  call assertEqual "material://candidate/window2",prov~outputRef,"candidate material reference retained"

  say "PASS media methodology -> RexxOS MI evidence -> Job-to-Node lease -> Memory Fabric window -> provenance"
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
::requires "MediaMethodologyJobNode.cls"
::requires "MediaMethodologyRexxOS.cls"
