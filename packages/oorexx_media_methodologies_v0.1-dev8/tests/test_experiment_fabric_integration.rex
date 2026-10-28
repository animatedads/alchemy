call testMain
exit 0

testMain: procedure
  catalogue=.MediaMethodologyCatalogue~new
  .MediaMethodologyBuiltins~populate(catalogue)
  shapes=.MediaWorkShapeCatalogue~new
  .MediaWorkShapeBuiltins~populate(shapes,catalogue)

  abilities=.Array~of("MEDIA.FFMPEG","MEDIA.VISION")
  profile=.MediaImplementationExecutionProfile~new("impl.edge.native/1","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","OOREXX",abilities,.Array~of("MEDIA.RESEARCH"),"X86_64",512,1024,2,256,512,1,500,250000,.true,"RECONSTRUCTABLE")
  definition=.MediaExperimentDefinition~new("exp-fabric","distributed leading-edge reconstruction",.Array~of("storage://source.mp4"))
  definition~addMethod(.MediaExperimentMethodSelection~new("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION",profile))
  plan=.MediaExperimentPlanner~new~plan(definition,shapes,1,300,100,"FRAME")
  task=plan~tasks[2]

  nodeProfile=.Directory~new
  nodeProfile["declared_role"]="media-worker"
  member=.RexxOSGridEstateMember~new("GRID-MEDIA","MI-B","MI","MU-2","inc-4","ACTIVE",nodeProfile)
  evidence=.MediaRexxOSNodeEvidence~new(member)

  projection=.MediaExperimentFabricProjection~new
  envelope=projection~project(task,"video:source:sha256",3,"storage://source.mp4","architect-node",0,.Array~of("EXPERIMENTAL_MEDIA"),.Array~of("GB"),.Array~of("EVIDENCE"),.Array~of("LOCAL_TRUST"),.Array~of("MEDIA_RESEARCH"))
  call assertEqual task~taskId,envelope~task~taskId,"task identity retained"
  call assertEqual "REFERENCE",envelope~memorySession~backingMap~stateAt(task~workUnit~coreFirst),"source remains reference-first"

  registry=.NodeCapabilityRegistry~new
  capability=.NodeCapabilityStatement~new(evidence~semanticRef,1,"",.Array~of("GB"),.Array~of("EVIDENCE"),.Array~of("LOCAL_TRUST"),.Array~of("MEDIA_RESEARCH"),abilities,.Array~of("OOREXX"),.Array~of("MEDIA.RESEARCH"),"X86_64",8192,16384,8,"r13196")
  call assertTrue registry~advertiseCapability(capability),"capability accepted"
  call assertTrue registry~observeCapacity(.NodeCapacityObservation~new(evidence~semanticRef,1,1,1000,100000,7000,15000,7,12000,1,0)),"capacity accepted"
  decision=.JobNodeAllocator~new(registry)~allocate(envelope~placementRequest,1000,30000)
  call assertTrue decision~placed,"Job-to-Node authoritatively places experiment task"

  call assertTrue envelope~memorySession~open("task-2","worker-B",1,"FORWARD")<>.nil,"Memory Fabric cursor opens"
  bundle=projection~recordCompletion(envelope,evidence,decision~lease~placementId,"material://candidate/shard2",3,.Array~of("storage://source.mp4"),"material://support/shard2","material://uncertainty/shard2")
  candidate=bundle["CANDIDATE"]
  provenance=bundle["PROVENANCE"]
  call assertEqual "SHARD",candidate~candidateKind,"distributed output remains a shard candidate"
  call assertEqual task~lineageId,candidate~lineageId,"methodological lineage survives node execution"
  call assertEqual decision~lease~placementId,provenance~placementRef,"authoritative placement retained"
  call assertEqual evidence~incarnation,provenance~nodeIncarnation,"RexxOS incarnation retained"
  call assertEqual envelope~memorySession~sparseObject~objectId,provenance~memoryObjectRef,"Memory Fabric object identity retained"

  say "PASS experiment -> RexxOS evidence -> Job-to-Node placement -> Memory Fabric -> candidate provenance"
  return

assertEqual: procedure
  use arg expected,actual,label
  if expected<>actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value,label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaWorkShapeBuiltins.cls"
::requires "MediaMethodologyExperiments.cls"
::requires "MediaMethodologyMemoryFabric.cls"
::requires "MediaMethodologyJobNode.cls"
::requires "MediaMethodologyRexxOS.cls"
::requires "MediaExperimentFabric.cls"
