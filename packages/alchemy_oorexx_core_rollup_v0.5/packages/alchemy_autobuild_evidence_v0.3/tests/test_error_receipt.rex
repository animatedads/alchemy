s=.EvidenceTestSupport
root=s~tempDir("evidence-error")
repo=s~initRepo(root)
subject=.AlchemyAutobuildEvidenceSubject~new("S-001","git-branch","refs/remotes/origin/autobuild-submit/S-001","deadbeef","tree001","CHATGPT")
out=.AlchemyAutobuildEvidenceOutcome~new(subject,"ERROR",.nil,"SYNTAX","synthetic failure","2026-08-23T10:00:00.000Z","2026-08-23T10:00:01.000Z")
w=.AlchemyAutobuildEvidenceWriter~new
wr=w~record(repo,out)
s~assertEq("RECORDED",wr~status,"record status")
s~assertTrue(w~receiptExists(repo,"S-001"),"receipt exists")
receipt=s~readJsonFromMain(repo,wr~receiptPath)
s~assertEq("ERROR",receipt["status"],"receipt terminal status")
result=s~readJsonFromMain(repo,wr~resultPath)
s~assertEq("synthetic failure",result["error_message"],"error message")
head1=.AlchemyTransportText~firstLine(.AlchemyCommandRunner~new~require(.array~of("git","rev-parse","refs/remotes/origin/main"),repo,"head")~stdout)
wr2=w~record(repo,out)
s~assertEq("EXISTING",wr2~status,"existing suppress")
head2=.AlchemyTransportText~firstLine(.AlchemyCommandRunner~new~require(.array~of("git","rev-parse","refs/remotes/origin/main"),repo,"head")~stdout)
s~assertEq(head1,head2,"existing receipt no commit")
say "PASS test_error_receipt"
exit 0
::requires "EvidenceTestSupport.cls"
::requires "AlchemyAutobuildEvidence.cls"
