/* Moonsault camera axis + landmark coarse navigation fix (ooRexx only).
 * A fitted J2000 projective sky plate supplies orientation. Three charted
 * landmarks provide an independent location by bearing intersection.
 * No optical plate alone can determine terrestrial position; no 5 m claim.
 */
::options digits 30
::class MoonsaultCameraFix public
::constant JULIAN_EPOCH 2451545
::constant METRES_PER_DEGREE 111320
::method rayJ2000 class
  use strict arg plate,x,y
  p=.MoonsaultPlateIdentity
  a=.array~new;b=.array~new
  do i=1 to 3
    a[i]=plate[1][i]-x*plate[3][i]
    b[i]=plate[2][i]-y*plate[3][i]
  end
  v=p~norm3(p~cross(a,b))
  if p~dot(v,plate[3])>0 then do i=1 to 3
    v[i]=-v[i]
  end
  return v
::method direction class
  use strict arg plate,x,y,julianDay,observerLat,observerLon
  o=.MoonsaultAngle;ignore=o~load
  v=self~rayJ2000(plate,x,y)
  ra=o~norm(o~atan2(v[2],v[1]))
  dec=o~atan2(v[3],o~sqrt(v[1]*v[1]+v[2]*v[2]))
  /* IAU 1976 mean precession, J2000 -> equinox of observation date.
   * No nutation, refraction, proper motion, polar motion or aberration.
   * This is nav-scale bearing, not an arcsecond astrometry product. */
  T=(julianDay-self~JULIAN_EPOCH)/36525
  zeta=(2306.2181*T+0.30188*T*T+0.017998*T*T*T)/3600
  z=(2306.2181*T+1.09468*T*T+0.018203*T*T*T)/3600
  theta=(2004.3109*T-0.42665*T*T-0.041833*T*T*T)/3600
  A=o~cos(dec)*o~sin(ra+zeta)
  B=o~cos(theta)*o~cos(dec)*o~cos(ra+zeta)-o~sin(theta)*o~sin(dec)
  C=o~sin(theta)*o~cos(dec)*o~cos(ra+zeta)+o~cos(theta)*o~sin(dec)
  raDate=o~norm(o~atan2(A,B)+z)
  decDate=o~atan2(C,o~sqrt(A*A+B*B))
  D=julianDay-self~JULIAN_EPOCH
  gmst=o~norm(280.46061837+360.98564736629*D)
  hour=o~norm(gmst+observerLon-raDate)
  if hour>180 then hour=hour-360
  s=o~sin(observerLat)*o~sin(decDate)+o~cos(observerLat)*o~cos(decDate)*o~cos(hour)
  s=max(-1,min(1,s))
  altitude=o~atan2(s,o~sqrt(max(0,1-s*s)))
  east=-o~cos(decDate)*o~sin(hour)
  north=o~cos(observerLat)*o~sin(decDate)-o~sin(observerLat)*o~cos(decDate)*o~cos(hour)
  azimuth=o~norm(o~atan2(east,north))
  d=.directory~new
  d['AZIMUTH_TRUE']=azimuth;d['ELEVATION']=altitude
  d['RA_J2000']=ra;d['DEC_J2000']=dec
  d['RA_OF_DATE']=raDate;d['DEC_OF_DATE']=decDate
  return d
::method landmarkBearing class
  use strict arg fromLat,fromLon,toLat,toLon
  o=.MoonsaultAngle;ignore=o~load
  e=(toLon-fromLon)*self~METRES_PER_DEGREE*o~cos((toLat+fromLat)/2)
  n=(toLat-fromLat)*self~METRES_PER_DEGREE
  return o~norm(o~atan2(e,n))
::method angleError class
  use strict arg a,b
  q=(a-b+540)//360-180
  return q
/* Each landmark is (name,lat,lon,x1920,y1080). At least three
 * independent image/charts bearings, no regression to a web camera pin.
 * Pairs of parallel bearings are explicitly rejected. */
::method locate class
  use strict arg plate,julianDay,landmarks,seedLat=.nil,seedLon=.nil
  if seedLat==.nil then seedLat=-33.85
  if seedLon==.nil then seedLon=151.21
  if landmarks~items<3 then raise syntax 88.900 array('at least 3 distinct physical landmarks required')
  o=.MoonsaultAngle;ignore=o~load
  refLat=seedLat;refLon=seedLon
  /* A perpendicular to azimuth direction in East/North basis is
   * (-cos(az), +sin(az)); solve the camera as intersection of lines. */
  do pass=1 to 3
    xx=0;xy=0;yy=0;bx=0;by=0
    do lm over landmarks
      if lm~items<5 then raise syntax 88.900 array('incomplete landmark',lm)
      az=self~direction(plate,lm[4],lm[5],julianDay,refLat,refLon)['AZIMUTH_TRUE']
      ux=-o~cos(az);uy=o~sin(az)
      E=(lm[3]-refLon)*self~METRES_PER_DEGREE*o~cos(refLat)
      N=(lm[2]-refLat)*self~METRES_PER_DEGREE
      projection=ux*E+uy*N
      xx=xx+ux*ux;xy=xy+ux*uy;yy=yy+uy*uy
      bx=bx+ux*projection;by=by+uy*projection
    end
    det=xx*yy-xy*xy
    if det<0.00001 then raise syntax 88.900 array('nearly parallel landmark directions')
    east=(bx*yy-by*xy)/det
    north=(by*xx-bx*xy)/det
    if o~sqrt(east*east+north*north)>10000 then -
      raise syntax 88.900 array('landmark candidate exceeds 10 km search envelope')
    refLat=refLat+north/self~METRES_PER_DEGREE
    refLon=refLon+east/(self~METRES_PER_DEGREE*o~cos(refLat))
  end
  maxError=0;errors=.array~new
  do lm over landmarks
    actual=self~landmarkBearing(refLat,refLon,lm[2],lm[3])
    predicted=self~direction(plate,lm[4],lm[5],julianDay,refLat,refLon)['AZIMUTH_TRUE']
    er=self~angleError(actual,predicted)
    maxError=max(maxError,abs(er))
    errors~append(.array~of(lm[1],actual,predicted,er))
  end
  axis=self~direction(plate,960,540,julianDay,refLat,refLon)
  fixout=.directory~new
  fixout['LATITUDE']=refLat
  fixout['LONGITUDE']=refLon
  fixout['BEARING_TRUE']=axis['AZIMUTH_TRUE']
  fixout['ELEVATION']=axis['ELEVATION']
  fixout['MAX_LANDMARK_ANGULAR_RESIDUAL']=maxError
  fixout['LANDMARKS']=errors
  fixout['STATUS']='COARSE_NAVIGATION_CANDIDATE'
  /* No apparent-place and photogrammetric/3D camera calibration: never
   * automatically assert ±1nm or 5m integrity from a small residual. */
  return fixout
::requires 'MoonsaultPlateIdentity.cls'