/* Four ground-plane correspondences -> exact 8-parameter planar homography.
   Requires camera image pixels u,v and independently surveyed flat-water X,Y.
   NO unknown camera/world coordinates are inferred. Outputs only ground-plane
   coordinate mapping; never warp a 3-D ferry hull with the water homography.
*/
numeric digits 20
parse arg controlsFile validationFile
if controlsFile='' | validationFile='' then do
 say 'USAGE: rexx calibrate_water_plane.rex control.psv holdout.psv'
 exit 2
end
n=0
a=.array~new(8,9)
if stream(controlsFile,'c','query exists')='' then call fatal 'missing controls'
header=linein(controlsFile)
if header<>'u|v|X|Y' then call fatal 'control header'
do while lines(controlsFile)>0
 rec=linein(controlsFile)
 if rec='' then iterate
 parse var rec u '|' v '|' wx '|' wy
 if \datatype(u,'N') | \datatype(v,'N') | \datatype(wx,'N') | \datatype(wy,'N') then call fatal 'non-numeric control'
 n=n+1
 if n>4 then call fatal 'exact calibration takes four points'
 r=2*n-1
 a[r,1]=u; a[r,2]=v; a[r,3]=1; a[r,4]=0; a[r,5]=0; a[r,6]=0; a[r,7]=-u*wx; a[r,8]=-v*wx; a[r,9]=wx
 r=2*n
 a[r,1]=0; a[r,2]=0; a[r,3]=0; a[r,4]=u; a[r,5]=v; a[r,6]=1; a[r,7]=-u*wy; a[r,8]=-v*wy; a[r,9]=wy
end
call stream controlsFile,'c','close'
if n<>4 then call fatal 'requires exactly four water-plane controls'
/* Pivoted Gaussian elimination. Fail closed on singular matrix. */
do col=1 to 8
 best=col;maxPivot=abs(a[col,col])
 do r=col+1 to 8
  if abs(a[r,col])>maxPivot then do
   best=r; maxPivot=abs(a[r,col])
  end
 end
 if maxPivot<0.000000000001 then call fatal 'singular or nearly singular controls'
 if best<>col then do
  do c=col to 9
   temp=a[col,c]; a[col,c]=a[best,c]; a[best,c]=temp
  end
 end
 pivot=a[col,col]
 do c=col to 9
  a[col,c]=a[col,c]/pivot
 end
 do r=1 to 8
  if r=col then iterate
  factor=a[r,col]
  do c=col to 9
   a[r,c]=a[r,c]-factor*a[col,c]
  end
 end
end
h=.array~new(9)
do r=1 to 8
 h[r]=a[r,9]
end
h[9]=1
say 'PLANAR_H='h[1] h[2] h[3] '/' h[4] h[5] h[6] '/' h[7] h[8] h[9]
if stream(validationFile,'c','query exists')='' then call fatal 'missing holdout'
if linein(validationFile)<>'u|v|X|Y' then call fatal 'holdout header'
held=0;worst=0
do while lines(validationFile)>0
 rec=linein(validationFile)
 if rec='' then iterate
 parse var rec u '|' v '|' wx '|' wy
 if \datatype(u,'N') | \datatype(v,'N') | \datatype(wx,'N') | \datatype(wy,'N') then call fatal 'non-numeric holdout'
 den=h[7]*u+h[8]*v+1
 if abs(den)<0.000000000001 then call fatal 'singular projected holdout'
 px=(h[1]*u+h[2]*v+h[3])/den
 py=(h[4]*u+h[5]*v+h[6])/den
 dx=abs(px-wx);dy=abs(py-wy)
 if dx>worst then worst=dx
 if dy>worst then worst=dy
 held=held+1
end
call stream validationFile,'c','close'
if held=0 then call fatal 'no unseen validation points'
say 'HOLDOUT_COUNT='held 'MAX_ABSOLUTE_COORD_ERROR='worst
/* Coordinate tolerance is synthetic qualification only. Real calibration must
   set its accuracy in surveyed units and validate independently. */
if worst>0.000001 then call fatal 'holdout reprojection error too large'
say 'WATER-PLANE HOMOGRAPHY MATH: PASS (SYNTHETIC ONLY)'
exit 0
fatal:
 parse arg msg
 say 'WATER-PLANE HOMOGRAPHY: FAIL:' msg
 exit 2
