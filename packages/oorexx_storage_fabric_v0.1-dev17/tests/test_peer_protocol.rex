call addpath
ref=.StorageRef~new("object-1","sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
tmp=SysTempFileName("/tmp/storage-peer-proto-??????")
call charout tmp,"0123456789abcdef"
call stream tmp,"c","close"
reg=.StoragePeerExportRegistry~new
reg~publish(.StoragePeerExport~new(ref,16,.StoragePeerLocalFileSourceFactory~new(tmp),"application/octet-stream"))
service=.StoragePeerService~new("B",reg,8)
transport=.StoragePeerInProcessTransport~new~bind("B",service)
client=.StoragePeerClient~new("A",transport)
hello=client~hello("B"); call ok hello<>.nil & hello["status"]="OK","HELLO"
have=client~have("B",ref); call ok have["payload"]["disposition"]="AVAILABLE","HAVE available"
missing=.StorageRef~new("missing",ref~digest)
h=client~have("B",missing); call ok h["payload"]["disposition"]="NOT_PRESENT","HAVE missing"
stat=client~stat("B",ref); call ok stat["payload"]["size_bytes"]=16,"STAT size"
r=client~read("B",ref,4,8); call ok x2c(r["payload"]["data_hex"])= "456789ab","READ exact bounded bytes"
bad=client~read("B",ref,0,9); call ok bad["status"]="ERROR" & bad["code"]="READ_RANGE_INVALID","READ bound enforced"
boundReq=.StoragePeerCodec~newRequest("bound-1","A","B",.StoragePeerOperation~HAVE,ref)
boundOk=service~handleFrom("A",boundReq); call ok boundOk["status"]="OK","authenticated peer binding accepts matching from_node"
boundBad=service~handleFrom("C",boundReq); call ok boundBad["status"]="ERROR" & boundBad["code"]="PEER_IDENTITY_MISMATCH","authenticated peer binding rejects forged from_node"
call SysFileDelete tmp
say "PASS Storage peer protocol identity/HAVE/STAT/bounded READ"
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