ctx=.MathContext~decimal(40)
grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(0,0,0,ctx),1,3)
point=.MathVector3~new(1.2,2.2,-3.2,ctx)
cell=grid~observePoint(point,.Vision3DState~inferredSurface,.6,'LOW',1,'OBJECT-A')
projection=.Vision3DWireProjection~new(grid,'vision-test','VISION TEST')
call assert projection~projectGrid=1,'one inferred cell projected'
snapshot=projection~snapshot
call assert snapshot['protocol']='WIRE-3D/0.1','Wire3D snapshot protocol'
call assert snapshot['rendererContract']['mathAuthority']='OOREXX_MATHS_V0.8','Maths authority'
call assert snapshot['nodes']~items=1,'one node in snapshot'
node=snapshot['nodes'][1]
call assert node['metadata']['evidenceState']='INFERRED_SURFACE','evidence state retained'
call assert node['representation']['classification']='evidence-inferred','inferred classification'
call assert node['modelMatrix']~items=16,'authoritative model matrix'

/* Refine the same spatial cell with directly observed evidence.  The live
   adapter must issue UPDATE_NODE rather than inventing a second object. */
ignored=cell~addEvidence(.Vision3DState~observedOccupied,1,'HIGH','OBJECT-A')
delta=projection~deltaForChanges
call assert delta\==.nil,'evidence refinement produced delta'
dd=delta~asDirectory
call assert dd['baseRevision']=snapshot['revision'],'delta revision fenced to snapshot'
call assert dd['operations']~items=1,'one update operation'
call assert dd['operations'][1]['op']='UPDATE_NODE','same cell updated in place'
call assert dd['operations'][1]['payload']['metadata']['evidenceState']='OBSERVED_OCCUPIED','observed state projected'
call assert dd['operations'][1]['payload']['modelMatrix']~items=16,'delta carries authoritative model matrix'
say 'PASS Vision3D -> Wire3D snapshot + evidence refinement delta'
exit 0
assert: procedure
  parse arg ok,message
  if \ok then do; say 'FAIL' message; exit 1; end
  say 'PASS' message
  return
::requires 'Vision3DWireProjection.cls'
