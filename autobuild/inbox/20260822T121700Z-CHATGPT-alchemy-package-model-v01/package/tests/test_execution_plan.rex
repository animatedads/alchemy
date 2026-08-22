call rxfuncadd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

floor = .AlchemyDependencyFloor~new
floor~add(.AlchemyDependencyFloorEntry~new(.AlchemyPackageId~new('reputation_effect','0.2'), '/repo/packages/reputation_effect_v0.2', 'REPUTATION_EFFECT_ROOT', .array~of('src')))
floor~add(.AlchemyDependencyFloorEntry~new(.AlchemyPackageId~new('runtime_registry','0.12'), '/repo/packages/runtime_registry_v0.12', 'RUNTIME_REGISTRY_ROOT', .array~of('src')))

deps = .array~of(.AlchemyDependencyRef~new('reputation_effect','0.2'), .AlchemyDependencyRef~new('runtime_registry','0.12'))

packageSet = .table~new
packageSet['PACKAGE_FLAG'] = 'base'
packageEnv = .AlchemyEnvironmentSpec~new(packageSet, .array~of('${PACKAGE_ROOT}/bin'), 'prepend', .array~of('${PACKAGE_ROOT}/src'), .true)

oneSet = .table~new
oneSet['SCRIPT_FLAVOUR'] = 'communication'
oneEnv = .AlchemyEnvironmentSpec~new(oneSet, .nil, 'prepend', .array~of('${PACKAGE_ROOT}/tests/support/communication'), .true, .array~of('REPUTATION_EFFECT_ROOT'), .array~of('REPUTATION_EFFECT_ROOT'), .array~of('SCRIPT_FLAVOUR'))

twoSet = .table~new
twoSet['SCRIPT_FLAVOUR'] = 'feed'
twoEnv = .AlchemyEnvironmentSpec~new(twoSet, .nil, 'replace', .array~of('${PACKAGE_ROOT}/tests/support/feed', '${REPO_ROOT}/packages/reputation_feed_v0.1/src'), .true, .array~of('RUNTIME_REGISTRY_ROOT'), .array~of('RUNTIME_REGISTRY_ROOT'), .array~of('SCRIPT_FLAVOUR'))

tests = .array~of(,
  .AlchemyTestSpec~new('communication', .array~of('rexx','tests/test_communication.rex'), '.', 30, oneEnv),,
  .AlchemyTestSpec~new('feed', .array~of('rexx','tests/test_feed.rex'), '.', 45, twoEnv))

spec = .AlchemyPackageSpec~new(.AlchemyPackageId~new('ourladyair_shannon','0.10'), '.', packageEnv, deps, tests, .AlchemyPublishSpec~new('.', 'packages/ourladyair_shannon_v0.10'))

base = .table~new
base['PATH'] = '/usr/bin:/bin'
base['REXX_PATH'] = '/ambient/should-not-win-for-replace'
paths = .AlchemyFakePathPolicy~new(.array~of(,
  '/pkg', '/pkg/src', '/pkg/tests/support/communication', '/pkg/tests/support/feed',,
  '/repo/packages/reputation_effect_v0.2', '/repo/packages/reputation_effect_v0.2/src',,
  '/repo/packages/runtime_registry_v0.12', '/repo/packages/runtime_registry_v0.12/src',,
  '/repo/packages/reputation_feed_v0.1/src'))
ctx = .AlchemyPlanningContext~new('/pkg', '/repo', base, paths)

plan = .AlchemyExecutionPlanner~new~plan(spec, floor, ctx)
call assertEq 2, plan~tests~items, 'planned test count'
call assertEq '/repo/packages/reputation_effect_v0.2', plan~dependencyRoots['reputation_effect@0.2'], 'resolved effect root'

one = plan~tests[1]
two = plan~tests[2]
call assertEq 'communication', one~name, 'first name'
call assertEq 'feed', two~name, 'second name'
call assertEq '/pkg', one~cwd, 'cwd expanded'
call assertEq 'communication', one~environment['SCRIPT_FLAVOUR'], 'per test set one'
call assertEq 'feed', two~environment['SCRIPT_FLAVOUR'], 'per test set two'
call assertEq '/repo/packages/reputation_effect_v0.2', one~environment['REPUTATION_EFFECT_ROOT'], 'dependency export effect'
call assertEq '/repo/packages/runtime_registry_v0.12', one~environment['RUNTIME_REGISTRY_ROOT'], 'dependency export registry'
call assertEq '/pkg/bin:/usr/bin:/bin', one~environment['PATH'], 'path prepend'
call assertEq '/pkg/tests/support/communication:/pkg/src:/repo/packages/reputation_effect_v0.2/src:/repo/packages/runtime_registry_v0.12/src:/ambient/should-not-win-for-replace', one~environment['REXX_PATH'], 'communication rexx path'
call assertEq '/pkg/tests/support/feed:/repo/packages/reputation_feed_v0.1/src', two~environment['REXX_PATH'], 'feed replace rexx path'
call assertEq 'communication', one~reportEnvironment['SCRIPT_FLAVOUR'], 'report one'
call assertEq 'feed', two~reportEnvironment['SCRIPT_FLAVOUR'], 'report two'

different = one~environment['REXX_PATH'] \== two~environment['REXX_PATH']
call assertTrue different, 'test-specific REXX_PATH differs'

say 'PASS test_execution_plan'
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return

::requires '../src/AlchemyPackageModel.cls'
