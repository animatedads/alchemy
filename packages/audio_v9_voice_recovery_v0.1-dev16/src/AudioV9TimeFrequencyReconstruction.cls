/* AudioV9TimeFrequencyReconstruction.cls
 * dev5: source-family/box-conditioned soft time-frequency reconstruction.
 * Boxes are evidence, never deletion authority. Ambiguous/voice-compatible
 * boxes protect their time-frequency region from interference attenuation.
 */
::options numeric inherit

::class AudioV9TfMaskRow public
::method init
  expose startSample endSample lowHz highHz gain protect confidence familyId speakerId reason characterId
  use strict arg startValue,endValue,lowValue,highValue,gainValue,protectValue,confidenceValue,familyValue='UNLABELLED',speakerValue='',reasonValue='EVIDENCE',characterValue=''
  startSample=startValue+0; endSample=endValue+0; lowHz=lowValue+0; highHz=highValue+0
  gain=gainValue+0; protect=(protectValue<>0); confidence=confidenceValue+0
  familyId=familyValue~string; speakerId=speakerValue~string; reason=reasonValue~string; characterId=characterValue~string
  if startSample<0 | endSample<=startSample then raise syntax 88.900 array('invalid TF mask sample range')
  if lowHz<0 | highHz<=lowHz then raise syntax 88.900 array('invalid TF mask frequency range')
  if gain<=0 then raise syntax 88.900 array('TF mask gain must be positive')
  if confidence<0 | confidence>1 then raise syntax 88.900 array('TF mask confidence must be 0..1')
::method startSample; expose startSample; return startSample
::method endSample; expose endSample; return endSample
::method lowHz; expose lowHz; return lowHz
::method highHz; expose highHz; return highHz
::method gain; expose gain; return gain
::method protect; expose protect; return protect
::method confidence; expose confidence; return confidence
::method familyId; expose familyId; return familyId
::method speakerId; expose speakerId; return speakerId
::method reason; expose reason; return reason
::method characterId; expose characterId; return characterId
::method tsv
  expose startSample endSample lowHz highHz gain protect confidence familyId speakerId reason characterId
  return startSample||'09'x||endSample||'09'x||lowHz||'09'x||highHz||'09'x||gain||'09'x||(protect+0)||'09'x||confidence||'09'x||familyId||'09'x||speakerId||'09'x||reason||'09'x||characterId

::class AudioV9TfMaskPolicy public
::method init
  expose voiceBoost alarmGain catGain playbackGain impactGain backgroundGain inferredAlarmGain inferredImpactGain inferredBackgroundGain
  use strict arg voiceBoostValue=1.18,alarmGainValue=.45,catGainValue=.65,playbackGainValue=.55,impactGainValue=.50,backgroundGainValue=.78,inferredAlarmGainValue=.72,inferredImpactGainValue=.65,inferredBackgroundGainValue=.84
  voiceBoost=voiceBoostValue+0; alarmGain=alarmGainValue+0; catGain=catGainValue+0; playbackGain=playbackGainValue+0
  impactGain=impactGainValue+0; backgroundGain=backgroundGainValue+0; inferredAlarmGain=inferredAlarmGainValue+0; inferredImpactGain=inferredImpactGainValue+0; inferredBackgroundGain=inferredBackgroundGainValue+0
::method decision
  expose voiceBoost alarmGain catGain playbackGain impactGain backgroundGain inferredAlarmGain inferredImpactGain inferredBackgroundGain
  use strict arg family,speakerId=''
  if \family~isA(.AudioV9SourceFamily) then raise syntax 88.900 array('TF mask policy requires source family')
  label=family~label~upper; e=family~evidence
  d=.directory~new
  /* An anonymous campaign/chunk speaker is positive voice evidence, not real-world identity. */
  if speakerId<>'' then return self~result(voiceBoost,.true,self~max(.55,e~voice),'SPEAKER_VOICE')
  if label='VOICE' | label='HUMAN_VOICE' | label='VOICE_LIKE' then return self~result(voiceBoost,.true,self~max(.55,e~voice),'CONFIRMED_VOICE')
  if label='ALARM' then return self~result(alarmGain,.false,1,'CONFIRMED_ALARM')
  if label='CAT' | label='CAT_MEOW' | label='ANIMAL' then return self~result(catGain,.false,1,'CONFIRMED_ANIMAL')
  if label='CAMERA_PLAYBACK' then return self~result(playbackGain,.false,1,'CONFIRMED_CAMERA_PLAYBACK')
  if label='IMPACT' | label='BANG' then return self~result(impactGain,.false,1,'CONFIRMED_IMPACT')
  if label='BACKGROUND' then return self~result(backgroundGain,.false,1,'CONFIRMED_BACKGROUND')

  /* Conservative inference: possible voice/structured vocalisation protects the bin.
   * Interference attenuation is only allowed when voice evidence is weak. */
  if e~voice>=.45 then return self~result(1.12,.true,e~voice,'INFERRED_VOICE')
  if e~vocalisation>=.55 then return self~result(1,.true,e~vocalisation,'AMBIGUOUS_VOCALISATION')
  if e~impulse>=.80 & e~voice<.25 then return self~result(inferredImpactGain,.false,e~impulse,'INFERRED_IMPACT')
  if e~alarm>=.80 & e~voice<.25 then return self~result(inferredAlarmGain,.false,e~alarm,'INFERRED_ALARM')
  if e~background>=.90 & e~voice<.25 then return self~result(inferredBackgroundGain,.false,e~background,'INFERRED_BACKGROUND')
  return self~result(1,.true,.35,'UNCERTAIN_PRESERVE')
::method result private
  use strict arg gain,protect,confidence,reason
  d=.directory~new; d['gain']=gain; d['protect']=protect; d['confidence']=confidence; d['reason']=reason; return d
::method max private
  use strict arg a,b
  if a>b then return a
  return b

::class AudioV9TfMaskRowComparator private
::method compare
  use strict arg a,b
  if a~startSample<b~startSample then return -1
  if a~startSample>b~startSample then return 1
  if a~lowHz<b~lowHz then return -1
  if a~lowHz>b~lowHz then return 1
  if a~familyId<b~familyId then return -1
  if a~familyId>b~familyId then return 1
  return 0

::class AudioV9TfMaskPlan public
::method init
  expose rows
  rows=.array~new
::method append
  expose rows
  use strict arg row
  if \row~isA(.AudioV9TfMaskRow) then raise syntax 88.900 array('TF mask plan requires AudioV9TfMaskRow')
  rows~append(row); return self
::method rows; expose rows; return rows~copy
::method items; expose rows; return rows~items
::method sort
  expose rows
  rows~sortWith(.AudioV9TfMaskRowComparator~new); return self
::method write
  expose rows
  use strict arg path
  self~sort
  call stream path,'C','OPEN WRITE REPLACE'
  call lineout path,'start_sample'||'09'x||'end_sample'||'09'x||'low_hz'||'09'x||'high_hz'||'09'x||'gain'||'09'x||'protect'||'09'x||'confidence'||'09'x||'family_id'||'09'x||'speaker_id'||'09'x||'reason'||'09'x||'character_id'
  do r over rows; call lineout path,r~tsv; end
  call stream path,'C','CLOSE'; return path

::class AudioV9TfMaskPlanner public
::method init
  expose policy
  use strict arg policyValue=.nil
  if policyValue==.nil then policy=.AudioV9TfMaskPolicy~new; else policy=policyValue
::method fromAnalysis
  expose policy
  use strict arg analysis,absoluteChunkStartMs,sampleRate,totalSamples
  if \analysis~isA(.AudioV9AcousticAnalysis) then raise syntax 88.900 array('TF mask planner requires acoustic analysis')
  sampleRate=sampleRate+0; totalSamples=totalSamples+0; absoluteChunkStartMs=absoluteChunkStartMs+0
  if sampleRate<1000 | totalSamples<1 then raise syntax 88.900 array('invalid TF mask render geometry')
  speakerByFamily=.directory~new
  do sp over analysis~speakers
    do f over sp~families; speakerByFamily[f~id]=sp~id; end
  end
  plan=.AudioV9TfMaskPlan~new
  do family over analysis~families
    speaker=''; if speakerByFamily~hasIndex(family~id) then speaker=speakerByFamily[family~id]
    dec=policy~decision(family,speaker)
    do track over family~tracks
      do c over track~members
        localStart=c~absoluteStartMs-absoluteChunkStartMs; localEnd=c~absoluteEndMs-absoluteChunkStartMs
        start=trunc(localStart*sampleRate/1000); finish=trunc(localEnd*sampleRate/1000)
        if start<0 then start=0
        if finish>totalSamples then finish=totalSamples
        if finish<=start then iterate
        b=c~box
        plan~append(.AudioV9TfMaskRow~new(start,finish,b~lowHz,b~highHz,dec['gain'],dec['protect'],dec['confidence'],family~id,speaker,dec['reason'],c~id))
      end
    end
  end
  return plan~sort

::requires 'AudioV9AcousticCharacter.cls'
