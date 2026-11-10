/* SLAM450 v0.88: fixed-wing buddy on Physics World dev51. Claude (Opus 5.5). */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
ph=.Slam450AirframeConstants~hoverJoules
fw=.Slam450FixedWingAirframe~new
sp=fw~spec
call verify abs(sp['CAPACITY']-24.42*3600/ph)<1e-9,'wing pack is 24.42 Wh in hover-second units'
call verify sp['CAN_HOVER']==0 & sp['HOVER_COST']=='','wing declares it cannot hover'
call verify sp['STALL_SPEED']<sp['MIN_SPEED'],'autopilot floor above physics stall'
call verify abs(sp['GLIDE_RATIO']-10)<0.01,'polar glide ratio about 10'
call verify sp['CRUISE_COST']<0.2,'wing level cruise under a fifth of quad hover'
call verify sp['CLIMB_COST_PER_M']>0,'wing climb costs energy'
q=fw~quote(.array~of(0,8,-0.8,0))
call verify q['THROTTLE']==0 & abs(q['TOTAL']-2/ph)<1e-12,'glide setpoint costs avionics only'
q=fw~quote(.array~of(0,0,0,0))
call verify q['AIRSPEED']>=fw~VMIN-1.5,'speed setpoint 0 is floored: no hover'
/* Referee: quad A1/A2 + wing A3. */
k=.directory~new;k['A3']='FIXED_WING'
world=.Slam450World~new(45045,'LEGACY',.false)
ref=.Slam450TrioReferee~new(world,.false,.true,k)
call verify ref~airframeKind('A3')=='FIXED_WING' & ref~airframeKind('A2')=='QUAD','team is one quad + one wing'
call verify abs(ref~batteryReport('A3')['CAPACITY']-sp['CAPACITY'])<1e-9,'wing referee pack matches spec'
hover=.array~of(0,0,0,0)
p0=ref~poseOf('A3')
ignored=ref~advance(hover,hover,.array~of(90,8,0,0))
p1=ref~poseOf('A3')
dturn=p1[4]-p0[4];if dturn<0 then dturn+=360
lane=.MathBinary64ScalarLane~new
limit=lane~degrees(9.80665*lane~tan(lane~radians(30))/7.9)
call verify dturn<=limit+0.01,'commanded 90 deg/tick turn is bank-limited'
s=ref~lastStates['A3']
call verify abs(ref~batteryReport('A3')['REMAINING']-(sp['CAPACITY']-s['PRICE']))<1e-9,'wing debit equals its quoted price'
/* Power-out: drain the wing pack; it must keep gliding (no POWER_STOP). */
do while ref~batteryReport('A3')['REMAINING']>=3; ignored=ref~debitRemote('A3'); end
do while ref~batteryReport('A3')['REMAINING']>=0.03; ignored=ref~debitRadio('A3'); end
zA=ref~poseOf('A3')[3];xA=ref~poseOf('A3')
gl=0
do 6
  ignored=ref~advance(hover,hover,.array~of(0,8,2,0))
  if ref~status\=='RUNNING' then leave
  gl+=1
end
call verify ref~status=='RUNNING' & gl==6,'flat-pack wing keeps flying: no POWER_STOP'
call verify ref~lastStates['A3']['MODE']=='POWER_OUT_GLIDE' & \ref~lastStates['A3']['POWERED'],'motor cut, natural glide mode'
xB=ref~poseOf('A3')
drop=xA[3]-xB[3];dist=HSqrt((xB[1]-xA[1])**2+(xB[2]-xA[2])**2)
call verify drop>0 & dist/drop>8 & dist/drop<10.5,'power-out glide ratio near the polar L/D (climb request ignored)'
call verify ref~batteryReport('A3')['REMAINING']>=0,'no overdraft while gliding'
/* Flight computer: operations profile. */
fc=.Slam450FixedWingFlightComputer~new
frame=makeFrame(480,121)
c=fc~command(frame,1,.array~of(0,0,0,0),.true)
call verify fc~lastMode=='LOITER' & abs(c[1])==30 & c[2]>=7.2,'HOLD becomes a loiter orbit'
c=fc~command(frame,1,.array~of(12,0,0),.false)
call verify fc~lastMode=='SEARCH_ORBIT' & c[1]\=0 & c[2]>=7.2,'search is an orbit, never a hover scan'
call verify c[4]==0,'wing never commands a sideways step'
say 'SLAM450 FIXED WING BUDDY PASS' checks 'checks'
exit 0
makeFrame: procedure
  use arg w,h
  rows=.array~new
  do y=1 to h;rows~append('.'~copies(w));end
  d=.directory~new;d['WIDTH']=w;d['HEIGHT']=h;d['PIXELS']=rows
return d
verify:
  parse arg ok,description
  if \ok then do;say 'FAIL' description;exit 7;end
  checks+=1
return
::requires 'Slam450Trio.cls'
::requires 'Slam450FixedWingPilot.cls'
