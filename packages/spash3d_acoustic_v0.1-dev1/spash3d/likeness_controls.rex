/* likeness_controls.rex -- what does SPASH POI1 likeness score for things that are NOT voice?
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Each view: unfiltered, and Tom's chain (+24 dB float gain, then speech-band 300-3400 Hz native band selection).
 * Gain is applied for the record; SPASH band shapes are normalised so gain alone cannot change the score.
 * usage: likeness_controls.rex workDir view1.f32 [view2.f32 ...]   (labels = file names)
 */
numeric digits 16
parse arg workDir rest
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
q=.SpashAudioBlocks~observe(prov,value('SPASH_PCM',,'ENVIRONMENT')'/poi1.f32','POI1'); tmpl=.SpashAudioBlocks~activeTemplate(q,6)
srch=.SpashExampleSearch~new(0,0.20)
say left('view',34) 'unfiltered' ' +24dB+speech-band'
do f over rest~space~makeArray(' ')
  u=top(prov,srch,tmpl,f)
  g=workDir'/ctl_gain.f32'; x=prov~renderAlignedMix(f,f,g,0,'7.943282347','7.943282347')   /* 2 x 7.943 x 0.5 weighting = +24 dB */
  n=stream(f,'C','QUERY SIZE')%4
  mask=workDir'/ctl_speech.mask.tsv'
  m=.stream~new(mask); m~open('WRITE REPLACE'); m~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); m~lineout('0'||'09'x||n||'09'x||'300'||'09'x||'3400'||'09'x||'1'); m~close
  fl=workDir'/ctl_filt.f32'; x=prov~renderSelection(g,mask,fl,8000,256,64)
  v=top(prov,srch,tmpl,fl)
  say left(filespec('name',f),34) format(u,,3) '      ' format(v,,3)
end
exit 0
top: procedure
  use arg prov, srch, tmpl, f
  c=.SpashAudioBlocks~observe(prov,f,'V')
  r=srch~find(tmpl,c['OBS'],1)
  if r~items=0 then return 0
  return r[1]~at('LIKENESS')
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'SpashAudioBlocks.cls'
::requires 'SpashExampleSearch.cls'
