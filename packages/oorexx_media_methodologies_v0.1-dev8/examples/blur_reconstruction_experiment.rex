/* A plural reconstruction experiment.  The example deliberately chooses
 * several method families.  It does not choose a winner or execute a job. */

catalog=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalog)
shapes=.MediaWorkShapeCatalogue~new
.MediaWorkShapeBuiltins~populate(shapes,catalog)

methods=.Array~of( -
  "VIDEO.RECON.LEADING_EDGE_BACKPROJECTION", -
  "VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL", -
  "VIDEO.RECON.LATENT_MULTI_FRAME", -
  "VIDEO.RECON.FLOW_WARP_ACCUMULATE", -
  "VIDEO.RECON.MOVING_STRIP_MOSAIC")

definition=.MediaExperimentDefinition~new("blur-person-001","recover supported structure from a moving blurred subject",.Array~of("storage://source-video"))

do methodId over methods
  profile=.MediaImplementationExecutionProfile~new("candidate-provider:"||methodId,methodId)
  definition~addMethod(.MediaExperimentMethodSelection~new(methodId,profile))
end

plan=.MediaExperimentPlanner~new~plan(definition,shapes,1,300,100,"FRAME")
say "experiment:" definition~experimentId
say "methodological lineages:" plan~lineageCount
say "work tasks:" plan~count

do lineage over definition~lineages
  say "  " lineage "tasks="plan~tasksForLineage(lineage)~items
end

say "No candidate is promoted to captured evidence; comparison comes after execution."

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaWorkShapeBuiltins.cls"
::requires "MediaMethodologyExperiments.cls"
