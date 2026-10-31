/* Qualify local ground-plane derivatives of an already-qualified H.
   THESE DERIVATIVES APPLY TO WATER-CONTACT POINTS, NOT A 3-D HULL.
   A SYNTHETIC status propagates unchanged; no metre/pixel claim for Sydney.
*/
numeric digits 25
parse arg hfile pointsfile outfile
if hfile='' | pointsfile='' | outfile='' then call fatal 'USAGE: homography.psv sample_pixels.psv results.psv'
if hfile=outfile | pointsfile=outfile then call fatal 'output must differ from inputs'
if stream(outfile,'c','query exists')<>'' then call fatal 'output exists'
if stream(hfile,'c','query exists')='' then call fatal 'homography input missing'
if linein(hfile)<>'key|value' then call fatal 'homography header'
props=.directory~new
do while lines(hfile)>0
 rec=linein(hfile)
 if rec='' then iterate
 if countstr('|',rec)<>1 then call fatal 'homography columns'
 parse var rec key '|' val
 if props~hasIndex(key) | key='' | val='' then call fatal 'duplicate/blank homography property'
 props[key]=val
end
call stream hfile,'c','close'
if \props~hasIndex('status') | \props~hasIndex('mode') then call fatal 'missing status/mode'
status=props['status'];mode=props['mode']
if status<>'SYNTHETIC_MATH_ONLY' & status<>'SURVEYED_CANDIDATE_REQUIRES_INDEPENDENT_AUDIT' then call fatal 'unqualified homography'
if mode='SYNTHETIC' & status<>'SYNTHETIC_MATH_ONLY' then call fatal 'mode/status contradiction'
if mode='SURVEYED_CANDIDATE' & status<>'SURVEYED_CANDIDATE_REQUIRES_INDEPENDENT_AUDIT' then call fatal 'mode/status contradiction'
if mode<>'SYNTHETIC' & mode<>'SURVEYED_CANDIDATE' then call fatal 'unknown mode'
if \props~hasIndex('image_width') | \props~hasIndex('image_height') then call fatal 'missing dimensions'
if \datatype(props['image_width'],'W') | \datatype(props['image_height'],'W') then call fatal 'invalid dimensions'
w=props['image_width'];height=props['image_height']
if w<32 | height<32 then call fatal 'image dimensions out of range'
h=.array~new(9)
do i=1 to 9
 key='h'||i
 if \props~hasIndex(key) then call fatal 'homography coefficient missing'
 if \datatype(props[key],'N') then call fatal 'nonnumeric coefficient'
 h[i]=props[key]
end
if abs(h[9]-1)>0.00000000001 then call fatal 'unnormalized homography'
if stream(pointsfile,'c','query exists')='' then call fatal 'sample pixels missing'
if linein(pointsfile)<>'point_id|u_px|v_px' then call fatal 'pixels header'
n=0;ids=.directory~new
do while lines(pointsfile)>0
 rec=linein(pointsfile)
 if rec='' then iterate
 if countstr('|',rec)<>2 then call fatal 'pixel columns'
 parse var rec pid '|' up '|' vp
 if pid='' | ids~hasIndex(pid) then call fatal 'duplicate/blank sample ID'
 if \datatype(up,'N') | \datatype(vp,'N') then call fatal 'non-numeric sample'
 if up<0 | vp<0 | up>=w | vp>=height then call fatal 'sample outside image'
 ids[pid]=1;n=n+1
 id.n=pid;us.n=up;vs.n=vp
end
call stream pointsfile,'c','close'
if n=0 then call fatal 'no samples'
/* Validate every point before writing results. */
do i=1 to n
 u=us.i/w;v=vs.i/height
 den=h[7]*u+h[8]*v+1
 if abs(den)<0.000000000001 then call fatal 'singular sample denominator'
 nx=h[1]*u+h[2]*v+h[3];ny=h[4]*u+h[5]*v+h[6]
 wx=(nx/den);wy=(ny/den)
 j11=(h[1]*den-h[7]*nx)/(den*den*w)
 j12=(h[2]*den-h[8]*nx)/(den*den*height)
 j21=(h[4]*den-h[7]*ny)/(den*den*w)
 j22=(h[5]*den-h[8]*ny)/(den*den*height)
 determinant=j11*j22-j12*j21
 if abs(determinant)<0.000000000001 then call fatal 'singular local mapping / area'
 /* Negative determinant is mirrored image coordinates; absolute area is used. */
 area=abs(determinant)
 scale=calcSqrt(area)
 X.i=wx;Y.i=wy;J11.i=j11;J12.i=j12;J21.i=j21;J22.i=j22;Area.i=area;Scale.i=scale
end
call stream outfile,'c','open write replace'
call lineout outfile,'point_id|east_m|north_m|dX_du_mpx|dX_dv_mpx|dY_du_mpx|dY_dv_mpx|area_m2_per_px2|geometric_mean_m_per_px|status'
do i=1 to n
 call lineout outfile,id.i||'|'||X.i||'|'||Y.i||'|'||J11.i||'|'||J12.i||'|'||J21.i||'|'||J22.i||'|'||Area.i||'|'||Scale.i||'|'||status
end
call stream outfile,'c','close'
say 'TOMBSTONE PIXEL METRIC/0.9 PASS POINTS='n 'STATUS='status
exit 0
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
fatal:
 parse arg msg
 say 'TOMBSTONE PIXEL METRIC/0.9 FAIL:' msg
 exit 2
