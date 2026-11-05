/* SLAM 450 v0.93: dump the stand-in ephemeris for checking against an
 * independent implementation (tests/check_sky450.py).
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * usage: rexx sky450_dump.rex lat lon startUnix count stepSeconds [STANDIN|MOONSAULT] */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg lat lon t0 n step provider .
if provider=='MOONSAULT' then e=.Slam450MoonsaultEphemeris~new(value('MOONSAULT_SRC',,'ENVIRONMENT'))
else e=.Slam450Ephemeris~new
do i=0 to n-1
  t=t0+i*step
  s=e~sunMoon(t,lat,lon)
  say t format(s['SUN_ALT'],,4) format(s['SUN_AZ'],,4) format(s['MOON_ALT'],,4) format(s['MOON_AZ'],,4) format(s['MOON_ILLUM'],,4) format(s['SUN_ALT_APP'],,4)
end
::requires 'Slam450Sky.cls'
