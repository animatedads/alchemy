/* AudioV9CalibrationAcoustic.cls
 * dev8: bounded seam-local acoustic analysis helpers.
 * Calibration is deliberately fail-closed: pathological acoustic fragmentation
 * may reduce clock evidence, but must never turn into unbounded host work or
 * manufacture independent source votes.
 */
::options numeric inherit

::class AudioV9CalibrationDiarizer public
::method init
  expose diarizer
  diarizer=.AudioV9AnonymousDiarizer~new(.AudioV9SourceFamilyClusterer~new(22,90,1400))
::method cluster
  expose diarizer
  use strict arg families,voiceThreshold=.45,maxVoiceFamilies=64
  if \families~isA(.Array) then raise syntax 88.900 array('calibration diarizer requires family Array')
  maxVoiceFamilies=maxVoiceFamilies+0
  if maxVoiceFamilies<1 then raise syntax 88.900 array('calibration diarizer family limit must be positive')
  selected=.array~new
  do f over families
    blocked=.false; label=f~label~upper
    if label='ALARM' | label='CAT' | label='CAMERA_PLAYBACK' | label='IMPACT' | label='BACKGROUND' then blocked=.true
    if \blocked then if f~evidence~voice>=voiceThreshold then selected~append(f)
  end
  if selected~items=0 then return .array~new
  if selected~items>maxVoiceFamilies then do
    /* Conservative overflow semantics: all voice-like families become ONE
     * anonymous source group.  This can lose a clock measurement, but cannot
     * create the two independent votes required for CLOCK_MEASURED. */
    return .array~of(.AudioV9AnonymousSpeakerCluster~new('SPEAKER_CALIBRATION_OVERFLOW',selected))
  end
  return diarizer~cluster(families,voiceThreshold)

::requires 'AudioV9AcousticCharacter.cls'
