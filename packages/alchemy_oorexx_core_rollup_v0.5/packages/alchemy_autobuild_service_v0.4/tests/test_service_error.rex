s=.ServiceTestSupport
root=s~tempDir("service-error")
repo=s~initRepo(root)
s~addBrokenDependencySubmission(repo,"SERVICE-ERROR")
cycle=.AlchemyAutobuildService~new(repo,1)~runOnce
s~assertEq(1,cycle~processed,"error processed")
s~assertEq("ERROR",cycle~results[1]~status,"error status")
receipt=s~remoteJson(repo,"autobuild/receipts/SERVICE-ERROR.json")
s~assertEq("ERROR",receipt["status"],"error receipt")
result=s~remoteJson(repo,receipt["result_path"])
s~assertTrue(result["error_message"]~pos("unresolved dependency")>0,"dependency error recorded")
say "PASS test_service_error"
exit 0
::requires "ServiceTestSupport.cls"
::requires "AlchemyAutobuildService.cls"
