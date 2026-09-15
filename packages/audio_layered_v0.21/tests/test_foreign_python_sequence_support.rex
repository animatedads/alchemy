say 'AUDIO FOREIGNPYTHON SEQUENCE SUPPORT START'
py=.ForeignPython~import('audio_ml_fixture')
seq=py~sequence_probe
call truth seq~isa(.ForeignPythonObject),'fixture sequence remains resident Python proxy'
call eq 3,seq~items,'ForeignPython v0.22.2 ITEMS'
call eq 'alpha',seq[1],'Rexx one-based [] reaches Python index zero'
call eq 'beta',seq~at(2),'Rexx AT is one-based'
call eq 'gamma',seq~pythonAt(-1),'exact Python negative index retained'
copy=.ForeignPythonSequenceSupport~toArray(seq)
call truth copy~isa(.Array),'explicit persistence copy becomes ooRexx Array'
call eq 3,copy~items,'copied item count'
call eq 'gamma',copy[3],'copied final value'
seq~close
py~close
say 'AUDIO FOREIGNPYTHON SEQUENCE SUPPORT: OK'
exit 0
::routine truth
  use strict arg v,label
  if \v then raise syntax 88.900 array('FAILED '||label)
::routine eq
  use strict arg e,a,label
  if e\=a then raise syntax 88.900 array('FAILED '||label||' expected='||e||' actual='||a)
::requires '../ForeignPythonSequenceSupport.cls'
