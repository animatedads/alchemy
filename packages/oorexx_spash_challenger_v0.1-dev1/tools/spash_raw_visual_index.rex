/* SPASH raw video PTS layer: time-resolved signed and absolute motion.
 * No audio processing, semantic event classification, or clock synchronization.
 */
parse arg samplesPath runPath outputPath widthMs
if samplesPath=='' | runPath=='' | outputPath=='' then do
  say 'usage: rexx tools/spash_raw_visual_index.rex samples.tsv run.tsv out.tsv [window_ms]'
  exit 2
end
if widthMs=='' then widthMs=1000
if \datatype(widthMs,'W') then do;say 'ERROR window must be integer ms';exit 2;end
if widthMs<60 | widthMs>30000 then do;say 'ERROR window out of bounds';exit 2;end
obj=.SpashRawMotionClock~new
count=obj~load(samplesPath,runPath)
profile=obj~cadence
say 'RAW_VIDEO_PTS SOURCE='obj~sourceFile 'SAMPLES='count
say 'CADENCE_MEAN_MS='profile['MEAN_MS'] 'RATE_HZ='profile['MEAN_RATE_HZ']
say 'SIXTY_MS_STEPS='profile['NEAR_60MS'] 'ONE_TWENTY_MS_STEPS='profile['NEAR_120MS']
call lineout outputPath,'schema' || '09'x || 'source_file' || '09'x || 'start_ms' || '09'x || 'end_ms' || '09'x || 'raw_steps' || '09'x || 'covered_ms' || '09'x || 'epoch' || '09'x || 'geometry' || '09'x || 'global_travel_px_per_sec' || '09'x || 'door_travel_px_per_sec' || '09'x || 'global_dx_px_per_sec' || '09'x || 'global_dy_px_per_sec' || '09'x || 'door_left_residual_px_per_sec' || '09'x || 'door_right_residual_px_per_sec' || '09'x || 'max_raw_step_ms' || '09'x || 'audio_clock_authority'
tab='09'x
windowCount=0
start=trunc((obj~firstMs+widthMs-1)/widthMs)*widthMs
do while start+widthMs<=obj~lastMs
  w=obj~window(start,start+widthMs)
  if w['STATUS']=='RAW_WINDOW_MEASURED' then do
    row=w['SCHEMA']||tab||w['SOURCE_FILE']||tab||start||tab||(start+widthMs)||tab||w['RAW_STEPS']||tab||w['COVERED_MS']||tab||w['EPOCH_ID']||tab||w['GEOMETRY_STATUS']||tab||w['GLOBAL_TRAVEL_PX_PER_SECOND']||tab||w['DOOR_TRAVEL_PX_PER_SECOND']||tab||w['GLOBAL_DX_PX_PER_SECOND']||tab||w['GLOBAL_DY_PX_PER_SECOND']||tab||w['DOOR_LEFT_RESIDUAL_PX_PER_SECOND']||tab||w['DOOR_RIGHT_RESIDUAL_PX_PER_SECOND']||tab||w['MAX_RAW_STEP_MS']||tab||w['AUDIO_CLOCK_AUTHORITY']
    call lineout outputPath,row
    windowCount=windowCount+1
  end
  start=start+widthMs
end
call stream outputPath,'C','CLOSE'
say 'RAW_PTS_INDEX_PASS WINDOWS='windowCount 'OUTPUT='outputPath
exit 0
::requires 'SpashRawMotionClock.cls'
