/*
 * Alchemy Submission v0.1
 *
 * Producer-side Git transport. A finished package is validated through the
 * package model, committed as a body commit, followed by ready.json, and both
 * commits are transferred in one push to a unique submission branch.
 */

::class AlchemySubmissionBuild public
::constant VERSION "0.4"
::constant API "alchemy.submission/0.1"
::constant READY_SCHEMA "alchemy.autobuild.git-submission/0.1"

::class AlchemySubmissionResult subclass AlchemyCoreComponent public
::attribute submissionId get
::attribute branch get
::attribute bodyCommit get
::attribute readyCommit get
::attribute packageId get
::attribute dryRun get

::method init
  expose submissionId branch bodyCommit readyCommit packageId dryRun
  use strict arg submissionId, branch, bodyCommit="", readyCommit="", packageId=.nil, dryRun=.false
  self~initCoreComponent("AlchemySubmissionResult", "0.3", "Alchemy core AlchemySubmissionResult component")
  if dryRun then dryRun=.true; else dryRun=.false

::class AlchemyGitSubmissionSender subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner=.nil
  self~initCoreComponent("AlchemyGitSubmissionSender", "0.3", "Leased Alchemy Git submission sender")
  if runner==.nil then runner=.AlchemyCommandRunner~new

::method submit
  expose runner
  use strict arg repoRoot, packageRoot, submittedBy, submissionId="", dryRun=.false
  repoRoot=repoRoot~string
  packageRoot=packageRoot~string
  submittedBy=submittedBy~string~strip
  if submittedBy="" then raise syntax 88.900 array("submitted-by required")
  if \.AlchemyTransportFs~isDirectory(repoRoot || "/.git") then raise syntax 88.900 array("submission sender requires Git repository")
  if \.AlchemyTransportFs~isDirectory(packageRoot) then raise syntax 88.900 array("package directory not found: " || packageRoot)
  manifestPath=packageRoot || "/integration.json"
  if \.AlchemyTransportFs~isFile(manifestPath) then raise syntax 88.900 array("package integration.json not found")
  .AlchemyTransportTreePolicy~assertSafe(packageRoot,runner)
  spec=.AlchemyIntegrationCodec~decodeFile(manifestPath)

  if submissionId="" then submissionId=self~newSubmissionId(submittedBy,spec~packageId)
  .AlchemyArchivePathPolicy~assertOne(submissionId)
  branch="autobuild-submit/" || submissionId
  if dryRun then return .AlchemySubmissionResult~new(submissionId,branch,"","",spec~packageId,.true)

  lease=.AlchemyRepositoryLease~new(repoRoot)~acquire(30)
  leaseActive=.true
  active=.false
  signal on syntax name submitSyntax
  refspec="+refs/heads/main:refs/remotes/origin/main"
  runner~require(.array~of("git","fetch","origin",refspec),repoRoot,"submission base fetch")
  base=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","--verify","refs/remotes/origin/main^{commit}"),repoRoot,"submission base resolve")~stdout)
  exists=runner~run(.array~of("git","ls-remote","--exit-code","--heads","origin","refs/heads/" || branch),repoRoot)
  if exists~rc=0 then raise syntax 88.900 array("submission branch already exists: " || branch)
  if exists~rc<>2 then raise syntax 88.900 array("unable to check submission branch existence rc=" || exists~rc)

  wt=SysTempFileName("/tmp/alchemy-submit-worktree-??????")
  if wt="" then raise syntax 88.900 array("unable to allocate submission worktree")
  runner~require(.array~of("git","worktree","add","--detach",wt,base),repoRoot,"submission worktree add")
  active=.true
  packageRel="autobuild/inbox/" || submissionId || "/package"
  packageTarget=wt || "/" || packageRel
  runner~require(.array~of("mkdir","-p",packageTarget),"","submission package target")
  runner~require(.array~of("cp","-a","--",packageRoot || "/.",packageTarget || "/"),"","submission package copy")
  runner~require(.array~of("git","add","--",packageRel),wt,"submission body add")
  runner~require(.array~of("git","config","user.name","Alchemy ooRexx Submission"),wt,"submission identity")
  runner~require(.array~of("git","config","user.email","alchemy-submit@localhost"),wt,"submission identity")
  runner~require(.array~of("git","commit","-m","autobuild submit body: " || submissionId),wt,"submission body commit")
  body=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),wt)~stdout)

  readyRel="autobuild/inbox/" || submissionId || "/ready.json"
  ready=.directory~new
  ready["schema"]=.AlchemySubmissionBuild~READY_SCHEMA
  ready["submission_id"]=submissionId
  ready["submitted_by"]=submittedBy
  ready["package_path"]="package"
  .JSON~toJsonFile(wt || "/" || readyRel,ready,.true)
  runner~require(.array~of("git","add","--",readyRel),wt,"submission ready add")
  runner~require(.array~of("git","commit","-m","autobuild submit ready: " || submissionId),wt,"submission ready commit")
  readyCommit=.AlchemyTransportText~firstLine(runner~require(.array~of("git","rev-parse","HEAD"),wt)~stdout)

  /* One network publication operation transfers body + ready commits together. */
  runner~require(.array~of("git","push","origin","HEAD:refs/heads/" || branch),wt,"submission push")
  runner~require(.array~of("git","worktree","remove","--force",wt),repoRoot,"submission worktree cleanup")
  active=.false
  lease~close; leaseActive=.false
  signal off syntax
  return .AlchemySubmissionResult~new(submissionId,branch,body,readyCommit,spec~packageId,.false)

submitSyntax:
  signal off syntax
  if active then runner~run(.array~of("git","worktree","remove","--force",wt),repoRoot)
  if leaseActive then lease~close
  raise propagate

::method newSubmissionId private
  use strict arg submittedBy, packageId
  stamp=date("S") || "T" || time("L")~changestr(":","")~changestr(".","")
  token=random(100000,999999)
  return stamp || "-" || self~safeToken(submittedBy) || "-" || self~safeToken(packageId~name) || "-" || token

::method safeToken private
  use strict arg text
  src=text~string
  allowed="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
  out=""
  do i=1 to src~length
    ch=src~substr(i,1)
    if allowed~pos(ch)>0 then out ||= ch
    else out ||= "-"
  end
  do while out~pos("--")>0; out=out~changestr("--","-"); end
  out=out~strip("B","-")
  if out="" then out="submission"
  return out

::requires "AlchemyTransport.cls"
::requires "AlchemyRepositoryLease.cls"
::requires "AlchemyPackageModel.cls"
::requires "json.cls"

::requires "AlchemyCoreComponent.cls"
