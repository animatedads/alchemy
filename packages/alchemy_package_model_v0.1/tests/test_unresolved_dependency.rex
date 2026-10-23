floor = .AlchemyDependencyFloor~new
deps = .array~of(.AlchemyDependencyRef~new('missing_component','9.9'))
tests = .array~of(.AlchemyTestSpec~new('noop', .array~of('rexx','noop.rex')))
spec = .AlchemyPackageSpec~new(.AlchemyPackageId~new('demo','0.1'), '.', .nil, deps, tests)
paths = .AlchemyFakePathPolicy~new(.array~of('/pkg'))
ctx = .AlchemyPlanningContext~new('/pkg','/repo',.nil,paths)

signal on syntax name caught
ignore = .AlchemyExecutionPlanner~new~plan(spec, floor, ctx)
say 'FAIL unresolved dependency was accepted'
exit 1
caught:
  say 'PASS test_unresolved_dependency'
  exit 0

::requires '../src/AlchemyPackageModel.cls'
