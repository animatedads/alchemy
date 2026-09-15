py = .ForeignPython~import('audio_ml_foreign')
info = py~runtime_info
call assertTrue info~isa(.Array), 'runtime info array'
call assertEq 'ok', info[1], 'SpeechBrain stack import status'
call assertTrue info[2]~string \= '', 'SpeechBrain version'
call assertTrue info[3]~string \= '', 'Torch version'
call assertTrue info[4]~string \= '', 'torchaudio version'
say 'AUDIO FOREIGNPYTHON SPEECHBRAIN RUNTIME: OK speechbrain='info[2] 'torch='info[3] 'torchaudio='info[4]
py~close
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array('FAILED ' || label)
::routine assertEq
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 88.900 array('FAILED ' || label || ' expected=' || expected || ' actual=' || actual)
::requires 'python_foreign.cls'
