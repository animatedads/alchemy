numeric digits 30
schema=.AudioV9AcousticCharacterSchema~new
m=measurement(0.02,0.018,0.18,0.17,3.2,3.1,1.0,120,.62)
b1=box(0,250,5,420,-68,2.0,2.4,.62,5.1)
b2=box(0,250,5,420,-38,2.0,2.4,.62,5.1)
c1=.AudioV9BoxCharacter~new('C1',1000,'FC',b1,m)
c2=.AudioV9BoxCharacter~new('C2',9000,'FC',b2,m)
d=schema~difference(c1,c2)
call assert d~exact,'acoustic character ignores absolute baseline/gain'

/* Two separated occurrences with the same movement trajectory should remain compatible. */
a=.array~new; b=.array~new
motion=.array~of(1.7,2.2,1.9,2.5); turns=.array~of(1.3,2.0,1.6,2.4); active=.array~of(.42,.61,.50,.68)
do i=1 to 4
  bx=box((i-1)*250,i*250,5,420,-70,motion[i],turns[i],active[i],5.0+i*.1)
  by=box((i-1)*250,i*250,5,420,-42,motion[i]*1.02,turns[i]*.99,active[i],5.0+i*.1)
  a~append(.AudioV9BoxCharacter~new('A'||i,1000+(i-1)*250,'FC',bx,m))
  b~append(.AudioV9BoxCharacter~new('B'||i,11000+(i-1)*250,'FC',by,m))
end
ta=.AudioV9AcousticTrack~new('TA',a); tb=.AudioV9AcousticTrack~new('TB',b)
call assert ta~temporalHash\==.nil,'track obtains temporal ML hash'
cmp=.AudioV9SourceFamilyClusterer~new(32,160)
rel=cmp~compareTracks(ta,tb)
call assert rel~at('compatible'),'similar movement trajectories compatible across occurrence time'
fams=cmp~cluster(.array~of(tb,ta))
call assert fams~items=1,'similar occurrences become one acoustic family independent input order'
call assert fams[1]~tracks~items=2,'family retains both appearances'

/* Clearly different spectral/movement source must not collapse into that family. */
z=.array~new
do i=1 to 4
  bz=box((i-1)*250,i*250,24,2750,-30,10+i,14+i,.95,18)
  z~append(.AudioV9BoxCharacter~new('Z'||i,21000+(i-1)*250,'FD',bz,measurement(.08,.01,.7,.08,8.8,8,18,8,.05)))
end
tz=.AudioV9AcousticTrack~new('TZ',z)
fams2=cmp~cluster(.array~of(tb,tz,ta))
call assert fams2~items>=2,'large source disagreement remains separate'

/* Anonymous diarisation can merge acoustically compatible voice families, but never names a person. */
ev=.AudioV9SourceFamilyEvidence~new(.9,.05,.02,.02,.5)
fa=.AudioV9SourceFamily~new('F_A',.array~of(ta),ev)
fb=.AudioV9SourceFamily~new('F_B',.array~of(tb),ev)
speakers=.AudioV9AnonymousDiarizer~new(cmp)~cluster(.array~of(fb,fa),.45)
call assert speakers~items=1,'compatible recurring voice families diarise to one anonymous speaker'
call assert speakers[1]~families~items=2,'anonymous speaker retains both family sections'
call assert speakers[1]~id~left(8)='SPEAKER_','speaker identity is anonymous stable namespace'
/* Large absolute campaign epochs must not alter temporal identity or collapse event times. */
large=.array~new
do i=1 to 4
  bx=box((i-1)*250,i*250,5,420,-55,motion[i],turns[i],active[i],5.0+i*.1)
  large~append(.AudioV9BoxCharacter~new('L'||i,63832500000000+(i-1)*500,'FC',bx,m))
end
tl=.AudioV9AcousticTrack~new('TL',large)
call assert tl~temporalHash\==.nil,'track-relative temporal hash survives large absolute CCTV epoch'

/* One externally confirmed exemplar labels every compatible family appearance. */
proto=.AudioV9SourcePrototype~new('P_CAT_01','CAT',fa,'user-confirmed reference section')
pc=.AudioV9SourcePrototypeClassifier~new(cmp)
match=pc~bestMatch(fb,.array~of(proto))
call assert match\==.nil & match~label='CAT','compatible family inherits confirmed prototype label'
labelled=pc~classify(fb,.array~of(proto))
call assert labelled~label='CAT','prototype classification labels the whole recurring family'
far=.AudioV9SourceFamily~new('F_Z',.array~of(tz),.AudioV9SourceFamilyEvidence~new(.1,.1,.8,.1,.1))
call assert pc~bestMatch(far,.array~of(proto))==.nil,'incompatible family is not force-labelled from prototype'

/* Track builder may migrate between adjacent bands over time, never sideways at identical time. */
same1=.AudioV9BoxCharacter~new('S1',50000,'FC',box(0,250,8,800,-50,2,2,.5,5),m)
same2=.AudioV9BoxCharacter~new('S2',50000,'FC',box(0,250,9,950,-50,2,2,.5,5),m)
later=.AudioV9BoxCharacter~new('S3',50250,'FC',box(0,250,9,950,-50,2,2,.5,5),m)
tracks=.AudioV9TrackBuilder~new(schema,750,1,40)~build(.array~of(same1,same2,later))
call assert tracks~items=2,'same-time adjacent boxes do not become one temporal track'

say 'PASS test_acoustic_character assertions=15'
exit 0

box: procedure
  use strict arg startMs,endMs,band,center,baseline,motion,turn,active,width
  ps=.MLPatternHashSchema~new(.MLPatternHashPolicy~new(24,48,1,4,10,.false,.false),'AUDIO-V9-SPECTRAL-BOX/1')
  vals=.array~of(0,1,3,2,4,1,0,2)
  h=ps~encode(vals)
  return .AudioV9SpectralBoxEvidence~new(startMs,endMs,band,center-60,center+60,center,8,baseline,8,motion+1,motion,turn,active,width,h,h,'MIXED_BOX')

measurement: procedure
  use strict arg rmsA,rmsB,peakA,peakB,crestA,crestB,ratio,lagMs,coh
  sr=8000; lag=trunc(lagMs*sr/1000)
  t='AUDIO_V9_SPATIAL/2'||'09'x||'SAMPLES=64000'||'09'x||'SR=8000'||'09'x||'RMS_A='||rmsA||'09'x||'RMS_B='||rmsB||'09'x||'PEAK_A='||peakA||'09'x||'PEAK_B='||peakB||'09'x||'CREST_A='||crestA||'09'x||'CREST_B='||crestB||'09'x||'RATIO_DB='||ratio||'09'x||'ENV_LAG_SAMPLES='||lag||'09'x||'ENV_LAG_MS='||lagMs||'09'x||'ENV_SCORE=.7'||'09'x||'DIRECT_LAG_SAMPLES=8'||'09'x||'DIRECT_LAG_MS=1'||'09'x||'DIRECT_SCORE=.2'||'09'x||'DIRECT_COHERENCE=.1'||'09'x||'REFINED_LAG_SAMPLES='||lag||'09'x||'REFINED_LAG_MS='||lagMs||'09'x||'REFINED_SCORE=.7'||'09'x||'REFINED_COHERENCE='||coh
  return .AudioV9SpatialMeasurement~new(t)

assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return

::requires 'AudioV9AcousticCharacter.cls'
::requires 'MLPatternHash.cls'
