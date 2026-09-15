s=.OrchestratorTestSupport; base=s~tempDir; setup=s~initRepo(base); runner=setup[1]; repo=setup[3]

/* Establish a local main which will deliberately become stale. */
s~write(repo || "/README.md","base" || "0a"x)
runner~require(.array~of("git","add","README.md"),repo)
runner~require(.array~of("git","commit","-q","-m","base"),repo)
runner~require(.array~of("git","push","-q","-u","origin","main"),repo)
baseHead=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),repo)~stdout)

/* Advance accepted remote main in a separate worktree with the dependency.
 * The ordinary checkout intentionally remains at baseHead and cannot resolve it. */
accept=base || "/accept"
runner~require(.array~of("git","worktree","add","-q","--detach",accept,"refs/remotes/origin/main"),repo)
s~write(accept || "/packages/depprobe_v1/src/DepMarker.cls", '::class DepMarker public' || "0a"x || '::constant VALUE "DEPENDENCY_OK"' || "0a"x)
runner~require(.array~of("git","add","packages"),accept)
runner~require(.array~of("git","config","user.email","test@example.invalid"),accept)
runner~require(.array~of("git","config","user.name","Alchemy Test"),accept)
runner~require(.array~of("git","commit","-q","-m","accepted dependency"),accept)
runner~require(.array~of("git","push","-q","origin","HEAD:refs/heads/main"),accept)
runner~require(.array~of("git","worktree","remove","--force",accept),repo)
runner~require(.array~of("git","fetch","-q","origin","+refs/heads/main:refs/remotes/origin/main"),repo)

/* Build a submission branch in a separate worktree. */
sid="20260822T150000Z-TEST-orchestrator"
branch="autobuild-submit/" || sid
wt=base || "/submit"
runner~require(.array~of("git","worktree","add","-q","-b",branch,wt,"refs/remotes/origin/main"),repo)
manifest='{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"orchprobe","version":"1","kind":"oorexx"},"dependencies":[{"name":"depprobe","version":"1","export":"DEP_ROOT"}],"tests":[{"name":"probe","argv":["rexx","tests/probe.rex"],"environment":{"require_dirs":["DEP_ROOT"],"report":["DEP_ROOT"]}}],"publish":{"tree":{"source":".","path":"packages/orchprobe_v1"}}}'
s~write(wt || "/autobuild/inbox/" || sid || "/package/integration.json",manifest)
s~write(wt || "/autobuild/inbox/" || sid || "/package/payload.txt","ORCHESTRATED" || "0a"x)
probe='if .DepMarker~VALUE <> "DEPENDENCY_OK" then raise syntax 88.900 array("dependency not loaded")' || "0a"x || -
      'root=value("DEP_ROOT",,"ENVIRONMENT")' || "0a"x || -
      'if root="" then raise syntax 88.900 array("DEP_ROOT absent")' || "0a"x || -
      'say "PASS orchestrated dependency=" || root' || "0a"x || -
      'exit 0' || "0a"x || -
      '::requires "DepMarker.cls"' || "0a"x
s~write(wt || "/autobuild/inbox/" || sid || "/package/tests/probe.rex",probe)
ready='{"schema":"alchemy.autobuild.git-submission/0.1","submission_id":"' || sid || '","submitted_by":"TEST","package_path":"package"}'
s~write(wt || "/autobuild/inbox/" || sid || "/ready.json",ready)
runner~require(.array~of("git","add","autobuild/inbox/" || sid),wt)
runner~require(.array~of("git","commit","-q","-m","submission ready"),wt)
runner~require(.array~of("git","push","-q","origin","HEAD:refs/heads/" || branch),wt)
runner~require(.array~of("git","fetch","-q","origin","+refs/heads/" || branch || ":refs/remotes/origin/" || branch),repo)
runner~require(.array~of("git","worktree","remove","--force",wt),repo)

/* Deliberately dirty ordinary checkout. */
s~write(repo || "/LOCAL_DIRT.txt","DO NOT TOUCH" || "0a"x)
statusBefore=runner~require(.array~of("git","status","--porcelain"),repo)~stdout
headBefore=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),repo)~stdout)

workspace=base || "/workspace"; s~mkdir(workspace)
orchResult=.AlchemyOrchestrator~new(runner)~processGitSubmission(repo,"refs/remotes/origin/" || branch,sid,workspace)
s~eq("PASS",orchResult~status,"orchestration status")
s~eq("PASS",orchResult~execution~status,"execution status")
s~eq("PUBLISHED",orchResult~publication~status,"publication status")
s~true(orchResult~execution~tests[1]~process~stdout~pos("PASS orchestrated dependency=")>0,"probe stdout")
remotePayload=runner~require(.array~of("git","show","origin/main:packages/orchprobe_v1/payload.txt"),repo)~stdout
s~eq("ORCHESTRATED" || "0a"x,remotePayload,"remote published payload")
statusAfter=runner~require(.array~of("git","status","--porcelain"),repo)~stdout
headAfter=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),repo)~stdout)
s~eq(statusBefore,statusAfter,"dirty checkout unchanged")
s~eq(headBefore,headAfter,"ordinary HEAD unchanged")
s~eq(baseHead,headAfter,"ordinary checkout stayed at base main")

s~remove(base); say "PASS test_git_pipeline"; exit 0
::requires "AlchemyOrchestrator.cls"
::requires "OrchestratorTestSupport.cls"
