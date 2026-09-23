cat=.StorageCatalogue~new
base=.StorageObject~new(.StorageRef~new("obj:base"),"document.txt",10,"text/plain")
cat~put(base)
newTracked=.StorageObject~new(.StorageRef~new("obj:tracked"),"document.txt",11,"text/plain")
cat~put(newTracked)
newDirect=.StorageObject~new(.StorageRef~new("obj:direct"),"document.txt",12,"text/plain")
cat~put(newDirect)

env=.StorageEnvironment~new("MIXED","LIVE","",0,1,.StorageWritePolicy~VERSIONED)
ns=.StorageNamespace~new("mixed",cat,env)
ns~bind("/X/document.txt",base~ref,.StorageWritePolicy~DIRECT)
ns~bind("/Z/document.txt",base~ref,.StorageWritePolicy~TRACKED)
ns~bind("/R/document.txt",base~ref,.StorageWritePolicy~READ_ONLY)

cs=.StorageChangeSet~new("z-changes","MIXED",1)
d=ns~applyWrite("/Z/document.txt",newTracked~ref,cs)
call assertTrue d~allowed,"tracked route write"
call assertEq "TRACKED_WRITE",d~action,"tracked action"
call assertEq "obj:base",ns~resolve("/X/document.txt")~entry~ref~objectId,"X untouched by Z write"
call assertEq "obj:base",ns~resolve("/Z/document.txt")~entry~ref~objectId,"Z base remains untouched"
call assertEq "obj:tracked",ns~resolve("/Z/document.txt",cs)~entry~ref~objectId,"Z overlay exposes tracked change"

x=ns~applyWrite("/X/document.txt",newDirect~ref)
call assertTrue x~allowed,"direct route write"
call assertEq "obj:direct",ns~resolve("/X/document.txt")~entry~ref~objectId,"direct route advances binding"
call assertEq "obj:base",ns~resolve("/Z/document.txt")~entry~ref~objectId,"Z remains its own route"

r=ns~applyWrite("/R/document.txt",newDirect~ref)
call assertFalse r~allowed,"read-only route blocks write"

say "PASS route-specific write semantics"
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
