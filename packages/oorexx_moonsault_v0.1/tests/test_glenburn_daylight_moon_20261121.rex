/* Moonsault independent daylight Moon ephemeris test, Glenburn/Paisley.
 * External area reference: approximate PA2 8EL postcode centroid; this is
 * NOT the numerical GPS EXIF or the photographer's exact standing point.
 * 2026-11-21 15:44:59 UTC is camera Gallery recorded time for one image.
 * Independent prediction: Swiss Ephemeris topocentric 2.10, height ~60 m,
 * 1013.25 hPa, 2 C. Prediction != observed pose or GPS navigation fix.
 */
numeric digits 17
utc='2026-11-21T15:44:59Z'
lat=55.822975
lon=-4.431436
answer=.MoonsaultEphemeris~sunMoon(utc,lat,lon)
sun=answer['sun'];moon=answer['moon']
call near moon['azimuthTrueDeg'],88.8206708,0.30,'Moon azimuth true'
call near moon['altitudeTrueDeg'],11.9130042,0.30,'Moon altitude true'
call near sun['azimuthTrueDeg'],230.6240537,0.10,'Sun azimuth true'
call near sun['altitudeTrueDeg'],0.9789832,0.10,'Sun altitude true'
if answer['status'] \= 'PREDICTION_ONLY' then call fail 'status not prediction-only'
if answer['observationIndependent'] then call fail 'model claims an observation'
if moon['illuminatedFraction']<0.80 | moon['illuminatedFraction']>0.95 then -
  call fail 'Moon phase inconsistent with waxing gibbous'
say 'GLENBURN DAYLIGHT MOON PREDICTION PASS'
say 'Moon az/alt' moon['azimuthTrueDeg'] moon['altitudeTrueDeg']
say 'Sun az/alt' sun['azimuthTrueDeg'] sun['altitudeTrueDeg']
say 'NO optical camera pose or GPS coordinate inferred from model'
exit 0
near: procedure
  use arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then call fail label 'expected' expected 'actual' actual
  return
fail: procedure
  parse arg message
  say 'FAIL' message
  exit 2
::requires 'MoonsaultEphemeris.cls'
