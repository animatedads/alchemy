/* Demonstrate one object, several paths, and TEST overlay semantics. */
cat=.StorageCatalogue~new
base=.StorageObject~new(.StorageRef~new("sha256:base-config"),"config.json",128,"application/json")
base~setEA(.StorageEA~new("system","role","configuration"))
cat~put(base)
changed=.StorageObject~new(.StorageRef~new("sha256:test-config"),"config.json",132,"application/json")
cat~put(changed)

liveEnv=.StorageEnvironment~new("LIVE",.StorageEnvironmentKind~LIVE,"",0,27)
live=.StorageNamespace~new("live",cat,liveEnv)
live~bind("/app/config.json",base~ref,.StorageWritePolicy~VERSIONED)
live~bind("/published/config.json",base~ref,.StorageWritePolicy~READ_ONLY)

testEnv=.StorageEnvironment~new("TEST",.StorageEnvironmentKind~TEST,"LIVE",27)
test=.StorageNamespace~new("test",cat,testEnv,live)
cs=.StorageChangeSet~new("test-27-1","TEST",27)

test~applyWrite("/app/config.json",changed~ref,cs)

say "LIVE /app/config.json ->" live~resolve("/app/config.json")~entry~ref~objectId
say "TEST base             ->" test~resolve("/app/config.json")~entry~ref~objectId
say "TEST with overlay     ->" test~resolve("/app/config.json",cs)~entry~ref~objectId
exit 0

::requires "src/StorageFabric.cls"