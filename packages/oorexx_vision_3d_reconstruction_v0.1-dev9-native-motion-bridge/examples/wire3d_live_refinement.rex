/* Minimal live-refinement contract: snapshot an inferred cell, then strengthen
   the same cell with observed evidence and emit one revision-fenced UPDATE_NODE. */
ctx=.MathContext~decimal(40)
grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(0,0,0,ctx),1,3)
cell=grid~observePoint(.MathVector3~new(1.2,2.2,-3.2,ctx),.Vision3DState~inferredSurface,.5,'coarse',0,'object')
view=.Vision3DWireProjection~new(grid,'refinement-demo')
ignored=view~projectGrid
snapshot=view~snapshot
say .JSON~new~toJSON(snapshot)
ignored=cell~addEvidence(.Vision3DState~observedOccupied,1,'enhanced','object')
delta=view~deltaForChanges
if delta\==.nil then say .JSON~new~toJSON(delta~asDirectory)
::requires 'Vision3DWireProjection.cls'
