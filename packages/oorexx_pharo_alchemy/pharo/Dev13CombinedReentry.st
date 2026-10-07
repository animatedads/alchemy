| cls callback result |
cls := ShiftClassInstaller make: [ :builder |
 builder superclass: Object; name: #AlchemyDev13Combined; package: 'Alchemy-ooRexx-Qualification' ].
cls class compile: 'invokeRexx
 ^ self ffiCall: #(#int32 pa_dev13_invoke_rexx()) module: ''/mnt/data/oorexx_pharo_alchemy_v0.1-dev13-combined-reentry/build/libpharo_alchemy_dev13.so'''.
cls class compile: 'runWith: callback
 ^ self ffiCall: #(#int32 pa_dev13_run(void * callback)) module: ''/mnt/data/oorexx_pharo_alchemy_v0.1-dev13-combined-reentry/build/libpharo_alchemy_dev13.so'''.
callback := FFICallback signature: #(int (int)) block: [ :argument |
 Transcript show: 'DEV13 pharoReceived='; show: argument printString; cr.
 cls invokeRexx ].
result := cls runWith: callback.
Transcript show: 'DEV13 combinedResult='; show: result printString; cr.
Smalltalk snapshot: false andQuit: true.
