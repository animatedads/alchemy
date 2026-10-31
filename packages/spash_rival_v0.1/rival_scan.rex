/* Real Audio V9 measured spectral tracks, no waveform processing in this file. */
parse arg sourceTracks originalRefId originalSha eventsPath
if sourceTracks='' | originalRefId='' | originalSha='' then do
  say 'usage: rexx rival_scan.rex AudioV9Tracks.tsv StorageRefID OriginalSHA256 [VideoEvents.tsv]'
  exit 2
end
ref=.StorageRef~new(originalRefId,originalSha)
frames=.SpashRivalTsvReader~new~read(sourceTracks,ref)
if frames~items<2 then do
  say 'NOT_APPLICABLE insufficient measured Audio V9 spectral tracks'
  exit 3
end
comp=.SpashRivalCompetition~new
ranks=comp~evaluate(frames,8)
say 'SCHEMA spash.rival.strategy-results/0.1'
say 'FRAMES' frames~items
say 'TRIALS' ranks['TRIALS']
say 'STRATEGIES_FIVE WINDOWS_FIVE GUARDS_FOUR'
say 'STRATEGY_ID MERIT SELECTED_ROWS COVERAGE CONTINUITY CONFOUND_VETOES'
do r over ranks['TOP']
  say r['STRATEGY_ID'] r['MERIT'] r['SELECTED_ROWS'] r['COVERAGE'] r['CONTINUITY'] r['CONFOUND_VETO_COUNT']
end
winner=ranks['TOP'][1]['STRATEGY_ID']
config=.nil
do s over comp~configurations
  if s~id==winner then do;config=s;leave;end
end
intervals=.SpashRivalIntervalSelector~new~select(frames,config,20)
say 'SELECTED_INTERVAlS' intervals~items 'LABELS=ACOUSTIC_CANDIDATE_ONLY'
do i over intervals
  say 'INTERVAL' i['FEED'] i['TRAJECTORY_ID'] i['START_MS'] i['END_MS'] i['FRAMES']
end
if eventsPath\='' then do
  ev=.SpashRivalEventLedger~new~read(eventsPath)
  say 'VIDEO_EVENT_STRATA' ev~items 'CLOCK_ALIGNMENT=UNKNOWN_ONLY_CONTEXT'
end
shards=.SpashRivalMUSharder~new~plan(comp~configurations,10)
do s over shards
  say 'ESTATE_PLAN' s['SLOT'] s['STRATEGIES']~items s['STATUS']
end
say 'SPEECH_RECOGNITION_NOT_CLAIMED'
say 'VIRTUAL_MICROPHONE_NOT_NEW_PHYSICAL_CHANNEL'
exit 0
::requires 'SpashChallenger.cls'
