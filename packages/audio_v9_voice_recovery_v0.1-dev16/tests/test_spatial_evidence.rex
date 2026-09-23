numeric digits 30
obs=.array~new
vals=.array~of(80,80,80,140,140,140)
do i=1 to vals~items
  d=.directory~new; d['id']='D'||i; d['lag_ms']=vals[i]; obs~append(d)
end
analysis=.AudioV9DelayTrackAnalyzer~new(0.01,3,1000)~analyze(obs)
call assert analysis~distanceToFit=3,'distance to coherent delay track'
call assert analysis~restoringSets~items=2,'two minimal coherent tracks'
parts=analysis~participation~toArray
call assert parts~items=6,'six participation rows'
do p over parts; call assert abs(p~fraction-0.5)<0.0000001,'balanced participation'; end
policy=.AudioV9SpeechPreservationPolicy~new
u=.AudioV9VoiceEvidence~new
call assert policy~disposition(u)='PRESERVE_UNCERTAIN|UNCERTAIN','uncertain evidence preserved'
a=.AudioV9VoiceEvidence~new; a~put('alarm',0.99); a~put('human_voice',0.05)
call assert policy~disposition(a)='SUPPRESS|ALARM','strong alarm may suppress'
i=.AudioV9VoiceEvidence~new; i~put('impulse',0.99); i~put('human_voice',0.1)
call assert policy~disposition(i)='PRESERVE_IMPAIRED|IMPULSE','impulse is not deletion authority'
h=.AudioV9VoiceEvidence~new; h~put('human_voice',0.4); h~put('animal',0.5)
call assert policy~disposition(h)='PRESERVE|HUMAN_VOICE','human protection wins below hard-negative threshold'
say 'PASS test_spatial_evidence assertions=13'
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return
::requires "AudioV9SpatialEvidence.cls"
