call addPath
scene=.Wire3DScene~new('corporate-city','ALCHEMY SYSTEMS / OPERATIONS DISTRICT')
storage=.Wire3DSpatialContainer~new('storage','storage.fabric://root',.Wire3DRepresentation~new('facility','STORAGE FABRIC','infrastructure'))~moveTo(-3,0,0)
compute=.Wire3DSpatialContainer~new('compute','job.node://estate',.Wire3DRepresentation~new('facility','COMPUTE AUTHORITY','infrastructure'))~moveTo(3,0,0)
ai=.Wire3DAIProjection~new('analyst-07','demo-agent','ai://analyst-07','LOCAL','OBSERVE')~moveTo(0,0,-2)
scene~add(storage); scene~add(compute); scene~add(ai)
scene~connect(ai,storage,'observes')~signal('active')
scene~connect(ai,compute,'access-denied')~signal('blocked')

/* The semantic snapshot stays renderer-neutral.  This demo then adds an explicit
   renderer contract generated through Maths v0.8.  JavaScript does not invent
   model or view transforms. */
snapshot=scene~snapshot
objects=.directory~new
objects[storage~spatialId]=storage; objects[compute~spatialId]=compute; objects[ai~spatialId]=ai
do nd over snapshot['nodes']
  object=objects[nd['id']]
  nd['modelMatrix']=.Wire3DMathsAdapter~columnMajor(.Wire3DMathsAdapter~transform(object~transform))
end
camera=.Wire3DSpatialCamera~new(.Wire3DVector3~new(0,4,12),.Wire3DVector3~new(0,0,0))
cd=camera~asDirectory
cd['viewMatrix']=.Wire3DMathsAdapter~columnMajor(camera~viewTransform)
snapshot['camera']=cd
contract=.directory~new
contract['matrixStorage']='COLUMN_MAJOR'; contract['vectorConvention']='COLUMN_VECTOR'; contract['clipConvention']='OPENGL'
contract['projectionAuthority']='VIEWPORT_ADAPTER'; contract['mathAuthority']='OOREXX_MATHS_V0.8'
snapshot['rendererContract']=contract
tracking=.Wire3DTrackingField~new('4A91C37D')
snapshot['trackingField']=tracking~asDirectory
json=.JSON~new~toJSON(snapshot)
out=value('WIRE3D_SCENE_OUT',,'ENVIRONMENT')
if out='' then out='web/scene.json'; call stream out,'c','open write replace'; call charout out,json; call stream out,'c','close'
say 'Wrote' out
exit 0
addPath: procedure
  here=filespec('location',parse source . . src)
  call value 'REXX_PATH', here'../src:'value('REXX_PATH',,'ENVIRONMENT'),'ENVIRONMENT'
  return

::requires 'Wire3DAll.cls'
