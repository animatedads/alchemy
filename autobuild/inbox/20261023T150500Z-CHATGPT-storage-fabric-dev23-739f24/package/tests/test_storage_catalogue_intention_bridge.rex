/* Native test of dynamic catalogue intentions and Management discovery. */
mesh=.StorageMeshAuthority~new("storage.fabric","ed209c","ACTIVE",12,1)
base=.StorageIntentionPort~new(.FakeBaseSurface~new,mesh)
command=.FakeCommand~new
caps=.FakeCaps~new
port=.StorageCatalogueIntentionPort~new(base,command,mesh,caps)
source=.StorageCatalogueManagementSource~new(port)
snap = source~discover
call require has(snap,.StorageCatalogueIntentionName~LIST),"list offered"
call require \has(source~discover,.StorageCatalogueIntentionName~ADD),"add absent until capability enabled"
caps~set("ADD",.true)
call require has(source~discover,.StorageCatalogueIntentionName~ADD),"add appears dynamically"
call require source~assessRelevance("find my video",source~discover)~relevant,"Management relevance selection"
call require \source~assessRelevance("change the clock",source~discover)~relevant,"unrelated query not selected"
args=.directory~new;args["SOURCE"]="/test/video.mp4";args["VIRTUAL"]="/videos/video.mp4";args["CONFIRMED"]=.true
actionReply=port~invoke(.StorageCatalogueIntentionName~ADD,args,.nil,11)
call require actionReply["code"]="EPOCH_MISMATCH","fence stale epoch"
actionReply=port~invoke(.StorageCatalogueIntentionName~ADD,args,.nil,.nil)
call require actionReply["code"]="EPOCH_REQUIRED","mutations require explicit epoch"
args["CONFIRMED"]=.false
actionReply=port~invoke(.StorageCatalogueIntentionName~ADD,args,.nil,12)
call require actionReply["code"]="CONFIRMATION_REQUIRED","confirmation mandatory"
args["CONFIRMED"]=.true
actionReply=port~invoke(.StorageCatalogueIntentionName~ADD,args,.nil,12)
call require actionReply["ok"] & command~last="ADD","confirmed operation dispatched"
args2=.directory~new;args2["VIRTUAL"]="/videos/video.mp4";args2["CONFIRMED"]=.true
caps~set("REMOVE",.true)
actionReply=port~invoke(.StorageCatalogueIntentionName~REMOVE,args2,.nil,12)
call require actionReply["ok"] & command~forgetValue==.false,"remove never forgets physical copy"
caps~set("ENSURE_AZURE",.true)
call require has(source~discover,.StorageCatalogueIntentionName~ENSURE),"Azure intent available after provider activation"
caps~set("ENSURE_AZURE",.false)
call require \has(source~discover,.StorageCatalogueIntentionName~ENSURE),"provider withdrawal disappears on next discovery"
argsAzure=.directory~new;argsAzure["OBJECT"]="sha256:video";argsAzure["CONFIRMED"]=.true
r=port~invoke(.StorageCatalogueIntentionName~ENSURE,argsAzure,.nil,12)
call require r["code"]="UNAVAILABLE","provider withdrawal rejects dispatch"
caps~set("ENSURE_AZURE",.true)
r=port~invoke(.StorageCatalogueIntentionName~ENSURE,argsAzure,.nil,12)
call require r["ok"] & command~last="ENSURE","confirmed Azure intent uses existing command backend"
call require \has(source~discover,.StorageCatalogueIntentionName~MATERIALISE),"transport unavailable hides materialise"
call require source~assessRelevance("backup file to azure git",source~discover)~relevant,"Azure backup selected"
mgmt=.ManagementIntentionDirectory~new
mgmt~registerSource(source)
r=mgmt~resolve("please locate the video recording")
call require r~relevantCandidates~items=1,"Management dev8 discovers Storage specialist dynamically"
r=mgmt~resolve("what time is it")
call require r~relevantCandidates~items=0,"Management leaves other domains alone"

ignore=mesh~setReplicaRole("SPARE",13)
call require \has(source~discover,.StorageCatalogueIntentionName~ENSURE),"SPARE hides mutating intentions"
actionReply=port~invoke(.StorageCatalogueIntentionName~ADD,args,.nil,13)
call require actionReply["code"]="UNAVAILABLE","SPARE rejects action"
call require has(source~discover,.StorageCatalogueIntentionName~LOCATE),"SPARE retains reads"
say "PASS dynamic Storage catalogue intentions / confirmations / epoch / Management relevance"
exit 0
has: procedure
 use strict arg descriptors,n
 do d over descriptors
   if d~name=n then return .true
 end
 return .false
require: procedure
 use strict arg ok,label
 if ok then return
 say "FAIL" label
 exit 1
::class FakeBaseSurface
::method capabilities
 d=.directory~new;return d
::method invokeStorageIntention
 use arg operation,args=.nil,context=.nil
 d=.directory~new;d["ok"]=.true;d["code"]="OK";return d
::class FakeCaps
::method init
 expose d
 d=.directory~new
 d["LIST"]=.true;d["FIND"]=.true;d["LOCATE"]=.true
::method set
 expose d
 use arg n,v
 d[n]=v
::method capabilities
 expose d
 use arg context=.nil
 return d
::class FakeCommand
::attribute last get
::attribute forgetValue get
::method init
 expose last forgetValue
 last="";forgetValue=.nil
::method objects
 return .array~new
::method addFile
 expose last
 use arg a,b,c,d,e,f,g,h
 last="ADD";return self~ok
::method ensureAzure
 expose last
 use arg key
 last="ENSURE";return self~ok
::method removeBinding
 expose last forgetValue
 use arg path,ns,forget
 last="REMOVE";forgetValue=forget;return self~ok
::method ok
 d=.directory~new;d["ok"]=.true;d["code"]="OK";return d
::requires "src/StorageCatalogueIntentionBridge.cls"
::requires "ManagementIntentionDiscovery.cls"
