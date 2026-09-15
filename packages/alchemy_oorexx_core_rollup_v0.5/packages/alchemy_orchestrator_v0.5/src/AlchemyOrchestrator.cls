/*
 * Alchemy Orchestrator v0.1
 *
 * Composition root only. Transport materializes; dependency catalog resolves;
 * executor plans/runs; publisher publishes. This class does not duplicate any
 * of those policies.
 */

::class AlchemyOrchestratorBuild public
::constant VERSION "0.5"
::constant API "alchemy.orchestrator/0.1"

::class AlchemyOrchestrationResult subclass AlchemyCoreComponent public
::attribute source get
::attribute execution get
::attribute publication get
::attribute status get

::method init
  expose source execution publication status
  use strict arg source, execution, publication
  self~initCoreComponent("AlchemyOrchestrationResult", "0.4", "Alchemy core AlchemyOrchestrationResult component")
  if execution~status <> "PASS" then status = "FAIL"
  else status = "PASS"

::class AlchemyOrchestrator subclass AlchemyCoreComponent public
::method init
  expose runner executor publisher catalog
  use strict arg runner=.nil, executor=.nil, publisher=.nil, catalog=.nil
  self~initCoreComponent("AlchemyOrchestrator", "0.4", "Manifest-first snapshot orchestrator")
  if runner==.nil then runner=.AlchemyCommandRunner~new
  if executor==.nil then executor=.AlchemyExecutor~new(.AlchemyProcessRunner~new(runner))
  if publisher==.nil then publisher=.AlchemyPublisher~new(runner)
  if catalog==.nil then catalog=.AlchemyRepositoryDependencyCatalog~new(runner)

::method processGitSubmission
  expose runner
  use strict arg repoRoot, revision, submissionId, workspaceRoot=""
  source=.AlchemyGitSubmissionDiscovery~new~discover(repoRoot,revision,submissionId,runner)
  return self~processSource(source,.AlchemyGitBranchTransport~new,repoRoot,workspaceRoot)

::method processManagedZip
  use strict arg repoRoot, zipPath, workspaceRoot=""
  source=.AlchemyTransportSource~new("managed-zip",zipPath)
  return self~processSource(source,.AlchemyManagedZipTransport~new,repoRoot,workspaceRoot)

::method processLocalDirectory
  use strict arg repoRoot, directoryPath, workspaceRoot=""
  source=.AlchemyTransportSource~new("local-directory",directoryPath)
  return self~processSource(source,.AlchemyLocalDirectoryTransport~new,repoRoot,workspaceRoot)

::method processSource
  expose runner executor publisher catalog
  use strict arg source, transport, repoRoot, workspaceRoot=""
  ownWorkspace=.false
  snapshot=.nil
  snapshotActive=.false
  if workspaceRoot="" then do
    workspaceRoot=SysTempFileName("/tmp/alchemy-orchestrator-??????")
    if workspaceRoot="" | SysMkDir(workspaceRoot)<>0 then raise syntax 88.900 array("unable to allocate orchestration workspace")
    ownWorkspace=.true
  end
  if \.AlchemyTransportFs~isDirectory(workspaceRoot) then raise syntax 88.900 array("orchestration workspace is not a directory: " || workspaceRoot)

  signal on syntax name orchestrationSyntax
  context=.AlchemyTransportContext~new(workspaceRoot,repoRoot,runner)
  materialized=transport~materialize(source,context)

  /* Dependency resolution and ${REPO_ROOT} come from the exact accepted remote
   * main snapshot, never from the caller's potentially stale/dirty checkout. */
  snapshot=.AlchemyGitRevisionSnapshot~new(repoRoot,runner)~begin
  snapshotActive=.true
  floor=catalog~build(snapshot~root)
  execution=executor~execute(materialized,floor,snapshot~root)
  snapshot~close; snapshotActive=.false

  publication=publisher~publish(materialized,execution,repoRoot)
  orchestration=.AlchemyOrchestrationResult~new(materialized~source,execution,publication)

  if ownWorkspace then runner~run(.array~of("rm","-rf","--",workspaceRoot),"")
  signal off syntax
  return orchestration

orchestrationSyntax:
  signal off syntax
  if snapshotActive then snapshot~close
  if ownWorkspace then runner~run(.array~of("rm","-rf","--",workspaceRoot),"")
  raise propagate

::requires "AlchemyTransport.cls"
::requires "AlchemyPackageModel.cls"
::requires "AlchemyDependencyFloor.cls"
::requires "AlchemyExecutor.cls"
::requires "AlchemyPublisher.cls"

::requires "AlchemyCoreComponent.cls"
