/* SPASH raw visual motion observation clock v0.1.
 * Pure ooRexx; frame PTS is authoritative, not a fixed frame rate.
 * Original source-video clock and audio clock are distinct authorities.
 */
::class SpashRawMotionClock public
::method init
  expose _source _frame _pts _ms _epoch _state _gx _gy _dl _dr _gm _dm _n _den _num _lastMs _firstMs _lastPts
  _source=''; _frame=.array~new; _pts=.array~new;_ms=.array~new
  _epoch=.array~new;_state=.array~new;_gx=.array~new;_gy=.array~new
  _dl=.array~new;_dr=.array~new;_gm=.array~new;_dm=.array~new
  _n=0;_den=90000;_num=1;_lastMs=0;_firstMs=0;_lastPts=0
::method load
  expose _source _frame _pts _ms _epoch _state _gx _gy _dl _dr _gm _dm _n _den _num _lastMs _firstMs _lastPts
  use strict arg samplesPath,runPath
  if _n>0 then raise syntax 88.900 array('single immutable source only')
  tab='09'x
  rs=linein(runPath)
  if rs=='' then raise syntax 88.900 array('missing run header')
  if pos('time_base_num',rs)=0 | pos('time_base_den',rs)=0 then raise syntax 88.900 array('missing timestamp authority')
  r=linein(runPath)
  call stream runPath,'C','CLOSE'
  parse var r schema (tab) version (tab) status (tab) sourcePath (tab) runSource (tab) frames (tab) sampledFrames (tab) samplesEmitted (tab) events (tab) epochs (tab) relocations (tab) firstPts (tab) lastPts (tab) timeNum (tab) timeDen (tab) lastRelMs (tab) audioUsed (tab) config
  if schema\=='FD_DOOR_MICRO_RUN_V2' | status\=='OK' then raise syntax 88.900 array('unqualified run')
  if \datatype(timeNum,'W') | \datatype(timeDen,'W') then raise syntax 88.900 array('noninteger PTS time base')
  if timeNum<=0 | timeDen<=0 then raise syntax 88.900 array('nonpositive PTS time base')
  _den=timeDen;_num=timeNum
  if \datatype(samplesEmitted,'W') then raise syntax 88.900 array('run count is not integer')
  if \datatype(lastPts,'W') | \datatype(lastRelMs,'W') then raise syntax 88.900 array('run timestamp malformed')
  header=linein(samplesPath)
  if header=='' then raise syntax 88.900 array('missing samples header')
  required=.array~of('schema','source_file','sample','time_ms','pts','epoch_id','geometry_state','global_dx_step_px','global_dy_step_px','door_left_residual_step_px','door_right_residual_step_px','global_magnitude_px','door_magnitude_px')
  do field over required
    if pos(field,header)=0 then raise syntax 88.900 array('missing raw sample field',field)
  end
  do while lines(samplesPath)>0
    line=linein(samplesPath)
    if line=='' then iterate
    parse var line s (tab) f (tab) ix (tab) mm (tab) hms (tab) p (tab) e (tab) st (tab) frameLeft (tab) frameRight (tab) fixedY (tab) doorLeft (tab) doorRight (tab) dx (tab) dy (tab) leftResidual (tab) rightResidual (tab) magGlobal (tab) magDoor (tab) gThreshold (tab) dThreshold (tab) gCandidate (tab) dCandidate (tab) cCandidate (tab) agreement
    if s\=='FD_DOOR_MICRO_SAMPLE_V2' then raise syntax 88.900 array('bad raw schema')
    if f\==runSource then raise syntax 88.900 array('mixed video source')
    if \datatype(ix,'W') | \datatype(mm,'W') | \datatype(p,'W') then raise syntax 88.900 array('noninteger raw timestamp')
    if \datatype(dx,'N') | \datatype(dy,'N') | \datatype(leftResidual,'N') | \datatype(rightResidual,'N') then raise syntax 88.900 array('non-numeric displacement')
    if \datatype(magGlobal,'N') | \datatype(magDoor,'N') then raise syntax 88.900 array('non-numeric magnitude')
    if magGlobal<0 | magDoor<0 then raise syntax 88.900 array('negative magnitude')
    exactMs=1000*p*_num/_den
    if abs(exactMs-mm)>1.01 then raise syntax 88.900 array('video PTS disagrees with ms projection',ix)
    if _n>0 then do
      if ix<=_frame[_n] | p<=_pts[_n] then raise syntax 88.900 array('nonmonotone video presentation',ix)
      if ix<>_frame[_n]+1 then raise syntax 88.900 array('missing raw frame index',ix)
    end
    _n=_n+1
    _frame[_n]=ix;_pts[_n]=p;_ms[_n]=mm;_epoch[_n]=e;_state[_n]=st
    _gx[_n]=dx;_gy[_n]=dy;_dl[_n]=leftResidual;_dr[_n]=rightResidual
    _gm[_n]=magGlobal;_dm[_n]=magDoor
  end
  call stream samplesPath,'C','CLOSE'
  if _n=0 then raise syntax 88.900 array('no raw samples')
  if _n<>samplesEmitted then raise syntax 88.900 array('run/sample count disagreement',_n)
  if _pts[_n]<>lastPts then raise syntax 88.900 array('run/last PTS disagreement')
  if abs(_ms[_n]-lastRelMs)>1 then raise syntax 88.900 array('run/last relative ms disagreement')
  if _frame[_n]<>sampledFrames then raise syntax 88.900 array('sampled frame count mismatch')
  _source=runSource;_firstMs=1000*_pts[1]*_num/_den;_lastMs=1000*_pts[_n]*_num/_den;_lastPts=_pts[_n]
  return _n
::method count; expose _n; return _n
::method sourceFile; expose _source; return _source
::method firstMs; expose _firstMs; return _firstMs
::method lastMs; expose _lastMs; return _lastMs
::method sampleAt
  expose _n _frame _pts _ms _epoch _state _gx _gy _dl _dr _gm _dm _den _num
  use strict arg index
  if \datatype(index,'W') then raise syntax 88.900 array('integer array index required')
  if index<1 | index>_n then raise syntax 88.900 array('raw sample out of bounds')
  d=.directory~new
  d['SAMPLE_INDEX']=_frame[index];d['PTS']=_pts[index];d['TIME_MS_EXACT']=1000*_pts[index]*_num/_den
  d['TIME_MS_REPORTED']=_ms[index];d['EPOCH_ID']=_epoch[index];d['GEOMETRY_STATE']=_state[index]
  d['GLOBAL_DX_STEP_PX']=_gx[index];d['GLOBAL_DY_STEP_PX']=_gy[index]
  d['DOOR_LEFT_RESIDUAL_STEP_PX']=_dl[index];d['DOOR_RIGHT_RESIDUAL_STEP_PX']=_dr[index]
  d['GLOBAL_MAGNITUDE_PX']=_gm[index];d['DOOR_MAGNITUDE_PX']=_dm[index]
  d['AUTHORITY']='OBSERVED_VIDEO_PTS_MOTION_SAMPLE'
  return d
::method cadence
  expose _n _pts _den _num
  if _n<2 then raise syntax 88.900 array('not enough samples for cadence')
  steps=_n-1;totalMs=1000*(_pts[_n]-_pts[1])*_num/_den
  count60=0;count120=0;other=0;small=1e100;large=0
  do i=2 to _n
    dt=1000*(_pts[i]-_pts[i-1])*_num/_den
    small=min(small,dt);large=max(large,dt)
    if abs(dt-60)<3 then count60=count60+1
    else if abs(dt-120)<3 then count120=count120+1
    else other=other+1
  end
  d=.directory~new
  d['SAMPLES']=_n;d['INTERVALS']=steps;d['MEAN_MS']=totalMs/steps
  d['MEAN_RATE_HZ']=1000*steps/totalMs
  d['NEAR_60MS']=count60;d['NEAR_120MS']=count120;d['OTHER_INTERVALS']=other
  d['MIN_INTERVAL_MS']=small;d['MAX_INTERVAL_MS']=large
  d['AUTHORITY']='DERIVED_FROM_VIDEO_PTS'
  return d
::method lowerIndex private
  expose _pts _n
  use strict arg target
  lo=2;hi=_n
  do while lo<=hi
    mid=trunc((lo+hi)/2)
    if _pts[mid]<target then lo=mid+1
    else hi=mid-1
  end
  return lo
::method window
  expose _source _pts _epoch _state _gx _gy _dl _dr _gm _dm _n _den _num
  use strict arg startMs,endMs
  if \datatype(startMs,'N') | \datatype(endMs,'N') then raise syntax 88.900 array('window bounds numeric')
  if startMs<0 | endMs<=startMs then raise syntax 88.900 array('bad window')
  if _n<2 then raise syntax 88.900 array('uninitialized or insufficient samples')
  startTick=startMs*_den/(1000*_num);endTick=endMs*_den/(1000*_num)
  i=self~lowerIndex(startTick)
  lengthMs=0; sumGlobal=0;sumDoor=0;sumDx=0;sumDy=0;sumL=0;sumR=0;count=0
  minGap=1e100;maxGap=0;peakGlobal=0;peakDoor=0;epoch='';geometry='STABLE'
  do while i<=_n
    if _pts[i-1]>=endTick then leave
    lo=max(startTick,_pts[i-1]);hi=min(endTick,_pts[i])
    if hi>lo then do
      span=_pts[i]-_pts[i-1]
      frac=(hi-lo)/span
      dtMs=1000*(hi-lo)*_num/_den
      lengthMs=lengthMs+dtMs
      sumGlobal=sumGlobal+_gm[i]*frac;sumDoor=sumDoor+_dm[i]*frac
      sumDx=sumDx+_gx[i]*frac;sumDy=sumDy+_gy[i]*frac
      sumL=sumL+_dl[i]*frac;sumR=sumR+_dr[i]*frac
      count=count+1
      gapMs=1000*span*_num/_den
      minGap=min(minGap,gapMs);maxGap=max(maxGap,gapMs)
      peakGlobal=max(peakGlobal,_gm[i]);peakDoor=max(peakDoor,_dm[i])
      if epoch=='' then epoch=_epoch[i]
      else if epoch\==_epoch[i] then geometry='MIXED_EPOCH'
      if _state[i]\=='STABLE' | _state[i-1]\=='STABLE' then geometry='UNSTABLE'
    end
    i=i+1
  end
  d=.directory~new
  d['SCHEMA']='spash.visual.raw-window/0.1';d['SOURCE_FILE']=_source
  d['START_MS']=startMs;d['END_MS']=endMs;d['RAW_STEPS']=count
  d['COVERED_MS']=lengthMs;d['UNCOVERED_MS']=max(0,endMs-startMs-lengthMs)
  d['EPOCH_ID']=epoch;d['GEOMETRY_STATUS']=geometry
  d['OBSERVED_MOTION_AUTHORITY']='RAW_PTS_STEP_DISPLACEMENT'
  d['AUDIO_CLOCK_AUTHORITY']='NOT_ALIGNED'
  d['VISUAL_EVENT_SUMMARIES']='NOT_USED_AS_PRIMARY_DATA'
  if count=0 | lengthMs<=0 then do
    d['STATUS']='NOT_APPLICABLE_NO_RAW_PTS_COVERAGE'
    return d
  end
  sec=lengthMs/1000
  d['STATUS']='RAW_WINDOW_MEASURED'
  d['SAMPLE_RATE_EFFECTIVE_HZ']=(count-1)/sec
  d['MIN_RAW_STEP_MS']=minGap;d['MAX_RAW_STEP_MS']=maxGap
  d['GLOBAL_TRAVEL_PX_PER_SECOND']=sumGlobal/sec
  d['DOOR_TRAVEL_PX_PER_SECOND']=sumDoor/sec
  d['GLOBAL_DX_PX_PER_SECOND']=sumDx/sec
  d['GLOBAL_DY_PX_PER_SECOND']=sumDy/sec
  d['DOOR_LEFT_RESIDUAL_PX_PER_SECOND']=sumL/sec
  d['DOOR_RIGHT_RESIDUAL_PX_PER_SECOND']=sumR/sec
  d['PEAK_GLOBAL_STEP_PX']=peakGlobal;d['PEAK_DOOR_STEP_PX']=peakDoor
  return d
