::class ServiceTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-service"
  p=SysTempFileName("/tmp/" || prefix || "-??????")
  if p="" | SysMkDir(p)<>0 then raise syntax 88.900 array("temp dir failed")
  return p

::method write class
  use strict arg path,data
  parent=filespec("D",path) || filespec("P",path)
  if parent<>"" then address system "mkdir -p -- " || .AlchemyShell~quote(parent)
  s=.stream~new(path); s~open("write replace"); s~charout(data); s~close

::method sh class
  use strict arg cmd
  address system cmd
  if rc<>0 then raise syntax 88.900 array("command failed rc=" || rc || ": " || cmd)

::method initRepo class
  use strict arg root
  remote=root || "/remote.git"; repo=root || "/repo"
  self~sh("git init --bare -q " || .AlchemyShell~quote(remote))
  self~sh("git clone -q " || .AlchemyShell~quote(remote) || " " || .AlchemyShell~quote(repo))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " config user.email test@example.invalid")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " config user.name ServiceTest")
  self~write(repo || "/README.md","seed" || "0a"x)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add README.md")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m seed")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " branch -M main")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q -u origin main")
  self~sh("git -C " || .AlchemyShell~quote(remote) || " symbolic-ref HEAD refs/heads/main")
  return repo

::method addPackageSubmission class
  use strict arg repo, id, shouldPass=.true, artifactOnly=.false
  branch="autobuild-submit/" || id
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q -B " || .AlchemyShell~quote(branch) || " origin/main")
  base=repo || "/autobuild/inbox/" || id || "/package"
  self~write(base || "/tests/test.rex",self~testProgram(shouldPass))
  doc=.directory~new
  doc["schema"]="alchemy.autobuild.integration/0.3"
  pkg=.directory~new; pkg["name"]="service_probe"; pkg["version"]="0.1"; pkg["kind"]="oorexx"; doc["package"]=pkg
  tests=.array~new; t=.directory~new; t["name"]="acceptance"; t["argv"]=.array~of("rexx","tests/test.rex"); t["timeout_seconds"]=30; tests~append(t); doc["tests"]=tests
  publish=.directory~new
  if artifactOnly then publish["artifact_only"]=.true
  else do; tree=.directory~new; tree["source"]="."; tree["path"]="packages/service_probe_v0.1"; publish["tree"]=tree; end
  doc["publish"]=publish
  .JSON~toJsonFile(base || "/integration.json",doc,.true)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add " || .AlchemyShell~quote("autobuild/inbox/" || id || "/package"))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m body")
  ready=.directory~new; ready["schema"]="alchemy.autobuild.git-submission/0.1"; ready["submission_id"]=id; ready["submitted_by"]="CHATGPT"; ready["package_path"]="package"
  .JSON~toJsonFile(repo || "/autobuild/inbox/" || id || "/ready.json",ready,.true)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add " || .AlchemyShell~quote("autobuild/inbox/" || id || "/ready.json"))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m ready")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q origin HEAD:refs/heads/" || .AlchemyShell~quote(branch))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q main")

::method addBrokenDependencySubmission class
  use strict arg repo, id
  branch="autobuild-submit/" || id
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q -B " || .AlchemyShell~quote(branch) || " origin/main")
  base=repo || "/autobuild/inbox/" || id || "/package"
  self~write(base || "/tests/test.rex",'exit 0' || "0a"x)
  doc=.directory~new; doc["schema"]="alchemy.autobuild.integration/0.3"
  pkg=.directory~new; pkg["name"]="broken_probe"; pkg["version"]="0.1"; pkg["kind"]="oorexx"; doc["package"]=pkg
  deps=.array~new; dep=.directory~new; dep["name"]="missing_dependency"; dep["version"]="9.9"; deps~append(dep); doc["dependencies"]=deps
  tests=.array~new; t=.directory~new; t["name"]="acceptance"; t["argv"]=.array~of("rexx","tests/test.rex"); tests~append(t); doc["tests"]=tests
  pub=.directory~new; pub["artifact_only"]=.true; doc["publish"]=pub
  .JSON~toJsonFile(base || "/integration.json",doc,.true)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add " || .AlchemyShell~quote("autobuild/inbox/" || id || "/package"))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m body")
  ready=.directory~new; ready["schema"]="alchemy.autobuild.git-submission/0.1"; ready["submission_id"]=id; ready["submitted_by"]="CHATGPT"; ready["package_path"]="package"
  .JSON~toJsonFile(repo || "/autobuild/inbox/" || id || "/ready.json",ready,.true)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add " || .AlchemyShell~quote("autobuild/inbox/" || id || "/ready.json"))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m ready")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q origin HEAD:refs/heads/" || .AlchemyShell~quote(branch))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q main")

::method testProgram class
  use strict arg shouldPass
  if shouldPass then return 'say "SERVICE TEST PASS"' || "0a"x || 'exit 0' || "0a"x
  return 'say "SERVICE TEST FAIL"' || "0a"x || 'exit 7' || "0a"x

::method remoteHas class
  use strict arg repo,rel
  runner=.AlchemyCommandRunner~new
  runner~require(.array~of("git","fetch","origin","+refs/heads/main:refs/remotes/origin/main"),repo,"remote has fetch")
  r=runner~run(.array~of("git","cat-file","-e","refs/remotes/origin/main:" || rel),repo)
  return r~rc=0

::method remoteJson class
  use strict arg repo,rel
  runner=.AlchemyCommandRunner~new
  runner~require(.array~of("git","fetch","origin","+refs/heads/main:refs/remotes/origin/main"),repo,"remote JSON fetch")
  text=runner~require(.array~of("git","show","refs/remotes/origin/main:" || rel),repo,"remote JSON read")~stdout
  return .JSON~fromJSON(text)

::method head class
  use strict arg repo
  return .AlchemyTransportText~firstLine(.AlchemyCommandRunner~new~require(.array~of("git","rev-parse","HEAD"),repo,"local head")~stdout)

::method assertEq class
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)

::method assertTrue class
  use strict arg condition,label
  if \condition then raise syntax 88.900 array("FAIL " || label)

::requires "AlchemyTransport.cls"
::requires "json.cls"
