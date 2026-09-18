cat=.StorageCatalogue~new
a=.StorageObject~new(.StorageRef~new("a"),"a.txt",1,"text/plain")
b=.StorageObject~new(.StorageRef~new("b"),"b.txt",1,"text/plain")
c=.StorageObject~new(.StorageRef~new("c"),"a.txt",1,"text/plain")
cat~put(a); cat~put(b); cat~put(c)

liveEnv=.StorageEnvironment~new("LIVE",.StorageEnvironmentKind~LIVE,"",0,1)
live=.StorageNamespace~new("live",cat,liveEnv)
live~bind("/folder/a.txt",a~ref)
live~bind("/folder/b.txt",b~ref)

testEnv=.StorageEnvironment~new("TEST",.StorageEnvironmentKind~TEST,"LIVE",1)
test=.StorageNamespace~new("test",cat,testEnv,live)
test~bind("/folder/a.txt",c~ref,.StorageWritePolicy~COPY_ON_WRITE)
items=test~list("/folder")
call assertEq 2,items~items,"child list shadows inherited path"
call assertEq "c",test~resolve("/folder/a.txt")~entry~ref~objectId,"child binding wins"
call assertEq "b",test~resolve("/folder/b.txt")~entry~ref~objectId,"other path inherited"

/* Two query results with one visible name must never silently choose one. */
f=.StorageFilter~new
q=.StorageNamespace~new("q",cat,liveEnv)
q~addQueryFolder(.StorageQueryFolder~new("/all",f,.StorageWritePolicy~READ_ONLY))
r=q~resolve("/all/a.txt")
call assertEq .StorageResolutionStatus~AMBIGUOUS,r~status,"query name collision is explicit"

say "PASS namespace inheritance/list/collision"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"