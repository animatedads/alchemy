floor = .AlchemyDependencyFloor~new
set = .table~new
set['BROKEN_ROOT'] = '/does/not/exist'
env = .AlchemyEnvironmentSpec~new(set, .nil, 'prepend', .nil, .false, .nil, .array~of('BROKEN_ROOT'))
tests = .array~of(.AlchemyTestSpec~new('noop', .array~of('rexx','noop.rex'), '.', 10, env))
spec = .AlchemyPackageSpec~new(.AlchemyPackageId~new('demo','0.1'), '.', .nil, .nil, tests)
paths = .AlchemyFakePathPolicy~new(.array~of('/pkg'))
ctx = .AlchemyPlanningContext~new('/pkg','/repo',.nil,paths)

signal on syntax name caught
ignore = .AlchemyExecutionPlanner~new~plan(spec, floor, ctx)
say 'FAIL missing required directory was accepted'
exit 1
caught:
  say 'PASS test_required_directory'
  exit 0

::requires '../src/AlchemyPackageModel.cls'
