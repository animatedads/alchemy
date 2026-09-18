call addpath
src=SysTempFileName("/tmp/storage-peer-src-??????")
dst=SysTempFileName("/tmp/storage-peer-dst-??????")
call SysFileDelete dst
payload=copies("StoragePeer-",40000)
call charout src,payload
call stream src,"c","close"
ver=.StoragePosixSha256Verifier~new
digest=ver~digestFile(src)
call ok digest<>"","source SHA-256"
ref=.StorageRef~new("peer-object","sha256:"||digest)
reg=.StoragePeerExportRegistry~new
reg~publish(.StoragePeerExport~new(ref,payload~length,.StoragePeerLocalFileSourceFactory~new(src)))
transport=.StoragePeerInProcessTransport~new~bind("B",.StoragePeerService~new("B",reg,65536))
client=.StoragePeerClient~new("A",transport)
mr=.StoragePeerMaterialiser~new(32768)~materialise(client,"B",ref,dst)
call ok mr~ok,"verified materialise"
call ok mr~bytes=payload~length,"byte count"
call ok ver~digestFile(dst)=digest,"destination digest"
catalogue=.StorageCatalogue~new
admit=.StoragePeerReplicaAdmission~new~admit(catalogue,"B",mr,"peer-cache","ed209b-root")
call ok admit~ok & admit~code="ADMITTED","verified peer materialisation admitted"
call ok catalogue~get(ref~objectId)<>.nil,"catalogue object created"
loc=admit~location
call ok loc~verified & loc~nodeId="B","admitted location verified and node-bound"
call ok loc~safetyClass=.StorageSafetyClass~DISPOSABLE & loc~lifecycleState=.StorageLifecycleState~TEMPORARY,"peer cache is not silently durable"
call ok \loc~countsAsDurable,"default peer cache excluded from durable replica count"
existsResult=.StoragePeerMaterialiser~new(32768)~materialise(client,"B",ref,dst)
call ok \existsResult~ok & existsResult~code="TARGET_EXISTS","peer transfer does not clobber an existing materialisation"
call ok ver~digestFile(dst)=digest,"existing verified target preserved"
/* Deliberately wrong identity must never leave an admitted target behind. */
bad=.StorageRef~new("peer-object-bad","sha256:"||copies("0",64))
reg~publish(.StoragePeerExport~new(bad,payload~length,.StoragePeerLocalFileSourceFactory~new(src)))
badDst=dst||".bad"; call SysFileDelete badDst
badResult=.StoragePeerMaterialiser~new(32768)~materialise(client,"B",bad,badDst)
call ok \badResult~ok & badResult~code="DIGEST_MISMATCH","digest mismatch rejected"
badAdmit=.StoragePeerReplicaAdmission~new~admit(catalogue,"B",badResult)
call ok \badAdmit~ok & badAdmit~code="UNVERIFIED_MATERIALISATION","unverified peer bytes cannot be admitted"
call ok stream(badDst,"c","query exists")="","bad target removed"
call SysFileDelete src; call SysFileDelete dst
say "PASS Storage peer verified materialisation / fail-closed digest admission"
exit 0
ok: procedure
  parse arg truth,label
  if truth then return
  say "FAIL" label
  exit 1
addpath:
  here=directory()
  call value "REXX_PATH",here||"/src"||":"||value("REXX_PATH",,"ENVIRONMENT"),"ENVIRONMENT"
  return
::requires "StoragePeer.cls"