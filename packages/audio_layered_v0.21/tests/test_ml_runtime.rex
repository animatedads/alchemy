attrs = .Directory~new; attrs['device'] = 'cpu'
m = .MLModelSpec~new('m1','speaker.embedding','SpeechBrain','ECAPA-TDNN','model/source','rev-1','ForeignPython','audio','vector',attrs)
call assertEq 'speaker.embedding', m~task, 'model task'
call assertEq 'ForeignPython', m~runtime, 'runtime identity'
p = .MLInferenceProvenance~new('speaker.embedding','m1','python','3.13','python.audio.foreign','foreign-python:test','gil-managed','audio path','3-vector',attrs)
call assertEq 'gil-managed', p~threadingMode, 'threading policy'
call assertTrue p~canonicalText~pos('ML_INFERENCE=') = 1, 'provenance canonical shape'
say 'ML RUNTIME SUBSTRATE: OK'
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array('FAILED ' || label)
::routine assertEq
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 88.900 array('FAILED ' || label || ' expected=' || expected || ' actual=' || actual)
::requires '../MLRuntime.cls'
