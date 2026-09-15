/* Alchemy Publisher v0.1 */

::class AlchemyPublisherBuild public
::constant VERSION "0.4"
::constant API "alchemy.publisher/0.1"

::class AlchemyPublicationResult subclass AlchemyCoreComponent public
::attribute status get
::attribute path get
::attribute commit get
::method init
  expose status path commit
  use strict arg status, path="", commit=""
  self~initCoreComponent("AlchemyPublicationResult", "0.3", "Alchemy core AlchemyPublicationResult component")

::class AlchemyPublisher subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner=.nil
  self~initCoreComponent("AlchemyPublisher", "0.3", "Leased accepted-main publisher")
  if runner==.nil then runner=.AlchemyCommandRunner~new

::method publish
  expose runner
  use strict arg materializedPackage, executionResult, repoRoot
  if executionResult~status<>"PASS" then return .AlchemyPublicationResult~new("REJECTED_TEST_FAILURE")
  spec=executionResult~packageSpec~publish
  if spec~artifactOnly then return .AlchemyPublicationResult~new("SKIPPED_ARTIFACT_ONLY")

  .AlchemyArchivePathPolicy~assertOne(spec~source)
  .AlchemyArchivePathPolicy~assertOne(spec~path)
  if spec~source="." then sourceRoot=materializedPackage~root
  else sourceRoot=materializedPackage~root || "/" || spec~source
  if \.AlchemyTransportFs~isDirectory(sourceRoot) then raise syntax 88.900 array("publish source is not a directory: " || sourceRoot)

  tx=.AlchemyGitMainTransaction~new(repoRoot,runner)~begin
  target=tx~root || "/" || spec~path
  if .AlchemyTransportFs~isDirectory(target) then do
    cmp=runner~run(.array~of("diff","-qr","--",sourceRoot,target),"")
    if cmp~rc=0 then do
      tx~close
      return .AlchemyPublicationResult~new("NOOP_IDENTICAL",spec~path,"")
    end
    tx~close
    if cmp~rc=1 then raise syntax 88.900 array("publish collision: target exists with different content: " || spec~path)
    raise syntax 88.900 array("publish comparison failed rc=" || cmp~rc || " stderr=" || cmp~stderr)
  end

  slash=target~lastPos("/")
  if slash>1 then parent=target~left(slash-1)
  else parent=tx~root
  runner~require(.array~of("mkdir","-p",parent),"","publish parent")
  runner~require(.array~of("cp","-a","--",sourceRoot,target),"","publish source copy")
  commit=tx~commitAndPush(.array~of(spec~path),"publish: " || executionResult~packageSpec~packageId~key)
  tx~close
  return .AlchemyPublicationResult~new("PUBLISHED",spec~path,commit)

::requires "AlchemyPackageModel.cls"
::requires "AlchemyTransport.cls"
::requires "AlchemyExecutor.cls"

::requires "AlchemyCoreComponent.cls"
