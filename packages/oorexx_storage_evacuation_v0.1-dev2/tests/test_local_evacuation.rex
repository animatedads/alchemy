root="/tmp/oorexx-evac2-source"
dst="/tmp/oorexx-evac2-dest"
cp="/tmp/oorexx-evac2-checkpoints"
manifest="/tmp/oorexx-evac2.manifest"
address system "/bin/rm -rf -- '"root"' '"dst"' '"cp"' '"manifest"'"
call SysMkDir root
call SysMkDir dst
call SysMkDir cp
call SysMkDir root||"/dir"
call charout root||"/plain.txt","hello evacuation dev2"; call stream root||"/plain.txt","c","close"
call charout root||"/dir/big.bin",copies("0123456789abcdef",65536); call stream root||"/dir/big.bin","c","close"
address system "/bin/chmod 640 '"root"/plain.txt'"
address system "/usr/bin/touch -m -d @1700000000 '"root"/plain.txt'"
address system "/bin/ln -s plain.txt '"root"/link.txt'"
address system "/bin/ln '"root"/plain.txt' '"root"/hard.txt'"

inv=.EvacInventory~new
controller=.EvacConvergenceController~new
g1=inv~scan(root,1,.false)
r1=controller~evacuateGeneration(g1,dst,cp)
if r1["failed"]<>0 | g1~outstandingCount<>0 | g1~errorCount<>0 then do
  say "FAIL first convergence" r1["failed"] g1~outstandingCount g1~errorCount
  exit 1
end

/* Content equality */
address system "/usr/bin/cmp -- '"root"/plain.txt' '"dst"/plain.txt'"
if rc<>0 then do; say "FAIL content compare"; exit 1; end
address system "/usr/bin/cmp -- '"root"/dir/big.bin' '"dst"/dir/big.bin'"
if rc<>0 then do; say "FAIL big compare"; exit 1; end

/* Symlink target equality */
if .EvacPosixMetadataProbe~new~probe(dst||"/link.txt")~symlinkTarget<>"plain.txt" then do
  say "FAIL symlink target"; exit 1
end

/* Hard links are structural, not merely equal bytes. */
p1=.EvacPosixMetadataProbe~new~probe(dst||"/plain.txt")
p2=.EvacPosixMetadataProbe~new~probe(dst||"/hard.txt")
if p1~inode<>p2~inode | p1~device<>p2~device then do
  say "FAIL hardlink reconstruction" p1~inode p2~inode; exit 1
end

/* Mode and mtime are verified reconstruction properties. */
srcm=.EvacPosixMetadataProbe~new~probe(root||"/plain.txt")
dstm=.EvacPosixMetadataProbe~new~probe(dst||"/plain.txt")
if srcm~modeOctal<>dstm~modeOctal | srcm~mtimeEpoch<>dstm~mtimeEpoch then do
  say "FAIL metadata reconstruction" srcm~modeOctal dstm~modeOctal srcm~mtimeEpoch dstm~mtimeEpoch; exit 1
end

/* Durable manifest must survive a process-style save/load boundary. */
store=.EvacManifestStore~new
store~save(g1,manifest)
loaded=store~load(manifest)
if loaded==.nil | loaded~count<>g1~count then do; say "FAIL manifest reload count"; exit 1; end
if loaded~entries["plain.txt"]~contentSha256<>g1~entries["plain.txt"]~contentSha256 then do; say "FAIL manifest digest reload"; exit 1; end
if loaded~entries["link.txt"]~metadata~symlinkTarget<>"plain.txt" then do; say "FAIL manifest symlink reload"; exit 1; end

/* A second unchanged inventory may inherit verified replica evidence and seal. */
g2=inv~scan(root,2,.false)
if \controller~sealStablePair(g1,g2) then do
  say "FAIL stable pair did not seal" g2~outstandingCount g2~errorCount g2~dirtyCount
  exit 1
end
if \g2~sealed then do; say "FAIL seal flag"; exit 1; end

/* A changed source invalidates inventory equivalence and cannot seal. */
call charout root||"/plain.txt","changed after seal candidate",1; call stream root||"/plain.txt","c","close"
g3=inv~scan(root,3,.false)
if controller~sealStablePair(g2,g3) then do; say "FAIL changed inventories sealed"; exit 1; end

/* Pre-dispatch fencing remains mandatory. */
g4=inv~scan(root,4,.false)
call charout root||"/plain.txt","newer generation",1; call stream root||"/plain.txt","c","close"
e4=g4~entries["plain.txt"]
rr=.EvacLocalReplicaExecutor~new~transfer(e4,root,dst,cp||"-stale")
if rr<>.nil | e4~objectState<>.EvacObjectState~DIRTY then do; say "FAIL stale dispatch fence"; exit 1; end

say "PASS local evacuation dev2"
exit 0
::requires "src/StorageEvacuation.cls"
