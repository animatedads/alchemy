/* fp_fleet_job.rex - SLAM 450 Flight Planner v0.1: the fleet job for the
 * glide and energy study. Run on one ed209 node, from the package folder,
 * after sourcing bin/fp_env.sh:
 *   rexx tools/fp_fleet_job.rex
 *
 * 1. Kit check: ooRexx version, the API Client bridge and CA bundle, the
 *    route file, a writable out/ folder. Any failure stops the job before
 *    anything is fetched, and the kit lines go in the result file.
 * 2. ERA5 wind and weather, 24-31 Oct 2026, every route point
 *    (fp_get_wind.rex, through Alchemy's API Client).
 * 3. The glide and energy study, flown through the 7 days before 31 Oct and
 *    the day itself, 120 m above ground, leaving at 06:00 and at civil dawn
 *    05:29 AEDT (fp_glide.rex).
 * 4. out/FLEET_RESULT.txt: the kit, each output with its bytes and SHA-512,
 *    and the day lines of both glide runs - the part to send back.
 *
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-07.
 */
exit .FpFleetJob~new~run

::requires 'FpLog.cls'
::requires 'crypto.cls'

::class FpFleetJob public
::method run
  log = .FpLog~for(self)
  report = 'out/FLEET_RESULT.txt'
  route = 'data/coast_route.words'
  wind = 'out/wind_coast_20261024_20261031.words'
  call SysMkDir 'out'
  if stream(report, 'c', 'query exists') \== '' then call SysFileDelete report
  call lineout report, 'SLAM 450 Flight Planner fleet job - glide and energy study, 24-31 Oct 2026'
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
  if stream(route, 'c', 'query exists') == '' then kit~append('fail route' route 'not found (run from the package folder)')
  else kit~append('ok   route' route)
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
  /* 2. wind */
  log~log(.Log~INFO, 'step 2: ERA5 wind 2026-10-24 to 2026-10-31')
  rc2 = 'fp_get_wind.rex'(route '2026-10-24 2026-10-31' wind)
  call lineout report, 'step fp_get_wind rc' rc2
  if rc2 \= 0 then do
    call stream report, 'c', 'close'
    log~log(.Log~ERROR, 'wind fetch failed, rc' rc2)
    return 4
  end
  /* 3. glide, two departures */
  outs = .array~of(wind)
  do dep over .array~of('06:00', '05:29')
    g = 'out/glide_20261031_dep'dep~changeStr(':', '')'.words'
    log~log(.Log~INFO, 'step 3: glide study, departing' dep 'AEDT')
    rc3 = 'fp_glide.rex'(route wind '2026-10-31' dep '11 120' g)
    call lineout report, 'step fp_glide' dep 'rc' rc3
    outs~append(g)
  end
  /* 4. outputs, evidence and the day lines */
  do f over outs
    if stream(f, 'c', 'query exists') == '' then do; call lineout report, 'output' f 'MISSING'; iterate; end
    body = charin(f, 1, chars(f)); call stream f, 'c', 'close'
    call lineout report, 'output' f body~length 'bytes sha512' .CryptoHash~hashString(body, 'SHA512')
  end
  do f over outs
    if f == wind then iterate
    if stream(f, 'c', 'query exists') == '' then iterate
    call lineout report, '--' f
    do while lines(f) > 0
      l = linein(f)
      if l~left(4) == 'day|' | l~left(6) == 'reach|' | l~left(9) == 'airframe|' then call lineout report, l
    end
    call stream f, 'c', 'close'
  end
  call lineout report, 'finished' .DateTime~new~toTimeZone(0)~isoDate~left(19)'Z'
  call stream report, 'c', 'close'
  log~log(.Log~INFO, 'done; send back' report)
  return 0
