/* SLAM 450 v0.93 - race clock and Sun/Moon sky, stand-in for Moonsault.
 *
 * Architecture: Tom Dyer (Moonsault supplies current solar and visible
 * lunar position for a time and place; SLAM 450 uses them as a heading
 * observation, never as an assumed fix).
 * Written by: Claude (Opus 5.5), 2026-11-04.
 *
 * Slam450Ephemeris is a STAND-IN with the call shape agreed for Moonsault:
 *   sunMoon(unixSeconds, latDeg, lonDeg) -> directory
 *     SUN_ALT SUN_AZ SUN_ALT_APP          (deg; true and refracted altitude)
 *     MOON_ALT MOON_AZ MOON_ALT_APP       (topocentric, deg)
 *     MOON_ILLUM (0..1) MOON_ELONG (deg) SUN_UP MOON_UP MOON_VISIBLE
 *     METHOD ACCURACY_SUN_DEG ACCURACY_MOON_DEG
 * Sun: the low-precision solar coordinates of the Astronomical Almanac
 * (about 0.01 deg, 1950-2050). Moon: Paul Schlyter's elements with the
 * main longitude/latitude perturbations (about 0.3 deg), topocentric
 * parallax applied. Refraction: Bennett. When Moonsault's provider lands,
 * the runner swaps the class; nothing else changes.
 * Checked against PyEphem by tests/check_sky450.py (independent code).
 */
::class Slam450Ephemeris public
::method sunMoon
  use strict arg unix,lat,lon
  numeric digits 16
  jd=unix/86400+2440587.5
  n=jd-2451545.0
  /* --- Sun ---------------------------------------------------------- */
  L=norm(280.460+0.9856474*n);g=norm(357.528+0.9856003*n)
  lam=L+1.915*sind(g)+0.020*sind(2*g)
  eps=23.439-0.0000004*n
  sra=atan2d(cosd(eps)*sind(lam),cosd(lam));sdec=asind(sind(eps)*sind(lam))
  gmst=norm(280.46061837+360.98564736629*n)
  lst=norm(gmst+lon)
  sh=horizon(lst-sra,sdec,lat)
  /* --- Moon (Schlyter) --------------------------------------------- */
  d=jd-2451543.5
  Nn=norm(125.1228-0.0529538083*d);ii=5.1454;w=norm(318.0634+0.1643573223*d)
  a=60.2666;e=0.054900;M=norm(115.3654+13.0649929509*d)
  Ms=norm(356.0470+0.9856002585*d);ws=norm(282.9404+4.70935E-5*d);Ls=norm(Ms+ws)
  /* EA, not E: Rexx names are case-blind, so E would be e (eccentricity) */
  EA=M+180/3.141592653589793*e*sind(M)*(1+e*cosd(M))
  do 6;EA=EA-(EA-180/3.141592653589793*e*sind(EA)-M)/(1-e*cosd(EA));end
  xv=a*(cosd(EA)-e);yv=a*RxCalcSqrt(1-e*e,16)*sind(EA)
  v=atan2d(yv,xv);r=RxCalcSqrt(xv*xv+yv*yv,16)
  xh=r*(cosd(Nn)*cosd(v+w)-sind(Nn)*sind(v+w)*cosd(ii))
  yh=r*(sind(Nn)*cosd(v+w)+cosd(Nn)*sind(v+w)*cosd(ii))
  zh=r*sind(v+w)*sind(ii)
  lonE=atan2d(yh,xh);latE=atan2d(zh,RxCalcSqrt(xh*xh+yh*yh,16))
  Lm=norm(Nn+w+M);Dm=norm(Lm-Ls);Fm=norm(Lm-Nn)
  lonE=lonE-1.274*sind(M-2*Dm)+0.658*sind(2*Dm)-0.186*sind(Ms)-0.059*sind(2*M-2*Dm),
          -0.057*sind(M-2*Dm+Ms)+0.053*sind(M+2*Dm)+0.046*sind(2*Dm-Ms)+0.041*sind(M-Ms),
          -0.035*sind(Dm)-0.031*sind(M+Ms)-0.015*sind(2*Fm-2*Dm)+0.011*sind(M-4*Dm)
  latE=latE-0.173*sind(Fm-2*Dm)-0.055*sind(M-Fm-2*Dm)-0.046*sind(M+Fm-2*Dm),
          +0.033*sind(Fm+2*Dm)+0.017*sind(2*M+Fm)
  r=r-0.58*cosd(M-2*Dm)-0.46*cosd(2*Dm)
  xg=cosd(lonE)*cosd(latE);yg=sind(lonE)*cosd(latE);zg=sind(latE)
  xe=xg;ye=yg*cosd(eps)-zg*sind(eps);ze=yg*sind(eps)+zg*cosd(eps)
  mra=atan2d(ye,xe);mdec=atan2d(ze,RxCalcSqrt(xe*xe+ye*ye,16))
  mh=horizon(lst-mra,mdec,lat)
  par=asind(1/r)
  malt=mh[1]-par*cosd(mh[1])
  /* elongation and illuminated fraction */
  elong=acosd(cosd(sdec)*cosd(mdec)*cosd(sra-mra)+sind(sdec)*sind(mdec))
  illum=(1-cosd(elong))/2   /* phase angle ~ 180-elongation: k=(1+cos i)/2 */
  out=.directory~new
  out['SUN_ALT']=sh[1];out['SUN_AZ']=sh[2];out['SUN_ALT_APP']=sh[1]+refraction(sh[1])
  out['MOON_ALT']=malt;out['MOON_AZ']=mh[2];out['MOON_ALT_APP']=malt+refraction(malt)
  out['MOON_ILLUM']=illum;out['MOON_ELONG']=elong
  out['SUN_UP']=(out['SUN_ALT_APP']>-0.27)
  out['MOON_UP']=(out['MOON_ALT_APP']>-0.25)
  out['MOON_VISIBLE']=(out['MOON_UP'] & illum>=0.15 & elong>=15)
  out['METHOD']='STANDIN AA-low-precision Sun + Schlyter Moon'
  out['ACCURACY_SUN_DEG']=0.01;out['ACCURACY_MOON_DEG']=0.3
  return out

::class Slam450MoonsaultEphemeris public
/* v0.93 adapter: Moonsault's provider (packages/oorexx_moonsault_v0.1,
 * .MoonsaultEphemeris~sunMoon(utcIso, lat, lon), ChatGPT) behind SLAM 450's
 * call shape. Moonsault takes an ISO UTC string; SLAM's clock gives Unix
 * seconds, so the adapter converts. Field mapping:
 *   SUN_ALT/SUN_AZ/SUN_ALT_APP <- sun altitudeTrueDeg/azimuthTrueDeg/altitudeRefractedDeg
 *   MOON_* the same from moon (topocentric, parallax applied by Moonsault)
 *   SUN_UP <- sun aboveHorizon; MOON_UP <- moon aboveHorizon
 *   MOON_VISIBLE <- moon visibilityCandidate (Moonsault: night only, Sun < -6)
 *   SUN_HEADING_OK / MOON_HEADING_OK <- headingCandidate (altitude >= 5)
 *   MOON_ILLUM <- illuminatedFraction; MOON_ELONG <- elongationDeg
 *   ACCURACY_*_DEG <- modelErrorBudgetDeg; SOURCE_TAG, STATUS kept.
 * Moonsault's answer is a PREDICTION; the observation stays SLAM's camera. */
::method init
  use strict arg moonsaultSrc=''
  if moonsaultSrc\=='' then .context~package~loadPackage(moonsaultSrc'/MoonsaultEphemeris.cls')
::method sunMoon
  use strict arg unix,lat,lon
  numeric digits 16
  a=.MoonsaultEphemeris~sunMoon(unixToIso(unix),lat,lon)
  s=a['sun'];m=a['moon']
  out=.directory~new
  out['SUN_ALT']=s['altitudeTrueDeg'];out['SUN_AZ']=s['azimuthTrueDeg'];out['SUN_ALT_APP']=s['altitudeRefractedDeg']
  out['MOON_ALT']=m['altitudeTrueDeg'];out['MOON_AZ']=m['azimuthTrueDeg'];out['MOON_ALT_APP']=m['altitudeRefractedDeg']
  out['MOON_ILLUM']=m['illuminatedFraction'];out['MOON_ELONG']=m['elongationDeg']
  out['SUN_UP']=s['aboveHorizon'];out['MOON_UP']=m['aboveHorizon']
  out['MOON_VISIBLE']=m['visibilityCandidate']
  out['SUN_HEADING_OK']=s['headingCandidate'];out['MOON_HEADING_OK']=m['headingCandidate']
  out['METHOD']='MOONSAULT' a['method']
  out['ACCURACY_SUN_DEG']=s['modelErrorBudgetDeg'];out['ACCURACY_MOON_DEG']=m['modelErrorBudgetDeg']
  out['SOURCE_TAG']=a['sourceTag'];out['STATUS']=a['status']
  return out

::class Slam450SkyFix public
/* SLAM's own observation: where is the bright dot in my panorama? */
::method bodyBearing class
  /* Relative bearing (deg, -180..180, + = right of the nose) of the circular
     mean of the symbol's pixels, and the pixel count; .nil if not seen. */
  use strict arg frame,sym
  numeric digits 16
  fw=frame['WIDTH'];sxs=0;cxs=0;nb=0
  do y over frame['PIXELS']
    p=0
    do forever
      p=y~pos(sym,p+1);if p=0 then leave
      ang=(p-0.5)*360/fw;sxs+=sind(ang);cxs+=cosd(ang);nb+=1
    end
  end
  if nb=0 then return .nil
  ma=atan2d(sxs,cxs);if ma<0 then ma+=360
  return .array~of(ma-180,nb)
::method heading class
  /* Absolute heading = the body's predicted azimuth minus its bearing. */
  use strict arg azimuth,relBearing
  h=(azimuth-relBearing)//360;if h<0 then h+=360
  return h

::class Slam450RaceClock public
/* UTC race clock: the start time plus one second per tick. */
::attribute startUnix get
::method init
  expose startUnix
  use strict arg iso
  /* 2026-11-04T06:00:00Z */
  parse var iso yy '-' mo '-' dd 'T' hh ':' mi ':' ss 'Z'
  if \datatype(yy,'W') | \datatype(mo,'W') | \datatype(dd,'W') then raise syntax 88.900 array('UTC start must be YYYY-MM-DDTHH:MM:SSZ')
  base=date('B',yy||right(mo,2,0)||right(dd,2,0),'S')-date('B','19700101','S')
  startUnix=base*86400+hh*3600+mi*60+ss
::method unixAt
  expose startUnix
  use strict arg tick
  return startUnix+tick
::method isoAt
  expose startUnix
  use strict arg tick
  t=startUnix+tick;days=t%86400;sec=t//86400
  return date('I',date('B','19700101','S')+days,'B')'T'right(sec%3600,2,0)':'right(sec//3600%60,2,0)':'right(sec//60,2,0)'Z'

::routine unixToIso public
  use strict arg t
  days=t%86400;sec=t//86400
  return date('I',date('B','19700101','S')+days,'B')'T'right(sec%3600,2,0)':'right(sec//3600%60,2,0)':'right(sec//60,2,0)'Z'
::routine norm
  use arg x
  x=x//360;if x<0 then x+=360
  return x
::routine sind
  return RxCalcSin(arg(1),16)
::routine cosd
  return RxCalcCos(arg(1),16)
::routine asind
  use arg v
  v=max(-1,min(1,v))
  return RxCalcArcSin(v,16)
::routine acosd
  use arg v
  v=max(-1,min(1,v))
  return RxCalcArcCos(v,16)
::routine atan2d
  use arg y,x
  if x=0 then do
    if y>0 then return 90
    if y<0 then return -90
    return 0
  end
  a=RxCalcArcTan(y/x,16)
  if x<0 then a+=180
  if a>180 then a-=360
  return a
::routine horizon
  /* hour angle, declination, latitude -> (altitude, azimuth from north) */
  use arg H,dec,lat
  alt=asind(sind(lat)*sind(dec)+cosd(lat)*cosd(dec)*cosd(H))
  az=atan2d(sind(H),cosd(H)*sind(lat)-sind(dec)/cosd(dec)*cosd(lat))+180
  az=az//360;if az<0 then az+=360
  return .array~of(alt,az)
::routine refraction
  /* Bennett: apparent minus true altitude, degrees (0 below -2 deg). */
  use arg h
  if h<-2 then return 0
  return 1.02/RxCalcTan(h+10.3/(h+5.11),16)/60
