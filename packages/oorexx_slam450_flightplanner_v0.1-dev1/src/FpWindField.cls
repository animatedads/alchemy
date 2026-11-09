/* FpWindField.cls - SLAM 450 Flight Planner v0.1: the hourly wind written by
 * fp_get_wind.rex, read back as a field over route points and time.
 *
 * at(point, utcDateTime) answers the wind at 100 m (10 m where 100 m is
 * missing), interpolated linearly between the hours as east/north
 * components, so a wind backing through north is not averaged through
 * south. Rain and low cloud are taken from the hour before.
 * Directory: W (m/s), FROM (deg true, where it blows from), RAIN (mm/h),
 * LOWCLOUD (%); GUST (10 m gust, m/s, the larger of the two hours; 9 Nov);
 * from 8 Nov also TEMP (2 m, C, interpolated), SNOW (snow depth,
 * m) and PMSL (mean sea-level pressure, hPa, interpolated), each '' when the file
 * has none.
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
::requires 'FpRoute.cls'
::requires 'FpAirframe.cls'
::requires 'MathsBootstrap.cls'

::class FpWindField public
::attribute rows get

::method loadRoute class
  use strict arg file
  return .FpRoute~load(file)

::method init
  expose cells rows hours elevs
  use strict arg file
  cells = .directory~new; rows = 0; hours = .set~new; elevs = .directory~new
  do while lines(file) > 0
    parse value linein(file) with kind '|' name '|' utc '|' ws10 '|' wd10 '|' ws100 '|' wd100 '|' gust '|' low '|' rain '|' temp '|' snow '|' pmsl .
    if kind == 'elev' then do
      if datatype(utc, 'N') then elevs[name] = utc
      iterate
    end
    if kind \== 'wind' then iterate
    w = ws100; d = wd100
    if \datatype(w, 'N') | \datatype(d, 'N') then do; w = ws10; d = wd10; end
    if \datatype(w, 'N') | \datatype(d, 'N') then iterate
    c = .directory~new
    c['U'] = -w * sind(d); c['V'] = -w * cosd(d)
    c['RAIN'] = 0; if datatype(rain, 'N') then c['RAIN'] = rain
    c['LOWCLOUD'] = 0; if datatype(low, 'N') then c['LOWCLOUD'] = low
    /* 8 Nov: 2 m temperature (C), snow depth (m), mean sea-level pressure (hPa); '' when the file predates them */
    c['TEMP'] = ''; if datatype(temp, 'N') then c['TEMP'] = temp
    c['SNOW'] = ''; if datatype(snow, 'N') then c['SNOW'] = snow
    c['GUST'] = ''; if datatype(gust, 'N') then c['GUST'] = gust
    c['PMSL'] = ''; if datatype(pmsl, 'N') then c['PMSL'] = pmsl
    cells[name'|'utc~left(13)] = c
    hours~put(utc~left(13))
    rows += 1
  end
  call stream file, 'c', 'close'

/* ground height of a point, m AMSL, from the file's elev| lines; '' if the
   file has none for it (files fetched before 8 Nov 2026) */
::method elevation
  expose elevs
  use strict arg name
  if elevs~hasIndex(name) then return elevs[name]
  return ''

/* is there wind for the hour of t (any point)? */
::method covers
  expose hours
  use strict arg t
  return hours~hasItem(t~isoDate~left(13))

::method at
  expose cells
  use strict arg name, t
  k0 = t~isoDate~left(13)
  t1 = t + .TimeSpan~fromHours(1)
  k1 = t1~isoDate~left(13)
  if \cells~hasIndex(name'|'k0) then raise syntax 88.900 array('wind for' name 'at' k0)
  c0 = cells[name'|'k0]
  c1 = c0; if cells~hasIndex(name'|'k1) then c1 = cells[name'|'k1]
  f = (t~minutes * 60 + t~seconds) / 3600
  u = c0['U'] + f * (c1['U'] - c0['U'])
  v = c0['V'] + f * (c1['V'] - c0['V'])
  r = .directory~new
  r['W'] = .Maths~sqrt(u*u + v*v)
  dir = 0
  if r['W'] > 0 then dir = .Maths~atan2(-u, -v)~degreesValue
  if dir < 0 then dir = dir + 360
  r['FROM'] = dir
  r['RAIN'] = c0['RAIN']; r['LOWCLOUD'] = c0['LOWCLOUD']
  r['SNOW'] = c0['SNOW']
  r['GUST'] = c0['GUST']
  if datatype(c0['GUST'], 'N') & datatype(c1['GUST'], 'N') then r['GUST'] = max(c0['GUST'], c1['GUST'])
  r['TEMP'] = c0['TEMP']; r['PMSL'] = c0['PMSL']
  if datatype(c0['TEMP'], 'N') & datatype(c1['TEMP'], 'N') then r['TEMP'] = c0['TEMP'] + f * (c1['TEMP'] - c0['TEMP'])
  if datatype(c0['PMSL'], 'N') & datatype(c1['PMSL'], 'N') then r['PMSL'] = c0['PMSL'] + f * (c1['PMSL'] - c0['PMSL'])
  return r
