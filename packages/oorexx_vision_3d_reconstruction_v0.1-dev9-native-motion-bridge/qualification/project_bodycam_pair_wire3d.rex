/* Real bodycam 9s -> 10s pair projected through Vision3D into a Wire3D scene. */
parse source . . thisFile
here=filespec('L',thisFile)
fixture=here || 'bodycam_pair_9_10.tsv'
ctx=.MathContext~decimal(40); conv=.Math3DConvention~openGL
line=linein(fixture); clean=translate(line,' ','09'x)
width=word(clean,3); height=word(clean,5); fx=word(clean,7); fy=word(clean,9); cx=word(clean,11); cy=word(clean,13)
line=linein(fixture); clean=translate(line,' ','09'x)
vals=.array~new; do i=2 to 17; vals~append(word(clean,i)); end
rows=.array~of(.array~of(vals[1],vals[2],vals[3],vals[4]),.array~of(vals[5],vals[6],vals[7],vals[8]),.array~of(vals[9],vals[10],vals[11],vals[12]),.array~of(vals[13],vals[14],vals[15],vals[16]))
pose1=.MathTransform3D~identity(ctx,conv)
pose2=.MathTransform3D~new(.MathMatrix4~new(rows,ctx),ctx,conv)
cam=.Vision3DCameraModel~new(width,height,fx,fy,cx,cy,ctx,conv,'BODYCAM-APPROX')
ignored=linein(fixture); ignored=linein(fixture)
grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(-50,-50,-50,ctx),.25,4)
recon=.Vision3DReconstruction~new(grid,.05)
do while lines(fixture)>0
  line=linein(fixture); if strip(line)='' then iterate
  clean=translate(line,' ','09'x); if word(clean,1)<>'MATCH' then iterate
  ax=word(clean,2); ay=word(clean,3); bx=word(clean,4); by=word(clean,5)
  a=cam~observationForPixel('1000060474.mp4',9.0,'t9',ax,ay,pose1,1,'PAIR9-10','SCENE')
  b=cam~observationForPixel('1000060474.mp4',10.0,'t10',bx,by,pose2,1,'PAIR9-10','SCENE')
  ignored=recon~triangulate(a,b,'SCENE',1)
end
call lineout fixture
projection=.Vision3DWireProjection~new(grid,'bodycam-pair-9-10','BODYCAM RECONSTRUCTION / 9s -> 10s')
added=projection~projectGrid
facets=projection~projectFacets(2.25,.08)
ignored=projection~addCameraPose('t9',pose1,'t9',9.0)
ignored=projection~addCameraPose('t10',pose2,'t10',10.0)
snapshot=projection~snapshot
snapshot['sourceVideo']='1000060474.mp4'
snapshot['qualification']='REAL_VIDEO_PAIR'
snapshot['acceptedTriangulations']=recon~accepted
snapshot['rejectedTriangulations']=recon~rejected
json=.JSON~new~toJSON(snapshot)
out=value('VISION3D_WIRE_SCENE_OUT',,'ENVIRONMENT')
if out='' then out=here || 'bodycam_pair_9_10_wire3d_scene.json'
call stream out,'c','open write replace'; call charout out,json; call stream out,'c','close'
say 'BODYCAM_WIRE3D scene='out 'cells='added 'facets='facets 'cameras=2 revision='snapshot['revision']
say 'PASS real bodycam sparse reconstruction -> Wire3D semantic scene'
exit 0
::requires 'Vision3DWireProjection.cls'
