/* MoonsaultEphemeris.cls - low-power celestial prediction (ooRexx 5.3)
 * Architecture: Tom Dyer. Additive implementation: ChatGPT (GPT-6), 2026-11-04.
 * Computational source: Paul Schlyter, Computing planetary positions,
 * https://stjarnhimlen.se/comp/ppcomp.html; simplified perturbations retained.
 * Numerical provider: ooRexx rxmath; optional Alchemy Maths trig adapter.
 * No Python process or network dependency.
 * This is an EPHEMERIS, not an observed position or GPS fix.
 * Input UTC is strictly YYYY-MM-DDTHH:MM:SSZ, lon positive east, degrees.
 * Sea-level spherical-earth topocentric lunar approximation, standard refraction.
 */

::class MoonsaultEphemeris public
::method sunMoon class
  use strict arg utc, latitude, longitude
  numeric digits 17
  ignore = .MoonsaultAngle~load
  if \datatype(latitude, 'N') | \datatype(longitude, 'N') then
    raise syntax 88.900 array('numeric latitude and longitude', latitude longitude)
  if latitude < -90 | latitude > 90 | longitude < -180 | longitude > 180 then
    raise syntax 88.900 array('latitude [-90,90] and longitude [-180,180]', latitude longitude)
  jd = self~julianDate(utc)
  d = jd - 2451543.5
  utHours = (substr(utc, 12, 2) + substr(utc,15,2)/60 + substr(utc,18,2)/3600)
  obliq = 23.4393 - 0.0000003563*d
  pi = 3.14159265358979323846
  o = .MoonsaultAngle

  /* Sun: elliptic orbit approximation, apparent ecliptic longitude of date. */
  ms = o~norm(356.0470 + 0.9856002585*d)
  ws = o~norm(282.9404 + 0.0000470935*d)
  es = 0.016709 - 0.000000001151*d
  ea = ms + es*180/pi*o~sin(ms)*(1 + es*o~cos(ms))
  xs = o~cos(ea) - es
  ys = o~sqrt(1-es*es)*o~sin(ea)
  vs = o~atan2(ys,xs)
  sunLon = o~norm(vs + ws)
  sunEq = self~eclipticToEquatorial(sunLon,0,obliq)

  /* Moon: elliptic orbit plus Schlyter longitude, latitude, distance terms. */
  n = o~norm(125.1228 - 0.0529538083*d)
  incl = 5.1454
  w = o~norm(318.0634 + 0.1643573223*d)
  am = 60.2666
  em = 0.054900
  mm = o~norm(115.3654 + 13.0649929509*d)
  ee = mm + em*180/pi*o~sin(mm)*(1 + em*o~cos(mm))
  xv = am*(o~cos(ee)-em)
  yv = am*o~sqrt(1-em*em)*o~sin(ee)
  vm = o~atan2(yv,xv)
  radius = o~sqrt(xv*xv+yv*yv)
  vw = o~norm(vm+w)
  xm = radius*(o~cos(n)*o~cos(vw)-o~sin(n)*o~sin(vw)*o~cos(incl))
  ym = radius*(o~sin(n)*o~cos(vw)+o~cos(n)*o~sin(vw)*o~cos(incl))
  zm = radius*o~sin(vw)*o~sin(incl)
  moonLon = o~norm(o~atan2(ym,xm))
  moonLat = o~atan2(zm,o~sqrt(xm*xm+ym*ym))
  ls = o~norm(ms+ws)
  lm = o~norm(mm+w+n)
  elong = o~norm(lm-ls)
  f = o~norm(lm-n)
  moonLon = o~norm(moonLon - 1.274*o~sin(mm-2*elong) + 0.658*o~sin(2*elong) -,
    0.186*o~sin(ms) - 0.059*o~sin(2*mm-2*elong) - 0.057*o~sin(mm-2*elong+ms) +,
    0.053*o~sin(mm+2*elong) + 0.046*o~sin(2*elong-ms) + 0.041*o~sin(mm-ms) -,
    0.035*o~sin(elong) - 0.031*o~sin(mm+ms) - 0.015*o~sin(2*f-2*elong) +,
    0.011*o~sin(mm-4*elong))
  moonLat = moonLat - 0.173*o~sin(f-2*elong) - 0.055*o~sin(mm-f-2*elong) -,
    0.046*o~sin(mm+f-2*elong) + 0.033*o~sin(f+2*elong) +,
    0.017*o~sin(2*mm+f)
  radius = radius - 0.58*o~cos(mm-2*elong) - 0.46*o~cos(2*elong)
  moonEq = self~eclipticToEquatorial(moonLon,moonLat,obliq)
  lst = o~norm(ls+180+utHours*15+longitude)

  sunHor = self~horizontal(sunEq[1], sunEq[2],lst,latitude)
  moonHor = self~horizontal(moonEq[1], moonEq[2],lst,latitude)
  /* Moon parallax: geocentric -> observer-surface true altitude. */
  parallaxDeg = o~atan2(1,o~sqrt(radius*radius-1))
  moonTopAltitude = moonHor[1] - parallaxDeg*o~cos(moonHor[1])

  sun = self~body('SUN',sunHor[1],sunHor[2],0,1,.true)
  moonPhaseAngle = o~norm(moonLon-sunLon)
  illuminated = (1-o~cos(moonPhaseAngle)*o~cos(moonLat))/2
  waxing = moonPhaseAngle <= 180
  moon = self~body('MOON',moonTopAltitude,moonHor[2],parallaxDeg,illuminated,waxing)
  moon['phase'] = self~phase(illuminated,waxing)
  moon['elongationDeg'] = moonPhaseAngle
  moon['distanceEarthRadii'] = radius
  /* Daytime Moon is possible but contrast, clouds, glare, occultation are unknown. */
  moon['visibilityCandidate'] = moon['aboveHorizon'] & illuminated >= 0.05 &,
    moon['altitudeRefractedDeg'] >= 2 & sun['altitudeRefractedDeg'] < -6
  moon['headingCandidate'] = moon['visibilityCandidate'] & moon['altitudeTrueDeg'] >= 5
  moon['visibilityReason'] = 'geometric horizon, >=5% illumination, >2 deg elevation, Sun <-6 deg; weather unknown'

  out = .directory~new
  out['utc'] = utc
  out['latitudeDeg'] = latitude
  out['longitudeDeg'] = longitude
  out['julianDate'] = jd
  out['sun'] = sun
  out['moon'] = moon
  out['method'] = 'Schlyter low-precision orbital elements and lunar perturbations; Meeus/Bennett refraction approximation'
  out['coordinates'] = 'azimuth clockwise from true north; degrees; longitude east positive'
  out['status'] = 'PREDICTION_ONLY'
  out['clockModel'] = 'UTC approximated UT1; no delta-T correction'
  out['accuracyStatus'] = 'EPHEMERIS_REFERENCE_TESTED; OBSERVATION_AND_NAVIGATION_UNQUALIFIED'
  out['sourceTag'] = 'MOONSAULT_PREDICTED'
  out['observationIndependent'] = .false
  out['mathematics'] = .MoonsaultAngle~providerName
  return out

::method body private class
  use strict arg name, trueAlt, trueAz, parallax, illum, waxing
  o = .MoonsaultAngle
  apparentAlt = trueAlt + self~refraction(trueAlt)
  b = .directory~new
  b['name'] = name
  b['altitudeTrueDeg'] = trueAlt
  b['azimuthTrueDeg'] = o~norm(trueAz)
  b['altitudeRefractedDeg'] = apparentAlt
  b['azimuthRefractedDeg'] = o~norm(trueAz)
  b['refractionCorrectionDeg'] = apparentAlt-trueAlt
  b['horizontalParallaxDeg'] = parallax
  b['illuminatedFraction'] = illum
  b['aboveHorizon'] = apparentAlt > 0
  b['visibilityCandidate'] = apparentAlt > 0
  b['refractionModelValid'] = trueAlt >= -1 & trueAlt <= 89.9
  b['headingCandidate'] = trueAlt >= 5
  b['method'] = 'geocentric orbital, local sidereal, lunar altitude parallax, standard atmosphere'
  if name = 'SUN' then b['modelErrorBudgetDeg'] = 0.10
  else b['modelErrorBudgetDeg'] = 0.50
  b['modelErrorClaim'] = 'conservative unqualified engineering allowance, not certified'
  return b

::method phase private class
  use strict arg fraction, waxing
  if fraction < 0.02 then return 'NEW'
  if fraction > 0.98 then return 'FULL'
  if fraction > 0.48 & fraction < 0.52 then do
    if waxing then return 'FIRST_QUARTER'
    return 'LAST_QUARTER'
  end
  if waxing then do
    if fraction < 0.5 then return 'WAXING_CRESCENT'
    return 'WAXING_GIBBOUS'
  end
  if fraction < 0.5 then return 'WANING_CRESCENT'
  return 'WANING_GIBBOUS'

::method refraction private class
  /* Bennett formula, 1010 hPa / 10 C, not trusted below -1 degree. */
  use strict arg altitude
  if altitude < -1 | altitude > 89.9 then return 0
  angle = altitude + 10.3/(altitude+5.11)
  return 1.02/(60*.MoonsaultAngle~tan(angle))

::method horizontal private class
  use strict arg ra, dec, lst, latitude
  o = .MoonsaultAngle
  ha = o~norm(lst-ra)
  x = o~cos(ha)*o~cos(dec)
  y = o~sin(ha)*o~cos(dec)
  z = o~sin(dec)
  xh = x*o~sin(latitude) - z*o~cos(latitude)
  yh = y
  zh = x*o~cos(latitude) + z*o~sin(latitude)
  a = .array~new
  a~append(o~atan2(zh,o~sqrt(xh*xh+yh*yh)))
  a~append(o~norm(o~atan2(yh,xh)+180))
  return a

::method eclipticToEquatorial private class
  use strict arg lon, lat, eps
  o = .MoonsaultAngle
  x = o~cos(lon)*o~cos(lat)
  y = o~sin(lon)*o~cos(lat)*o~cos(eps)-o~sin(lat)*o~sin(eps)
  z = o~sin(lon)*o~cos(lat)*o~sin(eps)+o~sin(lat)*o~cos(eps)
  a = .array~new
  a~append(o~norm(o~atan2(y,x)))
  a~append(o~atan2(z,o~sqrt(x*x+y*y)))
  return a

::method julianDate private class
  use strict arg utc
  if utc~length \= 20 then raise syntax 88.900 array('UTC YYYY-MM-DDTHH:MM:SSZ', utc)
  if substr(utc,5,1) \= '-' | substr(utc,8,1) \= '-' |,
     substr(utc,11,1) \= 'T' | substr(utc,14,1) \= ':' |,
     substr(utc,17,1) \= ':' | substr(utc,20,1) \= 'Z' then
     raise syntax 88.900 array('UTC YYYY-MM-DDTHH:MM:SSZ', utc)
  numeric digits 17
  year = substr(utc,1,4); mon = substr(utc,6,2); day = substr(utc,9,2)
  hh = substr(utc,12,2); mm = substr(utc,15,2); ss = substr(utc,18,2)
  if \datatype(year,'W') | \datatype(mon,'W') | \datatype(day,'W') |,
     \datatype(hh,'W') | \datatype(mm,'W') | \datatype(ss,'W') then
    raise syntax 88.900 array('digits in UTC timestamp', utc)
  if year < 1900 | year > 2099 | mon < 1 | mon > 12 |,
     hh < 0 | hh > 23 | mm < 0 | mm > 59 | ss < 0 | ss > 59 then
    raise syntax 88.900 array('UTC 1900-2099 date time bounds',utc)
  lengths = .array~of(31,28,31,30,31,30,31,31,30,31,30,31)
  if year // 4 = 0 & (year // 100 \= 0 | year // 400 = 0) then lengths[2] = 29
  if day < 1 | day > lengths[mon] then raise syntax 88.900 array('valid Gregorian day',utc)
  a = (14-mon) % 12
  y = year+4800-a
  m = mon+12*a-3
  jdn = day + (153*m+2) % 5 + 365*y + y % 4 - y % 100 + y % 400 - 32045
  return jdn - 0.5 + (hh+mm/60+ss/3600)/24

::class MoonsaultAngle public
::method providerName class
  expose backend
  if symbol('BACKEND') = 'VAR' then return 'ALCHEMY_MATHS_ADAPTER'
  return 'OOREXX_RXMATH'
::method setTrigProvider class
  expose backend
  use strict arg selected
  if \selected~hasMethod('SINDEG') | \selected~hasMethod('COSDEG') |,
     \selected~hasMethod('TANDEG') then
    raise syntax 88.900 array('sinDeg/cosDeg/tanDeg provider', selected)
  backend = selected
  return .true
::method load class
  expose loaded
  if symbol('LOADED') = 'VAR' then return .true
  if RxFuncQuery('MathLoadFuncs') then call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
  call MathLoadFuncs
  loaded = .true
  return loaded
::method trigProvider private class
  expose backend
  return backend
::method norm class
  use strict arg angle
  value = angle // 360
  if value < 0 then value += 360
  return value
::method sin class
  use strict arg angle
  if self~providerName = 'ALCHEMY_MATHS_ADAPTER' then return self~trigProvider~sinDeg(angle)
  return RxCalcSin(self~norm(angle), 16, 'D')
::method cos class
  use strict arg angle
  if self~providerName = 'ALCHEMY_MATHS_ADAPTER' then return self~trigProvider~cosDeg(angle)
  return RxCalcCos(self~norm(angle), 16, 'D')
::method tan class
  use strict arg angle
  if self~providerName = 'ALCHEMY_MATHS_ADAPTER' then return self~trigProvider~tanDeg(angle)
  return RxCalcTan(angle, 16, 'D')
::method sqrt class
  use strict arg value
  return RxCalcSqrt(value, 16)
::method atan2 class
  use strict arg y, x
  if x = 0 then do
    if y > 0 then return 90
    if y < 0 then return -90
    return 0
  end
  angle = RxCalcArcTan(y/x,16,'D')
  if x < 0 then do
    if y >= 0 then angle += 180
    else angle -= 180
  end
  return angle
