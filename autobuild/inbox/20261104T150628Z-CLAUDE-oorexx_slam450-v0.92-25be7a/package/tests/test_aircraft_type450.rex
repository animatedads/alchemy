/* SLAM450 v0.88: aircraft type as an image observation. Claude (Opus 5.5). */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
world=.Slam450World~new(45046,'LEGACY',.false)
cam=.Slam450Camera~new(world,'PURE')
eye=.array~of(250,-650,120,0)
/* 1. Renderer + classifier: correct type at every range, both airframes. */
do kind over .array~of('QUAD','FIXED_WING')
  do d over .array~of(12,25,50,100,200,300)
    other=.directory~new;other['R']=.array~of(eye[1]+d*0.05,eye[2]+d,eye[3]+3,0)
    k=.directory~new;k['R']=kind
    f=cam~renderAt(eye,480,121,.false,.nil,other,.nil,k)
    s=(.Slam450Vision~new)~observe(f,'R')
    c=.Slam450AircraftType~classify(s,480)
    call verify c['TYPE']==kind,kind 'classified at' d 'm (got' c['TYPE'] c['REASON']')'
  end
end
/* 2. Votes: candidate -> confirmed; contradiction is not resolved by fiat. */
mem=.Slam450AircraftTypeMemory~new(8)
other=.directory~new;other['R']=.array~of(255,-600,123,0)
kw=.directory~new;kw['R']='FIXED_WING'
fw=cam~renderAt(eye,480,121,.false,.nil,other,.nil,kw)
kq=.directory~new;kq['R']='QUAD'
fq=cam~renderAt(eye,480,121,.false,.nil,other,.nil,kq)
b=mem~observe(fw,1)
call verify b['R']['TYPE']=='FIXED_WING' & b['R']['CONFIDENCE']=='CANDIDATE','one sighting is a candidate'
b=mem~observe(fw,2);b=mem~observe(fw,3)
call verify b['R']['CONFIDENCE']=='CONFIRMED','three agreeing sightings confirm'
b=mem~observe(fq,4)
call verify b['R']['CONFIDENCE']=='CONTRADICTED' & b['R']['TYPE']=='UNKNOWN','contradiction yields UNKNOWN'
call verify b['P']['TYPE']=='UNKNOWN','unseen buddy has no type'
/* 3. Peer report fills only when own evidence is silent; bad types refused. */
ignored=mem~absorbPeer('P','QUAD')
call verify mem~belief('P')['SOURCE']=='BUDDY_SELF_REPORTED_NOT_ORACLE','peer type tagged as self-report'
call verify mem~belief('R')['SOURCE']=='OWN_IMAGE','own image evidence outranks a peer report'
signal on syntax name badType
ignored=mem~absorbPeer('R','BLIMP'); call verify .false,'invalid peer type rejected'
badType: signal off syntax
checks+=1
/* 4. Radio: OBS carries observed competitor type and own airframe. */
p2=.Slam450BuddyPeer~new('A2',8);p3=.Slam450BuddyPeer~new('A3',8)
pk=.directory~new;pk['FLIGHT_LEVEL']='L1';pk['SAIL']='NEUTRAL';pk['CUP_AIRSPEED_MPS']=3;pk['PITOT_FORWARD_MPS']=3
m=p2~windReport(0,pk,'UNKNOWN','QUAD','QUAD')
radio=.Slam450BuddyRadio~new
call verify radio~send(m,0)=='QUEUED_NEXT_TICK','typed OBS passes the whitelist'
got=radio~receive('A3',1)[1]
call verify got['RIVAL_TYPE']=='QUAD' & got['AIRFRAME']=='QUAD','type fields delivered intact'
call verify p3~absorb(got)=='OBS_STORED','typed OBS stored'
bad=p2~windReport(0,pk,'UNKNOWN','BLIMP','QUAD')
call verify p3~absorb(bad)=='DENIED_BAD_AIRCRAFT_TYPE','unknown aircraft type refused at absorb'
/* 5. Ranging uses the observed type's true size. */
ra=.Slam450RivalAir~new('A2',8)
f=cam~renderAt(eye,480,121,.false,.nil,other,.nil,kw)
n1=ra~observe(f,1,.nil,.nil,0,.nil,'UNKNOWN')
rb=.Slam450RivalAir~new('A2',8)
n2=rb~observe(f,1,.nil,.nil,0,.nil,'FIXED_WING')
call verify datatype(n1['RANGE_APPROX_M'],'N') & datatype(n2['RANGE_APPROX_M'],'N'),'both ranges resolved'
call verify abs(n2['RANGE_APPROX_M']/n1['RANGE_APPROX_M']-2)<0.01,'wing ranged with its own half-span (x2 quad billboard)'
call verify n2['RIVAL_TYPE']=='FIXED_WING','rival observation records the type'
/* 6. Tactics learn per observed rival type. */
t=.Slam450RaceTactics~new('A2',8)
a=t~choose(fq,1,2,1,'FIXED_WING')
call verify a['CONTEXT']~pos('_VS_WING')>0 & a['RIVAL_TYPE']=='FIXED_WING','tactical context keyed by rival type'
a=t~choose(fq,1,2,2,'QUAD')
call verify a['CONTEXT']~pos('_VS_QUAD')>0,'quad rival has its own learned context'
/* 7. Shared flight-window hints: basic normal operating parameters. */
h=.Slam450FlightWindowHints~new
q=h~window('QUAD');w=h~window('FIXED_WING')
call verify q['HOVER'] & \w['HOVER'],'QUAD HOVER TRUE, FIXED HOVER FALSE'
call verify q['SPEED_MIN']==0 & q['SPEED_MAX']==7 & w['SPEED_MIN']==7 & w['SPEED_MAX']==11,'speed windows by type'
call verify h~window('UNKNOWN')==.nil,'no window for an unidentified type'
w['HOVER']=.true
call verify \h~window('FIXED_WING')['HOVER'],'pilots receive copies; the manual cannot be edited'
text=h~describe
call verify text[1]=='QUAD SPEED 0 TO 7' & text[2]=='QUAD HOVER TRUE' & text[7]=='FIXED HOVER FALSE','hint text in operating-manual style'
say 'SLAM450 AIRCRAFT TYPE OBSERVATION PASS' checks 'checks'
exit 0
verify:
  parse arg ok,description
  if \ok then do;say 'FAIL' description;exit 7;end
  checks+=1
return
::requires 'Slam450Flight.cls'
::requires 'Slam450AircraftType.cls'
::requires 'Slam450Buddy.cls'
::requires 'Slam450RivalAir.cls'
::requires 'Slam450RaceTactics.cls'
