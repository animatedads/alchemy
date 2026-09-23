parse source . . here
root=filespec("location",here)||".."; call directory root
base="/tmp/evac-dev5-"||random(100000,999999); src=base||"/src"; dst=base||"/dst"; cp=base||"/cp"
address system "/bin/mkdir -p "||src||" "||dst||" "||cp
call charout src||"/database.db","DATA-ONE"; call stream src||"/database.db","c","close"
call charout src||"/database.idx","INDEX-ONE"; call stream src||"/database.idx","c","close"
inv=.EvacInventory~new; g=inv~scan(src,1,.false)
paths=.array~of("database.db","database.idx")
group=.EvacConsistencyGroup~new("db-main",paths)
/* Failed application quiesce must fail closed and dispatch nothing. */
bad=.EvacApplicationQuiesceProvider~new("/bin/false","/bin/true")
gx=.EvacConsistencyGroupExecutor~new(1048576)
call assert \gx~transferGroup(group,g,src,dst,cp,bad),"failed quiesce was accepted"
call assert g~entries["database.db"]~verifiedCurrentCount=0,"member copied without lease"
/* Successful explicit application lease covers both files as one epoch. */
g=inv~scan(src,2,.false)
good=.EvacApplicationQuiesceProvider~new("/bin/true","/bin/true")
call assert gx~transferGroup(group,g,src,dst,cp,good),"application group transfer failed"
call assert g~entries["database.db"]~consistencyClass=.EvacConsistencyClass~APPLICATION_CONSISTENT,"db class wrong"
call assert g~entries["database.idx"]~consistencyClass=.EvacConsistencyClass~APPLICATION_CONSISTENT,"idx class wrong"
call assert pos("group=db-main",g~entries["database.idx"]~consistencyEvidence)>0,"group evidence absent"
/* Prepared snapshot provider redirects capture to snapshot root and labels it honestly. */
snap=base||"/snap"; dst2=base||"/dst2"; cp2=base||"/cp2"; address system "/bin/mkdir -p "||snap||" "||dst2||" "||cp2
address system "/bin/cp -al "||src||"/. "||snap||"/"
g3=inv~scan(src,3,.false); sp=.EvacPreparedSnapshotProvider~new(snap)
call assert gx~transferGroup(group,g3,src,dst2,cp2,sp),"snapshot group transfer failed"
call assert g3~entries["database.db"]~consistencyClass=.EvacConsistencyClass~SNAPSHOT_CONSISTENT,"snapshot class wrong"
address system "/bin/rm -rf "||base
say "PASS dev5 consistency groups"
exit 0
assert: procedure
 use arg ok,msg
 if \ok then do; say "FAIL:" msg; exit 1; end
return
::requires "src/StorageEvacuation.cls"
