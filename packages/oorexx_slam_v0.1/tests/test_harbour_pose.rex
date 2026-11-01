/* Power SLAM harbour pose: deliberately synthetic image observations, NOT claimed
   measured pose for the live Sydney screenshots. ooRexx 5.3.0 r13196. */
parse arg outputDir
if outputDir='' then outputDir='.'
numeric digits 20
checks=0
scene=.HarbourScene~new
mask=.HarbourLandMask~new
/* DEMONSTRATION land-only regions, not a georeferenced complete coastline.
   In production, replace with surveyed raster/vector land/water polygons.
   Each rectangle is deliberately near a known dry-land location. */
mask~addRect(-1500,-1200,325,625,'Waverton / Balls Head coarse')
mask~addRect(500,600,170,270,'Kirribilli / Mary Booth coarse')
mask~addRect(20,145,-1225,-1025,'Circular Quay / Customs House coarse')
call check mask~contains(150,-200)=.false,'mid-harbour water is rejected'
call check mask~contains(-1400,425),'western land admitted'
call check mask~contains(550,220),'northeastern land admitted'
call check mask~contains(70,-1125),'Customs House land admitted'
/* A georeferenced raster dominates demonstration land patches and rejects
   blue and unknown cells. This tests the user's central admission rule. */
mapfile=outputDir || '/landmask_test.txt'
call SysFileDelete mapfile
call lineout mapfile,'HARBOUR_LAND_MASK_V1 4 3'
call lineout mapfile,'LLBB'
call lineout mapfile,'BXBB'
call lineout mapfile,'BBLL'
call stream mapfile,'C','CLOSE'
mapmask=.HarbourLandMask~new
mapmask~addRect(0,400,0,300,'should be overridden by raster')
mapmask~loadRasterAscii(mapfile,0,400,0,300)
call check mapmask~contains(25,275),'land pixel admitted by georeferenced raster'
call check \mapmask~contains(250,275),'blue water pixel rejected'
call check \mapmask~contains(125,150),'unknown pixel rejected'
call check mapmask~contains(350,25),'southern land pixel admitted'
call check \mapmask~contains(450,150),'outside image rejected'
call check scene~boxes~items=6,'four pylon boxes, one deck box, one Opera House box'
n=scene~features['N'];s=scene~features['S'];o=scene~features['O']
call check o[1]>s[1] & o[2]<s[2],'Opera House lies east and south of the southern bridge pylons'
/* The three screenshot silhouettes are hand-annotated left-to-right as:
   image 1  N-O-S; image 2 O-S-N; image 3 S-N (Opera off-screen).
   Only land cells are counted; no camera location is presumed known. */
call check scene~inOrder(-1400,425,.array~of('N','O','S')),'western synthetic site has image 1 order'
call check scene~inOrder(550,225,.array~of('O','S','N')),'northeastern synthetic site has image 2 order'
call check scene~inOrder(75,-1125,.array~of('S','N')),'southern synthetic site has image 3 order'
call check scene~countLandInOrder(mask,.array~of('N','O','S'))>0,'image 1 order has at least one admissible land location'
call check scene~countLandInOrder(mask,.array~of('O','S','N'))>0,'image 2 order has at least one admissible land location'
call check scene~countLandInOrder(mask,.array~of('S','N'))>0,'image 3 order has at least one admissible land location'
/* Camera coordinates are chosen to land exactly on a 25 m candidate grid.
   The truth is withheld from the solver: only projected image landmarks enter. */
w=1200; h=700; focal=900
poses=.array~of( -1400,425,550,225,75,-1125 )
labels=.array~of('western','northeastern','southern')
do i=1 to 3
  cx=poses[2*i-1];cy=poses[2*i]
  land=.array~of(cx,cy,16)
  forward=scene~aim(scene~features['D'],cx,cy,600,focal,w)
  obs=scene~observe(land,forward,focal,w,h,62)
  call check obs<>.nil,'synthetic' labels[i] 'view contains three landmarks'
  outcome=scene~fit(mask,obs,focal,w,h,16,25,6)
  call check outcome['STATUS']=='RANKED_NOT_UNIQUE','ranked locations returned for' labels[i]
  call check outcome['WATER_REJECTED']>0,'water excluded before fit for' labels[i]
  best=outcome['BEST'][1]
  dist=HSqrt((best[2]-cx)**2+(best[3]-cy)**2)
  call check dist<=25,'synthetic camera recovered within 25m for' labels[i] '(error' dist 'm)'
  call check best[1]<0.00001,'synthetic observations fit without reprojection error for' labels[i]
  say labels[i] 'land evaluated' outcome['LAND_EVALUATED'] 'water excluded' outcome['WATER_REJECTED'] 'best x y' best[2] best[3] 'pixel residual square' best[1]
  scene~writeSvg(outputDir || '/' || labels[i] || '.svg',land,forward,focal,w,h,62)
end
/* A water-based virtual camera must not be admitted by nearest-best selection. */
water=.array~of(1000,0,16)
forward=scene~aim(scene~features['D'],1000,0,600,focal,w)
obs=scene~observe(water,forward,focal,w,h,62)
call check obs<>.nil,'waterborne control can see all three landmarks'
outcome=scene~fit(mask,obs,focal,w,h,16,25,6,0.1)
call check outcome['STATUS']=='NO_GEOMETRIC_FIT','no land solution fabricates a water-camera fit'
/* 3D image geometry must be rejected if constraints are grossly inconsistent. */
obs=.array~of(.array~of('N',100,200),.array~of('S',900,100),.array~of('O',100000,400))
outcome=scene~fit(mask,obs,focal,w,h,16,25,6,1)
call check outcome['STATUS']=='NO_GEOMETRIC_FIT','grossly impossible pixels rejected by RMS threshold'
say 'POWER SLAM HARBOUR TEST: PASS (' || checks || ' checks)'
exit 0
check: procedure expose checks
 use arg ok,label
 checks+=1
 if ok then say 'PASS' label
 else do; say 'FAIL' label; exit 1;end
 return
::requires 'SlamHarbourPose.cls'
