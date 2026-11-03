/* SLAM 450 v0.7 — IMAGE-ONLY rival-aircraft wind/altitude hypotheses.
 * The architect's rule: only one's OWN pitot/cup/sail packet, OWN prior
 * command, one onboard frame, or an individually granted fixed panorama.
 * No rival XYZ, wind oracle, exact airspeed, physics model or map position.
 * Numeric optical estimates are apparent/relative; claims are hypothesis
 * slots, NOT measured rival ground velocity or wind direction.
 */
::requires 'Slam450Flight.cls'
::requires 'Slam450AircraftType.cls'

::class Slam450RivalAir public
::attribute id get
::attribute slots get
::attribute capacity get
::attribute lastEstimate get
::attribute trials get
::attribute fixedViews get
::attribute levelIdeas get
::method init
  expose id slots capacity lastEstimate trials lastSeen lastStep fixedViews lastLateral stalls jitterCounter moving levelIdeas
  use strict arg craft,maximum=48
  /* v0.90: any squad craft id A<n>. */
  if craft~left(1)\=='A' | \datatype(craft~substr(2),'W') then raise syntax 88.900 array('unknown aircraft')
  if maximum<8 | maximum>128 then raise syntax 88.900 array('rival memory capacity')
  id=craft;capacity=maximum;slots=.array~new;lastEstimate=.nil
  lastSeen=.nil;lastStep=-1;lastLateral=0;stalls=0;jitterCounter=0;moving=0
  trials=0;fixedViews=.directory~new;levelIdeas=.directory~new
::method wrap
  use strict arg angle
  do while angle>180;angle-=360;end
  do while angle< -180;angle+=360;end
  return angle
::method record private
  expose slots capacity lastEstimate
  use strict arg note
  if slots~items>=capacity then do
    kept=.array~new
    do i=2 to slots~items;kept~append(slots[i]);end
    slots=kept
  end
  slots~append(note);lastEstimate=note
  return note
::method restricted private
  use strict arg packet
  /* A whitelist rejects even accidental new referee fields. */
  allowed=.array~of('SOURCE','FLIGHT_LEVEL','CUP_AIRSPEED_MPS',,
    'PITOT_FORWARD_MPS','PITOT_STATUS','SAIL','CUP_STATUS','SAIL_STATUS')
  do key over packet~allIndexes
    good=.false
    do name over allowed
      if key==name then good=.true
    end
    if \good then raise syntax 88.900 array('unapproved sensor field in rival learner: '||key)
  end
  return .true
::method anchors private
  use strict arg frame
  a=.directory~new
  reader=.Slam450Vision~new
  do id over .array~of('A','B','C','D')
    r=reader~observe(frame,id)
    if r\==.nil then a[id]=r['AZ']
  end
  return a
::method rangeCandidate private
  use strict arg obs,w,rivalType='UNKNOWN'
  /* v0.88: half-width depends on the OBSERVED type: 2.5 m quad billboard,
   * 5.0 m wing half-span; UNKNOWN keeps the legacy quad assumption.
   * The renderer uses a 2.5m HALF-width billboard. Angular width gives
   * only a heavily quantised approximate ground range. 3px is unresolved.
   * An image-edge crop is also unresolved (not a known physical width). */
  if obs==.nil then return 'UNKNOWN'
  if obs['WIDTH']<=3 then return 'UNKNOWN'
  if obs['X']<=obs['WIDTH'] | obs['X']>=w-obs['WIDTH'] then return 'UNKNOWN'
  half=(obs['WIDTH']-1)/2
  alpha=half*360/w
  sine=RxCalcSin(alpha)
  if sine<0.001 then return 'UNKNOWN'
  return .Slam450AircraftType~halfWidth(rivalType)*RxCalcCos(alpha)/sine
::method observe
  expose lastSeen lastStep lastLateral stalls jitterCounter moving levelIdeas
  use strict arg frame,step,ownPacket=.nil,ownCommand=.nil,taskTarget=0,ownImagePose=.nil,rivalType='UNKNOWN'
  if \datatype(step,'W') | step<0 | step<=lastStep then ,
    raise syntax 88.900 array('rival image steps must strictly increase')
  ownLevel='UNKNOWN';ownSail='UNKNOWN';ownPitot='UNKNOWN';ownCup='UNKNOWN'
  if ownPacket\==.nil then do
    checked=self~restricted(ownPacket)
    ownLevel=ownPacket['FLIGHT_LEVEL']
    if ownLevel\=='L1' & ownLevel\=='L2' & ownLevel\=='L3' then ,
      raise syntax 88.900 array('unknown own flight-level sensor')
    ownSail=ownPacket['SAIL'];ownPitot=ownPacket['PITOT_FORWARD_MPS']
    ownCup=ownPacket['CUP_AIRSPEED_MPS']
  end
  reader=.Slam450Vision~new
  r=reader~observe(frame,'R')
  note=.directory~new
  note['STEP']=step;note['SOURCE']='ONBOARD_360_IMAGE'
  note['OWN_LEVEL']=ownLevel;note['OWN_SAIL']=ownSail
  note['OWN_PITOT_MPS']=ownPitot;note['OWN_CUP_MPS']=ownCup
  note['RIVAL_STATUS']='NOT_VISIBLE';note['HEIGHT_ORDER']='UNKNOWN'
  note['RIVAL_LEVEL_CANDIDATE']='UNRESOLVED'
  note['RIVAL_ALTITUDE_LOW_M']='UNKNOWN';note['RIVAL_ALTITUDE_HIGH_M']='UNKNOWN'
  note['RANGE_APPROX_M']='UNKNOWN';note['RELATIVE_SPEED_APPROX_MPS']='UNKNOWN'
  note['RELATIVE_SPEED_STATUS']='INSUFFICIENT_IMAGE_HISTORY'
  note['EGO_YAW_REMOVED']='NO'
  note['APPARENT_CROSS_TRACK_DEG']='UNKNOWN'
  note['WIND_IDEA']='NO_RIVAL_EVIDENCE';note['CONFIDENCE']='UNTESTED'
  note['OWN_ALTITUDE_EXACT_M']='UNKNOWN'
  note['OWN_ALTITUDE_IMAGE_EST_M']='UNKNOWN'
  note['RIVAL_GROUND_SPEED_MPS']='UNKNOWN'
  note['RIVAL_WIND_VECTOR']='UNKNOWN'
  if r==.nil then do
    lastSeen=.nil;stalls=0;jitterCounter=0;moving=0
    lastStep=step
    return self~record(note)
  end
  note['RIVAL_STATUS']='VISUAL_SILHOUETTE'
  note['RIVAL_AZ_DEG']=r['AZ'];note['RIVAL_EL_DEG']=r['EL']
  note['RIVAL_PIXELS']=r['COUNT'];note['RIVAL_WIDTH_PIXELS']=r['WIDTH']
  note['CONFIDENCE']='LOW'
  if r['EL']>5 then note['HEIGHT_ORDER']='ABOVE'
  else if r['EL']< -5 then note['HEIGHT_ORDER']='BELOW'
  else note['HEIGHT_ORDER']='NEAR_OR_UNKNOWN'
  note['RIVAL_TYPE']=rivalType
  dist=self~rangeCandidate(r,frame['WIDTH'],rivalType)
  note['RANGE_APPROX_M']=dist
  if dist\=='UNKNOWN' & ownLevel\=='UNKNOWN' then do
    /* Own band is known only coarsely from its wind instrumentation.
     * Therefore give an INTERVAL for the rival, not a made-up GPS z.
     * Range is quantised; allow substantial extra uncertainty. */
    select
      when ownLevel=='L1' then do;low=8;high=55;end
      when ownLevel=='L2' then do;low=55;high=105;end
      otherwise do;low=105;high=160;end
    end
    /* Optional independent image-only own-pose calculation narrows the
     * initial broad altitude band. The caller may supply only a pose
     * produced by the landmark inverse calculation, never referee XYZ. */
    if ownImagePose\==.nil then do
      if \ownImagePose~hasIndex('ESTIMATE_SOURCE') then raise syntax 88.900 array('unproven own height source')
      if ownImagePose['ESTIMATE_SOURCE']\=='ONBOARD_LANDMARK_INVERSE' | ,
         ownImagePose['STATUS']\=='IMAGE_BEARING_ESTIMATE' then ,
         raise syntax 88.900 array('rival learner refuses non-image own altitude')
      ownZ=ownImagePose['Z'];errorZ=ownImagePose['Z_UNCERTAINTY_M']
      if \datatype(ownZ,'N') | \datatype(errorZ,'N') | errorZ<5 then ,
        raise syntax 88.900 array('invalid photographic altitude uncertainty')
      if ownZ>=low-errorZ & ownZ<=high+errorZ then do
        low=max(low,ownZ-errorZ);high=min(high,ownZ+errorZ)
        note['OWN_ALTITUDE_IMAGE_EST_M']=ownZ
      end
    end
    cosine=RxCalcCos(r['EL'])
    if abs(cosine)>0.05 then do
      delta=dist*RxCalcSin(r['EL'])/cosine
      error=max(4,dist*0.08)
      low=low+delta-error;high=high+delta+error
      note['RIVAL_ALTITUDE_LOW_M']=low
      note['RIVAL_ALTITUDE_HIGH_M']=high
      if low>=8 & high<55 then note['RIVAL_LEVEL_CANDIDATE']='L1'
      if low>=55 & high<105 then note['RIVAL_LEVEL_CANDIDATE']='L2'
      if low>=105 & high<=160 then note['RIVAL_LEVEL_CANDIDATE']='L3'
    end
  end
  a=self~anchors(frame)
  if lastSeen\==.nil then do
   if step-lastSeen['STEP']<=8 then do
    dt=step-lastSeen['STEP']
    prev=lastSeen['RIVAL'];previousAnchors=lastSeen['ANCHORS']
    anchorMotion=0;count=0
    do key over a~allIndexes
      if \previousAnchors~hasIndex(key) then iterate
      anchorMotion+=self~wrap(a[key]-previousAnchors[key]);count+=1
    end
    if count>=2 then do
      shift=self~wrap(r['AZ']-prev['AZ']-anchorMotion/count)
      note['APPARENT_CROSS_TRACK_DEG']=shift/dt
      note['EGO_YAW_REMOVED']='SHARED_LANDMARKS'
      note['RELATIVE_SPEED_STATUS']='APPARENT_RELATIVE_MOTION_NOT_GROUND_SPEED'
      if dist\=='UNKNOWN' & lastSeen['DIST']\=='UNKNOWN' then do
        range0=lastSeen['DIST']
        /* Apparent speed of one image silhouette relative to observer:
           radial size change plus tangential motion after anchor rotation.
           Self translation and parallax are not separable; it is NOT the
           rival's independent speed and cannot prove headwind. */
        tang=abs(shift)*3.14159265358979/180*(dist+range0)/2/dt
        radial=abs(dist-range0)/dt
        note['RELATIVE_SPEED_APPROX_MPS']=HSqrt(tang*tang+radial*radial)
      end
      stableOwn=.false
      if ownCommand\==.nil then do
        if abs(ownCommand[1])<=3 & abs(ownCommand[2])<=1.2 then stableOwn=.true
      end
      if stableOwn then do
        rangeStable=.false
        if dist\=='UNKNOWN' then do
          if lastSeen['DIST']\=='UNKNOWN' then do
            if abs(dist-lastSeen['DIST'])/dt<1.0 then rangeStable=.true
          end
        end
        if abs(shift/dt)<0.6 & rangeStable then do
          stalls+=1;moving=0
        end
        else do
          stalls=0
          if abs(shift/dt)>1.5 then moving+=1
          else moving=0
        end
        if lastLateral*shift<0 & abs(lastLateral)>2 & abs(shift)>2 then ,
          jitterCounter+=1
        else jitterCounter=max(0,jitterCounter-1)
        lastLateral=shift
      end
      else do
        stalls=0;moving=0;jitterCounter=0;lastLateral=0
      end
    end
  end
  end
  if jitterCounter>=2 then do
    note['WIND_IDEA']='POSSIBLE_RIVAL_BUFFETING_OR_STEERING'
    note['CONFIDENCE']='LOW_CANDIDATE'
  end
  else if stalls>=3 then do
    note['WIND_IDEA']='POSSIBLE_HEADWIND_HOVER_OR_MATCHED_MOTION'
    note['CONFIDENCE']='LOW_CANDIDATE'
  end
  else if moving>=2 then do
    note['WIND_IDEA']='RIVAL_MOVING_RELATIVE_TO_OBSERVER'
    note['CONFIDENCE']='LOW_CANDIDATE'
  end
  else if note['EGO_YAW_REMOVED']=='SHARED_LANDMARKS' then ,
    note['WIND_IDEA']='RELATIVE_IMAGE_MOTION_WIND_UNDETERMINED'
  else note['WIND_IDEA']='RIVAL_SILHOUETTE_NO_SPEED_BASELINE'
  note['RIVAL_WIND_PROVEN']='NO'
  /* Only a sufficiently narrow IMAGE-BASED height interval may attribute a
   * weak rival-wind idea to a named altitude band. Otherwise do not invent
   * which level the observed headwind/buffeting belongs to. */
  lvl=note['RIVAL_LEVEL_CANDIDATE']
  if lvl\=='UNRESOLVED' & note['WIND_IDEA']~left(8)=='POSSIBLE' then do
    if \levelIdeas~hasIndex(lvl) then do
      h=.directory~new;h['OBSERVATIONS']=0;h['LAST_STEP']=step
      h['CONFIDENCE']='LOW_IMAGE_HYPOTHESIS'
      levelIdeas[lvl]=h
    end
    h=levelIdeas[lvl]
    h['OBSERVATIONS']+=1;h['LAST_STEP']=step
    h['IDEA']=note['WIND_IDEA']
  end
  lastSeen=.directory~new
  lastSeen['STEP']=step;lastSeen['RIVAL']=r;lastSeen['ANCHORS']=a;lastSeen['DIST']=dist
  lastStep=step
  return self~record(note)
::method observeFixed
  expose fixedViews
  use strict arg viewID,frame,step
  /* Fixed cameras are requested through the global 5-step service. This
   * method has NO means to request one or move it. Same-view tracking only. */
  allowed=.array~of('CAFE_SYDNEY','OPERA_WEST_WALK','KIRRIBILLI','NORTH_PTZ','BLUES_PT')
  ok=.false
  do name over allowed
    if viewID==name then ok=.true
  end
  if \ok then raise syntax 88.900 array('not a fixed camera site')
  rival=(.Slam450Vision~new)~observe(frame,'R')
  info=.directory~new
  info['STEP']=step;info['CAMERA']=viewID
  info['STATUS']='RIVAL_NOT_VISIBLE';info['ANGULAR_SPEED_DEG_PER_STEP']='UNKNOWN'
  info['SPEED_APPROX_MPS']='UNKNOWN';info['RANGE_APPROX_M']='UNKNOWN'
  info['WIND_PROVEN']='NO'
  info['SOURCE']='ONE_GRANTED_FIXED_IMAGE'
  if rival==.nil then return info
  info['STATUS']='FIXED_CAMERA_RIVAL_SEEN'
  info['AZ_DEG']=rival['AZ'];info['EL_DEG']=rival['EL']
  info['ALTITUDE_ORDER_FROM_FIXED']='ABOVE_OR_LEVEL'
  if rival['EL']< -5 then info['ALTITUDE_ORDER_FROM_FIXED']='BELOW_OR_LEVEL'
  info['RANGE_APPROX_M']=self~rangeCandidate(rival,frame['WIDTH'])
  if fixedViews~hasIndex(viewID) then do
    old=fixedViews[viewID]
    if step<=old['STEP'] then raise syntax 88.900 array('nonmonotonic fixed camera observation')
    info['ANGULAR_SPEED_DEG_PER_STEP']=self~wrap(rival['AZ']-old['AZ_DEG'])/(step-old['STEP'])
    info['STATUS']='SAME_STATIONARY_VIEW_MOTION_CANDIDATE'
    if info['RANGE_APPROX_M']\=='UNKNOWN' & old['RANGE_APPROX_M']\=='UNKNOWN' then do
      rate=abs(info['ANGULAR_SPEED_DEG_PER_STEP'])*3.14159265358979/180
      tang=rate*(info['RANGE_APPROX_M']+old['RANGE_APPROX_M'])/2
      radial=abs(info['RANGE_APPROX_M']-old['RANGE_APPROX_M'])/(step-old['STEP'])
      info['SPEED_APPROX_MPS']=HSqrt(tang*tang+radial*radial)
      info['SPEED_STATUS']='FIXED_SITE_APPARENT_SPEED_CANDIDATE_NOT_ABSOLUTE'
    end
  end
  fixedViews[viewID]=info
  return info
::method recommendAltitude
  expose lastEstimate trials
  use strict arg ownLevel,ownCommand
  reply=.directory~new
  reply['ACTION']='HOLD';reply['CLIMB_M_PER_STEP']=0
  reply['REASON']='NO_QUALIFIED_ALTERNATIVE';reply['CONFIDENCE']='UNTESTED'
  if lastEstimate==.nil then return reply
  if ownLevel\=='L1' & ownLevel\=='L2' & ownLevel\=='L3' then return reply
  note=lastEstimate
  idea=note['WIND_IDEA'];order=note['HEIGHT_ORDER']
  direction=0
  /* Deliberately PROBE, not a claimed optimal or known wind layer.
   * A visually struggling rival suggests trying AWAY from its relative
   * altitude; a visually faster rival with low own forward airflow can
   * motivate a trial TOWARDS its relative altitude. No level is named
   * for the rival unless the broad interval actually supports it. */
  if idea=='POSSIBLE_RIVAL_BUFFETING_OR_STEERING' | ,
     idea=='POSSIBLE_HEADWIND_HOVER_OR_MATCHED_MOTION' then do
    if order=='ABOVE' then direction=-1
    if order=='BELOW' then direction=1
    reply['REASON']='TRY_OTHER_LEVEL_RIVAL_APPARENTLY_STRUGGLING'
  end
  else if idea=='RIVAL_MOVING_RELATIVE_TO_OBSERVER' then do
    if note['OWN_PITOT_MPS']\=='UNKNOWN' & ownCommand\==.nil then do
      if note['OWN_PITOT_MPS']<max(0.1,ownCommand[2]*0.35) then do
        if order=='ABOVE' then direction=1
        if order=='BELOW' then direction=-1
        reply['REASON']='TRY_RIVAL_LEVEL_OWN_AIRFLOW_WEAK'
      end
    end
  end
  if (ownLevel=='L1' & direction<0) | (ownLevel=='L3' & direction>0) then direction=0
  if direction\=0 then do
    reply['ACTION']='ALTITUDE_EXPERIMENT'
    reply['CLIMB_M_PER_STEP']=1.5*direction
    reply['CONFIDENCE']='HYPOTHESIS_REQUIRES_TRIAL'
    trials+=1
  end
  return reply
::method saveObservations
  expose slots
  use strict arg file
  call SysFileDelete file
  call lineout file,'step,source,own_level,rival_status,rival_type,height_order,rival_level_candidate,rival_altitude_low_m,rival_altitude_high_m,range_approx_m,relative_speed_approx_mps,relative_speed_status,cross_track_deg_per_step,wind_idea,confidence'
  do o over slots
    call lineout file,o['STEP']||','||o['SOURCE']||','||o['OWN_LEVEL']||','||o['RIVAL_STATUS']||','||typeOf(o)||','||o['HEIGHT_ORDER']||','||o['RIVAL_LEVEL_CANDIDATE']||','||o['RIVAL_ALTITUDE_LOW_M']||','||o['RIVAL_ALTITUDE_HIGH_M']||','||o['RANGE_APPROX_M']||','||o['RELATIVE_SPEED_APPROX_MPS']||','||o['RELATIVE_SPEED_STATUS']||','||o['APPARENT_CROSS_TRACK_DEG']||','||o['WIND_IDEA']||','||o['CONFIDENCE']
  end
  call stream file,'C','CLOSE'
  return slots~items

::routine typeOf
  use strict arg o
  if o~hasIndex('RIVAL_TYPE') then return o['RIVAL_TYPE']
  return 'UNKNOWN'
