/* SLAM450 v0.92 — onboard warning sensors and advisory GPWS callouts (AVOID mode).
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Tom Dyer's design (2026-11-03):
 *  - the look-ahead is "a simple short range narrow band reflective scanner"
 *    (Slam450World~scan: 7 x 3 rays, +-15 deg x {-10,0,+10} deg, 60 m), and
 *    the RADIO ALTIMETER reads height above whatever is directly below;
 *  - each has an operating cost in line with power use and can be turned on
 *    or off; WHEN ON THEY GIVE WARNINGS, WHEN OFF THEY SIT SILENTLY;
 *  - warnings are ADVISORY: SLAM and the LLM pilots may ignore "pull up".
 *
 * Power (hover = 1.00 unit/s = 143.45 W from Physics World): scanner 2.9 W =
 * 0.020 unit/s, radio altimeter 1.0 W = 0.007 unit/s. Assumed small ToF/radar
 * modules; stated, not measured. Debited per tick (SENSOR category).
 *
 * Callouts (only from sensors that are ON):
 *   scanner   OBSTACLE <r> M AHEAD|LEFT|RIGHT  nearest return in the fan;
 *             PULL UP if time to contact < 3 s or r < 10 m
 *             (closing = drop in nearest range since the last scan)
 *   altimeter RADIO ALT <h> M; TOO LOW under 10 m; PULL UP under 6 m sinking
 *
 * SLAM's rules (it may ignore any warning):
 *   altimeter PULL UP -> climb, unless it is deliberately descending onto a
 *     visible near target below (threading, target below, > 3 m up);
 *   scanner PULL UP -> ignore if its own target is visible, within the fan
 *     and nearer than the obstacle by >= 4 m (the target comes first);
 *     otherwise climb if the upper ray ahead is clear, else turn to the side
 *     whose rays reach further, and slow the quad;
 *   other callouts are noted. SLAM runs both sensors whenever AVOID is ON.
 */
::class Slam450Gpws public
::attribute events get
::attribute lastCallouts get
::method power class
  d=.directory~new;d['SCANNER']=0.020;d['ALTIMETER']=0.007
  return d
::method init
  expose kind events lastCallouts lastNearest lastAgl hold holdSide
  use strict arg craftKind='QUAD'
  kind=craftKind~upper;events=.array~new;lastCallouts='';lastNearest=.nil;lastAgl=.nil;hold=0;holdSide=0
::method read
  /* scan: .nil (scanner off) or Slam450World~scan rays; agl: number, 'OFF'
   * or 'NO_RETURN'; climbCmd: last commanded climb. Returns a directory:
   * CALLOUTS (text, '' when silent), SCAN_PULL_UP, ALT_PULL_UP, NEAREST,
   * NEAREST_AZ, UP_CLEAR, SIDE (+1 right / -1 left: the side reaching further). */
  expose lastCallouts lastNearest lastAgl
  use strict arg scan,agl,climbCmd=0,speed=0
  numeric digits 16
  r=.directory~new;r['SCAN_PULL_UP']=.false;r['ALT_PULL_UP']=.false;r['NEAREST']=.nil
  c=.array~new
  if scan\==.nil then do
    near=1e9;nearAz=0;left=0;right=0;upClear=.true;maxR=0
    do d over scan
      maxR=max(maxR,d['RANGE'])
      if d['HIT'] then if d['RANGE']<near then do;near=d['RANGE'];nearAz=d['AZ'];end
      if d['AZ']<0 then left+=d['RANGE']
      if d['AZ']>0 then right+=d['RANGE']
      if d['EL']=10 & abs(d['AZ'])<=5 & d['HIT'] then upClear=.false
    end
    r['UP_CLEAR']=upClear;r['SIDE']=-1;if right>left then r['SIDE']=1
    if near<1e9 then do
      r['NEAREST']=near;r['NEAREST_AZ']=nearAz
      closing=max(0.5,speed)
      if lastNearest\==.nil then if lastNearest-near>0 then closing=max(closing,lastNearest-near)
      ttc=near/closing
      where='AHEAD';if nearAz<0 then where='LEFT';if nearAz>0 then where='RIGHT'
      c~append('OBSTACLE' format(near,,0) 'M' where)
      if ttc<3 | near<10 then do;c~append('PULL UP');r['SCAN_PULL_UP']=.true;end
      lastNearest=near
    end
    else lastNearest=.nil
  end
  else lastNearest=.nil
  if datatype(agl,'N') then do
    sinking=(climbCmd<0);if lastAgl\==.nil then if agl<lastAgl-0.3 then sinking=.true
    c~append('RADIO ALT' format(agl,,1) 'M')
    if agl<6 & sinking then do;r['ALT_PULL_UP']=.true;if c~index('PULL UP')==.nil then c~append('PULL UP');end
    else if agl<10 then c~append('TOO LOW')
    lastAgl=agl
  end
  else if agl=='NO_RETURN' then c~append('RADIO ALT NO RETURN')
  out='';do x over c;if out=='' then out=x;else out=out||'; '||x;end
  lastCallouts=out;r['CALLOUTS']=out
  return r
::method slamAdjust
  /* SLAM pilot: read both sensors, then heed or ignore by its rules. */
  expose kind events hold holdSide
  use strict arg tick,frame,cmd,targetNumber,scan,agl
  numeric digits 16
  r=self~read(scan,agl,cmd[3],max(0,cmd[2]))
  out=cmd~copy;action='NONE'
  /* own target, if visible ahead: bearing, elevation and range (2 m / size) */
  tgtRange=.nil;tgtEl=0;tgtAz=999
  if targetNumber>0 then do
    t=(.Slam450Vision~new)~observe(frame,targetNumber)
    if t\==.nil then do
      k=max(t['WIDTH'],t['HEIGHT']);tgtAz=t['AZ'];tgtEl=t['EL']
      if k>=1 then tgtRange=2/RxCalcTan(k*360/frame['WIDTH'],16)
    end
  end
  if r['ALT_PULL_UP'] then do
    deliberate=.false
    if tgtRange\==.nil then if tgtRange<40 & tgtEl<0 & abs(tgtAz)<=20 & agl>3 then deliberate=.true
    if deliberate then action='IGNORE_ALT_PULL_UP'
    else do;out[3]=max(out[3],2);if agl<4 then out[3]=max(out[3],3);action='ALT_PULL_UP';end
  end
  if r['SCAN_PULL_UP'] & action\=='ALT_PULL_UP' then do
    targetFirst=.false
    if tgtRange\==.nil then if abs(tgtAz)<=15 & tgtRange<r['NEAREST']-4 then targetFirst=.true
    if targetFirst then action='IGNORE_SCAN_PULL_UP'
    else do
      hold=1
      if r['UP_CLEAR'] then do
        action='CLIMB';holdSide=0;out[3]=max(out[3],3)
        if kind\=='FIXED_WING' then out[2]=min(out[2],1.0)
      end
      else do
        action='TURN';holdSide=r['SIDE']
        rate=15;if kind=='FIXED_WING' then rate=20
        out[1]=holdSide*rate
        if kind\=='FIXED_WING' then out[2]=min(out[2],0.8)
      end
    end
  end
  else if action=='NONE' & hold>0 then do
    hold-=1;action='HOLD'
    if holdSide\=0 then do;rate=15;if kind=='FIXED_WING' then rate=20;out[1]=holdSide*rate;end
    else out[3]=max(out[3],3)
  end
  if action\=='NONE' | r['CALLOUTS']\=='' then do
    nr='-';if r['NEAREST']\==.nil then nr=format(r['NEAREST'],,1)
    ag='-';if datatype(agl,'N') then ag=format(agl,,1)
    cl='-';if r['CALLOUTS']\=='' then cl=translate(r['CALLOUTS'],'_',' ')
    events~append(tick action nr ag cl)
  end
  return out
::method llmText
  /* What an LLM pilot or navigator hears: silent when both sensors are off. */
  use strict arg scan,agl,climbCmd=0,speed=0,scannerOn=.false,altimeterOn=.false
  r=self~read(scan,agl,climbCmd,speed)
  if \scannerOn & \altimeterOn then return ''
  state='SENSORS: scanner' word('OFF ON',1+scannerOn)', radio altimeter' word('OFF ON',1+altimeterOn)'.'
  if r['CALLOUTS']=='' then return state 'GPWS (advisory): nothing to report.'
  return state 'GPWS (advisory): 'r['CALLOUTS']'.'
::requires 'Slam450Flight.cls'
