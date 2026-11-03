/* SLAM 450 v0.2 — bounded visual episodic memory and observed-control learning.
 * Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-03.
 * DO NOT consult World~pose/targets/scene from either class. A memory slot is
 * built exclusively from indexed pixels and optional *image-derived* pose.
 * The simulator owns the ground-truth trajectory and admission checks.
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450Wind.cls'

::class Slam450VisualMemory public
::attribute slots get
::attribute pins get
::attribute capacity get
::attribute revisits get
::attribute images get
::attribute lastMatch get
::method init
  expose slots pins capacity revisits images lastMatch
  use strict arg maximum=48
  if maximum<8 | maximum>256 then raise syntax 88.900 array('visual memory capacity outside 8..256')
  slots=.array~new;pins=.directory~new;capacity=maximum;revisits=0;images=0;lastMatch=.nil
::method wrap
  use strict arg angle
  do while angle>180;angle-=360;end
  do while angle< -180;angle+=360;end
  return angle
::method signature
  use strict arg frame
  vision=.Slam450Vision~new
  seen=.directory~new;names=.array~of('A','B','C','D')
  do id over names
    v=vision~observe(frame,id)
    if v\==.nil then seen[id]=.array~of(v['AZ'],v['EL'])
  end
  sig=.directory~new
  sig['PAIRS']=.directory~new
  sig['VISIBLE']=seen~items
  sig['BEARINGS']=seen
  do i=1 to names~items
    do j=i+1 to names~items
      a=names[i];b=names[j]
      if \seen~hasIndex(a) | \seen~hasIndex(b) then iterate
      az=self~wrap(seen[a][1]-seen[b][1])
      el=seen[a][2]-seen[b][2]
      sig['PAIRS'][a||b]=.array~of(az,el)
    end
  end
  sig['PAIR_COUNT']=sig['PAIRS']~items
  return sig
::method similarity
  use strict arg a,b
  aa=a['PAIRS'];bb=b['PAIRS'];score=0;matches=0
  do id over aa~allIndexes
    if \bb~hasIndex(id) then iterate
    diffA=self~wrap(aa[id][1]-bb[id][1])
    diffE=aa[id][2]-bb[id][2]
    score+=abs(diffA)+0.35*abs(diffE)
    matches+=1
  end
  if matches<2 then return 1000000
  return score/matches
::method ingest
  expose slots capacity revisits images lastMatch
  use strict arg frame,step,tag='SCENE',status='IMAGE_ONLY'
  if \datatype(step,'W') | step<0 then raise syntax 88.900 array('invalid image frame step')
  image=self~signature(frame)
  images+=1
  best=.nil;bestScore=1e6
  do slot over slots
    if step-slot['STEP']<15 then iterate
    score=self~similarity(image,slot['SIGNATURE'])
    if score<bestScore then do;bestScore=score;best=slot;end
  end
  r=.directory~new
  r['STATUS']='NOVEL_OR_UNOBSERVABLE'
  r['PAIR_COUNT']=image['PAIR_COUNT']
  r['SCORE']=bestScore
  r['MATCH_STEP']='NONE'
  r['MATCH_TAG']='NONE'
  if best\==.nil & bestScore<=6 then do
    r['STATUS']='VISUAL_SIMILARITY_CANDIDATE'
    r['MATCH_STEP']=best['STEP']
    r['MATCH_TAG']=best['TAG']
    revisits+=1
  end
  r['POSITION_CONFIRMED']=.false /* no photographic match proves coordinates */
  r['MEANING']='VISUAL_ONLY_NOT_GEOLOCALISED'
  lastMatch=r
  /* Reserve slot 1 for the departure view to make loop closure possible.
   * Remaining slots are a FIFO of bounded recent snapshots. */
  if slots~items=0 | step//5=0 then do
    slot=.directory~new
    slot['STEP']=step;slot['TAG']=tag
    slot['SOURCE']='ONBOARD_360_PIXEL_FRAME';slot['EVIDENCE']=status
    slot['SIGNATURE']=image
    slot['TARGET_AZ']='NOT_SEEN'
    if tag~left(1)=='T' & tag~length==2 then do
      number=tag~substr(2)
      if datatype(number,'W') & number>=1 & number<=5 then do
        targetSeen=(.Slam450Vision~new)~observe(frame,number)
        if targetSeen\==.nil then slot['TARGET_AZ']=targetSeen['AZ']
      end
    end
    if slots~items>=capacity then do
      kept=.array~of(slots[1])
      do i=3 to slots~items;kept~append(slots[i]);end
      slots=kept
    end
    slots~append(slot)
  end
  return r
/* Recover an occluded target's expected *image direction* from an older
 * target sighting and common scene landmarks. The sighting may be stale;
 * no world point or true heading is used. */
::method recallDirection
  expose slots
  use strict arg frame,targetNumber,step
  answer=.directory~new
  answer['STATUS']='NO_VISUAL_RECALL';answer['AZ']='UNKNOWN';answer['STEP']='NONE';answer['SCORE']=1000000
  current=self~signature(frame)
  best=1000000;chosen=.nil
  do slot over slots
    if slot['TAG']\=='T'||targetNumber then iterate
    if slot['STEP']>=step | step-slot['STEP']>150 then iterate
    if slot['TARGET_AZ']=='NOT_SEEN' then iterate
    delta=self~similarity(current,slot['SIGNATURE'])
    if delta<best then do;best=delta;chosen=slot;end
  end
  if chosen==.nil | best>14 then return answer
  old=chosen['SIGNATURE']['BEARINGS'];now=current['BEARINGS']
  count=0;sum=0;lo=1e10;hi=-1e10
  do id over now~allIndexes
    if \old~hasIndex(id) then iterate
    moved=self~wrap(now[id][1]-old[id][1])
    count+=1;sum+=moved;lo=min(lo,moved);hi=max(hi,moved)
  end
  if count<2 then return answer
  if count>=3 then shift=(sum-lo-hi)/(count-2)
  else shift=sum/count
  answer['STATUS']='VISUAL_DIRECTION_RECALLED'
  answer['AZ']=self~wrap(chosen['TARGET_AZ']+shift)
  answer['STEP']=chosen['STEP'];answer['SCORE']=best
  return answer
::method pinFrame
  expose pins
  use strict arg frame,step,stage
  if \datatype(stage,'W') | stage<1 | stage>5 then raise syntax 88.900 array('target stage outside five')
  key='T'||stage
  if pins~hasIndex(key) then return 'PRESERVED_FIRST_VISIT'
  p=.directory~new
  p['STEP']=step;p['SIGNATURE']=self~signature(frame)
  p['SOURCE']='ONBOARD_360_PIXEL_FRAME'
  pins[key]=p
  return 'PINNED_VISUAL_WAYPOINT'
::method matchPinned
  expose pins
  use strict arg frame,stage
  key='T'||stage
  if \pins~hasIndex(key) then return 1000000
  return self~similarity(self~signature(frame),pins[key]['SIGNATURE'])
::method savePinned
  expose pins
  use strict arg file
  call SysFileDelete file
  call lineout file,'stage,step,pair,relative_az_deg,relative_el_deg'
  do key over pins~allIndexes~sort
    one=pins[key]
    sig=one['SIGNATURE']['PAIRS']
    do name over sig~allIndexes~sort
      angles=sig[name]
      call lineout file,key||','||one['STEP']||','||name||','||angles[1]||','||angles[2]
    end
  end
  call stream file,'C','CLOSE'
  return pins~items
::method loadPinned
  expose pins
  use strict arg file
  if stream(file,'C','QUERY EXISTS')=='' then return 'NO_ARCHIVE'
  header=linein(file)
  if header\=='stage,step,pair,relative_az_deg,relative_el_deg' then do
    call stream file,'C','CLOSE'
    return 'REJECTED_HEADER'
  end
  known=.array~of('AB','AC','AD','BC','BD','CD')
  seenRows=0
  do while lines(file)>0
    line=linein(file)
    if line~strip=='' then iterate
    parse var line stage ',' atStep ',' pair ',' az ',' el
    if stage~length\=2 | stage~left(1)\=='T' then raise syntax 88.900 array('invalid pinned frame key')
    n=stage~substr(2)
    if \datatype(n,'W') | n<1 | n>5 then raise syntax 88.900 array('pin stage outside 1..5')
    if \datatype(atStep,'W') | \datatype(az,'N') | \datatype(el,'N') then raise syntax 88.900 array('pinned signature nonnumeric')
    valid=.false
    do id over known
      if id==pair then valid=.true
    end
    if \valid then raise syntax 88.900 array('pinned pair not in known anchors')
    if \pins~hasIndex(stage) then do
      d=.directory~new
      d['STEP']=atStep
      sig=.directory~new
      sig['PAIRS']=.directory~new
      d['SIGNATURE']=sig
      d['SOURCE']='RECORDED_IMAGE_DESCRIPTOR_RELOADED'
      pins[stage]=d
    end
    d=pins[stage]
    if d['STEP']\=atStep then raise syntax 88.900 array('inconsistent pin step')
    if d['SIGNATURE']['PAIRS']~hasIndex(pair) then raise syntax 88.900 array('duplicate pinned pair')
    d['SIGNATURE']['PAIRS'][pair]=.array~of(az+0,el+0)
    seenRows+=1
    if seenRows>30 then raise syntax 88.900 array('pinned file too large')
  end
  call stream file,'C','CLOSE'
  do key over pins~allIndexes
    pins[key]['SIGNATURE']['PAIR_COUNT']=pins[key]['SIGNATURE']['PAIRS']~items
  end
  return pins~items
::method firstViewSimilar
  expose slots
  use strict arg frame
  if slots~items=0 then return 1e6
  return self~similarity(self~signature(frame),slots[1]['SIGNATURE'])

::class Slam450LearningPilot public subclass Slam450Pilot
::attribute memory get
::attribute learnedYawResponse get
::attribute responseUpdates get
::attribute rememberedViews get
::attribute memoryHints get
::attribute scanSteps get
::attribute windMemory get
::attribute lastVisualEvidence get
::method ingestWind
  expose windMemory lastCmd
  use strict arg step,restrictedPacket,visualEvidence='UNKNOWN'
  ownForward=0
  if lastCmd\==.nil then ownForward=lastCmd[2]
  return windMemory~record(step,restrictedPacket,ownForward,visualEvidence)
::method init
  expose memory learnedYawResponse responseUpdates rememberedViews memoryHints scanSteps lastTarget lastAz lastCmd lastAnchors frameStep policyPath windMemory lastVisualEvidence
  use strict arg store=.nil,file='',windArchive=''
  self~init:super(0.72)
  memory=store
  if memory==.nil then memory=.Slam450VisualMemory~new
  windMemory=.Slam450WindMemory~new(36)
  if windArchive\=='' then loadedWind=windMemory~loadObservations(windArchive)
  lastVisualEvidence='INSUFFICIENT_IMAGE_HISTORY'
  learnedYawResponse=0.75;responseUpdates=0;rememberedViews=0;memoryHints=0;scanSteps=0
  lastTarget=0;lastAz=.nil;lastCmd=.nil;lastAnchors=.directory~new;frameStep=0;policyPath=file
  if file\=='' then self~loadPolicy(file)
::method loadPolicy
  expose learnedYawResponse responseUpdates
  use strict arg file
  if stream(file,'C','QUERY EXISTS')=='' then return 'NEW'
  header=linein(file)
  if header\=='SLAM450_STEERING_V1' then do
    call stream file,'C','CLOSE'
    return 'REJECTED_HEADER'
  end
  parse value linein(file) with factor counter .
  call stream file,'C','CLOSE'
  if \datatype(factor,'N') | \datatype(counter,'W') then return 'REJECTED_DATA'
  if factor<0.3 | factor>1.7 | counter<0 | counter>100000 then return 'REJECTED_RANGE'
  learnedYawResponse=factor;responseUpdates=counter
  return 'LOADED'
::method savePolicy
  expose learnedYawResponse responseUpdates
  use strict arg file
  call SysFileDelete file
  call lineout file,'SLAM450_STEERING_V1'
  call lineout file,learnedYawResponse responseUpdates
  call stream file,'C','CLOSE'
  return 'SAVED'
::method wrap
  use strict arg angle
  do while angle>180;angle-=360;end
  do while angle< -180;angle+=360;end
  return angle
::method control
  expose memory learnedYawResponse responseUpdates rememberedViews memoryHints scanSteps lastTarget lastAz lastCmd lastAnchors frameStep lastVisualEvidence
  use strict arg frame,targetNumber
  observed=(.Slam450Vision~new)~observe(frame,targetNumber)
  note=memory~ingest(frame,frameStep,'T'||targetNumber)
  if note['STATUS']=='VISUAL_SIMILARITY_CANDIDATE' then rememberedViews+=1
  /* Rotational optical flow from stationary scene landmarks measures the
   * response to the previous yaw control. Use a trimmed mean across visible
   * anchors; ordinary translation parallax is an unknown/noise term. */
  currentAnchors=.directory~new
  reader=.Slam450Vision~new
  do id over .array~of('A','B','C','D')
    p=reader~observe(frame,id)
    if p\==.nil then currentAnchors[id]=p['AZ']
  end
  lastVisualEvidence='INSUFFICIENT_IMAGE_HISTORY'
  if lastCmd\==.nil then do
    if abs(lastCmd[1])>=3 then do
      count=0;sum=0;low=1e10;high=-1e10
      do id over currentAnchors~allIndexes
        if \lastAnchors~hasIndex(id) then iterate
        motion=self~wrap(lastAnchors[id]-currentAnchors[id])
        count+=1;sum+=motion
        low=min(low,motion);high=max(high,motion)
      end
      if count>=3 then sum=(sum-low-high)/(count-2)
      else if count>=2 then sum=sum/count
      if count>=2 then do
        /* Excess residual between observed panorama motion and expected yaw
           can indicate translation/parallax, not automatically wind drift. */
        if abs(sum-lastCmd[1]*learnedYawResponse)>1.5 then ,
          lastVisualEvidence='VISUAL_MOTION_RESIDUAL_CANDIDATE'
        else lastVisualEvidence='VISUAL_MOTION_CONSISTENT_WITH_YAW'
        ratio=sum/lastCmd[1]
        if ratio>=0.2 & ratio<=1.8 then do
          learnedYawResponse=0.90*learnedYawResponse+0.10*ratio
          responseUpdates+=1
        end
      end
    end
  end
  command=self~control:super(frame,targetNumber)
  if observed==.nil then do
    scanSteps+=1
    hint=memory~recallDirection(frame,targetNumber,frameStep)
    if hint['STATUS']=='VISUAL_DIRECTION_RECALLED' then do
      memoryHints+=1
      command[1]=max(-25,min(25,hint['AZ']*0.55))
      command[2]=0.5;command[3]=0
      if scanSteps>=10 then command[4]=1.5
    end
    else do
      /* A scan is necessary but NOT a route. Once a full 360 sweep
       * has failed to reveal the active target, use camera-conditioned,
       * bounded boustrophedon exploration. No coordinates, known target
       * locations or simulator collision oracle enter the controller.
       * Each long stroke creates baseline parallax; the sideways stroke
       * permits seeing round an occluding structure. The learned yaw
       * response still comes solely from optical landmark motion. */
      if scanSteps>30 then do
        probe=scanSteps-31
        command[1]=0;command[2]=2.8;command[3]=0;command[4]=0
        select
          when probe<60 then nop  /* first baseline: 168m */
          when probe<64 then do;command[1]=-22.5;command[2]=0;end
          when probe<104 then nop /* 112m cross track */
          when probe<108 then do;command[1]=22.5;command[2]=0;end
          when probe<188 then nop /* extend original bearing */
          when probe<192 then do;command[1]=22.5;command[2]=0;end
          when probe<272 then nop
          when probe<276 then do;command[1]=-22.5;command[2]=0;end
          otherwise do
            /* Expand novelty search by successive cross-track strokes.
             * The present geometric model does not guarantee all possible
             * open sectors, so the simulator remains a separate kill gate. */
            phase=(probe-276)//168
            if phase<4 then do;command[1]=-22.5;command[2]=0;end
            else if phase<84 then nop
            else if phase<88 then do;command[1]=22.5;command[2]=0;end
            else nop
          end
        end
      end
    end
  end
  else do
    scanSteps=0
    if abs(command[1])>2 then command[1]=max(-25,min(25,command[1]/learnedYawResponse))
  end
  lastTarget=targetNumber
  lastAz=.nil
  if observed\==.nil then lastAz=observed['AZ']
  lastCmd=command
  lastAnchors=currentAnchors
  frameStep+=1
  return command
