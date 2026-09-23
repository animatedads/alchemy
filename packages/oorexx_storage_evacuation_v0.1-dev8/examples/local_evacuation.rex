parse arg sourceRoot destinationRoot checkpointRoot
if sourceRoot="" | destinationRoot="" then do
  say "Usage: rexx examples/local_evacuation.rex source-root destination-root [checkpoint-root]"
  exit 2
end
if checkpointRoot="" then checkpointRoot=destinationRoot||"/.evac-checkpoints"
address system "/bin/mkdir -p -- '"destinationRoot"' '"checkpointRoot"'"
controller=.EvacConvergenceController~new
g=controller~inventory~scan(sourceRoot,1,.true)
r=controller~evacuateRegularFiles(g,destinationRoot,checkpointRoot)
say "generation="g~number
say "objects="g~count
say "verified_current="r["verifiedCurrent"]
say "failed="r["failed"]
say "metadata_only="r["metadataOnly"]
say "outstanding="g~outstandingCount
exit (r["failed"]>0)
::requires "src/StorageEvacuation.cls"
