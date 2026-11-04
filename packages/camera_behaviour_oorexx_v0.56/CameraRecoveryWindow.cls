/* Admission gate for a same-track, same-source, native-time recovery window.
 * Consumes existing camera observations; does not decode, track or classify.
 * A source barrier or missing/duplicated/irregular PTS rejects the window.
 */
::class CameraRecoveryWindowDecision public
::method init
  expose status reason frameCount firstPts lastPts
  use strict arg status, reason, frameCount=0, firstPts=.nil, lastPts=.nil
::attribute status get
::attribute reason get
::attribute frameCount get
::attribute firstPts get
::attribute lastPts get

::class CameraRecoveryWindow public
::method init
  expose minimumFrames maximumGapMs
  use strict arg minimumFramesArg=5, maximumGapMsArg=200
  if \datatype(minimumFramesArg,'W') then raise syntax 93.900 array('Integer minimumFrames required')
  if minimumFramesArg<2 then raise syntax 93.900 array('minimumFrames must be >=2')
  if \datatype(maximumGapMsArg,'N') then raise syntax 93.900 array('Numeric maximumGapMs required')
  if maximumGapMsArg<=0 then raise syntax 93.900 array('maximumGapMs must be positive')
  minimumFrames=minimumFramesArg
  maximumGapMs=maximumGapMsArg

/* rows: .Directory with SOURCE, GENERATION, TRACK, PTS_MS, ADMITTED.
 * Native source-PTS is mandatory, never infer time from ordinal/frame-rate.
 * A source or camera generation change is a hard barrier.
 */
::method inspect
  expose minimumFrames maximumGapMs
  use strict arg rows
  if rows=.nil then return .CameraRecoveryWindowDecision~new('REJECTED','MISSING_ROWS')
  n=rows~items
  if n<minimumFrames then return .CameraRecoveryWindowDecision~new('REJECTED','INSUFFICIENT_FRAMES',n)
  first=.nil
  firstPts=.nil
  lastPts=.nil
  do row over rows
    if \row~isA(.Directory) then return .CameraRecoveryWindowDecision~new('REJECTED','INVALID_OBSERVATION',n)
    do key over .array~of('SOURCE','GENERATION','TRACK','PTS_MS','ADMITTED')
      if \row~hasIndex(key) then return .CameraRecoveryWindowDecision~new('REJECTED','MISSING_FIELD_'||key,n)
    end
    if row['ADMITTED']<>.true then return .CameraRecoveryWindowDecision~new('REJECTED','TRACK_NOT_ADMITTED',n)
    if \datatype(row['PTS_MS'],'N') then return .CameraRecoveryWindowDecision~new('REJECTED','INVALID_PTS',n)
    if first=.nil then do
      first=row
      firstPts=row['PTS_MS']
    end
    else do
      if row['SOURCE']<>first['SOURCE'] then return .CameraRecoveryWindowDecision~new('REJECTED','SOURCE_BARRIER',n,firstPts,lastPts)
      if row['GENERATION']<>first['GENERATION'] then return .CameraRecoveryWindowDecision~new('REJECTED','GENERATION_BARRIER',n,firstPts,lastPts)
      if row['TRACK']<>first['TRACK'] then return .CameraRecoveryWindowDecision~new('REJECTED','TRACK_CHANGE',n,firstPts,lastPts)
      gap=row['PTS_MS']-lastPts
      if gap<=0 then return .CameraRecoveryWindowDecision~new('REJECTED','NONMONOTONIC_PTS',n,firstPts,lastPts)
      if gap>maximumGapMs then return .CameraRecoveryWindowDecision~new('REJECTED','TEMPORAL_GAP',n,firstPts,lastPts)
    end
    lastPts=row['PTS_MS']
  end
  return .CameraRecoveryWindowDecision~new('ADMITTED','SOURCE_NATIVE_TRACK',n,firstPts,lastPts)
