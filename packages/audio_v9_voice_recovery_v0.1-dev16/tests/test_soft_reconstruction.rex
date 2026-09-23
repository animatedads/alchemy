numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
policy=.AudioV9SoftReconstructionPolicy~new(.06,.92,32,0,.15,.35,7,3)
quiet=measurement(.004,.0035,.018,.016,4.5,4.6,0,120,.7,.8)
r1=policy~planRow(0,32000,quiet)
call assert r1~weightA=.5 & r1~weightB=.5,'strong coherent evidence uses balanced spatial fusion'
call assert r1~gain>1,'quiet coherent material receives recovery gain'
call assert r1~gain<=.92/(.5*.018+.5*.016)+1E-8,'planned gain obeys peak guard'

weak=measurement(.002,.006,.01,.025,5,4,0,120,.05,.1)
r2=policy~planRow(32000,64000,weak,.nil,r1~gain)
call assert r2~weightB>r2~weightA,'low coherence selects stronger feed softly'
step=dbGain(3)
call assert r2~gain<=r1~gain*step+1E-8 & r2~gain>=r1~gain/step-1E-8,'gain trajectory changes by at most configured step'

bang=measurement(.001,.001,.8,.7,800,700,0,120,.4,.7)
r3=policy~planRow(64000,96000,bang,.nil,r2~gain)
call assert r3~reason~pos('IMPULSE_HOLD_GAIN')>0,'impulse holds whisper gain trajectory'
call assert (.5*.8+.5*.7)*r3~gain<=.920001,'current impulse is still peak guarded'

alarm=.AudioV9SourceFamilyEvidence~new(.1,.95,.1,.05,.1)
r4=policy~planRow(96000,128000,quiet,alarm,r3~gain)
call assert r4~reason~pos('ALARM_EVIDENCE')>0,'coarse alarm family annotates reconstruction'
call assert r4~gain>0,'coarse source class cannot hard mute possible speech'

provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
a=root||'/run/test/a120.f32'; b=root||'/run/test/b120.f32'
scan=provider~scan(a,b,8000,8000,4000,500,25)
plan=.AudioV9SoftReconstructionPlanner~new(policy)~fromScan(scan,96000)
call assert plan~items=2,'12 second fixture makes complete two-row soft plan'
call assert plan~rows[1]~startSample=0 & plan~rows[plan~items]~endSample=96000,'plan covers exact input sample geometry'
pp=root||'/run/test/reconstruction.tsv'; out=root||'/run/test/reconstruction.f32'
plan~write(pp); provider~renderPlan(a,b,pp,out,800)
call assert stream(out,'C','QUERY SIZE')=96000*4,'native soft renderer preserves exact sample count'

say 'PASS test_soft_reconstruction assertions=12'
exit 0

measurement: procedure
  use strict arg rmsA,rmsB,peakA,peakB,crestA,crestB,ratio,lagMs,coh,score
  lag=trunc(lagMs*8)
  t='AUDIO_V9_SPATIAL/2'||'09'x||'SAMPLES=64000'||'09'x||'SR=8000'||'09'x||'RMS_A='||rmsA||'09'x||'RMS_B='||rmsB||'09'x||'PEAK_A='||peakA||'09'x||'PEAK_B='||peakB||'09'x||'CREST_A='||crestA||'09'x||'CREST_B='||crestB||'09'x||'RATIO_DB='||ratio||'09'x||'ENV_LAG_SAMPLES='||lag||'09'x||'ENV_LAG_MS='||lagMs||'09'x||'ENV_SCORE=.7'||'09'x||'DIRECT_LAG_SAMPLES=8'||'09'x||'DIRECT_LAG_MS=1'||'09'x||'DIRECT_SCORE=.2'||'09'x||'DIRECT_COHERENCE=.1'||'09'x||'REFINED_LAG_SAMPLES='||lag||'09'x||'REFINED_LAG_MS='||lagMs||'09'x||'REFINED_SCORE='||score||'09'x||'REFINED_COHERENCE='||coh
  return .AudioV9SpatialMeasurement~new(t)

dbGain: procedure
  use strict arg db
  /* sufficient only for the 3 dB assertion bound */
  if db=3 then return 1.4125375446227544
  return 1

assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return

::requires 'AudioV9SoftReconstruction.cls'
