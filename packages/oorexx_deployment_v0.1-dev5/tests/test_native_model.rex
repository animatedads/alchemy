numeric digits 30
d=.NativeArtifactDeclaration~new('foreign-runtime','build/libforeign_runtime.so','src','g++ ...','probe_foreign_runtime.rex')
call must d~validate='','native declaration valid'
r=.NativeArtifactDeploymentRequirement~new(d)
call must r~expected='LOADABLE','native expected state'
e=.NativeArtifactEvidence~new('foreign-runtime')
e~probeBefore=.false; e~rebuilt=.true; e~probeAfter=.true
call must e~satisfied,'rebuilt native artifact is accepted by probe'
say 'PASS native artifact model'
exit 0
must: procedure
 use strict arg c,m
 if \c then do; say 'FAIL' m; exit 1; end
return
::requires 'NativeDeployment.cls'
