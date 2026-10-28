call assertTrue .true, "test harness live"

catalog=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalog)
shapes=.MediaWorkShapeCatalogue~new
.MediaWorkShapeBuiltins~populate(shapes,catalog)

abilities=.Array~of("MEDIA.FFMPEG","MEDIA.VISION")
p1=.MediaImplementationExecutionProfile~new("leading-native","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","OOREXX",abilities)
p2=.MediaImplementationExecutionProfile~new("blur-envelope-native","VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL","OOREXX",abilities)

definition=.MediaExperimentDefinition~new("blur-exp-1","recover partially observed moving subject",.Array~of("storage://clip"))
definition~addMethod(.MediaExperimentMethodSelection~new("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION",p1))
definition~addMethod(.MediaExperimentMethodSelection~new("VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL",p2))
call assertEqual 2, definition~methodCount, "two methodologies retained"
call assertEqual 2, definition~lineages~items, "two scientific lineages retained"

plan=.MediaExperimentPlanner~new~plan(definition,shapes,1,300,100,"FRAME")
call assertTrue plan~count>=2, "plural experiment expands to work"
call assertEqual 2, plan~lineageCount, "planner does not collapse lineages"

leading=plan~tasksForLineage("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
call assertEqual 3, leading~items, "leading-edge method has three core shards"
call assertEqual 1, leading[1]~workUnit~coreFirst, "first core begins at one"
call assertTrue leading[2]~workUnit~readFirst<leading[2]~workUnit~coreFirst, "middle shard carries pre-halo"
call assertTrue leading[2]~workUnit~readLast>leading[2]~workUnit~coreLast, "middle shard carries post-halo"

say "PASS media experiment orchestration"
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

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaWorkShapeBuiltins.cls"
::requires "MediaMethodologyExperiments.cls"
