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
 *   wind|<point>|<utc>|<ws10>|<wd10>|<ws100>|<wd100>|<gust10>|<cloudLow%>|<precip mm>
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
    url = 'https://archive-api.open-meteo.com/v1/archive?latitude='lats~substr(2)'&longitude='lons~substr(2)'&start_date='startDate'&end_date='endDate,
      || '&hourly=wind_speed_10m,wind_direction_10m,wind_speed_100m,wind_direction_100m,wind_gusts_10m,cloud_cover_low,precipitation&wind_speed_unit=ms&timezone=GMT&models=era5'
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
    do i = 1 to batch~items
      /* the ground height Open-Meteo used for this point (its 90 m DEM) */
      elev = '-'
      if parsed[i]~hasIndex('elevation') then elev = parsed[i]['elevation']
      if elev == .nil then elev = '-'
      call lineout outFile, 'elev|'batch[i]['NAME']'|'elev
      h = parsed[i]['hourly']
      times = h['time']
      do k = 1 to times~items
        call lineout outFile, 'wind|'batch[i]['NAME']'|'times[k]':00Z|'v(h,'wind_speed_10m',k)'|'v(h,'wind_direction_10m',k)'|'v(h,'wind_speed_100m',k)'|'v(h,'wind_direction_100m',k)'|'v(h,'wind_gusts_10m',k)'|'v(h,'cloud_cover_low',k)'|'v(h,'precipitation',k)
        rows += 1
      end
    end
    log~log(.Log~INFO, 'batch' b || ': ' rows 'rows so far')
  end
  call stream outFile, 'c', 'close'
  log~log(.Log~INFO, rows 'hourly rows written to' outFile)
  return 0

::routine v
  use strict arg h, name, k
  if \h~hasIndex(name) then return '-'
  x = h[name][k]
  if x == .nil then return '-'
  return x

