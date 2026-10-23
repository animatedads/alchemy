store=.StorageFuseGenerationStore~new
store~mkdir("/db")
store~createFile("/db/database.db","DATA")
store~createFile("/db/database.idx","INDEX")
store~createFile("/db/other.tmp","OTHER")

members=.array~of("/db/database.db","/db/database.idx")
s=store~beginSnapshot("/db",members)
call assert s~published,"explicit N-file group published"
ref=.StorageFusePreparedSnapshotRef~new(s)
call assertEq "/db:g1",ref~virtualRoot,"immutable generation selector"
call assertEq "/mnt/storage/db:g1",ref~mountedRoot("/mnt/storage"),"mounted prepared-snapshot root"
call assert pos(s~snapshotId,ref~evidence)>0,"evidence carries snapshot id"
list=store~listSnapshot(s,"/db")
call assert arrayHas(list,"database.db"),"requested db member present"
call assert arrayHas(list,"database.idx"),"requested idx member present"
call assert \arrayHas(list,"other.tmp"),"unrequested pre-existing file excluded from N-file snapshot"

/* A later live mutation and later snapshot cannot retarget the prepared root. */
h=store~open("/db/database.db","WRITE")
call assert h<>.nil,"live writer"
call assert store~write(h,0,"NEXT")>=0,"live mutation"
call assert store~close(h),"writer close"
call assertEq "DATA",store~snapshotRead(s,"/db/database.db"),"prepared generation remains immutable"
call assertEq "/db:g1",ref~virtualRoot,"prepared root remains generation-pinned"

say "PASS FUSE prepared snapshot reference"
exit 0

arrayHas: procedure
  use arg a,wanted
  do x over a
    if x=wanted then return .true
  end
  return .false

assert: procedure
  use arg truth,label
  if \truth then do
    say "FAIL:" label
    exit 1
  end
  return
assertEq: procedure
  use arg expected,actual,label
  if expected<>actual then do
    say "FAIL:" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "src/StorageFuse.cls"
