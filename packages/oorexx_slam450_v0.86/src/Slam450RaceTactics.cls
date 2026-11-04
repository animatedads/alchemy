/* SLAM 450 duel strategy: bounded, private, image-only tactical memory.
 * Architecture: Tom Dyer. Native ooRexx implementation: ChatGPT GPT-6.
 * The caller passes ONE onboard panorama and public target-claim events.
 * No world pose, target coordinates, wind vector or rival controller state.
 * Target sequence is advisory in the race: an aircraft MAY anticipate the
 * next unclaimed target, but the referee alone validates physical claims.
 */
::requires 'Slam450Flight.cls'

::class Slam450RaceTactics public
::attribute id get
::attribute notes get
::attribute capacity get
::attribute stats get
::attribute decisions get
::method init
  expose id notes capacity stats decisions nextSerial
  use strict arg aircraftID,slots=48
  if aircraftID\=='A1' & aircraftID\=='A2' & aircraftID\=='A3' & aircraftID\=='A3' then raise syntax 88.900 array('bad aircraft id')
  if slots<6 | slots>128 then raise syntax 88.900 array('bad tactic memory capacity')
  id=aircraftID;capacity=slots
  notes=.array~new;stats=.directory~new;decisions=.directory~new;nextSerial=0
::method angle
  use strict arg a
  do while a>180;a-=360;end
  do while a< -180;a+=360;end
  return a
::method testedScore
  expose stats
  use strict arg context,action
  key=context||'_'||action
  if \stats~hasIndex(key) then return 0.55
  h=stats[key]
  return (h['REWARD']+0.55)/(h['TRIALS']+1)
::method choose
  expose id notes capacity stats decisions nextSerial
  use strict arg frame,currentNumber,nextNumber,step
  if \datatype(step,'W') | step<0 then raise syntax 88.900 array('invalid step')
  if \datatype(currentNumber,'W') | \datatype(nextNumber,'W') then raise syntax 88.900 array('invalid target id')
  if currentNumber<1 | currentNumber>5 | nextNumber<1 | nextNumber>5 then raise syntax 88.900 array('target outside 1..5')
  vision=.Slam450Vision~new
  current=vision~observe(frame,currentNumber)
  next=vision~observe(frame,nextNumber)
  rival=vision~observe(frame,'R')
  alignment='UNKNOWN'
  competitor='NOT_VISIBLE'
  if rival\==.nil & current\==.nil then do
    delta=abs(self~angle(rival['AZ']-current['AZ']))
    alignment=delta
    if delta<=10 then competitor='RIVAL_ALIGNED_WITH_CURRENT_TARGET'
    else competitor='RIVAL_OFF_CURRENT_TARGET_AXIS'
  end
  context='NEXT_HIDDEN'
  if next\==.nil then do
    context='NEXT_SEEN_RIVAL_UNRESOLVED'
    if competitor=='RIVAL_ALIGNED_WITH_CURRENT_TARGET' then context='NEXT_SEEN_RIVAL_ALIGNED'
    if competitor=='RIVAL_OFF_CURRENT_TARGET_AXIS' then context='NEXT_SEEN_RIVAL_OFF_AXIS'
  end
  target=currentNumber;action='CHASE_CURRENT';reason='CURRENT_TARGET_FIRST'
  if current==.nil & next\==.nil then do
    action='ANTICIPATE_NEXT';target=nextNumber;reason='CURRENT_UNSEEN_NEXT_VISIBLE'
  end
  else if current\==.nil & next\==.nil then do
    now=self~testedScore(context,'CHASE_CURRENT')
    later=self~testedScore(context,'ANTICIPATE_NEXT')
    /* An apparent alignment is a competing-aircraft hypothesis, NOT proof
     * of relative range or intention. Behaviour remains learnable. */
    if competitor=='RIVAL_ALIGNED_WITH_CURRENT_TARGET' then do
      now-=0.08;later+=0.08
    end
    if later>now then do
      action='ANTICIPATE_NEXT';target=nextNumber;reason='IMAGE_CUES_AND_LEARNED_CLAIM_RATE'
    end
    else reason='IMAGE_CUES_AND_LEARNED_CLAIM_RATE'
  end
  nextSerial+=1
  serial=id||'-'||nextSerial
  note=.directory~new
  note['ID']=serial;note['STEP']=step;note['CONTEXT']=context
  note['ACTION']=action;note['TARGET']=target;note['REASON']=reason
  note['RIVAL_CUE']=competitor;note['RIVAL_ALIGNMENT_DEG']=alignment
  note['CURRENT_VISIBLE']=(current\==.nil);note['NEXT_VISIBLE']=(next\==.nil)
  note['OUTCOME']='UNTESTED';note['CONFIDENCE']='VISUAL_CANDIDATE_NOT_RANGE_PROOF'
  if notes~items>=capacity then do
    old=notes[1]
    if decisions~hasIndex(old['ID']) then decisions~remove(old['ID'])
    trimmed=.array~new
    do i=2 to notes~items;trimmed~append(notes[i]);end
    notes=trimmed
  end
  notes~append(note);decisions[serial]=note
  answer=.directory~new
  answer['DECISION_ID']=serial;answer['ACTION']=action;answer['TARGET']=target
  answer['REASON']=reason;answer['EVIDENCE']='ONBOARD_IMAGE_AND_PRIVATE_HISTORY'
  answer['RIVAL_CUE']=competitor;answer['CONTEXT']=context
  answer['CLAIM_ELIGIBILITY']='REFEREE_DECIDES'
  return answer
::method outcome
  expose decisions stats
  use strict arg serial,event
  if \decisions~hasIndex(serial) then return 'UNKNOWN_OR_EXPIRED_DECISION'
  note=decisions[serial]
  if note['OUTCOME']\=='UNTESTED' then return 'ALREADY_SCORED'
  select
    when event=='SELF_CLAIMED' then reward=1
    when event=='RIVAL_CLAIMED' then reward=0
    when event=='ABANDONED' then reward=0.2
    otherwise raise syntax 88.900 array('unknown public claim event')
  end
  note['OUTCOME']=event
  key=note['CONTEXT']||'_'||note['ACTION']
  if \stats~hasIndex(key) then do
    d=.directory~new;d['TRIALS']=0;d['REWARD']=0
    stats[key]=d
  end
  d=stats[key];d['TRIALS']+=1;d['REWARD']+=reward
  return 'SCORED_FROM_PUBLIC_EVENT'
::method summary
  expose id notes stats
  s=.directory~new
  s['AIRCRAFT']=id;s['MEMORY_SLOTS']=notes~items;s['LEARNED_CONTEXTS']=stats~items
  s['PRIVATE']='TRUE';s['WORLD_COORDINATES']='NOT_STORED'
  return s

/* Image-only aircraft separation helper. It deliberately NEVER infers a
 * measured range from a pixel width; an expanding angular silhouette is a
 * proximity WARNING, not a certified separation distance. The referee's
 * exact swept-sphere kill gate is separate and remains authoritative. */
::class Slam450RivalAvoidance public
::attribute notes get
::method init
  expose notes
  notes=.array~new
::method filter
  expose notes
  use strict arg frame,command,step
  r=(.Slam450Vision~new)~observe(frame,'R')
  if r==.nil then return command
  if notes~items>=36 then do
    kept=.array~new
    do i=2 to notes~items;kept~append(notes[i]);end
    notes=kept
  end
  note=.directory~new;note['STEP']=step;note['RIVAL_AZ']=r['AZ']
  note['ANGULAR_WIDTH_PIXELS']=r['WIDTH']
  note['CAUSE']='ONBOARD_RIVAL_SILHOUETTE_ONLY'
  notes~append(note)
  out=command~copy
  /* A 2.5m model billboard crosses the visual-warning threshold when
   * its angular size grows large. Avoid toward the OPPOSITE visible side.
   * Thus two independently observing craft can separate without a shared
   * flight plan or access to each other's controls. */
  if r['WIDTH']>=30 then do
    out[2]=min(out[2],2.5)
    if r['AZ']>0 then out[4]=-3
    else if r['AZ']<0 then out[4]=3
    else do
      /* In exact head-on image ambiguity, hold instead of guessing. */
      out[2]=0;out[4]=0
    end
  end
  return out
