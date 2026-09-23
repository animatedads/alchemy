ctx=.MathContext~decimal(40)
grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(0,0,0,ctx),1,3)
/* three neighbouring observed points at level 1 => 0.5 cell size */
ignored=grid~observePoint(.MathVector3~new(.1,.1,.1,ctx),.Vision3DState~observedOccupied,1,'A',1)
ignored=grid~observePoint(.MathVector3~new(.6,.1,.1,ctx),.Vision3DState~observedOccupied,1,'B',1)
ignored=grid~observePoint(.MathVector3~new(.1,.6,.1,ctx),.Vision3DState~observedOccupied,1,'C',1)
projection=.Vision3DWireProjection~new(grid,'facet-test','FACET TEST')
call assert projection~projectGrid=3,'three observed cells projected'
call assert projection~projectFacets(2.25,.05)>=1,'local observed cells produce inferred facet'
snapshot=projection~snapshot
found=.false
do nd over snapshot['nodes']
  if nd['representation']['kind']='vision-facet' then do
    found=.true
    call assert nd['metadata']['evidenceState']='INFERRED_SURFACE','facet remains explicitly inferred'
    call assert nd['metadata']['geometry']['primitive']='TRIANGLE','facet carries triangle geometry'
    call assert nd['metadata']['geometry']['vertices']~items=9,'facet carries three local vertices'
  end
end
call assert found,'snapshot contains vision-facet node'
say 'PASS Vision3D inferred surface facets -> Wire3D semantic geometry'
exit 0
assert: procedure
  parse arg ok,message
  if \ok then do; say 'FAIL' message; exit 1; end
  say 'PASS' message
  return
::requires 'Vision3DWireProjection.cls'
