s=.ServiceTestSupport
root=s~tempDir("service-pass")
repo=s~initRepo(root)
s~addPackageSubmission(repo,"SERVICE-PASS",.true,.false)
/* Deliberately dirty ordinary checkout; service must not clean or move it. */
s~write(repo || "/DIRTY.txt","keep me" || "0a"x)
localHead=s~head(repo)
service=.AlchemyAutobuildService~new(repo,1)
cycle=service~runOnce
s~assertEq(1,cycle~processed,"first cycle processed")
s~assertEq("PASS",cycle~results[1]~status,"service pass status")
s~assertTrue(s~remoteHas(repo,"packages/service_probe_v0.1/integration.json"),"package published")
s~assertTrue(s~remoteHas(repo,"autobuild/receipts/SERVICE-PASS.json"),"receipt written")
receipt=s~remoteJson(repo,"autobuild/receipts/SERVICE-PASS.json")
s~assertEq("PASS",receipt["status"],"receipt pass")
s~assertTrue(s~remoteHas(repo,receipt["result_path"]),"result written")
s~assertEq(localHead,s~head(repo),"local head unchanged")
s~assertEq("keep me" || "0a"x,.AlchemyTransportFs~readFile(repo || "/DIRTY.txt"),"dirty file retained")
remoteHead1=.AlchemyTransportText~firstLine(.AlchemyCommandRunner~new~require(.array~of("git","rev-parse","refs/remotes/origin/main"),repo,"remote head")~stdout)
cycle2=service~runOnce
s~assertEq(0,cycle2~processed,"second cycle suppressed")
.AlchemyCommandRunner~new~require(.array~of("git","fetch","origin","+refs/heads/main:refs/remotes/origin/main"),repo,"final fetch")
remoteHead2=.AlchemyTransportText~firstLine(.AlchemyCommandRunner~new~require(.array~of("git","rev-parse","refs/remotes/origin/main"),repo,"remote head2")~stdout)
s~assertEq(remoteHead1,remoteHead2,"no second-cycle commit")
say "PASS test_service_pass_idempotent"
exit 0
::requires "ServiceTestSupport.cls"
::requires "AlchemyAutobuildService.cls"
