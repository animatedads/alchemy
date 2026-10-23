call addpath
surface=.FakeStorageSurface~new
a=.StorageMeshAuthority~new("storage.fabric.primary","A","ACTIVE",9,21)
port=.StorageIntentionPort~new(surface,a)
intents=port~discover
call ok has(intents,.StorageIntentionName~STATUS),"status intention"
call ok has(intents,.StorageIntentionName~SEARCH),"search intention"
call ok has(intents,.StorageIntentionName~BIND),"ACTIVE advertises namespace mutation"
call ok has(intents,.StorageIntentionName~REPLICA_EVICT),"replica safety administration"
call ok has(intents,.StorageIntentionName~CHECKPOINT_MOVE),"migratable checkpoint storage intention"
call ok has(intents,.StorageIntentionName~MEDIA_IMPORT),"media import"
call ok has(intents,.StorageIntentionName~PEER_PUBLISH),"mesh peer publication"
args=.directory~new; args["PATH"]="/live/x"; args["OBJECT"]="obj-x"
r=port~invoke(.StorageIntentionName~BIND,args,.nil,9)
call ok r["ok"] & surface~lastOperation="namespace.bind","dispatch to resident authority surface"
r=port~invoke(.StorageIntentionName~BIND,args,.nil,8)
call ok \r["ok"] & r["code"]="EPOCH_MISMATCH","stale caller fenced"
ignore=a~setReplicaRole("SPARE",10)
intents=port~discover
call ok has(intents,.StorageIntentionName~STATUS),"SPARE keeps read intentions"
call ok \has(intents,.StorageIntentionName~BIND),"SPARE dynamically hides mutations"
r=port~invoke(.StorageIntentionName~BIND,args,.nil,10)
call ok \r["ok"] & r["code"]="UNAVAILABLE","hidden intention cannot dispatch"
say "PASS comprehensive dynamic Storage intentions / ACTIVE-SPARE gating"
exit 0
has: procedure
  use strict arg intents,name
  do i over intents; if i~name=name then return .true; end
  return .false
ok: procedure
  parse arg truth,label
  if truth then return
  say "FAIL" label; exit 1
addpath: return
::class FakeStorageSurface public
::attribute lastOperation get
::method capabilities
  d=.directory~new
  do k over .array~of("STATUS","SEARCH","CAPACITY","PROVIDERS","OBJECT","LOCATIONS","NAMESPACE","PEERS","REPLICA","TRANSFER","NAMESPACE_WRITE","PROVIDER_ADMIN","REPLICA_WRITE","SNAPSHOT","TRANSFER_WRITE","MEDIA","CHECKPOINT","PEER_ADMIN")
    d[k]=.true
  end
  return d
::method invokeStorageIntention
  expose lastOperation
  use strict arg operation,args=.nil,context=.nil
  lastOperation=operation
  d=.directory~new; d["ok"]=.true; d["operation"]=operation; d["arguments"]=args; return d
::requires "src/StorageIntentions.cls"
