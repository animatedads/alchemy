path='/tmp/storage-fuse-dev21.state'
call SysFileDelete path
call SysFileDelete path||'.tmp'

/* Deliberately contains every byte 00-FF.  Persistence must not silently
 * become a text-only FUSE feature. */
data=''
do i=0 to 255; data=data||d2c(i); end
meta='stream:'||reverse(data)

s=.StorageFuseGenerationStore~new
call ok s~mkdir('/persistent'),'mkdir'
v=s~createFile('/persistent/allbytes.bin',data)
call ok v<>.nil,'create binary file'
v~putSeedStream('meta',meta)

/* Open surface handles are transient and deliberately are not checkpointed. */
h=s~open('/persistent/allbytes.bin','READ')
call ok h<>.nil,'open transient handle'
call no s~savePersistent(path),'checkpoint refuses active surface handle'
call ok s~close(h),'close handle'

snap=s~beginSnapshot('/persistent')
call ok snap<>.nil & snap~published,'publish generation snapshot'
call ok s~savePersistent(path),'save fuse projection state'

r=.StorageFuseGenerationStore~new
call ok r~loadPersistent(path),'reload fuse projection state'
call eq data,r~liveRead('/persistent/allbytes.bin',0,256,''),'all 256 byte values survive restart'
call eq meta,r~liveRead('/persistent/allbytes.bin',0,length(meta),'meta'),'named stream survives restart'
rs=r~snapshotByGeneration('/persistent',snap~generation)
call ok rs<>.nil & rs~published,'published generation survives restart'
call eq data,r~snapshotRead(rs,'/persistent/allbytes.bin',0,256,''),'snapshot bytes survive restart'
call eq meta,r~snapshotRead(rs,'/persistent/allbytes.bin',0,length(meta),'meta'),'snapshot named stream survives restart'

/* Prove the ordinary FUSE operation surface can reopen the recovered bytes;
 * the persistence implementation itself remains beneath the surface. */
core=.StorageFuseOperationCore~new(r)
o=core~open('/persistent/allbytes.bin','READ')
call eq 0,o~errno,'FUSE open after authority restart'
rd=core~read(o~value,0,256)
call eq 0,rd~errno,'FUSE read after authority restart'
call eq data,rd~value,'FUSE recovered binary bytes'
call eq 0,core~release(o~value)~errno,'FUSE release after restart'

call SysFileDelete path
say 'PASS FUSE projection restart persistence including binary/named streams'
exit 0

::routine ok
  use arg v,label
  if \v then do; say 'FAIL' label; raise syntax 88.900 array('assertion failed'); end
::routine no
  use arg v,label
  if v then do; say 'FAIL' label; raise syntax 88.900 array('assertion failed'); end
::routine eq
  use arg e,a,label
  if e<>a then do; say 'FAIL' label; raise syntax 88.900 array('assertion failed'); end
::requires 'src/StorageFuse.cls'
::requires 'src/StorageFabric.cls'
