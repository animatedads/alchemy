b=.FBMerchantWireUIDesignFixture~build
r=.WireUICompiler~new~compile(b["workspace"],b["release"])
call assert r~ok,"Merchant Wire UI release compiles"
call assert 12=r~value~definitions~items,"twelve exact Merchant operational definitions"
call assert r~value~releaseRef~artifactId="FEDERATIONBANK_MERCHANT_OPERATIONS","release identity"
call assert r~value~releaseRef~version="2026.09.01.1","release version"
found=.false
do d over r~value~definitions
  if d["definitionKey"]="FBM_EXECUTION_CHECKPOINT@1" then found=.true
end
call assert found,"execution checkpoint is compiled semantic definition"
say "PASS Merchant Wire UI Builder release compiles"
exit 0
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "FBMerchantWireUIDesignFixture.cls"
