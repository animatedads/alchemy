numeric digits 30
parse arg workersRoot outPath
if workersRoot='' | outPath='' then do
  say 'usage: merge_spatial_workers.rex WORKERS_ROOT OUT.tsv'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
c=.AudioV9VoiceCampaign~load(root||'/campaign/CAMPAIGN.tsv',root||'/campaign/WORKERS.tsv')
coordinator=.AudioV9SpatialCoordinator~new
count=coordinator~mergeWorkers(c,workersRoot,outPath)
say 'PASS spatial coordinator rows='||count||' out='||outPath
exit 0
::requires 'AudioV9VoiceCampaign.cls'
::requires 'AudioV9SpatialCoordinator.cls'
