| cls value |
cls := ShiftClassInstaller make: [ :builder |
 builder superclass: Object;
 name: #AlchemyDev10NativeFFI;
 package: 'Alchemy-ooRexx-Qualification' ].
cls class compile: 'nativeRoundtrip: x
 ^ self ffiCall: #(#int32 pa_pharo12_ffi_roundtrip(#int32 x)) module: ''/mnt/data/oorexx_pharo_alchemy_v0.1-dev10-native-ffi/build/libpharo_alchemy_dev10.so'''.
value := cls nativeRoundtrip: 41.
Transcript show: 'DEV10 nativeCoreRoundtrip=', value printString; cr.
Smalltalk snapshot: false andQuit: true.
