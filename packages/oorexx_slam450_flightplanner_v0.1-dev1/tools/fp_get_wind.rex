/* fp_get_wind.rex - SLAM 450 Flight Planner v0.1: hourly wind and weather
 * along a route, from Copernicus ERA5 through Open-Meteo's archive.
 *
 * Get:     one request per batch of up to 11 route points, through Alchemy's
 *          own HTTPS client (FpHttp -> API Client v0.4.1).
 * Process: json.cls, then one line per point and UTC hour.
 * Output (outFile):
 *   windset|<startDate>|<endDate>|era5|open-meteo archive
 *   credit|Contains modified Copernicus Climate Change Service information 2026; weather data by Open-Meteo.com (CC BY 4.0)
 *   evidence|<batch>|<url>|<status>|<bytes>|<sha512>|<retrievedUtc>
 *   elev|<point>|<ground height m AMSL, Open-Meteo's 90 m DEM>
 *   wind|<point>|<utc>|<ws10>|<wd10>|<ws100>|<wd100>|<gust10>|<cloudLow%>|<precip mm>|<temp2m C>|<snow depth m>|<pressure msl hPa>
 * (the last three added 8 Nov 2026). Snow depth is ERA5-Land, from a
 * second, optional request per batch (evidence|<batch>s|...); if it fails
 * the column is - and the wind fetch still succeeds. Test mode: a saved
 * ERA5-Land response from FP_SNOW_FROMFILE.
 * The 100 m wind is 100 m above that ground. Speeds m/s; directions are where the wind blows FROM, degrees true; a
 * missing value is "-". ERA5 is published with about 5 days' delay.
 *
 * Usage:
 *   rexx fp_get_wind.rex <routeFile> <startDate> <endDate> <outFile>
 *   rexx fp_get_wind.rex data/coast_route.words 2026-10-24 2026-10-31 out/wind_coast.words
 * For a test without the network, a saved response stands in for batch 1:
 *   FP_WIND_FROMFILE=<response.json> rexx fp_get_wind.rex ...
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
parse arg routeFile startDate endDate outFile
if outFile == '' then do
  say 'usage: rexx fp_get_wind.rex <routeFile> <startDate> <endDate> <outFile>'
  exit 2
end
exit .FpGetWind~new(routeFile, startDate, endDate, outFile)~run

::requires 'FpLog.cls'
::requires 'json.cls'
::requires 'FpRoute.cls'

::class FpGetWind public
::method init
  expose routeFile startDate endDate outFile
  use strict arg routeFile, startDate, endDate, outFile

::method run
  expose routeFile startDate endDate outFile
  log = .FpLog~for(self)
  points = .FpRoute~load(routeFile)
  log~log(.Log~INFO, points~items 'route points from' routeFile', ERA5' startDate 'to' endDate)
  fromFile = value('FP_WIND_FROMFILE',, 'ENVIRONMENT')
  http = .nil
  if fromFile == '' then do
    /* the HTTPS client is loaded only when the network is used, so a test
       run needs no API Client on its path; kit check before any request */
    .context~package~loadPackage('FpHttp.cls')
    do line over .FpHttp~kitCheck
      log~log(.Log~INFO, 'kit' line)
      if line~word(1) == 'fail' then return 3
    end
    http = .FpHttp~new
  end
  if stream(outFile, 'c', 'query exists') \== '' then call SysFileDelete outFile
  call lineout outFile, 'windset|'startDate'|'endDate'|era5|open-meteo archive'
  call lineout outFile, 'credit|Contains modified Copernicus Climate Change Service information 2026; weather data by Open-Meteo.com (CC BY 4.0)'
  batches = .array~new; batch = .array~new
  do p over points
    batch~append(p)
    if batch~items == 11 then do; batches~append(batch); batch = .array~new; end
  end
  if batch~items > 0 then batches~append(batch)
  rows = 0; b = 0
  do batch over batches
    b += 1
    lats = ''; lons = ''
    do p over batch; lats = lats','p['LAT']; lons = lons','p['LON']; end
    where = 'https://archive-api.open-meteo.com/v1/archive?latitude='lats~substr(2)'&longitude='lons~substr(2)'&start_date='startDate'&end_date='endDate
    url = where || '&hourly=wind_speed_10m,wind_direction_10m,wind_speed_100m,wind_direction_100m,wind_gusts_10m,cloud_cover_low,precipitation,temperature_2m,pressure_msl&wind_speed_unit=ms&timezone=GMT&models=era5'
    /* snow depth is not in ERA5 0.25 deg; ERA5-Land (0.1 deg) has it. A
       second request, and optional: if it fails the wind still stands */
    snowUrl = where || '&hourly=snow_depth&timezone=GMT&models=era5_land'
    if http == .nil then do
      if b > 1 then leave
      body = charin(fromFile, 1, chars(fromFile)); call stream fromFile, 'c', 'close'
      log~log(.Log~INFO, 'batch' b || ': test response from' fromFile)
      call lineout outFile, 'evidence|' || b || '|file:'fromFile'|200|'body~length'|-|-'
    end
    else do
      log~log(.Log~INFO, 'batch' b || '/' || batches~items': GET' batch~items 'points')
      got = http~get('wind' || b, url); resp = got[1]; ev = got[2]
      call lineout outFile, 'evidence|' || b || '|'ev['URL']'|'ev['STATUS']'|'ev['BYTES']'|'ev['SHA512']'|'ev['RETRIEVED']
      if \resp~ok then do
        log~log(.Log~ERROR, 'batch' b 'failed: status' resp~status ev['ERROR'])
        call stream outFile, 'c', 'close'
        return 4
      end
      body = resp~body
    end
    parsed = .json~fromJson(body)
    if parsed~isA(.Directory) then parsed = .array~of(parsed)
    if parsed~items \= batch~items then do
      log~log(.Log~ERROR, 'batch' b || ': expected' batch~items 'locations, got' parsed~items)
      return 5
    end
    got = self~snowFor(http, b, snowUrl, batch~items, log)
    snow = got[1]
    if got[2] \== '' then call lineout outFile, got[2]
    do i = 1 to batch~items
      /* the ground height Open-Meteo used for this point (its 90 m DEM) */
      elev = '-'
      if parsed[i]~hasIndex('elevation') then elev = parsed[i]['elevation']
      if elev == .nil then elev = '-'
      call lineout outFile, 'elev|'batch[i]['NAME']'|'elev
      h = parsed[i]['hourly']
      times = h['time']
      sh = .nil
      if snow \== .nil then do
        if snow[i]~hasIndex('hourly') then sh = snow[i]['hourly']
      end
      if sh \== .nil then do
        if \sh~hasIndex('time') then sh = .nil
      end
      do k = 1 to times~items
        sd = '-'
        if sh \== .nil then do
          if sh['time'][k] == times[k] then sd = v(sh, 'snow_depth', k)
        end
        call lineout outFile, 'wind|'batch[i]['NAME']'|'times[k]':00Z|'v(h,'wind_speed_10m',k)'|'v(h,'wind_direction_10m',k)'|'v(h,'wind_speed_100m',k)'|'v(h,'wind_direction_100m',k)'|'v(h,'wind_gusts_10m',k)'|'v(h,'cloud_cover_low',k)'|'v(h,'precipitation',k),
          || '|'v(h,'temperature_2m',k)'|'sd'|'v(h,'pressure_msl',k)
        rows += 1
      end
    end
    log~log(.Log~INFO, 'batch' b || ': ' rows 'rows so far')
  end
  call stream outFile, 'c', 'close'
  log~log(.Log~INFO, rows 'hourly rows written to' outFile)
  return 0

/* ERA5-Land snow depth for one batch: Array of (per-point objects or .nil,
   its evidence line or ''). The caller writes the evidence: every line of
   outFile is written from run, through one stream. Per-point objects, or
   .nil (with a warning) when it cannot be had. Never stops the wind fetch.
   In test mode a saved response comes from FP_SNOW_FROMFILE, if set. */
::method snowFor
  use strict arg http, b, snowUrl, n, log
  if http == .nil then do
    f = value('FP_SNOW_FROMFILE',, 'ENVIRONMENT')
    if f == '' then return .array~of(.nil, '')
    body = charin(f, 1, chars(f)); call stream f, 'c', 'close'
    evLine = 'evidence|' || b || 's|file:'f'|200|'body~length'|-|-'
  end
  else do
    got = http~get('snow' || b, snowUrl); resp = got[1]; ev = got[2]
    evLine = 'evidence|' || b || 's|'ev['URL']'|'ev['STATUS']'|'ev['BYTES']'|'ev['SHA512']'|'ev['RETRIEVED']
    if \resp~ok then do
      log~log(.Log~WARN, 'batch' b || ': snow depth not fetched (status' resp~status ev['ERROR']'); written as -')
      return .array~of(.nil, evLine)
    end
    body = resp~body
  end
  parsed = .json~fromJson(body)
  if parsed~isA(.Directory) then parsed = .array~of(parsed)
  if parsed~items \= n then do
    log~log(.Log~WARN, 'batch' b || ': snow depth for' parsed~items 'points, expected' n'; written as -')
    return .array~of(.nil, evLine)
  end
  log~log(.Log~INFO, 'batch' b || ': ERA5-Land snow depth fetched')
  return .array~of(parsed, evLine)

::routine v
  use strict arg h, name, k
  if \h~hasIndex(name) then return '-'
  x = h[name][k]
  if x == .nil then return '-'
  return x

