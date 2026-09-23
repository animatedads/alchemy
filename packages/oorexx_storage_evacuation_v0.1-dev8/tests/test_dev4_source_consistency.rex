parse source . . here
root=filespec("location",here)||".."
call directory root
base="/tmp/evac-dev4-"||random(100000,999999)
src=base||"/src"; dst=base||"/dst"; cp=base||"/cp"
address system "/bin/mkdir -p "||src||" "||dst||" "||cp
f=src||"/database.idx"
call charout f,"INDEX-GENERATION-ONE"; call stream f,"c","close"
inv=.EvacInventory~new
g=inv~scan(src,1,.false)
e=g~entries["database.idx"]
/* Hold the file open for writing in another process. */
holder=base||"/holder.py"
call lineout holder,"import sys,time"
call lineout holder,"f=open(sys.argv[1],'r+b')"
call lineout holder,"time.sleep(4)"
call stream holder,"c","close"
address system "/usr/bin/python3 "||holder||" "||f||" &"
call SysSleep 0.5
ex=.EvacLocalReplicaExecutor~new(1048576,.nil,.EvacOrdinaryFileConsistencyProvider~new(0.2))
r=ex~transfer(e,src,dst,cp)
call assert r==.nil,"in-use file was dispatched"
call assert e~objectState=.EvacObjectState~WAITING_FOR_QUIESCENCE,"missing waiting state"
call assert e~consistencyClass=.EvacConsistencyClass~UNKNOWN,"busy file gained consistency"
call SysSleep 4
/* New generation after holder exits. */
g2=inv~scan(src,2,.false); e2=g2~entries["database.idx"]
r2=ex~transfer(e2,src,dst,cp)
call assert r2<>.nil,"quiet file did not transfer"
call assert r2~state=.EvacReplicaState~VERIFIED_CURRENT,"quiet file not verified current"
call assert e2~consistencyClass=.EvacConsistencyClass~OBSERVED_QUIESCENT,"quiet evidence class wrong"
store=.EvacManifestStore~new; mf=base||"/manifest.evac"; store~save(g2,mf); loaded=store~load(mf)
call assert loaded~entries["database.idx"]~consistencyClass=.EvacConsistencyClass~OBSERVED_QUIESCENT,"consistency not durable"
address system "/bin/rm -rf "||base
say "PASS dev4 source consistency"
exit 0
assert: procedure
  use arg ok,msg
  if \ok then do; say "FAIL:" msg; exit 1; end
return

::requires "src/StorageEvacuation.cls"
