/* SLAM 450 v0.8 - negotiated peer partnership (A2 <-> A3).
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6.
 * Every offer originates in the sender's own indexed panorama and restricted
 * airflow packet. No exact XY, simulator pose, target XYZ or oracle wind enters
 * this class. The radio is a transport, not a team controller.
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450TargetCost.cls'

::class Slam450BuddyRadio public
::attribute sent get
::attribute rejected get
::method init
  expose pending sent rejected batteryAuthority
  use strict arg authority=.nil
  batteryAuthority=authority
  pending=.array~new;sent=0;rejected=0
::method send
  expose pending sent rejected batteryAuthority
  use strict arg packet,tick
  from=packet['FROM'];to=packet['TO'];kind=packet['KIND']
  good=((from=='A2' & to=='A3') | (from=='A3' & to=='A2'))
  if kind\=='BID' & kind\=='ACK' & kind\=='OBS' & kind\=='ENERGY' then good=.false
  if \datatype(tick,'W') | tick<0 then good=.false
  if \good then do;rejected+=1;return 'DENIED_NOT_BUDDY_LINK';end
  if \packet~hasIndex('EPOCH') | \packet~hasIndex('SEQ') then do
    rejected+=1;return 'DENIED_INVALID_HEADER'
  end
  if \datatype(packet['EPOCH'],'W') | \datatype(packet['SEQ'],'W') then do
    rejected+=1;return 'DENIED_INVALID_HEADER'
  end
  /* Packet whitelist: prevent accidental privileged-field leakage. */
  allowed=.array~of('FROM','TO','KIND','EPOCH','SEQ','SCORES','LEVEL','SAIL',,
                     'CUP','PITOT','SIGHTING','LEADER','A2_TARGET',,
                     'A3_TARGET','FINGERPRINT',,
                     'SAMPLE_TICK','REMAINING','CAPACITY','PERCENT',,
                     'WINDOW_TURNS','DELTA_FLIGHT','DELTA_REMOTE',,
                     'DELTA_RADIO','BURN_RATE','CRUISE_STEPS_ESTIMATE',,
                     'THEORY','CONFIDENCE',,
                     'COSTS','RISKS','CONFIDENCES','THEORIES',,
                     'BID_REMAINING','BID_RESERVE','BID_SAMPLE_TICK')
  do key over packet~allIndexes
    ok=.false
    do a over allowed
      if key==a then ok=.true
    end
    if \ok then do;rejected+=1;return 'DENIED_UNKNOWN_FIELD';end
  end
  /* A buddy's battery reading is SELF-REPORTED. Validate it before charging.
     No oracle fields, raw commands, coordinates or anonymous senders. */
  if kind=='ENERGY' then do
    mandatory=.array~of('SAMPLE_TICK','REMAINING','CAPACITY','PERCENT',,
      'WINDOW_TURNS','DELTA_FLIGHT','DELTA_REMOTE','DELTA_RADIO',,
      'BURN_RATE','CRUISE_STEPS_ESTIMATE','THEORY','CONFIDENCE')
    do key over mandatory
      if \packet~hasIndex(key) then do
        rejected+=1;return 'DENIED_ENERGY_FORMAT'
      end
    end
    integers=.array~of('SAMPLE_TICK','WINDOW_TURNS','CRUISE_STEPS_ESTIMATE')
    numerics=.array~of('REMAINING','CAPACITY','PERCENT','DELTA_FLIGHT',,
      'DELTA_REMOTE','DELTA_RADIO','BURN_RATE')
    do key over integers
      if \datatype(packet[key],'W') then do
        rejected+=1;return 'DENIED_ENERGY_FORMAT'
      end
      if packet[key]<0 then do
        rejected+=1;return 'DENIED_ENERGY_FORMAT'
      end
    end
    do key over numerics
      if \datatype(packet[key],'N') then do
        rejected+=1;return 'DENIED_ENERGY_FORMAT'
      end
      if packet[key]<0 then do
        rejected+=1;return 'DENIED_ENERGY_FORMAT'
      end
    end
    if packet['CAPACITY']<=0 | packet['REMAINING']>packet['CAPACITY'] then do
      rejected+=1;return 'DENIED_ENERGY_INCONSISTENT'
    end
    if packet['PERCENT']>100 | abs(packet['PERCENT']-100*packet['REMAINING']/packet['CAPACITY'])>0.001 then do
      rejected+=1;return 'DENIED_ENERGY_INCONSISTENT'
    end
    if packet['SAMPLE_TICK']>tick | packet['WINDOW_TURNS']>64 then do
      rejected+=1;return 'DENIED_ENERGY_INCONSISTENT'
    end
    if packet['THEORY']\=='INITIAL_SAMPLE' & ,
       packet['THEORY']\=='REMOTE_LOOKUPS_DOMINATE' & ,
       packet['THEORY']\=='CLIMB_ADDS_DRAIN' & ,
       packet['THEORY']\=='HIGH_RECENT_DRAIN' & ,
       packet['THEORY']\=='LOW_BATTERY_RESERVE' & ,
       packet['THEORY']\=='NORMAL_CRUISE_DRAIN' then do
      rejected+=1;return 'DENIED_ENERGY_THEORY'
    end
    if packet['CONFIDENCE']\=='TENTATIVE' & packet['CONFIDENCE']\=='OBSERVED_COST' then do
      rejected+=1;return 'DENIED_ENERGY_CONFIDENCE'
    end
  end
  /* A cost bid must be atomic: no partial price/risk matrices. Each
     value is a fallible estimate from the pilot, not a referee quote. */
  if kind=='BID' & packet~hasIndex('COSTS') then do
    do key over .array~of('RISKS','CONFIDENCES','THEORIES',,
                         'BID_REMAINING','BID_RESERVE','BID_SAMPLE_TICK')
      if \packet~hasIndex(key) then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
    end
    if \datatype(packet['BID_REMAINING'],'N') | ,
       \datatype(packet['BID_RESERVE'],'N') | ,
       \datatype(packet['BID_SAMPLE_TICK'],'W') then do
      rejected+=1;return 'DENIED_COST_FORMAT'
    end
    if packet['BID_REMAINING']<0 | packet['BID_RESERVE']<0 | ,
       packet['BID_RESERVE']>packet['BID_REMAINING'] | ,
       packet['BID_SAMPLE_TICK']>tick | packet['BID_SAMPLE_TICK']<0 then do
      rejected+=1;return 'DENIED_COST_FORMAT'
    end
    do key over .array~of('COSTS','RISKS','CONFIDENCES','THEORIES')
      if \packet[key]~isA(.array) then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
      if packet[key]~items\==5 then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
    end
    do i=1 to 5
      if \datatype(packet['COSTS'][i],'N') then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
      if packet['COSTS'][i]<0 | packet['COSTS'][i]>100000 then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
      risk=packet['RISKS'][i]
      if risk\=='LOW' & risk\=='UNCERTAIN' & risk\=='CAUTION' & ,
         risk\=='HIGH' & risk\=='STRANDED' & risk\=='CLAIMED' then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
      cert=packet['CONFIDENCES'][i]
      if cert\=='LOW' & cert\=='MEDIUM' & cert\=='HIGH' & cert\=='NONE' then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
      theory=packet['THEORIES'][i]
      if theory\=='HIDDEN_SEARCH' & theory\=='IMAGE_RANGE_WEAK' & ,
         theory\=='IMAGE_ANGULAR_RANGE' & theory\=='SHORT_RANGE_SIGHTING' & ,
         theory\=='CLIMB_LIKELY' & theory\=='HIGH_DRAIN_OBSERVED' & ,
         theory\=='TARGET_ALREADY_GONE' then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
    end
  end
  if kind=='BID' & \packet~hasIndex('COSTS') then do
    do key over .array~of('RISKS','CONFIDENCES','THEORIES',,
                         'BID_REMAINING','BID_RESERVE','BID_SAMPLE_TICK')
      if packet~hasIndex(key) then do
        rejected+=1;return 'DENIED_COST_FORMAT'
      end
    end
  end
  /* Snapshot the payload, never share a mutable dictionary by reference. */
  msg=.directory~new
  do key over packet~allIndexes
    value=packet[key]
    if key=='SCORES' then do
      if \value~isA(.array) then do;rejected+=1;return 'DENIED_SCORE_FORMAT';end
      if value~items\==5 then do;rejected+=1;return 'DENIED_SCORE_FORMAT';end
      cp=.array~new
      do score over value
        if \datatype(score,'N') | score<0 | score>100 then do
          rejected+=1;return 'DENIED_SCORE_FORMAT'
        end
        cp~append(score)
      end
      value=cp
    end
    if key=='COSTS' | key=='RISKS' | key=='CONFIDENCES' | key=='THEORIES' then value=value~copy
    msg[key]=value
  end
  /* The radio itself authorises/debits a successful transmission.
     Rejected packets never consume energy and unpowered packets never send. */
  if batteryAuthority\==.nil then do
    if \batteryAuthority~debitRadio(from) then do
      rejected+=1;return 'DENIED_LOW_BATTERY'
    end
  end
  transit=.directory~new
  transit['DELIVER_AT']=tick+1
  transit['MESSAGE']=msg
  pending~append(transit)
  sent+=1
  return 'QUEUED_NEXT_TICK'
::method receive
  expose pending
  use strict arg aircraft,tick
  if aircraft\=='A2' & aircraft\=='A3' then return .array~new
  out=.array~new;remaining=.array~new
  do x over pending
    p=x['MESSAGE']
    if p['TO']==aircraft & x['DELIVER_AT']<=tick then do
      copy=.directory~new
      do key over p~allIndexes
        v=p[key]
        if key=='SCORES' | key=='COSTS' | key=='RISKS' | ,
           key=='CONFIDENCES' | key=='THEORIES' then v=v~copy
        copy[key]=v
      end
      out~append(copy)
    end
    else remaining~append(x)
  end
  pending=remaining
  return out
::method pendingCount
  expose pending
  return pending~items

::class Slam450BuddyPeer public
::attribute id get
::attribute peerID get
::attribute memory get
::attribute current get
::attribute offers get
::attribute agreements get
::attribute received get
::attribute peerEnergy get
::attribute energyHistory get
::attribute costMemory get
::attribute peerCostMemory get
::attribute lastBidEstimate get
::method init
  expose id peerID memory current offers agreements received serial capacity lastEpoch peerEnergy energyHistory lastEnergyTick lastBidEstimate costMemory peerCostMemory
  use strict arg aircraft,slots=48
  if aircraft\=='A2' & aircraft\=='A3' then raise syntax 88.900 array('buddy must be A2 or A3')
  id=aircraft;peerID='A2'
  if id=='A2' then peerID='A3'
  if slots<8 | slots>128 then raise syntax 88.900 array('bad buddy memory slots')
  capacity=slots;memory=.array~new;offers=.directory~new
  agreements=.directory~new;received=.directory~new
  current=.nil;serial=0;lastEpoch=-1
  peerEnergy=.nil;energyHistory=.array~new;lastEnergyTick=-1
  lastBidEstimate=.nil;costMemory=.array~new;peerCostMemory=.array~new
::method remember private
  expose memory capacity
  use strict arg note
  if memory~items>=capacity then do
    remaining=.array~new
    do j=2 to memory~items;remaining~append(memory[j]);end
    memory=remaining
  end
  memory~append(note)
::method localOffer
  expose id peerID serial offers lastEpoch lastBidEstimate costMemory capacity
  use strict arg frame,available,epoch,ownAir=.nil,ownMeter=.nil,ownMemory=.nil,tick=0
  if epoch<0 | \datatype(epoch,'W') then raise syntax 88.900 array('invalid negotiation epoch')
  vision=.Slam450Vision~new
  scores=.array~new;best=0;bestID=0
  do t=1 to 5
    score=0
    if available~hasIndex(t) then do
      obs=vision~observe(frame,t)
      if obs\==.nil then do
        /* Larger and better-centred apparent red squares are preferred.
         * These are evidence strengths, NOT true distances. */
        score=max(1,min(100,40+3*min(12,obs['WIDTH'])-abs(obs['AZ'])/8))
      end
      else score=1
    end
    scores~append(score)
    if score>best then do;best=score;bestID=t;end
  end
  serial+=1
  m=.directory~new
  m['FROM']=id;m['TO']=peerID;m['KIND']='BID'
  m['EPOCH']=epoch;m['SEQ']=serial;m['SCORES']=scores
  /* Own wind sensor observations, not a truth vector. */
  if ownAir\==.nil then do
    m['LEVEL']=ownAir['FLIGHT_LEVEL']
    m['SAIL']=ownAir['SAIL']
    m['CUP']=ownAir['CUP_AIRSPEED_MPS']
    m['PITOT']=ownAir['PITOT_FORWARD_MPS']
  end
  if ownMeter\==.nil then do
    if tick<0 | \datatype(tick,'W') then ,
      raise syntax 88.900 array('invalid bid sample tick')
    estimate=(.Slam450TargetCost~new)~estimate(frame,available,ownMeter,ownMemory,tick)
    do key over .array~of('COSTS','RISKS','CONFIDENCES','THEORIES',,
                          'BID_REMAINING','BID_RESERVE')
      m[key]=estimate[key]
    end
    m['BID_SAMPLE_TICK']=tick
    lastBidEstimate=estimate
    snapshot=.directory~new
    snapshot['EPOCH']=epoch;snapshot['TICK']=tick
    snapshot['COSTS']=estimate['COSTS']~copy
    snapshot['RISKS']=estimate['RISKS']~copy
    snapshot['THEORIES']=estimate['THEORIES']~copy
    snapshot['SOURCE']=estimate['SOURCE']
    if costMemory~items>=capacity then do
      short=.array~new
      do j=2 to costMemory~items;short~append(costMemory[j]);end
      costMemory=short
    end
    costMemory~append(snapshot)
  end
  /* Own negotiation snapshot is isolated from the transmitted packet. */
  held=.directory~new
  do field over m~allIndexes
    v=m[field]
    if v~isA(.array) then v=v~copy
    held[field]=v
  end
  offers[epoch]=held
  do prev over offers~allIndexes
    if prev<epoch-2 then ignored=offers~remove(prev)
  end
  lastEpoch=epoch
  note=.directory~new
  note['EVENT']='LOCAL_BID';note['EPOCH']=epoch
  note['PREFERRED']=bestID;note['STRENGTH']=best
  note['SOURCE']='OWN_CAMERA_AND_RESTRICTED_SENSORS'
  self~remember(note)
  return m
::method absorb
  expose peerID received agreements current peerEnergy energyHistory lastEnergyTick capacity peerCostMemory
  use strict arg msg
  if msg['FROM']\==peerID | msg['TO']\==self~id then return 'REJECT_UNRELATED'
  epoch=msg['EPOCH'];kind=msg['KIND']
  if kind=='BID' then do
    if \msg~hasIndex('SCORES') then return 'REJECT_MISSING_SCORES'
    copy=.directory~new
    do field over msg~allIndexes
      v=msg[field]
      if v~isA(.array) then v=v~copy
      copy[field]=v
    end
    received[epoch]=copy
    do prev over received~allIndexes
      if prev<epoch-2 then ignored=received~remove(prev)
    end
    if copy~hasIndex('COSTS') then do
      bidNote=.directory~new
      bidNote['EPOCH']=epoch;bidNote['SOURCE']='PEER_SELF_REPORTED_UNVERIFIED'
      do field over .array~of('COSTS','RISKS','CONFIDENCES','THEORIES')
        bidNote[field]=copy[field]~copy
      end
      if peerCostMemory~items>=capacity then do
        recent=.array~new
        do j=2 to peerCostMemory~items;recent~append(peerCostMemory[j]);end
        peerCostMemory=recent
      end
      peerCostMemory~append(bidNote)
    end
    note=.directory~new;note['EVENT']='PEER_BID'
    note['EPOCH']=epoch;note['SOURCE']='BUDDY_RADIO_SELF_REPORTED'
    self~remember(note)
    return 'BID_STORED'
  end
  if kind=='ACK' then do
    agreements[epoch]=msg
    if current\==.nil then do
      if current['EPOCH']==epoch & current['FINGERPRINT']==msg['FINGERPRINT'] then do
        current['STATUS']='COMMITTED'
        return 'AGREED'
      end
    end
    return 'ACK_PENDING_LOCAL_COMPUTATION'
  end
  if kind=='ENERGY' then do
    /* Radio already validated payload and sender. Store as an untrusted
       peer statement; never overwrite this craft's OWN battery observations. */
    if msg['SAMPLE_TICK']<=lastEnergyTick then return 'REJECT_STALE_ENERGY'
    lastEnergyTick=msg['SAMPLE_TICK']
    copy=.directory~new
    do key over msg~allIndexes;copy[key]=msg[key];end
    peerEnergy=copy
    note=.directory~new
    note['EVENT']='PEER_ENERGY_REPORT';note['EPOCH']=epoch
    note['SOURCE']='BUDDY_SELF_REPORTED_NOT_ORACLE'
    note['PERCENT']=msg['PERCENT'];note['REMAINING']=msg['REMAINING']
    note['SAMPLE_TICK']=msg['SAMPLE_TICK']
    note['BURN_RATE']=msg['BURN_RATE']
    note['THEORY']=msg['THEORY']
    note['CONFIDENCE']=msg['CONFIDENCE']
    self~remember(note)
    if energyHistory~items>=capacity then do
      fresh=.array~new
      do i=2 to energyHistory~items;fresh~append(energyHistory[i]);end
      energyHistory=fresh
    end
    energyHistory~append(copy)
    return 'ENERGY_STORED'
  end
  if kind=='OBS' then do
    note=.directory~new;note['EVENT']='PEER_WIND_REPORT'
    note['EPOCH']=epoch;note['SOURCE']='SELF_REPORTED_NOT_ORACLE'
    if msg~hasIndex('LEVEL') then note['LEVEL']=msg['LEVEL']
    if msg~hasIndex('SAIL') then note['SAIL']=msg['SAIL']
    if msg~hasIndex('CUP') then note['CUP']=msg['CUP']
    if msg~hasIndex('SIGHTING') then note['SIGHTING']=msg['SIGHTING']
    self~remember(note)
    return 'OBS_STORED'
  end
  return 'REJECT_UNKNOWN_KIND'
::method calculate
  expose id peerID offers received current serial agreements
  use strict arg epoch,available
  if \offers~hasIndex(epoch) | \received~hasIndex(epoch) then return .nil
  own=offers[epoch];rival=received[epoch]
  a=own['SCORES'];b=rival['SCORES']
  if id=='A3' then do; a=rival['SCORES'];b=own['SCORES'];end
  /* Same bid matrix in BOTH peers. Cost bids include the sender's
     estimated energy, uncertainty and reserve risk. Those are self reports,
     NEVER certified distance, wind or actual expected consumption. */
  priced=own~hasIndex('COSTS') & rival~hasIndex('COSTS')
  bidA=own;bidB=rival
  if id=='A3' then do;bidA=rival;bidB=own;end
  best=-10000000;tar2=0;tar3=0
  do t2=1 to 5
    if \available~hasIndex(t2) then iterate
    do t3=1 to 5
      if t2==t3 | \available~hasIndex(t3) then iterate
      score=a[t2]+b[t3]
      if priced then do
        /* Hard depletion hazards are ineligible for joint assignment. */
        if bidA['RISKS'][t2]=='STRANDED' | ,
           bidB['RISKS'][t3]=='STRANDED' then iterate
        score=self~costUtility(bidA,t2)+self~costUtility(bidB,t3)
      end
      if score>best then do;best=score;tar2=t2;tar3=t3;end
    end
  end
  if tar2==0 & priced then do
    /* One craft can make an affordable solo offer while its partner
       holds position to avoid a knowingly unaffordable pursuit. */
    do t=1 to 5
      if \available~hasIndex(t) then iterate
      if bidA['RISKS'][t]\=='STRANDED' then do
        score=self~costUtility(bidA,t)
        if score>best then do;best=score;tar2=t;tar3=0;end
      end
      if bidB['RISKS'][t]\=='STRANDED' then do
        score=self~costUtility(bidB,t)
        if score>best then do;best=score;tar2=0;tar3=t;end
      end
    end
  end
  if tar2==0 & tar3==0 & \priced then do
    do t=1 to 5
      if available~hasIndex(t) then do
        tar2=t;tar3=t;leave
      end
    end
  end
  /* Leadership is disputed every epoch, not a permanent rank.
   * Compare strongest useful bid; on a tie alternate A2/A3 by epoch. */
  highA=0;highB=0
  do t=1 to 5
    if available~hasIndex(t) then do
      if priced then do
        if bidA['RISKS'][t]\=='STRANDED' then highA=max(highA,self~costUtility(bidA,t))
        if bidB['RISKS'][t]\=='STRANDED' then highB=max(highB,self~costUtility(bidB,t))
      end
      else do
        highA=max(highA,a[t]);highB=max(highB,b[t])
      end
    end
  end
  lead='A2'
  if highB>highA then lead='A3'
  if abs(highB-highA)<0.000001 then do
    if epoch//2==1 then lead='A3'
  end
  fingerprint=epoch||':'||lead||':'||tar2||':'||tar3
  if priced then fingerprint=fingerprint||':ENERGY:'||trunc(best*1000)

  d=.directory~new
  d['EPOCH']=epoch;d['LEADER']=lead
  d['A2_TARGET']=tar2;d['A3_TARGET']=tar3
  d['FINGERPRINT']=fingerprint;d['STATUS']='PROPOSED'
  d['ENERGY_AWARE']=priced
  if priced then do
    d['A2_COST']=0;d['A3_COST']=0
    d['A2_RISK']='HOLD';d['A3_RISK']='HOLD'
    d['A2_THEORY']='NO_AFFORDABLE_TARGET'
    d['A3_THEORY']='NO_AFFORDABLE_TARGET'
    if tar2>0 then do
      d['A2_COST']=bidA['COSTS'][tar2]
      d['A2_RISK']=bidA['RISKS'][tar2]
      d['A2_THEORY']=bidA['THEORIES'][tar2]
    end
    if tar3>0 then do
      d['A3_COST']=bidB['COSTS'][tar3]
      d['A3_RISK']=bidB['RISKS'][tar3]
      d['A3_THEORY']=bidB['THEORIES'][tar3]
    end
  end
  d['SOURCE']='MUTUAL_BIDS_WITH_DETERMINISTIC_TIE_RESOLUTION'
  if agreements~hasIndex(epoch) then do
    ack=agreements[epoch]
    if ack['FINGERPRINT']==fingerprint then d['STATUS']='COMMITTED'
  end
  current=d
  note=.directory~new;note['EVENT']='ROLE_AND_TARGET_NEGOTIATED'
  note['EPOCH']=epoch;note['LEADER']=lead
  note['A2_TARGET']=tar2;note['A3_TARGET']=tar3
  note['STATUS']=d['STATUS']
  if priced then do
    note['A2_RISK']=d['A2_RISK'];note['A3_RISK']=d['A3_RISK']
    note['A2_COST']=d['A2_COST'];note['A3_COST']=d['A3_COST']
    note['SOURCE']='MUTUAL_IMAGE_COST_HYPOTHESES'
  end
  self~remember(note)
  serial+=1
  m=.directory~new;m['FROM']=id;m['TO']=peerID;m['KIND']='ACK'
  m['EPOCH']=epoch;m['SEQ']=serial
  m['LEADER']=lead;m['A2_TARGET']=tar2;m['A3_TARGET']=tar3
  m['FINGERPRINT']=fingerprint
  return m
::method costUtility
  /* Scores are visual attractiveness, not ground-truth time-to-target.
     Risk is a discrete penalty; a stranded route is not offered. */
  use strict arg bid,t
  score=bid['SCORES'][t]-bid['COSTS'][t]*0.075
  risk=bid['RISKS'][t]
  if risk=='UNCERTAIN' then score-=12
  if risk=='CAUTION' then score-=25
  if risk=='HIGH' then score-=60
  if risk=='STRANDED' then score-=500
  return score
::method assignment
  expose current id
  use strict arg available
  if current==.nil then return 0
  if current['STATUS']\=='COMMITTED' then return 0
  tgt=current[id||'_TARGET']
  if tgt==0 then return 0
  if \available~hasIndex(tgt) then return 0
  return tgt
::method windReport
  expose id peerID serial
  use strict arg epoch,packet,sighting='UNKNOWN'
  serial+=1
  m=.directory~new;m['FROM']=id;m['TO']=peerID;m['KIND']='OBS'
  m['EPOCH']=epoch;m['SEQ']=serial
  m['LEVEL']=packet['FLIGHT_LEVEL'];m['SAIL']=packet['SAIL']
  m['CUP']=packet['CUP_AIRSPEED_MPS'];m['PITOT']=packet['PITOT_FORWARD_MPS']
  m['SIGHTING']=sighting
  return m

::method energyReport
  /* Send only this pilot's own meter and locally computed trend/theory.
     A recipient cannot read the meter authority or this pilot's ring. */
  expose id peerID serial
  use strict arg epoch,tick,meter,privateEnergyMemory
  if meter['SOURCE']\=='OWN_BATTERY_METER' then ,
    raise syntax 88.900 array('battery report must come from own meter')
  if meter~hasIndex('TRUE_X') | meter~hasIndex('WIND_EAST_MPS') then ,
    raise syntax 88.900 array('no oracle data in energy report')
  trend=privateEnergyMemory~peerSummary(tick,meter)
  serial+=1
  m=.directory~new
  m['FROM']=id;m['TO']=peerID;m['KIND']='ENERGY'
  m['EPOCH']=epoch;m['SEQ']=serial;m['SAMPLE_TICK']=tick
  m['REMAINING']=meter['REMAINING'];m['CAPACITY']=meter['CAPACITY']
  m['PERCENT']=meter['PERCENT']
  m['CRUISE_STEPS_ESTIMATE']=meter['CRUISE_STEPS_ESTIMATE']
  do key over .array~of('WINDOW_TURNS','DELTA_FLIGHT','DELTA_REMOTE',,
                        'DELTA_RADIO','BURN_RATE','THEORY','CONFIDENCE')
    m[key]=trend[key]
  end
  return m
::method energyInterpretation
  /* Advice is provisional; peer reported state is not authenticated truth
     about actual flight progress, and never gives direct commands. */
  expose peerEnergy
  use strict arg ownMeter
  if peerEnergy==.nil then return 'NO_PEER_EVIDENCE'
  if peerEnergy['PERCENT']<20 then return 'BUDDY_REPORTS_LOW_RESERVE'
  if peerEnergy['BURN_RATE']>2 & ownMeter['PERCENT']>peerEnergy['PERCENT']+10 then ,
    return 'BUDDY_REPORTS_HIGH_DRAIN_CONSIDER_SPLIT'
  if peerEnergy['THEORY']=='REMOTE_LOOKUPS_DOMINATE' then ,
    return 'BUDDY_REPORTS_REMOTE_COST_REVIEW'
  return 'NO_ENERGY_ACTION_YET'
