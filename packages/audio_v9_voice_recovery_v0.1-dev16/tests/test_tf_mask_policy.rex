numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
assertions=0
call check .true,'start'
policy=.AudioV9TfMaskPolicy~new
voice=.AudioV9SourceFamily~new('V',.array~new,.AudioV9SourceFamilyEvidence~new(.8,.1,.1,.1,.5),'VOICE')
alarm=.AudioV9SourceFamily~new('A',.array~new,.AudioV9SourceFamilyEvidence~new(.1,.95,.1,.1,.1),'ALARM')
cat=.AudioV9SourceFamily~new('C',.array~new,.AudioV9SourceFamilyEvidence~new(.15,.1,.1,.1,.8),'CAT')
unc=.AudioV9SourceFamily~new('U',.array~new,.AudioV9SourceFamilyEvidence~new(.35,.35,.35,.35,.40),'UNLABELLED')
vd=policy~decision(voice,'SPEAKER_0001'); call check vd['protect'],'speaker protects'; call check vd['gain']>1,'speaker boost'
ad=policy~decision(alarm); call check \ad['protect'],'alarm may attenuate'; call check ad['gain']<1,'alarm attenuation'
cd=policy~decision(cat); call check \cd['protect'],'cat may attenuate'; call check cd['gain']<1,'cat attenuation'
ud=policy~decision(unc); call check ud['protect'],'uncertain preserved'; call check ud['gain']=1,'uncertain unity'
plan=.AudioV9TfMaskPlan~new
plan~append(.AudioV9TfMaskRow~new(800,1600,2000,2400,.5,.false,.9,'A','','ALARM'))
plan~append(.AudioV9TfMaskRow~new(0,800,300,500,1.2,.true,.8,'V','SPEAKER_0001','VOICE'))
plan~sort; r=plan~rows; call check r[1]~startSample=0,'deterministic sort'; call check r[2]~startSample=800,'deterministic sort 2'
say 'PASS test_tf_mask_policy assertions='||assertions
exit 0
check: procedure expose assertions
  parse arg cond,msg
  assertions=assertions+1
  if \cond then do; say 'FAIL '||msg; exit 1; end
  return
::requires 'AudioV9TimeFrequencyReconstruction.cls'
