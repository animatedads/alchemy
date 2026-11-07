/* call_search.rex -- SPASH query-by-example within the recording: labelled broken-call speech -> similar FD segments.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Query: the most active 6 SPASH blocks (~1 s) of the labelled window. Corpus: FD chain [start, start+dur).
 * Excludes +-10 s around the query itself. Output: top N non-overlapping matches (FD clock).
 * usage: call_search.rex queryF32 startHMS durSec outTsv [topN]
 */
numeric digits 16
parse arg qF startT dur outF topN .
if topN='' then topN=15
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
q=.SpashAudioBlocks~observe(prov,qF,'QUERY'); tmpl=.SpashAudioBlocks~activeTemplate(q,6)
t0=hms2sec(startT~left(8)); corp=value('SPASH_WORK',,'ENVIRONMENT')'/call_corpus.f32'
ch['FD']~writeWindow(t0,dur*8000,corp)
c=.SpashAudioBlocks~observe(prov,corp,'FD')
srch=.SpashExampleSearch~new(0,0.20)
res=srch~find(tmpl,c['OBS'],topN*3)
o=.stream~new(outF); o~open('WRITE REPLACE'); o~lineout('rank'||'09'x||'fd_time'||'09'x||'likeness')
k=0
do r over res
  t=t0+r~at('MATCH_START_MS')/1000
  if abs(t-hms2sec('122142'))<10 then iterate
  k+=1; o~lineout(k'09'x||sec2hms(t)'09'x||format(r~at('LIKENESS'),,3)); say k sec2hms(t) format(r~at('LIKENESS'),,3)
  if k>=topN then leave
end
o~close
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'SpashAudioBlocks.cls'
::requires 'SpashExampleSearch.cls'
