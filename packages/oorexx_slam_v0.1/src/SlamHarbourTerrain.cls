/* Power SLAM Harbour v0.22 -- independent stitched DEM tile interface.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6.
 * This is not an NSW DEM download. Only externally georegistered numeric
 * tiles may be admitted. Strict CRS, frame, vertical datum, and nodata rules.
 */
::requires 'SlamHarbourOcclusion.cls'

::class HarbourTerrainTile public
::attribute source get
::attribute datum get
::attribute frame get
::attribute crs get
::attribute uncertainty get
::attribute rows get
::attribute columns get
::method init
  expose source datum frame crs uncertainty rows columns cells ox oy ex ey rx ry det stepSize
  use strict arg file
  header=linein(file)~strip
  if header\=='HARBOUR_TERRAIN_TILE_V1' then raise syntax 88.900 array('unknown DEM tile encoding')
  line=linein(file)~strip
  parse var line tag crs extra
  if tag\=='CRS' | crs\=='SLAM_LOCAL_ENU_V1' | extra\=='' then raise syntax 88.900 array('unresolved horizontal CRS')
  line=linein(file)~strip
  parse var line tag frame extra
  if tag\=='FRAME' | frame\=='SCENE_33.852S_151.210E' | extra\=='' then raise syntax 88.900 array('unresolved local frame')
  line=linein(file)~strip
  parse var line tag datum extra
  if tag\=='DATUM' | datum\=='AHD' | extra\=='' then raise syntax 88.900 array('unresolved DEM vertical datum')
  line=linein(file)~strip
  parse var line tag source extra
  if tag\=='SOURCE' | source=='' | extra\=='' then raise syntax 88.900 array('missing tile provenance')
  line=linein(file)~strip
  parse var line tag uncertainty extra
  if tag\=='UNCERTAINTY_M' | \datatype(uncertainty,'N') | extra\=='' then raise syntax 88.900 array('unknown height uncertainty')
  if uncertainty<0 then raise syntax 88.900 array('negative vertical uncertainty')
  line=linein(file)~strip
  parse var line tag ox oy extra
  if tag\=='ORIGIN' | \datatype(ox,'N') | \datatype(oy,'N') | extra\=='' then raise syntax 88.900 array('invalid origin')
  line=linein(file)~strip
  parse var line tag ex ey extra
  if tag\=='COL_VECTOR' | \datatype(ex,'N') | \datatype(ey,'N') | extra\=='' then raise syntax 88.900 array('invalid east axis')
  line=linein(file)~strip
  parse var line tag rx ry extra
  if tag\=='ROW_VECTOR' | \datatype(rx,'N') | \datatype(ry,'N') | extra\=='' then raise syntax 88.900 array('invalid row axis')
  det=ex*ry-ey*rx
  if abs(det)<0.001 then raise syntax 88.900 array('degenerate tile affine transform')
  stepSize=min(HSqrt(ex*ex+ey*ey),HSqrt(rx*rx+ry*ry))
  if stepSize<0.1 | stepSize>1000 then raise syntax 88.900 array('implausible grid resolution')
  line=linein(file)~strip
  parse var line tag columns rows extra
  if tag\=='SIZE' | \datatype(columns,'W') | \datatype(rows,'W') | extra\=='' then raise syntax 88.900 array('invalid tile size')
  if columns<2 | rows<2 | columns>10000 | rows>10000 then raise syntax 88.900 array('tile dimensions outside limits')
  cells=.array~new
  do row=1 to rows
    line=linein(file)~strip
    if line~words<>columns then raise syntax 88.900 array('incomplete DEM grid row')
    rr=.array~new
    do col=1 to columns
      token=line~word(col)
      if token=='W' | token=='X' then nop
      else do
        if token~left(2)\=='L:' then raise syntax 88.900 array('unknown DEM cell role')
        v=token~substr(3)
        if \datatype(v,'N') then raise syntax 88.900 array('invalid DEM height')
        if v < -300 | v > 9000 then raise syntax 88.900 array('invalid DEM height range')
      end
      rr~append(token)
    end
    cells~append(rr)
  end
  /* No extra records are accepted, avoiding silent tile concatenation. */
  if lines(file)>0 then do
    tail=linein(file)~strip
    if tail\=='' then raise syntax 88.900 array('trailing DEM tile records')
  end
  call stream file,'C','CLOSE'
::method resolution
  expose stepSize
  return stepSize
::method sample
  expose cells ox oy ex ey rx ry det rows columns
  use strict arg x,y
  u=((x-ox)*ry-(y-oy)*rx)/det
  v=((y-oy)*ex-(x-ox)*ey)/det
  r=.directory~new
  r['STATUS']='UNKNOWN_OUTSIDE_TILE'
  r['HEIGHT_M']='UNKNOWN'
  r['ROLE']='X'
  if u<(-0.5) | v<(-0.5) | u>(columns-0.5) | v>(rows-0.5) then return r
  col=trunc(u+0.5)+1;row=trunc(v+0.5)+1
  if col<1 | col>columns | row<1 | row>rows then return r
  cell=cells[row][col]
  if cell=='W' then do
    r['STATUS']='WATER_NOT_LAND';r['ROLE']='W'
    return r
  end
  if cell=='X' then do
    r['STATUS']='UNKNOWN_NODATA'
    return r
  end
  r['STATUS']='LAND_AHD';r['ROLE']='L';r['HEIGHT_M']=cell~substr(3)+0
  return r

::class HarbourTerrainVisibility public
::method result class private
  use strict arg status,occluder,range,source,first=.nil
  r=.directory~new
  r['STATUS']=status;r['OCCLUDER']=occluder
  r['FIRST_RANGE_M']=range;r['PROVENANCE']=source
  r['VERTICAL_DATUM']='AHD_IF_VALIDATED'
  r['FIRST_LOCAL_POINT']='UNKNOWN'
  if first\==.nil then r['FIRST_LOCAL_POINT']=first
  r['METRIC_POSE_ADMISSION']='NOT_ADMITTED'
  return r
::method trace class
  /* Both camera and target heights must be explicitly in the tile's AHD.
     Previous scene z='ASL' must NOT be silently interpreted as AHD. */
  use strict arg tile,scene,cam,target,camDatum,targetDatum,ignoreBox='',landCamera=.true
  if camDatum\=='AHD' | targetDatum\=='AHD' | tile~datum\=='AHD' then ,
      return self~result('UNKNOWN_VERTICAL_DATUM','',0,tile~source)
  if cam~items<3 | target~items<3 then return self~result('UNKNOWN_INVALID_RAY','',0,tile~source)
  if \datatype(cam[3],'N') | \datatype(target[3],'N') then ,
      return self~result('UNKNOWN_HEIGHT','',0,tile~source)
  start=tile~sample(cam[1],cam[2])
  if start['STATUS']~left(7)=='UNKNOWN' then return self~result(start['STATUS'],'',0,tile~source)
  if landCamera & start['ROLE']=='W' then ,
      return self~result('UNKNOWN_FIXED_CAMERA_OVER_WATER','',0,tile~source)
  dx=target[1]-cam[1];dy=target[2]-cam[2];dz=target[3]-cam[3]
  horizontal=HSqrt(dx*dx+dy*dy)
  length=HSqrt(horizontal*horizontal+dz*dz)
  if horizontal<0.001 then return self~result('UNKNOWN_VERTICAL_RAY','',0,tile~source)
  count=max(2,trunc(horizontal/(tile~resolution/2))+1)
  if count>20000 then return self~result('UNKNOWN_RAY_TOO_LONG_FOR_RESOLUTION','',0,tile~source)
  /* Query existing bridge/wharf/approach cuboids with the same ray segment. */
  best=1;boxName=''
  do box over scene~boxes
    if ignoreBox\=='' & box[1]==ignoreBox then iterate
    t=.HarbourRayOcclusion~hitSegment(box,cam,target)
    if t>=0 & t<best then do;best=t;boxName=box[1];end
  end
  unknown=''
  do i=1 to count-1
    t=i/count
    if t>=best then leave
    p=tile~sample(cam[1]+t*dx,cam[2]+t*dy)
    if p['STATUS']~left(7)=='UNKNOWN' then do
      unknown=p['STATUS']
      iterate
    end
    if p['ROLE']=='L' then do
      z=cam[3]+t*dz
      /* Positive tolerance prevents equality at grazing lines from
         being interpreted as certain obstruction. The data uncertainty
         must be handled by the consumer as UNKNOWN near a silhouette. */
      if p['HEIGHT_M'] > z+tile~uncertainty then do
        if unknown\=='' then return self~result('UNKNOWN_GAP_BEFORE_INTERCEPT','',t*length,tile~source)
        return self~result('BLOCKED_TERRAIN','TERRAIN',t*length,tile~source,.array~of(cam[1]+t*dx,cam[2]+t*dy,z))
      end
      if abs(p['HEIGHT_M']-z)<=tile~uncertainty then unknown='UNKNOWN_TERRAIN_HEIGHT_BAND'
    end
  end
  if unknown\=='' then return self~result(unknown,'',0,tile~source)
  if boxName\=='' then return self~result('BLOCKED_STRUCTURE',boxName,best*length,tile~source,.array~of(cam[1]+best*dx,cam[2]+best*dy,cam[3]+best*dz))
  finish=tile~sample(target[1],target[2])
  if finish['STATUS']~left(7)=='UNKNOWN' then return self~result(finish['STATUS'],'',0,tile~source)
  return self~result('CLEAR','',length,tile~source)

/* Adjacent DEM tiles are not blindly concatenated. Every covered sample
   must agree on cell role and elevation within documented uncertainty.
   Valid seams are usable; missing or contradictory seams remain UNKNOWN. */
::class HarbourTerrainMosaic public
::attribute source get
::attribute datum get
::attribute frame get
::attribute crs get
::attribute uncertainty get
::attribute resolution get
::method init
  expose tiles source datum frame crs uncertainty resolution
  tiles=.array~new
  source='MOSAIC_EMPTY';datum='UNKNOWN';frame='UNKNOWN';crs='UNKNOWN'
  uncertainty=0;resolution=100000
::method appendTile
  expose tiles source datum frame crs uncertainty resolution
  use strict arg tile
  if tiles~items==0 then do
    datum=tile~datum;frame=tile~frame;crs=tile~crs
    source='MOSAIC:' || tile~source
  end
  else do
    if tile~datum\==datum | tile~frame\==frame | tile~crs\==crs then ,
       raise syntax 88.900 array('incompatible DEM tile reference frame/datum')
    source=source || '+' || tile~source
  end
  uncertainty=max(uncertainty,tile~uncertainty)
  resolution=min(resolution,tile~resolution)
  tiles~append(tile)
::method sample
  expose tiles
  use strict arg x,y
  selected=.nil;selectedError=1e20;source=''
  do tile over tiles
    s=tile~sample(x,y)
    if s['STATUS']=='UNKNOWN_OUTSIDE_TILE' then iterate
    if s['STATUS']=='UNKNOWN_NODATA' then return self~unknown('UNKNOWN_NODATA_IN_MOSAIC')
    if selected==.nil then do
      selected=s;selectedError=tile~uncertainty
      iterate
    end
    if selected['ROLE']\==s['ROLE'] then return self~unknown('UNKNOWN_TILE_ROLE_CONFLICT')
    if selected['ROLE']=='L' then do
      if abs(selected['HEIGHT_M']-s['HEIGHT_M'])>selectedError+tile~uncertainty then ,
         return self~unknown('UNKNOWN_TILE_HEIGHT_CONFLICT')
      if tile~uncertainty<selectedError then do
        selected=s;selectedError=tile~uncertainty
      end
    end
  end
  if selected==.nil then return self~unknown('UNKNOWN_OUTSIDE_MOSAIC')
  return selected
::method unknown private
  use strict arg state
  d=.directory~new
  d['STATUS']=state;d['ROLE']='X';d['HEIGHT_M']='UNKNOWN'
  return d