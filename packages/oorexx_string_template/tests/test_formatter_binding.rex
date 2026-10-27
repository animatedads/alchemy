ctx = .Directory~new
ctx["code"] = "abc"

registry = .TemplateFormatterRegistry~default
registry~register("bracket", .BracketFormatter~new)
t = .StringTemplate~new("${code|bracket}", registry)

call assertTrue t~formatters~isSealed, "template captures sealed formatter registry"
call assertEq t~render(ctx), "[abc]", "captured formatter before caller mutation"

registry~register("bracket", .AngleFormatter~new)
call assertEq t~render(ctx), "[abc]", "caller registry mutation cannot alter compiled template"

signal on syntax name expectedSealed
ignore = t~formatters~register("new", .AngleFormatter~new)
signal off syntax
say "FAIL captured registry accepted mutation"
exit 1

expectedSealed:
  say "EXPECTED SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  signal off syntax

unbound = .StringTemplate~new("${code|domain}")
missing = unbound~missingFormatterNames
call assertEq missing~items, 1, "missing formatter inventory count"
call assertEq missing[1], "domain", "missing formatter inventory name"
call assertEq unbound~requirements~formatters[1], "domain", "unbound template remains inspectable"

signal on syntax name expectedUnbound
ignore = unbound~render(ctx)
signal off syntax
say "FAIL unbound formatter survived rendering"
exit 1

expectedUnbound:
  say "EXPECTED SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D")
  signal off syntax

binding = .TemplateFormatterRegistry~default
binding~register("domain", .BracketFormatter~new)
bound = unbound~withFormatters(binding)
call assertEq bound~missingFormatterNames~items, 0, "explicit rebinding satisfies requirements"
call assertEq bound~render(ctx), "[abc]", "explicit rebinding renders"

say "PASS test_formatter_binding"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

assertTrue: procedure
  use arg actual, label
  if \actual then do
    say "FAIL" label
    exit 1
  end
  return

::class BracketFormatter subclass TemplateFormatter public
::method format
  use strict arg value, argument=""
  return "[" || value || "]"

::class AngleFormatter subclass TemplateFormatter public
::method format
  use strict arg value, argument=""
  return "<" || value || ">"

::requires "StringTemplate.cls"
