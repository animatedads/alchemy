call addpath
a=.StorageMeshAuthority~new("storage.fabric.primary","B","SPARE",4,91)
call ok \a~canMutate,"SPARE cannot mutate"
g=a~guardMutation(4); call ok \g~allowed & g~code="NOT_ACTIVE","SPARE mutation fails closed"
p=a~acceptPromotion(5,91); call ok p~allowed & a~role="ACTIVE" & a~epoch=5,"external promotion advances epoch"
g=a~guardMutation(5); call ok g~allowed,"ACTIVE matching epoch may mutate"
g=a~guardMutation(4); call ok \g~allowed & g~code="EPOCH_MISMATCH","stale epoch fenced"
c=a~observeCommit(100); call ok c~allowed & a~committedSequence=100,"commit observation advances"
f=a~setReplicaRole("FORENSIC",6); call ok f~allowed & \a~canRead,"FORENSIC frozen"
p=a~acceptPromotion(7,100); call ok \p~allowed & p~code="FORENSIC_FROZEN","FORENSIC cannot promote"
say "PASS Storage mesh ACTIVE/SPARE/epoch authority projection"
exit 0
ok: procedure
  parse arg truth,label
  if truth then return
  say "FAIL" label; exit 1
addpath: return
::requires "src/StorageMesh.cls"
