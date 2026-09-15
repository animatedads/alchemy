parse arg packagePath
if packagePath="" then packagePath=directory()||"/semantic/federationbank_merchant_operations_v0.6.json"
p=.json~fromJsonFile(packagePath)
call assert p["packageId"]="FEDERATIONBANK_MERCHANT_OPERATIONS","package id"
call assert p["packageVersion"]="2026.09.01.1","package version"
call assert p["definitions"]~items=12,"twelve exact definitions"
call assert p["releaseRef"]["contentAddress"]~left(7)="sha512-","site release SHA-512 sealed"
feed=.FBMerchantWireProjectionFeed~new
r=.FBMerchantWireRuntimeFactory~buildFromPackage("FBM-PRECOMPILED","S-PRE","WEB",feed,p)
call assert r~ok,"server binds precompiled package without Builder authoring objects"
call assert r~value~siteReleaseBinding~releaseId="FEDERATIONBANK_MERCHANT_OPERATIONS","runtime exact release binding"
say "PASS Merchant precompiled deployment boundary"
exit 0
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "json.cls"
::requires "FBMerchantWireUIApplication.cls"
