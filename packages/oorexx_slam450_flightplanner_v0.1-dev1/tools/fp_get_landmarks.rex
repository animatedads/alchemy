/* fp_get_landmarks.rex - SLAM 450 Flight Planner v0.1: charted landmarks
 * along a route, for visual position fixes (the Moonsault camera-fix method:
 * bearings to recognised landmarks, intersected).
 *
 *   rexx fp_get_landmarks.rex <routeFile> <radiusKm> <outFile>
 *
 * One OpenStreetMap Overpass request through Alchemy's API Client: every
 * lighthouse, named cape and named summit within radiusKm of the route's
 * polyline. Output (.words, one record per line):
 *   landmarkset|<routeFile>|<radiusKm>|overpass
 *   credit|Map data (c) OpenStreetMap contributors, ODbL 1.0
 *   evidence|1|<url>|<status>|<bytes>|<sha512>|<retrieved>
 *   landmark|<kind lighthouse|cape|peak>|<name>|<lat>|<lon>|<ground m AMSL or ->|<structure height m or ->
 * Names have '|' replaced by '/'. Unnamed lighthouses are kept, as
 * "lighthouse <osm id>". Test mode: a saved Overpass response from
 * FP_LANDMARKS_FROMFILE (nothing is fetched).
 *
 * Not yet included: towers, bridges and other built landmarks (too many
 * unnamed in OSM to rank without a prominence measure), and peak
 * prominence (a named summit is not always one a camera can pick out).
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-10.
 */
parse arg routeFile radiusKm outFile
if outFile == '' then do
  say 'usage: rexx fp_get_landmarks.rex <routeFile> <radiusKm> <outFile>'
  exit 2
end
exit .FpGetLandmarks~new(routeFile, radiusKm, outFile)~run

::requires 'FpLog.cls'
::requires 'json.cls'
::requires 'FpRoute.cls'

::class FpGetLandmarks public
::method init
  expose routeFile radiusKm outFile
  use strict arg routeFile, radiusKm, outFile

::method run
  expose routeFile radiusKm outFile
  log = .FpLog~for(self)
  points = .FpRoute~load(routeFile)
  log~log(.Log~INFO, points~items 'route points from' routeFile', landmarks within' radiusKm 'km')
  /* the route as an Overpass linestring: lat,lon,lat,lon,... */
  line = ''
  do p over points; line = line','p['LAT']','p['LON']; end
  near = '(around:'radiusKm * 1000 || line')'
  query = '[out:json][timeout:180];(' ,
       || 'node["man_made"="lighthouse"]'near';' ,
       || 'way["man_made"="lighthouse"]'near';' ,
       || 'node["natural"="cape"]["name"]'near';' ,
       || 'node["natural"="peak"]["name"]'near';' ,
       || ');out center tags;'
  url = 'https://overpass-api.de/api/interpreter?data=' || urlEncode(query)
  fromFile = value('FP_LANDMARKS_FROMFILE',, 'ENVIRONMENT')
  if stream(outFile, 'c', 'query exists') \== '' then call SysFileDelete outFile
  call lineout outFile, 'landmarkset|'routeFile'|'radiusKm'|overpass'
  call lineout outFile, 'credit|Map data (c) OpenStreetMap contributors, ODbL 1.0'
  if fromFile \== '' then do
    body = charin(fromFile, 1, chars(fromFile)); call stream fromFile, 'c', 'close'
    log~log(.Log~INFO, 'test response from' fromFile)
    call lineout outFile, 'evidence|1|file:'fromFile'|200|'body~length'|-|-'
  end
  else do
    /* the HTTPS client is loaded only when the network is used */
    .context~package~loadPackage('FpHttp.cls')
    do k over .FpHttp~kitCheck
      log~log(.Log~INFO, 'kit' k)
      if k~word(1) == 'fail' then return 3
    end
    log~log(.Log~INFO, 'GET Overpass (' || url~length 'characters)')
    got = .FpHttp~new~get('landmarks', url); resp = got[1]; ev = got[2]
    call lineout outFile, 'evidence|1|'ev['URL']'|'ev['STATUS']'|'ev['BYTES']'|'ev['SHA512']'|'ev['RETRIEVED']
    if \resp~ok then do
      log~log(.Log~ERROR, 'Overpass failed: status' resp~status ev['ERROR'])
      call stream outFile, 'c', 'close'
      return 4
    end
    body = resp~body
  end
  parsed = .json~fromJson(body)
  if \parsed~hasIndex('elements') then do
    log~log(.Log~ERROR, 'no elements in the response')
    call stream outFile, 'c', 'close'
    return 5
  end
  counts = .directory~new
  do kind over .array~of('lighthouse', 'cape', 'peak'); counts[kind] = 0; end
  do e over parsed['elements']
    tags = e['tags']; if tags == .nil then tags = .directory~new
    lat = e['lat']; lon = e['lon']
    if lat == .nil then do
      c = e['center']
      if c == .nil then iterate
      lat = c['lat']; lon = c['lon']
    end
    kind = ''
    if tag(tags, 'man_made') == 'lighthouse' then kind = 'lighthouse'
    else if tag(tags, 'natural') == 'cape' then kind = 'cape'
    else if tag(tags, 'natural') == 'peak' then kind = 'peak'
    if kind == '' then iterate
    name = tag(tags, 'name')
    if name == '' then do
      if kind \== 'lighthouse' then iterate   /* capes and summits only when named */
      name = kind e['id']
    end
    name = name~changeStr('|', '/')
    ele = number(tag(tags, 'ele'))
    hgt = number(tag(tags, 'height'))
    if hgt == '-' then hgt = number(tag(tags, 'seamark:light:height'))
    call lineout outFile, 'landmark|'kind'|'name'|'lat'|'lon'|'ele'|'hgt
    counts[kind] = counts[kind] + 1
  end
  call stream outFile, 'c', 'close'
  log~log(.Log~INFO, counts['lighthouse'] 'lighthouses,' counts['cape'] 'capes,' counts['peak'] 'named summits written to' outFile)
  return 0

/* a tag's value, '' if absent */
::routine tag
  use strict arg tags, key
  v = tags[key]
  if v == .nil then return ''
  return v

/* the leading number of an OSM value ("1234", "1234 m", "45.5"), or - */
::routine number
  use strict arg v
  v = v~strip~word(1)~changeStr('m', '')
  if datatype(v, 'N') then return v
  return '-'

/* percent-encode everything but the URL-unreserved characters */
::routine urlEncode
  use strict arg s
  keep = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~'
  out = .mutableBuffer~new
  do i = 1 to s~length
    ch = s~subchar(i)
    if keep~pos(ch) > 0 then out~append(ch)
    else out~append('%' || ch~c2x)
  end
  return out~string
