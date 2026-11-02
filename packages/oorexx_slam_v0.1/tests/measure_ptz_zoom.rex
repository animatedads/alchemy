/* Reproducible native Power SLAM zoom fit on 1-fps 640x360 luma source. */
use strict arg raw
say 'POWER SLAM PTZ APPARENT ZOOM v0.17'
a=.HarbourPtzScale~estimatePair(raw,45,55)
b=.HarbourPtzScale~estimatePair(raw,217,227)
repeat=.HarbourPtzScale~repeatCheck(a,b,172)
p45=.HarbourPtzScale~profile(.HarbourPtzScale~readFrame(raw,45))
p217=.HarbourPtzScale~profile(.HarbourPtzScale~readFrame(raw,217))
p55=.HarbourPtzScale~profile(.HarbourPtzScale~readFrame(raw,55))
p227=.HarbourPtzScale~profile(.HarbourPtzScale~readFrame(raw,227))
wide1=.HarbourPtzScale~fitProfiles(p45,p217,0.95,1.05,0.025,-12,12,2)
wide2=.HarbourPtzScale~fitProfiles(p55,p227,0.95,1.05,0.025,-12,12,2)
say '45->55 scale='a['SCALE'] 'shift='a['TRANSLATION_X_PX'] 'corr='a['CORRELATION'] 'status='a['STATUS']
say '217->227 scale=' b['SCALE'] 'shift=' b['TRANSLATION_X_PX'] 'corr=' b['CORRELATION'] 'status=' b['STATUS']
say 'same_phase_45_vs_217 scale=' wide1['SCALE'] 'shift=' wide1['TRANSLATION_X_PX'] 'corr=' wide1['CORRELATION']
say 'same_phase_55_vs_227 scale=' wide2['SCALE'] 'shift=' wide2['TRANSLATION_X_PX'] 'corr=' wide2['CORRELATION']
say 'repeat='repeat['STATUS'] 'scale_gap='repeat['SCALE_DIFFERENCE'] 'shift_gap='repeat['TRANSLATION_DIFFERENCE_PX']
if repeat['STATUS']<>'REPEATED_APPARENT_ZOOM_CANDIDATE_NOT_LENS_CALIBRATED' then exit 2
if abs(wide1['SCALE']-1)>0.075 | abs(wide2['SCALE']-1)>0.075 then exit 2
if wide1['CORRELATION']<0.50 | wide2['CORRELATION']<0.50 then exit 2
exit 0

::requires 'SlamHarbourPtzScale.cls'