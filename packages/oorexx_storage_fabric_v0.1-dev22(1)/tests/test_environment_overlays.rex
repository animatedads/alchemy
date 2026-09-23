cat=.StorageCatalogue~new
v17=.StorageObject~new(.StorageRef~new("config:v17"),"config.json",100,"application/json")
v18=.StorageObject~new(.StorageRef~new("config:v18-test"),"config.json",101,"application/json")
cat~put(v17); cat~put(v18)

liveEnv=.StorageEnvironment~new("LIVE",.StorageEnvironmentKind~LIVE,"",0,12)
live=.StorageNamespace~new("live",cat,liveEnv)
live~bind("/app/config.json",v17~ref)

testEnv=.StorageEnvironment~new("TEST-payments",.StorageEnvironmentKind~TEST,"LIVE",12,0)
test=.StorageNamespace~new("test-payments",cat,testEnv,live)

r=test~resolve("/app/config.json")
call assertTrue r~found,"test inherits live path"
call assertEq "config:v17",r~entry~ref~objectId,"test initially shares immutable live ref"
call assertEq .StorageWritePolicy~COPY_ON_WRITE,r~entry~writePolicy,"test route becomes COW"

cs=.StorageChangeSet~new("test-change-1","TEST-payments",12)
d=test~applyWrite("/app/config.json",v18~ref,cs)
call assertTrue d~allowed,"test COW write"
call assertEq "config:v17",live~resolve("/app/config.json")~entry~ref~objectId,"live untouched"
call assertEq "config:v17",test~resolve("/app/config.json")~entry~ref~objectId,"test base untouched without overlay"
call assertEq "config:v18-test",test~resolve("/app/config.json",cs)~entry~ref~objectId,"test overlay sees change"

/* Development inherits the same ref but presents TRACKED semantics. */
devEnv=.StorageEnvironment~new("DEV-audio",.StorageEnvironmentKind~DEVELOPMENT,"TEST-payments",0,0)
dev=.StorageNamespace~new("dev-audio",cat,devEnv,test)
devBase=dev~resolve("/app/config.json")
call assertEq .StorageWritePolicy~TRACKED,devBase~entry~writePolicy,"development route defaults to tracked"

cs~seal
plan=.StoragePromotionPlan~new(cs,live,12)
call assertTrue plan~valid,"promotion preflight pinned to live generation"
call assertTrue plan~apply,"promotion applies"
call assertEq 13,liveEnv~generation,"live generation advances atomically"
call assertEq "config:v18-test",live~resolve("/app/config.json")~entry~ref~objectId,"promoted ref visible in live"

stale=.StorageChangeSet~new("stale","TEST-payments",12)
stale~recordWrite("/app/config.json",v17~ref,v18~ref,.StorageWritePolicy~COPY_ON_WRITE)
stale~seal
stalePlan=.StoragePromotionPlan~new(stale,live,12)
call assertFalse stalePlan~valid,"stale base generation rejected"

say "PASS LIVE/TEST overlay and generation-pinned promotion"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::routine assertFalse
  use arg v,l
  if v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
