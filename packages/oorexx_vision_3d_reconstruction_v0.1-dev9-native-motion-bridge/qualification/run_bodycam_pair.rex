/* Qualification fixture from the user's opportunistic/body-worn-style clip.
 *
 * 9.0s -> 10.0s was selected by the low-resolution probe as a strong pair.
 * The fixture contains approximate pinhole intrinsics, an externally measured
 * two-view relative pose, and 40 inlier pixel correspondences.  ooRexx owns
 * ray construction, closest-ray triangulation, acceptance and sparse grid state.
 */
parse source . . thisFile
here=filespec('L',thisFile)
fixture=here || 'bodycam_pair_9_10.tsv'
ctx=.MathContext~decimal(40)
conv=.Math3DConvention~openGL

line=linein(fixture)
clean=translate(line,' ','09'x)
width=word(clean,3); height=word(clean,5); fx=word(clean,7); fy=word(clean,9); cx=word(clean,11); cy=word(clean,13)
line=linein(fixture)
clean=translate(line,' ','09'x)
vals=.array~new
 do i=2 to 17; vals~append(word(clean,i)); end
rows=.array~of( -
  .array~of(vals[1],vals[2],vals[3],vals[4]), -
  .array~of(vals[5],vals[6],vals[7],vals[8]), -
  .array~of(vals[9],vals[10],vals[11],vals[12]), -
  .array~of(vals[13],vals[14],vals[15],vals[16]))
pose1=.MathTransform3D~identity(ctx,conv)
pose2=.MathTransform3D~new(.MathMatrix4~new(rows,ctx),ctx,conv)
cam=.Vision3DCameraModel~new(width,height,fx,fy,cx,cy,ctx,conv,'BODYCAM-APPROX')
ignored=linein(fixture) /* STATS */
ignored=linein(fixture) /* header */

grid=.VisionAdaptiveGrid3D~new(.MathVector3~new(-50,-50,-50,ctx),.25,4)
recon=.Vision3DReconstruction~new(grid,.05)
count=0; sepTotal=0; sepMax=0
 do while lines(fixture)>0
   line=linein(fixture)
   if strip(line)='' then iterate
   clean=translate(line,' ','09'x)
   if word(clean,1)<>'MATCH' then iterate
   ax=word(clean,2); ay=word(clean,3); bx=word(clean,4); by=word(clean,5)
   a=cam~observationForPixel('1000060474.mp4',9.0,'t9',ax,ay,pose1,1,'PAIR9-10','SCENE')
   b=cam~observationForPixel('1000060474.mp4',10.0,'t10',bx,by,pose2,1,'PAIR9-10','SCENE')
   tri=recon~triangulate(a,b,'SCENE',1)
   if tri~separation\==.nil then do
     count=count+1; sepTotal=sepTotal+tri~separation
     if tri~separation>sepMax then sepMax=tri~separation
   end
 end
call lineout fixture
say 'BODYCAM_PAIR_9_10 matches='count 'accepted='recon~accepted 'rejected='recon~rejected
say 'BODYCAM_PAIR_9_10 meanRaySeparation='sepTotal/count 'maxRaySeparation='sepMax
say 'BODYCAM_PAIR_9_10 occupiedCells='grid~countState(.Vision3DState~observedOccupied)
ply=here || 'bodycam_pair_9_10_oorexx_grid.ply'
written=.Vision3DPlyExporter~new~export(grid,ply)
say 'BODYCAM_PAIR_9_10 diagnosticPlyCells='written
if count<>40 then do; say 'FAIL fixture match count'; exit 1; end
if recon~accepted<35 then do; say 'FAIL too few accepted real-video triangulations'; exit 1; end
say 'PASS bodycam real-video pair -> ooRexx Maths v0.8 rays -> sparse Vision 3D grid'
exit 0
::requires 'Vision3DReconstruction.cls'
