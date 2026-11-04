/* Sydney Harbour approximate image-water geometry v0.12.
   Camera axes from unsurveyed map+landmark fit, stored as input evidence.
   Converts video PIXEL contact points to rough metre ENU, native ooRexx.
   This is not a surveyed calibration, nor a vessel identity test.
 */
numeric digits 22
parse arg axesFile pixelsFile outputFile
if axesFile='' | pixelsFile='' | outputFile='' then call bad 'USAGE axes.psv pixels.psv out.psv'
if outputFile=axesFile | outputFile=pixelsFile then call bad 'output overwrites input'
vals=.directory~new
if stream(axesFile,'c','query exists')='' then call bad 'axes missing'
if linein(axesFile)<>'name|value' then call bad 'axes header invalid'
validNames='cam_e cam_n cam_height front_e front_n front_z right_e right_n right_z up_e up_n up_z center_u center_v focal_px'
do while lines(axesFile)>0
 line=linein(axesFile)
 if line='' then iterate
 if countstr('|',line)<>1 then call bad 'bad axes columns'
 parse var line key '|' val
 if wordpos(key,validNames)=0 | vals~hasIndex(key) then call bad 'unknown or duplicate axis'
 if \datatype(val,'N') then call bad 'nonnumeric axis'
 vals[key]=val
end
call stream axesFile,'c','close'
if vals~items<>15 then call bad 'incomplete axes'
if vals['cam_height']<=0 | vals['focal_px']<=100 then call bad 'invalid physical model'
if vals['center_u']<>960 | vals['center_v']<>540 then call bad 'unexpected camera principal point'
seen=.directory~new
if stream(pixelsFile,'c','query exists')='' then call bad 'pixels missing'
if linein(pixelsFile)<>'frame|time_s|u_px|v_px' then call bad 'pixels header invalid'
n=0
do while lines(pixelsFile)>0
 line=linein(pixelsFile)
 if line='' then iterate
 if countstr('|',line)<>3 then call bad 'pixels columns invalid'
 parse var line frame '|' tt '|' uu '|' vv
 if \datatype(frame,'W') | \datatype(tt,'N') | \datatype(uu,'N') | \datatype(vv,'N') then call bad 'pixels values invalid'
 if frame<0 | tt<0 | uu<0 | uu>=1920 | vv<0 | vv>=1080 then call bad 'pixels out of bounds'
 if seen~hasIndex(frame) then call bad 'duplicated frame'
 if n>0 then do
   if frame<=fr.n | tt<=t.n then call bad 'nonmonotonic chronology'
 end
 seen[frame]=1
 un=(uu-vals['center_u'])/vals['focal_px']
 vn=(vals['center_v']-vv)/vals['focal_px']
 rz=vals['front_z']+un*vals['right_z']+vn*vals['up_z']
 if rz>=-0.02 then call bad 'pixel above stable water-plane horizon'
 re=vals['front_e']+un*vals['right_e']+vn*vals['up_e']
 rn=vals['front_n']+un*vals['right_n']+vn*vals['up_n']
 distance=-vals['cam_height']/rz
 east=vals['cam_e']+distance*re
 north=vals['cam_n']+distance*rn
 n=n+1
 fr.n=frame;t.n=tt;u.n=uu;v.n=vv;e.n=east;north.n=north
end
call stream pixelsFile,'c','close'
if n<2 then call bad 'insufficient data'
call stream outputFile,'c','open write replace'
call lineout outputFile,'frame|time_s|u_px|v_px|east_m|north_m|step_m|speed_mps|geometry_state'
prevE=0;prevN=0;prevT=0
do j=1 to n
 if j=1 then do
  step='NA';speed='NA'
 end
 else do
  dx=e.j-prevE;dy=north.j-prevN
  step=calcSqrt(dx*dx+dy*dy)
  speed=step/(t.j-prevT)
 end
 call lineout outputFile,fr.j||'|'||t.j||'|'||u.j||'|'||v.j||'|'||e.j||'|'||north.j||'|'||step||'|'||speed||'|APPROXIMATE_UNSURVEYED'
 prevE=e.j;prevN=north.j;prevT=t.j
end
call stream outputFile,'c','close'
say 'TOMBSTONE GEO v0.12 PASS n='n 'APPROXIMATE_UNSURVEYED'
exit 0
calcSqrt: procedure
 parse arg input
 if input<=0 then return 0
 guess=input
 if guess<1 then guess=1
 do 1000
  next=(guess+input/guess)/2
  if next>=guess then return guess
  guess=next
 end
 return guess
bad: procedure
 parse arg message
 say 'TOMBSTONE GEO v0.12 REJECT:' message
 exit 2
