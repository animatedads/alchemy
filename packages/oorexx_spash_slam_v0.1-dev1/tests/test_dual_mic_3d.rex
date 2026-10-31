/* Synthetic, falsifiable SPASH 2-mic 3D test. No private audio/geometry. */
.environment~put(0,'SPASH_PASS')
a=.SpashPoint~new('FC',0,0,0)
b=.SpashPoint~new('FD',3.43,0,0)
src=.SpashPoint~new('S1',0,3.43,0)
fit=.SpashDualMic3D~new(a,b,343)
expected=1000*(src~distanceTo(b)-src~distanceTo(a))/343
call ok abs(fit~predictTdoaMs(src)-expected)<0.000001,'predicted TDOA from two fixed microphones'
x=fit~evaluate(src)
call ok x~at('RESULT')=='UNTESTED','unmeasured case stays untested'
call ok x~at('GEOMETRY_STATUS')=='UNDERDETERMINED_WITH_TWO_MICS','two microphones cannot solve 3D uniquely'
y=fit~evaluate(src,expected,.05,.true)
call ok y~at('RESULT')=='DELAY_COMPATIBLE_NOT_LOCALIZED','acoustic TDOA fits without solved geometry'
call ok abs(y~at('RESIDUAL_MS'))<0.000001,'zero residual if exact synthetic observation'
z=fit~evaluate(src,expected+5,.05,.true)
call ok z~at('RESULT')=='DELAY_INCOMPATIBLE','wrong position hypothesis rejected by measured delay'
far=fit~evaluate(src,50,.05,.true)
call ok far~at('RESULT')=='OUTSIDE_TWO_MIC_PHYSICAL_BOUND','physically impossible two-mic TDOA rejected'
context=.directory~new
context~put(42.15,'VIDEO_FRAME_TIME')
context~put('VIDEO_FC_CLOCK_V1','CLOCK_MODEL_ID')
video=fit~evaluate(src,expected,.05,.false,context)
call ok video~at('RESULT')=='AUDIO_NOT_ADMITTED','video cannot admit acoustic path alone'
call ok video~at('VIDEO_CONTEXT')=='CAMERA_MOTION_CONTEXT_NOT_AUDIO','camera context remains separate'
call ok video~at('VIDEO_CLOCK_MODEL_ID')=='VIDEO_FC_CLOCK_V1','video clock provenance retained'
vp=.array~of(.SpashPoint~new('v1',0,0,0),.SpashPoint~new('v2',1,2,0),.SpashPoint~new('v3',2,1,3),.SpashPoint~new('v4',0,4,1))
p=fit~virtualMicrophones(src,vp)
call ok p~items==4,'four virtual positions'
call ok p[1]~at('AUTHORITY')=='MODEL_ONLY','virtual mic creates prediction not measurement'
noise=fit~processingPlan('KP-0001',.true,.false)
call ok noise~at('GAIN_POLICY')=='HOLD_WHISPER_GAIN_REFERENCE','passing vehicle does not reset gain'
call ok noise~at('VOICE_POLICY')=='SPEECH_PRESERVE_NO_HARD_MUTE','passing vehicle cannot erase speech'
quiet=fit~processingPlan('KP-0002',.false,.false)
call ok quiet~at('GAIN_POLICY')=='ELIGIBLE_FOR_BOUNDED_WHISPER_GAIN_REFERENCE','quiet interval eligible for gain reference'
loud=fit~processingPlan('KP-0003',.false,.true)
call ok loud~at('GAIN_POLICY')=='HOLD_WHISPER_GAIN_REFERENCE','impulse holds whisper gain'
call ok .environment~at('SPASH_PASS')==16,'16 assertions and no failures'
say 'SPASH dual-mic 3D model: 17/17 PASS'
exit 0
::routine ok
  use strict arg truth,label
  if \truth then do
    say 'FAIL:' label
    exit 1
  end
  .environment~put(.environment~at('SPASH_PASS')+1,'SPASH_PASS')
  say 'PASS:' label
::requires 'SpashDualMic3D.cls'
