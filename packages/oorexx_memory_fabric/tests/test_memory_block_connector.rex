call addWith "../src"
call addWith "../build"

bag=.MemoryBlockBag~new("mu-bag-1","mu-01","./memory-block-test.bin",8388608,2097152,7,.true)
call assert bag~nativePageSize>0, "native page size"
a=bag~allocate(1000,"RECONSTRUCTABLE","storage://a")
call assert a<>.nil, "allocate a"
call assert a~length=2097152, "a aligned to 2 MiB"
call assert bag~writeBytes(a,"hello memory fabric")=19, "write a"
call assert bag~readBytes(a,19)="hello memory fabric", "read a"
peer=.MemoryBlockNative~new
peerHandle=peer~open("./memory-block-test.bin",8388608,.false,.true)
call assert peerHandle<>0, "second native mapping attaches to same MU container"
call assert peer~read(peerHandle,a~offset,19)="hello memory fabric", "second mapping sees block without Rexx serialization"
call assert peer~close(peerHandle), "close second mapping"
b=bag~allocate(2097152)
call assert b<>.nil, "allocate b"
call assert bag~copyBlock(b,a,19)=19, "native block copy"
call assert bag~readBytes(b,19)="hello memory fabric", "read copied b"
oldOffset=a~offset
oldGeneration=a~generation
call assert bag~release(a), "release a"
c=bag~allocate(1024)
call assert c<>.nil, "allocate c"
call assert c~offset=oldOffset, "reuse released large-page extent"
call assert c~generation<>oldGeneration, "generation advances on reuse"
call assert \bag~validate(a), "stale handle rejected"
call assert bag~close, "close bag"
call SysFileDelete "./memory-block-test.bin"
say "PASS memory block connector"
exit 0

addWith: procedure
  parse arg p
  current=value("REXX_PATH",,"ENVIRONMENT")
  if current="" then call value "REXX_PATH",p,"ENVIRONMENT"
  else call value "REXX_PATH",p||":"||current,"ENVIRONMENT"
  return

assert: procedure
  parse arg condition, label
  if condition then return
  say "FAIL:" label
  exit 99

::requires "MemoryFabricMemoryBlock.cls"
