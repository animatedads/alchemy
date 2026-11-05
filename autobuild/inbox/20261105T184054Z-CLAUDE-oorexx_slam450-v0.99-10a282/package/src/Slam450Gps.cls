/* SLAM450 v0.92 — optional GPS receiver (power hungry, needs time to fix).
 * Architecture: Tom Dyer ("optional GPS; to be realistic it must be power
 * hungry and need time to obtain an initial fix; my phone's battery is cut
 * by half with GPS on"). Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Power: Tom's observation is that GPS roughly doubles a phone's drain, i.e.
 * draws about as much as the device's normal use. For these craft "normal
 * use" is flight at about 0.9 unit/s, so the receiver draws 0.9 unit/s
 * (SENSOR category) whenever it is ON, fixed or not. (A bare GNSS chip draws
 * far less; this models the whole powered receiver as Tom specified.)
 * Time to first fix, from when it is switched on (no network assistance on
 * a drone, so no A-GPS):
 *   cold  30 s   first use, or off for more than 120 s
 *   warm   8 s   off for 6..120 s (almanac/ephemeris still valid)
 *   hot    1 s   off for 5 s or less
 * Fix: 1 Hz, horizontal error ~ N(0, 2.0 m) per axis, vertical ~ N(0, 3.5 m),
 * seeded per craft; ground speed and track from successive fixes.
 * Reported in the pilot's OWN map frame: pixel x,y on the plan map (1.5 px
 * per metre, north-up, same crop) and altitude above sea level. This is the
 * paid, non-magic "you are here": nothing without power and patience.
 * SLAM's navigation is visual and does not use absolute position, so SLAM
 * leaves its GPS off; LLM pilots switch it with "gps":true|false, and a
 * back-seat navigator may ask the SLAM pilot to run it (the pilot pays).
 */
::class Slam450Gps public
::attribute status get
::method power class
  return 0.9
::method init
  expose status ttf offSince seed lastFix
  use strict arg craftSeed
  status='OFF';ttf=0;offSince=-1e9;seed=craftSeed;lastFix=.nil
::method gauss private
  /* Box-Muller on the craft's own Lehmer stream. */
  expose seed
  numeric digits 16
  seed=(seed*16807)//2147483647;u1=max(1e-12,seed/2147483647)
  seed=(seed*16807)//2147483647;u2=seed/2147483647
  return RxCalcSqrt(-2*RxCalcLog(u1),16)*RxCalcCos(360*u2)
::method step
  /* on: switch state this tick; pose: truth (x,y,z,hdg); crop: PlanMap crop.
   * Returns a directory STATUS (OFF|ACQUIRING|FIX), SECONDS_TO_FIX, and when
   * fixed X_PX, Y_PX, ALT_M, SPEED_MPS, TRACK_DEG. */
  expose status ttf offSince lastFix
  use strict arg tick,on,pose,crop
  numeric digits 16
  d=.directory~new
  if \on then do
    if status\=='OFF' then offSince=tick
    status='OFF';lastFix=.nil;d['STATUS']='OFF';return d
  end
  if status=='OFF' then do
    gap=tick-offSince
    if gap<=5 then ttf=1
    else if gap<=120 then ttf=8
    else ttf=30
    status='ACQUIRING'
  end
  if status=='ACQUIRING' then do
    ttf-=1
    if ttf>0 then do;d['STATUS']='ACQUIRING';d['SECONDS_TO_FIX']=ttf;return d;end
    status='FIX'
  end
  x=pose[1]+2.0*self~gauss;y=pose[2]+2.0*self~gauss;z=pose[3]+3.5*self~gauss
  d['STATUS']='FIX'
  d['SCALE']=crop[5]
  d['X_PX']=format((x-crop[1])*crop[5],,0);d['Y_PX']=format((crop[4]-y)*crop[5],,0)
  d['ALT_M']=format(z,,0)
  if lastFix\==.nil then do
    dx=x-lastFix[1];dy=y-lastFix[2];sp=RxCalcSqrt(dx*dx+dy*dy,16)
    d['SPEED_MPS']=format(sp,,1)
    tr=0
    if sp>0.01 then do
      if abs(dy)<1e-9 then tr=90+180*(dx<0)
      else do;tr=RxCalcArcTan(dx/dy,16);if dy<0 then tr+=180;if tr<0 then tr+=360;end
    end
    d['TRACK_DEG']=format(tr,,0)
  end
  lastFix=.array~of(x,y,z)
  return d
::method text class
  use strict arg d
  if d['STATUS']=='OFF' then return ''
  if d['STATUS']=='ACQUIRING' then return 'GPS: acquiring satellites, about' d['SECONDS_TO_FIX'] 's to first fix.'
  t='GPS fix: map pixel x='d['X_PX'] 'y='d['Y_PX'] '(plan map,' d['SCALE'] 'px per metre), altitude' d['ALT_M'] 'm above sea'
  if d~hasIndex('SPEED_MPS') then t=t', ground speed' d['SPEED_MPS'] 'm/s, track' d['TRACK_DEG'] 'deg'
  return t'.'
