numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
tracker=.AudioV9WhisperGainTracker~new(.06,36,3)
policy=.AudioV9ReflectionAwareWhisperPolicy~new(.45,.35,.35)

quiet=measurement(.002,.0024,.009,.010,3,3,8,.82,.62)
empty=.array~new
r1=policy~planWindow(0,16000,quiet,empty,tracker,.nil)
call ok r1~gain>1,'quiet whisper receives positive gain'
call ok r1~referenceRms\==.nil,'quiet whisper establishes reference rms'
ref1=r1~referenceRms; gain1=r1~gain
call near r1~weightSum,1,1E-12,'quiet contribution weights normalize'
call ok \r1~loudIsolated,'quiet row is not loud-isolated'

/* Passing vehicle makes FD much louder while an audio-observed transient
 * reflection appears. This may improve the usable path but must not reset the
 * source-level gain reference. */
boosted=measurement(.0022,.018,.012,.090,3,4,11,.91,.70)
a=.AudioV9PropagationObservation~new('P1',17000,19500,'SRC_WHISPER','FD','TRANSIENT_REFLECTION',96,8.5,.90,0,'',0,'AUDIO_ECHO')
v=.AudioV9VideoReflectorObservation~new('VEHICLE_1',16800,19800,.95,'VIDEO_TRACK')
c=.AudioV9PropagationCorrelator~new~corroborate(a,.array~of(v))
call ok c~audioScore=.90,'video correlation does not alter audio score'
call ok c~authority='AUDIO_PLUS_VIDEO','vehicle geometry corroborates existing audio path'
r2=policy~planWindow(16000,32000,boosted,.array~of(c),tracker,gain1)
call near r2~referenceRms,ref1,1E-15,'transient reflective gain does not reset whisper reference'
call ok r2~transientReflection,'transient reflection marked explicitly'
call ok r2~reason~pos('ECHO_CORROBORATION')>0,'reflection contributes as corroborating echo evidence'
call near r2~weightSum,1,1E-12,'reflection contribution weights normalize'
call ok reflectionWeight(r2)<=.35+1E-12,'reflection contribution is bounded'

/* A visually plausible vehicle with weak acoustic match cannot manufacture an
 * acoustic path. */
weak=.AudioV9PropagationObservation~new('P2',17000,19500,'SRC_WHISPER','FD','TRANSIENT_REFLECTION',112,9,.20,0,'',0,'AUDIO_WEAK')
weakc=.AudioV9PropagationCorrelator~new~corroborate(weak,.array~of(v))
call ok weakc~authority='VISUAL_ONLY_CANDIDATE','visual-only correlation remains non-authoritative'
call ok \weakc~audioEligible(.45),'visual evidence cannot pass audio gate'
r2b=policy~planWindow(16000,32000,boosted,.array~of(weakc),tracker,r2~gain)
call ok reflectionWeight(r2b)=0,'visual-only candidate is excluded from fusion'

/* A bang/loud probe is kept out of whisper gain tracking. */
loud=measurement(.030,.050,.85,.92,12,10,7,.70,.50)
lp=.AudioV9PropagationObservation~new('BANG1',33000,34000,'SRC_WHISPER','FC_FD','STATIC_REFLECTION',72,0,.88,0,'',1,'LOUD_ECHO')
refBefore=tracker~referenceRms
r3=policy~planWindow(32000,48000,loud,.array~of(lp),tracker,r2~gain)
call ok r3~loudIsolated,'loud probe is assigned to separate stem'
call near tracker~referenceRms,refBefore,1E-15,'loud probe does not reset whisper reference'
call ok r3~reason~pos('LOUD_PROBE_SEPARATE_STEM')>0,'separate loud-stem reason is explicit'
call near r3~weightSum,1,1E-12,'loud-row contribution weights normalize'

/* Static audio-only echo remains useful without requiring video. */
static=.AudioV9PropagationObservation~new('S1',49000,52000,'SRC_WHISPER','FD','STATIC_REFLECTION',144,3.2,.78,0,'',0,'AUDIO_ECHO')
call ok static~authority='AUDIO_ONLY','audio reflection can stand without video'
r4=policy~planWindow(48000,64000,quiet,.array~of(static),tracker,r3~gain)
call ok reflectionWeight(r4)>0,'audio-only compatible echo contributes'
call near r4~weightSum,1,1E-12,'static reflection weights normalize'

say 'PASS reflection-aware reconstruction assertions=20 gain='||r4~gain||' reference_rms='||tracker~referenceRms||' reflection_weight='||reflectionWeight(r4)
exit 0

measurement: procedure
  use strict arg ra,rb,pa,pb,ca,cb,lag,score,coh
  t='AUDIO_V9_SPATIAL/2'||'09'x||'SAMPLES=16000'||'09'x||'SR=8000'||'09'x||'RMS_A='||ra||'09'x||'RMS_B='||rb||'09'x||'PEAK_A='||pa||'09'x||'PEAK_B='||pb||'09'x||'CREST_A='||ca||'09'x||'CREST_B='||cb||'09'x||'RATIO_DB=0'||'09'x||'ENV_LAG_SAMPLES='||lag||'09'x||'ENV_LAG_MS='||(lag/8)||'09'x||'ENV_SCORE='||score||'09'x||'DIRECT_LAG_SAMPLES='||lag||'09'x||'DIRECT_LAG_MS='||(lag/8)||'09'x||'DIRECT_SCORE='||score||'09'x||'DIRECT_COHERENCE='||coh||'09'x||'REFINED_LAG_SAMPLES='||lag||'09'x||'REFINED_LAG_MS='||(lag/8)||'09'x||'REFINED_SCORE='||score||'09'x||'REFINED_COHERENCE='||coh
  return .AudioV9SpatialMeasurement~new(t)
reflectionWeight: procedure
  use strict arg row
  x=0; do c over row~contributions; if c~pathKind\='DIRECT' then x=x+c~weight; end; return x
near: procedure
  use strict arg actual,expected,tolerance,label
  if abs((actual+0)-(expected+0))<=tolerance then return
  say 'FAIL 'label' actual='actual' expected='expected
  exit 1
ok: procedure
  use strict arg condition,label
  if condition then return
  say 'FAIL 'label
  exit 1
::requires 'AudioV9PropagationReconstruction.cls'
