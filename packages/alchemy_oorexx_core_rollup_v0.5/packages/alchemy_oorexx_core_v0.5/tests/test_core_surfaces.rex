objects=.array~new
objects~append(.AlchemyPackageId~new("probe","1"))
objects~append(.AlchemyRepositoryLease~new(selfRepo()))
objects~append(.AlchemyTransportSource~new("local-directory","/tmp"))
objects~append(.AlchemyDependencyFloor~new)
objects~append(.AlchemyExecutor~new)
objects~append(.AlchemyPublisher~new)
objects~append(.AlchemyOrchestrator~new)
objects~append(.AlchemyGitSubmissionSender~new)
objects~append(.AlchemyGitInbox~new)
objects~append(.AlchemyAutobuildEvidenceWriter~new)
objects~append(.AlchemyAutobuildServiceCycleResult~new(0,0,.array~new,.array~new))

do obj over objects
  if \obj~isA(.AlchemyObject) then raise syntax 88.900 array("core object does not inherit AlchemyObject: " || obj~class~id)
  if obj~alchemyObjectId="" then raise syntax 88.900 array("core object missing Alchemy identity: " || obj~class~id)
  d=obj~componentDescriptor
  if d["object_id"]<>obj~alchemyObjectId then raise syntax 88.900 array("component descriptor identity mismatch")
end

ring=.CryptoMacKeyRing~new
ring~addKey("core-test","000102030405060708090a0b0c0d0e0f")
sealer=.AlchemyMacSealer~new(ring)
base=.AlchemyCoreComponent~new("sealed-probe","0.5","sealed evidence probe",sealer)
envelope=base~sealPublicIntrospection
if \sealer~verify(envelope) then raise syntax 88.900 array("sealed public introspection did not verify")

say "PASS test_core_surfaces"
call cleanupSelfRepo
exit 0

selfRepo: procedure expose tempRepo
  tempRepo=SysTempFileName("/tmp/alchemy-core-surface-repo-??????")
  if tempRepo="" | SysMkDir(tempRepo)<>0 then raise syntax 88.900 array("core surface temp repo failed")
  address system "git init -q " || .AlchemyShell~quote(tempRepo)
  if rc<>0 then raise syntax 88.900 array("core surface git init failed")
  return tempRepo
cleanupSelfRepo: procedure expose tempRepo
  if tempRepo<>"" then address system "rm -rf -- " || .AlchemyShell~quote(tempRepo)
  return

::requires "AlchemyCoreComponent.cls"
::requires "AlchemyRepositoryLease.cls"
::requires "AlchemyPackageModel.cls"
::requires "AlchemyTransport.cls"
::requires "AlchemyDependencyFloor.cls"
::requires "AlchemyExecutor.cls"
::requires "AlchemyPublisher.cls"
::requires "AlchemyOrchestrator.cls"
::requires "AlchemySubmission.cls"
::requires "AlchemyInbox.cls"
::requires "AlchemyAutobuildEvidence.cls"
::requires "AlchemyAutobuildService.cls"
