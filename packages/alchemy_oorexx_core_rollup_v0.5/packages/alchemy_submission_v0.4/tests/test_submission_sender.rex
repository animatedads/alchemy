s=.SubmissionTestSupport; runner=.AlchemyCommandRunner~new; base=s~tempDir; bare=base || "/remote.git"; repo=base || "/repo"
s~mkdir(bare); runner~require(.array~of("git","init","-q","--bare",bare),base)
/* Count actual receive operations. */
hook=bare || "/hooks/post-receive"; s~write(hook,'echo push >> "' || bare || '/push-count"' || "0a"x); runner~require(.array~of("chmod","+x",hook),base)
runner~require(.array~of("git","clone","-q",bare,repo),base); runner~require(.array~of("git","checkout","-q","-b","main"),repo)
runner~require(.array~of("git","config","user.email","test@example.invalid"),repo); runner~require(.array~of("git","config","user.name","Submit Test"),repo)
s~write(repo || "/README.md","base" || "0a"x); runner~require(.array~of("git","add","README.md"),repo); runner~require(.array~of("git","commit","-q","-m","base"),repo); runner~require(.array~of("git","push","-q","-u","origin","main"),repo)
/* Ignore initial main push; sender itself must cause exactly one more. */
s~write(bare || "/push-count","")
s~write(repo || "/LOCAL_DIRT.txt","DIRTY" || "0a"x); statusBefore=runner~require(.array~of("git","status","--porcelain"),repo)~stdout; headBefore=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),repo)~stdout)

pkg=base || "/pkg"; s~mkdir(pkg || "/tests")
s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"senderprobe","version":"1"},"tests":[{"name":"noop","argv":["rexx","tests/noop.rex"]}],"publish":{"tree":{"source":".","path":"packages/senderprobe_v1"}}}')
s~write(pkg || "/tests/noop.rex",'exit 0' || "0a"x)
binary='00ff10203000a5'x; s~write(pkg || "/payload.bin",binary)

sid="20260822T153000Z-TEST-senderprobe"
send=.AlchemyGitSubmissionSender~new(runner)~submit(repo,pkg,"TEST",sid)
s~eq(sid,send~submissionId,"submission id"); s~eq("autobuild-submit/" || sid,send~branch,"branch")
runner~require(.array~of("git","fetch","-q","origin","+refs/heads/" || send~branch || ":refs/remotes/origin/" || send~branch),repo)
ref="refs/remotes/origin/" || send~branch
count=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-list","--count","refs/remotes/origin/main.." || ref),repo)~stdout); s~eq("2",count,"two logical commits")
parent=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse",ref || "^"),repo)~stdout); s~eq(send~bodyCommit,parent,"ready commit parent is body")
readyAbsent=runner~run(.array~of("git","cat-file","-e",parent || ":autobuild/inbox/" || sid || "/ready.json"),repo); s~true(readyAbsent~rc<>0,"ready absent from body commit")
bodyPresent=runner~run(.array~of("git","cat-file","-e",parent || ":autobuild/inbox/" || sid || "/package/integration.json"),repo); s~eq(0,bodyPresent~rc,"body present before ready")
readyPresent=runner~run(.array~of("git","cat-file","-e",ref || ":autobuild/inbox/" || sid || "/ready.json"),repo); s~eq(0,readyPresent~rc,"ready present final")
showBin=runner~require(.array~of("git","show",ref || ":autobuild/inbox/" || sid || "/package/payload.bin"),repo)~stdout; s~eq(binary,showBin,"binary preserved")
pushes=.AlchemyTransportText~lines(.AlchemyTransportFs~readFile(bare || "/push-count")); s~eq(1,pushes~items,"one sender push")
statusAfter=runner~require(.array~of("git","status","--porcelain"),repo)~stdout; headAfter=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),repo)~stdout)
s~eq(statusBefore,statusAfter,"dirty checkout unchanged"); s~eq(headBefore,headAfter,"checkout HEAD unchanged")
s~remove(base); say "PASS test_submission_sender"; exit 0
::requires "AlchemySubmission.cls"
::requires "SubmissionTestSupport.cls"
