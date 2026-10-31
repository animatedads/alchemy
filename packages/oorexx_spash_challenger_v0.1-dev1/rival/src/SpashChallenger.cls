/* SPASH RIVAL v0.1, clean-sheet ooRexx strategy competition over EXISTING
 * Audio V9 spectral trajectories. Architecture Tom Dyer. No Python DSP.
 * Tests use synthetic spectral features and real native Audio V9 TSV input.
 */
::class SpashRivalFrame public
::attribute feed get
::attribute frameMs get
::attribute trajectory get
::attribute strength get
::attribute coherence get
::attribute stability get
::attribute shape get
::attribute confound get
::attribute sourceRef get
::method init
  expose feed frameMs trajectory strength coherence stability shape confound sourceRef
  use strict arg feed,frameMs,trajectory,strength,coherence,stability,shape,sourceRef,confound=.nil
  if feed=='' then raise syntax 88.900 array('feed identity missing')
  do n over .array~of(frameMs,strength,coherence,stability)
    if \datatype(n,'N') then raise syntax 88.900 array('spectral frame numeric value required')
  end
  if frameMs<0 | strength<0 | strength>1 | coherence<0 | coherence>1 | stability<0 | stability>1 then raise syntax 88.900 array('frame range out of bounds')
  if \shape~isA(.array) then raise syntax 88.900 array('shape must be Array')
  if shape~items<>3 then raise syntax 88.900 array('three band shape required')
  total=0
  do v over shape
    if \datatype(v,'N') then raise syntax 88.900 array('numeric spectral shape required')
    if v<0 then raise syntax 88.900 array('negative spectral shape')
    total=total+v
  end
  if total<=0 then raise syntax 88.900 array('empty shape')
  copied=.array~new
  do v over shape;copied~append(v/total);end
  shape=copied
  if sourceRef==.nil then raise syntax 88.900 array('Storage Fabric source reference required')
  if \sourceRef~hasMethod('objectId') | \sourceRef~hasMethod('digest') then raise syntax 88.900 array('StorageRef interface required')
  if sourceRef~objectId=='' | length(sourceRef~digest)<>64 then raise syntax 88.900 array('source objectId and sha256 required')
  if confound\==.nil then do
    if \confound~isA(.directory) then raise syntax 88.900 array('confound evidence must be directory')
    do k over .array~of('TONAL_PERSISTENCE','FREQUENCY_SWEEP','TWO_TONE_SWITCH')
      v=confound~at(k)
      if v==.nil then raise syntax 88.900 array('missing measured confound feature',k)
      if \datatype(v,'N') then raise syntax 88.900 array('numeric confound evidence',k)
      if v<0 | v>1 then raise syntax 88.900 array('invalid confound range',k)
    end
    if confound~at('AUTHORITY')\=='OBSERVED_SPECTRAL_FEATURES' then raise syntax 88.900 array('confound feature authority required')
  end
::method confoundStatus
  expose confound
  if confound==.nil then return 'UNTESTED_CONFOUND'
  if confound['TONAL_PERSISTENCE']>=.77 then do
    if confound['FREQUENCY_SWEEP']>=.68 then return 'SIREN_LIKE_VETO'
    if confound['TWO_TONE_SWITCH']>=.68 then return 'KLAXON_LIKE_VETO'
  end
  return 'NO_CONFOUND_VETO'
::method vector
  expose shape
  return shape~copy
/* A spectral run cannot continue across feed, original media object,
 * trajectory, reversed/duplicate time or a long unobserved interval.
 * Source time is measured frame_ms, NOT a verified wall-clock origin. */
::method continues
  expose feed frameMs trajectory sourceRef
  use strict arg previous,maxGapMs=250
  if previous==.nil then return .false
  if \previous~isA(.SpashRivalFrame) then return .false
  if feed\==previous~feed | trajectory\==previous~trajectory then return .false
  if sourceRef~objectId\==previous~sourceRef~objectId then return .false
  if sourceRef~digest\==previous~sourceRef~digest then return .false
  delta=frameMs-previous~frameMs
  return (delta>0 & delta<=maxGapMs)

::class SpashRivalTsvReader public
::method read
  use strict arg path,sourceRef
  src=.stream~new(path)
  if src~open('READ')<0 then raise syntax 88.900 array('native Audio V9 measured-track TSV not accessible',path)
  line=src~linein
  if pos('audio.v9',line)>0 then do
    src~close
    raise syntax 88.900 array('unexpected TSV header')
  end
  if pos('spectral_shape_low',line)=0 | pos('track_spectral_similarity',line)=0 then do
    src~close
    raise syntax 88.900 array('incompatible Audio V9 spectral track schema')
  end
  output=.array~new
  do while src~lines>0
    line=src~linein
    fields=line~makeArray('09'x)
    if fields~items<23 then do
      src~close
      raise syntax 88.900 array('truncated measured Audio V9 spectral row')
    end
    if fields[1]\=='audio.v9.multipath.spectral-track/1' then iterate
    if fields[10]=='UNCERTAIN_PATH' then nop /* preserve uncertainty, not delete */
    /* no claimed tonal feature: three spectral bands cannot identify sirens */
    frame=.SpashRivalFrame~new(fields[2],fields[4],fields[3],-
      min(1,max(0,abs(fields[9]))),-
      min(1,max(0,(abs(fields[16])+abs(fields[17])+abs(fields[18]))/3)), -
      min(1,max(0,fields[22])), -
      .array~of(fields[19],fields[20],fields[21]),sourceRef)
    output~append(frame)
  end
  src~close
  return output

::class SpashRivalStrategy public
::attribute method get
::attribute window get
::attribute guard get
::attribute selectThreshold get
::attribute id get
::method init
  expose method window guard selectThreshold id
  use strict arg method,window,guard,selectThreshold
  method=method;window=window;guard=guard;selectThreshold=selectThreshold
  id=method||':W'||window||':G'||guard
::method assess
  expose method guard selectThreshold
  use strict arg frame
  if \frame~isA(.SpashRivalFrame) then raise syntax 88.900 array('spectral frame required')
  status=frame~confoundStatus
  if status=='SIREN_LIKE_VETO' | status=='KLAXON_LIKE_VETO' then return .array~of(0,status)
  /* Five declared strategies from distinct Audio-method viewpoints.
   * Input fields were measured by Audio V9; no DSP here. */
  select
    when method=='PATH_COHERENCE' then score=.62*frame~coherence+.26*frame~stability+.12*frame~strength
    when method=='SPECTRAL_STABILITY' then score=.17*frame~coherence+.69*frame~stability+.14*frame~strength
    when method=='LOW_ENERGY_RETAIN' then score=.30*frame~coherence+.40*frame~stability+.30*(1-abs(frame~strength-.45))
    when method=='MULTIBAND_BALANCE' then do
      a=frame~vector
      balance=1-(max(a[1],a[2],a[3])-min(a[1],a[2],a[3]))
      score=.25*frame~coherence+.34*frame~stability+.41*balance
    end
    when method=='MOTION_RESIDUAL' then score=.48*frame~coherence+.22*frame~stability+.30*(1-abs(frame~strength-frame~stability))
    otherwise raise syntax 88.900 array('unknown registered strategy',method)
  end
  /* Unknown confounds must never be misreported as negative or verified speech.
   * Strictness is sensitivity exploration only, not acoustic truth. */
  if status=='UNTESTED_CONFOUND' then score=score-.015*guard
  if score<0 then score=0
  if score>1 then score=1
  if score<selectThreshold then return .array~of(score,'BELOW_STRATEGY_THRESHOLD')
  return .array~of(score,status)

::class SpashRivalCompetition public
::attribute configurations get
::method init
  expose configurations
  configurations=.array~new
  methods=.array~of('PATH_COHERENCE','SPECTRAL_STABILITY','LOW_ENERGY_RETAIN','MULTIBAND_BALANCE','MOTION_RESIDUAL')
  windows=.array~of(2,4,8,16,32)
  gates=.array~of(.35,.45,.55,.65)
  do method over methods
    do window over windows
      do i=1 to gates~items
        configurations~append(.SpashRivalStrategy~new(method,window,i-1,gates[i]))
      end
    end
  end
::method evaluate
  use strict arg frames,maxReturned=10
  if \frames~isA(.array) | frames~items<2 then raise syntax 88.900 array('at least 2 measured frames')
  if \datatype(maxReturned,'W') | maxReturned<=0 then raise syntax 88.900 array('positive result limit')
  rows=.array~new
  do config over self~configurations
    kept=0;sum=0;links=0;vetoes=0;framesCount=0
    last=.nil;previous=.nil;run=0
    do f over frames
      if previous\==.nil then do
        if \f~continues(previous) then do
          run=0;last=.nil
        end
      end
      previous=f
      trial=config~assess(f)
      score=trial[1]
      if trial[2]=='SIREN_LIKE_VETO' | trial[2]=='KLAXON_LIKE_VETO' then vetoes=vetoes+1
      if score>=config~selectThreshold & trial[2]\=='SIREN_LIKE_VETO' & trial[2]\=='KLAXON_LIKE_VETO' then do
        run=run+1
        if run>=config~window then do
          kept=kept+1;sum=sum+score
          if last\==.nil then do
            if f~continues(last) then links=links+1
          end
          last=f
        end
      end
      else do
        run=0;last=.nil
      end
      framesCount=framesCount+1
    end
    /* bounded multiobjective SLAM: pattern continuity plus useful coverage;
     * prefer multiple partial paths, do not overfit one long noisy interval. */
    if kept>0 then do
      mean=sum/kept
      continuity=links/max(1,kept)
      coverage=kept/framesCount
      merit=.42*mean+.28*continuity+.30*min(1,coverage*3)
    end
    else do
      mean=0;continuity=0;coverage=0;merit=0
    end
    r=.directory~new
    r['STRATEGY_ID']=config~id;r['MERIT']=merit;r['SELECTED_ROWS']=kept
    r['COVERAGE']=coverage;r['CONTINUITY']=continuity;r['MEAN_LIKENESS']=mean
    r['CONFOUND_VETO_COUNT']=vetoes;r['AUTHORITY']='UNSUPERVISED_CANDIDATE_RANKING_NOT_SPEECH_PROOF'
    r['GROUND_TRUTH_SCORE']='UNSCORED_REQUIRES_BLIND_HUMAN_REVIEW'
    rows~append(r)
  end
  /* Stable deterministic top N; all 100 candidates evaluated. */
  ranked=.array~new
  do r over rows
    posn=ranked~items+1
    do i=1 to ranked~items
      if r['MERIT']>ranked[i]['MERIT'] then do;posn=i;leave;end
      if r['MERIT']==ranked[i]['MERIT'] & r['STRATEGY_ID']<ranked[i]['STRATEGY_ID'] then do;posn=i;leave;end
    end
    ranked~append(r)
    do swapAt=ranked~items to posn+1 by -1
      ranked[swapAt]=ranked[swapAt-1]
    end
    ranked[posn]=r
  end
  out=.directory~new
  out['TRIALS']=rows~items
  out['TOP']=.array~new
  do i=1 to min(maxReturned,ranked~items);out['TOP']~append(ranked[i]);end
  out['AUTHORITY']='EXPERIMENTAL_SELECTION_NO_VOICE_LABELS'
  return out

::class SpashRivalEventLedger public
::method read
  use strict arg path
  stream=.stream~new(path)
  if stream~open('READ')<0 then raise syntax 88.900 array('video event table missing')
  header=stream~linein
  if pos('video_timing_authority',header)=0 | pos('nominal_clock_authority',header)=0 then raise syntax 88.900 array('not authoritative recovered video events')
  rows=.array~new
  do while stream~lines>0
    raw=stream~linein
    cols=raw~makeArray('09'x)
    if cols~items<20 then iterate
    row=.directory~new
    row['CAMERA']=cols[1];row['SOURCE_VIDEO']=cols[2];row['EVENT_ID']=cols[4]
    row['EVENT_CLASS']=cols[5];row['START_MS']=cols[6];row['END_MS']=cols[8]
    row['AUTHORITY']=cols[17];row['AUDIO_SYNC']='UNKNOWN'
    rows~append(row)
  end
  stream~close
  return rows
::method attach
  use strict arg event, clockEvidence=.nil
  if clockEvidence==.nil then return 'CONTEXT_ONLY_NO_AUDIO_ALIGNMENT'
  if \clockEvidence~isA(.directory) then raise syntax 88.900 array('clock evidence Directory required')
  if clockEvidence~at('AUTHORITY')\=='OBSERVED_AUDIO_VIDEO_CLOCK_ALIGNMENT' then return 'CONTEXT_ONLY_NO_AUDIO_ALIGNMENT'
  if clockEvidence~at('UNCERTAINTY_MS')==.nil then return 'CONTEXT_ONLY_NO_AUDIO_ALIGNMENT'
  if \datatype(clockEvidence['UNCERTAINTY_MS'],'N') then return 'CONTEXT_ONLY_NO_AUDIO_ALIGNMENT'
  if clockEvidence['UNCERTAINTY_MS']<=0 then return 'CONTEXT_ONLY_NO_AUDIO_ALIGNMENT'
  return 'EVENT_STRATUM_ELIGIBLE_NOT_ACOUSTIC_PROOF'

/* Audio layering is an immutable lineage, not another waveform processor.
 * Requires injected real Storage Fabric Catalogue and existing StorageRefs.
 * No physical object is declared persisted until Storage Fabric commits it. */
::class SpashRivalLayers public
::method register
  use strict arg catalogue,layerRef,originRef,role,methodId,byteCount=0
  if catalogue==.nil | layerRef==.nil | originRef==.nil then raise syntax 88.900 array('Storage Fabric object catalogue/ref required')
  if \catalogue~hasMethod('put') | \catalogue~hasMethod('get') then raise syntax 88.900 array('StorageCatalogue interface required')
  if \layerRef~hasMethod('digest') | \originRef~hasMethod('digest') then raise syntax 88.900 array('StorageRef interface required')
  if length(layerRef~digest)<>64 | length(originRef~digest)<>64 then raise syntax 88.900 array('source and layer SHA-256 required')
  if role\=='ORIGINAL' & role\=='MEASURED_SPECTRAL' & role\=='STRATEGY_VIEW' & role\=='MODEL_VIRTUAL' & role\=='LISTENING_DERIVATIVE' then raise syntax 88.900 array('unknown audio layer role')
  if \datatype(byteCount,'W') | byteCount<0 then raise syntax 88.900 array('invalid material length')
  if methodId=='' then raise syntax 88.900 array('method provenance required')
  if catalogue~get(layerRef~objectId)\==.nil then raise syntax 88.900 array('immutable layer already exists')
  material=.StorageObject~new(layerRef,role,byteCount,'application/vnd.spash.layer')
  material~eas~put(.StorageEA~new('spash','role',role,'STRING','SPASH_RIVAL','EXPERIMENTAL'))
  material~eas~put(.StorageEA~new('spash','origin_ref',originRef~objectId,'STRING','SPASH_RIVAL','SOURCE_LINEAGE'))
  material~eas~put(.StorageEA~new('spash','method',methodId,'STRING','SPASH_RIVAL','EXPERIMENTAL'))
  catalogue~put(material)
  return material

::class SpashRivalMUSharder public
::method plan
  use strict arg strategies,workerCount=10
  if \strategies~isA(.array) then raise syntax 88.900 array('strategy Array required')
  if \datatype(workerCount,'W') | workerCount<1 then raise syntax 88.900 array('positive available MU count required')
  shards=.array~new
  do i=1 to workerCount
    task=.directory~new;task['SLOT']='MU_SLOT_'||i;task['STRATEGIES']=.array~new
    task['STATUS']='PLANNED_NOT_DISPATCHED';task['DATA_POLICY']='JOB_TO_RESIDENT_DATA_NO_PCM_IN_CONTROL'
    shards~append(task)
  end
  do i=1 to strategies~items
    slot=((i-1)//workerCount)+1
    task=shards[slot]
    assigned=task~at('STRATEGIES')
    assigned~append(strategies[i]~id)
  end
  return shards

::class SpashRivalIntervalSelector public
::method select
  use strict arg frames,strategy,maxIntervals=40
  if \frames~isA(.array) | \strategy~isA(.SpashRivalStrategy) then raise syntax 88.900 array('measured frames and strategy required')
  if \datatype(maxIntervals,'W') | maxIntervals<1 then raise syntax 88.900 array('bounded number of intervals required')
  intervals=.array~new;begin=.nil;finish=.nil;count=0;feed='';trajectory='';lastFrame=.nil
  do f over frames
    result=strategy~assess(f)
    if result[1]>=strategy~selectThreshold & result[2]\=='SIREN_LIKE_VETO' & result[2]\=='KLAXON_LIKE_VETO' then do
      if begin==.nil then do
        begin=f~frameMs;finish=f~frameMs;feed=f~feed;trajectory=f~trajectory;count=0
      end
      if lastFrame\==.nil & \f~continues(lastFrame) then do
        if count>=strategy~window then call emitInterval intervals,begin,finish,count,feed,trajectory,strategy
        begin=f~frameMs;finish=f~frameMs;feed=f~feed;trajectory=f~trajectory;count=0
      end
      finish=f~frameMs;count=count+1;lastFrame=f
    end
    else do
      if begin\==.nil & count>=strategy~window then call emitInterval intervals,begin,finish,count,feed,trajectory,strategy
      begin=.nil;count=0;lastFrame=.nil
    end
  end
  if begin\==.nil & count>=strategy~window then call emitInterval intervals,begin,finish,count,feed,trajectory,strategy
  out=.array~new
  do i=1 to min(maxIntervals,intervals~items);out~append(intervals[i]);end
  return out
::routine emitInterval
  use strict arg intervals,first,last,n,feed,trajectory,strategy
  rec=.directory~new
  rec['FEED']=feed;rec['TRAJECTORY_ID']=trajectory;rec['START_MS']=first;rec['END_MS']=last
  rec['FRAMES']=n;rec['STRATEGY_ID']=strategy~id
  rec['TIME_REFERENCE']='MEASURED_TRACK_FRAME_MS_ORIGIN_UNVERIFIED'
  rec['FD_CHAIN_WALL_TIME']='NOT_DERIVABLE_WITHOUT_TRACK_ORIGIN_MAPPING'
  rec['BLIND_REVIEW_SCORE']='UNSCORED'
  rec['CLASSIFICATION']='ACOUSTIC_CANDIDATE_ONLY_NOT_VERIFIED_VOICE'
  rec['REQUIRES_RECONSTRUCTION']=.true
  intervals~append(rec)
::requires 'StorageFabric.cls'