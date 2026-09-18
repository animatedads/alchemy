store=.StorageFuseGenerationStore~new
store~mkdir("/project")
store~createFile("/project/main.dat","live-data")
store~createFile("/project/index.dat","live-index")
fs=.StorageFuseOperationCore~new(store)

/* A quiet directory acquires a frozen generation immediately. */
r=fs~getattr("/project:frozen")
say "frozen state:" r~value~state "generation:" r~value~generation
r=fs~readdir("/project:frozen")
do name over r~value; say "  " name; end

s=store~latestSnapshot("/project")
prepared=.StorageFusePreparedSnapshotRef~new(s)
say "stable prepared root:" prepared~mountedRoot("/mnt/storage")

/* Alternate stream bytes do not replace the default file stream. */
h=fs~open("/project/main.dat:thumbnail","WRITE")~value
ignored=fs~write(h,0,"preview")
ignored=fs~release(h)
say "main:" store~liveRead("/project/main.dat")
say "thumbnail:" store~liveRead("/project/main.dat",0,99,"thumbnail")
exit 0

::requires "src/StorageFuse.cls"