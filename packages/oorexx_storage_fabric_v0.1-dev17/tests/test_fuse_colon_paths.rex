store=.StorageFuseGenerationStore~new
store~mkdir("/project")
store~createFile("/project/doc.txt","MAIN")
core=.StorageFuseOperationCore~new(store)

/* Unknown colon suffix on the final filename is a named application stream. */
r=core~open("/project/doc.txt:thumbnail","WRITE")
call assert r~ok,"named stream open"
call assert core~write(r~value,0,"THUMB")~ok,"named stream write"
call assert core~release(r~value)~ok,"named stream release"
call assertEq "MAIN",store~liveRead("/project/doc.txt"),"default bytes unchanged"
r=core~open("/project/doc.txt:thumbnail","READ")
call assert r~ok,"named stream read open"
call assertEq "THUMB",core~read(r~value,0,99)~value,"named stream bytes"
call assert core~release(r~value)~ok,"named stream read release"

/* :frozen is a reserved directory view. With no writers it publishes in one
 * barrier operation and can be traversed as if it were an ordinary directory. */
r=core~getattr("/project:frozen")
call assert r~ok,"frozen selector getattr"
call assertEq .StorageFuseNodeKind~DIRECTORY,r~value~kind,"frozen selector is directory"
call assertEq .StorageFuseSnapshotState~PUBLISHED,r~value~state,"quiet frozen view publishes immediately"
r=core~getattr("/project:frozen/doc.txt")
call assert r~ok,"child path through frozen component"
call assertEq .StorageFuseNodeKind~FILE,r~value~kind,"frozen child file"

/* :gN is an immutable explicit generation selector. */
s=store~latestSnapshot("/project")
gpath="/project:g"||s~generation||"/doc.txt"
r=core~getattr(gpath)
call assert r~ok,"explicit generation lookup"
call assertEq s~generation,r~value~generation,"generation preserved"
r=core~open(gpath,"WRITE")
call assertEq .StorageFuseErrno~EROFS,r~errno,"generation write denied"

/* System streams are computed control/status views, not application bytes. */
r=core~readVirtual("/project:$status")
call assert r~ok,"status system stream"
call assert pos("liveGeneration=",r~value)>0,"status reports live generation"
r=core~readVirtual("/project:$history")
call assert r~ok,"history system stream"
call assert pos(s~snapshotId,r~value)>0,"history reports snapshot id"

/* Merely looking up :release is observational. */
r=core~getattr("/project:release")
call assert r~ok,"release control selector resolves"
call assertEq .StorageFuseNodeKind~CONTROL,r~value~kind,"release is control node"
call assert store~latestSnapshot("/project")<>.nil,"lookup did not release snapshot"

say "PASS FUSE colon paths and streams"
exit 0

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