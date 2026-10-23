cat=.StorageCatalogue~new
hiCommon=.StorageObject~new(.StorageRef~new("hi:common"),"common.txt",1,"text/plain")
hiOnly=.StorageObject~new(.StorageRef~new("hi:only"),"high.txt",1,"text/plain")
loCommon=.StorageObject~new(.StorageRef~new("lo:common"),"common.txt",1,"text/plain")
loOnly=.StorageObject~new(.StorageRef~new("lo:only"),"low.txt",1,"text/plain")
cat~put(hiCommon); cat~put(hiOnly); cat~put(loCommon); cat~put(loOnly)

env1=.StorageEnvironment~new("L1",.StorageEnvironmentKind~LIVE,"",0,1,.StorageWritePolicy~DIRECT)
env2=.StorageEnvironment~new("L2",.StorageEnvironmentKind~LIVE,"",0,1,.StorageWritePolicy~DIRECT)
hi=.StorageNamespace~new("high",cat,env1)
lo=.StorageNamespace~new("low",cat,env2)
hi~bind("/apps/common.txt",hiCommon~ref,.StorageWritePolicy~DIRECT)
hi~bind("/apps/high.txt",hiOnly~ref,.StorageWritePolicy~DIRECT)
lo~bind("/legacy/common.txt",loCommon~ref,.StorageWritePolicy~DIRECT)
lo~bind("/legacy/low.txt",loOnly~ref,.StorageWritePolicy~DIRECT)

u=.StorageUnionView~new("TVFS-like")
u~addLayer(hi,"/apps","preferred")
u~addLayer(lo,"/legacy","fallback")
call assertEq 2,u~layerCount,"two union layers"

r=u~resolve("/common.txt")
call assertTrue r~found,"common resolves"
call assertEq 1,r~layerIndex,"priority layer wins"
call assertEq "hi:common",r~entry~ref~objectId,"shadowing selects high common"

r2=u~resolve("/low.txt")
call assertTrue r2~found,"fallback resolves"
call assertEq 2,r2~layerIndex,"fallback layer selected"
call assertEq "lo:only",r2~entry~ref~objectId,"low-only file visible"

list=u~list("/")
call assertEq 3,list~items,"union listing merges and shadows duplicate names"
call assertContains list,"common.txt","hi:common"
call assertContains list,"high.txt","hi:only"
call assertContains list,"low.txt","lo:only"

say "PASS ordered TVFS-style union search path"
exit 0

::routine assertContains
  use arg a,name,id
  do e over a
    if .StoragePath~name(e~path)=name & e~ref~objectId=id then return
  end
  say "FAIL missing" name id
  raise syntax 88.900 array("test assertion failed")
::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
