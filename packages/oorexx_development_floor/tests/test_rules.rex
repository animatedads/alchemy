manager = .DFDevelopmentManager~new
scope = .Directory~new
manager~rules~add(.DFRule~new("G", scope, "general"))
scope = .Directory~new; scope["LANGUAGE"] = "ooRexx"
manager~rules~add(.DFRule~new("L", scope, "language"))
scope = .Directory~new; scope["PACKAGE"] = "ALCHEMY_LOG"
manager~rules~add(.DFRule~new("P", scope, "package"))
scope = .Directory~new; scope["PACKAGE"] = "ALCHEMY_LOG"; scope["IMPLEMENTATION"] = "PERSISTENCE"
manager~rules~add(.DFRule~new("PI", scope, "package implementation"))
context = .Directory~new; context["IMPLEMENTATION"] = "PERSISTENCE"; context["PLATFORM"] = "LINUX"
a = .DFAssignment~new("A1", "FRAMEWORK", "ALCHEMY_LOG", "ooRexx", "test", context)
rules = manager~effectiveRules(a)
call assertEqual 4, rules~items, "matching rule count"
call assertEqual "G", rules[1]~id, "general first"
call assertEqual "PI", rules[4]~id, "most specific last"
say "PASS test_rules"
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
::requires "DevelopmentFloor.cls"
