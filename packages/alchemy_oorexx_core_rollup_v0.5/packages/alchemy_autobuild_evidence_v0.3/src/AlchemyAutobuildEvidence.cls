/*
 * AlchemyEvidence v0.1
 *
 * Terminal run evidence and receipt persistence.  This component does not
 * execute packages and does not decide PASS/FAIL; it records an already-made
 * outcome atomically on accepted main.
 */

::class AlchemyAutobuildEvidenceBuild public
::constant VERSION "0.3"
::constant API "alchemy.evidence/0.1"
::constant RESULT_SCHEMA "alchemy.autobuild.result/1.0"
::constant RECEIPT_SCHEMA "alchemy.autobuild.receipt/1.0"

::class AlchemyAutobuildEvidenceSubject subclass AlchemyCoreComponent public
::attribute submissionId get
::attribute sourceKind get
::attribute sourceRef get
::attribute sourceCommit get
::attribute packageTree get
::attribute submittedBy get

::method init
  expose submissionId sourceKind sourceRef sourceCommit packageTree submittedBy
  use strict arg submissionId, sourceKind, sourceRef, sourceCommit="", packageTree="", submittedBy=""
  self~initCoreComponent("AlchemyAutobuildEvidenceSubject", "0.2", "Autobuild evidence subject")
  submissionId=submissionId~string~strip
  sourceKind=sourceKind~string~strip
  sourceRef=sourceRef~string
  sourceCommit=sourceCommit~string~strip
  packageTree=packageTree~string~strip
  submittedBy=submittedBy~string~strip
  if submissionId="" then raise syntax 88.900 array("evidence submission id required")
  if sourceKind="" then raise syntax 88.900 array("evidence source kind required")

::class AlchemyAutobuildEvidenceOutcome subclass AlchemyCoreComponent public
::attribute subject get
::attribute status get
::attribute orchestration get
::attribute errorCondition get
::attribute errorMessage get
::attribute startedAt get
::attribute finishedAt get

::method init
  expose subject status orchestration errorCondition errorMessage startedAt finishedAt
  use strict arg subject, status, orchestration=.nil, errorCondition="", errorMessage="", startedAt="", finishedAt=""
  self~initCoreComponent("AlchemyAutobuildEvidenceOutcome", "0.2", "Terminal autobuild outcome")
  if subject==.nil then raise syntax 88.900 array("evidence subject required")
  status=status~string~strip~upper
  if status<>"PASS" & status<>"FAIL" & status<>"ERROR" then raise syntax 88.900 array("invalid evidence status: " || status)
  errorCondition=errorCondition~string~strip~upper
  errorMessage=errorMessage~string
  startedAt=startedAt~string
  finishedAt=finishedAt~string

::class AlchemyAutobuildEvidenceWriteResult subclass AlchemyCoreComponent public
::attribute status get
::attribute resultPath get
::attribute receiptPath get
::attribute commit get

::method init
  expose status resultPath receiptPath commit
  use strict arg status, resultPath="", receiptPath="", commit=""
  self~initCoreComponent("AlchemyAutobuildEvidenceWriteResult", "0.2", "Autobuild evidence persistence result")

::class AlchemyAutobuildEvidenceClock subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner=.nil
  self~initCoreComponent("AlchemyAutobuildEvidenceClock", "0.2", "UTC evidence clock")
  if runner==.nil then runner=.AlchemyCommandRunner~new

::method nowUtc
  expose runner
  line=.AlchemyTransportText~firstLine(runner~require(.array~of("date","-u","+%Y-%m-%dT%H:%M:%S.%3NZ"),"","UTC clock")~stdout)
  if line="" then raise syntax 88.900 array("UTC clock returned empty time")
  return line

::method compactUtc
  expose runner
  line=.AlchemyTransportText~firstLine(runner~require(.array~of("date","-u","+%Y%m%dT%H%M%S%3NZ"),"","UTC compact clock")~stdout)
  if line="" then raise syntax 88.900 array("UTC compact clock returned empty time")
  return line

::class AlchemyAutobuildEvidenceWriter subclass AlchemyCoreComponent public
::method init
  expose runner clock
  use strict arg runner=.nil, clock=.nil
  self~initCoreComponent("AlchemyAutobuildEvidenceWriter", "0.2", "Leased terminal autobuild evidence writer")
  if runner==.nil then runner=.AlchemyCommandRunner~new
  if clock==.nil then clock=.AlchemyAutobuildEvidenceClock~new(runner)

::method receiptExists
  expose runner
  use strict arg repoRoot, submissionId
  submissionId=submissionId~string~strip
  if submissionId="" then raise syntax 88.900 array("receipt lookup submission id required")
  .AlchemyArchivePathPolicy~assertOne(submissionId)
  lease=.AlchemyRepositoryLease~new(repoRoot)~acquire(30)
  leaseActive=.true
  signal on syntax name receiptSyntax
  runner~require(.array~of("git","fetch","origin","+refs/heads/main:refs/remotes/origin/main"),repoRoot,"receipt main fetch")
  rel="autobuild/receipts/" || submissionId || ".json"
  probe=runner~run(.array~of("git","cat-file","-e","refs/remotes/origin/main:" || rel),repoRoot)
  exists=probe~rc=0
  lease~close; leaseActive=.false; signal off syntax
  return exists
receiptSyntax:
  signal off syntax
  if leaseActive then lease~close
  raise propagate

::method record
  expose runner clock
  use strict arg repoRoot, outcome
  if outcome==.nil then raise syntax 88.900 array("evidence outcome required")
  subject=outcome~subject
  .AlchemyArchivePathPolicy~assertOne(subject~submissionId)
  receiptRel="autobuild/receipts/" || subject~submissionId || ".json"

  tx=.AlchemyGitMainTransaction~new(repoRoot,runner)~begin
  receiptPath=tx~root || "/" || receiptRel
  runner~require(.array~of("mkdir","-p",tx~root || "/autobuild/receipts"),"","evidence receipt directory")
  if .AlchemyTransportFs~isFile(receiptPath) then do
    tx~close
    return .AlchemyAutobuildEvidenceWriteResult~new("EXISTING","",receiptRel,"")
  end

  runId=clock~compactUtc || "-" || self~safeToken(subject~submissionId)
  resultRel="autobuild/results/" || runId || "/result.json"
  resultRoot=tx~root || "/autobuild/results/" || runId
  logsRoot=resultRoot || "/logs"
  runner~require(.array~of("mkdir","-p",logsRoot),"","evidence result directory")

  tests=.array~new
  package=.directory~new
  publication=.directory~new
  if outcome~orchestration \== .nil then do
    orchestration=outcome~orchestration
    execution=orchestration~execution
    package["name"]=execution~packageSpec~packageId~name
    package["version"]=execution~packageSpec~packageId~version
    package["kind"]=execution~packageSpec~packageId~kind
    package["key"]=execution~packageSpec~packageId~key
    pub=orchestration~publication
    publication["status"]=pub~status
    publication["path"]=pub~path
    publication["commit"]=pub~commit
    index=0
    do executed over execution~tests
      index+=1
      plan=executed~plan
      process=executed~process
      leaf=self~twoDigits(index) || "-" || self~safeToken(plan~name)
      stdoutRel="autobuild/results/" || runId || "/logs/" || leaf || ".stdout.txt"
      stderrRel="autobuild/results/" || runId || "/logs/" || leaf || ".stderr.txt"
      self~writeText(tx~root || "/" || stdoutRel,process~stdout)
      self~writeText(tx~root || "/" || stderrRel,process~stderr)
      t=.directory~new
      t["name"]=plan~name
      t["status"]=executed~status
      t["returncode"]=process~rc
      t["timed_out"]=process~timedOut
      t["timeout_seconds"]=plan~timeoutSeconds
      t["cwd"]=plan~cwd
      t["stdout_path"]=stdoutRel
      t["stderr_path"]=stderrRel
      t["environment"]=plan~reportEnvironment
      tests~append(t)
    end
  end

  source=.directory~new
  source["kind"]=subject~sourceKind
  source["ref"]=subject~sourceRef
  source["commit"]=subject~sourceCommit
  source["package_tree"]=subject~packageTree
  source["submitted_by"]=subject~submittedBy

  doc=.directory~new
  doc["schema"]=.AlchemyAutobuildEvidenceBuild~RESULT_SCHEMA
  doc["run_id"]=runId
  doc["submission_id"]=subject~submissionId
  doc["status"]=outcome~status
  doc["started_at"]=outcome~startedAt
  doc["finished_at"]=outcome~finishedAt
  doc["source"]=source
  doc["package"]=package
  doc["publication"]=publication
  doc["tests"]=tests
  if outcome~errorCondition<>"" then doc["error_condition"]=outcome~errorCondition
  if outcome~errorMessage<>"" then doc["error_message"]=outcome~errorMessage
  .JSON~toJsonFile(tx~root || "/" || resultRel,doc,.true)

  receipt=.directory~new
  receipt["schema"]=.AlchemyAutobuildEvidenceBuild~RECEIPT_SCHEMA
  receipt["submission_id"]=subject~submissionId
  receipt["status"]=outcome~status
  receipt["result_path"]=resultRel
  receipt["recorded_at"]=clock~nowUtc
  receipt["source_commit"]=subject~sourceCommit
  receipt["package_tree"]=subject~packageTree
  .JSON~toJsonFile(receiptPath,receipt,.true)

  commit=tx~commitAndPush(.array~of("autobuild/results/" || runId,receiptRel),"autobuild receipt: " || subject~submissionId || " " || outcome~status)
  tx~close
  return .AlchemyAutobuildEvidenceWriteResult~new("RECORDED",resultRel,receiptRel,commit)

::method writeText private
  use strict arg path, text
  s=.stream~new(path)
  s~open("write replace")
  s~charout(text~string)
  s~close

::method safeToken private
  use strict arg value
  src=value~string
  allowed="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
  out=""
  do i=1 to src~length
    ch=src~substr(i,1)
    if allowed~pos(ch)>0 then out ||= ch
    else out ||= "-"
  end
  do while out~pos("--")>0; out=out~changeStr("--","-"); end
  out=out~strip("B","-")
  if out="" then out="run"
  return out

::method twoDigits private
  use strict arg value
  s=value~string
  if s~length<2 then return "0" || s
  return s

::requires "AlchemyTransport.cls"
::requires "AlchemyRepositoryLease.cls"
::requires "AlchemyCoreComponent.cls"
::requires "json.cls"
