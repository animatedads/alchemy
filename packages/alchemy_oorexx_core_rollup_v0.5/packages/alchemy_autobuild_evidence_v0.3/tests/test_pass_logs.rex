s=.EvidenceTestSupport
root=s~tempDir("evidence-pass")
repo=s~initRepo(root)
subject=.AlchemyAutobuildEvidenceSubject~new("S-002","git-branch","origin/x","cafebabe","tree002","CHATGPT")
out=.AlchemyAutobuildEvidenceOutcome~new(subject,"PASS",.FakeOrchestration~new,"","","2026-08-23T10:01:00.000Z","2026-08-23T10:01:01.000Z")
wr=.AlchemyAutobuildEvidenceWriter~new~record(repo,out)
s~assertEq("RECORDED",wr~status,"record status")
doc=s~readJsonFromMain(repo,wr~resultPath)
s~assertEq("demo@1.0",doc["package"]["key"],"package key")
s~assertEq(1,doc["tests"]~items,"test count")
s~assertEq(0,doc["tests"][1]["returncode"],"return code")
stdoutPath=doc["tests"][1]["stdout_path"]
text=.AlchemyCommandRunner~new~require(.array~of("git","show","refs/remotes/origin/main:" || stdoutPath),repo,"stdout evidence")~stdout
s~assertEq("hello" || "0a"x,text,"stdout persisted")
say "PASS test_pass_logs"
exit 0
::requires "EvidenceTestSupport.cls"
::requires "EvidenceFakes.cls"
::requires "AlchemyAutobuildEvidence.cls"
