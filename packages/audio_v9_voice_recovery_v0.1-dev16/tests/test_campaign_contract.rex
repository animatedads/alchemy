numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
c=.AudioV9VoiceCampaign~load(root||'/campaign/CAMPAIGN.tsv',root||'/campaign/WORKERS.tsv')
call assert c~workers~items=7,'seven workers'
call assert c~end-c~start=64800,'18 hour campaign'
call assert c~setting('expected_total_files')=120,'120 corpus files'
call assert c~setting('expected_total_bytes')='4292920762','corpus byte contract'
ws=c~workers
call assert ws[1]~worker='ed209a','first worker'
call assert ws[7]~worker='ed209i','last worker'
call assert ws[1]~coreStartText='2023-10-09 21:00:00','campaign start'
call assert ws[7]~coreEndText='2023-10-10 15:00:00','campaign end'
fc=.AudioV9SourceList~fromFile('fc',root||'/campaign/FC_FILES.txt')
fd=.AudioV9SourceList~fromFile('fd',root||'/campaign/FD_FILES.txt')
call assert fc~size=95,'FC file count'
call assert fd~size=25,'FD file count'
call assert fc~sourceFor(c~start)='20231009_202339_tp00002_original.ogg','FC 21:00 source'
call assert fd~sourceFor(c~start)='20231009_201239_tp00025_original.ogg','FD 21:00 source'
call assert fc~sourceFor(c~end-1)='20231010_143200_tp00034_original.ogg','FC 14:59:59 source'
call assert fd~sourceFor(c~end-1)='20231010_144510_tp00009_original.ogg','FD 14:59:59 source'
fa=fc~slices(ws[1]~analysisStart,ws[1]~analysisEnd,ws[1]~coreStart,ws[1]~coreEnd)
fda=fd~slices(ws[1]~analysisStart,ws[1]~analysisEnd,ws[1]~coreStart,ws[1]~coreEnd)
call assert fa[1]~sliceStart=ws[1]~analysisStart,'FC halo start covered'
call assert fa[fa~items]~sliceEnd=ws[1]~analysisEnd,'FC halo end covered'
call assert fda[1]~sliceStart=ws[1]~analysisStart,'FD halo start covered'
call assert fda[fda~items]~sliceEnd=ws[1]~analysisEnd,'FD halo end covered'
say 'PASS test_campaign_contract assertions=16'
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return
::requires "AudioV9VoiceCampaign.cls"
