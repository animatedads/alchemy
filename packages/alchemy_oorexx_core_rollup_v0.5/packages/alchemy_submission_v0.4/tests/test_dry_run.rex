s=.SubmissionTestSupport; runner=.AlchemyCommandRunner~new; base=s~tempDir; repo=base || "/repo"; s~mkdir(repo); runner~require(.array~of("git","init","-q",repo),base)
pkg=base || "/pkg"; s~mkdir(pkg || "/tests"); s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"dryprobe","version":"1"},"tests":[{"name":"n","argv":["rexx","tests/n.rex"]}],"publish":{"artifact_only":true}}'); s~write(pkg || "/tests/n.rex",'exit 0' || "0a"x)
send=.AlchemyGitSubmissionSender~new(runner)~submit(repo,pkg,"CHATGPT","fixed-dry-run",.true)
s~true(send~dryRun,"dry run flag"); s~eq("fixed-dry-run",send~submissionId,"dry run id")
branches=runner~require(.array~of("git","branch","--format=%(refname:short)"),repo)~stdout; s~eq("",branches,"dry run created no branch")
s~remove(base); say "PASS test_dry_run"; exit 0
::requires "AlchemySubmission.cls"
::requires "SubmissionTestSupport.cls"
