/* SLAM450 v0.86: independent cost/risk hypotheses, dual-peer decisions. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
radio=.Slam450BuddyRadio~new
p2=.Slam450BuddyPeer~new('A2',8)
p3=.Slam450BuddyPeer~new('A3',8)
all=.directory~new;do i=1 to 5;all[i]=.true;end
f2=makeFrame('1')
f3=makeFrame('2')
b2=.Slam450Battery~new(900)
b3=.Slam450Battery~new(900)
mem2=.Slam450BatteryMemory~new(8)
mem3=.Slam450BatteryMemory~new(8)
x2=p2~localOffer(f2,all,0,.nil,b2~report,mem2,0)
x3=p3~localOffer(f3,all,0,.nil,b3~report,mem3,0)
call verify x2~hasIndex('COSTS') & x3~hasIndex('COSTS'),'both peers offer cost hypotheses'
call verify x2['COSTS']~items==5 & x2['RISKS']~items==5,'all five targets estimated'
call verify x2['BID_REMAINING']==900 & x2['BID_RESERVE']>0,'bid includes self-reported battery and reserve'
call verify x2['COSTS'][1]<x2['COSTS'][2],'visible target estimated cheaper than unseen'
call verify x2['CONFIDENCES'][1]=='LOW','three-pixel target has low range certainty'
call verify x2['THEORIES'][1]=='IMAGE_RANGE_WEAK','range alias explicitly declared'
call verify x2['THEORIES'][2]=='HIDDEN_SEARCH','unseen target search overhead is a theory'
call verify x2['RISKS'][1]\=='STRANDED','full charge supports a tentative target bid'
call verify radio~send(x2,0)=='QUEUED_NEXT_TICK','energy-priced A2 bid accepted'
call verify radio~send(x3,0)=='QUEUED_NEXT_TICK','energy-priced A3 bid accepted'
old=x2['COSTS'][1]
x2['COSTS'][1]=98765
msgs2=radio~receive('A2',1);msgs3=radio~receive('A3',1)
call verify msgs3[1]['COSTS'][1]==old,'sender cannot mutate queued cost packet'
call verify p2~absorb(msgs2[1])=='BID_STORED','A2 received own peer cost bid'
call verify p3~absorb(msgs3[1])=='BID_STORED','A3 received peer cost bid'
call verify p2~peerCostMemory~items==1 & p3~peerCostMemory~items==1,'each buddy has peer-cost observation slots'
call verify p2~peerCostMemory[1]['SOURCE']=='PEER_SELF_REPORTED_UNVERIFIED','peer prices not trusted as truth'
call verify p2~peerCostMemory\==p3~peerCostMemory,'peer cost memories remain private'
a2=p2~calculate(0,all);a3=p3~calculate(0,all)
call verify a2['FINGERPRINT']==a3['FINGERPRINT'],'costs produce independent identical proposals'
call verify a2['A2_TARGET']\==a2['A3_TARGET'],'allocation exclusive'
call verify p2~current['ENERGY_AWARE'] & p3~current['ENERGY_AWARE'],'explicit energy-aware decision'
call verify p2~current['A2_COST']>0 & p3~current['A3_COST']>0,'decisions preserve cost of selected target'
call verify radio~send(a2,1)=='QUEUED_NEXT_TICK','A2 confirms priced proposal'
call verify radio~send(a3,1)=='QUEUED_NEXT_TICK','A3 confirms priced proposal'
call verify p2~absorb(radio~receive('A2',2)[1])=='AGREED','A2 commits priced assignment'
call verify p3~absorb(radio~receive('A3',2)[1])=='AGREED','A3 commits priced assignment'
call verify p2~assignment(all)>0 & p3~assignment(all)>0,'committed assignments actionable'
call verify p2~costMemory~items==1 & p3~costMemory~items==1,'private local cost memories recorded'
call verify p2~costMemory\==p3~costMemory,'no merged team cost history'
/* When one aircraft is critically low, it withdraws and its partner bids. */
low=.Slam450Battery~new(90)
y2=p2~localOffer(f2,all,1,.nil,low~report,mem2,16)
y3=p3~localOffer(f3,all,1,.nil,b3~report,mem3,16)
call verify y2['RISKS'][1]=='STRANDED' & y2['RISKS'][2]=='STRANDED',,'insufficient charge triggers depleted reserve risk'
call verify y3['RISKS'][2]\=='STRANDED','adequately charged peer remains viable'
call verify p2~absorb(y3)=='BID_STORED' & p3~absorb(y2)=='BID_STORED','peers exchange risk estimates'
z2=p2~calculate(1,all);z3=p3~calculate(1,all)
call verify z2['FINGERPRINT']==z3['FINGERPRINT'],'withdrawal negotiated consistently'
call verify z2['A2_TARGET']==0 & z2['A3_TARGET']>0,'low-charge craft can decline dangerous target'
call verify p2~current['A2_RISK']=='HOLD','refusal labelled in decision memory'
call verify p2~memory~items<=8 & p3~memory~items<=8,'bounded message rings'
call verify p2~peerCostMemory~items<=8 & p3~costMemory~items<=8,'bounded peer and local cost rings'
/* Malformed and privileged cost bids never get delivered or charged. */
forged=y3~copy;forged['TRUE_TARGET_X']=23
call verify radio~send(forged,16)=='DENIED_UNKNOWN_FIELD','true target coordinate forbidden'
forged=y3~copy;forged['COSTS']=.array~of(1,2,3,4)
call verify radio~send(forged,16)=='DENIED_COST_FORMAT','must price all five targets'
forged=y3~copy;forged['RISKS']=.array~of('LOW','LOW','LOW','LOW','CERTAIN')
call verify radio~send(forged,16)=='DENIED_COST_FORMAT','unsupported risk claims rejected'
forged=y3~copy;forged['BID_REMAINING']=-1
call verify radio~send(forged,16)=='DENIED_COST_FORMAT','negative self-report rejected'
forged=y3~copy;ignored=forged~remove('THEORIES')
call verify radio~send(forged,16)=='DENIED_COST_FORMAT','incomplete hypothesis rejected'
forged=y3~copy;forged['TO']='A1'
call verify radio~send(forged,16)=='DENIED_NOT_BUDDY_LINK','A1 cannot eavesdrop'
say 'SLAM450 TARGET COST NEGOTIATION PASS' checks 'checks'
exit 0
makeFrame: procedure
  use arg symbol
  rows=.array~new
  do y=1 to 121
    line='.'~copies(480)
    if y==60 then line=overlay(symbol~copies(3),line,240)
    rows~append(line)
  end
  d=.directory~new;d['WIDTH']=480;d['HEIGHT']=121;d['PIXELS']=rows
return d
verify:
  parse arg ok,description
  if \ok then do;say 'FAIL' description;exit 7;end
  checks+=1
return
::requires 'Slam450Buddy.cls'
::requires 'Slam450Trio.cls'
