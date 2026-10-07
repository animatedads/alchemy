| cls receiver callback result |
cls := ShiftClassInstaller make: [ :builder |
 builder superclass: Object;
 name: #AlchemyDev11Receiver;
 slots: #(base);
 package: 'Alchemy-ooRexx-Qualification' ].
cls compile: 'initialize base := 40'.
cls compile: 'alchemyAdd: x ^ base + x'.
receiver := cls new.
callback := FFICallback
 signature: #(int (int))
 block: [ :argument | receiver alchemyAdd: argument ].
cls class compile: 'nativeCallback: callback argument: argument
 ^ self ffiCall: #(#int32 pa_pharo12_callback_roundtrip(void * callback, int32 argument)) module: ''/mnt/data/oorexx_pharo_alchemy_v0.1-dev11-native-callback/build/libpharo_alchemy_dev11.so'''.
result := cls nativeCallback: callback argument: 2.
Transcript show: 'DEV11 nativeToPharoResult='; show: result printString; cr.
Transcript show: 'DEV11 receiverIdentityStable='; show: (receiver == receiver) printString; cr.
Smalltalk snapshot: false andQuit: true.
