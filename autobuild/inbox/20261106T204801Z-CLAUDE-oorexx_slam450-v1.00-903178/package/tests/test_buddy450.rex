/* Native peer negotiation and isolated information flow. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
bus=.Slam450BuddyRadio~new
p2=.Slam450BuddyPeer~new('A2',8)
p3=.Slam450BuddyPeer~new('A3',8)
call verify p2~peerID=='A3' & p3~peerID=='A2','reciprocal peers'
call verify p2~memory\==p3~memory,'separate memory objects'
claims=.directory~new
available=.directory~new
 do i=1 to 5;available[i]=.true;end
f2=makeFrame('1',480,121)
f3=makeFrame('2',480,121)
bid2=p2~localOffer(f2,available,0)
bid3=p3~localOffer(f3,available,0)
call verify bid2['SCORES'][1]>bid2['SCORES'][2],'A2 own target 1 sighting'
call verify bid3['SCORES'][2]>bid3['SCORES'][1],'A3 own target 2 sighting'
call verify bus~send(bid2,0)=='QUEUED_NEXT_TICK','A2 can transmit'
call verify bus~send(bid3,0)=='QUEUED_NEXT_TICK','A3 can transmit'
call verify bus~receive('A2',0)~items==0,'one-step latency for A2'
call verify bus~receive('A3',0)~items==0,'one-step latency for A3'
in2=bus~receive('A2',1);in3=bus~receive('A3',1)
call verify in2~items==1 & in3~items==1,'both-way delivery at same logical time'
call verify p2~absorb(in2[1])=='BID_STORED','A2 records A3 offer'
call verify p3~absorb(in3[1])=='BID_STORED','A3 records A2 offer'
ack2=p2~calculate(0,available);ack3=p3~calculate(0,available)
call verify ack2['FINGERPRINT']==ack3['FINGERPRINT'],'distributed same agreement'
call verify ack2['A2_TARGET']==1 & ack2['A3_TARGET']==2,'mutually assigned different visible targets'
call verify p2~assignment(available)==0 & p3~assignment(available)==0,'no unilateral unacknowledged authority'
call verify bus~send(ack2,1)=='QUEUED_NEXT_TICK','A2 ACK sent'
call verify bus~send(ack3,1)=='QUEUED_NEXT_TICK','A3 ACK sent'
in2=bus~receive('A2',2);in3=bus~receive('A3',2)
call verify p2~absorb(in2[1])=='AGREED','A2 explicit agreement'
call verify p3~absorb(in3[1])=='AGREED','A3 explicit agreement'
call verify p2~assignment(available)==1 & p3~assignment(available)==2,'independent committed target decisions'
call verify p2~current['LEADER']==p3~current['LEADER'],'lead dispute resolved consistently'
/* A claimed target invalidates the agreement; no overruled world truth. */
ignored=available~remove(2)
call verify p3~assignment(available)==0,'claimed target invalidates old assignment'
/* Contested equal-quality bids rotate leader role at epoch boundary. */
all=.directory~new;do i=1 to 5;all[i]=.true;end
same2=p2~localOffer(f2,all,1)
same3=p3~localOffer(f2,all,1)
call verify p2~absorb(same3)=='BID_STORED','new peer epoch A2'
call verify p3~absorb(same2)=='BID_STORED','new peer epoch A3'
a2=p2~calculate(1,all);a3=p3~calculate(1,all)
call verify a2['LEADER']=='A3' & a3['LEADER']=='A3','equal bids elect A3 odd epoch'
call verify a2['FINGERPRINT']==a3['FINGERPRINT'],'tie resolved independently'
/* Check even-epoch alternating resolution. */
c2=p2~localOffer(f2,all,2);c3=p3~localOffer(f2,all,2)
call verify p2~absorb(c3)=='BID_STORED' & p3~absorb(c2)=='BID_STORED','even-epoch bids received'
d2=p2~calculate(2,all);d3=p3~calculate(2,all)
call verify d2['LEADER']=='A2' & d3['LEADER']=='A2','equal bids elect A2 even epoch'
/* Sender cannot invent physical coordinates in this channel. */
leak=.directory~new
 do k over bid2~allIndexes;leak[k]=bid2[k];end
leak['TRUE_X']=123
call verify bus~send(leak,2)=='DENIED_UNKNOWN_FIELD','oracle field rejected'
leak['TO']='A1';leak~remove('TRUE_X')
call verify bus~send(leak,2)=='DENIED_NOT_BUDDY_LINK','A1 cannot receive team traffic'
call verify bus~receive('A1',100)~items==0,'A1 may not eavesdrop'
call verify p2~memory~items<=8 & p3~memory~items<=8,'bounded local memories'
/* Test genuine three-ship simultaneous physical referee and camera. */
world=.Slam450World~new(45045,'LEGACY',.false)
ref=.Slam450TrioReferee~new(world,.false)
call verify ref~tick==0,'three aircraft same time zero'
a=ref~poseOf('A1');b=ref~poseOf('A2');c=ref~poseOf('A3')
call verify abs(world~distance(a,b)-10)<0.00001,'A1 A2 start 10m'
call verify abs(world~distance(a,c)-10)<0.00001,'A1 A3 start 10m'
call verify abs(world~distance(b,c)-10)<0.00001,'A2 A3 start 10m'
call verify ref~minSeparation>9.999,'10m starting minimum'
zero=.array~of(0,0,0,0)
events=ref~advance(zero,zero,zero)
call verify ref~tick==1 & ref~status=='RUNNING','three independent commands advance together'
call verify ref~claims~items==0,'stationary craft do not claim targets'
service=.Slam450TrioCameraService~new(world)
r1=service~request('A1','CAFE_SYDNEY',5,ref~claims,a,.array~of(b,c))
r2=service~request('A3','CAFE_SYDNEY',5,ref~claims,c,.array~of(a,b))
call verify r1['STATUS']=='GRANTED' & r2['STATUS']=='DENIED','one shared fixed-camera grant'
r3=service~request('A3','BLUES_PT',10,ref~claims,c,.array~of(a,b))
call verify r3['STATUS']=='GRANTED','three craft share global five-step throttle'
cam=.Slam450Camera~new(world)
f=cam~renderAt(b,480,121,.false,ref~claims,.array~of(a,c))
call verify f['PIXELS']~items==121,'multiple aircraft silhouettes render'
call verify (.Slam450Vision~new)~observe(f,'R')\==.nil,'other craft visible to own camera'
say 'SLAM450 THREE AIRCRAFT BUDDY PASS' checks 'checks'
exit 0
makeFrame: procedure
  use arg symbol,w,h
  rows=.array~new
  do y=1 to h
    line='.'~copies(w)
    if y==60 then line=overlay(symbol~copies(7),line,230)
    rows~append(line)
  end
  d=.directory~new;d['WIDTH']=w;d['HEIGHT']=h;d['PIXELS']=rows
return d
verify:
  parse arg ok,description
  if \ok then do; say 'FAIL' description;exit 7;end
  checks+=1
return
::requires 'Slam450Buddy.cls'
::requires 'Slam450Trio.cls'
