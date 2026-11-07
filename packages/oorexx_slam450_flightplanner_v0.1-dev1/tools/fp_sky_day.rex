/* fp_sky_day.rex - SLAM 450 Flight Planner v0.1: the day's light at one place.
 *
 * Sunrise, sunset, civil dawn and dusk, moonrise, moonset and the Moon's
 * illuminated fraction for one place and local date, from Moonsault's own
 * ephemeris (MoonsaultEphemeris~sunMoon). Nothing is fetched: this is the
 * planner's "light" input, and the sky Moonsault gives SLAM 450 in flight.
 *
 * Usage:
 *   rexx fp_sky_day.rex <name> <lat> <lon> <YYYY-MM-DD> <utcOffsetHours> [stepMinutes] [outFile]
 *   rexx fp_sky_day.rex sydney_heads -33.83 151.29 2026-10-31 11
 * Output: a progress log (FpLog), and outFile (default sky_<name>_<date>.words):
 *   sky|<name>|<lat>|<lon>|<date>|<utcOffset>
 *   event|<kind>|<utc>|<local>|<azimuthDeg>
 *   moon|illuminated|<fraction at local noon>
 * Events: civil-dawn, sunrise, sunset, civil-dusk, moonrise, moonset.
 * Altitudes: Sun rise/set at -0.833 deg true (refraction + semi-diameter),
 * civil twilight at -6 deg true, Moon rise/set at 0 deg refracted (centre);
 * found by stepping (default 2 min) and interpolating, so +-1 min.
 *
 * Needs on REXX_PATH: this package's src, oorexx_moonsault_v0.1/src,
 * oorexx_maths (Maths.cls), oorexx_logging_v0.7/src.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
parse arg name lat lon day off stepMin outFile
if day == '' then do
  say 'usage: rexx fp_sky_day.rex <name> <lat> <lon> <YYYY-MM-DD> <utcOffsetHours> [stepMinutes] [outFile]'
  exit 2
end
if stepMin == '' then stepMin = 2
if outFile == '' then outFile = 'sky_'name'_'day'.words'
tool = .FpSkyDay~new(name, lat, lon, day, off, stepMin, outFile)
exit tool~run

::requires 'FpLog.cls'
::requires 'MoonsaultEphemeris.cls'

::class FpSkyDay public
::method init
  expose name lat lon day off stepMin outFile
  use strict arg name, lat, lon, day, off, stepMin, outFile

::method run
  expose name lat lon day off stepMin outFile
  numeric digits 16
  log = .FpLog~for(self)
  log~log(.Log~INFO, name 'at' lat lon', local date' day', UTC'off', step' stepMin 'min')
  /* local midnight to midnight, in UTC seconds since the day's local midnight */
  base = .DateTime~fromIsoDate(day'T00:00:00.000000')
  startUtc = base - .TimeSpan~fromHours(off)
  watch = .array~of(.array~of('sun', -6, 'civil-dawn', 'civil-dusk', 'altitudeTrueDeg'), -
                    .array~of('sun', -0.833, 'sunrise', 'sunset', 'altitudeTrueDeg'), -
                    .array~of('moon', 0, 'moonrise', 'moonset', 'altitudeRefractedDeg'))
  events = .array~new
  prev = .nil
  steps = 24*60 % stepMin
  do i = 0 to steps
    t = startUtc + .TimeSpan~fromMinutes(i*stepMin)
    a = .MoonsaultEphemeris~sunMoon(utcText(t), lat, lon)
    if prev \== .nil then do w over watch
      v0 = prev[w[1]][w[5]]; v1 = a[w[1]][w[5]]
      if (v0 - w[2]) * (v1 - w[2]) <= 0 & v0 \= v1 then do
        f = (w[2] - v0) / (v1 - v0)
        te = t - .TimeSpan~fromSeconds(trunc((1 - f) * stepMin * 60))
        kind = w[3]; if v1 < v0 then kind = w[4]
        events~append(.array~of(kind, te, a[w[1]]['azimuthTrueDeg']))
        log~log(.Log~INFO, left(kind, 11) localText(te, off) 'local, azimuth' format(a[w[1]]['azimuthTrueDeg'],,0) 'deg')
      end
    end
    prev = a
    if i // (steps % 4) = 0 then log~log(.Log~INFO, 'stepped to' localText(t, off) 'local ('i'/'steps')')
  end
  noon = .MoonsaultEphemeris~sunMoon(utcText(startUtc + .TimeSpan~fromHours(12)), lat, lon)
  illum = noon['moon']['illuminatedFraction']
  log~log(.Log~INFO, 'Moon illuminated' format(illum * 100,,0)'% at local noon,' noon['moon']['phase'])
  call lineout outFile, 'sky|'name'|'lat'|'lon'|'day'|'off, 1
  do e over events
    call lineout outFile, 'event|'e[1]'|'utcText(e[2])'|'localText(e[2], off)'|'format(e[3],,1)
  end
  call lineout outFile, 'moon|illuminated|'format(illum,,3)'|'noon['moon']['phase']
  call stream outFile, 'c', 'close'
  log~log(.Log~INFO, events~items 'events written to' outFile)
  return 0

::routine utcText
  use strict arg t
  return t~isoDate~left(19)'Z'

::routine localText
  use strict arg t, off
  return (t + .TimeSpan~fromHours(off))~isoDate~substr(12, 5)
