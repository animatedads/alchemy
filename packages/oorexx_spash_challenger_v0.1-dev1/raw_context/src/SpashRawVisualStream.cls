/* SPASH raw PTS bounded visual window stream v0.2.
 * Original frame PTS and recorded displacement are authoritative.
 * No event-index time arithmetic; audio clock remains NOT_ALIGNED.
 * O(1) per-width working memory; incomplete views are never promoted.
 */
::class SpashRawVisualStream public
::attribute count get
::attribute emitted get
::method init
  expose count emitted
  count=0;emitted=0
::method scan
  expose count emitted
  use strict arg samplesPath,runPath,outputPath
  tab='09'x
  run=.stream~new(runPath)
  if run~open('READ')<0 then raise syntax 88.900 array('missing source run',runPath)
  header=run~linein
  if pos('time_base_num',header)=0 | pos('time_base_den',header)=0 then raise syntax 88.900 array('missing original PTS basis')
  runrow=run~linein~makeArray(tab)
  run~close
  if runrow~items<17 then raise syntax 88.900 array('truncated run metadata')
  if runrow[1]\=='FD_DOOR_MICRO_RUN_V2' | runrow[3]\=='OK' then raise syntax 88.900 array('wrong run schema/status')
  source=runrow[5];expected=runrow[8];sampled=runrow[7]
  num=runrow[14];den=runrow[15];lastPts=runrow[13];lastMs=runrow[16]
  if \datatype(expected,'W') | \datatype(sampled,'W') | \datatype(num,'W') | \datatype(den,'W') | \datatype(lastPts,'W') | \datatype(lastMs,'W') then raise syntax 88.900 array('invalid run integer')
  if num<=0 | den<=0 | expected<2 then raise syntax 88.900 array('invalid run basis or sample count')
  if runrow[17]\=='NO' then raise syntax 88.900 array('visual-only acquisition required')
  input=.stream~new(samplesPath)
  if input~open('READ')<0 then raise syntax 88.900 array('missing raw video samples',samplesPath)
  sampleHeader=input~linein
  keys=.array~of('schema','source_file','sample','time_ms','pts','epoch_id','geometry_state','global_dx_step_px','global_dy_step_px','door_left_residual_step_px','door_right_residual_step_px','global_magnitude_px','door_magnitude_px')
  do key over keys
    if pos(key,sampleHeader)=0 then raise syntax 88.900 array('raw video column absent',key)
  end
  cols=sampleHeader~makeArray(tab)
  expectedCols=.array~of('schema','source_file','sample','time_ms','time_hms','pts','epoch_id','geometry_state','left_frame_x','right_frame_x','fixed_horizontal_y','left_door_x','right_door_x','global_dx_step_px','global_dy_step_px','door_left_residual_step_px','door_right_residual_step_px','global_magnitude_px','door_magnitude_px')
  if cols~items<expectedCols~items then raise syntax 88.900 array('truncated raw sample column header')
  do j=1 to expectedCols~items
    if cols[j]\==expectedCols[j] then raise syntax 88.900 array('raw field position mismatched',expectedCols[j])
  end
  stagePath=outputPath||'.INCOMPLETE'
  if stream(stagePath,'C','QUERY EXISTS')\=='' then raise syntax 88.900 array('unresolved previous incomplete view',stagePath)
  output=.stream~new(stagePath)
  if output~open('WRITE REPLACE')<0 then raise syntax 88.900 array('staging view not writable',stagePath)
  output~lineout('schema'||tab||'source_file'||tab||'window_ms'||tab||'start_ms'||tab||'end_ms'||tab||'raw_steps'||tab||'covered_ms'||tab||'valid_geometry_ms'||tab||'epoch_id'||tab||'geometry_status'||tab||'global_travel_px_per_sec'||tab||'door_travel_px_per_sec'||tab||'door_excess_px_per_sec'||tab||'global_dx_px_per_sec'||tab||'global_dy_px_per_sec'||tab||'door_left_residual_px_per_sec'||tab||'door_right_residual_px_per_sec'||tab||'peak_door_step_px'||tab||'max_raw_gap_ms'||tab||'audio_clock_authority'||tab||'status')
  windows=.array~of(.SpashVisualAccumulator~new(250,source),.SpashVisualAccumulator~new(500,source),.SpashVisualAccumulator~new(1000,source),.SpashVisualAccumulator~new(2000,source))
  first=.true;oldPts=0;oldIx=0;oldEpoch='';oldState='';count=0;emitted=0
  do while input~lines>0
    line=input~linein
    if line=='' then iterate
    f=line~makeArray(tab)
    if f~items<20 then raise syntax 88.900 array('short raw movement record')
    if f[1]\=='FD_DOOR_MICRO_SAMPLE_V2' | f[2]\==source then raise syntax 88.900 array('raw sample source/schema mismatch')
    if \datatype(f[3],'W') | \datatype(f[4],'W') | \datatype(f[6],'W') then raise syntax 88.900 array('invalid source sample index/PTS')
    ix=f[3];pts=f[6];ms=f[4];epoch=f[7];state=f[8]
    if epoch=='' | state=='' then raise syntax 88.900 array('missing geometry evidence')
    do j over .array~of(14,15,16,17,18,19)
      if \datatype(f[j],'N') then raise syntax 88.900 array('invalid measured motion')
    end
    if f[18]<0 | f[19]<0 then raise syntax 88.900 array('negative raw magnitude')
    actualMs=1000*pts*num/den
    if abs(actualMs-ms)>1.01 then raise syntax 88.900 array('PTS and reported millisecond mismatch')
    count=count+1
    if first then first=.false
    else do
      if pts<=oldPts | ix<=oldIx then raise syntax 88.900 array('raw PTS/index nonmonotone')
      stepStart=1000*oldPts*num/den
      gap=actualMs-stepStart
      /* Long gaps, unstable states and epoch crossings are not interpolated
       * as authoritative motion. The window records their invalid coverage. */
      valid=(gap<=250 & state=='STABLE' & oldState=='STABLE' & epoch==oldEpoch)
      do w over windows
        emitted=emitted+w~add(stepStart,actualMs,valid,epoch,state,gap, -
          f[14],f[15],f[16],f[17],f[18],f[19],output)
      end
    end
    oldPts=pts;oldIx=ix;oldEpoch=epoch;oldState=state
  end
  input~close
  if count<>expected then raise syntax 88.900 array('raw count differs from source run',count)
  if oldPts<>lastPts then raise syntax 88.900 array('final PTS conflicts with source run')
  if abs(1000*oldPts*num/den-lastMs)>1.01 then raise syntax 88.900 array('source run end timestamp conflict')
  /* Preserve trailing partial observed intervals. */
  do w over windows
    emitted=emitted+w~finish(output)
  end
  output~close
  /* SysFileMove does not overwrite existing POSIX files. Back up an earlier
   * complete view, promote the validated staging file, then drop the backup. */
  backupPath=outputPath||'.BEFORE_REPLACE'
  hadPrevious=(stream(outputPath,'C','QUERY EXISTS')\=='')
  if hadPrevious then do
    if stream(backupPath,'C','QUERY EXISTS')\=='' then raise syntax 88.900 array('unresolved output backup',backupPath)
    if SysFileMove(outputPath,backupPath)<>0 then raise syntax 88.900 array('previous view backup failed',outputPath)
  end
  if SysFileMove(stagePath,outputPath)<>0 then do
    if hadPrevious then call SysFileMove backupPath,outputPath
    raise syntax 88.900 array('view promotion failed; incomplete staging retained',stagePath)
  end
  if hadPrevious then call SysFileDelete backupPath
  return emitted

::class SpashVisualAccumulator public
::method init
  expose width source slot initialized steps covered validMs dx dy leftR rightR gtravel dtravel peak gapmax epoch mixed bad
  use strict arg width,source
  slot=0;initialized=.false
  self~reset
::method reset private
  expose steps covered validMs dx dy leftR rightR gtravel dtravel peak gapmax epoch mixed bad
  steps=0;covered=0;validMs=0;dx=0;dy=0;leftR=0;rightR=0;gtravel=0;dtravel=0;peak=0;gapmax=0;epoch='';mixed=.false;bad=.false
::method add
  expose width source slot initialized steps covered validMs dx dy leftR rightR gtravel dtravel peak gapmax epoch mixed bad
  use strict arg lo,hi,valid,newEpoch,newState,gap,gx,gy,dl,dr,gm,dm,output
  produced=0
  if hi<=lo then raise syntax 88.900 array('invalid PTS interval')
  do while lo<hi
    newSlot=trunc(lo/width)
    if \initialized then do
      initialized=.true;slot=newSlot
    end
    if newSlot<>slot then do
      produced=produced+self~emit(output)
      self~reset;slot=newSlot
    end
    edge=(slot+1)*width
    stop=min(edge,hi)
    dt=stop-lo
    covered=covered+dt;steps=steps+1
    if epoch=='' then epoch=newEpoch
    else if epoch\==newEpoch then mixed=.true
    if \valid | newState\=='STABLE' then bad=.true
    if valid then do
      validMs=validMs+dt
      fraction=dt/gap
      dx=dx+gx*fraction;dy=dy+gy*fraction
      leftR=leftR+dl*fraction;rightR=rightR+dr*fraction
      gtravel=gtravel+gm*fraction;dtravel=dtravel+dm*fraction
      peak=max(peak,dm)
    end
    gapmax=max(gapmax,gap)
    lo=stop
    if lo=edge then do
      produced=produced+self~emit(output)
      self~reset
      slot=slot+1
    end
  end
  return produced
::method finish
  expose steps
  use strict arg output
  if steps=0 then return 0
  answer=self~emit(output)
  self~reset
  return answer
::method emit private
  expose width source slot steps covered validMs dx dy leftR rightR gtravel dtravel peak gapmax epoch mixed bad
  use strict arg output
  if steps=0 then return 0
  tab='09'x
  start=slot*width;finish=start+width
  geometry='STABLE'
  if mixed then geometry='MIXED_EPOCH'
  if bad then geometry='UNSTABLE_OR_GAP'
  status='VALID_RAW_PTS_WINDOW'
  if covered<width-.01 then status='PARTIAL_COVERAGE'
  else if geometry\=='STABLE' | validMs<width-.01 then status='INVALID_GEOMETRY_OR_GAP'
  sec=width/1000
  /* Invalid/partial rows survive as evidence, never as selected stable strata. */
  row='spash.visual.raw-window/0.2'||tab||source||tab||width||tab||start||tab||finish||tab||steps||tab||covered||tab||validMs||tab||epoch||tab||geometry||tab||gtravel/sec||tab||dtravel/sec||tab||max(0,(dtravel-gtravel)/sec)||tab||dx/sec||tab||dy/sec||tab||leftR/sec||tab||rightR/sec||tab||peak||tab||gapmax||tab||'NOT_ALIGNED'||tab||status
  output~lineout(row)
  return 1