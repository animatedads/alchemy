/* SLAM450 v0.85: native peer battery telemetry, ideas and privacy. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
checks=0
world=.Slam450World~new(45046,'LEGACY',.false)
auth=.Slam450TrioReferee~new(world,.false,.true)
radio=.Slam450BuddyRadio~new(auth)
p2=.Slam450BuddyPeer~new('A2',8)
p3=.Slam450BuddyPeer~new('A3',8)
m2=.Slam450BatteryMemory~new(8)
m3=.Slam450BatteryMemory~new(8)
call verify p2~peerEnergy==.nil & p3~peerEnergy==.nil,'private peer energy initially unknown'
call verify p2~energyHistory~items==0 & p3~energyHistory~items==0,'independent empty peer energy histories'
report2=auth~batteryReport('A2')
report3=auth~batteryReport('A3')
e2=p2~energyReport(0,0,report2,m2)
e3=p3~energyReport(0,0,report3,m3)
call verify e2['FROM']=='A2' & e2['TO']=='A3' & e3['FROM']=='A3' & e3['TO']=='A2','two way only'
call verify e2['REMAINING']==900 & e3['PERCENT']==100,'each craft publishes own current meter'
call verify e2['THEORY']=='INITIAL_SAMPLE' & e2['CONFIDENCE']=='TENTATIVE','first observation is provisional'
call verify e2['WINDOW_TURNS']==0 & e2['BURN_RATE']==0,'no history cannot imply consumption rate'
call verify \e2~hasIndex('TRUE_X') & \e2~hasIndex('WIND_EAST_MPS'),'no oracle state included'
call verify radio~send(e2,0)=='QUEUED_NEXT_TICK','A2 energy packet accepted'
call verify radio~send(e3,0)=='QUEUED_NEXT_TICK','A3 energy packet accepted'
call verify radio~receive('A1',1)~items==0,'solo cannot receive peer battery'
call verify radio~receive('A3',0)~items==0,'energy latency at least one tick'
in3=radio~receive('A3',1)
in2=radio~receive('A2',1)
call verify in3~items==1 & in2~items==1,'both independent peer energy messages arrive'
call verify p3~absorb(in3[1])=='ENERGY_STORED','A3 stores reported A2 battery'
call verify p2~absorb(in2[1])=='ENERGY_STORED','A2 stores reported A3 battery'
call verify p2~peerEnergy['FROM']=='A3' & p3~peerEnergy['FROM']=='A2','received battery belongs to other craft'
call verify p2~peerEnergy['REMAINING']==900 & p3~peerEnergy['REMAINING']==900,'battery is explicitly reported'
call verify p2~energyHistory\==p3~energyHistory,'no shared energy memory'
call verify p2~memory[1]['SOURCE']=='BUDDY_SELF_REPORTED_NOT_ORACLE','peer theories provenance is untrusted'
call verify p2~absorb(in2[1])=='REJECT_STALE_ENERGY','replay snapshot rejected'
call verify p2~energyHistory~items==1,'stale snapshot does not occupy a slot'
call verify abs(auth~batteryReport('A2')['REMAINING']-899.97)<0.000001,'A2 pays one 0.03 radio charge'
call verify abs(auth~batteryReport('A3')['REMAINING']-899.97)<0.000001,'A3 pays one 0.03 radio charge'
call verify auth~batteryReport('A1')['REMAINING']==900,'A1 battery unchanged by peer traffic'
call verify p2~energyInterpretation(auth~batteryReport('A2'))=='NO_ENERGY_ACTION_YET','initial peer report prompts no speculative action'
/* Independently build an observation window dominated by paid lookups.
   Energy history sees own meter, not rival's true state. */
forged=.Slam450Battery~new
own=.Slam450BatteryMemory~new(8)
cruise=.array~of(0,3,0,0)
do t=1 to 10
  ignored=forged~debit('FLIGHT',1)
  if t>=6 then ignored=forged~debit('LOOKUP',3)
  ignored=own~observe(t,forged~report,cruise,t>=6,0)
end
trend=own~peerSummary(10,forged~report)
call verify trend['WINDOW_TURNS']>0,'trend uses bounded recent observations'
call verify trend['DELTA_FLIGHT']>0 & trend['DELTA_REMOTE']>0,'flight and remote energy categories separately measured'
call verify trend['DELTA_REMOTE']>trend['DELTA_FLIGHT'],'remote view measured as dominant cost'
call verify trend['THEORY']=='REMOTE_LOOKUPS_DOMINATE','theory reflects recent meter evidence'
call verify trend['CONFIDENCE']=='OBSERVED_COST','theory labelled observed cost pattern, not oracle'
packet=p2~energyReport(1,10,forged~report,own)
call verify packet['THEORY']=='REMOTE_LOOKUPS_DOMINATE','own battery hypothesis goes on radio'
call verify packet['PERCENT']<100 & packet['BURN_RATE']>1,'rate and charge are sent'
call verify radio~send(packet,10)=='QUEUED_NEXT_TICK','updated A2 energy report accepted'
received=radio~receive('A3',11)
call verify received~items==1,'new report delivered at next tick'
call verify p3~absorb(received[1])=='ENERGY_STORED','A3 stores updated A2 theory'
call verify p3~peerEnergy['THEORY']=='REMOTE_LOOKUPS_DOMINATE','A3 has peer theory'
call verify p3~energyInterpretation(auth~batteryReport('A3'))=='BUDDY_REPORTS_REMOTE_COST_REVIEW','peer theory interpreted cautiously'
call verify p2~peerEnergy['THEORY']=='INITIAL_SAMPLE','A2 own peer memory remains independent'
/* Radio must validate all types and conserve power on rejection. */
invalid=packet~copy
invalid['TRUE_X']=42
before=auth~batteryReport('A2')['REMAINING']
call verify radio~send(invalid,10)=='DENIED_UNKNOWN_FIELD','privileged position blocked'
call verify auth~batteryReport('A2')['REMAINING']==before,'invalid report never debited'
invalid=packet~copy;invalid['TO']='A1'
call verify radio~send(invalid,10)=='DENIED_NOT_BUDDY_LINK','no solo battery leak'
invalid=packet~copy;invalid['PERCENT']=90
call verify radio~send(invalid,10)=='DENIED_ENERGY_INCONSISTENT','contradictory battery charge and percent blocked'
invalid=packet~copy;invalid['REMAINING']=-1
call verify radio~send(invalid,10)=='DENIED_ENERGY_FORMAT','negative reported charge blocked'
invalid=packet~copy;invalid['BURN_RATE']='fast'
call verify radio~send(invalid,10)=='DENIED_ENERGY_FORMAT','nonnumeric reported consumption blocked'
invalid=packet~copy;invalid['THEORY']='MUST_GIVE_COORDINATES'
call verify radio~send(invalid,10)=='DENIED_ENERGY_THEORY','only bounded energy theories allowed'
invalid=packet~copy;invalid['CONFIDENCE']='ABSOLUTE_CERTAINTY'
call verify radio~send(invalid,10)=='DENIED_ENERGY_CONFIDENCE','absolute certainty not allowed'
invalid=packet~copy;invalid['SAMPLE_TICK']=12
call verify radio~send(invalid,10)=='DENIED_ENERGY_INCONSISTENT','cannot cite future sensor sample'
invalid=packet~copy;ignored=invalid~remove('BURN_RATE')
call verify radio~send(invalid,10)=='DENIED_ENERGY_FORMAT','incomplete energy report blocked'
call verify auth~batteryReport('A2')['REMAINING']==before,'all malformed reports cost zero'
/* No leaking mutable original snapshot through radio transport. */
packet=p3~energyReport(1,11,forged~report,own)
call verify radio~send(packet,11)=='QUEUED_NEXT_TICK','snapshot copied at send'
packet['THEORY']='LOW_BATTERY_RESERVE'
out=radio~receive('A2',12)
call verify out[1]['THEORY']=='REMOTE_LOOKUPS_DOMINATE','in-flight payload immutable'
call verify p2~absorb(out[1])=='ENERGY_STORED','A2 receives immutable A3 report'
/* Ring bounded after many fresh self-reports. */
do t=12 to 31
  m=p2~energyReport(2,t,forged~report,own)
  call verify radio~send(m,t)=='QUEUED_NEXT_TICK','repeated safe report '||t
  out=radio~receive('A3',t+1)
  call verify p3~absorb(out[1])=='ENERGY_STORED','repeated peer storage '||t
end
call verify p3~energyHistory~items==8,'peer energy history stays bounded'
call verify p3~peerEnergy['SAMPLE_TICK']==31,'latest self-report retained'
call verify p3~energyHistory[1]['SAMPLE_TICK']==24,'oldest snapshots evicted'
call verify p3~memory~items<=8,'shared buddy observation ring also bounded'
say 'SLAM450 BUDDY ENERGY PASS' checks 'checks'
exit 0
verify:
  parse arg ok,desc
  if \ok then do; say 'FAIL' desc;exit 7;end
  checks+=1
return
::requires 'Slam450Battery.cls'
::requires 'Slam450Buddy.cls'
::requires 'Slam450Trio.cls'
