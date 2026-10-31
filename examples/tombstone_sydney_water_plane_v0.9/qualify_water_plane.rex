/* Tombstone fixed-camera water-plane candidate qualifier v0.9.
   REXX, external observations only. Does NOT claim surveyed geometry exists.
   Numeric units: metres in projected planar CRS; no latitude/longitude input.
   A candidate passes only with independent withheld points and declared source.
*/
numeric digits 25
parse arg metadata controls holds output
if metadata='' | controls='' | holds='' | output='' then call fatal 'USAGE: metadata.psv controls.psv heldout.psv output.psv'
if output=metadata | output=controls | output=holds then call fatal 'output must differ from inputs'
if stream(output,'c','query exists')<>'' then call fatal 'output already exists; provide unique evidence filename'
if stream(metadata,'c','query exists')='' then call fatal 'metadata missing'
if linein(metadata)<>'key|value' then call fatal 'metadata header'
meta=.directory~new
allowed='mode image_width image_height crs unit source_reference source_sha256 max_error_m'
do while lines(metadata)>0
 row=linein(metadata)
 if row='' then iterate
 if countstr('|',row)<>1 then call fatal 'metadata columns'
 parse var row key '|' val
 if wordpos(key,allowed)=0 | val='' then call fatal 'metadata key or value'
 if meta~hasIndex(key) then call fatal 'metadata duplicate key'
 meta[key]=val
end
call stream metadata,'c','close'
if meta~items<>8 then call fatal 'metadata incomplete'
mode=meta['mode'];crs=meta['crs'];unit=meta['unit'];ref=meta['source_reference'];hash=meta['source_sha256']
if mode<>'SYNTHETIC' & mode<>'SURVEYED_CANDIDATE' then call fatal 'unsupported mode'
if unit<>'metre' then call fatal 'unit must be metre'
if left(crs,5)<>'EPSG:' | \datatype(substr(crs,6),'W') then call fatal 'projected EPSG required'
if crs='EPSG:4326' | crs='EPSG:4979' then call fatal 'geographic degrees are not projected metres'
if \datatype(meta['image_width'],'W') | \datatype(meta['image_height'],'W') then call fatal 'image dimensions must be whole numbers'
width=meta['image_width'];height=meta['image_height']
if width<32 | height<32 then call fatal 'image too small'
if \datatype(meta['max_error_m'],'N') then call fatal 'invalid maximum error'
limit=meta['max_error_m']
if limit<=0 then call fatal 'maximum error must be positive'
if mode='SYNTHETIC' then do
 if ref<>'SYNTHETIC_TEST' | hash<>'SYNTHETIC_NOT_A_REAL_FILE' | limit>0.01 then call fatal 'synthetic provenance or tolerance invalid'
end
else do
 if ref='SYNTHETIC_TEST' | length(ref)<8 | \validSha(hash) | limit>5 then call fatal 'surveyed candidate provenance/tolerance not admitted'
end
seen=.directory~new
cCount=0;hCount=0
call readPoints controls, 'CONTROL'
call readPoints holds, 'HOLDOUT'
if cCount<>4 then call fatal 'must have exactly four control points'
if hCount<3 then call fatal 'must have at least three independent holdouts'
/* Require points not confined to a thin perspective stripe. */
minU=cU.1;maxU=cU.1;minV=cV.1;maxV=cV.1
do j=2 to 4
 minU=min(minU,cU.j);maxU=max(maxU,cU.j)
 minV=min(minV,cV.j);maxV=max(maxV,cV.j)
end
if (maxU-minU)/width<0.08 | (maxV-minV)/height<0.07 then call fatal 'controls do not cover water-plane image area'
/* 4 points -> 8 equations. Pixel normalized to image dimensions. */
a=.array~new(8,9)
do j=1 to 4
 u=cU.j/width;v=cV.j/height;wx=cX.j;wy=cY.j
 r=2*j-1
 a[r,1]=u;a[r,2]=v;a[r,3]=1;a[r,4]=0;a[r,5]=0;a[r,6]=0;a[r,7]=-u*wx;a[r,8]=-v*wx;a[r,9]=wx
 r=2*j
 a[r,1]=0;a[r,2]=0;a[r,3]=0;a[r,4]=u;a[r,5]=v;a[r,6]=1;a[r,7]=-u*wy;a[r,8]=-v*wy;a[r,9]=wy
end
/* Partial-pivot elimination with column-relative zero diagnostics. */
do col=1 to 8
 best=col;maxPivot=abs(a[col,col])
 do r=col+1 to 8
  if abs(a[r,col])>maxPivot then do
   best=r;maxPivot=abs(a[r,col])
  end
 end
 if maxPivot<0.0000000000001 then call fatal 'degenerate control geometry / singular homography'
 if best<>col then do
  do c=col to 9
   tmp=a[col,c];a[col,c]=a[best,c];a[best,c]=tmp
  end
 end
 pv=a[col,col]
 do c=col to 9
  a[col,c]=a[col,c]/pv
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
do i=1 to 8
 h[i]=a[i,9]
end
h[9]=1
/* Check all anchors AND holdouts, with metre-valued residual and uncertainty. */
worst=0;mean=0;holdWorst=0;interior=0
do i=1 to 4
 u=cU.i/width;v=cV.i/height
 den=h[7]*u+h[8]*v+1
 if abs(den)<0.00000000001 then call fatal 'control projects to infinity'
 xx=(h[1]*u+h[2]*v+h[3])/den
 yy=(h[4]*u+h[5]*v+h[6])/den
 err=calcSqrt((xx-cX.i)**2+(yy-cY.i)**2)
 if err>0.000001 then call fatal 'control fit inconsistent'
end
do i=1 to hCount
 u=tU.i/width;v=tV.i/height
 den=h[7]*u+h[8]*v+1
 if abs(den)<0.00000000001 then call fatal 'holdout projects to infinity'
 xx=(h[1]*u+h[2]*v+h[3])/den
 yy=(h[4]*u+h[5]*v+h[6])/den
 err=calcSqrt((xx-tX.i)**2+(yy-tY.i)**2)
 worst=max(worst,err);mean=mean+err
 /* Each heldout must be compatible with its independently declared uncertainty,
    and all must fit the experiment's maximum error. */
 if err>limit | err>3*tUnc.i then call fatal 'holdout residual exceeds error/uncertainty budget'
 if tU.i>minU & tU.i<maxU & tV.i>minV & tV.i<maxV then interior=interior+1
end
if interior<2 then call fatal 'less than two heldouts within control image coverage'
mean=mean/hCount
if mode='SYNTHETIC' then state='SYNTHETIC_MATH_ONLY'
else state='SURVEYED_CANDIDATE_REQUIRES_INDEPENDENT_AUDIT'
/* Save exactly once only after all tests. No artifact for a rejected candidate. */
call stream output,'c','open write replace'
call lineout output,'key|value'
call lineout output,'status|'||state
call lineout output,'mode|'||mode
call lineout output,'source_reference|'||ref
call lineout output,'source_sha256|'||hash
call lineout output,'crs|'||crs
call lineout output,'image_width|'||width
call lineout output,'image_height|'||height
call lineout output,'control_count|4'
call lineout output,'holdout_count|'||hCount
call lineout output,'mean_holdout_error_m|'||mean
call lineout output,'max_holdout_error_m|'||worst
do i=1 to 9
 call lineout output,'h'||i||'|'||h[i]
end
call stream output,'c','close'
say 'TOMBSTONE WATER/0.9 PASS STATUS='state 'CONTROL=4 HOLDOUT='hCount 'MAX_ERROR_M='worst
exit 0
readPoints: procedure expose seen width height mode cCount hCount cU. cV. cX. cY. tU. tV. tX. tY. tUnc.
 parse arg file,kind
 if stream(file,'c','query exists')='' then call fatal 'missing point file'
 if linein(file)<>'point_id|u_px|v_px|east_m|north_m|uncertainty_m|source_id' then call fatal 'point header'
 do while lines(file)>0
  row=linein(file)
  if row='' then iterate
  if countstr('|',row)<>6 then call fatal 'point columns'
  parse var row id '|' u '|' v '|' x '|' y '|' unc '|' source
  if id='' | source='' | seen~hasIndex(id) then call fatal 'missing/duplicate point id or source'
  if \datatype(u,'N') | \datatype(v,'N') | \datatype(x,'N') | \datatype(y,'N') | \datatype(unc,'N') then call fatal 'nonnumeric coordinate'
  if u<0 | u>=width | v<0 | v>=height | unc<=0 then call fatal 'invalid pixel/uncertainty'
  if mode='SYNTHETIC' & source<>'SYNTHETIC' then call fatal 'synthetic point source mismatch'
  if mode='SURVEYED_CANDIDATE' & source='SYNTHETIC' then call fatal 'fabricated source not admitted'
  seen[id]=1
  if kind='CONTROL' then do
   cCount=cCount+1
   if cCount>4 then call fatal 'too many control points'
   cU.cCount=u;cV.cCount=v;cX.cCount=x;cY.cCount=y
  end
  else do
   hCount=hCount+1
   tU.hCount=u;tV.hCount=v;tX.hCount=x;tY.hCount=y;tUnc.hCount=unc
  end
 end
 call stream file,'c','close'
 return
calcSqrt: procedure
 parse arg value
 if value=0 then return 0
 guess=value
 if guess<1 then guess=1
 do forever
  next=(guess+value/guess)/2
  if next>=guess then leave
  guess=next
 end
 return guess
validSha: procedure
 parse arg s
 return length(s)=64 & verify(s,'0123456789abcdef')=0
fatal:
 parse arg msg
 say 'TOMBSTONE WATER/0.9 FAIL:' msg
 exit 2
