cat=.StorageCatalogue~new

v1=.StorageObject~new(.StorageRef~new("sha256:v1"),"cam001.mov",1000,"video/quicktime")
v1~setEA(.StorageEA~new("capture","device","bodycam-17"))
v1~setEA(.StorageEA~new("evidence","case","CASE-42"))
cat~put(v1)

v2=.StorageObject~new(.StorageRef~new("sha256:v2"),"cam002.mov",2000,"video/quicktime")
v2~setEA(.StorageEA~new("capture","device","bodycam-22"))
v2~setEA(.StorageEA~new("evidence","case","CASE-42"))
cat~put(v2)

a1=.StorageObject~new(.StorageRef~new("sha256:a1"),"note.wav",300,"audio/wav")
a1~setEA(.StorageEA~new("capture","device","bodycam-17"))
cat~put(a1)

filter=.StorageFilter~new
filter~add(.StorageFilterClause~new("media.type","video/quicktime"))
filter~add(.StorageFilterClause~new("ea:evidence.case","CASE-42"))

env=.StorageEnvironment~new("LIVE","LIVE","",0,4)
ns=.StorageNamespace~new("live",cat,env)
ns~addQueryFolder(.StorageQueryFolder~new("/views/case42-video",filter,.StorageWritePolicy~READ_ONLY))

entries=ns~list("/views/case42-video")
call assertEq 2,entries~items,"query folder result count"
r=ns~resolve("/views/case42-video/cam001.mov")
call assertTrue r~found,"query path resolves"
call assertEq "sha256:v1",r~entry~ref~objectId,"query path points to stable ref"
call assertEq .StorageWritePolicy~READ_ONLY,r~entry~writePolicy,"query route policy"

/* Removing from a query view is exclusion, never object destruction. */
/* Use a writable query route to demonstrate exclusion semantics. */
ns~addQueryFolder(.StorageQueryFolder~new("/review",filter,.StorageWritePolicy~TRACKED))
d=ns~applyUnlink("/review/cam001.mov",.StorageChangeSet~new("review-cs","LIVE",4))
call assertTrue d~allowed,"query exclusion allowed"
call assertEq "EXCLUDE",d~action,"query unlink means exclusion"
call assertEq 3,cat~count,"catalogue object survives exclusion"
call assertEq 1,ns~list("/review")~items,"excluded query entry hidden"

say "PASS namespace query views / EA / safe exclusion"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
