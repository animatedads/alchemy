numeric digits 30
pass=0
call t_family_budget
call t_conservative_diarizer
say 'PASS calibration bounded acoustic assertions='pass
exit 0

t_family_budget:
  tracks=.array~new
  do i=1 to 8
    tracks~append(.AudioV9TrackSummary~new('T'||i,'L'||i,'FIX','FC',i*1000,i*1000+500,3,1,1,.5,2,.7,3,10,0,1000))
  end
  caught=.false
  signal on syntax name family_budget_hit
  x=.AudioV9SourceFamilyClusterer~new(28,120)~cluster(tracks,3)
  signal off syntax
  call ok .false,'family comparison budget must stop pathological clustering'
  return
family_budget_hit:
  signal off syntax
  caught=.true
  d=condition('D')
  call ok caught,'family comparison budget raises fail-closed condition'
  return

t_conservative_diarizer:
  fam=.array~new
  do i=1 to 5
    t=.AudioV9TrackSummary~new('V'||i,'L'||i,'FIX','FC',i*1000,i*1000+500,3,1,1,.8,2,.8,2,5,0,800+i)
    e=.AudioV9SourceFamilyEvidence~new(.9,.1,.1,.1,.8)
    fam~append(.AudioV9SourceFamily~new('F'||i,.array~of(t),e,'UNLABELLED'))
  end
  sp=.AudioV9CalibrationDiarizer~new~cluster(fam,.45,3)
  call ok sp~items=1,'overflow collapses voice-like families to one speaker'
  call ok sp[1]~id='SPEAKER_CALIBRATION_OVERFLOW','overflow speaker id explicit'
  call ok sp[1]~families~items=5,'overflow preserves every voice-like family in conservative group'
  return

ok: procedure expose pass
  use arg condition,label
  if condition then do; pass=pass+1; return; end
  say 'FAIL 'label
  exit 1

::requires 'AudioV9CalibrationAcoustic.cls'
::requires 'AudioV9AcousticCoordinator.cls'
