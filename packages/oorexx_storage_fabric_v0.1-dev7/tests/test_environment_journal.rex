tmp="tests/.tmp-environment-journal"
call SysFileDelete tmp||"/environment-TEST-audio.state"
call SysFileDelete tmp||"/changeset-cs-77.state"
call SysRmDir tmp
call SysMkDir tmp

env=.StorageEnvironment~new("TEST-audio",.StorageEnvironmentKind~TEST,"LIVE",42,7,.StorageWritePolicy~COPY_ON_WRITE)
cs=.StorageChangeSet~new("cs-77","TEST-audio",42)
base=.StorageRef~new("obj:base","sha256:aaa")
new=.StorageRef~new("obj:new","sha256:bbb")
cs~recordWrite("/audio/a.wav",base,new,.StorageWritePolicy~COPY_ON_WRITE)
cs~recordUnlink("/audio/old.wav",base,.StorageWritePolicy~COPY_ON_WRITE)
cs~seal

j=.StorageEnvironmentJournal~new(tmp)
j~saveEnvironment(env)
j~saveChangeSet(cs)

env2=j~loadEnvironment("TEST-audio")
call assertTrue env2<>.nil,"environment restored"
call assertEq 42,env2~baseGeneration,"base generation persisted"
call assertEq 7,env2~generation,"current generation persisted"
call assertEq .StorageWritePolicy~COPY_ON_WRITE,env2~defaultWritePolicy,"environment policy persisted"

cs2=j~loadChangeSet("cs-77")
call assertTrue cs2<>.nil,"change set restored"
call assertTrue cs2~sealed,"sealed state persisted"
call assertEq 2,cs2~count,"change count persisted"
wr=cs2~get("/audio/a.wav")
call assertEq .StorageChangeOperation~WRITE,wr~operation,"write operation restored"
call assertEq "obj:base",wr~baseRef~objectId,"base ref restored"
call assertEq "sha256:bbb",wr~newRef~digest,"new ref digest restored"
un=cs2~get("/audio/old.wav")
call assertEq .StorageChangeOperation~UNLINK,un~operation,"unlink restored"

call SysFileDelete tmp||"/environment-TEST-audio.state"
call SysFileDelete tmp||"/changeset-cs-77.state"
call SysRmDir tmp
say "PASS persistent environment/change-set journal"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
