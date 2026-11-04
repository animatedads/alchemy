/* SLAM450 v0.88 fixed-wing flight computer (pilot side, onboard).
 * Architecture: Tom Dyer. Implementation: Claude (Opus 5.5), 2026-11-03.
 *
 * Inputs are the SAME as any SLAM pilot: its own indexed panorama, the
 * target stage, the quad-style intent the shared learning pilot produced,
 * the negotiated HOLD flag and its own battery meter. No XYZ, no oracle.
 * Output is a fixed-wing setpoint command for the airframe's inner loop:
 *   array(turn_deg_per_tick, airspeed_setpoint_mps, climb_mps, 0)
 *
 * Operations profile (what a wing must do differently from a quad):
 *   - it cannot stop: HOLD becomes a LOITER orbit at best-endurance speed;
 *   - searching becomes an ORBIT scan instead of yawing on the spot;
 *   - a close target abeam/behind is inside the turn circle, so it EXTENDs
 *     straight out for a few ticks and comes back round;
 *   - a steep target above/below is reached by SPIRAL climb/descent;
 *   - separation is by turning AND changing level (no sideways step);
 *   - below 15% charge it flies best-range; below 5% it glides.
 */
::requires 'Slam450Flight.cls'

::class Slam450FixedWingFlightComputer public
::attribute lastMode get
::attribute counts get
::method init
  expose extendTicks orbitSign lastMode counts
  extendTicks=0;orbitSign=1;lastMode='INIT';counts=.directory~new
::method note private
  expose lastMode counts
  use strict arg mode
  lastMode=mode
  if counts~hasIndex(mode) then counts[mode]=counts[mode]+1
  else counts[mode]=1
::method command
  expose extendTicks orbitSign
  use strict arg frame,target,intent,hold=.false,meter=.nil
  numeric digits 16
  vis=.Slam450Vision~new
  cruise=8;loiter=7.4;fast=10
  climbIntent=0
  if intent~items>=3 then climbIntent=max(-3,min(3,intent[3]))
  /* 1. Separation. Silhouette size encodes HORIZONTAL range only, so a
     craft hovering far above/below looks large. A wing threatens only what
     is ahead (+-60 deg) and roughly co-altitude (|el| <= 20 deg). */
  threat=.nil
  do symbol over .array~of('R','P')
    do s over vis~observeBlobs(frame,symbol)
      if s['WIDTH']<16 | abs(s['AZ'])>60 | abs(s['EL'])>20 then iterate
      if threat==.nil then threat=s
      else if s['WIDTH']>threat['WIDTH'] then threat=s
    end
  end
  obs=.nil
  if target>0 then obs=vis~observe(frame,target)
  /* A committed, centred final approach is aborted only by a very close
     threat; the referee's hard 4 m separation limit still applies. */
  if threat\==.nil & obs\==.nil then do
    if max(obs['WIDTH'],obs['HEIGHT'])>=8 & abs(obs['AZ'])<=20 & threat['WIDTH']<30 then threat=.nil
  end
  if threat\==.nil then do
    turn=-30;if threat['AZ']<0 then turn=30
    climb=2.5;if threat['EL']>0 then climb=-2.5
    self~note('SEPARATE')
    return .array~of(turn,9,climb,0)
  end
  /* 2. Negotiated hold: a wing cannot hover, so it loiters. */
  if hold then do
    self~note('LOITER')
    return .array~of(30*orbitSign,loiter,0,0)
  end
  if obs==.nil then do
    /* 3. Search: orbit scan; follow a recalled bearing if the shared
       visual memory supplied one (intent yaw not the plain 12 deg scan). */
    turn=20*orbitSign
    if intent[1]\=12 & intent[1]\=0 then turn=max(-30,min(30,intent[1]))
    speed=cruise;if intent[2]<1 then speed=loiter
    self~note('SEARCH_ORBIT')
    return self~energy(.array~of(turn,speed,climbIntent,0),meter)
  end
  az=obs['AZ'];el=obs['EL'];size=max(obs['WIDTH'],obs['HEIGHT'])
  if az<0 then orbitSign=-1
  else orbitSign=1
  /* 4. Extend: target close and outside +-70 deg is inside the circle. */
  if extendTicks>0 then do
    extendTicks-=1
    self~note('EXTEND')
    return self~energy(.array~of(0,cruise,self~climbFor(el,cruise),0),meter)
  end
  if abs(az)>70 & size>=6 then do
    extendTicks=3
    self~note('EXTEND')
    return self~energy(.array~of(0,cruise,self~climbFor(el,cruise),0),meter)
  end
  /* 5. Spiral when the target is steeply above/below and near. */
  if abs(el)>30 & size>=6 then do
    climb=3;if el<0 then climb=-3
    self~note('SPIRAL')
    return self~energy(.array~of(30*orbitSign,loiter,climb,0),meter)
  end
  /* 6. Track: point at it, speed by apparent size. */
  speed=cruise
  if size<5 then speed=9
  if size<5 & intent[2]>=6 then speed=fast
  if size>=15 then speed=7.6
  turn=max(-30,min(30,az))
  self~note('TRACK')
  return self~energy(.array~of(turn,speed,self~climbFor(el,speed),0),meter)
::method climbFor private
  /* Path angle toward the target's elevation, within airframe limits. */
  use strict arg el,speed
  numeric digits 16
  c=speed*RxCalcTan(max(-60,min(60,el)),16)*0.8
  return max(-3,min(3,c))
::method energy private
  use strict arg cmd,meter
  if meter==.nil then return cmd
  if meter['PERCENT']<15 then cmd[2]=min(cmd[2],8.6)
  if meter['PERCENT']<5 then do
    cmd[2]=8;cmd[3]=min(cmd[3],-0.8)
    self~note('LOW_POWER_GLIDE')
  end
  return cmd
