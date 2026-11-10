/* fp_fixes.rex - SLAM 450 Flight Planner v0.1: where along the route a
 * visual position fix is possible, and how good it would be.
 *
 *   rexx fp_fixes.rex <routeFile> <glideFile> <landmarkFile> <windFile> <utcOffset> <heightAGL> [outFile]
 *
 * The recovery method is the Moonsault camera fix (ChatGPT, 10 Nov 2026):
 * orientation from the sky, then bearings to two or more recognised
 * landmarks, intersected. The goal is to get back on a visual track within
 * 1 NM; SLAM 450's own 3D registration does the precision after that.
 *
 * Inputs: the route; the flight day's schedule (pass| lines from
 * fp_glide.rex); landmarks (fp_get_landmarks.rex); ground heights (the
 * elev| lines of the fp_get_wind.rex file).
 *
 * Every FP_FIX_SAMPLE_KM along each leg, at the time the plane is there:
 *  - a landmark is in sight if it is within FP_FIX_MAXSIGHT_KM and above
 *    the geometric horizon of both (4.12 km x (sqrt hA + sqrt hL), with
 *    standard refraction; hA the plane's height AMSL, hL the landmark top);
 *  - the best fix is the pair of the nearest 8 in sight whose bearings
 *    cross at FP_FIX_MINCROSS_DEG or more, with the smallest error
 *    e = (bearing error in radians) x (the farther range) / sin(crossing),
 *    the bearing error being FP_FIX_BEARING_DEG (1.5 deg: the worst
 *    landmark residual of the Kirribilli test);
 *  - a sample "has a fix" when e is 1,852 m (1 NM) or less.
 * At each leg's midpoint and time, the Sun and Moon from Moonsault: the
 * sky orientation available on that leg.
 *
 * Output (.words):
 *   fixset|<route>|<bearing err deg>|<sample km>|<max sight km>|<kinds>|<height AGL>
 *   sample|<km along>|<leg>|<lat>|<lon>|<local time>|<in sight>|<fix error m or ->|<landmark 1>|<landmark 2>
 *   fixleg|<n>|<from>|<to>|<km>|<start local>|<samples>|<with fix>|<best error m>|<sun az>|<sun alt>|<moon az>|<moon alt>
 *   gap|<from km>|<to km>|<from leg>|<to leg>
 *   fixsummary|<route km>|<samples>|<with fix>|<gaps>|<longest gap km>|<where>
 *
 * Not yet: terrain between plane and landmark (the Copernicus DEM), cloud
 * and haze (the sight limit stands in for both), and whether the camera
 * can recognise a given summit (all named summits count).
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-10.
 */
parse arg routeFile glideFile landmarkFile windFile off height outFile
if height == '' then do
  say 'usage: rexx fp_fixes.rex <routeFile> <glideFile> <landmarkFile> <windFile> <utcOffset> <heightAGL> [outFile]'
  exit 2
end
if outFile == '' then outFile = 'out/fixes.words'
exit .FpFixes~new(routeFile, glideFile, landmarkFile, windFile, off, height, outFile)~run

::requires 'FpLog.cls'
::requires 'FpRoute.cls'
::requires 'FpAirframe.cls'
::requires 'FpWindField.cls'
::requires 'MathsBootstrap.cls'
::requires 'MoonsaultEphemeris.cls'

::class FpFixes public
::method init
  expose routeFile glideFile landmarkFile windFile off height outFile
  use strict arg routeFile, glideFile, landmarkFile, windFile, off, height, outFile

::method run
  expose routeFile glideFile landmarkFile windFile off height outFile
  numeric digits 16
  log = .FpLog~for(self)
  errDeg = env('FP_FIX_BEARING_DEG', 1.5)
  stepKm = env('FP_FIX_SAMPLE_KM', 5)
  sightKm = env('FP_FIX_MAXSIGHT_KM', 60)
  minCross = env('FP_FIX_MINCROSS_DEG', 30)
  kinds = value('FP_FIX_KINDS',, 'ENVIRONMENT')
  if kinds == '' then kinds = 'lighthouse cape peak'
  nm = 1852
  errRad = errDeg * 3.14159265358979 / 180
  route = .FpRoute~load(routeFile)
  field = .FpWindField~new(windFile)
  /* the flight day's schedule */
  pass = .directory~new
  do while lines(glideFile) > 0
    parse value linein(glideFile) with kind '|' n '|' a '|' b '|' t0 '|' t1 .
    if kind == 'pass' then pass[n] = .array~of(isoUtc(t0), isoUtc(t1))
  end
  call stream glideFile, 'c', 'close'
  if pass~items \= route~items - 1 then do
    log~log(.Log~ERROR, glideFile 'has' pass~items 'pass lines for' route~items - 1 'legs (rerun fp_glide.rex from 10 Nov)')
    return 5
  end
  /* landmarks of the chosen kinds */
  marks = .array~new
  do while lines(landmarkFile) > 0
    parse value linein(landmarkFile) with kind '|' kn '|' name '|' la '|' lo '|' ele '|' hgt .
    if kind \== 'landmark' then iterate
    if wordpos(kn, kinds) == 0 then iterate
    top = 0
    if datatype(ele, 'N') then top = ele
    if datatype(hgt, 'N') then top = top + hgt
    m = .directory~new
    m['NAME'] = kn':'name; m['LAT'] = la; m['LON'] = lo; m['TOP'] = max(top, 0)
    marks~append(m)
  end
  call stream landmarkFile, 'c', 'close'
  log~log(.Log~INFO, marks~items 'landmarks (' || kinds || '),' route~items - 1 'legs; bearing error' errDeg 'deg, every' stepKm 'km, sight up to' sightKm 'km')
  if stream(outFile, 'c', 'query exists') \== '' then call SysFileDelete outFile
  call lineout outFile, 'fixset|'routeFile'|'errDeg'|'stepKm'|'sightKm'|'kinds'|'height
  along = 0; total = 0; withFix = 0
  gaps = .array~new; gapStart = ''; gapLeg = ''; lastKm = 0; lastLeg = 0
  do n = 1 to route~items - 1
    pa = route[n]; pb = route[n + 1]
    legKm = .FpGeo~distance(pa['LAT'], pa['LON'], pb['LAT'], pb['LON']) / 1000
    ea = groundOf(field, pa['NAME']); eb = groundOf(field, pb['NAME'])
    t0 = pass[n][1]; t1 = pass[n][2]
    legSecs = (t1 - t0)~totalSeconds
    samples = 0; fixed = 0; best = ''
    s = 0
    do while s < legKm | (n == route~items - 1 & s <= legKm)
      f = s / legKm
      lat = pa['LAT'] + f * (pb['LAT'] - pa['LAT'])
      lon = pa['LON'] + f * (pb['LON'] - pa['LON'])
      hA = ea + f * (eb - ea) + height
      t = t0 + .TimeSpan~fromSeconds(trunc(f * legSecs))
      fix = self~bestFix(marks, lat, lon, hA, sightKm, minCross, errRad)
      samples += 1; total += 1
      km = along + s
      e = fix['ERR']
      isFix = 0
      if e \== '-' then do
        isFix = (e <= nm)
        if best == '' then best = e
        best = min(best, e)
      end
      if isFix then do
        fixed += 1; withFix += 1
        if gapStart \== '' then do
          gaps~append(.array~of(gapStart, lastKm, gapLeg, lastLeg)); gapStart = ''
        end
      end
      else if gapStart == '' then do
        gapStart = km; gapLeg = n
      end
      call lineout outFile, 'sample|'format(km,,1)'|'n'|'format(lat,,4)'|'format(lon,,4)'|'localText(t, off)'|'fix['SEEN']'|'fmt0(e)'|'fix['A']'|'fix['B']
      lastKm = km; lastLeg = n
      s = s + stepKm
    end
    /* the sky at the leg's midpoint */
    mid = t0 + .TimeSpan~fromSeconds(trunc(legSecs / 2))
    sky = .MoonsaultEphemeris~sunMoon(mid~isoDate~left(19)'Z', (pa['LAT'] + pb['LAT']) / 2, (pa['LON'] + pb['LON']) / 2)
    call lineout outFile, 'fixleg|'n'|'pa['NAME']'|'pb['NAME']'|'format(legKm,,1)'|'localText(t0, off)'|'samples'|'fixed'|'fmt0(best) ,
      || '|'format(sky['sun']['azimuthTrueDeg'],,0)'|'format(sky['sun']['altitudeTrueDeg'],,1) ,
      || '|'format(sky['moon']['azimuthTrueDeg'],,0)'|'format(sky['moon']['altitudeRefractedDeg'],,1)
    log~log(.Log~INFO, 'leg' n pa['NAME'] '->' pb['NAME']':' fixed'/'samples 'samples with a 1 NM fix; best' fmt0(best) 'm; Sun' format(sky['sun']['altitudeTrueDeg'],,0) 'deg up')
    along = along + legKm
  end
  if gapStart \== '' then gaps~append(.array~of(gapStart, lastKm, gapLeg, lastLeg))
  longest = 0; where = '-'
  do g over gaps
    call lineout outFile, 'gap|'format(g[1],,1)'|'format(g[2],,1)'|'g[3]'|'g[4]
    if g[2] - g[1] > longest then do
      longest = g[2] - g[1]
      where = route[g[3]]['NAME']'..'route[g[4] + 1]['NAME']
    end
  end
  call lineout outFile, 'fixsummary|'format(along,,0)'|'total'|'withFix'|'gaps~items'|'format(longest,,0)'|'where
  call stream outFile, 'c', 'close'
  log~log(.Log~INFO, withFix'/'total 'samples have a 1 NM fix;' gaps~items 'gaps, longest' format(longest,,0) 'km ('where')')
  return 0

/* the best two-landmark fix from one position: ERR (m, or - if none),
   SEEN (landmarks in sight), A and B (the pair) */
::method bestFix
  use strict arg marks, lat, lon, hA, sightKm, minCross, errRad
  r = .directory~new; r['ERR'] = '-'; r['A'] = '-'; r['B'] = '-'
  /* cheap flat-earth screen first, exact range and bearing for the rest */
  kx = cosd(lat) * 111.32; ky = 110.57
  lim2 = sightKm * sightKm
  seen = .array~new
  do m over marks
    dx = (m['LON'] - lon) * kx; dy = (m['LAT'] - lat) * ky
    if dx * dx + dy * dy > lim2 then iterate
    d = .FpGeo~distance(lat, lon, m['LAT'], m['LON']) / 1000
    horizon = 4.12 * (.Maths~sqrt(max(hA, 0)) + .Maths~sqrt(m['TOP']))
    if d > horizon | d > sightKm then iterate
    seen~append(.array~of(d, m['NAME'], .FpGeo~bearing(lat, lon, m['LAT'], m['LON'])))
  end
  r['SEEN'] = seen~items
  if seen~items < 2 then return r
  near = nearest(seen, 8)
  do i = 1 to near~items - 1
    do j = i + 1 to near~items
      cross = abs(sind(near[i][3] - near[j][3]))
      if cross < sind(minCross) then iterate
      e = errRad * max(near[i][1], near[j][1]) * 1000 / cross
      if r['ERR'] == '-' then better = 1
      else better = (e < r['ERR'])
      if better then do
        r['ERR'] = e; r['A'] = near[i][2]; r['B'] = near[j][2]
      end
    end
  end
  return r

/* the k nearest of (range, name, bearing) triples */
::routine nearest
  use strict arg seen, k
  out = .array~new
  pool = seen~copy
  do while out~items < k & pool~items > 0
    bi = 1
    do i = 2 to pool~items
      if pool[i][1] < pool[bi][1] then bi = i
    end
    out~append(pool[bi]); pool~delete(bi)
  end
  return out

::routine groundOf
  use strict arg field, name
  e = field~elevation(name)
  if e == '' then return 0
  return e

::routine isoUtc
  use strict arg text
  return .DateTime~fromIsoDate(text~left(19)'.000000')

::routine localText
  use strict arg t, off
  return (t + .TimeSpan~fromHours(off))~isoDate~substr(12, 5)

::routine fmt0
  use strict arg x
  if x == '' | x == '-' then return '-'
  return format(x,,0)

::routine env
  use strict arg name, default
  v = value(name,, 'ENVIRONMENT')
  if datatype(v, 'N') then return v
  return default
