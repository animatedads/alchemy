/* make_synthetic_wind.rex - test input for fp_glide.rex: a steady wind at
 * every route point, every UTC hour of the given days, in fp_get_wind.rex's
 * output format. Usage: rexx make_synthetic_wind.rex <routeFile> <firstDate> <days> <speed> <fromDeg> <outFile>
 * Written by: Claude (Opus 5.5), 2026-11-07. */
parse arg routeFile firstDate days speed from outFile
pts = .FpRoute~load(routeFile)
if stream(outFile, 'c', 'query exists') \== '' then call SysFileDelete outFile
call lineout outFile, 'windset|synthetic|'speed' m/s from' from
d0 = .DateTime~fromIsoDate(firstDate'T00:00:00.000000')
do k = 0 to days - 1
  do h = 0 to 23
    t = (d0 + .TimeSpan~fromDays(k) + .TimeSpan~fromHours(h))~isoDate~left(16)
    do p over pts
      call lineout outFile, 'wind|'p['NAME']'|'t':00Z|'speed'|'from'|'speed'|'from'|'speed'|0|0'
    end
  end
end
call stream outFile, 'c', 'close'
::requires 'FpRoute.cls'
