s=.ServiceTestSupport
root=s~tempDir("service-fail")
repo=s~initRepo(root)
s~addPackageSubmission(repo,"SERVICE-FAIL",.false,.false)
cycle=.AlchemyAutobuildService~new(repo,1)~runOnce
s~assertEq(1,cycle~processed,"failure processed")
s~assertEq("FAIL",cycle~results[1]~status,"failure status")
s~assertTrue(\s~remoteHas(repo,"packages/service_probe_v0.1/integration.json"),"failed package not published")
receipt=s~remoteJson(repo,"autobuild/receipts/SERVICE-FAIL.json")
s~assertEq("FAIL",receipt["status"],"failure receipt")
result=s~remoteJson(repo,receipt["result_path"])
s~assertEq(7,result["tests"][1]["returncode"],"failing return code recorded")
say "PASS test_service_fail"
exit 0
::requires "ServiceTestSupport.cls"
::requires "AlchemyAutobuildService.cls"
