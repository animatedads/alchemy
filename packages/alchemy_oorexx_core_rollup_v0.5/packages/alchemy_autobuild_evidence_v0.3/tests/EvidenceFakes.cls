::class FakePackageId public
::attribute name get
::attribute version get
::attribute kind get
::method init
  expose name version kind
  name="demo"; version="1.0"; kind="oorexx"
::method key
  return "demo@1.0"

::class FakePackageSpec public
::attribute packageId get
::method init
  expose packageId
  packageId=.FakePackageId~new

::class FakePlan public
::attribute name get
::attribute timeoutSeconds get
::attribute cwd get
::attribute reportEnvironment get
::method init
  expose name timeoutSeconds cwd reportEnvironment
  name="acceptance"; timeoutSeconds=30; cwd="/tmp/pkg"
  reportEnvironment=.table~new; reportEnvironment["REXX_PATH"]="/tmp/pkg/src"

::class FakeProcess public
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute timedOut get
::method init
  expose rc stdout stderr timedOut
  rc=0; stdout="hello" || "0a"x; stderr=""; timedOut=.false

::class FakeExecuted public
::attribute plan get
::attribute process get
::attribute status get
::method init
  expose plan process status
  plan=.FakePlan~new; process=.FakeProcess~new; status="PASS"

::class FakeExecution public
::attribute packageSpec get
::attribute tests get
::attribute status get
::method init
  expose packageSpec tests status
  packageSpec=.FakePackageSpec~new; tests=.array~of(.FakeExecuted~new); status="PASS"

::class FakePublication public
::attribute status get
::attribute path get
::attribute commit get
::method init
  expose status path commit
  status="PUBLISHED"; path="packages/demo_v1.0"; commit="abc123"

::class FakeOrchestration public
::attribute execution get
::attribute publication get
::attribute status get
::method init
  expose execution publication status
  execution=.FakeExecution~new; publication=.FakePublication~new; status="PASS"
