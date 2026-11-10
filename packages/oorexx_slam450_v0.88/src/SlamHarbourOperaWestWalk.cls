/* Power SLAM v0.20: user-requested western Opera House forecourt walkway.
 * Architecture: Tom Dyer; ooRexx implementation by ChatGPT GPT-6.
 * EXPLICIT scenic correction to the legacy Opera cuboid's axis orientation.
 * Coordinates/h=7m ASL are provisional site hypotheses, NOT surveyed land.
 * Do not use this rendered viewpoint to qualify a ferry position or height.
 */
::requires 'SlamHarbourBluesPointTower.cls'
::requires 'SlamHarbourQuayInfrastructure.cls'
::class HarbourOperaWestWalk public subclass HarbourQuayInfrastructurePanorama
::constant CAM_LAT -33.856700
::constant CAM_LON 151.214430
::constant CAM_ASL 7
::method init
  self~init:super
  self~sites['OPERA_WEST_WALK']=.array~of('Opera House western forecourt walkway - provisional',self~CAM_LAT,self~CAM_LON)
::method siteCamera
  use strict arg key
  c=self~siteCamera:super(key)
  if key~upper=='OPERA_WEST_WALK' then c[3]=self~CAM_ASL
  return c
::method orientOperaBox
  /* Legacy model's 183 m dimension is erroneously E-W for western walkway.
   * Reorient long axis N-S, short axis E-W, using existing coarse dimensions
   * and existing centre. This is DISPLAY-ONLY, not surveyed footprint data.
   */
  scene=self~scene
  old=scene~boxes
  revised=.array~new
  seen=0
  do b over old
    if b[1]=='OPERA' then do
      seen+=1
      iterate
    end
    revised~append(b)
  end
  if seen\=1 then raise syntax 88.900 array('expected single legacy Opera cuboid')
  o=scene~features['O']
  revised~append(scene~cuboid('OPERA',o[1],o[2],4,183,120,65,0,1,1,0))
  scene~boxes=revised
  return 'OPERA_AXIS_NORTH_SOUTH_UNSURVEYED'
::method qualifyWalk
  scene=self~scene
  local=scene~local(self~CAM_LAT,self~CAM_LON)
  o=scene~features['O']
  /* Rotated box short-axis half-extent = 60m east/west. */
  westLimit=o[1]-60
  if local[1]>=westLimit then raise syntax 88.900 array('camera inside or east of west face')
  if abs(local[2]-o[2])>=91.5 then raise syntax 88.900 array('camera outside long-axis band')
  res=.directory~new
  res['STATUS']='WEST_OF_CORRECTED_OPERA_BOX_NOT_GEOREGISTERED_LAND'
  res['DISTANCE_WEST_OF_FACE_M']=westLimit-local[1]
  res['MODEL_BEARING_FROM_CAMERA']='DERIVED_ON_RENDER'
  res['CAMERA_LAT']=self~CAM_LAT
  res['CAMERA_LON']=self~CAM_LON
  res['CAMERA_ASL']=self~CAM_ASL
  return res
