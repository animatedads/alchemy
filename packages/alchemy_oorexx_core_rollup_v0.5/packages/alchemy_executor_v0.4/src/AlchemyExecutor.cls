/* Alchemy Executor v0.1 */

::class AlchemyExecutorBuild public
::constant VERSION "0.4"
::constant API "alchemy.executor/0.1"

::class AlchemyProcessResult subclass AlchemyCoreComponent public
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute timedOut get
::method init
  expose rc stdout stderr timedOut
  use strict arg rc, stdout, stderr, timedOut=.false
  self~initCoreComponent("AlchemyProcessResult", "0.3", "Alchemy core AlchemyProcessResult component")

::class AlchemyExecutedTest subclass AlchemyCoreComponent public
::attribute plan get
::attribute process get
::attribute status get
::method init
  expose plan process status
  use strict arg plan, process
  self~initCoreComponent("AlchemyExecutedTest", "0.3", "Alchemy core AlchemyExecutedTest component")
  if process~rc=0 then status="PASS"; else status="FAIL"

::class AlchemyPackageExecutionResult subclass AlchemyCoreComponent public
::attribute packageSpec get
::attribute source get
::attribute plan get
::attribute tests get
::attribute status get
::method init
  expose packageSpec source plan tests status
  use strict arg packageSpec, source, plan, tests
  self~initCoreComponent("AlchemyPackageExecutionResult", "0.3", "Alchemy core AlchemyPackageExecutionResult component")
  tests=.AlchemyCollections~copyArray(tests)
  status="PASS"
  do t over tests; if t~status<>"PASS" then status="FAIL"; end

::class AlchemyHostEnvironment subclass AlchemyCoreComponent public
::method minimal class
  out=.table~new
  do key over .array~of("PATH","HOME","LANG","LC_ALL","TZ","REXX_PATH")
    v=value(key,,"ENVIRONMENT")
    if v<>"" then out[key]=v
  end
  if \out~hasIndex("PATH") then out["PATH"]="/usr/local/bin:/usr/bin:/bin"
  return out

::class AlchemyProcessRunner subclass AlchemyCoreComponent public
::method init
  expose runner
  use strict arg runner=.nil
  self~initCoreComponent("AlchemyProcessRunner", "0.3", "Alchemy core AlchemyProcessRunner component")
  if runner==.nil then runner=.AlchemyCommandRunner~new

::method run
  expose runner
  use strict arg plannedTest
  envArgs=.array~of("/usr/bin/env","-i")
  keys=.array~new; sup=plannedTest~environment~supplier
  do while sup~available; keys~append(sup~index~string); sup~next; end
  keys~sort
  do key over keys
    self~assertEnvKey(key)
    envArgs~append(key || "=" || plannedTest~environment[key])
  end
  envArgs~append("/usr/bin/timeout")
  envArgs~append("--signal=TERM")
  envArgs~append("--kill-after=5s")
  envArgs~append(plannedTest~timeoutSeconds || "s")
  do a over plannedTest~argv; envArgs~append(a); end
  r=runner~run(envArgs,plannedTest~cwd)
  return .AlchemyProcessResult~new(r~rc,r~stdout,r~stderr,r~rc=124)

::method assertEnvKey private
  use strict arg key
  if key="" then raise syntax 88.900 array("empty environment key")
  allowed="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"
  do i=1 to key~length
    if allowed~pos(key~substr(i,1))=0 then raise syntax 88.900 array("invalid environment key: " || key)
  end

::class AlchemyExecutor subclass AlchemyCoreComponent public
::method init
  expose processRunner
  use strict arg processRunner=.nil
  self~initCoreComponent("AlchemyExecutor", "0.3", "Alchemy core AlchemyExecutor component")
  if processRunner==.nil then processRunner=.AlchemyProcessRunner~new

::method execute
  expose processRunner
  use strict arg materializedPackage, dependencyFloor, repoRoot, baseEnvironment=.nil
  if materializedPackage==.nil then raise syntax 88.900 array("materialized package required")
  if dependencyFloor==.nil then dependencyFloor=.AlchemyDependencyFloor~new
  if baseEnvironment==.nil then baseEnvironment=.AlchemyHostEnvironment~minimal
  spec=.AlchemyIntegrationCodec~decodeFile(materializedPackage~manifestPath)
  context=.AlchemyPlanningContext~new(materializedPackage~root,repoRoot,baseEnvironment)
  plan=.AlchemyExecutionPlanner~new~plan(spec,dependencyFloor,context)
  executed=.array~new
  do testPlan over plan~tests
    process=processRunner~run(testPlan)
    executed~append(.AlchemyExecutedTest~new(testPlan,process))
  end
  return .AlchemyPackageExecutionResult~new(spec,materializedPackage~source,plan,executed)

::requires "AlchemyPackageModel.cls"
::requires "AlchemyTransport.cls"

::requires "AlchemyCoreComponent.cls"
