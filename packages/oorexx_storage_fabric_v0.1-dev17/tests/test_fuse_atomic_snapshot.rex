store=.StorageFuseGenerationStore~new
store~mkdir("/mydir")
store~createFile("/mydir/a.txt","AAAA")
store~createFile("/mydir/b.txt","BBBB")

/* NTFS-like application stream: separate bytes, same filesystem object version. */
ads=store~open("/mydir/a.txt","WRITE","1")
call assert ads<>.nil,"named stream writer open"
call assertEq 3,store~write(ads,0,"ALT"),"named stream write length"
call assert store~close(ads),"named stream close"
call assertEq "AAAA",store~liveRead("/mydir/a.txt",0,99,""),"default stream independent"
call assertEq "ALT",store~liveRead("/mydir/a.txt",0,99,"1"),"named stream content"

/* Existing writer is the hard case.  It remains pinned to generation S while
 * the live path switches to S+1; its post-barrier writes are dual-written so
 * live semantics are not lost. */
oldWriter=store~open("/mydir/a.txt","WRITE")
call assert oldWriter<>.nil,"pre-barrier writer open"
call assertEq 1,store~write(oldWriter,1,"X"),"pre-barrier write"
oldVersion=oldWriter~version
snap=store~beginSnapshot("/mydir")
call assert snap<>.nil,"snapshot request created"
call assertEq .StorageFuseSnapshotState~WAITING_FOR_HANDLES,snap~state,"snapshot waits for old writer"
call assert snap~member("/mydir/a.txt")~state=.StorageFuseSnapshotMemberState~DRAINING,"busy member drains"
call assert snap~member("/mydir/b.txt")~state=.StorageFuseSnapshotMemberState~FROZEN,"idle member freezes immediately"
call assert oldVersion<>store~liveVersion("/mydir/a.txt"),"live path advanced to next generation"

/* New writer is on the new live generation only. */
newWriter=store~open("/mydir/a.txt","WRITE")
call assert newWriter<>.nil,"post-barrier writer open"
call assert newWriter~version==store~liveVersion("/mydir/a.txt"),"new writer pinned to live generation"
call assertEq 1,store~write(newWriter,0,"N"),"new generation write"

/* Old writer continues and is mirrored into the new live generation. */
call assertEq 1,store~write(oldWriter,2,"Y"),"old writer dual write"

/* Membership is frozen at the barrier. */
store~createFile("/mydir/c.txt","CCCC")

core=.StorageFuseOperationCore~new(store)
r=core~getattr("/mydir:frozen")
call assert r~ok,"frozen root is a synthetic directory even while draining"
call assertEq .StorageFuseSnapshotState~WAITING_FOR_HANDLES,r~value~state,"frozen root exposes pending state"
r=core~readdir("/mydir:frozen")
call assertEq .StorageFuseErrno~EAGAIN,r~errno,"pending frozen directory does not expose partial membership"

/* Closing the final pre-barrier writer atomically publishes the snapshot.
 * The newer live writer does not block publication because it belongs to S+1. */
call assert store~close(oldWriter),"old writer close"
call assertEq .StorageFuseSnapshotState~PUBLISHED,snap~state,"snapshot published after last old writer"
call assertEq "AXYA",store~snapshotRead(snap,"/mydir/a.txt"),"frozen data includes old writer through close"
call assertEq "NXYA",store~liveRead("/mydir/a.txt"),"live data includes old and new writes"
call assertEq "BBBB",store~snapshotRead(snap,"/mydir/b.txt"),"idle member frozen at barrier"

r=core~readdir("/mydir:frozen")
call assert r~ok,"published frozen directory lists"
call assert arrayHas(r~value,"a.txt"),"frozen contains a"
call assert arrayHas(r~value,"b.txt"),"frozen contains b"
call assert \arrayHas(r~value,"c.txt"),"post-barrier create absent from frozen membership"

r=core~open("/mydir:frozen/a.txt","READ")
call assert r~ok,"open frozen file"
fh=r~value
call assertEq "AXYA",core~read(fh,0,99)~value,"read through frozen path"
call assert core~release(fh)~ok,"release frozen handle"

/* Named streams are frozen with the object generation but are not directory
 * entries. */
liveAds=core~open("/mydir/a.txt:1","WRITE")
call assert liveAds~ok,"open live named stream"
call assert core~write(liveAds~value,0,"NEW")~ok,"replace live alternate stream"
call assert core~release(liveAds~value)~ok,"release live stream"
frozenAds=core~open("/mydir:frozen/a.txt:1","READ")
call assert frozenAds~ok,"open frozen named stream"
call assertEq "ALT",core~read(frozenAds~value,0,99)~value,"frozen named stream independent from live change"
call assert core~release(frozenAds~value)~ok,"release frozen stream"
call assertEq "NEW",store~liveRead("/mydir/a.txt",0,99,"1"),"live named stream advanced"

/* Explicit mutation releases the synthetic view; it never destroys the files. */
r=core~rmdir("/mydir:frozen")
call assert r~ok,"rmdir frozen view releases snapshot pin"
call assert store~fileExists("/mydir/a.txt"),"release leaves live object"
call assert store~fileExists("/mydir/b.txt"),"release leaves second live object"

call assert store~close(newWriter),"new writer close"
say "PASS FUSE atomic generation snapshot"
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