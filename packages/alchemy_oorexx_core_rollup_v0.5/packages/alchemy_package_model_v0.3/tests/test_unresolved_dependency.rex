id=.AlchemyPackageId~new("p","1")
deps=.array~of(.AlchemyDependencyRef~new("missing","9"))
test=.AlchemyTestSpec~new("t",.array~of("rexx","x.rex"))
spec=.AlchemyPackageSpec~new(id,".",.nil,deps,.array~of(test))
policy=.AlchemyFakePathPolicy~new(.array~of("/pkg"))
signal on syntax name good
.AlchemyExecutionPlanner~new~plan(spec,.AlchemyDependencyFloor~new,.AlchemyPlanningContext~new("/pkg","/repo",.nil,policy))
signal off syntax
say "FAIL unresolved dependency accepted"; exit 1
good: signal off syntax; say "PASS test_unresolved_dependency"; exit 0
::requires "AlchemyPackageModel.cls"
