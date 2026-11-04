/* Power SLAM <- native V5V/Camera Behaviour observation boundary v0.1.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
 * Does not create surveyed camera geometry, production positions, identity,
 * canonical SLAM graph edges or TESTED evidence from V5V video hypotheses.
 * Perspective projection follows existing HarbourPerspectiveFit~project.
 */
::class PowerSlamV5VBridge public
::attribute observations get
::attribute sources get

::method init
  expose observations sources
  observations=.array~new
  sources=.directory~new
  /* Only registered sources from original user-supplied 2026-11-01 uploads. */
  sources['2']=.array~of('6d2c535739dd8f96de8f16d26c9b43ed9c11654320d0d7bfc3106ecc4fa5488f',1280,720,'UNKNOWN_UNSURVEYED')
  sources['3']=.array~of('08f2814c2d4033272a7c6532c3e5b340534ba16ad9fecc2d374d65324f9cab5f',640,360,'CAFE_SYDNEY_SITE_ANCHORED_POSE_UNSURVEYED')

::method load
  expose observations sources
  use strict arg filename
  if stream(filename,'C','QUERY EXISTS')=='' then raise syntax 88.900 array('no observation PSV')
  got=.array~new
  seen=.directory~new
  header='camera|source_sha256|frame_index|source_pts_seconds|relative_frame_seconds|centre_x_approx_px|centre_y_approx_px|crop_x|crop_y|crop_width|crop_height|crop_rgb24_sha256|crop_file|observation_kind|identity_claim|evidence_state'
  if linein(filename)\==header then raise syntax 88.900 array('unexpected V5V candidate schema')
  do while lines(filename)>0
    row=linein(filename)
    if row=='' then raise syntax 88.900 array('empty observation row')
    if self~pipes(row)<>15 then raise syntax 88.900 array('wrong number of PSV fields')
    parse var row cam '|' hash '|' frame '|' pts '|' relative '|' x '|' y '|' cropX '|' cropY '|' cropW '|' cropH '|' cropHash '|' cropFile '|' kind '|' identity '|' state
    if \sources~hasIndex(cam) then raise syntax 88.900 array('unregistered camera')
    source=sources[cam]
    if hash\==source[1] then raise syntax 88.900 array('forged source hash')
    if length(hash)<>64 | verify(hash,'0123456789abcdef')<>0 then raise syntax 88.900 array('invalid source digest')
    if length(cropHash)<>64 | verify(cropHash,'0123456789abcdef')<>0 then raise syntax 88.900 array('invalid crop digest')
    if kind\=='HUMAN_REVIEWED_VESSEL_CANDIDATE' then raise syntax 88.900 array('unsupported observation kind')
    if identity\=='CROSS_CAMERA_HYPOTHESIS_UNVERIFIED' | state\=='OBSERVED_UNTESTED' then raise syntax 88.900 array('claim elevated beyond observation')
    nums=.array~of(frame,pts,relative,x,y,cropX,cropY,cropW,cropH)
    do n over nums
      if \datatype(n,'N') then raise syntax 88.900 array('non-numeric observation')
    end
    if \datatype(frame,'W') | frame<0 | frame>=1800 then raise syntax 88.900 array('invalid source frame index')
    if pts<0 | relative<0 | abs(relative-frame/30)>0.000001 then raise syntax 88.900 array('invalid source timeline')
    if x<0 | x>=source[2] | y<0 | y>=source[3] then raise syntax 88.900 array('observation outside image')
    if cropX<0 | cropY<0 | cropW<=0 | cropH<=0 | cropX+cropW>source[2] | cropY+cropH>source[3] then raise syntax 88.900 array('invalid crop bounds')
    if x<cropX | x>=cropX+cropW | y<cropY | y>=cropY+cropH then raise syntax 88.900 array('candidate centre outside source crop')
    if cropFile=='' then raise syntax 88.900 array('crop reference missing')
    key=cam||':'||frame
    if seen~hasIndex(key) then raise syntax 88.900 array('repeated source observation')
    seen[key]=1
    /* Source-bound candidate only; world location never derived here. */
    o=.directory~new
    o['CAMERA']=cam;o['SOURCE_SHA256']=hash;o['FRAME']=frame;o['PTS']=pts;o['SECONDS']=relative
    o['X']=x;o['Y']=y;o['WIDTH']=source[2];o['HEIGHT']=source[3]
    o['CROP_SHA256']=cropHash;o['CROP_FILE']=cropFile
    o['EVIDENCE']='OBSERVED_UNTESTED';o['IDENTITY']='CROSS_CAMERA_HYPOTHESIS_UNVERIFIED'
    o['POSE']='UNSURVEYED';o['WORLD']='BLOCKED_UNCALIBRATED'
    got~append(o)
  end
  call stream filename,'C','CLOSE'
  /* Full validation before admission; a bad row does not partly replace previous state. */
  if got~items=0 then raise syntax 88.900 array('empty observation set')
  observations=got
  return got~items

/* Immutable pixel-space seam: no claim of a camera world pose or vessel ID.
 * The final status is always OBSERVED_UNTESTED, and the geometrical destination
 * must refuse it until the Power SLAM camera pose certificate is qualified.
 */
::method exportCandidates
  expose observations
  use strict arg filename
  if observations~items=0 then raise syntax 88.900 array('nothing validated to export')
  header='camera|source_sha256|frame_index|source_pts_seconds|source_x_px|source_y_px|width|height|v5v_column|v5v_row|crop_rgb24_sha256|vessel_identity|camera_pose|world_position|evidence_state'
  rows=.array~new
  do o over observations
    col=trunc(o['X']*80/o['WIDTH'])
    row=trunc(o['Y']*45/o['HEIGHT'])
    if col<0 | col>=80 | row<0 | row>=45 then raise syntax 88.900 array('V5V cell projection invalid')
    line=o['CAMERA']||'|'||o['SOURCE_SHA256']||'|'||o['FRAME']||'|'||o['PTS']||'|'||o['X']||'|'||o['Y']||'|'||o['WIDTH']||'|'||o['HEIGHT']||'|'||col||'|'||row||'|'||o['CROP_SHA256']||'|CROSS_CAMERA_HYPOTHESIS_UNVERIFIED|UNSURVEYED|BLOCKED_UNCALIBRATED|OBSERVED_UNTESTED'
    rows~append(line)
  end
  call stream filename,'C','OPEN WRITE REPLACE'
  call lineout filename,header
  do line over rows
    call lineout filename,line
  end
  call stream filename,'C','CLOSE'
  return rows~items

::method pipes private
  use strict arg s
  n=0
  do k=1 to length(s)
    if substr(s,k,1)=='|' then n=n+1
  end
  return n

/* Diagnostic candidate ray: camera horizontal coordinates east/north, Z ASL;
 * the vector is not a world position and may be issued for provisional poses.
 * Inverse of HarbourPerspectiveFit~project -- same degree convention as rxmath.
 */
::method diagnosticRay
  use strict arg observation, cameraPose
  if observation['EVIDENCE']\=='OBSERVED_UNTESTED' then raise syntax 88.900 array('observation authority changed')
  if cameraPose~items<>6 then raise syntax 88.900 array('camera pose must have 6 values')
  do n over cameraPose
    if \datatype(n,'N') then raise syntax 88.900 array('nonnumeric camera pose')
  end
  if cameraPose[6]<=0 then raise syntax 88.900 array('invalid focal length')
  w=observation['WIDTH'];h=observation['HEIGHT']
  u=(observation['X']-w/2)/cameraPose[6]
  v=(h/2-observation['Y'])/cameraPose[6]
  yaw=cameraPose[4];pitch=cameraPose[5]
  horizontal=RxCalcCos(pitch)-v*RxCalcSin(pitch)
  dz=RxCalcSin(pitch)+v*RxCalcCos(pitch)
  dx=horizontal*RxCalcSin(yaw)+u*RxCalcCos(yaw)
  dy=horizontal*RxCalcCos(yaw)-u*RxCalcSin(yaw)
  rayResult=.directory~new
  rayResult['CAMERA']=observation['CAMERA'];rayResult['FRAME']=observation['FRAME']
  rayResult['VECTOR']=.array~of(dx,dy,dz)
  rayResult['STATUS']='DIAGNOSTIC_UNCALIBRATED_RAY'
  rayResult['POSE_STATUS']='PROVISIONAL_NOT_ADMITTED'
  return rayResult

/* Fail closed: no image observation yields a world coordinate without a
 * signed qualified pose token from the geometric owner. Caller supplies
 * horizontal water-plane elevation only in a qualification-only calculation.
 * This method is intentionally NOT a world positioning endpoint until the
 * Power SLAM owner defines a durable pose-certificate validation protocol.
 */
::method worldIntersection
  use strict arg observation, cameraPose, waterLevel, poseCertificate
  if poseCertificate\=='POWER_SLAM_SURVEYED_POSE_CERTIFICATE_UNIMPLEMENTED' then return 'BLOCKED_UNCALIBRATED'
  return 'BLOCKED_NO_POSE_CERTIFICATE_VERIFIER'

/* Convert exact V5V 80x45 cell centre to source pixel centre, preserving
 * camera-specific resolutions. No world position or vessel labels. */
::method v5vCellCentre
  expose sources
  use strict arg cam,col,row
  if \sources~hasIndex(cam) then raise syntax 88.900 array('unregistered camera')
  if \datatype(col,'W') | \datatype(row,'W') then raise syntax 88.900 array('non-integer V5V cell')
  if col<0 | col>=80 | row<0 | row>=45 then raise syntax 88.900 array('out-of-bounds V5V cell')
  s=sources[cam]
  return .array~of((col+0.5)*s[2]/80,(row+0.5)*s[3]/45)
