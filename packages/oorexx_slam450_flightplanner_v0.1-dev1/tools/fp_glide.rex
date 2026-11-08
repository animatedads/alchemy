/* fp_glide.rex - SLAM 450 Flight Planner v0.1: how far the fixed wing can
 * glide, and what the trip costs, judged on the 7 days before the flight.
 *
 * For each of the 7 days before the flight date, the planned flight is
 * "flown" through that day's ERA5 wind: the same departure time, the same
 * waypoints, the wind at 100 m interpolated to the minute the craft reaches
 * each leg. That gives, for every leg, the spread of winds it may meet and
 * so the spread of:
 *   - ground speed and leg time (the wind triangle), so trip time and energy;
 *   - glide reach from the cruise height: into the wind, down it, across it;
 *   - crosswind against the airframe's limit;
 *   - low cloud and rain at the minute of passage (the cameras need to see).
 * The flight date itself is flown too when its wind is in the file, as the
 * check of how well the week predicted the day; it does not shape the plan.
 *
 * Usage:
 *   rexx fp_glide.rex <routeFile> <windFile> <flightDate> <departLocal> <utcOffset> <heightAGL> [outFile]
 *   rexx fp_glide.rex data/coast_route.words out/wind_coast.words 2026-10-31 06:00 11 120
 * Airframe: FpAirframe (planning defaults, FP_* environment overrides).
 * Output: progress log (FpLog), and outFile (default out/glide_<date>.words):
 *   airframe|<description>
 *   day|<date>|<role prior|flight>|<depart>|<arrive local>|<hours>|<energy %>|<min reach into wind m>|<max crosswind>|<legs over limit>|<legs with rain>|<legs low cloud>|<highest ground m AMSL>|<total climb m>
 *   leg|<n>|<from>|<to>|<km>|<track>|<median wind>|<max wind>|<min reach into wind m>|<max crosswind>|<mean ground speed>|<higher end's ground m AMSL>
 * Ground heights come from the wind file's elev| lines (sea level if none).
 * Each leg is flown at heightAGL above the mean of its ends' ground, at
 * true airspeed for that density; energy counts the thinner air and every
 * climb between waypoints (FpAirframe). Ground between waypoints is not
 * seen yet: that is the Copernicus DEM's job.
 *   reach|<height m>|<wind m/s>|<into m>|<across m>|<down m>|<seconds>
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
parse arg routeFile windFile flightDate departLocal off height outFile
if height == '' then do
  say 'usage: rexx fp_glide.rex <routeFile> <windFile> <flightDate> <departLocal> <utcOffset> <heightAGL> [outFile]'
  exit 2
end
if outFile == '' then outFile = 'out/glide_'flightDate'.words'
exit .FpGlide~new(routeFile, windFile, flightDate, departLocal, off, height, outFile)~run

::requires 'FpLog.cls'
::requires 'FpAirframe.cls'
::requires 'FpWindField.cls'
::requires 'MathsBootstrap.cls'

::class FpGlide public
::method init
  expose routeFile windFile flightDate departLocal off height outFile
  use strict arg routeFile, windFile, flightDate, departLocal, off, height, outFile

::method run
  expose routeFile windFile flightDate departLocal off height outFile
  log = .FpLog~for(self)
  craft = .FpAirframe~new
  log~log(.Log~INFO, craft~describe)
  route = .FpWindField~loadRoute(routeFile)
  field = .FpWindField~new(windFile)
  log~log(.Log~INFO, route~items 'waypoints;' field~rows 'wind rows from' windFile)
  legs = .array~new; noElev = 0
  do i = 1 to route~items - 1
    a = route[i]; b = route[i+1]
    leg = .directory~new
    leg['N'] = i; leg['FROM'] = a; leg['TO'] = b
    leg['M'] = .FpGeo~distance(a['LAT'], a['LON'], b['LAT'], b['LON'])
    leg['TRACK'] = .FpGeo~bearing(a['LAT'], a['LON'], b['LAT'], b['LON'])
    leg['WINDS'] = .array~new; leg['INTO'] = .array~new; leg['CROSS'] = .array~new; leg['GS'] = .array~new
    /* ground height at each end (sea level when the wind file has none);
       the leg is flown at height above the mean of the two, and climbs
       when the far end is higher */
    ea = field~elevation(a['NAME']); eb = field~elevation(b['NAME'])
    if ea == '' then do; ea = 0; noElev += 1; end
    if eb == '' then eb = 0
    leg['ELEV'] = max(ea, eb)
    leg['SIGMA'] = .FpAirframe~densityRatio((ea + eb) / 2 + height)
    leg['CLIMB'] = max(0, eb - ea)
    legs~append(leg)
  end
  total = 0; climb = 0; top = 0; topName = '-'
  do leg over legs
    total = total + leg['M']; climb = climb + leg['CLIMB']
    if leg['ELEV'] > top then do; top = leg['ELEV']; topName = leg['FROM']['NAME']'/'leg['TO']['NAME']; end
  end
  log~log(.Log~INFO, legs~items 'legs,' format(total/1000,,0) 'km; height' height 'm above ground')
  if noElev > 0 then log~log(.Log~WARN, noElev 'waypoints have no ground height in the wind file; sea level assumed for them')
  log~log(.Log~INFO, 'highest ground' format(top,,0) 'm AMSL ('topName'), so up to' format(top + height,,0) 'm AMSL; total climb' format(climb,,0) 'm')
  /* the days: 7 before the flight, then the flight date */
  base = .DateTime~fromIsoDate(flightDate'T'departLocal':00.000000') - .TimeSpan~fromHours(off)
  days = .array~new
  do k = 7 to 1 by -1; days~append(.array~of(base - .TimeSpan~fromDays(k), 'prior')); end
  days~append(.array~of(base, 'flight'))
  if stream(outFile, 'c', 'query exists') \== '' then call SysFileDelete outFile
  call lineout outFile, 'airframe|'craft~describe
  allPriorW = .array~new
  do dd over days
    t = dd[1]; role = dd[2]
    localDay = (t + .TimeSpan~fromHours(off))~isoDate~left(10)
    if \field~covers(t) then do
      log~log(.Log~WARN, localDay role': no wind in the file for this day; skipped')
      iterate
    end
    secs = 0; budget = 0; minInto = 1e9; maxCross = 0; over = 0; rainy = 0; lowCloud = 0
    do leg over legs
      p = leg['FROM']['NAME']
      w = field~at(p, t + .TimeSpan~fromSeconds(trunc(secs)))
      tri = craft~triangle(leg['TRACK'], w['W'], w['FROM'], leg['SIGMA'])
      g = craft~glide(height, w['W'], leg['SIGMA'])
      if role == 'prior' then do
        leg['WINDS']~append(w['W']); leg['INTO']~append(g['INTO'])
        leg['CROSS']~append(abs(tri['CROSS'])); leg['GS']~append(tri['GROUND'])
        allPriorW~append(w['W'])
      end
      minInto = min(minInto, g['INTO']); maxCross = max(maxCross, abs(tri['CROSS']))
      if \tri['OK'] then over += 1
      if w['RAIN'] > 0.2 then rainy += 1
      if w['LOWCLOUD'] > 60 then lowCloud += 1
      gs = tri['GROUND']; if gs < 1 then gs = 1
      legSecs = leg['M'] / gs
      secs = secs + legSecs
      budget = budget + craft~budgetSeconds(legSecs, leg['SIGMA']) + craft~climbSeconds(leg['CLIMB'])
    end
    hours = secs / 3600
    arrive = (t + .TimeSpan~fromSeconds(trunc(secs)) + .TimeSpan~fromHours(off))~isoDate~substr(12, 5)
    used = 100 * budget / 3600 / craft~enduranceHours
    call lineout outFile, 'day|'localDay'|'role'|'departLocal'|'arrive'|'format(hours,,2)'|'format(used,,0)'|'format(minInto,,0)'|'format(maxCross,,1)'|'over'|'rainy'|'lowCloud'|'format(top,,0)'|'format(climb,,0)
    log~log(.Log~INFO, localDay left(role, 6) 'arrive' arrive', flying' format(hours,,1) 'h,' format(used,,0)'% of budget; shortest glide into wind' format(minInto,,0) 'm; max crosswind' format(maxCross,,1) 'm/s;' over 'legs over limit,' rainy 'with rain,' lowCloud 'low cloud')
  end
  /* per leg, over the prior week */
  do leg over legs
    if leg['WINDS']~items == 0 then iterate
    call lineout outFile, 'leg|'leg['N']'|'leg['FROM']['NAME']'|'leg['TO']['NAME']'|'format(leg['M']/1000,,1)'|'format(leg['TRACK'],,0)'|'format(median(leg['WINDS']),,1)'|'format(maxOf(leg['WINDS']),,1)'|'format(minOf(leg['INTO']),,0)'|'format(maxOf(leg['CROSS']),,1)'|'format(meanOf(leg['GS']),,1)'|'format(leg['ELEV'],,0)
  end
  /* reach against height for the week's median and 90th-percentile wind */
  if allPriorW~items > 0 then do
    w50 = pct(allPriorW, 50); w90 = pct(allPriorW, 90)
    log~log(.Log~INFO, 'prior week at passage: median wind' format(w50,,1) 'm/s, 90th percentile' format(w90,,1) 'm/s')
    do h over .array~of(120, 300, 600, 1500)
      do w over .array~of(0, w50, w90)
        g = craft~glide(h, w)
        call lineout outFile, 'reach|'h'|'format(w,,1)'|'format(g['INTO'],,0)'|'format(g['ACROSS'],,0)'|'format(g['DOWN'],,0)'|'format(g['SECONDS'],,0)
      end
      g = craft~glide(h, w90)
      log~log(.Log~INFO, 'from' right(h, 4) 'm: still air' format(h*craft~glideRatio/1000,,1) 'km; into a' format(w90,,1) 'm/s wind' format(g['INTO']/1000,,2) 'km, across' format(g['ACROSS']/1000,,2) 'km, downwind' format(g['DOWN']/1000,,2) 'km')
    end
  end
  call stream outFile, 'c', 'close'
  log~log(.Log~INFO, 'written' outFile)
  return 0

::routine sorted
  use strict arg a
  s = a~copy; s~sortWith(.NumericComparator~new)
  return s
::routine median
  use strict arg a
  return pct(a, 50)
::routine pct
  use strict arg a, p
  s = sorted(a); n = s~items
  k = max(1, min(n, trunc(p / 100 * n + 0.5)))
  return s[k]
::routine maxOf
  use strict arg a
  m = a[1]; do x over a; m = max(m, x); end
  return m
::routine minOf
  use strict arg a
  m = a[1]; do x over a; m = min(m, x); end
  return m
::routine meanOf
  use strict arg a
  s = 0; do x over a; s = s + x; end
  return s / a~items
