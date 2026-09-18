cat=.StorageCatalogue~new
base=.StorageObject~new(.StorageRef~new("obj:base"),"document.txt",10,"text/plain")
newX=.StorageObject~new(.StorageRef~new("obj:x2"),"document.txt",11,"text/plain")
newZ=.StorageObject~new(.StorageRef~new("obj:z2"),"document.txt",12,"text/plain")
cat~put(base); cat~put(newX); cat~put(newZ)

env=.StorageEnvironment~new("MIXED",.StorageEnvironmentKind~LIVE,"",0,1,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new("mixed",cat,env)
ns~bind("/X/document.txt",base~ref,.StorageWritePolicy~DIRECT)
ns~addAlias("/Z/document.txt","/X/document.txt",.StorageWritePolicy~TRACKED)
ns~addAlias("/R/document.txt","/X/document.txt",.StorageWritePolicy~READ_ONLY)

call assertEq "obj:base",ns~resolve("/Z/document.txt")~entry~ref~objectId,"alias initially follows X"
call assertEq .StorageNamespaceEntryKind~ALIAS,ns~resolve("/Z/document.txt")~entry~kind,"alias kind"

x=ns~applyWrite("/X/document.txt",newX~ref)
call assertTrue x~allowed,"direct X update"
call assertEq "obj:x2",ns~resolve("/Z/document.txt")~entry~ref~objectId,"Z follows advanced X without rebinding"

cs=.StorageChangeSet~new("z-overlay","MIXED",1)
z=ns~applyWrite("/Z/document.txt",newZ~ref,cs)
call assertTrue z~allowed,"tracked alias write"
call assertEq "TRACKED_WRITE",z~action,"tracked alias action"
call assertEq "obj:x2",ns~resolve("/X/document.txt")~entry~ref~objectId,"tracked alias does not alter X"
call assertEq "obj:z2",ns~resolve("/Z/document.txt",cs)~entry~ref~objectId,"alias overlay visible through Z"

r=ns~applyWrite("/R/document.txt",newZ~ref)
call assertFalse r~allowed,"read only alias denied"

ns~addAlias("/loop-a","/loop-b",.StorageWritePolicy~READ_ONLY)
ns~addAlias("/loop-b","/loop-a",.StorageWritePolicy~READ_ONLY)
loop=ns~resolve("/loop-a")
call assertEq .StorageResolutionStatus~LINK_LOOP,loop~status,"alias loop fails closed"

say "PASS fluid path aliases and route semantics"
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