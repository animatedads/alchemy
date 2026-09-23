numeric digits 30
parse arg workerName chunkSeconds
if workerName='' then do; say 'usage: plan_worker_chunks.rex WORKER [CHUNK_SECONDS]'; exit 2; end
if chunkSeconds='' then chunkSeconds=60
chunkSeconds=chunkSeconds+0
if chunkSeconds<8 | chunkSeconds\=trunc(chunkSeconds) then do; say 'FAIL chunk seconds must be integer >= 8'; exit 2; end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
c=.AudioV9VoiceCampaign~load(root||'/campaign/CAMPAIGN.tsv',root||'/campaign/WORKERS.tsv')
w=c~worker(workerName)
chunkStart=c~start
do while chunkStart>w~analysisStart; chunkStart=chunkStart-chunkSeconds; end
do while chunkStart+chunkSeconds<=w~analysisStart; chunkStart=chunkStart+chunkSeconds; end
say 'chunk'||'09'x||'start_serial'||'09'x||'end_serial'||'09'x||'analysis_start'||'09'x||'analysis_end'||'09'x||'core_start'||'09'x||'core_end'
i=0
do while chunkStart<w~analysisEnd
  i=i+1; chunkEnd=chunkStart+chunkSeconds
  say i||'09'x||chunkStart||'09'x||chunkEnd||'09'x||w~analysisStart||'09'x||w~analysisEnd||'09'x||w~coreStart||'09'x||w~coreEnd
  chunkStart=chunkEnd
end
exit 0
::requires 'AudioV9VoiceCampaign.cls'
