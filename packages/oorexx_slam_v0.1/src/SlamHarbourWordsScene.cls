/* Power SLAM v0.24 — explicit Top Rope height-to-scene adapter.
 * Architecture: Tom Dyer. Native ooRexx implementation: ChatGPT GPT-6.
 * MGA projection from Claude (Opus 5.5), see SlamHarbourMGA.cls.
 * This never qualifies a camera pose or invents water/land from elevation.
 */
::requires 'SlamHarbourWordsAdapter.cls'
::requires 'SlamHarbourMGA.cls'

::class HarbourWordsRoleEvidence public
::attribute source get
::method init
  expose labels source
  use strict arg provenance
  if provenance=='' then raise syntax 88.900 array('missing role provenance')
  source=provenance
  labels=.directory~new
::method setCell
  expose labels
  use strict arg column,row,role
  if \datatype(column,'W') | \datatype(row,'W') | column<1 | row<1 then ,
    raise syntax 88.900 array('invalid mask index')
  if role\=='L' & role\=='W' & role\=='X' then ,
    raise syntax 88.900 array('invalid map role')
  labels[column||':'||row]=role
::method roleAt
  expose labels
  use strict arg column,row
  key=column||':'||row
  if \labels~hasIndex(key) then return 'X'
  return labels[key]

::class HarbourWordsSceneTile public
::attribute source get
::attribute datum get
::attribute rawDatum get
::attribute crs get
::attribute frame get
::attribute resolution get
::attribute uncertainty get
::attribute roleSource get
::method init
  expose words mask source datum rawDatum crs frame resolution uncertainty roleSource
  use strict arg rawWords,verticalError,roleEvidence=.nil
  if rawWords~crs\=='GDA94_MGA_ZONE_56' | rawWords~datum\=='AHD71' then ,
    raise syntax 88.900 array('unsupported source datum or projection')
  if \datatype(verticalError,'N') | verticalError<0 then ,
    raise syntax 88.900 array('invalid uncertainty')
  words=rawWords;mask=roleEvidence
  source=rawWords~source
  datum='AHD'          /* AHD71 is the realisation of the AHD datum. */
  rawDatum='AHD71'
  crs='SLAM_LOCAL_ENU_V1'
  frame='SCENE_33.852S_151.210E'
  resolution=rawWords~resolution
  uncertainty=verticalError
  roleSource='UNKNOWN_UNCLASSIFIED'
  if mask\==.nil then roleSource=mask~source
::method sceneMGA
  /* Exact inverse of HarbourScene~local approximation, then GDA94 TM.
   * The scene's tangent approximation is NOT a surveyed coordinate system.
   * x and y metres are east and north in the existing model only.
   */
  use strict arg x,y
  if \datatype(x,'N') | \datatype(y,'N') then return .nil
  latitude=(-33.852)+(y/111200)
  longitude=151.210+(x/92300)
  parse value mgaOf(latitude,longitude,56) with east north
  if \datatype(east,'N') | \datatype(north,'N') then return .nil
  return .array~of(east+0,north+0)
::method sample
  expose words mask source
  use strict arg x,y
  p=self~sceneMGA(x,y)
  if p==.nil then do
    d=.directory~new
    d['STATUS']='UNKNOWN_INVALID_COORDINATE';d['ROLE']='X'
    d['HEIGHT_M']='UNKNOWN';d['PROVENANCE']=source
    return d
  end
  d=words~sampleMGA(p[1],p[2])
  d['MGA_E']=p[1];d['MGA_N']=p[2]
  d['SOURCE_HEIGHT_DATUM']='AHD71'
  d['SCENE_TRANSFORM']='APPROX_TANGENT_TO_GDA94_MGA56'
  d['FRAME_QUALIFICATION']='NOT_SURVEYED'
  if d['STATUS']\=='HEIGHT_AHD71' then do
    d['ROLE']='X'
    return d
  end
  if mask==.nil then do
    d['STATUS']='UNKNOWN_UNCLASSIFIED_ROLE'
    d['ROLE']='X'
    return d
  end
  /* Independently mapped role evidence is required. No DEM threshold. */
  col=d['COLUMN'];row=d['ROW']
  role=mask~roleAt(col,row)
  d['ROLE_PROVENANCE']=mask~source
  if role=='L' then do
    d['STATUS']='LAND_AHD';d['ROLE']='L'
  end
  else if role=='W' then do
    d['STATUS']='WATER_NOT_LAND';d['ROLE']='W'
  end
  else do
    d['STATUS']='UNKNOWN_UNCLASSIFIED_ROLE';d['ROLE']='X'
  end
  return d
