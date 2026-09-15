::class InboxTestSupport public
::method tempDir class
  use strict arg prefix="alchemy-inbox"
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
  self~sh("git -C " || .AlchemyShell~quote(repo) || " config user.name InboxTest")
  self~write(repo || "/README.md","seed" || "0a"x)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add README.md")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m seed")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " branch -M main")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q -u origin main")
  self~sh("git -C " || .AlchemyShell~quote(remote) || " symbolic-ref HEAD refs/heads/main")
  return repo

::method addSubmission class
  use strict arg repo, submissionId, branch="", payload="payload", submittedBy="CHATGPT"
  if branch="" then branch="autobuild-submit/" || submissionId
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q -B " || .AlchemyShell~quote(branch) || " origin/main")
  base=repo || "/autobuild/inbox/" || submissionId
  self~write(base || "/package/integration.json",'{"schema":"alchemy.autobuild.integration/0.3","package":{"name":"demo","version":"1.0","kind":"oorexx"},"tests":[{"name":"t","argv":["true"]}],"publish":{"artifact_only":true}}' || "0a"x)
  self~write(base || "/package/payload.txt",payload || "0a"x)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add " || .AlchemyShell~quote("autobuild/inbox/" || submissionId || "/package"))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m body")
  ready=.directory~new; ready["schema"]="alchemy.autobuild.git-submission/0.1"; ready["submission_id"]=submissionId; ready["submitted_by"]=submittedBy; ready["package_path"]="package"
  .JSON~toJsonFile(base || "/ready.json",ready,.true)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add " || .AlchemyShell~quote("autobuild/inbox/" || submissionId || "/ready.json"))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m ready")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q origin HEAD:refs/heads/" || .AlchemyShell~quote(branch))
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q main")
  return branch

::method addMainSubmission class
  use strict arg repo, submissionId, payload="payload"
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q main")
  base=repo || "/autobuild/inbox/" || submissionId
  self~write(base || "/package/integration.json",'{"schema":"alchemy.autobuild.integration/0.3","package":{"name":"demo","version":"1.0","kind":"oorexx"},"tests":[{"name":"t","argv":["true"]}],"publish":{"artifact_only":true}}' || "0a"x)
  self~write(base || "/package/payload.txt",payload || "0a"x)
  ready=.directory~new; ready["schema"]="alchemy.autobuild.git-submission/0.1"; ready["submission_id"]=submissionId; ready["submitted_by"]="CHATGPT"; ready["package_path"]="package"
  .JSON~toJsonFile(base || "/ready.json",ready,.true)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add autobuild")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m main-ready")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q origin main")

::method addReceipt class
  use strict arg repo, submissionId
  self~sh("git -C " || .AlchemyShell~quote(repo) || " checkout -q main")
  self~write(repo || "/autobuild/receipts/" || submissionId || ".json",'{"status":"PASS"}' || "0a"x)
  self~sh("git -C " || .AlchemyShell~quote(repo) || " add autobuild/receipts")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " commit -q -m receipt")
  self~sh("git -C " || .AlchemyShell~quote(repo) || " push -q origin main")

::method assertEq class
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("FAIL " || label || " expected=" || expected || " actual=" || actual)

::method assertTrue class
  use strict arg condition,label
  if \condition then raise syntax 88.900 array("FAIL " || label)

::requires "AlchemyTransport.cls"
::requires "json.cls"
