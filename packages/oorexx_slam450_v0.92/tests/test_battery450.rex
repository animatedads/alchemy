/* Native battery contract and endurance qualification, pure ooRexx. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
b=.Slam450Battery~new
radio=b~radioCost;remote=b~remoteCost
call verify abs(remote-100*radio)<0.00000001,'remote cost exactly 100 radio messages'
call verify abs(b~capacity-900)<0.00000001,'nominal aircraft battery'
cruise=.array~of(0,3,0,0)
fast=.array~of(0,7,0,0)
climb=.array~of(0,3,2,0)
descend=.array~of(0,3,-2,0)
hover=.array~of(0,0,0,0)
side=.array~of(0,0,0,3)
turn=.array~of(25,0,0,0)
/* v0.88 physics contract (Physics World dev51 MultirotorMomentumModel).
   Replaces the v0.84 synthetic tariff checks one for one; see README_V088. */
call verify abs(b~quote(hover)['TOTAL']-1)<0.000000001,'hover costs exactly one unit (unit definition)'
call verify b~quote(cruise)['TOTAL']<b~quote(hover)['TOTAL'],'translational lift: 3 m/s cruise cheaper than hover'
call verify b~quote(fast)['TOTAL']<b~quote(cruise)['TOTAL'] & b~quote(fast)['TOTAL']/7<b~quote(cruise)['TOTAL']/3,'7 m/s inside the minimum-power bucket and cheaper per metre'
call verify b~quote(climb)['TOTAL']>b~quote(cruise)['TOTAL'] & abs(b~quote(descend)['TOTAL']-b~quote(cruise)['TOTAL'])<0.000000001,'climb costs power; descent earns no regeneration credit'
call verify b~quote(hover)['TOTAL']>0,'hover and baseline sensors have cost'
call verify abs(b~quote(side)['TOTAL']-b~quote(cruise)['TOTAL'])<0.000000001,'lateral flight priced as horizontal airspeed'
call verify abs(b~quote(turn)['TOTAL']-b~quote(hover)['TOTAL'])<0.000000001,'yaw rotation priced at hover (torque power below model resolution)'
call verify b~debit('RADIO',radio),'radio debitable'
call verify b~debit('LOOKUP',remote),'remote debitable'
call verify abs(b~remaining-(900-radio-remote))<0.000001,'actual meter reports spends'
packet=b~report
call verify packet['SOURCE']=='OWN_BATTERY_METER','meter not oracle'
call verify \packet~hasIndex('WIND_EAST_MPS') & \packet~hasIndex('TRUE_X'),'meter contains no oracle values'
call verify abs(packet['TOTAL_USED']-packet['RADIO_USED']-packet['LOOKUP_USED']-packet['FLIGHT_USED'])<0.000001,'ledger reconciles'
call verify \b~debit('LOOKUP',10000),'no overdraft allowed'
call verify abs(b~remaining-(900-radio-remote))<0.000001,'rejected debit atomic'

/* Calibration specification: one nominal leg = 150 straight cruise ticks.
 * Both cases also budget 100m of ascent and 100 radio messages. */
five=.Slam450Battery~new
 do i=1 to 750
  call verify five~debit('FLIGHT',five~quote(cruise)['TOTAL']),'five-target cruise runway step'||i
 end
 do i=1 to 100
  call verify five~debit('FLIGHT',five~quote(.array~of(0,0,1,0))['ASCENT']),'five-target ascent reserve'||i
  call verify five~debit('RADIO',radio),'five-target radio reserve'||i
 end
call verify five~remaining>0,'five cruise targets without fixed lookup minimum'
three=.Slam450Battery~new
 do i=1 to 450
  call verify three~debit('FLIGHT',three~quote(cruise)['TOTAL']),'three-target cruise runway step'||i
  if i//5==0 then call verify three~debit('LOOKUP',remote),'one lookup every fifth turn'||i
 end
 do i=1 to 100
  call verify three~debit('FLIGHT',three~quote(.array~of(0,0,1,0))['ASCENT']),'three-target ascent reserve'||i
  call verify three~debit('RADIO',radio),'three-target radio reserve'||i
 end
call verify three~remaining>0,'three cruise targets with one-per-five lookups minimum'
call verify three~remaining<900-450-90-100*radio,'lookup access measurably reduces runway'
fullLookup=.Slam450Battery~new
insufficient=.false
 do i=1 to 750
  if \fullLookup~debit('FLIGHT',fullLookup~quote(cruise)['TOTAL']) then do
    insufficient=.true;leave
  end
  if i//5==0 then do
    if \fullLookup~debit('LOOKUP',remote) then do
      insufficient=.true;leave
    end
  end
 end
call verify insufficient,'lookups force tradeoff on five-leg course'

policy=.Slam450BatteryPolicy~new
frame=makeFrame(480,121)
call verify policy~wantRemote((.Slam450Battery~new)~report,1,frame,1,'EVERY'),'lookup legally available on turn 1'
call verify policy~wantRemote((.Slam450Battery~new)~report,3,frame,1,'EVERY'),'lookup legally available on turn 3'
call verify \policy~wantRemote((.Slam450Battery~new)~report,3,frame,1,'FIFTH'),'optional 1/5 policy still available'
call verify \policy~wantRemote((.Slam450Battery~new)~report,5,frame,1,'NONE'),'no-lookup flight mode'
command=policy~adjust(fast,(.Slam450Battery~new)~report)
call verify command[2]==7,'no unnecessary speed cap at full charge'
low=.Slam450Battery~new(100)
 call verify low~debit('FLIGHT',70),'make low capacity meter'
lowMeter=low~report;lowMeter['BEST_RANGE_SPEED']=5
command=policy~adjust(fast,lowMeter)
call verify command[2]==5,'low charge caps speed at the airframe best-range speed'
mem=.Slam450BatteryMemory~new(8)
 do i=1 to 20
   note=mem~observe(i,b~report,cruise,i//5==0,1)
 end
call verify mem~slots~items==8,'private battery observation ring bounded'
call verify mem~slots[1]['TICK']==13,'oldest battery observation evicted'
call verify mem~idea\=='UNKNOWN','energy memory forms a cost idea'

/* Test battery-authority integration in the real three-aircraft referee. */
world=.Slam450World~new(45045,'LEGACY',.false)
ref=.Slam450TrioReferee~new(world,.false,.true)
call verify ref~batteryEnabled,'three independent batteries are enabled'
m1=ref~batteryReport('A1');m2=ref~batteryReport('A2')
call verify m1['REMAINING']==900 & m2['REMAINING']==900,'three full private start meters'
call verify ref~debitRadio('A2'),'A2 charged radio'
call verify ref~debitRemote('A3'),'A3 charged visual remote lookup'
call verify ref~batteryReport('A1')['REMAINING']==900,'A1 unaffected by buddy spend'
call verify abs(ref~batteryReport('A2')['REMAINING']-(900-radio))<0.000001,'A2 own radio cost only'
call verify abs(ref~batteryReport('A3')['REMAINING']-(900-remote))<0.000001,'A3 own lookup cost only'
z=.array~of(0,0,0,0)
ignored=ref~advance(cruise,z,climb)
call verify ref~tick==1,'all three batteries advanced on one flight tick'
call verify abs(ref~batteryReport('A1')['REMAINING']-(900-b~quote(cruise)['TOTAL']))<0.000001,'A1 cruise debit per turn'
call verify abs(ref~batteryReport('A2')['REMAINING']-(900-radio-b~quote(z)['TOTAL']))<0.000001,'A2 hover plus radio debit'
call verify abs(ref~batteryReport('A3')['REMAINING']-(900-remote-b~quote(climb)['TOTAL']))<0.000001,'A3 ascent plus remote debit'
service=.Slam450TrioCameraService~new(world,.true)
a=ref~poseOf('A1');bpose=ref~poseOf('A2');cpose=ref~poseOf('A3')
r1=service~request('A1','CAFE_SYDNEY',1,ref~claims,a,.array~of(bpose,cpose))
r2=service~request('A2','OPERA_WEST_WALK',1,ref~claims,bpose,.array~of(a,cpose))
r3=service~request('A1','BLUES_PT',1,ref~claims,a,.array~of(bpose,cpose))
r4=service~request('A1','BLUES_PT',2,ref~claims,a,.array~of(bpose,cpose))
call verify r1['STATUS']=='GRANTED' & r2['STATUS']=='GRANTED','different craft can request same tick'
call verify r3['STATUS']=='DENIED','no duplicate same craft same tick'
call verify r4['STATUS']=='GRANTED','same craft can request next turn'
call verify service~grants==3,'flexible service counts grants'
/* Real radio/camera services enforce cost atomically, not just caller code. */
auth=.Slam450TrioReferee~new(world,.false,.true)
serverRadio=.Slam450BuddyRadio~new(auth)
msg=.directory~new
msg['FROM']='A2';msg['TO']='A3';msg['KIND']='OBS';msg['EPOCH']=0;msg['SEQ']=1
before=auth~batteryReport('A2')['REMAINING']
call verify serverRadio~send(msg,0)=='QUEUED_NEXT_TICK','radio transport accepts powered message'
call verify abs(auth~batteryReport('A2')['REMAINING']-(before-radio))<0.000001,'radio transport automatically charges sender'
msg['TRUE_X']=123
before=auth~batteryReport('A2')['REMAINING']
call verify serverRadio~send(msg,0)=='DENIED_UNKNOWN_FIELD','invalid packet not forwarded'
call verify auth~batteryReport('A2')['REMAINING']==before,'invalid radio packet incurs no charge'
serverCamera=.Slam450TrioCameraService~new(world,.true,auth)
startA=auth~poseOf('A1');startB=auth~poseOf('A2');startC=auth~poseOf('A3')
full=auth~batteryReport('A1')['REMAINING']
resp=serverCamera~request('A1','CAFE_SYDNEY',1,auth~claims,startA,.array~of(startB,startC))
call verify resp['STATUS']=='GRANTED','meter-backed camera grant'
call verify abs(auth~batteryReport('A1')['REMAINING']-(full-remote))<0.000001,'camera service itself charges one lookup'
resp=serverCamera~request('A1','BLUES_PT',1,auth~claims,startA,.array~of(startB,startC))
call verify resp['STATUS']=='DENIED','camera prevents same-tick duplicate'
call verify abs(auth~batteryReport('A1')['REMAINING']-(full-remote))<0.000001,'denied duplicate not charged'
/* Power failure must stop before moving ANY aircraft; no free cruise. */
empty=.Slam450TrioReferee~new(world,.false,.true)
 do i=1 to 300
  call verify empty~debitRemote('A1'),'drain battery by legal energy debits '||i
 end
call verify empty~batteryReport('A1')['REMAINING']==0,'battery reaches zero without going negative'
p0=empty~poseOf('A1')
ignored=empty~advance(cruise,cruise,cruise)
call verify empty~status=='POWER_STOP' & empty~tick==0,'insufficient energy stops atomic flight tick'
call verify world~distance(p0,empty~poseOf('A1'))==0,'no motion is committed after power exhaustion'
call verify empty~batteryReport('A2')['REMAINING']==900,'other craft not charged for failed tick'
say 'SLAM450 BATTERY PASS' checks 'checks'
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
::requires 'Slam450Buddy.cls'
::requires 'Slam450Learning.cls'
