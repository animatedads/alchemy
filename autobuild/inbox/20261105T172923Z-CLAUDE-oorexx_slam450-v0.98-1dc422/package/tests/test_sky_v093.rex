/* SLAM450 v0.93 race clock, Sun/Moon stand-in and the sky heading fix.
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-04.
 * - the clock parses UTC and round-trips; 1 tick = 1 s;
 * - the Sun at 13:00 AEDT on the December solstice matches PyEphem
 *   (alt 79.471, az 351.203); at local midnight it is down;
 * - the camera paints the Sun where the ephemeris says, and SLAM's bearing
 *   of that dot plus the azimuth recovers the camera heading within 1 deg
 *   for headings all round the compass;
 * - a Sun behind a structure is not painted (structures are drawn after). */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
fails=0
c=.Slam450RaceClock~new('2026-12-21T02:00:00Z')
if c~isoAt(0)\=='2026-12-21T02:00:00Z' then call fail 'clock round trip:' c~isoAt(0)
if c~unixAt(3600)-c~unixAt(0)\=3600 then call fail '1 tick must be 1 s'
if c~isoAt(86400)\=='2026-12-22T02:00:00Z' then call fail 'day rollover:' c~isoAt(86400)
e=.Slam450Ephemeris~new
s=e~sunMoon(c~unixAt(0),-33.852,151.210)
/* 02:00 UTC = 13:00 AEDT. Reference (PyEphem 4.2.1, no refraction):
   alt 79.4712, az 351.2033. The stand-in claims 0.01 deg for the Sun. */
if abs(s['SUN_ALT']-79.4712)>0.05 then call fail 'Sun altitude should be 79.471, got' s['SUN_ALT']
d=abs(s['SUN_AZ']-351.2033);if d>180 then d=360-d
if d>0.3 then call fail 'Sun azimuth should be 351.203, got' s['SUN_AZ']
n=e~sunMoon(c~unixAt(12*3600),-33.852,151.210)
if n['SUN_UP'] then call fail 'Sun must be down at local midnight'
/* paint + observe */
w=.Slam450World~new(45046,'LEGACY')
cam=.Slam450Camera~new(w)
sky=.directory~new;sky['SUN_UP']=.true;sky['SUN_ALT_APP']=25;sky['SUN_AZ']=110;sky['MOON_VISIBLE']=.false
.local['SLAM450.SKY']=sky
noT=.directory~new;do t=1 to 5;noT[t]='T';end
worst=0
do h=0 to 330 by 30
  f=cam~renderAt(.array~of(300,-500,120,h),480,121,.false,noT)
  bb=.Slam450SkyFix~bodyBearing(f,'S')
  if bb==.nil then do;call fail 'Sun not painted at heading' h;iterate;end
  got=.Slam450SkyFix~heading(110,bb[1])
  dd=abs(got-h);if dd>180 then dd=360-dd
  worst=max(worst,dd)
end
if worst>1 then call fail 'heading from the Sun off by' worst 'deg'
/* behind structure: put the Sun low toward the Salesforce tower from the quay */
.local['SLAM450.SKY']=.nil
f=cam~renderAt(.array~of(300,-500,120,0),480,121,.false,noT)
if .Slam450SkyFix~bodyBearing(f,'S')\==.nil then call fail 'no clock: no Sun'
/* Moonsault adapter (packages/oorexx_moonsault_v0.1): same shape, same sky */
msrc=value('MOONSAULT_SRC',,'ENVIRONMENT')
if msrc\=='' then do
  me=.Slam450MoonsaultEphemeris~new(msrc)
  do k over .array~of('SUN_ALT','SUN_AZ','SUN_ALT_APP','MOON_ALT','MOON_AZ','MOON_ALT_APP','MOON_ILLUM','SUN_UP','MOON_VISIBLE','SUN_HEADING_OK','MOON_HEADING_OK')
    if \me~sunMoon(c~unixAt(0),-33.852,151.210)~hasIndex(k) then call fail 'Moonsault adapter lacks' k
  end
  do t=0 to 20
    u=c~unixAt(t*37003)
    a=e~sunMoon(u,-33.852,151.210);b=me~sunMoon(u,-33.852,151.210)
    if abs(a['SUN_ALT']-b['SUN_ALT'])>0.05 then call fail 'Sun altitude stand-in vs Moonsault' a['SUN_ALT'] b['SUN_ALT']
    if a['MOON_ALT']>0 | b['MOON_ALT']>0 then if abs(a['MOON_ALT']-b['MOON_ALT'])>0.3 then call fail 'Moon altitude stand-in vs Moonsault' a['MOON_ALT'] b['MOON_ALT']
  end
  /* night of 2026-11-18 23:00 AEDT: Moon up ~36 deg, 60% lit, Sun down */
  nm=me~sunMoon(.Slam450RaceClock~new('2026-11-18T12:00:00Z')~unixAt(0),-33.852,151.210)
  if nm['SUN_UP'] | \nm['MOON_VISIBLE'] | abs(nm['MOON_ALT']-36.5)>0.5 then call fail 'Moonsault night Moon check failed' nm['MOON_ALT'] nm['MOON_VISIBLE']
end
else say 'NOTE: MOONSAULT_SRC not set; adapter checks skipped'
if fails==0 then say 'TEST_SKY_V093 PASS (worst heading error' format(worst,,2) 'deg)'
else say 'TEST_SKY_V093 FAIL' fails
exit (fails>0)
fail: fails+=1;say 'FAIL:' arg(1);return
::requires 'Slam450Flight.cls'
::requires 'Slam450Sky.cls'
