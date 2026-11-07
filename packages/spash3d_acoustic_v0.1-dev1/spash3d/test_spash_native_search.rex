/* test_spash_native_search.rex -- SPASH example search in ooRexx on native band blocks.
 * Control: POI1 copied into silence/noise at a known offset must be found there; unrelated noise must not match.
 * Coding: Claude (Opus 5.5). */
numeric digits 16
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
p=.AudioV9SpatialNativeProvider~new(root'/run/native/av9_spatial.bridge.json')
poi='/home/claude/work/pcm/poi1.f32'
q=.SpashAudioBlocks~observe(p,poi,'POI1')
say 'POI1 blocks' q['OBS']~items
tmpl=.SpashAudioBlocks~activeTemplate(q,6)
/* build a test corpus: 4 s of TP28 background, then POI1 * 0.3, then 3 s background */
fc=.stream~new('/home/claude/work/pcm/tp28.f32'); fc~open('READ')
bg=fc~charin(600*8000*4+1,7*8000*4); fc~close
pq=.stream~new(poi); pq~open('READ'); ps=pq~charin(1,stream(poi,'C','QUERY SIZE')); pq~close
corp='/tmp/spash_corpus.f32'; call sysFileDelete corp
o=.stream~new(corp); o~open('WRITE REPLACE'); o~charout(bg~substr(1,4*8000*4)); o~charout(ps); o~charout(bg~substr(4*8000*4+1)); o~close
c=.SpashAudioBlocks~observe(p,corp,'CORPUS')
s=.SpashExampleSearch~new(0.70,0.20)
res=s~find(tmpl,c['OBS'],5)
expectMs=4000+tmpl[1]~startMs
say 'template starts in POI1 at' tmpl[1]~startMs 'ms; expected in corpus at' expectMs 'ms'
hit=.false
do r over res
  say '  match' r~at('MATCH_START_MS') 'ms likeness' format(r~at('LIKENESS'),,3)
  if abs(r~at('MATCH_START_MS')-expectMs)<=160 then hit=.true
end
if \hit then do; say 'FAIL planted POI1 not found'; exit 1; end
/* negative control: background only */
nb='/tmp/spash_bg.f32'; call sysFileDelete nb
o=.stream~new(nb); o~open('WRITE REPLACE'); o~charout(bg); o~close
c2=.SpashAudioBlocks~observe(p,nb,'BG')
res2=s~find(tmpl,c2['OBS'],5)
top=0; if res2~items>0 then top=res2[1]~at('LIKENESS')
say 'background-only top likeness' format(top,,3) 'results' res2~items
say 'PASS test_spash_native_search planted_found=1 background_top='format(top,,3)
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'SpashAudioBlocks.cls'
::requires 'SpashExampleSearch.cls'
