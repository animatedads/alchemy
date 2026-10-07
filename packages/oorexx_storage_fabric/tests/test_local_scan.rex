root="/tmp/oorexx-storage-scan-fixture"
call SysFileTree root,"old.","FSO"
do i=1 to old.0; call SysFileDelete old.i; end
call SysRmDir root
call SysMkDir root
call lineout root||"/clip.mov","abc"
call lineout root||"/note.txt","hello"
call stream root||"/clip.mov","c","close"
call stream root||"/note.txt","c","close"
pool=.StoragePool~new("fixture","local-test",root,"fixture-domain",.StoragePoolMode~BOTH,0)
provider=.LocalFilesystemProvider~new("local-test",pool)
cat=.StorageCatalogue~new
n=provider~scan(cat,.false)
if n<>2 | cat~count<>2 then do; say "FAIL scan count" n cat~count; exit 1; end
if cat~search("clip.mov")~items<>1 then do; say "FAIL scan search"; exit 1; end
call SysFileDelete root||"/clip.mov"; call SysFileDelete root||"/note.txt"; call SysRmDir root
say "PASS local scan"
exit 0
::requires "src/StorageFabric.cls"
