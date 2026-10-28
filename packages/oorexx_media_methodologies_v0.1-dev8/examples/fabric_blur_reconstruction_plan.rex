methods=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(methods)
shapes=.MediaWorkShapeCatalogue~new
.MediaWorkShapeBuiltins~populate(shapes,methods)
shape=shapes~shape("VIDEO.RECON.LEADING_EDGE_BACKPROJECTION")
plan=.MediaMethodologyExecutionPlanner~new~partition(shape,1,300,100,"FRAME")
say "METHOD" shape~methodologyId
say "STATE " shape~stateModel
say "MERGE " shape~mergeMode
say "UNITS " plan~count
do u over plan~units
  say u~workId "core="u~coreFirst".."u~coreLast "read="u~readFirst".."u~readLast
end
say "Output authority belongs to core ranges; halo frames are supporting reads."
say "Every reconstruction output remains a candidate and retains source support."
::requires "MediaMethodologies.cls"
::requires "MediaMethodologyBuiltins.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaWorkShapeBuiltins.cls"
