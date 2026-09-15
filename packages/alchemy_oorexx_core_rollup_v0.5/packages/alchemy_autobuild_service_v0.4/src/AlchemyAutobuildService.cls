/*
 * AlchemyAutobuildService v0.1
 *
 * Resident composition loop only. Discovery belongs to AlchemyInbox;
 * materialization/planning/execution/publication belong to AlchemyOrchestrator;
 * terminal persistence belongs to AlchemyAutobuildEvidence.
 */

::class AlchemyAutobuildServiceBuild public
::constant VERSION "0.4"
::constant API "alchemy.autobuild.service/0.1"

::class AlchemyAutobuildServiceItemResult subclass AlchemyCoreComponent public
::attribute submissionId get
::attribute status get
::attribute evidence get
::attribute message get

::method init
  expose submissionId status evidence message
  use strict arg submissionId, status, evidence=.nil, message=""
  self~initCoreComponent("AlchemyAutobuildServiceItemResult", "0.3", "Autobuild service item result")

::class AlchemyAutobuildServiceCycleResult subclass AlchemyCoreComponent public
::attribute discovered get
::attribute processed get
::attribute results get
::attribute suppressedReceipts get

::method init
  expose discovered processed results suppressedReceipts
  use strict arg discovered, processed, results, suppressedReceipts
  self~initCoreComponent("AlchemyAutobuildServiceCycleResult", "0.3", "Autobuild service cycle result")
  results=.AlchemyTransportCollections~copyArray(results)
  suppressedReceipts=.AlchemyTransportCollections~copyArray(suppressedReceipts)

::class AlchemyAutobuildService subclass AlchemyCoreComponent public
::method init
  expose repoRoot pollSeconds runner inbox orchestrator evidence clock
  use strict arg repoRoot, pollSeconds=5, runner=.nil, inbox=.nil, orchestrator=.nil, evidence=.nil, clock=.nil
  self~initCoreComponent("AlchemyAutobuildService", "0.3", "Leased resident ooRexx autobuild service")
  repoRoot=repoRoot~string
  pollSeconds=pollSeconds+0
  if pollSeconds<1 then raise syntax 88.900 array("autobuild poll seconds must be >= 1")
  if runner==.nil then runner=.AlchemyCommandRunner~new
  if inbox==.nil then inbox=.AlchemyGitInbox~new(runner)
  if orchestrator==.nil then orchestrator=.AlchemyOrchestrator~new(runner)
  if clock==.nil then clock=.AlchemyAutobuildEvidenceClock~new(runner)
  if evidence==.nil then evidence=.AlchemyAutobuildEvidenceWriter~new(runner,clock)
  if \.AlchemyTransportFs~isDirectory(repoRoot || "/.git") then raise syntax 88.900 array("autobuild service requires Git repository checkout")

::method runOnce
  expose repoRoot inbox evidence
  scan=inbox~scan(repoRoot)
  results=.array~new
  processed=0
  do candidate over scan~candidates
    /* Recheck terminal receipt immediately before work to close scan races. */
    if evidence~receiptExists(repoRoot,candidate~submissionId) then iterate
    item=self~processCandidate(candidate)
    results~append(item)
    processed+=1
  end
  return .AlchemyAutobuildServiceCycleResult~new(scan~candidates~items,processed,results,scan~suppressedReceipts)

::method runForever
  expose pollSeconds
  do forever
    self~runOnce
    call SysSleep pollSeconds
  end

::method processCandidate private
  expose repoRoot orchestrator evidence clock
  use strict arg candidate
  started=clock~nowUtc
  subject=.AlchemyAutobuildEvidenceSubject~new(candidate~submissionId,"git-branch",candidate~sourceRef,candidate~revision,candidate~packageTree,candidate~submittedBy)
  if candidate~conflicted then do
    finished=clock~nowUtc
    outcome=.AlchemyAutobuildEvidenceOutcome~new(subject,"ERROR",.nil,"INBOX_CONFLICT",candidate~conflictMessage,started,finished)
    wr=evidence~record(repoRoot,outcome)
    return .AlchemyAutobuildServiceItemResult~new(candidate~submissionId,"ERROR",wr,candidate~conflictMessage)
  end

  signal on syntax name processSyntax
  signal on error name processError
  signal on failure name processFailure
  orchestration=orchestrator~processGitSubmission(repoRoot,candidate~revision,candidate~submissionId)
  signal off syntax
  signal off error
  signal off failure
  finished=clock~nowUtc
  outcome=.AlchemyAutobuildEvidenceOutcome~new(subject,orchestration~status,orchestration,"","",started,finished)
  wr=evidence~record(repoRoot,outcome)
  return .AlchemyAutobuildServiceItemResult~new(candidate~submissionId,orchestration~status,wr,"")

processSyntax:
  signal off syntax
  signal off error
  signal off failure
  return self~recordCondition(candidate,subject,started,condition("O"))
processError:
  signal off syntax
  signal off error
  signal off failure
  return self~recordCondition(candidate,subject,started,condition("O"))
processFailure:
  signal off syntax
  signal off error
  signal off failure
  return self~recordCondition(candidate,subject,started,condition("O"))

::method recordCondition private
  expose repoRoot evidence clock
  use strict arg candidate, subject, started, conditionObject
  conditionName="ERROR"; message="autobuild processing error"
  if conditionObject \== .nil then do
    if conditionObject~hasIndex("CONDITION") then conditionName=conditionObject["CONDITION"]~string
    if conditionObject~hasIndex("MESSAGE") then message=conditionObject["MESSAGE"]~string
    if message="" & conditionObject~hasIndex("ERRORTEXT") then message=conditionObject["ERRORTEXT"]~string
  end
  finished=clock~nowUtc
  outcome=.AlchemyAutobuildEvidenceOutcome~new(subject,"ERROR",.nil,conditionName,message,started,finished)
  wr=evidence~record(repoRoot,outcome)
  return .AlchemyAutobuildServiceItemResult~new(candidate~submissionId,"ERROR",wr,message)

::requires "AlchemyInbox.cls"
::requires "AlchemyOrchestrator.cls"
::requires "AlchemyAutobuildEvidence.cls"
::requires "AlchemyCoreComponent.cls"
