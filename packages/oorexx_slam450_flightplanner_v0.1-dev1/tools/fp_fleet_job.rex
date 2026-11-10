/* fp_fleet_job.rex - SLAM 450 Flight Planner v0.1: the fleet job for the
 * glide and energy study. Run on one ed209 node, from the package folder,
 * after sourcing bin/fp_env.sh:
 *   rexx tools/fp_fleet_job.rex
 *
 * 1. Kit check: ooRexx version, machine, json.cls, the API Client bridge and
 *    CA bundle, both route files, a writable out/ folder. Any failure stops
 *    the job before anything is fetched, and the kit lines go in the result.
 * 2. For each route (coast; alpine, over Mt Kosciuszko): ERA5 wind, weather
 *    and ground height, 23-31 Oct 2026 UTC (the fetch is in UTC days; 06:00
 *    AEDT on 24 Oct is 19:00 UTC on 23 Oct), every route point
 *    (fp_get_wind.rex, through Alchemy's API Client).
 * 3. For each route: the glide and energy study, flown through the 7 days
 *    before 31 Oct and the day itself, 120 m above ground, leaving at 06:00
 *    and at civil dawn 05:29 AEDT (fp_glide.rex).
 * 4. For each route (10 Nov, optional): OSM landmarks within 60 km
 *    (fp_get_landmarks.rex) and the visual-fix study along the 06:00
 *    schedule (fp_fixes.rex). A failed landmark fetch is logged and the job
 *    carries on without the fix study for that route.
 * 5. out/FLEET_RESULT.txt: the kit, each output with its bytes and SHA-512,
 *    the day, reach and airframe lines of every glide run, and the fixset,
 *    fixleg, gap and fixsummary lines of every fix study - the part to
 *    send back.
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07;
 * two routes 2026-11-08; landmarks and fixes 2026-11-10.
 */
exit .FpFleetJob~new~run

::requires 'FpLog.cls'
::requires 'crypto.cls'

::class FpFleetJob public
::method run
  log = .FpLog~for(self)
  report = 'out/FLEET_RESULT.txt'
  /* each route once, here; everything below loops over this */
  routes = .array~new
  routes~append(.array~of('coast', 'data/coast_route.words'))
  routes~append(.array~of('alpine', 'data/alpine_route.words'))
  call SysMkDir 'out'
  if stream(report, 'c', 'query exists') \== '' then call SysFileDelete report
  call lineout report, 'SLAM 450 Flight Planner fleet job - glide and energy study, coast and alpine routes, 24-31 Oct 2026 AEDT (wind 23-31 Oct UTC)'
  call lineout report, 'node:' value('FP_NODE',, 'ENVIRONMENT') 'started' .DateTime~new~toTimeZone(0)~isoDate~left(19)'Z'
  /* 1. kit */
  parse version v
  kit = .array~new
  if pos('5.3.0', v) > 0 then kit~append('ok   rexx' v)
  else kit~append('fail rexx' v '(want ooRexx 5.3.0)')
  address system 'uname -m' with output stem arch.
  if arch.0 > 0 then machine = arch.1~strip
  else machine = '?'
  if machine == 'x86_64' then kit~append('ok   machine' machine)
  else kit~append('fail machine' machine '(the Foreign Runtime build is x86_64)')
  jsonAt = SysSearchPath('REXX_PATH', 'json.cls')
  if jsonAt == '' then jsonAt = SysSearchPath('PATH', 'json.cls')
  if jsonAt == '' then kit~append('fail json json.cls not on REXX_PATH or PATH (ships with ooRexx 5)')
  else kit~append('ok   json' jsonAt)
  .context~package~loadPackage('FpHttp.cls')
  do line over .FpHttp~kitCheck; kit~append(line); end
  do r over routes
    if stream(r[2], 'c', 'query exists') == '' then kit~append('fail route' r[2] 'not found (run from the package folder)')
    else kit~append('ok   route' r[2])
  end
  if \SysIsFileDirectory('out') then kit~append('fail out cannot create out/')
  else kit~append('ok   out out/')
  failed = 0
  do line over kit
    log~log(.Log~INFO, 'kit' line)
    call lineout report, 'kit' line
    if line~word(1) == 'fail' then failed = 1
  end
  if failed then do
    call lineout report, 'KIT CHECK FAILED: nothing was fetched'
    call stream report, 'c', 'close'
    log~log(.Log~ERROR, 'kit check failed; see' report)
    return 3
  end
  /* 2 and 3, per route */
  winds = .array~new; glides = .array~new; lms = .array~new; fixes = .array~new
  do r over routes
    name = r[1]; route = r[2]
    wind = 'out/wind_'name'_20261023_20261031.words'
    log~log(.Log~INFO, name': ERA5 wind 2026-10-23 to 2026-10-31 UTC')
    rc2 = 'fp_get_wind.rex'(route '2026-10-23 2026-10-31' wind)
    call lineout report, 'step' name 'fp_get_wind rc' rc2
    if rc2 \= 0 then do
      call stream report, 'c', 'close'
      log~log(.Log~ERROR, name': wind fetch failed, rc' rc2)
      return 4
    end
    winds~append(wind)
    do dep over .array~of('06:00', '05:29')
      g = 'out/glide_'name'_20261031_dep'dep~changeStr(':', '')'.words'
      log~log(.Log~INFO, name': glide study, departing' dep 'AEDT')
      rc3 = 'fp_glide.rex'(route wind '2026-10-31' dep '11 120' g)
      call lineout report, 'step' name 'fp_glide' dep 'rc' rc3
      glides~append(g)
    end
    /* landmarks and visual fixes (10 Nov); optional: a failed landmark
       fetch is reported and the job carries on */
    lm = 'out/landmarks_'name'.words'
    log~log(.Log~INFO, name': OSM landmarks within 60 km')
    rc5 = 'fp_get_landmarks.rex'(route '60' lm)
    call lineout report, 'step' name 'fp_get_landmarks rc' rc5
    if rc5 = 0 then do
      lms~append(lm)
      fx = 'out/fixes_'name'_20261031_dep0600.words'
      log~log(.Log~INFO, name': visual fixes along the 06:00 schedule')
      rc6 = 'fp_fixes.rex'(route 'out/glide_'name'_20261031_dep0600.words' lm wind '11 120' fx)
      call lineout report, 'step' name 'fp_fixes rc' rc6
      fixes~append(fx)
    end
    else log~log(.Log~WARN, name': no landmarks (rc' rc5'), so no fix study; the rest stands')
  end
  /* 4. outputs, evidence and the summary lines */
  outs = winds~copy; do g over glides; outs~append(g); end
  do f over lms; outs~append(f); end
  do f over fixes; outs~append(f); end
  do f over outs
    if stream(f, 'c', 'query exists') == '' then do; call lineout report, 'output' f 'MISSING'; iterate; end
    body = charin(f, 1, chars(f)); call stream f, 'c', 'close'
    call lineout report, 'output' f body~length 'bytes sha512' .CryptoHash~hashString(body, 'SHA512')
  end
  do f over glides
    if stream(f, 'c', 'query exists') == '' then iterate
    call lineout report, '--' f
    do while lines(f) > 0
      l = linein(f)
      if l~left(4) == 'day|' | l~left(6) == 'reach|' | l~left(9) == 'airframe|' then call lineout report, l
    end
    call stream f, 'c', 'close'
  end
  do f over fixes
    if stream(f, 'c', 'query exists') == '' then iterate
    call lineout report, '--' f
    do while lines(f) > 0
      l = linein(f)
      if l~left(7) == 'fixset|' | l~left(7) == 'fixleg|' | l~left(4) == 'gap|' | l~left(11) == 'fixsummary|' then call lineout report, l
    end
    call stream f, 'c', 'close'
  end
  call lineout report, 'finished' .DateTime~new~toTimeZone(0)~isoDate~left(19)'Z'
  call stream report, 'c', 'close'
  log~log(.Log~INFO, 'done; send back' report)
  return 0
